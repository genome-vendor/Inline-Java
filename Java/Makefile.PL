use ExtUtils::MakeMaker ;
use File::Find ;

use strict ;
use File::Spec ;

require "Portable.pm" ;
# The file we just produced in the parent Makefile.PL
require "default_j2sdk.pl" ;


# Some shortcuts while developing
my $jdk_dir = undef ;
my $build_jni = ($jdk_dir ? 1 : 0) ;

my $jvm_lib = Inline::Java::Portable::portable('JVM_LIB') ;
my $jvm_so = Inline::Java::Portable::portable('JVM_SO') ;

my %so_dirs = () ;

my @files = (
	'jni.h',
	'jni_md.h',
	$jvm_lib,
) ;
if ($jvm_so ne $jvm_lib){
	push @files, $jvm_so ;
}
push @files, 'jvm.cfg' ;

my $files = {
	'jni.h'		=> {
		discard		=> qr/include-old/,
	},
	'jni_md.h'	=> {
		discard		=> qr/include-old/,
	},
	$jvm_lib	=> {
	},
	'jvm.cfg'	=> {
	},
	$jvm_so		=> {
	},
} ;

foreach my $f (@files){
	$files->{$f}->{selected} = undef ;
	$files->{$f}->{choices} = [] ;
	$files->{$f}->{default_choice} = 1 ;
}


print
	"\nInline::Java can use a JNI extension that allows the Java Virtual Machine\n" .
	"(JVM) to be dynamically linked with Perl instead of running as a separate\n" .
	"process. The use of this extension is optional, and building it still\n" .
	"allows Inline::Java to run the JVM in the default (separate process)\n" .
	"fashion.\n" .
	"Note: You need a C compiler to build the extension.\n" .
	"Note: You must build the extension if you wish to use PerlNatives or\n" .
	"      PerlInterpreter.\n" ;

if (($build_jni || AskYN("Do you wish to build the JNI extension?", 'y'))){
	print "\nBuilding JNI extension.\n\n" ;

	$jdk_dir = Inline::Java::get_default_j2sdk() ;

	my $symlink = Inline::Java::Portable::portable("GOT_SYMLINK") ;
	find(
		{
			wanted => \&search,
			($symlink ? (follow => 1, follow_skip => 2) : ()),
		},
		$jdk_dir) ;

	my $type = FindDefaultVMType() ;
	if (defined($type)){
		my $cnt = 1 ;
		foreach my $c (@{$files->{$jvm_so}->{choices}}){
			if ($c =~ /$type/){
				$files->{$jvm_so}->{default_choice} = $cnt ;
			}
			$cnt++ ;
		}
	}

	# We no longer need jvm.cfg from now on...
	pop @files ;

	my $done = 0 ;
	foreach my $f (@files){
		my $cnt = scalar(@{$files->{$f}->{choices}}) ;
		if ($cnt == 0){
			print "Can't locate file '$f' anywhere under '$jdk_dir'\n" ;
			$done = 1 ;
			last ;
		}
		elsif ($cnt == 1){
			$files->{$f}->{selected} = $files->{$f}->{choices}->[0] ;
		}
		else{
			Choose($f) ;
		}
	}
	if (! $done){
		# We have all the required files selected.

		CleanSoDirs() ;

		print "Building with:\n" ;
		map { print "  " . File::Spec->catfile($files->{$_}->{selected}, $_) . "\n" ;} @files ;

		$done = 0 ;
		if (! $done){
			print
				"\nNote: In order for Inline::Java to use the JNI extension, you will need to\n" . 			    
				"use the JNI configuration option or set the PERL_INLINE_JAVA_JNI environment\n" .
				"variable to a true value. You will also need to add the following directories\n" .
				"to your " . Inline::Java::Portable::portable('SO_LIB_PATH_VAR') . " environment variable:\n" ;
			@main::SO_DIRS = keys %so_dirs ;
			map {print "  $_\n"; } @main::SO_DIRS ;
			print "See README.JNI for more information.\n\n" ;

			@main::I = (
				Inline::Java::Portable::portable('SUB_FIX_MAKE_QUOTES', 
					"-I" . $files->{'jni.h'}->{selected}), 
				Inline::Java::Portable::portable('SUB_FIX_MAKE_QUOTES', 
					"-I" . $files->{'jni_md.h'}->{selected})) ; 
			@main::L = (
				Inline::Java::Portable::portable('SUB_FIX_MAKE_QUOTES', 
					"-L" . $files->{$jvm_lib}->{selected})) ;

			my $DIR = [] ;
			print <<TXT;
The PerlNatives extension allows for callbacks to be defined as native
Java methods. It is still EXPERIMENTAL and may not build or work properly
on all platforms. See documentation for more details.
Note: PerlNatives requires J2SDK 1.4 or greater.
TXT
			if (AskYN("Do you wish to build the PerlNatives extension?", 'n')){
				push @{$DIR}, 'PerlNatives' ;
			}
			print "\n" ;

			print <<TXT;
The PerlInterpreter extension allows Inline::Java to be loaded directly from
Java using an embedded Perl interpreter. It is still EXPERIMENTAL and 
may not build or work properly on all platforms. See documentation for 
more details.
TXT
			if (AskYN("Do you wish to build the PerlInterpreter extension?", 'n')){
				push @{$DIR}, 'PerlInterpreter' ;
			}
			print "\n" ;

			WriteMakefile(
				NAME => 'Inline::Java::JNI',
				VERSION_FROM => 'JNI.pm',
				DIR => $DIR,
				PMLIBDIRS => [File::Spec->catdir('sources', 'org', 'perl', 'inline', 'java')],
				INC => join(' ', @main::I),
				LIBS => [join(' ', @main::L) . " -ljvm"],
				# CCFLAGS => '-D_REENTRANT',
			) ;
		}
	}
}
else{
	print "\n" ;
	WriteMakefile(
		NAME => 'Inline::Java::JNI',
		VERSION_FROM => 'JNI.pm',
		DIR => [],
		PMLIBDIRS => [File::Spec->catdir('sources', 'org', 'perl', 'inline', 'java')],
		XS => {},
		C => []
	) ;
}


