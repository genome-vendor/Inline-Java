use ExtUtils::MakeMaker ;
use File::Find ;

use strict ;
use File::Spec ;

require "Portable.pm" ;

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

my $files = {
	'jni.h'		=> {
		discard		=> qr/include-old/,
	},
	'jni_md.h'	=> {
		discard		=> qr/include-old/,
	},
	$jvm_lib	=> {
	},
	$jvm_so		=> {
	},
} ;

foreach my $f (@files){
	$files->{$f}->{selected} = undef ;
	$files->{$f}->{choices} = [] ;
}


print "\n" ;
print
	"Inline::Java can use a JNI extension that allows the Java Virtual Machine\n" .
	"(JVM) to be dynamically linked with Perl instead of running as a separate\n" .
	"process. The use of this extension is optional, and building it still\n" .
	"allows Inline::Java to run the JVM in the default (separate process)\n" .
	"fashion.\n\n" ;

if (($build_jni || AskYN("Do you wish to build the JNI extension?"))){
	print "\nBuilding JNI extension.\n\n" ;

	rename("JNI.xs_", "JNI.xs") ;

	$jdk_dir = ($jdk_dir || AskSub("Enter the path to your Java 2 SDK installation",
		sub {((-d $_[0]) ? 1 : (print("Directory '$_[0]' does not exist.\n") && 0))})) ;
	print "\n" ;

	my $type = FindDefaultVMType() ;

	find(\&search, $jdk_dir) ;

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
			Choose($f, $type) ;
		}
	}
	if (! $done){
		# We have all the required files selected.

		CleanSoDirs() ;

		print "Building with:\n" ;
		foreach my $f (@files){
			print File::Spec->catfile($files->{$f}->{selected}, $f) . "\n" ;
		}
		print "\n" ;

		$done = 0 ;
		# BS file used to be written here

		if (! $done){
			WriteMakefile(
				NAME => 'Inline::Java::JNI',
				VERSION_FROM => 'JNI.pm',
				INC => "-I" . $files->{'jni.h'}->{selected} . " -I" . $files->{'jni_md.h'}->{selected},
				LIBS => ["-L" . $files->{$jvm_lib}->{selected} . " -ljvm"],
			) ;

			print
				"\nNote: In order for Inline::Java to use the JNI extension, you\n" .
				"will need to use the JNI configuration option or set the\n" .
				"PERL_INLINE_JAVA_JNI environment variable to a true value.\n" .
				"You will also need to add the following directories to your\n" .
				Inline::Java::Portable::portable('SO_LIB_PATH_VAR') . " environment variable:\n" ;

			foreach my $d (keys %so_dirs){
				print "  $d\n" ;
			}

			print 
				"See README.JNI for more information.\n" ;

			print "\n" ;
		}
	}
}
else{
	print "\n" ;

	rename("JNI.xs", "JNI.xs_") ;

	WriteMakefile(
		NAME => 'Inline::Java::JNI',
		VERSION_FROM => 'JNI.pm') ;
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
		elsif ($d =~ /_threads/){
			if ($d !~ /native_threads/){
				delete $so_dirs{$d} ;
			}
		}
	}
	$so_dirs{$files->{$jvm_so}->{selected}} = 1 ;
}



sub WriteBSFile {
	if (! open(BS, '>JNI_BS')){
		return 1 ;
	}

	my $so = File::Spec->catfile($files->{$jvm_so}->{selected}, $jvm_so) ;
	print BS <<BS_CODE;
my \$so = '$so' ;
push(\@dl_resolve_using, \$so) ;

\$bscode = <<CODE ;
dl_load_file('\$so', Inline::Java::JNI->dl_load_flags) or
croak("Can't load '\$so' for module Inline::Java::JNI: " . dl_error()) ;
CODE

BS_CODE

	close(BS) ;
	return 0 ;
}


sub FindDefaultVMType {
	my $type = undef ;
	my $cfg = File::Spec->catfile($jdk_dir, "jre", "lib", "jvm.cfg") ;
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
				$type = $line ;
				$type =~ s/^-// ;
				last ;
			}
		}
		close(CFG) ;
	}

	return $type ;
}


sub Choose {
	my $f = shift ;
	my $type = shift ;

	my $o = $files->{$f} ;
	my $cnt = 0 ;
	foreach my $f (@{$o->{choices}}){
		$cnt++ ;
		my $hint = '' ;
		if ($f =~ /$type/){
			$hint = "[your system default]" ;
		}
		print "[$cnt] $f $hint\n" ;
	}
	my $idx = AskSub("Please select from the above list which '$f' to use [1-$cnt]",
		sub {(($_[0] >= 1)&&($_[0] <= $cnt))}) ;

	$o->{selected} = $o->{choices}->[int($idx) - 1] ;
	print "\n" ;
}


# Gets string from stdin
sub Ask {
	my $ques = shift ;

	return AskSub($ques, undef) ;
}


# Gets yes/no from stdin
sub AskYN {
	my $ques = shift ;

	$ques .= " [yn]" ;

	my $ans = AskSub($ques, sub {$_[0] =~ /^(y|n)$/i}) ;

	return (($ans eq "y") ? 1 : 0) ;
}


sub AskSub {
	my $ques = shift ;
	my $sub = shift ;

	my $str = $ques . ": " ;
	print $str ;

	while (<STDIN>){
		my $ans = $_ ;
		chomp($ans) ;
		if (! $sub){
			return $ans ;
		}
		elsif ($sub->($ans)){
			return $ans ;
		}

		print $str ;
	}
}
