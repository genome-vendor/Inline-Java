package Inline::Java::Portable ;
@Inline::Java::Portable::ISA = qw(Exporter) ;

@EXPORT = qw(portable make_classpath get_server_jar get_user_jar) ;

use strict ;
use Exporter ;
use Carp ;
use Config ;
use Cwd ;
use File::Find ;
use File::Spec ;

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
			(`ver` =~ /win(dows )?((9[58])|(m[ei]))/i)
		)
	) || 0 ;


sub debug {
	if (Inline::Java->can("debug")){
		return Inline::Java::debug(@_) ;
	}
}


# Cleans the CLASSPATH environment variable and adds
# the paths specified.
sub make_classpath {
	my @paths = @_ ;

	my @list = () ;
	if (defined($ENV{CLASSPATH})){
		push @list, $ENV{CLASSPATH} ;
	}
	push @list, @paths ;

	my $sep = portable("ENV_VAR_PATH_SEP_CP") ;
	my @cp = split(/$sep+/, join($sep, @list)) ;

	# Clean up paths
	foreach my $p (@cp){
		$p =~ s/^\s+// ;
		$p =~ s/\s+$// ;
	}

	# Remove duplicates, remove invalids but preserve order
	my @fcp = () ;
	my %cp = map {$_ => 1} @cp ;
	foreach my $p (@cp){
		if (($p)&&($cp{$p})&&(-e $p)){
			my $fp = (-d $p ? Cwd::abs_path($p) : $p) ;
			push @fcp, portable("SUB_FIX_CLASSPATH", $fp) ;
			delete $cp{$p} ;
		}
		else{
			Inline::Java::debug(2, "classpath candidate '$p' scraped") ;
		}
	}

	my $cp = join($sep, @fcp) ;

	return (wantarray ? @fcp : $cp) ;
}


sub get_jar_dir {
	my $path = $INC{"Inline/Java.pm"} ;
	my ($v, $d, $f) = File::Spec->splitpath($path) ;

	# This undef for the file should be ok.
	my $dir = File::Spec->catpath($v, $d, 'Java', undef) ;

	return Cwd::abs_path($dir) ;
}


sub get_server_jar {
	return File::Spec->catfile(get_jar_dir(), 'InlineJavaServer.jar') ;
}


sub get_user_jar {
	return File::Spec->catfile(get_jar_dir(), 'InlineJavaUser.jar') ;
}


# This maybe could be made more stable
sub find_classes_in_dir {
	my $dir = shift ;

	my @ret = () ;
	find(sub {
		my $f = $_ ;
		if ($f =~ /\.class$/){
			my $file = $File::Find::name ;
			my $fdir = $File::Find::dir ;
			my @dirs = File::Spec->splitdir($fdir) ;
			# Remove '.'
			shift @dirs ;
			# Add an empty dir to get the last '.' (for '.class')
			if ((! scalar(@dirs))||($dirs[-1] ne '')){
				push @dirs, '' ;
			}
			my $pkg = (scalar(@dirs) ? join('.', @dirs) : '') ;
			my $class = "$pkg$f" ;
			$class =~ s/\.class$// ;
			push @ret, {file => $file, class => $class} ;
		}
	}, $dir) ;

	return @ret ;
}


sub portable {
	my $key = shift ;
	my $val = shift ;

	my $defmap = {
		EXE_EXTENSION		=>	$Config{exe_ext},
		GOT_ALARM			=>  $Config{d_alarm} || 0,
		GOT_FORK			=>	$Config{d_fork} || 0,
		GOT_NEXT_FREE_PORT	=>	1,
		ENV_VAR_PATH_SEP	=>	$Config{path_sep},
		SO_EXT				=>	$Config{dlext},
		PREFIX				=>	$Config{prefix},
		LIBPERL				=>	$Config{libperl},
		DETACH_OK			=>	1,
		SO_LIB_PATH_VAR		=>	'LD_LIBRARY_PATH',
		ENV_VAR_PATH_SEP_CP	=>	':',
		IO_REDIR			=>  '2>&1',
		MAKE				=>	'make',
		DEV_NULL			=>  '/dev/null',
		COMMAND_COM			=>  0,
		SUB_FIX_CLASSPATH	=>	undef,
		SUB_FIX_CMD_QUOTES	=>	undef,
		SUB_FIX_MAKE_QUOTES	=>	undef,
		JVM_LIB				=>	'libjvm.so',
		JVM_SO				=>	'libjvm.so',
	} ;

	my $map = {
		MSWin32 => {
			ENV_VAR_PATH_SEP_CP	=>	';',
			# 2>&1 doesn't work under command.com
			IO_REDIR			=>  ($COMMAND_COM ? '' : undef),
			MAKE				=>	'nmake',
			DEV_NULL			=>  'nul',
			COMMAND_COM			=>	$COMMAND_COM,
			SO_LIB_PATH_VAR		=>	'PATH',
			DETACH_OK			=>	0,
			JVM_LIB				=>	'jvm.lib',
			JVM_SO				=>	'jvm.dll',
			GOT_NEXT_FREE_PORT	=>	0,
			SUB_FIX_CMD_QUOTES	=>	($COMMAND_COM ? undef : sub {
				my $val = shift ;
				$val = qq{"$val"} ;
				return $val ;
			}),
			SUB_FIX_MAKE_QUOTES	=>	sub {
				my $val = shift ;
				$val = qq{"$val"} ;
				return $val ;
			},
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
			JVM_LIB				=>	'jvm.lib',
			JVM_SO				=>	'jvm.dll',
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
				Inline::Java::Portable::debug(4, "portable: $key => $val for $^O is '$val'") ;
				return $val ;
			}
			else{
				Inline::Java::Portable::debug(4, "portable: $key for $^O is 'undef'") ;
				return undef ;
			}
		}
		elsif ($key =~ /^SUB_/){
			my $sub = $map->{$^O}->{$key} ;
			if (defined($sub)){
				$val = $sub->($val) ;
				Inline::Java::Portable::debug(4, "portable: $key => $val for $^O is '$val'") ;
				return $val ;
			}
			else{
				return $val ;
			}
		}
		else{
			Inline::Java::Portable::debug(4, "portable: $key for $^O is '$map->{$^O}->{$key}'") ;
			return $map->{$^O}->{$key} ;
		}
	}
	else{
		if ($key =~ /^RE_/){
			Inline::Java::Portable::debug(4, "portable: $key => $val for $^O is default '$val'") ;
			return $val ;
		}
		if ($key =~ /^SUB_/){
			Inline::Java::Portable::debug(4, "portable: $key => $val for $^O is default '$val'") ;
			return $val ;
		}
		else{
			Inline::Java::Portable::debug(4, "portable: $key for $^O is default '$defmap->{$key}'") ;
			return $defmap->{$key} ;
		}
	}
}


1 ;
