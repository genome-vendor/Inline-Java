package Inline::Java::Init ;


use strict ;

$Inline::Java::Init::VERSION = '0.20' ;

my $DATA = join('', <DATA>) ;
my $OBJECT_DATA = join('', <Inline::Java::Object::DATA>) ;
my $ARRAY_DATA = join('', <Inline::Java::Array::DATA>) ;
my $CLASS_DATA = join('', <Inline::Java::Class::DATA>) ;
my $PROTO_DATA = join('', <Inline::Java::Protocol::DATA>) ;


sub DumpUserJavaCode {
	my $fh = shift ;
	my $modfname = shift ;
	my $code = shift ;

	print $fh $code ;
}


sub DumpServerJavaCode {
	my $fh = shift ;
	my $modfname = shift ;

	my $java = $DATA ;
	my $java_obj = $OBJECT_DATA ;
	my $java_array = $ARRAY_DATA ;
	my $java_class = $CLASS_DATA ;
	my $java_proto = $PROTO_DATA ;

	$java =~ s/<INLINE_JAVA_OBJECT>/$java_obj/g ;
	$java =~ s/<INLINE_JAVA_ARRAY>/$java_array/g ;
	$java =~ s/<INLINE_JAVA_CLASS>/$java_class/g ;
	$java =~ s/<INLINE_JAVA_PROTOCOL>/$java_proto/g ;

	print $fh $java ;
}



1 ;



__DATA__
import java.net.* ;
import java.io.* ;
import java.util.* ;
import java.lang.reflect.* ;


/*
	This is the server that will answer all the requests for and on Java
	objects.
*/
public class InlineJavaServer {
	public ServerSocket ss ;
	public Socket client ;
	boolean debug = false ;

	public HashMap objects = new HashMap() ;
	public int objid = 1 ;

	// This constructor is used in JNI mode
	InlineJavaServer(boolean d) {
		debug = d ;
	}


	// This constructor is used in server mode
	InlineJavaServer(String[] argv) {
		debug = new Boolean(argv[0]).booleanValue() ;

		int port = Integer.parseInt(argv[1]) ;

		try {
			ss = new ServerSocket(port) ;
			client = ss.accept() ;

			BufferedReader br = new BufferedReader(
				new InputStreamReader(client.getInputStream())) ;
			BufferedWriter bw = new BufferedWriter(
				new OutputStreamWriter(client.getOutputStream())) ;

			while (true){
				String cmd = br.readLine() ;

				String resp = ProcessCommand(cmd) ;
				bw.write(resp) ;
				bw.flush() ;
			}
		}
		catch (IOException e){
			System.err.println("Can't open server socket on port " + String.valueOf(port)) ;
		}
		System.exit(1) ;
	}


	public String ProcessCommand(String cmd){
		debug("  packet recv is " + cmd) ;

		String resp = null ;
		if (cmd != null){
			InlineJavaProtocol ijp = new InlineJavaProtocol(this, cmd) ;
			try {
				ijp.Do() ;
				debug("  packet sent is " + ijp.response) ;
				resp = ijp.response + "\n" ;
			}
			catch (InlineJavaException e){
				String err = "error scalar:" + ijp.unpack(e.getMessage()) ;
				debug("  packet sent is " + err) ;
				resp = err + "\n" ;
			}
		}
		else{
			// Probably connection dropped...
			debug("  Lost connection with client") ;
			System.exit(1) ;
		}

		return resp ;
	}


	/*
		Creates a string representing a method signature
	*/
	String CreateSignature(Class param[]){
		return CreateSignature(param, ", ") ;
	}


	String CreateSignature(Class param[], String del){
		StringBuffer ret = new StringBuffer() ;
		for (int i = 0 ; i < param.length ; i++){
			if (i > 0){
				ret.append(del) ;
			}
			ret.append(param[i].getName()) ;
		}

		return "(" + ret.toString() + ")" ;
	}


	public void debug(String s) {
		if (debug){
			System.err.println("java: " + s) ;
			System.err.flush() ;
		}
	}


	/*
		Startup
	*/
	public static void main(String[] argv) {
		new InlineJavaServer(argv) ;
	}


	public static InlineJavaServer jni_main(boolean debug) {
		return new InlineJavaServer(debug) ;
	}
	

	<INLINE_JAVA_OBJECT>

	<INLINE_JAVA_ARRAY>

	<INLINE_JAVA_CLASS>

	<INLINE_JAVA_PROTOCOL>

	/*
		Exception thrown by this code.
	*/
	class InlineJavaException extends Exception {
		InlineJavaException(String s) {
			super(s) ;
		}
	}


	/*
		Exception thrown by this code while trying to cast arguments
	*/
	class InlineJavaCastException extends InlineJavaException {
		InlineJavaCastException(String m){
			super(m) ;
		}
	}
}
