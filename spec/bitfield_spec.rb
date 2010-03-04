require 'spec/spec_helper'

class User < ActiveRecord::Base
  extend Bitfield
  bitfield :bits, 1 => :seller, 2 => :insane, 4 => :stupid
end

class UserWithBitfieldOptions < ActiveRecord::Base
  extend Bitfield
  bitfield :bits, 1 => :seller, 2 => :insane, 4 => :stupid, :named_scopes => true
end

class MultiBitUser < ActiveRecord::Base
  extend Bitfield
  bitfield :bits, 1 => :seller, 2 => :insane, 4 => :stupid
  bitfield :more_bits, 1 => :one, 2 => :two, 4 => :four
end


describe Bitfield do
  describe :bitfields do
    it "parses them correctly" do
      User.bitfields.should == {:bits => {:seller => 1, :insane => 2, :stupid => 4}}
    end
  end

  describe :bitfield_options do
    it "parses them correctly when not set" do
      User.bitfield_options.should == {:bits => {}}
    end

    it "parses them correctly when set" do
      UserWithBitfieldOptions.bitfield_options.should == {:bits => {:named_scopes => true}}
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
  end

  describe :bitfield_sql do
    it "includes true states" do
      User.bitfield_sql(:insane => true).should == 'users.bits IN (2,3,6,7)' # 2, 1+2, 2+4, 1+2+4
    end

    it "includes invalid states" do
      User.bitfield_sql(:insane => false).should == 'users.bits IN (0,1,4,5)' # 0, 1, 4, 4+1
    end

    it "can combine multiple fields" do
      User.bitfield_sql(:seller => true, :insane => true).should == 'users.bits IN (3,7)' # 1+2, 1+2+4
    end

    it "can combine multiple fields with different values" do
      User.bitfield_sql(:seller => true, :insane => false).should == 'users.bits IN (1,5)' # 1, 1+4
    end

    it "combines multiple columns into one sql" do
      sql = MultiBitUser.bitfield_sql(:seller => true, :insane => false, :one => true, :four => true)
      sql.should == 'users.bits IN (1,5) AND users.more_bits IN (5,7)' # 1, 1+4 AND 1+4, 1+2+4
    end
  end
end