package org.perl.inline.java ;


public class InlineJavaPerlException extends Exception {
	private Object obj ;


	public InlineJavaPerlException(Object o){
		obj = o ;
	}

	public Object GetObject(){
		return obj ;
	}

	public String GetString(){
		return (String)obj ;
	}
}
