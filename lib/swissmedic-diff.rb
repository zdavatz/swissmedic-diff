#!/usr/bin/env ruby
# SwissmedicDiff -- swissmedic-diff -- 27.03.2008 -- hwyss@ywesee.com

require 'ostruct'
require 'parseexcel'

class SwissmedicDiff
  module Diff
    COLUMNS = [ :iksnr, :seqnr, :name_base, :company, :product_group, 
                :index_therapeuticus, :production_science, :registration_date,
                :expiry_date, :ikscd, :size, :unit, :ikscat, :substances,
                :composition ]
    FLAGS = {
      :new                 =>  'Neues Produkt',
      :name_base           =>  'Namensänderung', 
      :ikscat              =>  'Abgabekategorie',
      :index_therapeuticus =>  'Index Therapeuticus',
      :company             =>  'Zulassungsinhaber',
      :composition         =>  'Zusammensetzung', 
      :sequence            =>  'Packungen', 
      :size                =>  'Packungsgrösse',
      :expiry_date         =>  'Ablaufdatum der Zulassung',
      :registration_date   =>  'Erstzulassungsdatum',
      :delete              =>  'Das Produkt wurde gelöscht',
      :replaced_package    =>  'Packungs-Nummer',
      :substances          =>  'Wirkstoffe',
      :production_science  =>  'Heilmittelcode',
    }
    GALFORM_P = %r{excipiens\s+(ad|pro)\s+(?<galform>((?!\bpro\b)[^.])+)}
    def capitalize(string)
      string.split(/\s+/).collect { |word| word.capitalize }.join(' ')
    end
    def cell(row, pos)
      if(cell = row.at(pos))
        case cell
        when String
          cell
        else
          cell.to_s('latin1')
        end
      end
    rescue
      cell.to_s
    end
    def data_diff(row, other)
      flags = rows_diff(row, other)
      package = @app.registration(cell(row, 0)).package(cell(row, 9))
      flags.select { |flag|
        origin = package.data_origin(flag)
        origin ||= package.sequence.data_origin(flag)
        origin ||= package.registration.data_origin(flag)
        origin.nil? || origin == :swissmedic
      }
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
        sprintf "%s (%s)", txt, 
                row.at(COLUMNS.index(flag)).date.strftime('%d.%m.%Y')
      else
        row = diff.newest_rows[iksnr].sort.first.last
        sprintf "%s (%s)", txt, cell(row, COLUMNS.index(flag))
      end
    end
    def diff(target, latest)
      replacements = {}
      known_regs, known_seqs, known_pacs, newest_rows = known_data(latest)
      @diff = OpenStruct.new
      @diff.news = news = []
      @diff.updates = updates = []
      @diff.changes = changes = {}
      @diff.newest_rows = newest_rows
      tbook = Spreadsheet::ParseExcel.parse(target)
      tbook.worksheet(0).each(3) { |row|
        group = cell(row, 4)
        if(group != 'TAM')
          iksnr = cell(row, 0)
          seqnr = "%02i" % cell(row, 1).to_i
          pacnr = cell(row, 9)
          (newest_rows[iksnr] ||= {})[pacnr] = row
          if(other = known_regs.delete(iksnr))
            changes[iksnr] ||= []
          else
            changes[iksnr] ||= [:new]
          end
          known_seqs.delete([iksnr, seqnr])
          if(other = known_pacs.delete([iksnr, seqnr, pacnr]))
            flags = latest ? rows_diff(row, other) : data_diff(row, other)
            (changes[iksnr].concat flags).uniq!
            updates.push row unless flags.empty?
          else
            replacements.store [iksnr, seqnr, cell(row, 10), cell(row, 11)], row
            flags = changes[iksnr]
            flags.push(:sequence).uniq! unless(flags.include? :new)
            news.push row
          end
        end
      }
      @diff.replacements = reps = {}
      known_pacs.each { |(iksnr, seqnr, pacnr), row|
        key = [iksnr, "%02i" % cell(row, 1).to_i, cell(row, 10), cell(row, 11)]
        if(rep = replacements[key])
          changes[iksnr].push :replaced_package
          reps.store rep, pacnr
        end
      }
      known_regs.each_key { |iksnr| changes[iksnr] = [:delete] }
      changes.delete_if { |iksnr, flags| flags.empty? }
      @diff.package_deletions = known_pacs.keys
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
      lbook = Spreadsheet::ParseExcel.parse(latest)
      lbook.worksheet(0).each(3) { |row| 
        group = cell(row, 4)
        if(group != 'TAM')
          iksnr = cell(row, 0)
          seqnr = "%02i" % cell(row, 1).to_i
          pacnr = cell(row, 9)
          known_regs.store iksnr, row
          known_seqs.store [iksnr, seqnr], row
          known_pacs.store [iksnr, seqnr, pacnr], row
          (newest_rows[iksnr] ||= {})[pacnr] = row
        end
      }
    end
    def name(diff, iksnr)
      rows = diff.newest_rows[iksnr]
      row = rows.sort.first.last
      cell(row, 2)
    end
    def rows_diff(row, other)
      flags = []
      COLUMNS.each_with_index { |key, idx|
        if(cell(row, idx) != cell(other, idx))
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
  end
  include Diff
end
