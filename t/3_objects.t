use strict ;
use Test ;

use Inline Config => 
           DIRECTORY => './_Inline_test';

use Inline(
	Java => 'DATA'
) ;


BEGIN {
	plan(tests => 13) ;
}


# Create some objects
my $t = new types() ;

my $obj1 = new obj1() ;
eval {my $obj2 = new obj2()} ; ok($@, qr/No public constructor/) ;
my $obj11 = new obj11() ;

ok($t->_obj1(undef), undef) ;
ok($t->_obj1($obj1)->get_data(), "obj1") ;
ok($t->_obj11($obj11)->get_data(), "obj11") ;
ok($t->_obj1($obj11)->get_data(), "obj11") ;
eval {$t->_int($obj1)} ; ok($@, qr/Can't convert (.*) to primitive int/) ;
eval {$t->_obj11($obj1)} ; ok($@, qr/is not a kind of/) ;

# Receive an unbound object and send it back
my $unb = $t->get_unbound() ;
ok($t->send_unbound($unb), "al_elem") ;

# Unexisting method
eval {$t->toto()} ; ok($@, qr/No public method/) ;

# Method on unbound object
eval {$unb->toto()} ; ok($@, qr/Can't call method/) ;

# Incompatible prototype, 1 signature
eval {$t->_obj1(5)} ; ok($@, qr/Can't convert/) ;

# Incompatible prototype, >1 signature
eval {$t->__obj1(5)} ; ok($@, qr/Can't find any signature/) ;

# Return a scalar hidden in an object.
ok($t->_olong(), 12345) ;


__END__

__Java__

import java.util.* ;


class obj1 {
	String data = "obj1" ;

	public obj1() {
	}

	public String get_data(){
		return data ;
	}
}

class obj11 extends obj1 {
	String data = "obj11" ;

	public obj11() {
	}

	public String get_data(){
		return data ;		
	}
}


class obj2 {
	String data = "obj2" ;

	obj2() {
	}

	public String get_data(){
		return data ;		
	}
}


class types {
	public types(){
	}

	public int _int(int i){
		return i + 1 ;
	}

	public Object _Object(Object o){
		return o ;
	}

	public obj1 _obj1(obj1 o){
		return o ;
	}


	public obj1 __obj1(obj1 o, int i){
		return o ;
	}


	public obj1 __obj1(obj1 o){
		return o ;
	}


	public obj11 _obj11(obj11 o){
		return o ;
	}

	public ArrayList get_unbound(){
		ArrayList al = new ArrayList() ;
		al.add(0, "al_elem") ;

		return al ;
	}

	public String send_unbound(ArrayList al){
		return (String)al.get(0) ;
	}

	public Object _olong(){
		return new Long("12345") ;
	}
}
