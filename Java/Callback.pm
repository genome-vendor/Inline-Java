package Inline::Java::Callback ;


use strict ;

$Inline::Java::Callback::VERSION = '0.31' ;


use Carp ;


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

		Inline::Java::debug(" processing callback $module" . "::" . "$function(" . 
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

	($ret) = Inline::Java::Class::CastArgument($ret, $proto, $inline->get_api('modfname')) ;
	
	# Here we must keep a reference to $ret or else it gets deleted 
	# before the id is returned to Java...
	my $ref = $ret ;

	($ret) = $pc->ValidateArgs([$ret], 1) ;

	return ("callback $thrown $ret", $ref) ;
}



1 ;


__DATA__

/*
	Callback to Perl...
*/
public class InlineJavaPerlCaller {
	public InlineJavaPerlCaller(){
	}


	class InlineJavaException extends Exception {
		private InlineJavaServer.InlineJavaException ije = null ;
		
		InlineJavaException(InlineJavaServer.InlineJavaException e) {
			ije = e ;
		}

		public InlineJavaServer.InlineJavaException GetException(){
			return ije ;
		}
	}


	class PerlException extends Exception {
		private Object obj = null ;

		PerlException(Object o) {
			obj = o ;
		}

		public Object GetObject(){
			return obj ;
		}
	}


	public Object CallPerl(String pkg, String method, Object args[]) throws InlineJavaException, PerlException {
		return CallPerl(pkg, method, args, null) ;
	}


	public Object CallPerl(String pkg, String method, Object args[], String cast) throws InlineJavaException, PerlException {
		if (InlineJavaServer.instance == null){
			System.err.println("Can't use InlineJavaPerlCaller outside of an Inline::Java context") ;
			System.err.flush() ;
			System.exit(1) ;
		}

		try {
			return InlineJavaServer.instance.Callback(pkg, method, args, cast) ;
		}
		catch (InlineJavaServer.InlineJavaException e){
			throw new InlineJavaException(e) ;
		}
		catch (InlineJavaServer.InlineJavaPerlException e){
			throw new PerlException(e.GetObject()) ;
		}
	}
}

