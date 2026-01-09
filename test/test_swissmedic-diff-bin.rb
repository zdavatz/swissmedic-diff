#!/usr/bin/env ruby

# SwissmedicPluginTest -- oddb.org -- 18.03.2008 -- hwyss@ywesee.com

$: << File.expand_path("../lib", File.dirname(__FILE__))

require "minitest/autorun"
require "tempfile"
require "open3"

module ODDB
  class SwissmedicPluginBinTest < Minitest::Test
    def test_running_binary
      cmd = "bundle exec ruby bin/swissmedic-diff test/data/Packungen-2025.07.01.xlsx test/data/Packungen-2019.03.06.xlsx"
      stdout, stderr, status = Open3.capture3(cmd)
      puts "Output: #{stdout}"
      puts "Error: #{stderr}" if stderr
      puts "Exit Status: #{status.exitstatus}"
      assert_equal(0, status.exitstatus)
      lines = stdout.split("\n")
      assert_equal(40, lines.size)
      found = lines.find { |line| line.eql?("+ 16105: Hirudoid, Creme") }
      assert(found, "Must find + 16105: Hirudoid, Creme")
      found = lines.find { |line| line.eql?("> 44447: Lopresor Retard 200, Divitabs; Namensänderung (Lopresor Retard 200, Divitabs), Heilmittelcode (Synthetika human), Ablaufdatum der Zulassung (22.12.2019), Wirkstoffe (metoprololi tartras (2:1)), Zusammensetzung (metoprololi tartras (2:1) 200 mg, excipiens pro compresso obducto.)") }
      assert(found, "must found Ablaufdatum")
    end
  end
end
