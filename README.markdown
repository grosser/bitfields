Save migrations and columns by storing multiple booleans in a single integer.

    class User < ActiveRecord::Base
      extend Bitfield
      bitfield :my_bits, 1 => :is_seller, 2 => :is_dangerous, 4 => :is_stupid, 8 => is_insane
    end

    user = User.new(:is_seller => true, :is_insane => true)
    user.is_seller == true
    user.is_stupid == false
    user.my_bits == 9

 - reader and writers
 - records changes `user.chamges == {:is_seller => [false, true], :is_insane => [false, true]}`
 - provides scopes with `:named_scopes => true` so we can do `User.is_seller.is_stupid.first`
 - query sql via `User.bitfield_sql(:is_insane => true) == '(my_bits NOT IN (TODO))'`
 - setter sql via `User.set_bitfield_sql(:is_insane => true) == 'TODO'`

Install
=======
As Gem: ` sudo gem install bitfield `
Or as Rails plugin: ` script/plugins install git://github.com/grosser/bitfield.git `

Authors
=======
[Michael Grosser](http://pragmatig.wordpress.com)  
grosser.michael@gmail.com  
Hereby placed under public domain, do what you want, just do not hold me accountable...