require 'bitfields/version'
require 'active_support'
require 'active_support/version'

module Bitfields
  TRUE_VALUES = [true, 1, '1', 't', 'T', 'true', 'TRUE'] # taken from ActiveRecord::ConnectionAdapters::Column
  class DuplicateBitNameError < ArgumentError; end

  def self.included(base)
    class << base
      attr_accessor :bitfields, :bitfield_options, :bitfield_args

      # all the args passed into .bitfield so children can initialize from parents
      def bitfield_args
        @bitfield_args ||= []
      end

      def inherited(klass)
        super
        klass.bitfield_args = bitfield_args.dup
        klass.bitfield_args.each do |column, options|
          klass.send :store_bitfield_values, column, options.dup
        end
      end
    end

    base.extend Bitfields::ClassMethods
  end

  def self.extract_bits(options)
    bitfields = {}
    options.keys.select{|key| key.is_a?(Numeric) }.each do |bit|
      raise "#{bit} is not a power of 2 !!" unless bit & (bit - 1) == 0
      bit_name = options.delete(bit).to_sym
      raise DuplicateBitNameError if bitfields.include?(bit_name)
      bitfields[bit_name] = bit
    end
    bitfields
  end

  module ClassMethods
    def bitfield(column, *args)
      column = column.to_sym
      options = extract_bitfield_options args
      bitfield_args << [column, options.dup]

      store_bitfield_values column, options
      add_bitfield_methods column, options
    end

    def bitfield_column(bit_name)
      found = bitfields.detect{|_, bits| bits.keys.include?(bit_name.to_sym) }
      raise "Unknown bitfield #{bit_name}" unless found
      found.first
    end

    def bitfield_sql(bit_values, options={})
      bits = group_bits_by_column(bit_values).sort_by{|c,_| c.to_s }
      bits.map{|column, bit_values| bitfield_sql_by_column(column, bit_values, options) } * ' AND '
    end

    def set_bitfield_sql(bit_values)
      bits = group_bits_by_column(bit_values).sort_by{|c,_| c.to_s }
      bits.map{|column, bit_values| set_bitfield_sql_by_column(column, bit_values) } * ', '
    end

    private

    def extract_bitfield_options(args)
      options = (args.last.is_a?(Hash) ? args.pop.dup : {})
      args.each_with_index{|field,i| options[2**i] = field } # add fields given in normal args to options
      options
    end

    def store_bitfield_values(column, options)
      self.bitfields ||= {}
      self.bitfield_options ||= {}
      bitfields[column] = Bitfields.extract_bits(options)
      bitfield_options[column] = options
    end

    def add_bitfield_methods(column, options)
      bitfields[column].keys.each do |bit_name|
        define_method(bit_name) { bitfield_value(bit_name) }
        define_method("#{bit_name}?") { bitfield_value(bit_name) }
        define_method("#{bit_name}=") { |value| set_bitfield_value(bit_name, value) }
        define_method("#{bit_name}_was") { bitfield_value_was(bit_name) }
        define_method("#{bit_name}_changed?") { bitfield_value_was(bit_name) != bitfield_value(bit_name) }
        define_method("#{bit_name}_change") do
          values = [bitfield_value_was(bit_name), bitfield_value(bit_name)]
          values unless values[0] == values[1]
        end
        define_method("#{bit_name}_became_true?") do
          value = bitfield_value(bit_name)
          value && bitfield_value_was(bit_name) != value
        end

        if options[:scopes] != false
          scope bit_name, bitfield_scope_options(bit_name => true)
          scope "not_#{bit_name}", bitfield_scope_options(bit_name => false)
        end
      end

      include Bitfields::InstanceMethods
    end

    def bitfield_scope_options(bit_values)
      -> { where(bitfield_sql(bit_values)) }
    end

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
      Hash[self.class.bitfields[column.to_sym].map{|bit_name, _| [bit_name, bitfield_value(bit_name)]}]
    end

    def bitfield_changes
      self.class.bitfields.values.flat_map(&:keys).each_with_object({}) do |bit, changes|
        old, current = bitfield_value_was(bit), bitfield_value(bit)
        changes[bit.to_s] = [old, current] unless old == current
      end
    end

    private

    def bitfield_value(bit_name)
      _, bit, current_value = bitfield_info(bit_name)
      current_value & bit != 0
    end

    def bitfield_value_was(bit_name)
      column, bit, _ = bitfield_info(bit_name)
      send("#{column}_was") & bit != 0
    end

    def set_bitfield_value(bit_name, value)
      column, bit, current_value = bitfield_info(bit_name)
      new_value = TRUE_VALUES.include?(value)
      old_value = bitfield_value(bit_name)
      return if new_value == old_value

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
