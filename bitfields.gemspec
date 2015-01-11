name = "bitfields"
require "./lib/#{name}/version"

Gem::Specification.new name, Bitfields::VERSION do |s|
  s.summary = "Save migrations and columns by storing multiple booleans in a single integer"
  s.authors = ["Michael Grosser"]
  s.email = "michael@grosser.it"
  s.homepage = "https://github.com/grosser/#{name}"
  s.files = Dir["{lib/**/*.rb,Readme.md}"]
  s.license = 'MIT'
  s.add_development_dependency 'wwtd'
  s.add_development_dependency 'activerecord'
  s.add_development_dependency 'sqlite3'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'rspec', '~>3'
  s.add_development_dependency 'bump'
end
