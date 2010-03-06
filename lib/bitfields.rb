require 'active_support'

module Bitfields
  TRUE_VALUES = [true, 1, '1', 't', 'T', 'true', 'TRUE'] # taken from ActiveRecord::ConnectionAdapters::Column

  def self.included(base)
    base.class_inheritable_accessor :bitfields, :bitfield_options
    base.extend Bitfields::ClassMethods
  end

  def self.extract_bits(options)
    bitfields = {}
    options.keys.select{|key| key.is_a?(Numeric) }.each do |bit|
      bit_name = options.delete(bit).to_sym
      bitfields[bit_name] = bit
    end
    bitfields
  end

  module ClassMethods
    def bitfield(column, options)
      # prepare ...
      column = column.to_sym
      options = options.dup # since we will modify them...

      # extract options
      self.bitfields ||= {}
      self.bitfield_options ||= {}
      bitfields[column] = Bitfields.extract_bits(options)
      bitfield_options[column] = options

      # add instance methods and scopes
      bitfields[column].keys.each do |bit_name|
        define_method(bit_name){ bitfield_value(bit_name) }
        define_method("#{bit_name}?"){ bitfield_value(bit_name) }
        define_method("#{bit_name}="){|value| set_bitfield_value(bit_name, value) }
        if options[:named_scopes] != false
          scoping_method = (respond_to?(:scope) ? :scope : :named_scope) # AR 3.0+ uses scope
          send scoping_method, bit_name, :conditions => bitfield_sql(bit_name => true)
          send scoping_method, "not_#{bit_name}", :conditions => bitfield_sql(bit_name => false)
        end
      end

      include Bitfields::InstanceMethods
    end

    def bitfield_column(bit_name)
      bitfields.detect{|c, bits| bits.keys.include?(bit_name) }.first
    end

    def bitfield_sql(bit_values)
      bits = group_bits_by_column(bit_values)
      bits.map{|column, bit_values| bitfield_sql_by_column(column, bit_values) } * ' AND '
    end

    def bitfield_sql_by_column(column, bit_values)
      mode = (bitfield_options[column][:query_mode] || :in_list)
      case mode
      when :in_list then
        max = (bitfields[column].values.max * 2) - 1
        bits = (0..max).to_a # all possible bits
        bit_values.each do |bit_name, value|
          bit = bitfields[column][bit_name]
          # reject values with: bit off for true, bit on for false
          bits.reject!{|i| i & bit == (value ? 0 : bit) }
        end
        "#{table_name}.#{column} IN (#{bits * ','})"
      when :bit_operator
        set, unset = bit_values_to_set_and_unset(column, bit_values)
        "(#{table_name}.#{column} & #{set+unset}) = #{set}"
      else raise("bitfields: unknown query mode #{mode.inspect}")
      end
    end

    def set_bitfield_sql(bit_values)
      columns = group_bits_by_column(bit_values)
      columns.map{|column, bit_values| set_bitfield_sql_by_column(column, bit_values) } * ', '
    end

    def set_bitfield_sql_by_column(column, bit_values)
      set, unset = bit_values_to_set_and_unset(column, bit_values)
      "#{column} = (#{column} | #{set+unset}) - #{unset}"
    end

    def group_bits_by_column (bit_values)
      columns = {}
      bit_values.each do |bit_name, value|
        column = bitfield_column(bit_name)
        columns[column] ||= {}
        columns[column][bit_name] = value
      end
      columns
    end

    def bit_values_to_set_and_unset(column, bit_values)
      set = 0
      unset = 0
      bit_values.each do |bit_name, value|
        bit = bitfields[column][bit_name]
        value ? set += bit : unset += bit
      end
      [set, unset]
    end
  end

  module InstanceMethods
    def bitfield_value(bit_name)
      column, bit, current_value = bitfield_info(bit_name)
      current_value & bit != 0
    end

    def set_bitfield_value(bit_name, value)
      column, bit, current_value = bitfield_info(bit_name)
      new_value = TRUE_VALUES.include?(value)
      old_value = bitfield_value(bit_name)
      return if new_value == old_value

      if defined? changed_attributes
        send(:changed_attributes).merge!(bit_name.to_s => old_value)
      end

      # 8 + 1 == 9 // 8 + 8 == 8 // 1 - 8 == 1 // 8 - 8 == 0
      new_bits = if new_value then current_value | bit else (current_value | bit) - bit end
      send("#{column}=", new_bits)
    end

    def bitfield_info(bit_name)
      column = self.class.bitfield_column(bit_name)
      [
        column,
        self.class.bitfields[column][bit_name], # bit
        (send(column)||0) # current value
      ]
    end
  end
end