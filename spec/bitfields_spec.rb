require 'spec_helper'

class User < ActiveRecord::Base
  include Bitfields
  bitfield :bits, 1 => :seller, 2 => :insane, 4 => :stupid
end

class UserWithBitfieldOptions < ActiveRecord::Base
  include Bitfields
  bitfield :bits, 1 => :seller, 2 => :insane, 4 => :stupid, :scopes => false
end

class MultiBitUser < ActiveRecord::Base
  set_table_name 'users'
  include Bitfields
  bitfield :bits, 1 => :seller, 2 => :insane, 4 => :stupid
  bitfield :more_bits, 1 => :one, 2 => :two, 4 => :four
end

class UserWithoutScopes < ActiveRecord::Base
  set_table_name 'users'
  include Bitfields
  bitfield :bits, 1 => :seller, 2 => :insane, 4 => :stupid, :scopes => false
end

class UserWithoutSetBitfield < ActiveRecord::Base
  set_table_name 'users'
  include Bitfields
end

class InheritedUser < User
end

class GrandchildInheritedUser < InheritedUser
end

class InheritedUserWithoutSetBitfield < UserWithoutSetBitfield
end

class OverwrittenUser < User
  bitfield :bits, 1 => :seller_inherited
end

class BitOperatorMode < ActiveRecord::Base
  set_table_name 'users'
  include Bitfields
  bitfield :bits, 1 => :seller, 2 => :insane, :query_mode => :bit_operator
end

class WithoutThePowerOfTwo < ActiveRecord::Base
  set_table_name 'users'
  include Bitfields
  bitfield :bits, :seller, :insane, :stupid, :query_mode => :bit_operator
end

class WithoutThePowerOfTwoWithoutOptions < ActiveRecord::Base
  set_table_name 'users'
  include Bitfields
  bitfield :bits, :seller, :insane
end

class CheckRaise < ActiveRecord::Base
  set_table_name 'users'
  include Bitfields
end

class ManyBitsUser < User
  set_table_name 'users'
end

class InitializedUser < User
  set_table_name 'users'
  bitfield :bits, 1 => :seller, 2 => :insane, 4 => :stupid, :scopes => false

  after_initialize do
    self.seller = true
    self.insane = false
  end
end

