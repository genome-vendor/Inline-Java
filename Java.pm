package Inline::Java ;
@Inline::Java::ISA = qw(Inline Exporter) ;

# Export the cast function if wanted
@EXPORT_OK = qw(cast study_classes caught) ;


use strict ;

$Inline::Java::VERSION = '0.33' ;


# DEBUG is set via the DEBUG config
if (! defined($Inline::Java::DEBUG)){
	$Inline::Java::DEBUG = 0 ;
}


# Set DEBUG stream
*DEBUG_STREAM = *STDERR ;


require Inline ;
use Carp ;
use Config ;
use File::Copy ;
use Cwd ;
use Data::Dumper ;

use IO::Socket ;
use File::Spec ;

use Inline::Java::Portable ;
use Inline::Java::Class ;
use Inline::Java::Object ;
use Inline::Java::Array ;
use Inline::Java::Protocol ;
use Inline::Java::Callback ;
# Must be last.
use Inline::Java::Init ;
use Inline::Java::JVM ;


# This is set when the script is over.
my $DONE = 0 ;


# This is set when at least one JVM is loaded.
my $JVM = undef ;


# This hash will store the $o objects...
my $INLINES = {} ;


# This stuff is to control the termination of the Java Interpreter
sub done {
	my $signal = shift ;

	# To preserve the passed exit code...
	# Thanks Maria
	my $ec = $? ;

	$DONE = 1 ;

	if (! $signal){
		Inline::Java::debug(1, "killed by natural death.") ;
	}
	else{
		Inline::Java::debug(1, "killed by signal SIG$signal.") ;
	}

	shutdown_JVM() ;
	
	Inline::Java::debug(1, "exiting with $ec") ;

	CORE::exit($ec) ;
}


END {
	if ($DONE < 1){
		done() ;
	}
}


# To export the cast function and others.
sub import {
    Inline::Java->export_to_level(1, @_) ;
}



######################## Inline interface ########################



# Register this module as an Inline language support module
sub register {
	return {
		language => 'Java',
		aliases => ['JAVA', 'java'],
		type => 'interpreted',
		suffix => 'jdat',
	} ;
}


sub validate {
	my $o = shift ;

	return $o->_validate(0, @_) ;
}


# Here validate is overridden because some of the config options are needed
# at load as well.
sub _validate {
	my $o = shift ;
	my $ignore_other_configs = shift ;

	if (! exists($o->{ILSM}->{PORT})){
		$o->{ILSM}->{PORT} = 7890 ;
	}
	if (! exists($o->{ILSM}->{STARTUP_DELAY})){
		$o->{ILSM}->{STARTUP_DELAY} = 15 ;
	}
	if (! exists($o->{ILSM}->{SHARED_JVM})){
		$o->{ILSM}->{SHARED_JVM} = 0 ;
	}
	if (! exists($o->{ILSM}->{DEBUG})){
		$o->{ILSM}->{DEBUG} = 0 ;
	}
	if (! exists($o->{ILSM}->{JNI})){
		$o->{ILSM}->{JNI} = 0 ;
	}
	if (! exists($o->{ILSM}->{CLASSPATH})){
		$o->{ILSM}->{CLASSPATH} = '' ;
	}
	if (! exists($o->{ILSM}->{WARN_METHOD_SELECT})){
		$o->{ILSM}->{WARN_METHOD_SELECT} = '' ;
	}
	if (! exists($o->{ILSM}->{AUTOSTUDY})){
		$o->{ILSM}->{AUTOSTUDY} = 0 ;
	}

	while (@_) {
		my ($key, $value) = (shift, shift) ;
		if ($key eq 'BIN'){
		    $o->{ILSM}->{$key} = $value ;
		}
		elsif ($key eq 'CLASSPATH'){
		    $o->{ILSM}->{$key} = $value ;
		}
		elsif ($key eq 'WARN_METHOD_SELECT'){
		    $o->{ILSM}->{$key} = $value ;
		}
		elsif (
			($key eq 'PORT')||
			($key eq 'STARTUP_DELAY')){

			if ($value !~ /^\d+$/){
				croak "config '$key' must be an integer" ;
			}
			if (! $value){
				croak "config '$key' can't be zero" ;
			}
			$o->{ILSM}->{$key} = $value ;
		}
		elsif ($key eq 'SHARED_JVM'){
			$o->{ILSM}->{$key} = $value ;
		}
		elsif ($key eq 'DEBUG'){
			$o->{ILSM}->{$key} = $value ;
			$Inline::Java::DEBUG = $value ;
		}
		elsif ($key eq 'JNI'){
			$o->{ILSM}->{$key} = $value ;
		}
		elsif ($key eq 'AUTOSTUDY'){
			$o->{ILSM}->{$key} = $value ;
		}
		elsif ($key eq 'STUDY'){
			$o->{ILSM}->{$key} = $o->check_config_array(
				$key, $value,
				"Java class names") ;
		}
		else{
			if (! $ignore_other_configs){
				croak "'$key' is not a valid config option for Inline::Java";
			}
		}
	}

	if (defined($ENV{PERL_INLINE_JAVA_DEBUG})){
		$Inline::Java::DEBUG = $ENV{PERL_INLINE_JAVA_DEBUG} ;
	}
	$Inline::Java::DEBUG = int($Inline::Java::DEBUG) ;

	if (defined($ENV{PERL_INLINE_JAVA_JNI})){
		$o->{ILSM}->{JNI} = $ENV{PERL_INLINE_JAVA_JNI} ;
	}

	if (defined($ENV{PERL_INLINE_JAVA_SHARED_JVM})){
		$o->{ILSM}->{SHARED_JVM} = $ENV{PERL_INLINE_JAVA_SHARED_JVM} ;
	}

	if (($o->{ILSM}->{JNI})&&($o->{ILSM}->{SHARED_JVM})){
		croak("You can't use the 'SHARED_JVM' option in 'JNI' mode") ;
	}

	$o->set_java_bin() ;

	if ($o->{ILSM}->{JNI}){
		require Inline::Java::JNI ;
	}

	Inline::Java::debug(1, "validate done.") ;
}