#################################################


sub search {
	my $file = $_ ;

	my $ext = Inline::Java::Portable::portable('SO_EXT') ;
	if ($File::Find::dir =~ /jre/){
		if ($file =~ /\.$ext$/){
			my $dir = File::Spec->canonpath($File::Find::dir) ;
			$so_dirs{$dir} = 1 ;
		}
	}

	foreach my $f (@files){
		if ($file eq $f){
			my $re = $files->{$f}->{discard} ;
			if ((! $re)||($File::Find::dir !~ /$re/)){
				push @{$files->{$f}->{choices}}, File::Spec->canonpath($File::Find::dir) ;
			}
			last ;
		}
	}
}


sub CleanSoDirs {
	foreach my $d (keys %so_dirs){
		if (-e File::Spec->catfile($d, $jvm_so)){
			delete $so_dirs{$d} ;
		}
		elsif ($d =~ /plugin/){
				delete $so_dirs{$d} ;
		}
		elsif ($d =~ /motif/){
				delete $so_dirs{$d} ;
		}
		elsif ($d =~ /javaws/){
				delete $so_dirs{$d} ;
		}
		elsif ($d =~ /headless/){
				delete $so_dirs{$d} ;
		}
		elsif ($d =~ /xawt/){
				delete $so_dirs{$d} ;
		}
		elsif ($d =~ /_threads/){
			if ($d !~ /native_threads/){
				delete $so_dirs{$d} ;
			}
		}
	}
	$so_dirs{$files->{$jvm_so}->{selected}} = 1 ;
}


sub FindDefaultVMType {
	my $type = undef ;
	my $choices = $files->{'jvm.cfg'}->{choices} ;
	if (scalar(@{$choices})){
		my $cfg = File::Spec->catfile($choices->[0], 'jvm.cfg') ;
		if (open(CFG, "<$cfg")){
			while (<CFG>){
				my $line = $_ ;
				chomp($line) ;
				$line =~ s/^\s+// ;
				$line =~ s/\s+$// ;

				if (! $line){
					next ;
				}
				elsif ($line =~ /^#/){
					next ;
				}
				else{
					($type) = split(/\s+/, $line) ;
					$type =~ s/^-// ;
					last ;
				}
			}
			close(CFG) ;
		}
	}

	return $type ;
}


sub Choose {
	my $f = shift ;

	my $o = $files->{$f} ;
	my $cnt = 0 ;
	my $def = undef ;
	foreach my $f (@{$o->{choices}}){
		$cnt++ ;
		print "$cnt) $f\n" ;
	}
	my $idx = AskSub("Please select from the above list which '$f' to use:",
		$o->{default_choice}, sub {(($_[0] >= 1)&&($_[0] <= $cnt))}) ;

	$o->{selected} = $o->{choices}->[int($idx) - 1] ;
	print "\n" ;
}


# Gets string from stdin
sub Ask {
	my $ques = shift ;
	my $def = shift ;

	return AskSub($ques, $def, undef) ;
}


# Gets yes/no from stdin
sub AskYN {
	my $ques = shift ;
	my $def = shift ;

	my $ans = AskSub($ques, $def, sub {((! $_[0])||($_[0] =~ /^(y|n)$/i))}) ;

	return (($ans =~ /^y$/i) ? 1 : 0) ;
}


sub AskSub {
	my $ques = shift ;
	my $def = shift ;
	my $sub = shift ;

	while (1){
		my $ans = prompt($ques, $def) ;
		if (! $sub){
			return $ans ;
		}
		elsif ($sub->($ans)){
			return $ans ;
		}
	}
}
