package Inline::Java::Init ;


use strict ;

$Inline::Java::Init::VERSION = '0.31' ;

my $DATA = join('', <DATA>) ;
my $OBJECT_DATA = join('', <Inline::Java::Object::DATA>) ;
my $ARRAY_DATA = join('', <Inline::Java::Array::DATA>) ;
my $CLASS_DATA = join('', <Inline::Java::Class::DATA>) ;
my $PROTO_DATA = join('', <Inline::Java::Protocol::DATA>) ;

my $CALLBACK_DATA = join('', <Inline::Java::Callback::DATA>) ;


sub DumpUserJavaCode {
	my $fh = shift ;
	my $code = shift ;

	print $fh $code ;
}


sub DumpServerJavaCode {
	my $fh = shift ;

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


sub DumpCallbackJavaCode {
	my $fh = shift ;

	my $java = $CALLBACK_DATA ;

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
	static public InlineJavaServer instance = null ;
	private int debug ;
	private int port = 0 ;
	private boolean shared_jvm = false ;

	private HashMap thread_objects = new HashMap() ;
	private int objid = 1 ;

	// This constructor is used in JNI mode
	InlineJavaServer(int d) {
		init() ;
		debug = d ;

		thread_objects.put(Thread.currentThread().getName(), new HashMap()) ;
	}


	// This constructor is used in server mode
	InlineJavaServer(String[] argv) {
		init() ;

		debug = new Integer(argv[0]).intValue() ;
		port = Integer.parseInt(argv[1]) ;
		shared_jvm = new Boolean(argv[2]).booleanValue() ;

		ServerSocket ss = null ;
		try {
			ss = new ServerSocket(port) ;	
		}
		catch (IOException e){
			System.err.println("Can't open server socket on port " + String.valueOf(port) +
				": " + e.getMessage()) ;
			System.err.flush() ;
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
				System.err.flush() ;
			}
		}

		System.exit(1) ;
	}


	private void init(){
		instance = this ;
	}

	
	public String GetType(){
		return (shared_jvm ? "shared" : "private") ;
	}


	/*
		Since this function is also called from the JNI XS extension,
		it's best if it doesn't throw any exceptions.
	*/
	private String ProcessCommand(String cmd) {
		return ProcessCommand(cmd, true) ;
	}

	private String ProcessCommand(String cmd, boolean addlf) {
		debug(3, "packet recv is " + cmd) ;

		String resp = null ;
		if (cmd != null){
			InlineJavaProtocol ijp = new InlineJavaProtocol(this, cmd) ;
			try {
				ijp.Do() ;
				debug(3, "packet sent is " + ijp.response) ;
				resp = ijp.response ;
			}
			catch (InlineJavaException e){
				String err = "error scalar:" + ijp.encode(e.getMessage()) ;
				debug(3, "packet sent is " + err) ;
				resp = err ;
			}
		}
		else{
			if (! shared_jvm){
				// Probably connection dropped...
				debug(1, "lost connection with client in single client mode. Exiting.") ;
				System.exit(1) ;
			}
			else{
				debug(1, "lost connection with client in shared JVM mode.") ;
				return null ;
			}
		}

		if (addlf){
			resp = resp + "\n" ;
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


	public Object DeleteObject(int id) throws InlineJavaException {
		Object o = null ;
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

		return o ;
	}


	public int ObjectCount() throws InlineJavaException {
		int i = -1 ;
		String name = Thread.currentThread().getName() ;
		HashMap h = (HashMap)thread_objects.get(name) ;

		if (h == null){
			throw new InlineJavaException("Can't find thread " + name + "!") ;
		}
		else{
			i = h.values().size() ;
		}

		return i ;
	}


	public Object Callback(String pkg, String method, Object args[], String cast) throws InlineJavaException, InlineJavaPerlException {
		Object ret = null ;

		try {
			InlineJavaProtocol ijp = new InlineJavaProtocol(this, null) ;
			InlineJavaClass ijc = new InlineJavaClass(this, ijp) ;
			StringBuffer cmdb = new StringBuffer("callback " + pkg + " " + method + " " + cast) ;
			if (args != null){
				for (int i = 0 ; i < args.length ; i++){
					 cmdb.append(" " + ijp.SerializeObject(args[i])) ;
				}
			}
			String cmd = cmdb.toString() ;
			debug(2, "callback command: " + cmd) ;

			Thread t = Thread.currentThread() ;
			String resp = null ;
			while (true) {			
				debug(3, "packet sent (callback) is " + cmd) ;
				if (t instanceof InlineJavaThread){
					// Client-server mode
					InlineJavaThread ijt = (InlineJavaThread)t ;
					ijt.bw.write(cmd + "\n") ;
					ijt.bw.flush() ;

					resp = ijt.br.readLine() ;
				}
				else{
					// JNI mode
					resp = jni_callback(cmd) ;
				}
				debug(3, "packet recv (callback) is " + resp) ;

				StringTokenizer st = new StringTokenizer(resp, " ") ;
				String c = st.nextToken() ;
				if (c.equals("callback")){
					boolean thrown = new Boolean(st.nextToken()).booleanValue() ;
					String arg = st.nextToken() ;
					ret = ijc.CastArgument(java.lang.Object.class, arg) ;

					if (thrown){
						throw new InlineJavaPerlException(ret) ;
					}

					break ;
				}	
				else{
					// Pass it on through the regular channel...
					debug(3, "packet is not callback response: " + resp) ;
					cmd = ProcessCommand(resp, false) ;

					continue ;
				}
			}
		}
		catch (IOException e){
			throw new InlineJavaException("IO error: " + e.getMessage()) ;
		}

		return ret ;
	}


	native private String jni_callback(String cmd) ;


	/*
		Creates a string representing a method signature
	*/
	public String CreateSignature(Class param[]){
		return CreateSignature(param, ", ") ;
	}


	public String CreateSignature(Class param[], String del){
		StringBuffer ret = new StringBuffer() ;
		for (int i = 0 ; i < param.length ; i++){
			if (i > 0){
				ret.append(del) ;
			}
			ret.append(param[i].getName()) ;
		}

		return "(" + ret.toString() + ")" ;
	}


	synchronized public void debug(int level, String s) {
		if ((debug > 0)&&(debug >= level)){
			StringBuffer sb = new StringBuffer() ;
			for (int i = 0 ; i < level ; i++){
				sb.append(" ") ;
			}
			System.err.println("[java][" + level + "]" + sb.toString() + s) ;
			System.err.flush() ;
		}
	}


	boolean reverse_members() {
		String v = System.getProperty("java.version") ;
		boolean no_rev = ((v.startsWith("1.2"))||(v.startsWith("1.3"))) ;

		return (! no_rev) ;
	}


	/*
		Startup
	*/
	public static void main(String[] argv) {
		new InlineJavaServer(argv) ;
	}


	public static InlineJavaServer jni_main(int debug) {
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
		Exception thrown by Perl callbacks.
	*/
	class InlineJavaPerlException extends Exception {
		private Object obj = null ;


		InlineJavaPerlException(Object o) {
			obj = o ;
		}

		public Object GetObject(){
			return obj ;
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



	class InlineJavaInvocationTargetException extends InlineJavaException {
		Throwable t = null ;

		InlineJavaInvocationTargetException(String m, Throwable _t){
			super(m) ;
			t = _t ;
		}

		public Throwable GetThrowable(){
			return t ;
		}
	}

	
	class InlineJavaThread extends Thread {
		InlineJavaServer ijs ;
		Socket client ;
		BufferedReader br ;
		BufferedWriter bw ;

		InlineJavaThread(InlineJavaServer _ijs, Socket _client) throws IOException {
			super() ;
			client = _client ;
			ijs = _ijs ;

			br = new BufferedReader(
				new InputStreamReader(client.getInputStream())) ;
			bw = new BufferedWriter(
				new OutputStreamWriter(client.getOutputStream())) ;
		}


		public void run(){
			try {
				ijs.thread_objects.put(getName(), new HashMap()) ;

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


class InlineJavaServerThrown {
	Throwable t = null ;

	InlineJavaServerThrown(Throwable _t){
		t = _t ;
	}

	public Throwable GetThrowable(){
		return t ;
	}
}
