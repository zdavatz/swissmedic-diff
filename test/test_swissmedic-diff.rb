#!/usr/bin/env ruby

# SwissmedicPluginTest -- oddb.org -- 18.03.2008 -- hwyss@ywesee.com

$: << File.expand_path("../lib", File.dirname(__FILE__))

require "minitest/autorun"
require "swissmedic-diff"
require "pp"

module ODDB
  class SwissmedicPluginTest < Minitest::Test
    def setup
      @diff = SwissmedicDiff.new
    end

    def test_diff_changes_february_2019
      @diff = SwissmedicDiff.new
      last_month = File.expand_path "data/Packungen-2019.03.06.xlsx", File.dirname(__FILE__)
      this_month = File.expand_path "data/Packungen-2025.07.01.xlsx", File.dirname(__FILE__)
      expected = {"00450" => [:new],
                  "00278" => [:new],
                  "00279" => [:new],
                  "44447" => [:name_base, :production_science, :expiry_date, :substances, :composition],
                  "65837" => [:new],
                  "65838" => [:new],
                  "15219" => [:expiry_date],
                  "00000" => [:new],
                  "00277" => [:delete],
                  "16105" => [:delete],
                  "16598" => [:delete],
                  "28486" => [:delete],
                  "30015" => [:delete],
                  "31644" => [:delete],
                  "32475" => [:delete],
                  "35366" => [:delete],
                  "43454" => [:delete],
                  "44625" => [:delete],
                  "45882" => [:delete],
                  "53290" => [:delete],
                  "53662" => [:delete],
                  "54015" => [:delete],
                  "54534" => [:delete],
                  "55558" => [:delete],
                  "66297" => [:delete],
                  "55594" => [:delete],
                  "55674" => [:delete],
                  "56352" => [:delete],
                  "58943" => [:delete],
                  "59267" => [:delete],
                  "61186" => [:delete],
                  "62069" => [:delete],
                  "62132" => [:delete],
                  "65856" => [:delete],
                  "65857" => [:delete],
                  "58734" => [:delete],
                  "55561" => [:delete],
                  "65160" => [:delete],
                  "58158" => [:delete],
                  "39252" => [:delete]}

      result = @diff.diff this_month, last_month
      assert_equal(expected, result.changes)
    end
  end
end
