use strict ;
use Test ;

use Inline Config => 
           DIRECTORY => './_Inline_test';

use Inline(
	Java => 'DATA',
) ;

use Inline::Java qw(cast) ;


BEGIN {
	plan(tests => 16) ;
}


my $t = new types() ;
my $t1 = new t1() ;

ok($t->func(5), "int") ;
ok($t->func(cast("char", 5)), "char") ;
ok($t->func(55), "int") ;
ok($t->func("str"), "string") ;
ok($t->func(cast("java.lang.StringBuffer", "str")), "stringbuffer") ;

ok($t->f($t->{hm}), "hashmap") ;
ok($t->f(cast("java.lang.Object", $t->{hm})), "object") ;

ok($t->f(["a", "b", "c"]), "string[]") ;

ok($t->f(["12.34", "45.67"]), "double[]") ;
ok($t->f(cast("java.lang.Object", ['a'], "[Ljava.lang.String;")), "object") ;

eval {$t->func($t1)} ; ok($@, qr/Can't find any signature/) ;
eval {$t->func(cast("int", $t1))} ; ok($@, qr/Can't convert (.*) to primitive int/) ;

my $t2 = new t2() ;
ok($t2->f($t2), "t1") ;
ok($t1->f($t2), "t1") ;
ok($t2->f($t1), "t2") ;
ok($t2->f(cast("t1", $t2)), "t2") ;


__END__

__Java__


import java.util.* ;

class t1 {
	public t1(){
	}

	public String f(t2 o){
		return "t1" ;
	}
}


class t2 extends t1 {
	public t2(){
	}

	public String f(t1 o){
		return "t2" ;
	}
}


class types {
	public HashMap hm = new HashMap() ;

	public types(){
	}

	public String func(String o){
		return "string" ;
	}

	public String func(StringBuffer o){
		return "stringbuffer" ;
	}

	public String func(int o){
		return "int" ;
	}

	public String func(char o){
		return "char" ;
	}

	public	String f(HashMap o){
		return "hashmap" ;
	}

	public String f(Object o){
		return "object" ;
	}

	public String f(String o[]){
		return "string[]" ;
	}

	public String f(double o[]){
		return "double[]" ;
	}
}

