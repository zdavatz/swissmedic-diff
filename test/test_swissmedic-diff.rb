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

    def test_diff_changes_january_2026
      start_time = Time.now
      @diff = SwissmedicDiff.new
      last_month = File.expand_path "data/Packungen-2025.12.15.xlsx", File.dirname(__FILE__)
      this_month = File.expand_path "data/Packungen-2026.01.08.xlsx", File.dirname(__FILE__)
      result = @diff.diff this_month, last_month
      duration = (Time.now - start_time).to_i
      puts "Took #{duration} seconds"
      assert_equal(487, result.updates.size)
      assert_equal(336, result.changes.size)
      assert_equal(148, result.news.size)
      assert_equal(7, result.replacements.size)
      assert_equal(107, result.package_deletions.size)

      assert_equal(["16105", "01", "Hirudoid, Creme", "Medinova AG", "Synthetika", "02.08.2.", "C05BA01", Date.new(1951, 9, 1), Date.new(1951, 9, 1), "unbegrenzt", "001", "14", "g", "D", "D", "D", "heparinoidum (chondroitini polysulfas)", "heparinoidum (chondroitini polysulfas) 3 mg, corresp. 250 U., glycerolum (85 per centum), acidum stearicum, alcoholes adipis lanae, alcohol cetylicus et stearylicus 31.375 mg, vaselinum album, alcohol myristylicus, alcohol isopropylicus, kalii hydroxidum, E 218 1.6 mg, thymolum, propylis parahydroxybenzoas 0.4 mg, aqua purificata, ad unguentum pro 1 g.", "X", "Venenmittel für den äusserlichen Gebrauch", nil, nil, nil, nil, 0], result.news.first)

      assert_equal([["55249", "01", "Bronchosan Husten, Tropfen zum Einnehmen", "A.Vogel AG", "Phytoarzneimittel", "03.02.0.", "R05CA10", Date.new(2000, 10, 18), Date.new(2000, 10, 18), "unbegrenzt", "001", "50", "ml", "D", "D", "D", "hederae helicis herbae recentis tinctura (Hedera helix L., herba), thymi herbae recentis tinctura (Thymus vulgaris L., herba), liquiritiae radicis tinctura (Glycyrrhiza glabra L., radix)", "hederae helicis herbae recentis tinctura (Hedera helix L., herba) 376.1 mg, ratio: 1:5.6, Auszugsmittel ethanolum 50.6% (V/V), thymi herbae recentis tinctura (Thymus vulgaris L., herba) 329.1 mg, ratio: 1:7.9, Auszugsmittel ethanolum 50.6% (V/V), liquiritiae radicis tinctura (Glycyrrhiza glabra L., radix) 233.9 mg, ratio: 1:10, Auszugsmittel ethanolum 50.6% (V/V), anisi stellati aetheroleum, eucalypti aetheroleum, ad solutionem pro 1 ml, corresp. ethanolum 51 % V/V.", "X", "Bei Erkältungshusten", nil, nil, nil, nil, 0], "052"], result.replacements.first)

      assert_equal(["00613", [:expiry_date]], result.changes.first)
      assert_equal({target: "Packungen-2026.01.08.xlsx 3198082 bytes", latest: "Packungen-2025.12.15.xlsx 3218271 bytes",  news: 148, updates: 487, changes: 336, newest_rows: 6305, replacements: 147, package_deletions: 107, sequence_deletions: 60, registration_deletions: 47}, SwissmedicDiff.stat)
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
      assert_equal({target: "Packungen-2025.07.01.xlsx 245310 bytes", latest: "Packungen-2019.03.06.xlsx 347989 bytes", news: 41, updates: 2, changes: 40, newest_rows: 40, replacements: 9, package_deletions: 39, sequence_deletions: 34, registration_deletions: 32}, SwissmedicDiff.stat)
    end
  end
end
