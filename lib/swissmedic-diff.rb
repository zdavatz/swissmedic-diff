#!/usr/bin/env ruby
# encoding: utf-8
# SwissmedicDiff -- swissmedic-diff -- 27.03.2008 -- hwyss@ywesee.com

require 'ostruct'
require 'spreadsheet'

#= diff command (compare two xls fles) for swissmedic xls file.
#
#Compares two Excel Documents provided by Swissmedic and displays the
#salient differences. Also: Find out what Products have changed on the
#swiss healthcare market.
#
#Authors::   Hannes Wyss (hwyss@ywesee.com), Masaomi Hatakeyama (mhatakeyama@ywesee.com)
#Version::   0.1.4 2013-10-16 commit c30af5c15f6b8101f8f84cb482dfd09ab20729d6
#Copyright:: Copyright (C) ywesee GmbH, 2010. All rights reserved.
#License::   GPLv2.0 Compliance 
#Source::    http://scm.ywesee.com/?p=swissmedic-diff/.git;a=summary
class SwissmedicDiff
  VERSION = '0.1.4'

  module Diff
    COLUMNS = [ :iksnr, :seqnr, :name_base, :company, 
                :index_therapeuticus, :atc_class, :production_science,
                :registration_date, :sequence_date, :expiry_date, :ikscd,
                :size, :unit, :ikscat, :substances, :composition,
                :indication_registration, :indication_sequence ]
    FLAGS = {
      :new                      =>  'Neues Produkt',
      :name_base                =>  'Namensänderung',
      :ikscat                   =>  'Abgabekategorie',
      :index_therapeuticus      =>  'Index Therapeuticus',
      :indication_registration  =>  'Anwendungsgebiet Präparate',
      :indication_sequence      =>  'Anwendungsgebiet Sequenz',
      :company                  =>  'Zulassungsinhaber',
      :composition              =>  'Zusammensetzung',
      :sequence                 =>  'Packungen',
      :size                     =>  'Packungsgrösse',
      :expiry_date              =>  'Ablaufdatum der Zulassung',
      :registration_date        =>  'Erstzulassungsdatum',
      :sequence_date            =>  'Zulassungsdatum Sequenz',
      :delete                   =>  'Das Produkt wurde gelöscht',
      :replaced_package         =>  'Packungs-Nummer',
      :substances               =>  'Wirkstoffe',
      :production_science       =>  'Heilmittelcode',
      :atc_class                =>  'ATC-Code',
    }
    GALFORM_P = %r{excipiens\s+(ad|pro)\s+(?<galform>((?!\bpro\b)[^.])+)}

    def capitalize(string)
      string.split(/\s+/).collect { |word| word.capitalize }.join(' ')
    end
    def cell(row, pos)
      if(cell = row[pos])
        cell.to_s
      end
    end
    def column(key)
      COLUMNS.index(key)
    end
    def describe(diff, iksnr)
      sprintf("%s: %s", iksnr, name(diff, iksnr))
    end
    def describe_flag(diff, iksnr, flag)
      txt = FLAGS.fetch(flag, flag)
      case flag
      when :sequence
      when :replaced_package
        pairs = diff.newest_rows[iksnr].collect { |rep, row|
          if(old = diff.replacements[row])
            [old, rep].join(' -> ')
          end
        }.compact
        sprintf "%s (%s)", txt, pairs.join(',')
      when :registration_date, :expiry_date
        row = diff.newest_rows[iksnr].sort.first.last
        sprintf "%s (%s)", txt, row[column(flag)].strftime('%d.%m.%Y')
      else
        row = diff.newest_rows[iksnr].sort.first.last
        sprintf "%s (%s)", txt, cell(row, column(flag))
      end
    end

    #=== Comparison two Excel files
    #
    #_target_:: new file path (String)
    #_latest_:: old file path (String)
    #_ignore_:: columns not to be compared (Symbol)
    #
    #return  :: differences (OpenStruct class)
    def diff(target, latest, ignore = [])
      replacements = {}
      known_regs, known_seqs, known_pacs, newest_rows = known_data(latest)
      @diff = OpenStruct.new
      @diff.news = news = []
      @diff.updates = updates = []
      @diff.changes = changes = {}
      @diff.newest_rows = newest_rows
      Spreadsheet.client_encoding = 'UTF-8'
      tbook = Spreadsheet.open(target)
      sheet = tbook.worksheet(0)
      if new_column = cell(sheet.row(2), COLUMNS.size)
        raise "New column #{COLUMNS.size} (#{new_column})"
      end
      idx, prr, prp = nil
      multiples = {}
      each_valid_row(tbook) { |row|
        iksnr = cell(row, column(:iksnr))
        seqnr = cell(row, column(:seqnr))
        pacnr = cell(row, column(:ikscd))
        (multiples[iksnr] ||= {})
        if prr == iksnr && prp == pacnr
          idx += 1
        elsif previous = multiples[iksnr][pacnr]
          prr = iksnr
          prp = pacnr
          idx = previous[COLUMNS.size].to_i + 1
        else
          prr = iksnr
          prp = pacnr
          idx = 0
        end
        row[COLUMNS.size] = idx
        (newest_rows[iksnr] ||= {})[pacnr] = row
        multiples[iksnr][pacnr] = row
        if(other = known_regs.delete([iksnr]))
          changes[iksnr] ||= []
        else
          changes[iksnr] ||= [:new]
        end
        known_seqs.delete([iksnr, seqnr])
        if(other = known_pacs.delete([iksnr, pacnr, idx]))
          flags = rows_diff(row, other, ignore)
          (changes[iksnr].concat flags).uniq!
          updates.push row unless flags.empty?
        else
          replacements.store [ iksnr, seqnr, cell(row, column(:size)), 
                                cell(row, column(:unit)) ], row
          flags = changes[iksnr]
          flags.push(:sequence).uniq! unless(flags.include? :new)
          news.push row
        end
      }
      @diff.replacements = reps = {}
      known_pacs.each { |(iksnr, pacnr), row|
        key = [iksnr, '%02i' % cell(row, column(:seqnr)).to_i, 
                      cell(row, column(:size)), cell(row, column(:unit))]
        if(rep = replacements[key])
          changes[iksnr].push :replaced_package
          reps.store rep, pacnr
        end
      }
      known_regs.each_key { |(iksnr,_)| changes[iksnr] = [:delete] }
      changes.delete_if { |iksnr, flags| flags.empty? }
      @diff.package_deletions = known_pacs.collect { |key, row|
        ## the keys in known_pacs don't include the sequence number (which
        #  would prevent us from properly recognizing multi-sequence-Packages), 
        #  so we need complete the path to the package now
        key[1,0] = '%02i' % cell(row, column(:seqnr)).to_i
        key
      }
      @diff.sequence_deletions = known_seqs.keys
      @diff.registration_deletions = known_regs.keys
      @diff
    end
    def format_flags(flags)
      flags.delete(:revision)
      flags.collect { |flag|
        "- %s\n" % FLAGS.fetch(flag, "Unbekannt (#{flag})")
      }.compact.join
    end
    def known_data(latest)
      known_regs = {}
      known_seqs = {}
      known_pacs = {}
      newest_rows = {}
      _known_data latest, known_regs, known_seqs, known_pacs, newest_rows
      [known_regs, known_seqs, known_pacs, newest_rows]
    end
    def _known_data(latest, known_regs, known_seqs, known_pacs, newest_rows)
      lbook = Spreadsheet.open(latest)
      idx, prr, prp = nil
      multiples = {}
      each_valid_row(lbook) { |row|
        iksnr = cell(row, column(:iksnr))
        seqnr = cell(row, column(:seqnr))
        pacnr = cell(row, column(:ikscd))
        multiples[iksnr] ||= {}
        if prr == iksnr && prp == pacnr
          idx += 1
        elsif previous = multiples[iksnr][pacnr]
          prr = iksnr
          prp = pacnr
          idx = previous[COLUMNS.size].to_i + 1
        else
          prr = iksnr
          prp = pacnr
          idx = 0
        end
        multiples[iksnr][pacnr] = row
        row[COLUMNS.size] = idx
        known_regs.store [iksnr], row
        known_seqs.store [iksnr, seqnr], row
        known_pacs.store [iksnr, pacnr, idx], row
        (newest_rows[iksnr] ||= {})[pacnr] = row                            
      }
    end
    def name(diff, iksnr)
      rows = diff.newest_rows[iksnr]
      row = rows.sort.first.last
      cell(row, column(:name_base))
    end
    def rows_diff(row, other, ignore = [])
      flags = []
      COLUMNS.each_with_index { |key, idx|
        if(!ignore.include?(key) \
           && _comparable(key, row, idx) != _comparable(key, other, idx))
          flags.push key
        end
      }
      flags
    end

    #=== Output the differencies with String
    #
    # This should be called after diff method.
    #
    #_sort_ :: sort key (:group | :name | :registration)
    #
    #return :: difference (String)
    def to_s(sort=:group)
      @diff ||= nil
      return '' unless @diff
      @diff.changes.sort_by { |iksnr, flags| 
        _sort_by(sort, iksnr, flags)
      }.collect { |iksnr, flags|
        if(flags.include? :new)
          "+ " << describe(@diff, iksnr)
        elsif(flags.include? :delete)
          "- " << describe(@diff, iksnr)
        else
          "> " << describe(@diff, iksnr) << "; " \
            << flags.collect { |flag| describe_flag(@diff, iksnr, flag) 
          }.compact.join(", ")
        end
      }.join("\n")
    end
    def _sort_by(sort, iksnr, flags)
      case sort
      when :name
        [name(@diff, iksnr), iksnr]
      when :registration
        iksnr
      else
        weight = if(flags.include? :new)
                   0
                 elsif(flags.include? :delete)
                   1
                 else
                   2
                 end
        [weight, iksnr]
      end
    end
    def _comparable(key, row, idx)
      if cell = row[idx]
        case key
        when :registration_date, :expiry_date
          row[idx]
        when :seqnr
          sprintf "%02i", cell.to_i
        else
          cell(row, idx).downcase.gsub(/\s+/, "")
        end
      end
    end
  
    #=== iterate over all valid rows of a swissmedic Packungen.xls
    #
    # Iterates over all rows, ignoring Tierarzneimittel and
    # lines  with not enough data
    # Patches the fields :iksnr, :seqnr, :ikscd to match the old swissmedic convention
    # of a fixed sized string
    #
    # example:
    #   SwissmedicDiff.new.each_valid_row(Spreadsheet.open('path/to/file')) { |x| puts "iksnr #{x[0]}" }
    #
    #_spreadsheet_:: spreadsheet to operate on
    #
    #return  ::
    def each_valid_row(spreadsheet)
      worksheet = spreadsheet.worksheet(0)
      # Packungen.xls of swissmedic before October 2013 had  3 leading rows
      # Packungen.xls of swissmedic after  October 2013 have 4 leading rows
      skipRows = worksheet.row(3)[0].to_i == 0 ? 4 : 3
      worksheet.each(skipRows) {
        |row|
        if row.size < COLUMNS.size/2 || row.select{|val| val==nil}.size > COLUMNS.size/2
          raise "Data missing in \n(line " + (row.idx+1).to_s + "): " + row.join(", ").to_s + "\n"
        end
        next if (cell(row, column(:production_science)) == 'Tierarzneimittel')
        row[column(:iksnr)] = "%05i" % cell(row, column(:iksnr)).to_i
        row[column(:seqnr)] = "%02i" % cell(row, column(:seqnr)).to_i
        row[column(:ikscd)] = "%03i" % cell(row, column(:ikscd)).to_i
        yield row
      }
    end
  end
  include Diff
end
