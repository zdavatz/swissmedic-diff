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
      @workbook = Spreadsheet::ParseExcel.parse(@data)
    end
    def test_diff
      result = @diff.diff(@data, @older)
      assert_equal 3, result.news.size
      assert_equal 'Osanit, homöopathische Kügelchen',
                   result.news.first.at(2).to_s('latin1')
      assert_equal 7, result.updates.size
      assert_equal 'Weleda Schnupfencrème, anthroposophisches Heilmittel',
                   result.updates.first.at(2).to_s('latin1')
      assert_equal 6, result.changes.size
      expected = {
        "09232" => [:name_base],
        "10368" => [:delete],
        "10999" => [:new],
        "25144" => [:sequence, :replaced_package],
        "57678" => [:company, :index_therapeuticus, :atc_class, :expiry_date, :ikscat],
        "57699" => [:new],
      }
      assert_equal(expected, result.changes)
      assert_equal 3, result.package_deletions.size
      assert_equal 4, result.package_deletions.first.size
      iksnrs = result.package_deletions.collect { |row| row.at(0) }.sort
      ikscds = result.package_deletions.collect { |row| row.at(2) }.sort
      assert_equal ['10368', '13689', '25144'], iksnrs
      assert_equal ['024', '031', '049'], ikscds
      assert_equal 1, result.sequence_deletions.size
      assert_equal ['10368', '01'], result.sequence_deletions.at(0)
      assert_equal 1, result.registration_deletions.size
      assert_equal ['10368'], result.registration_deletions.at(0)
      assert_equal 1, result.replacements.size
      assert_equal '031', result.replacements.values.first
    end
    def test_diff__ignore
      ignore = [:company, :index_therapeuticus, :expiry_date, :ikscat, :atc_class]
      result = @diff.diff(@data, @older, ignore)
      assert_equal 3, result.news.size
      assert_equal 'Osanit, homöopathische Kügelchen',
                   result.news.first.at(2).to_s('latin1')
      assert_equal 1, result.updates.size
      assert_equal 'Weleda Schnupfencrème, anthroposophisches Heilmittel',
                   result.updates.first.at(2).to_s('latin1')
      assert_equal 5, result.changes.size
      expected = {
        "09232" => [:name_base],
        "10368" => [:delete],
        "10999" => [:new],
        "25144" => [:sequence, :replaced_package],
        "57699" => [:new],
      }
      assert_equal(expected, result.changes)
      assert_equal 3, result.package_deletions.size
      assert_equal 4, result.package_deletions.first.size
      iksnrs = result.package_deletions.collect { |row| row.at(0) }.sort
      ikscds = result.package_deletions.collect { |row| row.at(2) }.sort
      assert_equal ['10368', '13689', '25144'], iksnrs
      assert_equal ['024', '031', '049'], ikscds
      assert_equal 1, result.sequence_deletions.size
      assert_equal ['10368', '01'], result.sequence_deletions.at(0)
      assert_equal 1, result.registration_deletions.size
      assert_equal ['10368'], result.registration_deletions.at(0)
      assert_equal 1, result.replacements.size
      assert_equal '031', result.replacements.values.first
    end
    def test_to_s
      assert_nothing_raised {
        @diff.to_s
      }
      result = @diff.diff(@data, @older)
      assert_equal <<-EOS.strip, @diff.to_s
+ 10999: Osanit, homöopathische Kügelchen
+ 57699: Pyrazinamide Labatec, comprimés
- 10368: Alcacyl, Tabletten
> 09232: Weleda Schnupfencrème, anthroposophisches Heilmittel; Namensänderung (Weleda Schnupfencrème, anthroposophisches Heilmittel)
> 25144: Panadol, Filmtabletten; Packungs-Nummer (031 -> 048)
> 57678: Amlodipin-besyl-Mepha 5, Tabletten; Zulassungsinhaber (Vifor SA), Index Therapeuticus (07.10.5.), ATC-Code (D11AF), Ablaufdatum der Zulassung (10.05.2017), Abgabekategorie (A)
      EOS
      assert_equal <<-EOS.strip, @diff.to_s(:name)
- 10368: Alcacyl, Tabletten
> 57678: Amlodipin-besyl-Mepha 5, Tabletten; Zulassungsinhaber (Vifor SA), Index Therapeuticus (07.10.5.), ATC-Code (D11AF), Ablaufdatum der Zulassung (10.05.2017), Abgabekategorie (A)
+ 10999: Osanit, homöopathische Kügelchen
> 25144: Panadol, Filmtabletten; Packungs-Nummer (031 -> 048)
+ 57699: Pyrazinamide Labatec, comprimés
> 09232: Weleda Schnupfencrème, anthroposophisches Heilmittel; Namensänderung (Weleda Schnupfencrème, anthroposophisches Heilmittel)
      EOS
      assert_equal <<-EOS.strip, @diff.to_s(:registration)
> 09232: Weleda Schnupfencrème, anthroposophisches Heilmittel; Namensänderung (Weleda Schnupfencrème, anthroposophisches Heilmittel)
- 10368: Alcacyl, Tabletten
+ 10999: Osanit, homöopathische Kügelchen
> 25144: Panadol, Filmtabletten; Packungs-Nummer (031 -> 048)
> 57678: Amlodipin-besyl-Mepha 5, Tabletten; Zulassungsinhaber (Vifor SA), Index Therapeuticus (07.10.5.), ATC-Code (D11AF), Ablaufdatum der Zulassung (10.05.2017), Abgabekategorie (A)
+ 57699: Pyrazinamide Labatec, comprimés
      EOS
    end
  end
end
