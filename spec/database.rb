require 'active_record'

# connect
ActiveRecord::Base.establish_connection(
  :adapter => "sqlite3",
  :database => ":memory:"
)

# create tables
ActiveRecord::Schema.define(:version => 1) do
  create_table :users do |t|
    t.integer :bits, :default => 0, :null => false
    t.integer :more_bits, :default => 0, :null => false
  end
end
