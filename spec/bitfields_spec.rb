require 'spec_helper'

class User < ActiveRecord::Base
  include Bitfields
  bitfield :bits, 1 => :seller, 2 => :insane, 4 => :stupid
end

class UserWithBitfieldOptions < ActiveRecord::Base
  include Bitfields
  bitfield :bits, 1 => :seller, 2 => :insane, 4 => :stupid, :scopes => false
end

class UserWithInstanceOptions < ActiveRecord::Base
  self.table_name = 'users'
  include Bitfields
  bitfield :bits, 1 => :seller, 2 => :insane, 4 => :stupid, :added_instance_methods => false
end

class MultiBitUser < ActiveRecord::Base
  self.table_name = 'users'
  include Bitfields
  bitfield :bits, 1 => :seller, 2 => :insane, 4 => :stupid
  bitfield :more_bits, 1 => :one, 2 => :two, 4 => :four
end

class UserWithoutScopes < ActiveRecord::Base
  self.table_name = 'users'
  include Bitfields
  bitfield :bits, 1 => :seller, 2 => :insane, 4 => :stupid, :scopes => false
end

class UserWithoutSetBitfield < ActiveRecord::Base
  self.table_name = 'users'
  include Bitfields
end

class InheritedUser < User
end

class GrandchildInheritedUser < InheritedUser
end

# other children should not disturb the inheritance
class OtherInheritedUser < UserWithoutSetBitfield
  self.table_name = 'users'
  bitfield :bits, 1 => :seller_inherited
end

class InheritedUserWithoutSetBitfield < UserWithoutSetBitfield
end

class OverwrittenUser < User
  bitfield :bits, 1 => :seller_inherited
end

class BitOperatorMode < ActiveRecord::Base
  self.table_name = 'users'
  include Bitfields
  bitfield :bits, 1 => :seller, 2 => :insane, :query_mode => :bit_operator
end

class WithoutThePowerOfTwo < ActiveRecord::Base
  self.table_name = 'users'
  include Bitfields
  bitfield :bits, :seller, :insane, :stupid, :query_mode => :bit_operator
end

class WithoutThePowerOfTwoWithoutOptions < ActiveRecord::Base
  self.table_name = 'users'
  include Bitfields
  bitfield :bits, :seller, :insane
end

class CheckRaise < ActiveRecord::Base
  self.table_name = 'users'
  include Bitfields
end

