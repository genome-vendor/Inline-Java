package Inline::Java ;
@Inline::Java::ISA = qw(Inline Exporter) ;

# Export the cast function if wanted
@EXPORT_OK = qw(cast study_classes) ;


use strict ;

$Inline::Java::VERSION = '0.23' ;


# DEBUG is set via the DEBUG config
if (! defined($Inline::Java::DEBUG)){
	$Inline::Java::DEBUG = 0 ;
}


# Set DEBUG stream
*DEBUG_STREAM = *STDERR ;


require Inline ;
use Carp ;
use Config ;
use FindBin ;
use File::Copy ;
use Cwd ;
use Data::Dumper ;

use IO::Socket ;

use Inline::Java::Class ;
use Inline::Java::Object ;
use Inline::Java::Array ;
use Inline::Java::Protocol ;
# Must be last.
use Inline::Java::Init ;
use Inline::Java::JVM ;


# This is set when the script is over.
my $DONE = 0 ;


# This is set when at least one JVM is loaded.
my $JVM = undef ;

# This hash will store the $o objects...
my $INLINES = {} ;

# Here is some code to figure out if we are running on command.com
# shell under Windows.
my $COMMAND_COM = 
	(
		($^O eq 'MSWin32')&&
		(
			($ENV{PERL_INLINE_JAVA_COMMAND_COM})||
			(
				(defined($ENV{COMSPEC}))&&
				($ENV{COMSPEC} =~ /(command|4dos)\.com/i)
			)||
			(`ver` =~ /win(dows )?(9[58]|m[ei])/i)
		)
	) || 0 ;


# This stuff is to control the termination of the Java Interpreter
sub done {
	my $signal = shift ;

	# To preserve the passed exit code...
	# Thanks Maria
	my $ec = $? ;

	$DONE = 1 ;

	if (! $signal){
		Inline::Java::debug("killed by natural death.") ;
	}
	else{
		Inline::Java::debug("killed by signal SIG$signal.") ;
	}

	if ($JVM){
		undef $JVM ;
	}
	
	Inline::Java::debug("exiting with $ec") ;

	# In Windows, it is possible that the process will hang here if
	# the children are not all dead. But they should be. Really.
	exit($ec) ;
}


END {
	if ($DONE < 1){
		done() ;
	}
}


# Signal stuff, not really needed with JNI
use sigtrap 'handler', \&done, 'normal-signals' ;

# This whole $SIG{__DIE__} thing doesn't work because it is called
# even if the die is trapped inside an eval...
# $SIG{__DIE__} = sub {
	# Setting this to -1 will prevent Inline::Java::Object::DESTROY
	# from executing it's code for object destruction, since the state
	# in possibly unstable.
	# $DONE = -1 ;
#	die @_ ;
# } ;


