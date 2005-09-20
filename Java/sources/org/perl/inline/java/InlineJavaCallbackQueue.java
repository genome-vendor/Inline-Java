package org.perl.inline.java ;

import java.util.* ;
import java.io.* ;


/*
	Queue for callbacks to Perl...
*/
class InlineJavaCallbackQueue {
	// private InlineJavaServer ijs = InlineJavaServer.GetInstance() ;
	private ArrayList queue = new ArrayList() ;
	private boolean stop_loop = false ;


	InlineJavaCallbackQueue() {
	}


	synchronized void EnqueueCallback(InlineJavaCallback ijc) {
		queue.add(ijc) ;
		notify() ;
	}


	synchronized private InlineJavaCallback DequeueCallback() {
		if (queue.size() > 0){
			return (InlineJavaCallback)queue.remove(0) ;
		}
		return null ;
	}


	synchronized InlineJavaCallback WaitForCallback(){
		while ((! stop_loop)&&(IsEmpty())){
			try {
				wait() ;
			}
			catch (InterruptedException ie){
				// Do nothing, return and wait() some more...
			}
		}
		return DequeueCallback() ;
	}


	private boolean IsEmpty(){
		return (queue.size() == 0) ;
	}


	void StartLoop(){
		stop_loop = false ;
	}


	synchronized void StopLoop(){
		stop_loop = true ;
		notify() ;
	}


	boolean IsLoopStopped(){
		return stop_loop ;
	}
}
