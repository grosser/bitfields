require 'rubygems'
if ENV['VERSION']
  gem 'activerecord', ENV['VERSION']
  gem 'activesupport', ENV['VERSION']
end
$LOAD_PATH << 'lib'
require 'bitfields'

require 'active_record'
puts "Using ActiveRecord #{ActiveRecord::VERSION::STRING}"

require 'spec/database'
