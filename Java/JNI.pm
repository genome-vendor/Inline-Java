package Inline::Java::JNI ;
@Inline::Java::JNI::ISA = qw(DynaLoader) ;


use strict ;

$Inline::Java::JNI::VERSION = '0.31' ;

use DynaLoader ;
use Carp ;
use File::Basename ;


# A place to attach the Inline object that is currently in Java land
$Inline::Java::JNI::INLINE_HOOK = undef ;


eval {
	Inline::Java::JNI->bootstrap($Inline::Java::JNI::VERSION) ;
} ;
if ($@){
	croak "Can't load JNI module. Did you build it at install time?\nError: $@" ;
}


1 ;
