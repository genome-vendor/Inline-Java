use ExtUtils::MakeMaker ;

use strict ;
use File::Spec ;

require "Java/Portable.pm" ;

# Replace everything just like out-of-the-box...
my $xs = File::Spec->catfile("Java", "JNI.xs") ;
rename($xs . "_", "$xs") ;

print "\nWelcome to the Inline::Java installation procedure.\n\n" ;

WriteMakefile(
	NAME => 'Inline::Java',
	VERSION_FROM => 'Java.pm',
	PREREQ_PM => {
		Inline	=> 0.43
	},
	clean => {FILES => '_Inline_test/'},
) ;


if (Inline::Java::Portable::portable('COMMAND_COM')){
	print "\nFixing Makefile for Win95/98/Me...\n" ;
	open(MAKEFILE, "<Makefile") or die "Can't open Makefile for reading" ;
	my @lines = <MAKEFILE> ;
	close(MAKEFILE) ;
	open(MAKEFILE, ">Makefile") or die "Can't open Makefile for writing" ;
	foreach my $line (@lines){
		if ($line !~ /^\s*((\@\[)|(\]))\s*$/){
			print MAKEFILE $line ;
		}
	}
	close(MAKEFILE) ;
}

