#!/usr/bin/env ruby
# -*- encoding: utf-8 -*-
# SwissmedicPluginTest -- oddb.org -- 18.03.2008 -- hwyss@ywesee.com

$: << File.expand_path("../lib", File.dirname(__FILE__))

require 'test/unit'
require 'swissmedic-diff'

module ODDB
  class SwissmedicPluginTest < Test::Unit::TestCase
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
    def test_diff_pre_2013_to_2013
      result = @diff.diff(@data_2013, @data)
      assert(result.changes.flatten.index('Zulassungs-Nummer') == nil, "Should not find Zulassungs-Nummer in difference")
      assert_equal 6, result.news.size
      expected = {
"00277"=>
  [:company, :sequence_date, :ikscd, :substances, :composition, :name_base],
 "61338"=>[:sequence_date, :ikscd, :company, :atc_class],
 "61367"=>
  [:sequence_date,
   :ikscd,
   :ikscat,
   :substances,
   :composition,
   :sequence,
   :replaced_package],
 "61416"=>[:sequence_date, :ikscd],
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
> 00277: Coeur-Vaisseaux Sérocytol, suppositoire; Zulassungsinhaber (Sérolab, société anonyme), Zulassungsdatum Sequenz (2010-04-26), ikscd (1), Wirkstoffe (globulina equina (immunisé avec coeur, endothélium vasculaire porcins)), Zusammensetzung (globulina equina (immunisé avec coeur, endothélium vasculaire porcins) 8 mg, propylenglycolum, conserv.: E 216, E 218, excipiens pro suppositorio.), Namensänderung (Coeur-Vaisseaux Sérocytol, suppositoire)
> 61338: Cefuroxim Fresenius i.v. 750 mg, Pulver zur Herstellung einer i.v. Lösung; Zulassungsdatum Sequenz (2010-03-16), ikscd (1), Zulassungsinhaber (Fresenius Kabi (Schweiz) AG), ATC-Code (J01DC02)
> 61367: Hypericum-Mepha 250, Lactab; Zulassungsdatum Sequenz (2010-04-23), ikscd (1), Abgabekategorie (D), Wirkstoffe (hyperici herbae extractum ethanolicum siccum quantificatum), Zusammensetzung (hyperici herbae extractum ethanolicum siccum quantificatum 250 mg corresp. hypericinum 0.25-0.75 mg, DER: 4-7:1, excipiens pro compresso obducto.), Packungs-Nummer (006 -> 005)
> 61416: Otriduo Schnupfen, Nasentropfen; Zulassungsdatum Sequenz (2010-05-12), ikscd (1))
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
      assert_raise(RuntimeError) { 
        @diff.diff(@data_error_column, @older)
      }
    end

    # if row.size < COLUMNS.size/2
    def test_diff_error_missing_case1
      assert_raise(RuntimeError) {
        @diff.diff(@data_error_missing_case1, @older)
      }
    end

    # if row.select{|val| val==nil}.size > COLUMNS.size/2
    def test_diff_error_missing_case2
      assert_raise(RuntimeError) {
        @diff.diff(@data_error_missing_case2, @older)
      }
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
      assert_nothing_raised {
        @diff.to_s
      }
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
