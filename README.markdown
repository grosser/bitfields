Save migrations and columns by storing multiple booleans in a single integer.  
e.g. 3 = 1->true 2->true 4->false, 4 = 1->false 2->false 4->true, 5 = 1->true 2->false 4->true

    class User < ActiveRecord::Base
      include Bitfields
      bitfield :my_bits, 1 => :seller, 2 => :insane, 4 => :stupid
    end

    user = User.new(:seller => true, :insane => true)
    user.seller == true
    user.stupid? == false
    user.my_bits == 9

 - records changes `user.chamges == {:seller => [false, true]}`
 - adds scopes `User.seller.stupid.first` (deactivate with `bitfield ..., :scopes => false`)
 - builds sql `User.bitfield_sql(:insane => true, :stupid => false) == 'users.my_bits IN (2, 3)'` (2 and 1+2)
 - builds not-index-using sql with `bitfield ... ,:query_mode => :bit_operator` and `User.bitfield_sql(:insane => true, :stupid => false) == '(users.my_bits & 3) = 1'`, always slower than IN() sql, since it will not use an existing index (tested for up to 64 values)
 - builds update sql `User.set_bitfield_sql(:insane => true, :stupid => false) == 'my_bits = (my_bits | 6) - 4'`
 - gives access to bits `User.bitfields[:my_bits][:stupid] == 4`

Install
=======
As Gem: ` sudo gem install bitfields `  
Or as Rails plugin: ` script/plugins install git://github.com/grosser/bitfields.git `

### Migration
ALWAYS set a default, bitfield queries will not work for NULL
    t.integer :my_bits, :default => 0, :null => false
    OR
    add_column :users, :my_bits, :integer, :default => 0, :null => false

Usage
=====

    # update all users
    User.seller.not_stupid.update_all(User.set_bitfield_sql(:seller => true, :insane => true))

    # delete the shop when a user is no longer a seller
    before_save :delete_shop, :if => lambda{|u| u.changes['seller'] == [true, false]}

Author
======
[Michael Grosser](http://pragmatig.wordpress.com)  
grosser.michael@gmail.com  
Hereby placed under public domain, do what you want, just do not hold me accountable...