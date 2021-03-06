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
      @january_2014 = File.expand_path 'data/Packungen-2014.01.01.xlsx',  File.dirname(__FILE__)
      @february_2014 = File.expand_path 'data/Packungen-2014.02.01.xlsx',  File.dirname(__FILE__)
    end

    def test_diff_new_format_july_2015
      @diff = SwissmedicDiff.new
      last_month = File.expand_path 'data/Packungen-2015.06.04.xlsx',  File.dirname(__FILE__)
      this_month = File.expand_path 'data/Packungen-2015.07.02.xlsx',  File.dirname(__FILE__)
      result = @diff.diff this_month, last_month, [:atc_class, :sequence_date]
      assert(result.changes.flatten.index('Zulassungs-Nummer') == nil, "Should not find Zulassungs-Nummer in changes")
      assert_equal(2, result.news.size)
      assert_equal(4, result.changes.size)
      assert_equal(4, result.updates.size)
      assert_equal(['65838', nil], result.news.collect{|x| x[0] if x[0] == '65838'})
      assert_equal({"00277"=>[:name_base, :expiry_date], "00279"=>[:expiry_date], "65838"=>[:new], "15219"=>[:new]}, result.changes)
    end

    def test_diff_changes
      @diff = SwissmedicDiff.new
      last_month = File.expand_path 'data/Packungen-2015.06.04.xlsx',  File.dirname(__FILE__)
      this_month = File.expand_path 'data/Packungen-2015.07.02.xlsx',  File.dirname(__FILE__)
      expected = {
          "00277"=>[:name_base, :expiry_date],
          "00279"=>[:expiry_date],
          "65838"=>[:new],
          "15219"=>[:new]
      }
      result = @diff.diff this_month, last_month
      assert_equal(expected, result.changes)
    end


    def test_diff_changes_february_2019
      @diff = SwissmedicDiff.new
      last_month = File.expand_path 'data/Packungen-2015.07.02.xlsx',  File.dirname(__FILE__)
      this_month = File.expand_path 'data/Packungen-2019.03.06.xlsx',  File.dirname(__FILE__)
      expected =  {"00277"=>[:name_base, :expiry_date, :production_science],
        "15219"=>[:expiry_date, :indication_registration, :indication_sequence, :sequence],
        "16105"=>[:new],
        "16598"=>[:new],
        "28486"=>[:new],
        "30015"=>[:new],
        "31644"=>[:new],
        "32475"=>[:new],
        "35366"=>[:new],
        "43454"=>[:new],
        "44625"=>[:new],
        "45882"=>[:new],
        "53290"=>[:new],
        "53662"=>[:new],
        "54015"=>[:new],
        "54534"=>[:new],
        "55558"=>[:new],
        "66297"=>[:new],
        "55594"=>[:new],
        "55674"=>[:new],
        "56352"=>[:new],
        "58943"=>[:new],
        "59267"=>[:new],
        "61186"=>[:new],
        "62069"=>[:new],
        "62132"=>[:new],
        "65856"=>[:new],
        "65857"=>[:new],
        "58734"=>[:new],
        "55561"=>[:new],
        "65160"=>[:new],
        "58158"=>[:new],
        "44447"=>[:new],
        "39252"=>[:new],
        "00278"=>[:delete],
        "00279"=>[:delete],
        "65837"=>[:delete],
        "65838"=>[:delete]
                }
      result = @diff.diff this_month, last_month
      assert_equal(expected, result.changes)
    end

    def test_diff_wrong_header
      @diff = SwissmedicDiff.new
      last_month = File.expand_path 'data/Packungen-2015.06.04.xlsx',  File.dirname(__FILE__)
      this_month = File.expand_path 'data/Packungen-wrong-header.xlsx',  File.dirname(__FILE__)
      assert_raises(RuntimeError) { @diff.diff this_month, last_month, [:atc_class, :sequence_date]}
    end


    def test_diff_xlsx_and_xlsx
      result = @diff.diff @february_2014, @january_2014, [:atc_class, :sequence_date]
      assert_equal 4, result.news.size
      expected = {
          "00277"=>[:name_base, :expiry_date],
          "65040"=>[:sequence, :replaced_package],
          "60125"=>[:new],
          "61367"=>[:new],
          "00274"=>[:delete]
      }
      assert_equal(expected, result.changes)
      assert_equal 1, result.updates.size
      assert_equal 5, result.changes.size
      assert_equal 3, result.package_deletions.size
      assert_equal 4, result.package_deletions.first.size
      iksnrs = result.package_deletions.collect { |row| row.at(0) }.sort
      ikscds = result.package_deletions.collect { |row| row.at(2) }.sort
      assert_equal ["00274", "00274", "65040"], iksnrs
      assert_equal ["001", "001", "002"], ikscds
      assert_equal 1, result.sequence_deletions.size
      assert_equal ["00274", "01"], result.sequence_deletions.at(0)
      assert_equal 1, result.registration_deletions.size
      assert_equal ["00274"], result.registration_deletions.at(0)
      assert_equal 1, result.replacements.size
      assert_equal '001', result.replacements.values.first

      assert_equal 'Panthoben, Salbe', result.news.first[2].value
      assert_equal 'Coeur-Vaisseaux Sérocytol, Namensänderung', result.updates.first[2].value
    end

    def test_diff_error_column
      res = @diff.diff(@february_2014, @january_2014)
      assert_equal(OpenStruct, res.class)
    end

    def test_diff__ignore
      ignore = [:company, :name_base, :expiry_date, :indication_sequence]
      result = @diff.diff(@february_2014, @january_2014, ignore)
      expected = {
        "00278"=>[:atc_class],
        "00279"=>[:atc_class],
        "65040"=>[:sequence, :replaced_package],
        "60125"=>[:new],
        "61367"=>[:new],
        "00274"=>[:delete]
      }
      assert_equal(expected, result.changes)
      assert_equal 4, result.news.size
      assert_equal 3, result.updates.size
      assert_equal 6, result.changes.size
      assert_equal 3, result.package_deletions.size
    end
    def test_to_s
      @diff.to_s
      @diff.diff(@february_2014, @january_2014)
      assert_equal <<-EOS.strip, @diff.to_s
