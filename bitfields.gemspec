$LOAD_PATH.unshift File.expand_path('../lib', __FILE__)
name = "bitfields"
require "#{name}/version"

Gem::Specification.new name, Bitfields::VERSION do |s|
  s.summary = "Save migrations and columns by storing multiple booleans in a single integer"
  s.authors = ["Michael Grosser"]
  s.email = "michael@grosser.it"
  s.homepage = "http://github.com/grosser/#{name}"
  s.files = `git ls-files`.split("\n")
  s.license = 'MIT'
end
