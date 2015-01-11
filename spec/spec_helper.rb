require 'bundler/setup'
require 'bitfields/rspec'
require 'bitfields'
require 'timeout'

require 'active_record'
puts "Using ActiveRecord #{ActiveRecord::VERSION::STRING}"

require_relative 'database'

RSpec.configure do |config|
  config.expect_with(:rspec) { |c| c.syntax = :should }
  config.mock_with(:rspec) { |c| c.syntax = :should }
end
