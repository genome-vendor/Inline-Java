use ExtUtils::MakeMaker ;

use strict ;

WriteMakefile(
	NAME => 'Inline::Java::PerlNatives',
	VERSION_FROM => 'PerlNatives.pm',
	INC => join(' ', @main::I),
	LIBS => [join(' ', @main::L) . " -ljvm"],
	# CCFLAGS => '-D_REENTRANT',
    clean => {FILES => "_Inline_test"},
) ;

