use strict ;
use Test ;

use Inline Config => 
           DIRECTORY => './_Inline_test';

use Inline(
	Java => 'DATA'
) ;


BEGIN {
	plan(tests => 7) ;
}


# Methods
ok(types->get("key"), undef) ;
my $t = new types("key", "value") ;
ok($t->get("key"), "value") ;

# Members
ok($types::i == 5) ;
$types::i = 7 ;
ok($t->{i} == 7) ;

my $t2 = new types("key2", "value2") ;
my $hm = $types::hm ;
ok(types->get($hm, "key2"), "value2") ;

$types::hm = $hm ;
ok($t2->get("key2"), "value2") ;

# Calling an instance method without an object reference
eval {types->set()} ; ok($@, qr/must be called from an object reference/) ;


__END__

__Java__


import java.util.* ;


class types {
	public static int i = 5 ;
	public static HashMap hm = new HashMap() ;

	public types(String k, String v){
		hm.put(k, v) ;
	}

	public static String get(String k){
		return (String)hm.get(k) ; 
	}

	public static String get(HashMap h, String k){
		return (String)h.get(k) ; 
	}

	public String set(){
		return "set" ;
	}
}

