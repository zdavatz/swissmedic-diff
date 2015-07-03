source "https://rubygems.org"

gemspec

group :development do
  gem 'rake',                 :platforms => :ruby_18
end

group :debugger do
  if RUBY_VERSION.match(/^1/)
    gem 'pry-debugger'
  else
    gem 'pry-byebug'
    gem 'pry-doc'
  end
end unless RUBY_VERSION =~ /^1\.8/
