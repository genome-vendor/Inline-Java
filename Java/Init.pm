package Inline::Java::Init ;


use strict ;

$Inline::Java::Init::VERSION = '0.30' ;

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
	boolean debug ;
	int port = 0 ;
	boolean shared_jvm = false ;

	public HashMap thread_objects = new HashMap() ;
	public int objid = 1 ;

	// This constructor is used in JNI mode
	InlineJavaServer(boolean d) {
		debug = d ;

		thread_objects.put(Thread.currentThread().getName(), new HashMap()) ;
	}


	// This constructor is used in server mode
	InlineJavaServer(String[] argv) {
		debug = new Boolean(argv[0]).booleanValue() ;
		port = Integer.parseInt(argv[1]) ;
		shared_jvm = new Boolean(argv[2]).booleanValue() ;

		ServerSocket ss = null ;
		try {
			ss = new ServerSocket(port) ;	
		}
		catch (IOException e){
			System.err.println("Can't open server socket on port " + String.valueOf(port)) ;
			System.exit(1) ;
		}

		while (true){
			try {
				InlineJavaThread ijt = new InlineJavaThread(this, ss.accept()) ;
				ijt.start() ;
				if (! shared_jvm){
					try {
						ijt.join() ; 
					}
					catch (InterruptedException e){
					}
					break ;
				}
			}
			catch (IOException e){
				System.err.println("IO error: " + e.getMessage()) ;
			}
		}

		System.exit(1) ;
	}


	/*
		Since this function is also called from the JNI XS extension,
		it's best if it doesn't throw any exceptions.
	*/
	public String ProcessCommand(String cmd) {
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
			if (! shared_jvm){
				// Probably connection dropped...
				debug("  Lost connection with client in single client mode. Exiting.") ;
				System.exit(1) ;
			}
			else{
				debug("  Lost connection with client in shared JVM mode.") ;
				return null ;
			}
		}

		return resp ;
	}

	
	public Object GetObject(int id) throws InlineJavaException {
		Object o = null ;
		String name = Thread.currentThread().getName() ;
		HashMap h = (HashMap)thread_objects.get(name) ;

		if (h == null){
			throw new InlineJavaException("Can't find thread " + name + "!") ;
		}
		else{
			o = h.get(new Integer(id)) ;
			if (o == null){
				throw new InlineJavaException("Can't find object " + id + " for thread " + name) ;
			}
		}

		return o ;
	}


	synchronized public void PutObject(int id, Object o) throws InlineJavaException {
		String name = Thread.currentThread().getName() ;
		HashMap h = (HashMap)thread_objects.get(name) ;

		if (h == null){
			throw new InlineJavaException("Can't find thread " + name + "!") ;
		}
		else{
			h.put(new Integer(id), o) ;
			objid++ ;
		}
	}


	public Object DeleteObject(int id) {
		Object o = null ;
		try {
			String name = Thread.currentThread().getName() ;
			HashMap h = (HashMap)thread_objects.get(name) ;

			if (h == null){
				throw new InlineJavaException("Can't find thread " + name + "!") ;
			}
			else{
				o = h.remove(new Integer(id)) ;
				if (o == null){
					throw new InlineJavaException("Can't find object " + id + " for thread " + name) ;
				}
			}
		}
		catch (InlineJavaException e){
			debug(e.getMessage()) ;
		}

		return o ;
	}


	public int ObjectCount() {
		int i = -1 ;
		try {
			String name = Thread.currentThread().getName() ;
			HashMap h = (HashMap)thread_objects.get(name) ;

			if (h == null){
				throw new InlineJavaException("Can't find thread " + name + "!") ;
			}
			else{
				i = h.values().size() ;
			}
		}
		catch (InlineJavaException e){
			debug(e.getMessage()) ;
		}

		return i ;
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


	synchronized public void debug(String s) {
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


	class InlineJavaIOException extends IOException {
		InlineJavaIOException(String m){
			super(m) ;
		}
	}

	
	class InlineJavaThread extends Thread {
		InlineJavaServer ijs ;
		Socket client ;

		InlineJavaThread(InlineJavaServer _ijs, Socket _client){
			super() ;
			client = _client ;
			ijs = _ijs ;
		}


		public void run(){
			try {
				ijs.thread_objects.put(getName(), new HashMap()) ;

				BufferedReader br = new BufferedReader(
					new InputStreamReader(client.getInputStream())) ;
				BufferedWriter bw = new BufferedWriter(
					new OutputStreamWriter(client.getOutputStream())) ;

				while (true){
					String cmd = br.readLine() ;

					String resp = ijs.ProcessCommand(cmd) ;
					if (resp != null){
						bw.write(resp) ;
						bw.flush() ;
					}
					else {
						break ;
					}
				}
			}
			catch (IOException e){
				System.err.println("IO error: " + e.getMessage()) ;
			}
			finally {
				ijs.thread_objects.remove(getName()) ;
			}
		}
	}
}
