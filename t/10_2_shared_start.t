package t10 ;

use strict ;
use Test ;


BEGIN {
	require Inline::Java::Portable ;
	if ($ENV{PERL_INLINE_JAVA_JNI}){
		plan(tests => 0) ;
		exit ;
	}
	elsif (! Inline::Java::Portable::portable("DETACH_OK")){
		plan(tests => 0) ;
		exit ;
	}
	else{		
		plan(tests => 4) ;
	}
}


use Inline Config => 
           DIRECTORY => './_Inline_test' ;

use Inline (
	Java => 't/shared.java',
	SHARED_JVM => 1,
	NAME => 't10',
) ;


my $t = new t10::t10() ;
{
	ok($t->{i}++, 5) ;
	ok(Inline::Java::i_am_JVM_owner()) ;
	Inline::Java::release_JVM() ;
	ok(! Inline::Java::i_am_JVM_owner()) ;
}

ok($t->__get_private()->{proto}->ObjectCount(), 1) ;

