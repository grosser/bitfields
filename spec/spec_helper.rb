require 'rubygems'
if ENV['VERSION']
  gem 'activerecord', ENV['VERSION']
  gem 'activesupport', ENV['VERSION']
end
$LOAD_PATH << 'lib'
require 'bitfields/rspec'
require 'bitfields'
require 'timeout'

require 'active_record'
puts "Using ActiveRecord #{ActiveRecord::VERSION::STRING}"

require File.expand_path('../database', __FILE__)

RSpec.configure do |config|
  config.expect_with(:rspec) { |c| c.syntax = :should }
  config.mock_with(:rspec) { |c| c.syntax = :should }
end