sub check_config_array {
	my $o = shift ;
	my $key = shift ;
	my $value = shift ;
	my $desc = shift ;

	if (ref($value) eq 'ARRAY'){
		foreach my $c (@{$value}){
			if (ref($c)){
				croak "config '$key' must be an array of $desc" ;
			}
		}
	}
	else{
		croak "config '$key' must be an array of $desc" ;
	}

	return $value ;
}


sub get_java_config {
	my $o = shift ;
	my $param = shift ;

	return $o->{ILSM}->{$param} ;
}


# In theory we shouldn't need to use this, but it seems
# it's not all accessible by the API yet.
sub get_config {
	my $o = shift ;
	my $param = shift ;

	if (defined($param)){
		return $o->{CONFIG}->{$param} ;
	}
	else{
		return %{$o->{CONFIG}} ;
	}
}


sub get_api {
	my $o = shift ;
	my $param = shift ;

	return $o->{API}->{$param} ;
}


sub set_java_bin {
	my $o = shift ;

	my $cjb = $o->{ILSM}->{BIN} ;
	my $ejb = $ENV{PERL_INLINE_JAVA_BIN} ;
	if ($cjb){
		return $o->find_java_bin([$cjb]) ;
	}
	elsif ($ejb) {
		$o->{ILSM}->{BIN} = $ejb ;
		return $o->find_java_bin([$ejb]) ;
	}

	# Java binaries are assumed to be in $ENV{PATH} ;
	return $o->find_java_bin() ;
}


sub find_java_bin {
	my $o = shift ;
	my $paths = shift ;

	my $java =  "java" . portable("EXE_EXTENSION") ;
	my $javac = "javac" . portable("EXE_EXTENSION") ;

	my $path = $o->find_file_in_path([$java, $javac], $paths) ;
	if (defined($path)){
		$o->{ILSM}->{BIN} = $path ;
	}
	else{
		croak
			"Can't locate your java binaries ('$java' and '$javac'). Please set one of the following to the proper directory:\n" .
			"  - The BIN config option;\n" .
			"  - The PERL_INLINE_JAVA_BIN environment variable;\n" .
			"  - The PATH environment variable.\n" ;
	}
}


sub find_file_in_path {
	my $o = shift ;
	my $files = shift ;
	my $paths = shift ;

	if (! defined($paths)){
		$paths = [File::Spec->path()] ;
	}

	Inline::Java::debug_obj($paths) ;

	foreach my $p (@{$paths}){
		$p =~ s/^\s+// ;
		$p =~ s/\s+$// ;
		Inline::Java::debug(4, "path element: $p") ;
		if ($p !~ /^\s*$/){
			my $found = 0 ;
			foreach my $file (@{$files}){
				my $f = File::Spec->catfile($p, $file) ;
				Inline::Java::debug(4, " candidate: $f\n") ;

				if (-f $f){
					Inline::Java::debug(4, " found file $file in $p") ;
					$found++ ;
				}
			}
			if ($found == scalar(@{$files})){	
				return $p ;
			}
		}
	}

	return undef ;
}


