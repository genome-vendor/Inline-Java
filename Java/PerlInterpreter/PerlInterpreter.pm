package Inline::Java::PerlInterpreter ;

use strict ;
use Inline::Java ;

$Inline::Java::PerlInterpreter::VERSION = '0.50' ;


use Inline (
	Java => 'STUDY',
	EMBEDDED_JNI => 1,
	STUDY => [],
	NAME => 'Inline::Java::PerlInterpreter',
) ;



sub java_eval {
	my $code = shift ;

	my $ret = eval $code ;
	if ($@){
		die($@) ;
	}

	return $ret ;
}


sub java_require {
	my $module = shift ;

	return java_eval("require $module ;") ;
}

1 ;
