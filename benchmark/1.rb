def benchmark
  t = Time.now.to_f
  yield
  Time.now.to_f - t
end

def create(bit_counts, count)
  count.times do |i|
    columns = bit_counts.map do |bits_count|
      ["bit_#{bits_count}", rand(2**(bits_count-1))]
    end
    User.create!(Hash[columns])
  end
end

def connect
  ActiveRecord::Base.establish_connection(
    :adapter => "sqlite3",
    :database => ":memory:"
  )
end

def create_model_table(bit_counts)
  ActiveRecord::Schema.define(:version => 2) do
    create_table :users do |t|
      bit_counts.each do |bit_count|
        t.integer "bit_#{bit_count}", :default => 0, :null => false
      end
    end

    bit_counts.each do |bit_count|
      add_index :users, "bit_#{bit_count}"
    end
  end
end

def create_model_fields(bit_counts)
  puts "creating model"
  User.class_eval do
    include Bitfields

    # this takes long for 15/20 bits, maybe needs to be optimized..
    bit_counts.each do |bits_count|
      bits = {}
      0.upto(bits_count-1) do |bit|
        bits[2**bit] = "bit_#{bits_count}_#{bit}"
      end

      bitfield "bit_#{bits_count}", bits
    end
  end
end

def test_speed(bit_counts, query_mode)
  bit_counts.each do |bit_count|
    sql = User.bitfield_sql({"bit_#{bit_count}_1" => true}, :query_mode => query_mode)
#    puts sql
    time = benchmark do
      User.count sql
    end
    puts "#{bit_count} -> #{time}"
  end
end

bit_counts = [2,4,6,8,10,12,14,16]
tests = [1_000, 10_000, 100_000, 1_000_000, 2_000_000]

$LOAD_PATH.unshift File.expand_path('lib')
require 'rubygems'
require 'active_record'
require 'bitfields'

connect
puts 'xxx'
create_model_table(bit_counts)
class User < ActiveRecord::Base
end
create_model_fields(bit_counts)

puts "creating test data"
last = 0
tests.each do |count|
  create(bit_counts, count-last)
  last += count

  puts "testing with #{count} records -- bit_operator"
  test_speed(bit_counts, :bit_operator)

  puts "testing with #{count} records -- in_list"
  test_speed(bit_counts, :in_list)
end