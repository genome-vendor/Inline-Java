package Inline::Java::JNI ;
@Inline::Java::JNI::ISA = qw(DynaLoader) ;


use strict ;

$Inline::Java::JNI::VERSION = '0.20' ;

use Carp ;


eval {
	Inline::Java::JNI->bootstrap($Inline::Java::JNI::VERSION) ;
} ;
if ($@){
	croak "Can't load JNI module. Did you build it at install time?\nError: $@" ;
}



1 ;
