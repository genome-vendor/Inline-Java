use ExtUtils::MakeMaker;


# So that the the sub dir Makefile.PL will see it...
$main::JNI_BUILD = 0 ;


# In case we had built differently a previous time
rename("Java/JNI.xs_", "Java/JNI.xs") ;


my $fix_makefile = 0 ;
foreach my $arg (@ARGV){
	my $a = $arg ;
	$a =~ s/^\s+// ;
	$a =~ s/\s+$// ;

	if ($a =~ /^JNI$/i){
		$JNI_BUILD = 1 ;
	}
	elsif ($a =~ /^FIX$/i){
		$fix_makefile = 1 ;
	}
}


WriteMakefile(
	NAME => 'Inline::Java',
	VERSION_FROM => 'Java.pm',
	PREREQ_PM => {
		Inline	=> 0.41
	},
	clean => {FILES => '_Inline_test/'},
) ;


if ($fix_makefile){
	print "\nFixing Makefile for Win32...\n" ;
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

