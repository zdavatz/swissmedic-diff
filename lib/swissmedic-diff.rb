#!/usr/bin/env ruby
# SwissmedicDiff -- swissmedic-diff -- 27.03.2008 -- hwyss@ywesee.com

require 'ostruct'
require 'simple_xlsx_reader'
require 'pp'
require File.join(File.dirname(__FILE__), 'version.rb')


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
    VALUE_UNLIMITED = nil
    REGEXP_UNLIMITED = /unbegrenzt/i

  module Diff
    COLUMNS_OLD = [ :iksnr, :seqnr, :name_base, :company,
                :index_therapeuticus, :atc_class, :production_science,
                :registration_date, :sequence_date, :expiry_date, :ikscd,
                :size, :unit, :ikscat, :substances, :composition,
                :indication_registration, :indication_sequence ]

    COLUMNS_FEBRUARY_2019= {
      :iksnr => /Zulassungs-Nummer/i,                  # column-nr: 0
      :seqnr => /Dosisstärke-nummer/i,
      :name_base => /Bezeichnung des Arzneimittels/i,
      :company => /Zulassungsinhaberin/i,
      :production_science => /Heilmittelcode/i,
      :index_therapeuticus => /IT-Nummer/i,            # column-nr: 5
      :atc_class => /ATC-Code/i,
      :registration_date => /Erstzul.datum Arzneimittel/i,
      :sequence_date => /Zul.datum Dosisstärke/i,
      :expiry_date => /Gültigkeitsdauer der Zulassung/i,
      :ikscd => /Packungscode/i,                 # column-nr: 10
      :size => /Packungsgrösse/i,
      :unit => /Einheit/i,
      :ikscat => /Abgabekategorie Packung/i,
      :ikscat_seq => /Abgabekategorie Dosisstärke/i,
      :ikscat_preparation => /Abgabekategorie Arzneimittel/i, # column-nr: 15
      :substances => /Wirkstoff/i,
      :composition => /Zusammensetzung/i,
      :composition_AMZV => /Volldeklaration rev. AMZV umgesetzt/i,
      :indication_registration => /Anwendungsgebiet Arzneimittel/i,
      :indication_sequence => /Anwendungsgebiet Dosisstärke/i, # column-nr 20
      :gen_production => /Gentechnisch hergestellte Wirkstoffe/i,
      :insulin_category => /Kategorie bei Insulinen/i,
      # swissmedi corrected in february 2018 the typo  betäubunsmittel to  betäubungsmittel-
        :drug_index       => /Verz. bei betäubungsmittel-haltigen Arzneimittel/i,
    }
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
    DATE_FORMAT = '%Y:%m:%d'

    def capitalize(string)
      string.split(/\s+/).collect { |word| word.capitalize }.join(' ')
    end
    def cell(row, pos)
      if(cell = row[pos])
        cell.to_s
      end
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
        if row[COLUMNS_2014.keys.index(flag)].to_s.match(REGEXP_UNLIMITED)
          sprintf "%s (%s)", txt, 'unbegrenzt'
        else
          sprintf "%s (%s)", txt, row[COLUMNS_2014.keys.index(flag)].strftime('%d.%m.%Y')
        end
      else
        row = diff.newest_rows[iksnr].sort.first.last
        sprintf "%s (%s)", txt, cell(row, COLUMNS_2014.keys.index(flag))
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
      t_rows = SimpleXlsxReader.open(target).sheets.first.rows.slurp
      idx, prr, prp = nil
      multiples = {}
      l_rows = SimpleXlsxReader.open(latest).sheets.first.rows.slurp
      @latest_keys = get_column_indices(l_rows).keys
      @target_keys = get_column_indices(t_rows).keys
      each_valid_row(t_rows) { |row|
        iksnr = cell(row, @target_keys.index(:iksnr))
        seqnr = cell(row, @target_keys.index(:seqnr))
        pacnr = cell(row, @target_keys.index(:ikscd))
        (multiples[iksnr] ||= {})
        if prr == iksnr && prp == pacnr
          idx += 1
        elsif previous = multiples[iksnr][pacnr]
          prr = iksnr
          prp = pacnr
          idx = previous[@target_keys.size].to_i + 1
        else
          prr = iksnr
          prp = pacnr
          idx = 0
        end
        row[@target_keys.size] = idx
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
          replacements.store [ iksnr, seqnr, cell(row, @target_keys.index(:size)),
                                cell(row, @target_keys.index(:unit)) ], row
          flags = changes[iksnr]
          flags.push(:sequence).uniq! unless(flags.include? :new)
          news.push row
        end
      }
      @diff.replacements = reps = {}
      known_pacs.each { |(iksnr, pacnr), row|
        key = [iksnr, '%02i' % cell(row, @target_keys.index(:seqnr)).to_i,
                      cell(row, @target_keys.index(:size)), cell(row, @target_keys.index(:unit))]
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
        key[1,0] = '%02i' % cell(row, @target_keys.index(:seqnr)).to_i
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
      sheet = SimpleXlsxReader.open(latest).sheets.first
      rows = sheet.rows.slurp
      @latest_keys = get_column_indices(rows).keys
      idx, prr, prp = nil
      multiples = {}

      each_valid_row(rows) { |row|
        iksnr = cell(row, @latest_keys.index(:iksnr))
        seqnr = cell(row, @latest_keys.index(:seqnr))
        pacnr = cell(row, @latest_keys.index(:ikscd))
        multiples[iksnr] ||= {}
        if prr == iksnr && prp == pacnr
          idx += 1
        elsif previous = multiples[iksnr][pacnr]
          prr = iksnr
          prp = pacnr
          idx = previous[@latest_keys.size].to_i + 1
        else
          prr = iksnr
          prp = pacnr
          idx = 0
        end
        multiples[iksnr][pacnr] = row
        row[@latest_keys.size] = idx
        known_regs.store [iksnr], row
        known_seqs.store [iksnr, seqnr], row
        known_pacs.store [iksnr, pacnr, idx], row
        (newest_rows[iksnr] ||= {})[pacnr] = row
      }
    end
    def name(diff, iksnr)
      rows = diff.newest_rows[iksnr]
      row = rows.sort.first.last
      cell(row, COLUMNS_2014.keys.index(:name_base))
    end
    def rows_diff(row, other, ignore = [])
      flags = []
      COLUMNS_OLD.each_with_index {
        |key, idx|
        if !ignore.include?(key)
          left  = _comparable(key, row,   @target_keys.index(key))
          right = _comparable(key, other, @latest_keys.index(key))
          next if left.is_a?(Date) && right.is_a?(Date) && left.strftime(DATE_FORMAT).eql?(right.strftime(DATE_FORMAT))
          next if left.is_a?(String) && left.empty? && !right
          next if right.is_a?(String) && right.empty? && !left
          if left != right
            flags.push key
          end
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
          "+ " + describe(@diff, iksnr)
        elsif(flags.include? :delete)
          "- " + describe(@diff, iksnr)
        else
          "> " + describe(@diff, iksnr) << "; " \
            + flags.collect { |flag| describe_flag(@diff, iksnr, flag)
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
          if  row[idx] && row[idx] && REGEXP_UNLIMITED.match(row[idx].to_s)
            VALUE_UNLIMITED # Date.new(2099,12,31)
          else
            row[idx]
          end
        when :seqnr
          sprintf "%02i", cell(row, idx).to_i
        else
          cell(row, idx).downcase.gsub(/\s+/, "")
        end
      end
    end

    def get_column_indices(rows)
      headerRowId = rows_to_skip(rows)-1
      row = rows[headerRowId]
      row = rows[5] # Headers are found at row 5 since February 5
      0.upto((COLUMNS_FEBRUARY_2019.size) -1).each{ |idx| puts "#{idx}: #{row[idx]}" }  if $VERBOSE
      COLUMNS_FEBRUARY_2019.each{
        |key, value|
        header_name = row[COLUMNS_FEBRUARY_2019.keys.index(key)].to_s
        unless value.match(header_name)
          puts "#{__LINE__}: #{key} ->  #{COLUMNS_FEBRUARY_2019.keys.index(key)} #{value}\nbut was  #{header_name}" if $VERBOSE
          error_2019 = "Packungen.xlslx_has_unexpected_column_#{COLUMNS_FEBRUARY_2019.keys.index(key)}_#{key}_#{value.to_s}_but_was_#{header_name}"
        break
        end
      }
     COLUMNS_FEBRUARY_2019
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
    # rows:: rows to operate on
    #
    #return  ::
    def each_valid_row(rows)
      skipRows = rows_to_skip(rows)
      column_keys = get_column_indices(rows).keys
      row_nr = 0
      rows.each() {
        |row|
        row_nr += 1
        next if row_nr <= skipRows
        break unless row
        if row.size < column_keys.size/2
          $stdout.puts "Data missing in \n(line " + (row_nr).to_s + "): " + row.join(", ").to_s + "\n"
          next
        end
        next if (cell(row, column_keys.index(:production_science)) == 'Tierarzneimittel')
        row[column_keys.index(:iksnr)] = "%05i" % cell(row, column_keys.index(:iksnr)).to_i
        row[column_keys.index(:seqnr)] = "%02i" % cell(row, column_keys.index(:seqnr)).to_i
        row[column_keys.index(:ikscd)] = "%03i" % cell(row, column_keys.index(:ikscd)).to_i
        yield row
      }
    end

    def rows_to_skip(rows)
      j = 0
      while true
        cell = rows[j][0]
        break if cell.respond_to?(:to_i) and cell.to_i != 0
        j += 1
      end
      j
    end

  end
  include Diff
end
