require 'rubygems'
if ENV['VERSION']
  gem 'activerecord', ENV['VERSION']
  gem 'activesupport', ENV['VERSION']
end
$LOAD_PATH << 'lib'
require 'bitfields'
require 'timeout'

require 'active_record'
puts "Using ActiveRecord #{ActiveRecord::VERSION::STRING}"

require File.expand_path('../database', __FILE__)