# To export the cast function.
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

	# if ($o->get_INLINE_nb() == 1){
	# 	croak "Inline::Java does not currently support multiple Inline sections" ;
	# }

	if (! exists($o->{ILSM}->{PORT})){
		$o->{ILSM}->{PORT} = 7890 ;
	}
	if (! exists($o->{ILSM}->{STARTUP_DELAY})){
		$o->{ILSM}->{STARTUP_DELAY} = 15 ;
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

	if (defined($ENV{PERL_INLINE_JAVA_JNI})){
		$o->{ILSM}->{JNI} = $ENV{PERL_INLINE_JAVA_JNI} ;
	}

	$o->set_java_bin() ;

	Inline::Java::debug("validate done.") ;
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

	my $sep = portable("PATH_SEP_RE") ;

	my $cjb = $o->{ILSM}->{BIN} ;
	my $ejb = $ENV{PERL_INLINE_JAVA_BIN} ;
	if ($cjb){
		$cjb =~ s/$sep+$// ;
		return $o->find_java_bin([$cjb]) ;
	}
	elsif ($ejb) {
		$ejb =~ s/$sep+$// ;
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
			"Can't locate your java binaries ('java' and 'javac'). Please set one of the following to the proper directory:\n" .
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
		my $psep = portable("ENV_VAR_PATH_SEP") ;
		$paths = [(split(/$psep/, $ENV{PATH} || ''))] ;
	}

	Inline::Java::debug_obj($paths) ;

	my $home = $ENV{HOME} ;
	my $sep = portable("PATH_SEP_RE") ;

	foreach my $p (@{$paths}){
		Inline::Java::debug("path element: $p") ;
		if ($p !~ /^\s*$/){
			$p =~ s/$sep+$// ;

			if ($p =~ /^~/){
				if ($home){
					$p =~ s/^~/$home/ ;
				}
				else{
					# -f don't work with ~/...
					next ;
				}
			}

			my $found = 0 ;
			foreach my $file (@{$files}){
				my $f = "$p/$file" ;
				Inline::Java::debug("  candidate: $f\n") ;

				if (-f $f){
					Inline::Java::debug("  found file $file in $p") ;
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
	my $study_only = ($code eq 'STUDY') ;

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

	$o->mkpath($build_dir) ;

	if (! $study_only){
		open(JAVA, ">$build_dir/$modfname.java") or
			croak "Can't open $build_dir/$modfname.java: $!" ;
		Inline::Java::Init::DumpUserJavaCode(\*JAVA, $modfname, $code) ;
		close(JAVA) ;
	}

	open(JAVA, ">$build_dir/InlineJavaServer.java") or
		croak "Can't open $build_dir/InlineJavaServer.java: $!" ;
	Inline::Java::Init::DumpServerJavaCode(\*JAVA, $modfname) ;
	close(JAVA) ;

	Inline::Java::debug("write_java done.") ;
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

	my $install = "$install_lib/auto/$modpname" ;
	my $pinstall = portable("RE_FILE", $install) ;

	$o->mkpath("$install") ;
	$o->set_classpath($pinstall) ;

	my $javac = $o->{ILSM}->{BIN} . "/javac" . portable("EXE_EXTENSION") ;

	my $predir = portable("IO_REDIR") ;
	my $pjavac = portable("RE_FILE", $javac) ;

	my $cwd = Cwd::cwd() ;
	if ($o->get_config('UNTAINT')){
		($cwd) = $cwd =~ /(.*)/ ;
	}

	my $debug = ($Inline::Java::DEBUG ? "true" : "false") ;

	my $source = ($study_only ? '' : "$modfname.java") ;

	# When we run the commands, we quote them because in WIN32 you need it if
	# the programs are in directories which contain spaces. Unfortunately, in
	# WIN9x, when you quote a command, it masks it's exit value, and 0 is always
	# returned. Therefore a command failure is not detected.
	# copy_classes will take care of checking whether there are actually files
	# to be copied, and if not will exit the script.
	# This strategy doesn't work that well if you have many classes in the same 
	# file, but we can't penalize the other users just to give better support
	# for Win9x...
	foreach my $cmd (
		"\"$pjavac\" InlineJavaServer.java $source > cmd.out $predir",
		["copy_classes", $o, $install],
		["touch_file", $o, "$install/$modfname.$suffix"],
		) {

		if ($cmd){

			chdir $build_dir ;
			if (ref($cmd)){
				Inline::Java::debug_obj($cmd) ;
				my $func = shift @{$cmd} ;
				my @args = @{$cmd} ;

				Inline::Java::debug("$func" . "(" . join(", ", @args) . ")") ;

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

				Inline::Java::debug("$cmd") ;
				my $res = system($cmd) ;
				$res and do {
					croak $o->compile_error_msg($cmd, $cwd) ;
				} ;
			}

			chdir $cwd ;
		}
	}

	if ($o->get_api('cleanup')){
		$o->rmpath('', $build_dir) ;
	}

	Inline::Java::debug("compile done.") ;
}


sub compile_error_msg {
	my $o = shift ;
	my $cmd = shift ;
	my $cwd = shift ;

	my $build_dir = $o->get_api('build_dir') ;
	my $error = '' ;
	if (open(CMD, "<cmd.out")){
		$error = join("", <CMD>) ;
		close(CMD) ;
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
	my $pinstall = portable("RE_FILE", $install) ;

	my $src_dir = $build_dir ;
	my $dest_dir = $pinstall ;

	my @flist = glob("*.class") ;

	if (portable('COMMAND_COM')){
		if (! scalar(@flist)){
			croak "No files to copy. Previous command failed under command.com?" ;
		}
		foreach my $file (@flist){
			if (! (-s $file)){
				croak "File $file has size zero. Previous command failed under WIN9x?" ;
			}
		}
	}

	foreach my $file (@flist){
		if ($o->get_config('UNTAINT')){
			($file) = $file =~ /(.*)/ ;
		}
		Inline::Java::debug("copy_classes: $file, $dest_dir/$file") ;
		if (! File::Copy::copy($file, "$dest_dir/$file")){
			return "Can't copy $src_dir/$file to $dest_dir/$file: $!" ;
		}
	}

	return '' ;
}


sub touch_file {
	my $o = shift ;
	my $file = shift ;

	my $pfile = portable("RE_FILE", $file) ;

	if (! open(TOUCH, ">$pfile")){
		croak "Can't create file $pfile" ;
	}
	close(TOUCH) ;

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
	my $install = "$install_lib/auto/$modpname" ;
	my $pinstall = portable("RE_FILE", $install) ;

	# Make sure the default options are set.
	$o->_validate(1, $o->get_config()) ;

	# If the JVM is not running, we need to start it here.
	if (! $JVM){
		$o->set_classpath($pinstall) ;
		$JVM = new Inline::Java::JVM($o) ;
	}

	# Add our Inline object to the list.
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
	my @cp = split(/$sep/, join($sep, @list)) ;
	my %cp = map { ($_ !~ /^\s*$/ ? ($_, 1) : ()) } @cp ;

	foreach my $k (keys %cp){
		if ($k =~ /\s*\[PERL_INLINE_JAVA=(.*?)\]\s*/){
			my $modules = $1 ;
			Inline::Java::debug("   found special CLASSPATH entry: $modules") ;

			my @modules = split(/\s*,\s*/, $modules) ;
			my $sep = portable("PATH_SEP") ;
			my $sep_re = portable("PATH_SEP_RE") ;
			my $dir = $o->get_config('DIRECTORY') . $sep . "lib" . $sep ."auto" ;

			foreach my $m (@modules){
				$m =~ s/::/$sep_re/g ;
				$cp{"$dir$sep$m"} = 1 ;
			}

			delete $cp{$k} ;
		}
	}
	$ENV{CLASSPATH} = join($sep, keys %cp) ;

	Inline::Java::debug("  classpath: " . $ENV{CLASSPATH}) ;
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
	my $install = "$install_lib/auto/$modpname" ;
	my $pinstall = portable("RE_FILE", $install) ;

	my $use_cache = 0 ;
	if (! defined($classes)){
		$classes = [] ;

		$use_cache = 1 ;

		# We need to take the classes that are in the directory...
		my @cl = glob("$pinstall/*.class") ;
		foreach my $class (@cl){
			$class =~ s/^\Q$pinstall\E\/(.*)\.class$/$1/ ;
			if ($class !~ /^InlineJavaServer/){
				push @{$classes}, $class ;
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
		Inline::Java::debug("using jdat cache") ;
		my $size = (-s "$install/$modfname.$suffix") || 0 ;
		if ($size > 0){
			if (open(CACHE, "<$install/$modfname.$suffix")){
				$resp = join("", <CACHE>) ;
				close(CACHE) ;
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
		Inline::Java::debug("updating jdat cache") ;
		if (open(CACHE, ">$install/$modfname.$suffix")){
			print CACHE $resp ;
			close(CACHE) ;
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

	if (Inline::Java::debug_all()){
		Inline::Java::debug(join("\n", @lines)) ;
	}

	# We need an array here since the same object can have many 
	# load sessions.
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

			$d->{classes}->{$current_class}->{fields}->{$field} = 
				{
					TYPE => $type,
					STATIC => ($static eq "static" ? 1 : 0),
					IDX => $idx,
				} ;
		}
		$idx++ ;
	}

	if (Inline::Java::debug_all()){
		Inline::Java::debug_obj($d) ;
	}

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

		while (my ($field, $sign) = each %{$d->{classes}->{$class}->{fields}}){
			if ($sign->{STATIC}){
				$code .= <<CODE;
tie \$$class$colon:$field, "Inline::Java::Object::StaticMember", 
			\$DUMMY_OBJECT,
			'$field' ;
CODE
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

		if (Inline::Java::debug_all()){
			Inline::Java::debug($code) ;
		}

		# open (CODE, ">>code") and print CODE $code and close(CODE) ;

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
				my $static = ($v->{STATIC} ? "static " : "") ;
				my $type = $v->{TYPE} ;

				$info .= "      $static$type $k\n" ;
			}
		}
	}

    return $info ;
}



######################## General Functions ########################


sub get_JVM {
	return $JVM ;
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


sub debug_all {
	return (Inline::Java::get_DEBUG() > 1) ;
}


sub get_DONE {
	return $DONE ;
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
		Inline::Java::debug("  returned class exists!") ;
		return 1 ;
	}
	else{
		Inline::Java::debug("  returned class doesn't exist!") ;
	}

	return 0 ;
}


sub debug {
	if ($Inline::Java::DEBUG){
		my $str = join("", @_) ;
		while (chomp($str)) {}
		print DEBUG_STREAM "perl $$: $str\n" ;
	}
}


sub debug_obj {
	my $obj = shift ;
	my $pre = shift || "perl: " ;

	if ($Inline::Java::DEBUG){
		print DEBUG_STREAM $pre . Dumper($obj) ;
		if (UNIVERSAL::isa($obj, "Inline::Java::Object")){
			# Print the guts as well...
			print DEBUG_STREAM $pre . Dumper($obj->__get_private()) ;
		}
	}
}


sub dump_obj {
	my $obj = shift ;

	return debug_obj($obj, "Java Object Dump:\n") ;
}


sub portable {
	my $key = shift ;
	my $val = shift ;

	my $defmap = {
		EXE_EXTENSION		=>	'',
		ENV_VAR_PATH_SEP	=>	':',
		ENV_VAR_PATH_SEP_CP	=>	':',
		PATH_SEP			=>	'/',
		PATH_SEP_RE			=>	'/',
		RE_FILE				=>  [],
		IO_REDIR			=>  '2>&1',
		GOT_ALARM			=>  1,
		COMMAND_COM			=>  0,
		SUB_FIX_CLASSPATH	=>	undef,
	} ;

	my $map = {
		MSWin32 => {
			EXE_EXTENSION		=>	'.exe',
			ENV_VAR_PATH_SEP	=>	';',
			ENV_VAR_PATH_SEP_CP	=>	';',
			PATH_SEP			=>	'\\',
			PATH_SEP_RE			=>	'\\\\',
			RE_FILE				=>  ['/', '\\'],
			# 2>&1 doesn't work under command.com
			IO_REDIR			=>  ($COMMAND_COM ? '' : undef),
			GOT_ALARM			=>  0,
			COMMAND_COM			=>	$COMMAND_COM,
		},
		cygwin => {
			ENV_VAR_PATH_SEP_CP	=>	';',
			SUB_FIX_CLASSPATH	=>	sub {
				my $val = shift ;
				if (defined($val)&&($val)){
					$val = `cygpath -w \"$val\"` ;
					chomp($val) ;
				}
				return $val ;
			},
		},
	} ;

	if (! exists($defmap->{$key})){
		croak "Portability issue $key not defined!" ;
	}

	if ((defined($map->{$^O}))&&(defined($map->{$^O}->{$key}))){
		if ($key =~ /^RE_/){
			if (defined($val)){
				my $f = $map->{$^O}->{$key}->[0] ;
				my $t = $map->{$^O}->{$key}->[1] ;
				$val =~ s/$f/$t/g ;
				Inline::Java::debug("portable: $key => $val for $^O is '$val'") ;
				return $val ;
			}
			else{
				Inline::Java::debug("portable: $key for $^O is 'undef'") ;
				return undef ;
			}
		}
		elsif ($key =~ /^SUB_/){
			my $sub = $map->{$^O}->{$key} ;
			if (defined($sub)){
				$val = $sub->($val) ;
				Inline::Java::debug("portable: $key => $val for $^O is '$val'") ;
				return $val ;
			}
			else{
				return $val ;
			}
		}
		else{
			Inline::Java::debug("portable: $key for $^O is '$map->{$^O}->{$key}'") ;
			return $map->{$^O}->{$key} ;
		}
	}
	else{
		if ($key =~ /^RE_/){
			Inline::Java::debug("portable: $key => $val for $^O is default '$val'") ;
			return $val ;
		}
		if ($key =~ /^SUB_/){
			Inline::Java::debug("portable: $key => $val for $^O is default '$val'") ;
			return $val ;
		}
		else{
			Inline::Java::debug("portable: $key for $^O is default '$defmap->{$key}'") ;
			return $defmap->{$key} ;
		}
	}
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

	Inline::Java::debug("Selecting random module to house studied classes...") ;

	# Select a random Inline object to be responsible for these
	# classes
	my @modules = keys %{$INLINES} ;
	srand() ;
	my $idx = int rand @modules ;
	my $module = $modules[$idx] ;

	Inline::Java::debug("  Selected $module") ;

	my $o = Inline::Java::get_INLINE($module) ;

	return $o->_study($classes) ;
}



1 ;

__END__