# Parse and compile Java code
sub build {
	my $o = shift ;

	if ($o->{ILSM}->{built}){
		return ;
	}

	my $code = $o->get_api('code') ;
	my $study_only = ($code =~ /^(STUDY|SERVER)$/) ;

	$o->write_java($study_only, $code) ;
	$o->compile($study_only) ;

	$o->{ILSM}->{built} = 1 ;
}


# Writes the java code.
sub write_java {
	my $o = shift ;
	my $study_only = shift ;
	my $code = shift ;

	my $build_dir = $o->get_api('build_dir') ;
	my $modfname = $o->get_api('modfname') ;

	Inline::Java::Portable::mkpath($o, $build_dir) ;

	if (! $study_only){
		my $p = File::Spec->catfile($build_dir, "$modfname.java") ;
		open(Inline::Java::JAVA, ">$p") or
			croak "Can't open $p: $!" ;
		Inline::Java::Init::DumpUserJavaCode(\*Inline::Java::JAVA, $code) ;
		close(Inline::Java::JAVA) ;
	}

	my $p = File::Spec->catfile($build_dir, "InlineJavaServer.java") ;
	open(Inline::Java::JAVA, ">$p") or
		croak "Can't open $p: $!" ;
	Inline::Java::Init::DumpServerJavaCode(\*Inline::Java::JAVA) ;
	close(Inline::Java::JAVA) ;

	$p = File::Spec->catfile($build_dir, "InlineJavaPerlCaller.java") ;
	open(Inline::Java::JAVA, ">$p") or
		croak "Can't open $p: $!" ;
	Inline::Java::Init::DumpCallbackJavaCode(\*Inline::Java::JAVA) ;
	close(Inline::Java::JAVA) ;

	Inline::Java::debug(1, "write_java done.") ;
}


# Run the build process.
sub compile {
	my $o = shift ;
	my $study_only = shift ;

	my $build_dir = $o->get_api('build_dir') ;
	my $modpname = $o->get_api('modpname') ;
	my $modfname = $o->get_api('modfname') ;
	my $suffix = $o->get_api('suffix') ;
	my $install_lib = $o->get_api('install_lib') ;

	my $install = File::Spec->catdir($install_lib, "auto", $modpname) ;

	Inline::Java::Portable::mkpath($o, $install) ;
	$o->set_classpath($install) ;

	my $javac = File::Spec->catfile($o->{ILSM}->{BIN}, 
		"javac" . portable("EXE_EXTENSION")) ;

	my $predir = portable("IO_REDIR") ;

	my $cwd = Cwd::cwd() ;
	if ($o->get_config('UNTAINT')){
		($cwd) = $cwd =~ /(.*)/ ;
	}

	my $source = ($study_only ? '' : "$modfname.java") ;

	# When we run the commands, we quote them because in WIN32 you need it if
	# the programs are in directories which contain spaces. Unfortunately, in
	# WIN9x, when you quote a command, it masks it's exit value, and 0 is always
	# returned. Therefore a command failure is not detected.
	# copy_classes will take care of checking whether there are actually files
	# to be copied, and if not will exit the script.
	foreach my $cmd (
		"\"$javac\" InlineJavaServer.java $source > cmd.out $predir",
		["copy_classes", $o, $install],
		["touch_file", $o, File::Spec->catfile($install, "$modfname.$suffix")],
		) {

		if ($cmd){

			chdir $build_dir ;
			if (ref($cmd)){
				Inline::Java::debug_obj($cmd) ;
				my $func = shift @{$cmd} ;
				my @args = @{$cmd} ;

				Inline::Java::debug(3, "$func" . "(" . join(", ", @args) . ")") ;

				no strict 'refs' ;
				my $ret = $func->(@args) ;
				if ($ret){
					croak $ret ;
				}
			}
			else{
				if ($o->get_config('UNTAINT')){
					($cmd) = $cmd =~ /(.*)/ ;
				}

				Inline::Java::debug(3, "$cmd") ;
				my $res = system($cmd) ;
				$res and do {
					croak $o->compile_error_msg($cmd, $cwd) ;
				} ;
			}

			chdir $cwd ;
		}
	}

	if ($o->get_api('cleanup')){
		Inline::Java::Portable::rmpath($o, '', $build_dir) ;
	}

	Inline::Java::debug(1, "compile done.") ;
}


