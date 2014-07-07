#!/usr/bin/env ruby
# -*- encoding: utf-8 -*-
# SwissmedicPluginTest -- oddb.org -- 18.03.2008 -- hwyss@ywesee.com

$: << File.expand_path("../lib", File.dirname(__FILE__))

require 'minitest/autorun'
require 'swissmedic-diff'
require 'pp'  

module ODDB
  class SwissmedicPluginTest < Minitest::Test
    def setup
      @diff = SwissmedicDiff.new
      @data = File.expand_path 'data/Packungen.xls',
                                File.dirname(__FILE__)
      @older = File.expand_path 'data/Packungen.older.xls',
                                File.dirname(__FILE__)
      @data_error_column = File.expand_path 'data/Packungen_error_column.xls',
                                File.dirname(__FILE__)
      @data_error_missing_case1 = File.expand_path 'data/Packungen_error_missing1.xls',
                                File.dirname(__FILE__)
      @data_error_missing_case2 = File.expand_path 'data/Packungen_error_missing2.xls',
                                File.dirname(__FILE__)
      @data_2013 = File.expand_path 'data/Packungen-2013.10.14.xls',
                                File.dirname(__FILE__)
      @workbook = Spreadsheet.open(@data)
    end
    
    def test_diff_xls_and_xlsx
      @diff = SwissmedicDiff.new
      last_month = File.expand_path 'data/Packungen_2013_small.xls',  File.dirname(__FILE__)
      this_month = File.expand_path 'data/Packungen_2014_small.xlsx',  File.dirname(__FILE__)
      result = @diff.diff last_month, this_month, [:atc_class, :sequence_date]
      assert(result.changes.flatten.index('Zulassungs-Nummer') == nil, "Should not find Zulassungs-Nummer in changes")
      # puts "Got #{result.news.size} news, #{result.changes.size} changes, #{result.updates.size} updates."
      assert_equal(8, result.news.size)
      assert_equal(3, result.changes.size)
      assert_equal(1, result.updates.size)
      assert(result.news.first.index('00280'), "Should find 00280 in news")
      assert(result.news.flatten.index('65034'), "Should find 65034 in news")
      assert(result.news.flatten.index('00277') == nil, "Should not find 00277 in news")
      assert(result.news.flatten.index('Zulassungs-Nummer') == nil, "Should not find Zulassungs-Nummer in changes")
    end

    def test_date_xls
      tbook = Spreadsheet.open(File.expand_path('data/Packungen.xls',  File.dirname(__FILE__)))
      sheet = tbook.worksheet(0)
      assert_equal(nil, sheet.row(0)[8]) # sequence_date
      assert_equal(2010, sheet.row(4).date(8).year)
      assert_equal(26, sheet.row(4).date(8).day)
      # assert_equal(26, Spreadsheet.date_cell(sheet.row(4), 8))
      assert_equal(26, Spreadsheet.date_cell(sheet.row(4), 8).day)
      assert_equal(2010, Spreadsheet.date_cell(sheet.row(4), 8).year)
    end
    
    def test_date_xlsx
      tbook = Spreadsheet.open(File.expand_path('data/Packungen_2014_small.xlsx',  File.dirname(__FILE__)))
      sheet = tbook.worksheet(0)
      # sheet = RubyXL::Parser.parse(File.expand_path(File.expand_path 'data/Packungen_2014_small.xlsx',  File.dirname(__FILE__)))[0]
      assert_equal(nil, sheet.row(0)[8]) # sequence_date
      assert_equal(2010, sheet.row(4).date(8).year)
      assert_equal(26, sheet.row(4).date(8).day)
      assert_equal(26, Spreadsheet.date_cell(sheet.row(4), 8).day)
      assert_equal(2010, Spreadsheet.date_cell(sheet.row(4), 8).year)
    end

    def test_diff_xlsx_and_xls
      @diff = SwissmedicDiff.new
      last_month = File.expand_path 'data/Packungen_2014_01.xlsx',  File.dirname(__FILE__)
      this_month = File.expand_path 'data/Packungen.xls',  File.dirname(__FILE__)
      result = @diff.diff last_month, this_month, [:atc_class, :sequence_date]
      assert_equal(7, result.news.size)
      assert_equal(2, result.updates.size)
      assert_equal(10, result.changes.size)
      assert(result.changes.flatten.index('00275'), "Should find 00275 in changes")
      assert(result.changes.flatten.index('00277'), "Should find 00277 in changes")
      assert(result.news.flatten.index('Zulassungs-Nummer') == nil, "Should not find Zulassungs-Nummer in changes")
    end
    def test_diff_xlsx_and_xlsx
      @diff = SwissmedicDiff.new
      last_month = File.expand_path 'data/Packungen_2014_small.xlsx',  File.dirname(__FILE__)
      this_month = File.expand_path 'data/Packungen_2014_small.xlsx',  File.dirname(__FILE__)
      result = @diff.diff last_month, this_month, [:atc_class, :sequence_date]
      assert_equal({}, result.changes)
      assert_equal([], result.news)
      assert_equal([], result.updates)
    end

    # This is not a unit test as it takes way too long (> 1 minute)
    # Instead it might just tell you how to test with real data
    def test_real_diff
      @diff = SwissmedicDiff.new
      last_month = File.expand_path 'data/Packungen-2013.08.16.xls',  File.dirname(__FILE__)
      this_month = File.expand_path 'data/Packungen-2013.11.04.xls',  File.dirname(__FILE__)
      result = @diff.diff last_month, this_month, [:atc_class, :sequence_date]
      assert(result.changes.flatten.index('Zulassungs-Nummer') == nil, "Should not find Zulassungs-Nummer in changes")
      assert(result.news.flatten.index('Zulassungs-Nummer') == nil, "Should not find Zulassungs-Nummer in changes")
      assert(result.news.flatten.index('00277') == nil, "Should not find 00277 in news")
    end if false

    def test_iterate
      diff = SwissmedicDiff.new
      strings = []
      diff.each_valid_row(Spreadsheet.open(@data_2013)) { |x| strings << "iksnr #{x[0]} packungs id #{x[diff.column(:ikscd)]}" }
      expected = [
        "iksnr 00277 packungs id 001",
        "iksnr 00277 packungs id 002",
        "iksnr 61338 packungs id 001",
        "iksnr 61338 packungs id 002",
        "iksnr 61367 packungs id 001",
        "iksnr 61367 packungs id 002",
        "iksnr 61367 packungs id 003",
        "iksnr 61367 packungs id 004",
        "iksnr 61367 packungs id 005",
        "iksnr 61416 packungs id 001",
        "iksnr 63164 packungs id 001",
        "iksnr 63164 packungs id 002",
        "iksnr 63164 packungs id 003",
        "iksnr 65040 packungs id 001"
      ]
      assert_equal(expected, strings)
    end

    def test_diff_pre_2013_to_2013
      result = @diff.diff(@data_2013, @data)
      assert(result.changes.flatten.index('Zulassungs-Nummer') == nil, "Should not find Zulassungs-Nummer in changes")
      assert(result.news.flatten.index('Zulassungs-Nummer') == nil, "Should not find Zulassungs-Nummer in changes")
      assert(result.news.flatten.index('00277') == nil, "Should not find 00277 in news")
      assert_equal 6, result.news.size
      expected = {
"00277"=>[:company, :sequence_date, :substances, :composition, :name_base],
 "61338"=>[:sequence_date, :company, :atc_class],
 "61367"=>
  [:sequence_date,
   :ikscat,
   :substances,
   :composition,
   :sequence,
   :replaced_package],
 "61416"=>[:sequence_date],
 "63164"=>[:new],
 "65040"=>[:new],
 "00275"=>[:delete],
 "61345"=>[:delete]
      }
      assert_equal(expected, result.changes)
      diff_string =%(+ 63164: Rivastigmin Patch Sandoz 5, Transdermales Pflaster
+ 65040: Panthoben, Salbe
- 00275: Cardio-Pulmo-Rénal Sérocytol, suppositoire
- 61345: Terbinafin-Teva 125 mg, Tabletten
> 00277: Coeur-Vaisseaux Sérocytol, suppositoire; Zulassungsinhaber (Sérolab, société anonyme), Zulassungsdatum Sequenz (2010-04-26), Wirkstoffe (globulina equina (immunisé avec coeur, endothélium vasculaire porcins)), Zusammensetzung (globulina equina (immunisé avec coeur, endothélium vasculaire porcins) 8 mg, propylenglycolum, conserv.: E 216, E 218, excipiens pro suppositorio.), Namensänderung (Coeur-Vaisseaux Sérocytol, suppositoire)
> 61338: Cefuroxim Fresenius i.v. 750 mg, Pulver zur Herstellung einer i.v. Lösung; Zulassungsdatum Sequenz (2010-03-16), Zulassungsinhaber (Fresenius Kabi (Schweiz) AG), ATC-Code (J01DC02)
> 61367: Hypericum-Mepha 250, Lactab; Zulassungsdatum Sequenz (2010-04-23), Abgabekategorie (D), Wirkstoffe (hyperici herbae extractum ethanolicum siccum quantificatum), Zusammensetzung (hyperici herbae extractum ethanolicum siccum quantificatum 250 mg corresp. hypericinum 0.25-0.75 mg, DER: 4-7:1, excipiens pro compresso obducto.), Packungs-Nummer (006 -> 005)
> 61416: Otriduo Schnupfen, Nasentropfen; Zulassungsdatum Sequenz (2010-05-12))
      assert_equal(diff_string, @diff.to_s)      
    end
    def test_diff
      result = @diff.diff(@data, @older)
      assert_equal 3, result.news.size
      assert_equal 'Cardio-Pulmo-Rénal Sérocytol, suppositoire',
                   result.news.first.at(2)
      assert_equal 2, result.updates.size
      assert_equal 'Coeur-Vaisseaux Sérocytol, suppositoire(update)',
                   result.updates.first.at(2)
      assert_equal 6, result.changes.size
      expected = {
        "00275"=>[:new],
        "00277"=>[:name_base],
        "61338"=>[:company, :atc_class],
        "61367"=>[:sequence, :replaced_package],
        "61416"=>[:new],
        "00274"=>[:delete]
      }
      assert_equal(expected, result.changes)
      assert_equal 3, result.package_deletions.size
      assert_equal 4, result.package_deletions.first.size
      iksnrs = result.package_deletions.collect { |row| row.at(0) }.sort
      ikscds = result.package_deletions.collect { |row| row.at(2) }.sort
      assert_equal ["00274", "61367", "61367"], iksnrs
      assert_equal ["001", "002", "005"], ikscds
      assert_equal 1, result.sequence_deletions.size
      assert_equal ["00274", "01"], result.sequence_deletions.at(0)
      assert_equal 1, result.registration_deletions.size
      assert_equal ["00274"], result.registration_deletions.at(0)
      assert_equal 1, result.replacements.size
      assert_equal '005', result.replacements.values.first
    end
    def test_diff_error_column
      assert_raises(RuntimeError) { 
        @diff.diff(@data_error_column, @older)
      }
    end

    # if row.size < COLUMNS.size/2
    # as per december 2013 does no longer raise an error, but outputs the problematic line
    def test_diff_error_missing_case1
      @diff.diff(@data_error_missing_case1, @older)
    end

    # if row.select{|val| val==nil}.size > COLUMNS.size/2
    # as per december 2013 does no longer raise an error, but outputs the problematic line
    def test_diff_error_missing_case2
      @diff.diff(@data_error_missing_case2, @older)
    end
    def test_diff__ignore
      ignore = [:company, :atc_class]
      result = @diff.diff(@data, @older, ignore)
      assert_equal 3, result.news.size
      assert_equal 'Cardio-Pulmo-Rénal Sérocytol, suppositoire',
                   result.news.first.at(2)
      assert_equal 1, result.updates.size
      assert_equal 'Coeur-Vaisseaux Sérocytol, suppositoire(update)',
                   result.updates.first.at(2)
      assert_equal 5, result.changes.size
      expected = {
        "00275"=>[:new],
        "00277"=>[:name_base],
        "61367"=>[:sequence, :replaced_package],
        "61416"=>[:new],
        "00274"=>[:delete]
      }
      assert_equal(expected, result.changes)
      assert_equal 3, result.package_deletions.size
      assert_equal 4, result.package_deletions.first.size
      iksnrs = result.package_deletions.collect { |row| row.at(0) }.sort
      ikscds = result.package_deletions.collect { |row| row.at(2) }.sort
      assert_equal ["00274", "61367", "61367"], iksnrs
      assert_equal ["001", "002", "005"], ikscds
      assert_equal 1, result.sequence_deletions.size
      assert_equal ["00274", "01"], result.sequence_deletions.at(0)
      assert_equal 1, result.registration_deletions.size
      assert_equal ["00274"], result.registration_deletions.at(0)
      assert_equal 1, result.replacements.size
      assert_equal '005', result.replacements.values.first
    end
    def test_to_s
      @diff.to_s
      @diff.diff(@data, @older)
      assert_equal <<-EOS.strip, @diff.to_s
