use ExtUtils::MakeMaker ;

use strict ;

WriteMakefile(
	NAME => 'Inline::Java::Natives',
	VERSION_FROM => 'Natives.pm',
	INC => join(' ', @main::I),
	LIBS => [join(' ', @main::L) . " -ljvm"],
	# CCFLAGS => '-D_REENTRANT',
) ;