class ManyBitsUser < User
  self.table_name = 'users'
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
      UserWithInstanceOptions.bitfield_options.should == {:bits => {:added_instance_methods => false}}
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

  describe :bitfield_bits do
    it "converts bitfield values to bits" do
      User.bitfield_bits({ insane: true, stupid: true, seller: true }).should == 7
      User.bitfield_bits({ seller: true }).should == 1
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

    context "when instantiating a new record" do
      it "has _was" do
        user = User.new(:seller => true)
        user.seller_was.should == false
        user.save!
        user.seller_was.should == true
      end

      it "has _changed?" do
        user = User.new(:seller => true)
        user.seller_changed?.should == true
        user.save!
        user.seller_changed?.should == false
      end

      it "has _change" do
        user = User.new(:seller => true)
        user.seller_change.should == [false, true]
        user.save!
        user.seller_change.should == nil
        user.seller = false
        user.seller_change.should == [true, false]
      end

      it "has _before_last_save" do
        user = User.new(:seller => true)
        user.seller_before_last_save.should == nil
        user.save!
        user.seller_before_last_save.should == false
      end

      it "has _change_to_be_saved" do
        user = User.new(:seller => true)
        user.seller_change_to_be_saved.should == [false, true]
        user.save!
        user.seller_change_to_be_saved.should == nil
      end

      it "has _in_database" do
        user = User.new(:seller => true)
        user.seller_in_database.should == false
        user.save!
        user.seller_in_database.should == true
      end

      it "has saved_change_to_" do
        user = User.new(:seller => true)
        user.saved_change_to_seller.should == nil
        user.save!
        user.saved_change_to_seller.should == [false, true]
      end

      it "has saved_change_to_?" do
        user = User.new(:seller => true)
        user.saved_change_to_seller?.should == false
        user.save!
        user.saved_change_to_seller?.should == true
      end

      it "has will_save_change_to_?" do
        user = User.new(:seller => true)
        user.will_save_change_to_seller?.should == true
        user.save!
        user.will_save_change_to_seller?.should == false
        user.seller = false
        user.will_save_change_to_seller?.should == true
      end
    end

    context "when creating a new model" do
      it "has _was" do
        user = User.create!(:seller => true)
        user.seller = false
        user.seller_was.should == true
        user.save!
        user.seller_was.should == false
      end

      it "has _changed?" do
        user = User.create!(:seller => true)
        user.seller_changed?.should == false
        user.seller = false
        user.seller_changed?.should == true
        user.save!
        user.seller_changed?.should == false
      end

      it "has _change" do
        user = User.create!(:seller => true)
        user.seller_change.should == nil
        user.seller = false
        user.seller_change.should == [true, false]
        user.save!
        user.seller_change.should == nil
      end

      it "has _before_last_save" do
        user = User.create!(:seller => true)
        user.seller_before_last_save.should == false
        user.seller = false
        user.save!
        user.seller_before_last_save.should == true
      end

      it "has _change_to_be_saved" do
        user = User.create!(:seller => true)
        user.seller_change_to_be_saved.should == nil
        user.seller = false
        user.seller_change_to_be_saved.should == [true, false]
        user.save!
        user.seller_change_to_be_saved.should == nil
      end

      it "has _in_database" do
        user = User.create!(:seller => true)
        user.seller_in_database.should == true
        user.seller = false
        user.save!
        user.seller_in_database.should == false
      end

      it "has saved_change_to_" do
        user = User.create!(:seller => true)
        user.saved_change_to_seller.should == [false, true]
      end

      it "has saved_change_to_?" do
        user = User.create!(:seller => true)
        user.saved_change_to_seller?.should == true
      end

      it "has will_save_change_to_?" do
        user = User.create!(:seller => true)
        user.will_save_change_to_seller?.should == false
        user.seller = false
        user.will_save_change_to_seller?.should == true
        user.save!
        user.will_save_change_to_seller?.should == false
        user.seller = true
        user.will_save_change_to_seller?.should == true
      end
    end

    context "when loading a model from the database" do
      it "has _was" do
        User.create!(:seller => true)
        user = User.last
        user.seller
        user.seller = false
        user.seller_was.should == true
        user.save!
        user.seller_was.should == false
      end

      it "has _changed?" do
        User.create!(:seller => true)
        user = User.last
        user.seller_changed?.should == false
        user.seller = false
        user.seller_changed?.should == true
        user.save!
        user.seller_changed?.should == false
      end

      it "has _change" do
        User.create!(:seller => true)
        user = User.last
        user.seller_change.should == nil
        user.seller = false
        user.seller_change.should == [true, false]
        user.save!
        user.seller_change.should == nil
      end

      it "has _before_last_save" do
        User.create!(:seller => true)
        user = User.last
        user.seller_before_last_save.should == nil
        user.seller = false
        user.save!
        user.seller_before_last_save.should == true
      end

      it "has _change_to_be_saved" do
        User.create!(:seller => true)
        user = User.last
        user.seller_change_to_be_saved.should == nil
        user.seller = false
        user.seller_change_to_be_saved.should == [true, false]
        user.save!
        user.seller_change_to_be_saved.should == nil
      end

      it "has _in_database" do
        User.create!(:seller => true)
        user = User.last
        user.seller_in_database.should == true
        user.seller = false
        user.save!
        user.seller_in_database.should == false
      end

      it "has saved_change_to_" do
        User.create!(:seller => true)
        user = User.last
        user.saved_change_to_seller.should == nil
        user.seller = false
        user.saved_change_to_seller.should == nil
        user.save!
        user.saved_change_to_seller.should == [true, false]
      end

      it "has saved_change_to_?" do
        User.create!(:seller => true)
        user = User.last
        user.saved_change_to_seller?.should == false
        user.seller = false
        user.saved_change_to_seller?.should == false
        user.save!
        user.saved_change_to_seller?.should == true
      end

      it "has will_save_change_to_?" do
        User.create!(:seller => true)
        user = User.last
        user.will_save_change_to_seller?.should == false
        user.seller = false
        user.will_save_change_to_seller?.should == true
        user.save!
        user.will_save_change_to_seller?.should == false
        user.seller = true
        user.will_save_change_to_seller?.should == true
      end

      context "when the model loaded from the database does not select the bitfield column" do
        it "does not try to assign the bitfield attributes" do
          User.create!(:seller => true)

          lambda{
            User.select(:id).last
          }.should_not raise_error
        end
      end
    end

    it "has _became_true?" do
      user = User.new
      user.seller_became_true?.should == false
      user.seller = true
      user.seller_became_true?.should == true
      user.save!
      user.seller_became_true?.should == false
      user.seller = true
      user.seller_became_true?.should == false
    end

    it "has _became_false?" do
      user = User.new
      user.seller_became_false?.should == false
      user.seller = true
      user.seller_became_false?.should == false
      user.save!
      user.seller_became_false?.should == false
      user.seller = false
      user.seller_became_false?.should == true
    end

    context "when :added_instance_methods is false" do
      %i{
        seller seller? seller= seller_was seller_changed? seller_change seller_became_true? seller_became_false?
      }.each do |meth|
        describe "method #{meth} is not generated" do
          UserWithInstanceOptions.new.respond_to?(meth).should == false
        end
      end

      it "does not define an after_find method" do
        UserWithInstanceOptions.new.respond_to?(:after_find).should == false
      end
    end

    it "does still have the main bitfield method" do
      UserWithInstanceOptions.new.bits.should eq 0
    end
  end

  describe '#bitfield_changes' do
    it "has no changes by default" do
      User.new.bitfield_changes.should == {}
    end

    it "records a change when setting" do
      u = User.new(:seller => true)
      u.changes.should == { 'bits' => [0,1] }
      u.bitfield_changes.should == {'seller' => [false, true]}
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
      conditions = MultiBitUser.bitfield_sql({:seller => true, :one => false}, :query_mode => :in_list)
      MultiBitUser.where(conditions).should == [u2]
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

        conditions = MultiBitUser.bitfield_sql(:seller => true, :insane => false)
        BitOperatorMode.where(conditions).should == [u2]
      end
    end

    describe 'with OR' do
      it "generates sql for each bit" do
        User.bitfield_sql({:seller => true, :insane => true, :stupid => false}, :query_mode => :bit_operator_or).should == '(users.bits & 3) <> 0 OR (users.bits & 4) <> 4'
      end

      it "generates sql for only ON" do
        User.bitfield_sql({:seller => true, :insane => true}, :query_mode => :bit_operator_or).should == '(users.bits & 3) <> 0'
      end

      it "generates sql for only OFF" do
        User.bitfield_sql({:seller => false, :stupid => false}, :query_mode => :bit_operator_or).should == '(users.bits & 5) <> 5'
      end

      it "generates working sql" do
        u1 = User.create!(:seller => true, :insane => true)
        u2 = User.create!(:seller => true, :insane => false)
        u3 = User.create!(:seller => false, :insane => false)
        u4 = User.create!(:stupid => true, :insane => false)

        conditions = User.bitfield_sql({:seller => true, :insane => true}, :query_mode => :bit_operator_or)
        User.where(conditions).should == [u1, u2]

        conditions = User.bitfield_sql({:seller => true, :insane => false}, :query_mode => :bit_operator_or)
        User.where(conditions).should == [u1, u2, u3, u4]

        conditions = User.bitfield_sql({:seller => false, :insane => false}, :query_mode => :bit_operator_or)
        User.where(conditions).should == [u2, u3, u4]
      end

      it "generates working sql for multiple ON bits" do
        u1 = User.create!(:seller => true)
        u2 = User.create!(:insane => true)
        u3 = User.create!(:stupid => true)
        u4 = User.create! # all off

        conditions = User.bitfield_sql({:seller => true, :insane => true,  :stupid => true}, :query_mode => :bit_operator_or)
        User.where(conditions).should == [u1, u2, u3]

        conditions = User.bitfield_sql({:seller => true, :stupid => true}, :query_mode => :bit_operator_or)
        User.where(conditions).should == [u1, u3]

        conditions = User.bitfield_sql({:seller => true}, :query_mode => :bit_operator_or)
        User.where(conditions).should == [u1]

        conditions = User.bitfield_sql({:seller => true, :insane => true,  :stupid => false}, :query_mode => :bit_operator_or)
        User.where(conditions).should == [u1, u2, u4]
      end

      it "generates working sql for multiple OFF bits" do
        u1 = User.create!(:seller => false, :insane => true,  :stupid => true)
        u2 = User.create!(:seller => true, :insane => false,  :stupid => true)
        u3 = User.create!(:seller => true, :insane => true,  :stupid => false)
        u4 = User.create!(:seller => true, :insane => true,  :stupid => true) # all ON

        conditions = User.bitfield_sql({:seller => false, :insane => false,  :stupid => false}, :query_mode => :bit_operator_or)
        User.where(conditions).should == [u1, u2, u3]

        conditions = User.bitfield_sql({:seller => false, :stupid => false}, :query_mode => :bit_operator_or)
        User.where(conditions).should == [u1, u3]

        conditions = User.bitfield_sql({:seller => false}, :query_mode => :bit_operator_or)
        User.where(conditions).should == [u1]

        conditions = User.bitfield_sql({:seller => false, :insane => false,  :stupid => true}, :query_mode => :bit_operator_or)
        User.where(conditions).should == [u1, u2, u4]
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

    it "checks that bitfields are powers of two" do
      lambda{
        CheckRaise.class_eval do
          bitfield :foo, 1 => :bar, 3 => :baz, 4 => :bar
        end
      }.should raise_error("3 is not a power of 2 !!")

      lambda{
        CheckRaise.class_eval do
          bitfield :foo, 1 => :bar, -1 => :baz, 4 => :bar
        end
      }.should raise_error("-1 is not a power of 2 !!")
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
      -> {
        OverwrittenUser.bitfield_column(:seller)
      }.should raise_error(RuntimeError)
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

  describe "rspec matchers" do
    subject { User.new }

    it { should have_a_bitfield :seller }
    it { should_not have_a_bitfield :pickle_eater }
  end
end
