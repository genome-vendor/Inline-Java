package org.perl.inline.java ;

import java.util.* ;


/*
	Creates a string representing a method signature
*/
class InlineJavaUtils { 
	static int debug = 0 ;


	static String CreateSignature(Class param[]){
		return CreateSignature(param, ", ") ;
	}


	static String CreateSignature(Class param[], String del){
		StringBuffer ret = new StringBuffer() ;
		for (int i = 0 ; i < param.length ; i++){
			if (i > 0){
				ret.append(del) ;
			}
			ret.append(param[i].getName()) ;
		}

		return "(" + ret.toString() + ")" ;
	}


	synchronized static void debug(int level, String s) {
		if ((debug > 0)&&(debug >= level)){
			StringBuffer sb = new StringBuffer() ;
			for (int i = 0 ; i < level ; i++){
				sb.append(" ") ;
			}
			System.err.println("[java][" + level + "]" + sb.toString() + s) ;
			System.err.flush() ;
		}
	}


	static void Fatal(String msg){
		System.err.println(msg) ;
		System.err.flush() ;
		System.exit(1) ;
	}


	static boolean ReverseMembers() {
		String v = System.getProperty("java.version") ;
		boolean no_rev = ((v.startsWith("1.2"))||(v.startsWith("1.3"))) ;

		return (! no_rev) ;
	}
}
