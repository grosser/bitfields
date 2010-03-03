require 'active_support'

module Bitfield
  TRUE_VALUES = [true, 1, '1', 't', 'T', 'true', 'TRUE'] # taken from ActiveRecord::ConnectionAdapters::Column

  attr_accessor :bitfields, :bitfield_options

  def bitfield(column, options)
    # prepare ...
    column = column.to_sym
    options = options.dup # since we will modify them...

    # extract options
    self.bitfields ||= {}
    self.bitfield_options ||= {}
    bitfields[column] = Bitfield.extract_bitfields!(options)
    bitfield_options[column] = options

    # add instance methods
    bitfields[column].keys.each do |name|
      define_method(name){ bitfield_value(name) }
      define_method("#{name}?"){ bitfield_value(name) }
      define_method("#{name}="){|value| set_bitfield_value(name, value) }
    end

    include Bitfield::InstanceMethods
  end

  def self.extract_bitfields!(options)
    bitfields = {}
    options.keys.select{|key| key.is_a?(Numeric) }.each do |key|
      name = options.delete(key)
      bitfields[name.to_sym] = key
    end
    bitfields
  end

  def bitfield_column(bitfield)
    bitfields.detect{|c, bitfields| bitfields.keys.include?(bitfield) }.first
  end

  def bitfield_sql(bitfield_values)
    columns = {}
    bitfield_values.each do |bitfield, value|
      column = bitfield_column(bitfield)
      bit = bitfields[column][bitfield]

      max = (bitfields[column].values.max * 2) - 1
      columns[column] ||= (0..max).to_a # seed with all possible values

      # remove values that do not fit in
      if value
        columns[column].reject!{|i| i & bit == 0 } # reject all with this bit off
      else
        columns[column].reject!{|i| i & bit == bit } # reject all with this bit on
      end
    end

    columns.map do |column, values|
      "users.#{column} IN (#{values * ','})"
    end * ' AND '
  end

  module InstanceMethods
    def bitfield_value(bitfield)
      column, bit, current_value = bitfield_info(bitfield)
      current_value & bit != 0
    end

    def set_bitfield_value(bitfield, value)
      column, bit, current_value = bitfield_info(bitfield)
      if TRUE_VALUES.include?(value)
        send("#{column}=", current_value | bit) # bit8 + bit1 == 9 and bit8 + bit8 == 8
      else
        send("#{column}=", (current_value | bit) - bit) # bit1 - bit8 == 1 and bit8 - bit8 == 0
      end
    end

    def bitfield_info(bitfield)
      column = self.class.bitfield_column(bitfield)
      [
        column,
        self.class.bitfields[column][bitfield], # bit
        (send(column)||0) # current value
      ]
    end
  end
end