use ExtUtils::MakeMaker;


# So that the the sub dir Makefile.PL will see it...
$main::JNI_BUILD = 0 ;


# In case we had built differently a previous time
rename("Java/JNI.xs_", "Java/JNI.xs") ;


foreach my $arg (@ARGV){
	my $a = $arg ;
	$a =~ s/^\s+// ;
	$a =~ s/\s+$// ;

	if ($a =~ /^JNI$/i){
		$JNI_BUILD = 1 ;
		last ;
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
