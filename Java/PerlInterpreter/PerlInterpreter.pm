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


1 ;
