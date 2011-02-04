require 'active_support'

module Bitfields
  VERSION = File.read( File.join(File.dirname(__FILE__),'..','VERSION') ).strip
  TRUE_VALUES = [true, 1, '1', 't', 'T', 'true', 'TRUE'] # taken from ActiveRecord::ConnectionAdapters::Column
  class DuplicateBitNameError < ArgumentError; end

  def self.included(base)
    base.class_inheritable_accessor :bitfields, :bitfield_options
    base.extend Bitfields::ClassMethods
  end

  def self.extract_bits(options)
    bitfields = {}
    options.keys.select{|key| key.is_a?(Fixnum) }.each do |bit|
      raise "#{bit} is not a power of 2 !!" unless bit.to_s(2).scan('1').size == 1
      bit_name = options.delete(bit).to_sym
      raise DuplicateBitNameError if bitfields.include?(bit_name)
      bitfields[bit_name] = bit
    end
    bitfields
  end

  # AR 3+ -> :scope, below :named_scope
  def self.ar_scoping_method
    return :scope if defined?(ActiveRecord::VERSION::MAJOR) and ActiveRecord::VERSION::MAJOR >= 3
    :named_scope
  end

  module ClassMethods
    def bitfield(column, *args)
      # prepare ...
      column = column.to_sym
      options = (args.last.is_a?(Hash) ? args.pop.dup : {}) # since we will modify them...
      args.each_with_index{|field,i| options[2**(i+1)] = field } # add fields given in normal args to options

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
        if options[:scopes] != false
          scoping_method = Bitfields.ar_scoping_method
          send scoping_method, bit_name, :conditions => bitfield_sql(bit_name => true)
          send scoping_method, "not_#{bit_name}", :conditions => bitfield_sql(bit_name => false)
        end
      end

      include Bitfields::InstanceMethods
    end

    def bitfield_column(bit_name)
      found = bitfields.detect{|c, bits| bits.keys.include?(bit_name.to_sym) }
      raise "Unknown bitfield #{bit_name}" unless found
      found.first
    end

    def bitfield_sql(bit_values, options={})
      bits = group_bits_by_column(bit_values).sort_by{|c,v| c.to_s }
      bits.map{|column, bit_values| bitfield_sql_by_column(column, bit_values, options) } * ' AND '
    end

    def set_bitfield_sql(bit_values)
      bits = group_bits_by_column(bit_values).sort_by{|c,v| c.to_s }
      bits.map{|column, bit_values| set_bitfield_sql_by_column(column, bit_values) } * ', '
    end

    private

    def bitfield_sql_by_column(column, bit_values, options={})
      mode = options[:query_mode] || (bitfield_options[column][:query_mode] || :bit_operator)
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
        on, off = bit_values_to_on_off(column, bit_values)
        "(#{table_name}.#{column} & #{on+off}) = #{on}"
      else raise("bitfields: unknown query mode #{mode.inspect}")
      end
    end

    def set_bitfield_sql_by_column(column, bit_values)
      on, off = bit_values_to_on_off(column, bit_values)
      "#{column} = (#{column} | #{on+off}) - #{off}"
    end

    def group_bits_by_column(bit_values)
      columns = {}
      bit_values.each do |bit_name, value|
        column = bitfield_column(bit_name.to_sym)
        columns[column] ||= {}
        columns[column][bit_name.to_sym] = value
      end
      columns
    end

    def bit_values_to_on_off(column, bit_values)
      on = off = 0
      bit_values.each do |bit_name, value|
        bit = bitfields[column][bit_name]
        value ? on += bit : off += bit
      end
      [on, off]
    end
  end

  module InstanceMethods
    def bitfield_values(column)
      Hash[bitfields[column.to_sym].map{|bit_name, bit| [bit_name, bitfield_value(bit_name)]}]
    end

    private

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