+ 00275: Cardio-Pulmo-Rénal Sérocytol, suppositoire
+ 61416: Otriduo Schnupfen, Nasentropfen
- 00274: Cardio-Pulmo-Rénal Sérocytol, suppositoire
> 00277: Coeur-Vaisseaux Sérocytol, suppositoire; Namensänderung (Coeur-Vaisseaux Sérocytol, suppositoire)
> 61338: Cefuroxim Fresenius i.v. 750 mg, Pulver zur Herstellung einer i.v. Lösung; Zulassungsinhaber (Fresenius Kabi (Schweiz) AG), ATC-Code (J01DC02)
> 61367: Hypericum-Mepha 250, Lactab; Packungs-Nummer (005 -> 006)
      EOS
      assert_equal <<-EOS.strip, @diff.to_s(:name)
- 00274: Cardio-Pulmo-Rénal Sérocytol, suppositoire
+ 00275: Cardio-Pulmo-Rénal Sérocytol, suppositoire
> 61338: Cefuroxim Fresenius i.v. 750 mg, Pulver zur Herstellung einer i.v. Lösung; Zulassungsinhaber (Fresenius Kabi (Schweiz) AG), ATC-Code (J01DC02)
> 00277: Coeur-Vaisseaux Sérocytol, suppositoire; Namensänderung (Coeur-Vaisseaux Sérocytol, suppositoire)
> 61367: Hypericum-Mepha 250, Lactab; Packungs-Nummer (005 -> 006)
+ 61416: Otriduo Schnupfen, Nasentropfen
      EOS
      assert_equal <<-EOS.strip, @diff.to_s(:registration)
- 00274: Cardio-Pulmo-Rénal Sérocytol, suppositoire
+ 00275: Cardio-Pulmo-Rénal Sérocytol, suppositoire
> 00277: Coeur-Vaisseaux Sérocytol, suppositoire; Namensänderung (Coeur-Vaisseaux Sérocytol, suppositoire)
> 61338: Cefuroxim Fresenius i.v. 750 mg, Pulver zur Herstellung einer i.v. Lösung; Zulassungsinhaber (Fresenius Kabi (Schweiz) AG), ATC-Code (J01DC02)
> 61367: Hypericum-Mepha 250, Lactab; Packungs-Nummer (005 -> 006)
+ 61416: Otriduo Schnupfen, Nasentropfen
      EOS
    end
  end
end
