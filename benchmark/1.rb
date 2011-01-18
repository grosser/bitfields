bit_counts = [2,3,4,5,6,7,8,9,10,11,12,13,14]
record_counts = (1..20).to_a.map{|i| i * 50_000 }
use_index = true
database = ARGV[0]

puts "running#{' with index' if use_index} on #{database}"

$LOAD_PATH.unshift File.expand_path('lib')
require 'rubygems'
gem 'gchartrb'
require 'google_chart'
require 'active_record'
require 'bitfields'

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

def connect(db)
  if db == 'mysql'
    puts 'using mysql'
    ActiveRecord::Base.establish_connection(
      :adapter => "mysql",
      :database => "bitfields_benchmark"
    )
  else
    puts 'using sqlite'
    ActiveRecord::Base.establish_connection(
      :adapter => "sqlite3",
        :database => ":memory:"
    )
  end
end

def create_model_table(bit_counts, use_index)
  ActiveRecord::Schema.define(:version => 2) do
    drop_table :users rescue nil
    create_table :users do |t|
      bit_counts.each do |bit_count|
        t.integer "bit_#{bit_count}", :default => 0, :null => false
      end
    end

    if use_index
      bit_counts.each do |bit_count|
        add_index :users, "bit_#{bit_count}"
      end
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
  result = bit_counts.map do |bit_count|
    sql = User.bitfield_sql({"bit_#{bit_count}_1" => true}, :query_mode => query_mode)
#    puts sql[0..100]
    time = benchmark do
      User.count sql
    end
    puts "#{bit_count} -> #{time}"
    [bit_count, time]
  end
  Hash[result]
end

#determines a unique color based on a name
def color_for(name)
  name = name.inspect + "some randomness for fun"
  hash = (name.hash % 1_000_000_000).to_s #get a hash of a constant size
  colors = [hash[0..1], hash[2..3], hash[4..5]].map{|c| c.to_f / 100.0 * 16} #use 3 parts of the hash to get numbers from 0 to 15.99
  palette = ('0'..'9').to_a + ('a'..'f').to_a #hex values 0..f
  colors.map{|c| palette[c.floor].to_s * 2} * '' #each color is duplicated and the joined
end

connect(database)
create_model_table(bit_counts, use_index)
class User < ActiveRecord::Base
end
create_model_fields(bit_counts)

puts "creating test data"
last = 0

graphs = {:bit => {}, :in => {}}
data = record_counts.map do |record_count|
  create(bit_counts, record_count-last)
  puts User.count
  last = record_count

  puts "testing with #{record_count} records -- bit_operator"
  graphs[:bit][record_count] = test_speed(bit_counts, :bit_operator)

  puts "testing with #{record_count} records -- in_list"
  graphs[:in][record_count] = test_speed(bit_counts, :in_list)

end

colors = {:bit => '00xx00', :in => 'xx0000'}
alpha_num = (('0'..'9').to_a + ('a'..'f').to_a).reverse
title = "bit-operator vs IN() -- #{use_index ? 'with' : 'without'} index"
url = GoogleChart::LineChart.new('600x500', title, false) do |line|
  max = 0
  graphs.each do |type, line_data|
    bit_counts.each do |bit_count|
      data = record_counts.map{|rc| line_data[rc][bit_count] }
      name = "#{bit_count}bits (#{type})"
      color = colors[type].sub('xx', alpha_num[bit_count]*2)
      line.data(name, data, color)
      max = [data.max, max].max
    end
  end

  line.axis :x, :labels => record_counts.map{|c|"#{c/1000}K"}
  line.axis :y, :labels => ['0', "%.3f" % [max*100]]
end.to_url

puts url