use ExtUtils::MakeMaker ;
use ExtUtils::Embed ;
use Config ;

use strict ;
require "../Portable.pm" ;


my $ccopts = ccopts() ;
chomp($ccopts) ;
my $ldopts = ldopts() ;
chomp($ldopts) ;

my $pre = Inline::Java::Portable::portable("PRE_WHOLE_ARCHIVE") ;
my $post = Inline::Java::Portable::portable("POST_WHOLE_ARCHIVE") ;

WriteMakefile(
	NAME => 'Inline::Java::PerlInterpreter',
	VERSION_FROM => 'PerlInterpreter.pm',
	CCFLAGS => $ccopts,
	LDDLFLAGS => "$pre $ldopts $post $Config{lddlflags}",
	INC => join(' ', @main::I),
	# CCFLAGS => '-D_REENTRANT',
) ;

