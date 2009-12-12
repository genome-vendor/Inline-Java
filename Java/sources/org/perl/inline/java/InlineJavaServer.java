package org.perl.inline.java ;

import java.net.* ;
import java.io.* ;
import java.util.* ;


/*
	This is the server that will answer all the requests for and on Java
	objects.
*/
public class InlineJavaServer {
	private static InlineJavaServer instance = null ;
	private int port = 0 ;
	private boolean shared_jvm = false ;
	private boolean priv = false ;

	private boolean finished = false ;
	private ServerSocket server_socket = null ;
	private InlineJavaUserClassLoader ijucl = null ;
	private HashMap thread_objects = new HashMap() ;
	private int objid = 1 ;
	private boolean jni = false ;
	private Thread creator = null ;
	private int thread_count = 0 ;


	// This constructor is used in JNI mode
	private InlineJavaServer(int d){
		init(d) ;

		jni = true ; 
		AddThread(creator) ;
	}


	// This constructor is used in server mode
	private InlineJavaServer(String[] argv){
		init(new Integer(argv[0]).intValue()) ;

		jni = false ;
		port = Integer.parseInt(argv[1]) ;
		shared_jvm = new Boolean(argv[2]).booleanValue() ;
		priv = new Boolean(argv[3]).booleanValue() ;

		try {
			server_socket = new ServerSocket(port) ;	
		}
		catch (IOException e){
			InlineJavaUtils.Fatal("Can't open server socket on port " + String.valueOf(port) +
				": " + e.getMessage()) ;
		}

		while (! finished){
			try {
				String name = "IJST-#" + thread_count++ ;
				InlineJavaServerThread ijt = new InlineJavaServerThread(name, this, server_socket.accept(),
					(priv ? new InlineJavaUserClassLoader() : ijucl)) ;
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
				if (! finished){
					System.err.println("Main Loop IO Error: " + e.getMessage()) ;
					System.err.flush() ;
				}
			}
		}

		System.exit(0) ;
	}


	private void init(int debug){
		instance = this ;
		creator = Thread.currentThread() ;
		InlineJavaUtils.debug = debug ;

		ijucl = new InlineJavaUserClassLoader() ;
	}

	
	static InlineJavaServer GetInstance(){
		if (instance == null){
			InlineJavaUtils.Fatal("No instance of InlineJavaServer has been created!") ;
		}

		return instance ;
	}


	InlineJavaUserClassLoader GetUserClassLoader(){
		Thread t = Thread.currentThread() ;
		if (t instanceof InlineJavaServerThread){
			return ((InlineJavaServerThread)t).GetUserClassLoader() ;
		}
		else{
			return ijucl ;
		}
	}


	String GetType(){
		return (shared_jvm ? "shared" : "private") ;
	}


	boolean IsJNI(){
		return jni ;
	}


	/*
		Since this function is also called from the JNI XS extension,
		it's best if it doesn't throw any exceptions.
	*/
	String ProcessCommand(String cmd) {
		return ProcessCommand(cmd, true) ;
	}


	String ProcessCommand(String cmd, boolean addlf) {
		InlineJavaUtils.debug(3, "packet recv is " + cmd) ;

		String resp = null ;
		if (cmd != null){
			InlineJavaProtocol ijp = new InlineJavaProtocol(this, cmd) ;
			try {
				ijp.Do() ;
				InlineJavaUtils.debug(3, "packet sent is " + ijp.GetResponse()) ;
				resp = ijp.GetResponse() ;
			}
			catch (InlineJavaException e){
				String err = "error scalar:" + ijp.Encode(e.getMessage()) ;
				InlineJavaUtils.debug(3, "packet sent is " + err) ;
				resp = err ;
			}
		}
		else{
			if (! shared_jvm){
				// Probably connection dropped...
				InlineJavaUtils.debug(1, "lost connection with client in single client mode. Exiting.") ;
				System.exit(1) ;
			}
			else{
				InlineJavaUtils.debug(1, "lost connection with client in shared JVM mode.") ;
				return null ;
			}
		}

		if (addlf){
			resp = resp + "\n" ;
		}

		return resp ;
	}


	/*
		This method really has no business here, but for historical reasons
		it will remain here.
	*/
	native String jni_callback(String cmd) ;


	boolean IsThreadPerlContact(Thread t){
		if (((jni)&&(t == creator))||
			((! jni)&&(t instanceof InlineJavaServerThread))){
			return true ;
		}

		return false ;
	}


	synchronized Object GetObject(int id) throws InlineJavaException {
		Object o = null ;
		HashMap h = (HashMap)thread_objects.get(Thread.currentThread()) ;

		if (h == null){
			throw new InlineJavaException("Can't find thread " + Thread.currentThread().getName() + "!") ;
		}
		else{
			o = h.get(new Integer(id)) ;
			if (o == null){
				throw new InlineJavaException("Can't find object " + id + " for thread " +Thread.currentThread().getName()) ;
			}
		}

		return o ;
	}


	synchronized int PutObject(Object o) throws InlineJavaException {
		HashMap h = (HashMap)thread_objects.get(Thread.currentThread()) ;

		int id = objid ;
		if (h == null){
			throw new InlineJavaException("Can't find thread " + Thread.currentThread().getName() + "!") ;
		}
		else{
			h.put(new Integer(objid), o) ;
			objid++ ;
		}

		return id ;
	}


	synchronized Object DeleteObject(int id) throws InlineJavaException {
		Object o = null ;
		HashMap h = (HashMap)thread_objects.get(Thread.currentThread()) ;

		if (h == null){
			throw new InlineJavaException("Can't find thread " + Thread.currentThread().getName() + "!") ;
		}
		else{
			o = h.remove(new Integer(id)) ;
			if (o == null){
				throw new InlineJavaException("Can't find object " + id + " for thread " + Thread.currentThread().getName()) ;
			}
		}

		return o ;
	}


	synchronized int ObjectCount() throws InlineJavaException {
		int i = -1 ;
		HashMap h = (HashMap)thread_objects.get(Thread.currentThread()) ;

		if (h == null){
			throw new InlineJavaException("Can't find thread " + Thread.currentThread().getName() + "!") ;
		}
		else{
			i = h.values().size() ;
		}

		return i ;
	}


	synchronized void Shutdown(){
		if (! jni){
			try {
				finished = true ;
				server_socket.close() ;
			}
			catch (IOException e){
				System.err.println("Shutdown IO Error: " + e.getMessage()) ;
				System.err.flush() ;
			}
		}
		System.exit(0) ;
	}


	/*
		Here the prototype accepts Threads because the JNI thread
		calls this method also.
	*/
	synchronized void AddThread(Thread t){
		thread_objects.put(t, new HashMap()) ;
		InlineJavaPerlCaller.AddThread(t) ;
	}


	synchronized void RemoveThread(InlineJavaServerThread t){
		thread_objects.remove(t) ;
		InlineJavaPerlCaller.RemoveThread(t) ;
	}



	/*
		Startup
	*/
	public static void main(String[] argv){
		new InlineJavaServer(argv) ;
	}


	/*
		With PerlInterpreter this is called twisce, but we don't want to create
		a new object the second time.
	*/
	public static InlineJavaServer jni_main(int debug){
		if (instance != null){
			InlineJavaUtils.debug = debug ;
			InlineJavaUtils.debug(1, "recycling InlineJavaServer created by PerlInterpreter") ;
			return instance ;
		}
		else{
			return new InlineJavaServer(debug) ;
		}
	}
}
