package org.perl.inline.java ;


/*
	InlineJavaPerlObject
*/
public class InlineJavaPerlObject extends InlineJavaPerlCaller {
	private int id = 0 ;
	private String pkg = null ;


	/* 
		Creates a Perl Object by calling 
			pkg->new(args) ;
	*/
	public InlineJavaPerlObject(String _pkg, Object args[]) throws InlineJavaPerlException, InlineJavaException {
		pkg = _pkg ;
		InlineJavaPerlObject stub = (InlineJavaPerlObject)CallPerlStaticMethod(pkg, "new", args, getClass()) ;
		id = stub.GetId() ;
		stub.id = 0 ;
	}


	/*
		This is just a stub for already existing objects
	*/
	InlineJavaPerlObject(String _pkg, int _id) throws InlineJavaException {
		pkg = _pkg ;
		id = _id ;
	}


	public int GetId(){
		return id ;
	}


	public String GetPkg(){
		return pkg ;
	}


	public Object InvokeMethod(String name, Object args[]) throws InlineJavaPerlException, InlineJavaException {
		return InvokeMethod(name, args, null) ;
	}


	public Object InvokeMethod(String name, Object args[], Class cast) throws InlineJavaPerlException, InlineJavaException {
		return CallPerlMethod(this, name, args, cast) ;
	}


	public void Done() throws InlineJavaPerlException, InlineJavaException {
		Done(false) ;
	}


	protected void Done(boolean gc) throws InlineJavaPerlException, InlineJavaException {
		if (id != 0){
			CallPerlSub("Inline::Java::Callback::java_finalize", new Object [] {new Integer(id), new Boolean(gc)}) ;
		}
	}


	protected void finalize() throws Throwable {
		try {
			Done(true) ;
		}
		finally {
			super.finalize() ;
		}
	}
}
