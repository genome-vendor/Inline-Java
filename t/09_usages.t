use strict ;
use Test ;


use Inline Config => 
           DIRECTORY => './_Inline_test';


BEGIN {
	plan(tests => 4) ;
}



package t09::p1 ;
use Inline(
	Java => qq |
		class t09p1 {
			public static String name = "p1" ;

			public t09p1(){
			}
		}
	|,
	NAME => 't09::p1',
) ;


package t09::p2 ;
use Inline(
	Java => qq |
		class t09p2 {
			public static String name = "p2" ;
		}
	|,
	NAME => 't09::p2',
) ;



package t09::p3 ;
Inline->bind(
	Java => qq |
		class t09p3 {
			public static String name = "p3" ;
		}
	|,
	NAME => 't09::p3',
) ;


package main ;

my $t = new t09::p1::t09p1() ;

{
	ok($t->{name}, "p1") ;
	ok($t09::p2::t09p2::name . $t09::p3::t09p3::name, "p2p3") ;
	ok($t09::p2::t09p2::name . $t09::p3::t09p3::name, "p2p3") ;
}

ok($t->__get_private()->{proto}->ObjectCount(), 1) ;
