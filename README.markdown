Save migrations and columns by storing multiple booleans in a single integer.

    class User < ActiveRecord::Base
      extend Bitfield
      bitfield :my_bits, 1 => :seller, 2 => :insane, 4 => :stupid
    end

    user = User.new(:seller => true, :insane => true)
    user.seller == true
    user.stupid? == false
    user.my_bits == 9

 - reader and writers
 - records changes `user.chamges == {:seller => [false, true], :insane => [false, true]}`
 - provides scopes with `:named_scopes => true` so we can do `User.seller.stupid.first`
 - **FAST** sql via `User.bitfield_sql(:insane => true, :stupid => false) == 'users.my_bits IN (2, 3)' # 2, 1+2`
 - setter sql via `User.set_bitfield_sql(:insane => true) == 'TODO'`
 - simple access to bits e.g. `User.bitfields[:my_bits][:stupid] == 4`

Install
=======
As Gem: ` sudo gem install bitfield `
Or as Rails plugin: ` script/plugins install git://github.com/grosser/bitfield.git `

Authors
=======
[Michael Grosser](http://pragmatig.wordpress.com)  
grosser.michael@gmail.com  
Hereby placed under public domain, do what you want, just do not hold me accountable...