sub compile_error_msg {
	my $o = shift ;
	my $cmd = shift ;
	my $cwd = shift ;

	my $build_dir = $o->get_api('build_dir') ;
	my $error = '' ;
	if (open(Inline::Java::CMD, "<cmd.out")){
		$error = join("", <Inline::Java::CMD>) ;
		close(Inline::Java::CMD) ;
	}

	my $lang = $o->get_api('language') ;
	return <<MSG

A problem was encountered while attempting to compile and install your Inline
$lang code. The command that failed was:
  $cmd

The build directory was:
$build_dir

The error message was:
$error

To debug the problem, cd to the build directory, and inspect the output files.

MSG
;
}


sub copy_classes {
	my $o = shift ;
	my $install = shift ;

	my $build_dir = $o->get_api('build_dir') ;
	my $modpname = $o->get_api('modpname') ;
	my $install_lib = $o->get_api('install_lib') ;

	my $src_dir = $build_dir ;
	my $dest_dir = $install ;

	my @flist = Inline::Java::Portable::find_classes_in_dir(".") ;
	if (portable('COMMAND_COM')){
		if (! scalar(@flist)){
			croak "No files to copy. Previous command failed under command.com?" ;
		}
		foreach my $file (@flist){
			if (! (-s $file)){
				croak "File $file has size zero. Previous command failed under command.com?" ;
			}
		}
	}

	foreach my $file (@flist){
		if ($o->get_config('UNTAINT')){
			($file) = $file =~ /(.*)/ ;
		}
		my $f = File::Spec->catfile($src_dir, $file) ;
		my $t = File::Spec->catfile($dest_dir, $file) ;
		Inline::Java::debug(4, "copy_classes: $file, $t") ;
		if (! File::Copy::copy($file, $t)){
			return "Can't copy $f to $t: $!" ;
		}
	}

	return '' ;
}


sub touch_file {
	my $o = shift ;
	my $file = shift ;

	if (! open(Inline::Java::TOUCH, ">$file")){
		croak "Can't create file $file" ;
	}
	close(Inline::Java::TOUCH) ;

	return '' ;
}


# Load and Run the Java Code.
sub load {
	my $o = shift ;

	if ($o->{ILSM}->{loaded}){
		return ;
	}

	my $install_lib = $o->get_api('install_lib') ;
	my $modfname = $o->get_api('modfname') ;
	my $modpname = $o->get_api('modpname') ;
	my $install = File::Spec->catdir($install_lib, "auto", $modpname) ;

	# Make sure the default options are set.
	$o->_validate(1, $o->get_config()) ;

	# If the JVM is not running, we need to start it here.
	if (! $JVM){
		$o->set_classpath($install) ;
		$JVM = new Inline::Java::JVM($o) ;

		my $pc = new Inline::Java::Protocol(undef, $o) ;
		my $st = $pc->ServerType() ;
		if ((($st eq "shared")&&(! $o->get_java_config('SHARED_JVM')))||
			(($st eq "private")&&($o->get_java_config('SHARED_JVM')))){
			croak "JVM type mismatch on port " . $o->get_java_config('PORT') ;
		}
	}

	# Add our Inline object to the list.
	my $prev_o = $INLINES->{$modfname} ;
	if (defined($prev_o)){
		Inline::Java::debug(2, "module '$modfname' was already loaded, importing binding into new instance") ;
		if (! defined($o->{ILSM}->{data})){
			$o->{ILSM}->{data} = [] ;
		}
		push @{$o->{ILSM}->{data}}, @{$prev_o->{ILSM}->{data}} ;		
	}

	$INLINES->{$modfname} = $o ;

	$o->_study() ;
	if ((defined($o->{ILSM}->{STUDY}))&&(scalar($o->{ILSM}->{STUDY}))){
		$o->_study($o->{ILSM}->{STUDY}) ;
	}

	$o->{ILSM}->{loaded} = 1 ;
}


