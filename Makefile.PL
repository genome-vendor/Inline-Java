use ExtUtils::MakeMaker;

WriteMakefile(
	NAME => 'Inline::Java',
	VERSION_FROM => 'Java.pm',
	PREREQ_PM => {
		Inline	=> 0.31
	},
	clean => {FILES => '_Inline_test/'},
);
