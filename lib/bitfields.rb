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
      # sort bit_values by column
      columns = {}
      bit_values.each do |bit_name, value|
        column = bitfield_column(bit_name)
        columns[column] ||= {}
        columns[column][bit_name] = value
      end

      columns.map{|column, bit_values| bitfield_sql_by_column(column, bit_values) } * ' AND '
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
        bit_values.map do |bit_name, value|
          column = bitfield_column(bit_name)
          bit = bitfields[column][bit_name]
          "(#{table_name}.#{column} & #{bit}) = #{value ? bit : 0})"
        end * ' AND '
      else raise("bitfields: unknown query mode #{mode.inspect}")
      end
    end

    def set_bitfield_sql(bit_values)
      # :seller => true, :insane => false ---> :my_bits => {:set => [1], :unset => [4]}
      columns = {}
      bit_values.each do |bit_name, value|
        column = bitfield_column(bit_name)
        bit = bitfields[column][bit_name]

        columns[column] ||= {:set => 0, :unset => 0}

        collector = (value ? :set : :unset)
        columns[column][collector] += bit
      end

      # :my_bits => {:set => [1], :unset => [4]} ----> sql
      columns.map do |column, changes|
        changed = changes[:set] + changes[:unset]
        "#{column} = (#{column} | #{changed}) - #{changes[:unset]}"
      end * ', '
    end
  end

  module InstanceMethods
    def bitfield_value(bit_name)
      column, bit, current_value = bitfield_info(bit_name)
      current_value & bit != 0
    end

    def set_bitfield_value(bit_name, value)
      column, bit, current_value = bitfield_info(bit_name)
      if TRUE_VALUES.include?(value)
        send("#{column}=", current_value | bit) # bit8 + bit1 == 9 and bit8 + bit8 == 8
      else
        send("#{column}=", (current_value | bit) - bit) # bit1 - bit8 == 1 and bit8 - bit8 == 0
      end
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