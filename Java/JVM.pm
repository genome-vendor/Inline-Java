package Inline::Java::JVM ;


use strict ;

$Inline::Java::JVM::VERSION = '0.31' ;

use Carp ;
use IPC::Open3 ;
use IO::File ;
use IO::Pipe ;
use POSIX qw(setsid) ;

my %SIGS = () ;

my @SIG_LIST = ('HUP', 'INT', 'PIPE', 'TERM') ;

sub new {
	my $class = shift ;
	my $o = shift ;

	my $this = {} ;
	bless($this, $class) ;

	foreach my $sig (@SIG_LIST){
		local $SIG{__WARN__} = sub {} ;
		if (exists($SIG{$sig})){
			$SIGS{$sig} = $SIG{$sig} ;
		}
	}

	$this->{socket} = undef ;
	$this->{JNI} = undef ;

	$this->{destroyed} = 0 ;

	Inline::Java::debug(1, "starting JVM...") ;

	$this->{owner} = 1 ;
	if ($o->get_java_config('JNI')){
		Inline::Java::debug(1, "JNI mode") ;

		my $jni = new Inline::Java::JNI(
			$ENV{CLASSPATH} || "",
			Inline::Java::get_DEBUG(),
		) ;
		$jni->create_ijs() ;

		$this->{JNI} = $jni ;
	}
	else{
		Inline::Java::debug(1, "client/server mode") ;

		my $debug = Inline::Java::get_DEBUG() ;

		$this->{shared} = $o->get_java_config('SHARED_JVM') ;
		$this->{port} = $o->get_java_config('PORT') ;
		$this->{host} = "localhost" ;

		# Check if JVM is already running
		if ($this->{shared}){
			eval {
				$this->reconnect() ;
			} ;
			if (! $@){
				Inline::Java::debug(1, "connected to already running JVM!") ;
				return $this ;
			}
		}
		$this->capture(1) ;

		my $java = File::Spec->catfile($o->get_java_config('BIN'), 
			"java" . Inline::Java::portable("EXE_EXTENSION")) ;

		my $shared_arg = ($this->{shared} ? "true" : "false") ;
		my $cmd = "\"$java\" InlineJavaServer $debug $this->{port} $shared_arg" ;
		Inline::Java::debug(1, $cmd) ;

		if ($o->get_config('UNTAINT')){
			($cmd) = $cmd =~ /(.*)/ ;
		}

		my $pid = 0 ;
		eval {
			$pid = $this->launch($cmd) ;
		} ;
		croak "Can't exec JVM: $@" if $@ ;

		$this->{pid} = $pid ;
		$this->{socket}	= $this->setup_socket(
			$this->{host}, 
			$this->{port}, 
			$o->get_java_config('STARTUP_DELAY'),
			0
		) ;
	}

	return $this ;
}


sub launch {
	my $this = shift ;
	my $cmd = shift ;

	local $SIG{__WARN__} = sub {} ;

	my $dn = Inline::Java::portable("DEV_NULL") ;
	my $in = new IO::File("<$dn") ;
	if (! defined($in)){
		croak "Can't open $dn for reading" ;
	}
	my $out = ">&STDOUT" ;
	if ($this->{shared}){
		$out = new IO::File(">$dn") ;
		if (! defined($out)){
			croak "Can't open $dn for writing" ;
		}
	}
	my $pid = open3($in, $out, ">&STDERR", $cmd) ;

	close($in) ;
	if ($this->{shared}){
		close($out) ;
	}

	return $pid ;
}


sub DESTROY {
	my $this = shift ;

	$this->shutdown() ;	
}


sub shutdown {
	my $this = shift ;

	if (! $this->{destroyed}){
		if ($this->am_owner()){
			Inline::Java::debug(1, "JVM owner exiting...") ;

			if ($this->{socket}){
				# This asks the Java server to stop and die.
				my $sock = $this->{socket} ;
				if ($sock->peername()){
					Inline::Java::debug(1, "Sending 'die' message to JVM...") ;
					print $sock "die\n" ;
				}
				else{
					carp "Lost connection with Java virtual machine" ;
				}
				close($sock) ;
		
				if ($this->{pid}){
					# Here we go ahead and send the signals anyway to be very 
					# sure it's dead...
					# Always be polite first, and then insist.
					Inline::Java::debug(1, "Sending 15 signal to JVM...") ;
					kill(15, $this->{pid}) ;
					Inline::Java::debug(1, "Sending 9 signal to JVM...") ;
					kill(9, $this->{pid}) ;
		
					# Reap the child...
					waitpid($this->{pid}, 0) ;
				}
			}
			if ($this->{JNI}){
				$this->{JNI}->shutdown() ;
			}
		}
		else{
			# We are not the JVM owner, so we simply politely disconnect
			if ($this->{socket}){
				Inline::Java::debug(1, "JVM non-owner exiting...") ;
				close($this->{socket}) ;
				$this->{socket} = undef ;
			}

			# This should never happen in JNI mode
		}

        $this->{destroyed} = 1 ;
	}
}


