use strict ;
use Test ;

BEGIN {
	plan(tests => 1) ;
}

mkdir('./_Inline_test', 0777) unless -e './_Inline_test' ;

if ($ENV{PERL_INLINE_JAVA_JNI}){
	print STDERR "\nUsing JNI extension.\n" ;
}

ok(1) ;
