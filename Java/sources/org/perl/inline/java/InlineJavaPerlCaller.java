package org.perl.inline.java ;

import java.util.* ;
import java.io.* ;


/*
	Callback to Perl...
*/
public class InlineJavaPerlCaller {
	private InlineJavaServer ijs = InlineJavaServer.GetInstance() ;
	private Thread creator = null ;
	static private HashMap thread_callback_queues = new HashMap() ;
	static private ResourceBundle resources = null ;
	static private boolean inited = false ;


	/*
		Only thread that communicate with Perl are allowed to create PerlCallers because
		this is where we get the thread that needs to be notified when the callbacks come in.
	*/
	public InlineJavaPerlCaller() throws InlineJavaException {
		init() ;
		Thread t = Thread.currentThread() ;
		if (ijs.IsThreadPerlContact(t)){
			creator = t ;
		}
		else{
			throw new InlineJavaException("InlineJavaPerlCaller objects can only be created by threads that communicate directly with Perl") ;
		}
	}


	synchronized static protected void init() throws InlineJavaException {
       if (! inited){
            try {
                resources = ResourceBundle.getBundle("InlineJava") ;

                inited = true ;
            }
            catch (MissingResourceException mre){
                throw new InlineJavaException("Error loading InlineJava.properties: " + mre.getMessage()) ;
            }
        }
	}


	static protected ResourceBundle GetBundle(){
		return resources ;
	}


	public Object CallPerl(String pkg, String method, Object args[]) throws InlineJavaException, InlineJavaPerlException {
		return CallPerl(pkg, method, args, null) ;
	}


	public Object CallPerl(String pkg, String method, Object args[], String cast) throws InlineJavaException, InlineJavaPerlException {
		InlineJavaCallback ijc = new InlineJavaCallback(pkg, method, args, cast) ;
		return CallPerl(ijc) ;
	}


	public Object CallPerl(InlineJavaCallback ijc) throws InlineJavaException, InlineJavaPerlException {
		Thread t = Thread.currentThread() ;
		if (t == creator){
			ijc.Process() ;
			return ijc.GetResponse() ;
		}
		else{
			// Enqueue the callback into the creator thread's queue and notify it
			// that there is some work for him.
			ijc.ClearResponse() ;
			InlineJavaCallbackQueue q = GetQueue(creator) ;
			InlineJavaUtils.debug(3, "enqueing callback for processing for " + creator.getName() + " in " + t.getName() + "...") ;
			q.EnqueueCallback(ijc) ;
			InlineJavaUtils.debug(3, "notifying that a callback request is available for " + creator.getName() + " in " + t.getName()) ;

			// Now we must wait until the callback is processed and get back the result...
			return ijc.WaitForResponse(t) ;
		}
	}


	public void StartCallbackLoop() throws InlineJavaException, InlineJavaPerlException {
		Thread t = Thread.currentThread() ;
		if (! ijs.IsThreadPerlContact(t)){
			throw new InlineJavaException("InlineJavaPerlCaller.StartCallbackLoop() can only be called by threads that communicate directly with Perl") ;
		}

		InlineJavaCallbackQueue q = GetQueue(t) ;
		q.StartLoop() ;
		while (! q.IsLoopStopped()){
			InlineJavaUtils.debug(3, "waiting for callback request in " + t.getName() + "...") ;
			InlineJavaCallback ijc = q.WaitForCallback() ;
			InlineJavaUtils.debug(3, "waiting for callback request finished " + t.getName() + "...") ;
			InlineJavaUtils.debug(3, "processing callback request in " + t.getName() + "...") ;
			// The callback object can be null if the wait() is interrupted by StopCallbackLoop
			if (ijc != null){	
				ijc.Process() ;
				ijc.NotifyOfResponse(t) ;
			}
		}
	}


	public void StopCallbackLoop() throws InlineJavaException {
		Thread t = Thread.currentThread() ;
		InlineJavaCallbackQueue q = GetQueue(creator) ;
		InlineJavaUtils.debug(3, "interrupting callback loop for " + creator.getName() + " in " + t.getName()) ;
		q.StopLoop() ;
	}


	/*
		Here the prototype accepts Threads because the JNI thread
		calls this method also.
	*/
	static synchronized void AddThread(Thread t){
		thread_callback_queues.put(t, new InlineJavaCallbackQueue()) ;
	}


	static synchronized void RemoveThread(InlineJavaServerThread t){
		thread_callback_queues.remove(t) ;
	}


	static private InlineJavaCallbackQueue GetQueue(Thread t) throws InlineJavaException {
		InlineJavaCallbackQueue q = (InlineJavaCallbackQueue)thread_callback_queues.get(t) ;

		if (q == null){
			throw new InlineJavaException("Can't find thread " + t.getName() + "!") ;
		}
		return q ;
	}
}