sub setup_socket {
	my $this = shift ;
	my $host = shift ;
	my $port = shift ;
	my $timeout = shift ;
	my $one_shot = shift ;

	my $socket = undef ;

	my $last_words = "timeout\n" ;
	my $got_alarm = Inline::Java::portable("GOT_ALARM") ;

	eval {
		local $SIG{ALRM} = sub { die($last_words) ; } ;

		if ($got_alarm){
			alarm($timeout) ;
		}

		# ignore expected "connection refused" warnings
		# Thanks binkley!
		local $SIG{__WARN__} = sub { 
			warn($@) unless ($@ =~ /Connection refused/i) ; 
		} ;

		while (1){
			$socket = new IO::Socket::INET(
				PeerAddr => $host,
				PeerPort => $port,
				Proto => 'tcp') ;
			if (($socket)||($one_shot)){
				last ;
			}
		}

		if ($got_alarm){
			alarm(0) ;
		}
	} ;
	if ($@){
		if ($@ eq $last_words){
			croak "JVM taking more than $timeout seconds to start, or died before Perl could connect. Increase config STARTUP_DELAY if necessary." ;
		}
		else{
			if ($got_alarm){
				alarm(0) ;
			}
			croak $@ ;
		}
	}

	if (! $socket){
		croak "Can't connect to JVM at ($host:$port): $!" ;
	}

	$socket->autoflush(1) ;

	return $socket ;
}


sub reconnect {
	my $this = shift ;

	if (($this->{JNI})||(! $this->{shared})){
		return ;
	}

	if ($this->{socket}){
		# Close the previous socket
		close($this->{socket}) ;
		$this->{socket} = undef ;
	}

	my $socket = $this->setup_socket(
		$this->{host}, 
		$this->{port}, 
		0,
		1
	) ;
	$this->{socket} = $socket ;

	# Now that we have reconnected, we release the JVM
	$this->release() ;
}


sub capture {
	my $this = shift ;

	if (($this->{JNI})||(! $this->{shared})){
		return ;
	}

	foreach my $sig (@SIG_LIST){
		if (exists($SIG{$sig})){
			$SIG{$sig} = \&Inline::Java::done ;
		}
	}

	$this->{owner} = 1 ;
}


sub am_owner {
	my $this = shift ;

	return $this->{owner} ;
}


sub release {
	my $this = shift ;

	if (($this->{JNI})||(! $this->{shared})){
		return ;
	}

	foreach my $sig (@SIG_LIST){
		local $SIG{__WARN__} = sub {} ;
		if (exists($SIG{$sig})){
			$SIG{$sig} = $SIGS{$sig} ;
		}
	}

	$this->{owner} = 0 ;
}


sub process_command {
	my $this = shift ;
	my $inline = shift ;
	my $data = shift ;

	my $resp = undef ;
	while (1){
		Inline::Java::debug(3, "packet sent is $data") ;

		if ($this->{socket}){
			my $sock = $this->{socket} ;
			print $sock $data . "\n" or
				croak "Can't send packet to JVM: $!" ;

			$resp = <$sock> ;
			if (! $resp){
				croak "Can't receive packet from JVM: $!" ;
			}

			# Release the reference since the object has been sent back
			# to Java.
			$Inline::Java::Callback::OBJECT_HOOK = undef ;
		}
		if ($this->{JNI}){
			$Inline::Java::JNI::INLINE_HOOK = $inline ;
			$resp = $this->{JNI}->process_command($data) ;
		}
		chomp($resp) ;

		Inline::Java::debug(3, "packet recv is $resp") ;

		# We got an answer from the server. Is it a callback?
		if ($resp =~ /^callback/){
			($data, $Inline::Java::Callback::OBJECT_HOOK) = Inline::Java::Callback::InterceptCallback($inline, $resp) ;
			next ;
		}
		else{
			last ;
		}
	}

	return $resp ;
}



1 ;

