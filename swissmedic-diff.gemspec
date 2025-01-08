require File.expand_path('../lib/version', __FILE__)

spec = Gem::Specification.new do |s|
   s.name        = "swissmedic-diff"
   s.version     = SwissmedicDiff::VERSION
   s.summary     = "Find out what Products have changed on the swiss healthcare market"
   s.description = "Compares two Excel Documents provided by Swissmedic and displays the salient differences"
   s.author      = "Hannes Wyss, Masaomi Hatakeyama"
   s.email       = "hwyss@ywesee.com, mhatakeyama@ywesee.com"
   s.platform    = Gem::Platform::RUBY
   s.files       = Dir.glob('lib/*.rb') +
                   Dir.glob('bin/*') +
                   Dir.glob('[A-Z]*') +
                   Dir.glob('test/*') +
                   Dir.glob('test/data/*.xls')
   s.test_file   = "test/test_swissmedic-diff.rb"
   s.executables << 'swissmedic-diff'
   s.add_dependency('rubyXL', '>= 3.3.1')
   s.add_dependency('nokogiri')
   s.add_dependency('rubyzip')
   s.add_dependency('spreadsheet')
   s.add_dependency('logger')
   s.add_dependency('ostruct')
   s.add_development_dependency "rake"
   s.add_development_dependency "minitest"
   s.add_development_dependency "minitest-reporters"

   s.homepage	 = "https://github.com/zdavatz/swissmedic-diff"
   s.metadata["changelog_uri"] = s.homepage + "/blob/master/History.md"

end
