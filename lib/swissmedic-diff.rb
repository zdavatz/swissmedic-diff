#!/usr/bin/env ruby
# encoding: utf-8
# SwissmedicDiff -- swissmedic-diff -- 27.03.2008 -- hwyss@ywesee.com

require 'ostruct'
require 'spreadsheet'

class SwissmedicDiff
  module Diff
    COLUMNS = [ :iksnr, :seqnr, :name_base, :company, :product_group,
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
      tbook.worksheet(0).each(3) { |row|
        group = cell(row, column(:product_group))
        if(group != 'TAM')
          iksnr = cell(row, column(:iksnr))
          seqnr = "%02i" % cell(row, column(:seqnr)).to_i
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
        end
      }
      @diff.replacements = reps = {}
      known_pacs.each { |(iksnr, pacnr, idx), row|
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
      lbook.worksheet(0).each(3) { |row| 
        group = cell(row, column(:product_group))
        if(group != 'TAM')
          iksnr = cell(row, column(:iksnr))
          seqnr = "%02i" % cell(row, column(:seqnr)).to_i
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
        end
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
    def to_s(sort=:group)
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
  end
  include Diff
end