+ 60125: Otriduo Schnupfen, Dosierspray
+ 61367: Hypericum-Mepha 250, Lactab
- 00274: Cardio-Pulmo-Rénal Sérocytol, suppositoire
> 00277: Coeur-Vaisseaux Sérocytol, Namensänderung; Namensänderung (Coeur-Vaisseaux Sérocytol, Namensänderung), Ablaufdatum der Zulassung (25.04.2020)
> 00278: Colon Sérocytol, suppositoire; ATC-Code (J06AA)
> 00279: Conjonctif Sérocytol, suppositoire; ATC-Code (D03AX04)
> 65040: Panthoben, Salbe; Packungs-Nummer (001 -> 003)
      EOS
      assert_equal <<-EOS.strip, @diff.to_s(:name)
- 00274: Cardio-Pulmo-Rénal Sérocytol, suppositoire
> 00277: Coeur-Vaisseaux Sérocytol, Namensänderung; Namensänderung (Coeur-Vaisseaux Sérocytol, Namensänderung), Ablaufdatum der Zulassung (25.04.2020)
> 00278: Colon Sérocytol, suppositoire; ATC-Code (J06AA)
> 00279: Conjonctif Sérocytol, suppositoire; ATC-Code (D03AX04)
+ 61367: Hypericum-Mepha 250, Lactab
+ 60125: Otriduo Schnupfen, Dosierspray
> 65040: Panthoben, Salbe; Packungs-Nummer (001 -> 003)
    EOS
      assert_equal <<-EOS.strip, @diff.to_s(:registration)
- 00274: Cardio-Pulmo-Rénal Sérocytol, suppositoire
> 00277: Coeur-Vaisseaux Sérocytol, Namensänderung; Namensänderung (Coeur-Vaisseaux Sérocytol, Namensänderung), Ablaufdatum der Zulassung (25.04.2020)
> 00278: Colon Sérocytol, suppositoire; ATC-Code (J06AA)
> 00279: Conjonctif Sérocytol, suppositoire; ATC-Code (D03AX04)
+ 60125: Otriduo Schnupfen, Dosierspray
+ 61367: Hypericum-Mepha 250, Lactab
> 65040: Panthoben, Salbe; Packungs-Nummer (001 -> 003)
      EOS
    end
  end
end
