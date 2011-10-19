Save migrations and columns by storing multiple booleans in a single integer.<br/>
e.g. true-false-false = 1, false-true-false = 2,  true-false-true = 5 (1,2,4,8,..)

    class User < ActiveRecord::Base
      include Bitfields
      bitfield :my_bits, 1 => :seller, 2 => :insane, 4 => :stupid
    end

    user = User.new(:seller => true, :insane => true)
    user.seller == true
    user.stupid? == false
    user.my_bits == 3

 - records changes `user.chamges == {:seller => [false, true]}`
 - adds scopes `User.seller.stupid.first` (deactivate with `bitfield ..., :scopes => false`)
 - builds sql `User.bitfield_sql(:insane => true, :stupid => false) == '(users.my_bits & 3) = 1'`
 - builds index-using sql with `bitfield ... ,:query_mode => :in_list` and `User.bitfield_sql(:insane => true, :stupid => false) == 'users.my_bits IN (2, 3)'` (2 and 1+2), often slower than :bit_operator sql especially for high number of bits
 - builds update sql `User.set_bitfield_sql(:insane => true, :stupid => false) == 'my_bits = (my_bits | 6) - 4'`
 - **faster sql than any other bitfield lib** through combination of multiple bits into a single sql statement
 - gives access to bits `User.bitfields[:my_bits][:stupid] == 4`

Install
=======
As Gem: ` sudo gem install bitfields `<br/>
Or as Rails plugin: ` rails plugin install git://github.com/grosser/bitfields.git `

### Migration
ALWAYS set a default, bitfield queries will not work for NULL

    t.integer :my_bits, :default => 0, :null => false
    OR
    add_column :users, :my_bits, :integer, :default => 0, :null => false

Examples
========
Update all users

    User.seller.not_stupid.update_all(User.set_bitfield_sql(:seller => true, :insane => true))

Delete the shop when a user is no longer a seller

    before_save :delete_shop, :if => lambda{|u| u.changes['seller'] == [true, false]}

TIPS
====
 - [Upgrading] in version 0.2.2 the first field(when not given as hash) used bit 2 -> add a bogus field in first position
 - [Defaults] afaik it is not possible to have some bits true by default (without monkeypatching AR/see [tests](https://github.com/grosser/bitfields/commit/2170dc546e2c4f1187089909a80e8602631d0796)) -> choose a good naming like `xxx_on` / `xxx_off` to use the default 'false'
 - Never do: "#{bitfield_sql(...)} AND #{bitfield_sql(...)}", merge both into one hash
 - bit_operator is faster in most cases, use :query_mode => :in_list sparingly
 - Standard mysql integer is 4 byte -> 32 bitfields
 - If you are lazy or bad at math you can also do `bitfields :bits, :foo, :bar, :baz`

Query-mode Benchmark
=========
The `:query_mode => :in_list` is slower for most queries and scales mierably with the number of bits.<br/>
*Stay with the default query-mode*. Only use :in_list if your edge-case shows better performance.

![performance](http://chart.apis.google.com/chart?chtt=bit-operator+vs+IN+--+with+index&chd=s:CEGIKNPRUW,DEHJLOQSVX,CFHKMPSYXZ,DHJMPSVYbe,DHLPRVZbfi,FKOUZeinsx,FLQWbglqw2,HNTZfkqw19,BDEGHJLMOP,BDEGIKLNOQ,BDFGIKLNPQ,BDFGILMNPR,BDFHJKMOQR,BDFHJLMOQS,BDFHJLNPRT,BDFHJLNPRT&chxt=x,y&chxl=0:|100K|200K|300K|400K|500K|600K|700K|800K|900K|1000K|1:|0|1441.671ms&cht=lc&chs=600x500&chdl=2bits+%28in%29|3bits+%28in%29|4bits+%28in%29|6bits+%28in%29|8bits+%28in%29|10bits+%28in%29|12bits+%28in%29|14bits+%28in%29|2bits+%28bit%29|3bits+%28bit%29|4bits+%28bit%29|6bits+%28bit%29|8bits+%28bit%29|10bits+%28bit%29|12bits+%28bit%29|14bits+%28bit%29&chco=0000ff,0000ee,0000dd,0000cc,0000bb,0000aa,000099,000088,ff0000,ee0000,dd0000,cc0000,bb0000,aa0000,990000,880000)

TODO
====
 - convenient named scope `User.with_bitfields(:xxx=>true, :yy=>false)`

Authors
=======
### [Contributors](http://github.com/grosser/bitfields/contributors)
 - [Hellekin O. Wolf](https://github.com/hellekin)

[Michael Grosser](http://grosser.it)<br/>
michael@grosser.it<br/>
Hereby placed under public domain, do what you want, just do not hold me accountable...<br/>
[![Build Status](https://secure.travis-ci.org/grosser/bitfields.png)](http://travis-ci.org/grosser/bitfields)

