package org.perl.inline.java ;

/*
	Callback to Perl...
*/
public class InlineJavaPerlCaller {
	public InlineJavaPerlCaller(){
	}


	public Object CallPerl(String pkg, String method, Object args[]) throws InlineJavaException, InlineJavaPerlException {
		return CallPerl(pkg, method, args, null) ;
	}


	public Object CallPerl(String pkg, String method, Object args[], String cast) throws InlineJavaException, InlineJavaPerlException {
		return InlineJavaServer.GetInstance().Callback(pkg, method, args, cast) ;
	}
}