# This function builds the CLASSPATH environment variable for the JVM
sub set_classpath {
	my $o = shift ;
	my $path = shift ;

	my @list = () ;
	if (defined($ENV{CLASSPATH})){
		push @list, $ENV{CLASSPATH} ;
	}
	if (defined($o->{ILSM}->{CLASSPATH})){
		push @list, $o->{ILSM}->{CLASSPATH} ;
	}
	if (defined($path)){
		push @list, portable("SUB_FIX_CLASSPATH", $path) ;
	}

	my $sep = portable("ENV_VAR_PATH_SEP_CP") ;
	my $cpall = join($sep, @list) ;
	

	$cpall =~ s/\s*\[PERL_INLINE_JAVA\s*=\s*(.*?)\s*\]\s*/{
		my $modules = $1 ;
		Inline::Java::debug(1, "found special CLASSPATH entry: $modules") ;
	
		my @modules = split(m#\s*,\s*#, $modules) ;
		my $dir = File::Spec->catdir($o->get_config('DIRECTORY'), "lib", "auto") ;

		my %paths = () ;
		foreach my $m (@modules){
			$m = File::Spec->catdir(split(m#::#, $m)) ;

			# Here we must make sure that the directory exists, or
			# else it is removed from the CLASSPATH by Java
			my $path = File::Spec->catdir($dir, $m) ;
			Inline::Java::Portable::mkpath($o, $path) ;

			$paths{portable("SUB_FIX_CLASSPATH", $path)} = 1 ;
		}

		join($sep, keys %paths) ;
	}/ge ;

	my @cp = split(/$sep+/, $cpall) ;

	# Add dot to CLASSPATH, required when building
	push @cp, '.' ;

	foreach my $p (@cp){
		$p =~ s/^\s+// ;
		$p =~ s/\s+$// ;
	}

	my @fcp = () ;
	my %cp = map {$_ => 1} @cp ;
	foreach my $p (@cp){
		if ($cp{$p}){
			push @fcp, $p ;
			delete $cp{$p} ;
		}
	}

	$ENV{CLASSPATH} = join($sep, @fcp) ;

	Inline::Java::debug(1, "classpath: " . $ENV{CLASSPATH}) ;
}



# This function 'studies' the specified classes and binds them to 
# Perl
sub _study {
	my $o = shift ;
	my $classes = shift ;

	# Then we ask it to give us the public symbols from the classes
	# that we got.
	my @lines = $o->report($classes) ;

	# Now we read up the symbols and bind them to Perl.
	$o->bind_jdat(
		$o->load_jdat(@lines)
	) ;
}


# This function asks the JVM what are the public symbols for the specified
# classes
sub report {
	my $o = shift ;
	my $classes = shift ;

	my $install_lib = $o->get_api('install_lib') ;
	my $modpname = $o->get_api('modpname') ;
	my $modfname = $o->get_api('modfname') ;
	my $suffix = $o->get_api('suffix') ;
	my $install = File::Spec->catdir($install_lib, "auto", $modpname) ;

	my $use_cache = 0 ;
	if (! defined($classes)){
		$classes = [] ;

		$use_cache = 1 ;

		# We need to take the classes that are in the directory...
		my @cl = Inline::Java::Portable::find_classes_in_dir($install) ;
		foreach my $class (@cl){
			if ($class =~ s/([\w\$]+)\.class$/$1/){
				my $f = $1 ;
				if ($f !~ /^InlineJava(Server|Perl)/){
					push @{$classes}, $f ;
				}
			}
		}
	}

	my @new_classes = () ;
	foreach my $class (@{$classes}){
		$class = Inline::Java::Class::ValidateClass($class) ;

		if (! Inline::Java::known_to_perl($o->get_api('pkg'), $class)){
			push @new_classes, $class ;
		}
	}

	if (! scalar(@new_classes)){
		return () ;
	}

	my $resp = undef ;
	if (($use_cache)&&(! $o->{ILSM}->{built})){
		# Since we didn't build the module, this means that 
		# it was up to date. We can therefore use the data 
		# from the cache
		Inline::Java::debug(1, "using jdat cache") ;
		my $p = File::Spec->catfile($install, "$modfname.$suffix") ;
		my $size = (-s $p) || 0 ;
		if ($size > 0){
			if (open(Inline::Java::CACHE, "<$p")){
				$resp = join("", <Inline::Java::CACHE>) ;
				close(Inline::Java::CACHE) ;
			}
			else{
				croak "Can't open $modfname.$suffix file for reading" ;
			}
		}
	}

	if (! defined($resp)){
		my $pc = new Inline::Java::Protocol(undef, $o) ;
		$resp = $pc->Report(join(" ", @new_classes)) ;
	}

	if (($use_cache)&&($o->{ILSM}->{built})){
		# Update the cache.
		Inline::Java::debug(1, "updating jdat cache") ;
		if (open(Inline::Java::CACHE, ">$install/$modfname.$suffix")){
			print Inline::Java::CACHE $resp ;
			close(Inline::Java::CACHE) ;
		}
		else{
			croak "Can't open $modfname.$suffix file for writing" ;
		}
	}

	return split("\n", $resp) ;
}



# Load the jdat code information file.
sub load_jdat {
	my $o = shift ;
	my @lines = @_ ;

	Inline::Java::debug(5, join("\n", @lines)) ;

	# We need an array here since the same object can have many 
	# study sessions.
	if (! defined($o->{ILSM}->{data})){
		$o->{ILSM}->{data} = [] ;
	}
	my $d = {} ;
	my $data_idx = scalar(@{$o->{ILSM}->{data}}) ;
	push @{$o->{ILSM}->{data}}, $d ;
	
	my $re = '[\w.\$\[;]+' ;

	my $idx = 0 ;
	my $current_class = undef ;
	foreach my $line (@lines){
		chomp($line) ;
		if ($line =~ /^class ($re)$/){
			# We found a class definition
			my $java_class = $1 ;
			$current_class = Inline::Java::java2perl($o->get_api('pkg'), $java_class) ;
			$d->{classes}->{$current_class} = {} ;
			$d->{classes}->{$current_class}->{java_class} = $java_class ;
			$d->{classes}->{$current_class}->{constructors} = {} ;
			$d->{classes}->{$current_class}->{methods} = {} ;
			$d->{classes}->{$current_class}->{fields} = {} ;
		}
		elsif ($line =~ /^constructor \((.*)\)$/){
			my $signature = $1 ;

			$d->{classes}->{$current_class}->{constructors}->{$signature} = 
				{
					SIGNATURE => [split(", ", $signature)],
					STATIC => 1,
					IDX => $idx,
				} ;
		}
		elsif ($line =~ /^method (\w+) ($re) (\w+)\((.*)\)$/){
			my $static = $1 ;
			my $declared_in = $2 ;
			my $method = $3 ;
			my $signature = $4 ;

			if (! defined($d->{classes}->{$current_class}->{methods}->{$method})){
				$d->{classes}->{$current_class}->{methods}->{$method} = {} ;
			}

			$d->{classes}->{$current_class}->{methods}->{$method}->{$signature} = 
				{
					SIGNATURE => [split(", ", $signature)],
					STATIC => ($static eq "static" ? 1 : 0),
					IDX => $idx,
				} ;
		}
		elsif ($line =~ /^field (\w+) ($re) (\w+) ($re)$/){
			my $static = $1 ;
			my $declared_in = $2 ;
			my $field = $3 ;
			my $type = $4 ;

			if (! defined($d->{classes}->{$current_class}->{fields}->{$field})){
				$d->{classes}->{$current_class}->{fields}->{$field} = {} ;
			}

			$d->{classes}->{$current_class}->{fields}->{$field}->{$type} =  
				{
					TYPE => $type,
					STATIC => ($static eq "static" ? 1 : 0),
					IDX => $idx,
				} ;
		}
		$idx++ ;
	}

	Inline::Java::debug_obj($d) ;

	return ($d, $data_idx) ;
}


# Binds the classes and the methods to Perl
sub bind_jdat {
	my $o = shift ;
	my $d = shift ;
	my $idx = shift ;

	my $modfname = $o->get_api('modfname') ;

	if (! defined($d->{classes})){
		return ;
	}

	my %classes = %{$d->{classes}} ;
	foreach my $class (sort keys %classes) {
		my $class_name = $class ;
		$class_name =~ s/^(.*)::// ;

		my $java_class = $d->{classes}->{$class}->{java_class} ;

		my $colon = ":" ;
		my $dash = "-" ;
		
		my $code = <<CODE;
package $class ;
use vars qw(\@ISA \$EXISTS \$JAVA_CLASS \$DUMMY_OBJECT) ;

\@ISA = qw(Inline::Java::Object) ;
\$EXISTS = 1 ;
\$JAVA_CLASS = '$java_class' ;
\$DUMMY_OBJECT = $class$dash>__new(
	\$JAVA_CLASS,
	Inline::Java::get_INLINE('$modfname'),
	0) ;

use Carp ;

CODE

		while (my ($field, $types) = each %{$d->{classes}->{$class}->{fields}}){
			while (my ($type, $sign) = each %{$types}){
				if ($sign->{STATIC}){
					$code .= <<CODE;
tie \$$class$colon:$field, "Inline::Java::Object::StaticMember", 
	\$DUMMY_OBJECT,
	'$field' ;
CODE
					# We have at least one static version of this field,
					# that's enough.
					# Don't forget to reset the 'each' static pointer
					keys %{$types} ;
					last ;
				}
			}
		}


		if (scalar(keys %{$d->{classes}->{$class}->{constructors}})){
			$code .= <<CODE;

sub new {
	my \$class = shift ;
	my \@args = \@_ ;

	my \$o = Inline::Java::get_INLINE('$modfname') ;
	my \$d = \$o->{ILSM}->{data}->[$idx] ;
	my \$signatures = \$d->{classes}->{'$class'}->{constructors} ;
	my (\$proto, \$new_args, \$static) = \$class->__validate_prototype('new', [\@args], \$signatures, \$o) ;

	my \$ret = undef ;
	eval {
		\$ret = \$class->__new(\$JAVA_CLASS, \$o, -1, \$proto, \$new_args) ;
	} ;
	croak \$@ if \$@ ;

	return \$ret ;
}


sub $class_name {
	return new(\@_) ;
}

CODE
		}

		while (my ($method, $sign) = each %{$d->{classes}->{$class}->{methods}}){
			$code .= $o->bind_method($idx, $class, $method) ;
		}

		Inline::Java::debug(5, $code) ;

		# open (Inline::Java::CODE, ">>code") and print CODE $code and close(CODE) ;

		eval $code ;

		croak $@ if $@ ;
	}
}


sub bind_method {
	my $o = shift ;
	my $idx = shift ;
	my $class = shift ;
	my $method = shift ;
	my $static = shift ;

	my $modfname = $o->get_api('modfname') ;
	
	my $code = <<CODE;

sub $method {
	my \$this = shift ;
	my \@args = \@_ ;

	my \$o = Inline::Java::get_INLINE('$modfname') ;
	my \$d = \$o->{ILSM}->{data}->[$idx] ;
	my \$signatures = \$d->{classes}->{'$class'}->{methods}->{'$method'} ;
	my (\$proto, \$new_args, \$static) = \$this->__validate_prototype('$method', [\@args], \$signatures, \$o) ;

	if ((\$static)&&(! ref(\$this))){
		\$this = \$DUMMY_OBJECT ;
	}

	my \$ret = undef ;
	eval {
		\$ret = \$this->__get_private()->{proto}->CallJavaMethod('$method', \$proto, \$new_args) ;
	} ;
	croak \$@ if \$@ ;

	return \$ret ;
}

CODE

	return $code ; 
}


sub get_fields {
	my $o = shift ;
	my $class = shift ;

	my $fields = {} ;
	my $data_list = $o->{ILSM}->{data} ;

	foreach my $d (@{$data_list}){
		if (exists($d->{classes}->{$class})){
			while (my ($field, $value) = each %{$d->{classes}->{$class}->{fields}}){
				# Here $value is a hash that contains all the different
				# types available for the field $field
				$fields->{$field} = $value ;
			}
		}
	}

	return $fields ;
}


# Return a small report about the Java code.
sub info {
	my $o = shift;

	# Make sure the default options are set.
	$o->_validate(1, $o->get_config()) ;

	if ((! $o->get_api('mod_exists'))&&(! $o->{ILSM}->{built})){
		$o->build ;
	}

	if (! $o->{ILSM}->{loaded}){
		$o->load ;
	}

	my $info = '' ;
	my $data_list = $o->{ILSM}->{data} ;

	foreach my $d (@{$data_list}){
		if (! defined($d->{classes})){
			next ;
		}

		my %classes = %{$d->{classes}} ;

		$info .= "The following Java classes have been bound to Perl:\n" ;
		foreach my $class (sort keys %classes) {
			$info .= "\n  class $class:\n" ;

			$info .= "    public methods:\n" ;
			while (my ($k, $v) = each %{$d->{classes}->{$class}->{constructors}}){
				my $name = $class ;
				$name =~ s/^(.*)::// ;
				$info .= "      $name($k)\n" ;
			}

			while (my ($k, $v) = each %{$d->{classes}->{$class}->{methods}}){
				while (my ($k2, $v2) = each %{$d->{classes}->{$class}->{methods}->{$k}}){
					my $static = ($v2->{STATIC} ? "static " : "") ;
					$info .= "      $static$k($k2)\n" ;
				}
			}

			$info .= "    public member variables:\n" ;
			while (my ($k, $v) = each %{$d->{classes}->{$class}->{fields}}){
				while (my ($k2, $v2) = each %{$d->{classes}->{$class}->{fields}->{$k}}){
					my $static = ($v2->{STATIC} ? "static " : "") ;
					my $type = $v2->{TYPE} ;

					$info .= "      $static$type $k\n" ;
				}
			}
		}
	}

    return $info ;
}



######################## General Functions ########################


sub __get_JVM {
	return $JVM ;
}


# For testing purposes only...
sub __clear_JVM {
	$JVM = undef ;
}


sub shutdown_JVM {
	if ($JVM){
		$JVM->shutdown() ;
		$JVM = undef ;
	}
}


sub reconnect_JVM {
	if ($JVM){
		$JVM->reconnect() ;
	}
}


sub capture_JVM {
	if ($JVM){
		$JVM->capture() ;
	}
}


sub i_am_JVM_owner {
	if ($JVM){
		$JVM->am_owner() ;
	}
}


sub release_JVM {
	if ($JVM){
		$JVM->release() ;
	}
}


sub get_INLINE {
	my $module = shift ;

	return $INLINES->{$module} ;
}


sub get_INLINE_nb {
	return scalar(keys %{$INLINES}) ;
}


sub get_DEBUG {
	return $Inline::Java::DEBUG ;
}


sub get_DONE {
	return $DONE ;
}


sub set_DONE {
	$DONE = 1 ;
}


sub java2perl {
	my $pkg = shift ;
	my $jclass = shift ;

	$jclass =~ s/[.\$]/::/g ;

	if ((defined($pkg))&&($pkg)){
		$jclass = $pkg . "::" . $jclass ;
	}

	return $jclass ;
}


sub known_to_perl {
	my $pkg = shift ;
	my $jclass = shift ;

	my $perl_class = java2perl($pkg, $jclass) ;

	no strict 'refs' ;
	if (defined(${$perl_class . "::" . "EXISTS"})){
		Inline::Java::debug(3, "perl knows about '$jclass'") ;
		return 1 ;
	}
	else{
		Inline::Java::debug(3, "perl doesn't know about '$jclass'") ;
	}

	return 0 ;
}


sub debug {
	my $level = shift ;

	if (($Inline::Java::DEBUG)&&($Inline::Java::DEBUG >= $level)){
		my $x = " " x $level ;
		my $str = join("\n$x", @_) ;
		while (chomp($str)) {}
		print DEBUG_STREAM sprintf("[perl][%s]$x%s\n", $level, $str) ;
	}
}


sub debug_obj {
	my $obj = shift ;
	my $force = shift || 0 ;

	if (($Inline::Java::DEBUG >= 5)||($force)){
		debug(5, "Dump:\n" . Dumper($obj)) ;
		if (UNIVERSAL::isa($obj, "Inline::Java::Object")){
			# Print the guts as well...
			debug(5, "Private Dump:" . Dumper($obj->__get_private())) ;
		}
	}
}


sub dump_obj {
	my $obj = shift ;

	return debug_obj($obj, 1) ;
}


######################## Public Functions ########################


sub cast {
	my $type = shift ;
	my $val = shift ;
	my $array_type = shift ;

	my $o = undef ;
	eval {
		$o = new Inline::Java::Class::Cast($type, $val, $array_type) ;
	} ;
	croak $@ if $@ ;

	return $o ;
}


sub study_classes {
	my $classes = shift ;

	Inline::Java::debug(2, "selecting random module to house studied classes...") ;

	# Select a random Inline object to be responsible for these
	# classes
	my @modules = keys %{$INLINES} ;
	srand() ;
	my $idx = int rand @modules ;
	my $module = $modules[$idx] ;

	Inline::Java::debug(2, "selected $module") ;

	my $o = Inline::Java::get_INLINE($module) ;

	return $o->_study($classes) ;
}


sub caught {
	my $class = shift ;

	my $e = $@ ;

	$class = Inline::Java::Class::ValidateClass($class) ;

	my $ret = 0 ;
	if (($e)&&(UNIVERSAL::isa($e, "Inline::Java::Object"))){
		my ($msg, $score) = $e->__isa($class) ;
		if ($msg){
			$ret = 0 ;
		}
		else{
			$ret = 1 ;
		}
	}
	$@ = $e ;

	return $ret ;
}


1 ;

__END__

