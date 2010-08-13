require "rubygems"
require "rake"

spec = Gem::Specification.new do |s|
   s.name        = "swissmedic-diff"
   s.version     = "0.1.3"
   s.summary     = "Find out what Products have changed on the swiss healthcare market"
   s.description = "Compares two Excel Documents provided by Swissmedic and displays the salient differences"
   s.author      = "Hannes Wyss, Masaomi Hatakeyama"
   s.email       = "hwyss@ywesee.com, mhatakeyama@ywesee.com"
   s.platform    = Gem::Platform::RUBY
   s.files       = FileList['lib/*.rb', 'bin/*', '[A-Z]*', 'test/*', 
                            'test/data/*.xls'].to_a
   s.test_file   = "test/test_swissmedic-diff.rb"
   s.executables << 'swissmedic-diff'
   s.add_dependency('parseexcel')
   s.homepage	 = "http://scm.ywesee.com/swissmedic-diff/.git"
end

if $0 == __FILE__
   Gem.manage_gems
   Gem::Builder.new(spec).build
end
