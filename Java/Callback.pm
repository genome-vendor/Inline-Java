package Inline::Java::Callback ;

use strict ;
use Carp ;

$Inline::Java::Callback::VERSION = '0.46' ;

$Inline::Java::Callback::OBJECT_HOOK = undef ;



sub InterceptCallback {
	my $inline = shift ;
	my $resp = shift ;

	# With JNI we need to store the object somewhere since we
	# can't drag it along all the way through Java land...
	if (! defined($inline)){
		$inline = $Inline::Java::JNI::INLINE_HOOK ;
	}

	if ($resp =~ s/^callback ([^ ]+) (\w+) ([^ ]+)//){
		my $module = $1 ;
		my $function = $2 ;
		my $cast_return = $3 ;
		my @args = split(' ', $resp) ;

		# "Relative" namespace...
		if ($module =~ /^::/){
			$module = $inline->get_api('pkg') . $module ;
		}

		return Inline::Java::Callback::ProcessCallback($inline, $module, $function, $cast_return, @args) ;
	}

	croak "Malformed callback request from server: $resp" ;
}


sub ProcessCallback {
	my $inline = shift ;
	my $module = shift ;
	my $function = shift ;
	my $cast_return = shift ;
	my @sargs = @_ ;

	my $pc = new Inline::Java::Protocol(undef, $inline) ;
	my $thrown = 'false' ;
	my $ret = undef ;
	eval {
		my @args = map {
			my $a = $pc->DeserializeObject(0, $_) ;
			$a ;
		} @sargs ;

		Inline::Java::debug(2, "processing callback $module" . "::" . "$function(" . 
			join(", ", @args) . ")") ;

		no strict 'refs' ;
		my $sub = "$module" . "::" . $function ;
		$ret = $sub->(@args) ;
	} ;
	if ($@){
		$ret = $@ ;
		$thrown = 'true' ;

		if ((ref($ret))&&(! UNIVERSAL::isa($ret, "Inline::Java::Object"))){
			croak "Can't propagate non-Inline::Java reference exception ($ret) to Java" ;
		}
	}

	my $proto = 'java.lang.Object' ;
	if ($cast_return ne "null"){
		$ret = Inline::Java::cast($proto, $ret, $cast_return) ;
	}

	($ret) = Inline::Java::Class::CastArgument($ret, $proto, $inline) ;
	
	# Here we must keep a reference to $ret or else it gets deleted 
	# before the id is returned to Java...
	my $ref = $ret ;

	($ret) = $pc->ValidateArgs([$ret], 1) ;

	return ("callback $thrown $ret", $ref) ;
}



1 ;