describe Bitfields do
  before do
    User.delete_all
  end

  describe :bitfields do
    it "parses them correctly" do
      User.bitfields.should == {:bits => {:seller => 1, :insane => 2, :stupid => 4}}
    end
    
    it "is fast for huge number of bits" do
      bits = {}
      0.upto(20) do |bit|
        bits[2**bit] = "my_bit_#{bit}"
      end

      Timeout.timeout(0.2) do
        ManyBitsUser.class_eval{ bitfield :bits, bits }
      end
    end
  end

  describe :bitfield_options do
    it "parses them correctly when not set" do
      User.bitfield_options.should == {:bits => {}}
    end

    it "parses them correctly when set" do
      UserWithBitfieldOptions.bitfield_options.should == {:bits => {:scopes => false}}
    end
  end

  describe :bitfield_column do
    it "raises a nice error when i use a unknown bitfield" do
      lambda{
        User.bitfield_column(:xxx)
      }.should raise_error(RuntimeError, 'Unknown bitfield xxx')
    end
  end

  describe :bitfield_values do
    it "contains all bits with values" do
      User.new.bitfield_values(:bits).should == {:insane=>false, :stupid=>false, :seller=>false}
      User.new(:bits => 15).bitfield_values(:bits).should == {:insane=>true, :stupid=>true, :seller=>true}
    end
  end

  describe 'attribute accessors' do
    it "has everything on false by default" do
      User.new.seller.should == false
      User.new.seller?.should == false
    end

    it "is true when set to true" do
      User.new(:seller => true).seller.should == true
    end

    it "is true when set to truthy" do
      User.new(:seller => 1).seller.should == true
    end

    it "is false when set to false" do
      User.new(:seller => false).seller.should == false
    end

    it "is false when set to falsy" do
      User.new(:seller => 'false').seller.should == false
    end

    it "stays true when set to true twice" do
      u = User.new
      u.seller = true
      u.seller = true
      u.seller.should == true
      u.bits.should == 1
    end

    it "stays false when set to false twice" do
      u = User.new(:bits => 3)
      u.seller = false
      u.seller = false
      u.seller.should == false
      u.bits.should == 2
    end

    it "changes the bits when setting to false" do
      user = User.new(:bits => 7)
      user.seller = false
      user.bits.should == 6
    end

    it "does not get negative when unsetting high bits" do
      user = User.new(:seller => true)
      user.stupid = false
      user.bits.should == 1
    end

    it "changes the bits when setting to true" do
      user = User.new(:bits => 2)
      user.seller = true
      user.bits.should == 3
    end

    it "does not get too high when setting high bits" do
      user = User.new(:bits => 7)
      user.seller = true
      user.bits.should == 7
    end

    describe 'changes' do
      it "has no changes by defaut" do
        User.new.changes.should == {}
      end

      it "records a change when setting" do
        User.new(:seller => true).changes.should == {'seller' => [false, true], 'bits' => [0,1]}
      end

      it "records a change when unsetting" do
        u = User.create!(:seller => true)
        u.seller = false
        u.changes.should == {'seller' => [true, false], 'bits' => [1,0]}
      end

      it "does not track duplicate changes" do
        User.create!(:seller => false).changes.should == {}
      end
    end
  end

  describe :bitfield_sql do
    it "includes true states" do
      User.bitfield_sql({:insane => true}, :query_mode => :in_list).should == 'users.bits IN (2,3,6,7)' # 2, 1+2, 2+4, 1+2+4
    end

    it "includes invalid states" do
      User.bitfield_sql({:insane => false}, :query_mode => :in_list).should == 'users.bits IN (0,1,4,5)' # 0, 1, 4, 4+1
    end

    it "can combine multiple fields" do
      User.bitfield_sql({:seller => true, :insane => true}, :query_mode => :in_list).should == 'users.bits IN (3,7)' # 1+2, 1+2+4
    end

    it "can combine multiple fields with different values" do
      User.bitfield_sql({:seller => true, :insane => false}, :query_mode => :in_list).should == 'users.bits IN (1,5)' # 1, 1+4
    end

    it "combines multiple columns into one sql" do
      sql = MultiBitUser.bitfield_sql({:seller => true, :insane => false, :one => true, :four => true}, :query_mode => :in_list)
      sql.should == 'users.bits IN (1,5) AND users.more_bits IN (5,7)' # 1, 1+4 AND 1+4, 1+2+4
    end

    it "produces working sql" do
      u1 = MultiBitUser.create!(:seller => true, :one => true)
      u2 = MultiBitUser.create!(:seller => true, :one => false)
      u3 = MultiBitUser.create!(:seller => false, :one => false)
      MultiBitUser.all(:conditions => MultiBitUser.bitfield_sql({:seller => true, :one => false}, :query_mode => :in_list)).should == [u2]
    end

    describe 'with bit operator mode' do
      it "generates bit-operator sql" do
        BitOperatorMode.bitfield_sql(:seller => true).should == '(users.bits & 1) = 1'
      end

      it "generates sql for each bit" do
        BitOperatorMode.bitfield_sql(:seller => true, :insane => false).should == '(users.bits & 3) = 1'
      end

      it "generates working sql" do
        u1 = BitOperatorMode.create!(:seller => true, :insane => true)
        u2 = BitOperatorMode.create!(:seller => true, :insane => false)
        u3 = BitOperatorMode.create!(:seller => false, :insane => false)
        BitOperatorMode.all(:conditions => MultiBitUser.bitfield_sql(:seller => true, :insane => false)).should == [u2]
      end
    end

    describe 'without the power of two' do
      it 'uses correct bits' do
        u = WithoutThePowerOfTwo.create!(:seller => false, :insane => true, :stupid => true)
        u.bits.should == 6
      end

      it 'has all fields' do
        u = WithoutThePowerOfTwo.create!(:seller => false, :insane => true)
        u.seller.should == false
        u.insane.should == true
        WithoutThePowerOfTwo.bitfield_options.should == {:bits=>{:query_mode=>:bit_operator}}
      end

      it "can e built without options" do
        u = WithoutThePowerOfTwoWithoutOptions.create!(:seller => false, :insane => true)
        u.seller.should == false
        u.insane.should == true
        WithoutThePowerOfTwoWithoutOptions.bitfield_options.should == {:bits=>{}}
      end
    end

    it "checks that bitfields are unique" do
      lambda{
        CheckRaise.class_eval do
          bitfield :foo, :bar, :baz, :bar
        end
      }.should raise_error(Bitfields::DuplicateBitNameError)
    end
  end

  describe :set_bitfield_sql do
    it "sets a single bit" do
      User.set_bitfield_sql(:seller => true).should == 'bits = (bits | 1) - 0'
    end

    it "unsets a single bit" do
      User.set_bitfield_sql(:seller => false).should == 'bits = (bits | 1) - 1'
    end

    it "sets multiple bits" do
      User.set_bitfield_sql(:seller => true, :insane => true).should == 'bits = (bits | 3) - 0'
    end

    it "unsets multiple bits" do
      User.set_bitfield_sql(:seller => false, :insane => false).should == 'bits = (bits | 3) - 3'
    end

    it "sets and unsets in one command" do
      User.set_bitfield_sql(:seller => false, :insane => true).should == 'bits = (bits | 3) - 1'
    end

    it "sets and unsets for multiple columns in one sql" do
      sql = MultiBitUser.set_bitfield_sql(:seller => false, :insane => true, :one => true, :two => false)
      sql.should == "bits = (bits | 3) - 1, more_bits = (more_bits | 3) - 2"
    end

    it "produces working sql" do
      u = MultiBitUser.create!(:seller => true, :insane => true, :stupid => false, :one => true, :two => false, :four => false)
      sql = MultiBitUser.set_bitfield_sql(:seller => false, :insane => true, :one => true, :two => false)
      MultiBitUser.update_all(sql)
      u.reload
      u.seller.should == false
      u.insane.should == true
      u.stupid.should == false
      u.one.should == true
      u.two.should == false
      u.four.should == false
    end
  end

  describe 'named scopes' do
    before do
      @u1 = User.create!(:seller => true, :insane => false)
      @u2 = User.create!(:seller => true, :insane => true)
    end

    it "creates them when nothing was passed" do
      User.respond_to?(:seller).should == true
      User.respond_to?(:not_seller).should == true
    end

    it "does not create them when false was passed" do
      UserWithoutScopes.respond_to?(:seller).should == false
      UserWithoutScopes.respond_to?(:not_seller).should == false
    end

    it "produces working positive scopes" do
      User.insane.seller.to_a.should == [@u2]
    end

    it "produces working negative scopes" do
      User.not_insane.seller.to_a.should == [@u1]
    end
  end

  describe 'overwriting' do
    it "does not change base class" do
      OverwrittenUser.bitfields[:bits][:seller_inherited].should_not == nil
      User.bitfields[:bits][:seller_inherited].should == nil
    end

    it "has inherited methods" do
      User.respond_to?(:seller).should == true
      OverwrittenUser.respond_to?(:seller).should == true
    end
  end

  describe 'inheritance' do
    it "knows overwritten values and normal" do
      User.bitfields.should == {:bits=>{:seller=>1, :insane=>2, :stupid=>4}}
      OverwrittenUser.bitfields.should == {:bits=>{:seller_inherited=>1}}
    end

    it "knows overwritten values when overwriting" do
      OverwrittenUser.bitfield_column(:seller_inherited).should == :bits
    end

    it "does not know old values when overwriting" do
      expect{
        OverwrittenUser.bitfield_column(:seller)
      }.to raise_error
    end

    it "knows inherited values without overwriting" do
      InheritedUser.bitfield_column(:seller).should == :bits
    end

    it "has inherited scopes" do
      InheritedUser.should respond_to(:not_seller)
    end

    it "has inherited methods" do
      InheritedUser.new.should respond_to(:seller?)
    end

    it "knows grandchild inherited values without overwriting" do
      GrandchildInheritedUser.bitfield_column(:seller).should == :bits
    end

    it "inherits no bitfields for a user without bitfields set" do
      InheritedUserWithoutSetBitfield.bitfields.should be_nil
    end
  end

  describe 'initializers' do
    it "sets defaults" do
      InitializedUser.new.seller.should == true
      InitializedUser.new.insane.should == false
    end

    it "can overwrite defaults in new" do
      pending do
        InitializedUser.new(:seller => false).seller.should == false
        InitializedUser.new(:insane => true).insane.should == true
      end
    end
  end
end
