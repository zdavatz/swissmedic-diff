#!/usr/bin/env ruby
# SwissmedicPluginTest -- oddb.org -- 18.03.2008 -- hwyss@ywesee.com

$: << File.expand_path("../lib", File.dirname(__FILE__))

require 'test/unit'
require 'flexmock'
require 'swissmedic-diff'

module ODDB
  class SwissmedicPluginTest < Test::Unit::TestCase
    include FlexMock::TestCase
    def setup
      @diff = SwissmedicDiff.new
      @data = File.expand_path 'data/Packungen.xls',
                               File.dirname(__FILE__)
      @older = File.expand_path 'data/Packungen.older.xls',
                                File.dirname(__FILE__)
      @workbook = Spreadsheet.open(@data)
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
      result = @diff.diff(@data, @older)
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
