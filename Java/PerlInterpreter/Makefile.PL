use ExtUtils::MakeMaker ;
use ExtUtils::Embed ;
use Config ;

use strict ;
require "../Portable.pm" ;


my $ccopts = ccopts() ;
chomp($ccopts) ;
my $ldopts = ldopts() ;
chomp($ldopts) ;

WriteMakefile(
	NAME => 'Inline::Java::PerlInterpreter',
	VERSION_FROM => 'PerlInterpreter.pm',
	CCFLAGS => $ccopts,
	LDDLFLAGS => "-Wl,--whole-archive $ldopts -Wl,--no-whole-archive $Config{lddlflags}",
	INC => join(' ', @main::I),
	# CCFLAGS => '-D_REENTRANT',
) ;

__END__

#!perl

use 5.8.0;
use strict;
use Config;
use ExtUtils::Embed;

my $cmodule = 'PerlInterpreter';


my $ar  = "-Wl,--whole-archive";
my $nar = "-Wl,--no-whole-archive";

run("$Config{cc} -Wall $ar $ccopts $ldopts $nar -o lib$cmodule.so $cmodule.c");
