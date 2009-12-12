package org.perl.inline.java ;

import java.util.* ;
import java.lang.reflect.* ;


/*
	This is where most of the work of Inline Java is done. Here determine
	the request type and then we proceed to serve it.
*/
class InlineJavaProtocol {
	private InlineJavaServer ijs ;
	private InlineJavaClass ijc ;
	private InlineJavaArray ija ;
	private String cmd ;
	private String response = null ;

	static private HashMap member_cache = new HashMap() ;

	InlineJavaProtocol(InlineJavaServer _ijs, String _cmd) {
		ijs = _ijs ;
		ijc = new InlineJavaClass(ijs, this) ;
		ija = new InlineJavaArray(ijc) ;

		cmd = _cmd ;	
	}


	/*
		Starts the analysis of the command line
	*/
	void Do() throws InlineJavaException {
		StringTokenizer st = new StringTokenizer(cmd, " ") ;
		String c = st.nextToken() ;

		if (c.equals("call_method")){
			CallJavaMethod(st) ;
		}		
		else if (c.equals("set_member")){
			SetJavaMember(st) ;
		}		
		else if (c.equals("get_member")){
			GetJavaMember(st) ;
		}		
		else if (c.equals("add_classpath")){
			AddClassPath(st) ;
		}
		else if (c.equals("server_type")){
			ServerType(st) ;
		}
		else if (c.equals("report")){
			Report(st) ;
		}
		else if (c.equals("isa")){
			IsA(st) ;
		}
		else if (c.equals("create_object")){
			CreateJavaObject(st) ;
		}
		else if (c.equals("delete_object")){
			DeleteJavaObject(st) ;
		}
		else if (c.equals("obj_cnt")){
			ObjectCount(st) ;
		}
		else if (c.equals("die")){
			InlineJavaUtils.debug(1, "received a request to die...") ;
			ijs.Shutdown() ;
		}
		else {
			throw new InlineJavaException("Unknown command " + c) ;
		}
	}

	/*
		Returns a report on the Java classes, listing all public methods
		and members
	*/
	void Report(StringTokenizer st) throws InlineJavaException {
		StringBuffer pw = new StringBuffer() ;

		StringTokenizer st2 = new StringTokenizer(st.nextToken(), ":") ;
		st2.nextToken() ;

		StringTokenizer st3 = new StringTokenizer(Decode(st2.nextToken()), " ") ;

		ArrayList class_list = new ArrayList() ;
		while (st3.hasMoreTokens()){
			String c = st3.nextToken() ;
			class_list.add(class_list.size(), c) ;
		}

		for (int i = 0 ; i < class_list.size() ; i++){
			String name = (String)class_list.get(i) ;
			Class c = ijc.ValidateClass(name) ;

			InlineJavaUtils.debug(3, "reporting for " + c) ;

			Class parent = c.getSuperclass() ;
			String pname = (parent == null ? "null" : parent.getName()) ;
			pw.append("class " + c.getName() + " " + pname + "\n") ;
			Constructor constructors[] = c.getConstructors() ;
			Method methods[] = c.getMethods() ;
			Field fields[] = c.getFields() ;

			int pub = c.getModifiers() & Modifier.PUBLIC ;
			if (pub != 0){
				// If the class is public and has no constructors,
				// we provide a default no-arg constructors.
				if (c.getDeclaredConstructors().length == 0){
					String noarg_sign = InlineJavaUtils.CreateSignature(new Class [] {}) ;
					pw.append("constructor " + noarg_sign + "\n") ;	
				}
			}

			boolean pn = InlineJavaPerlNatives.class.isAssignableFrom(c) ;
			for (int j = 0 ; j < constructors.length ; j++){
				Constructor x = constructors[j] ;
				if ((pn)&&(Modifier.isNative(x.getModifiers()))){
					continue ;
				}
				Class params[] = x.getParameterTypes() ;
				String sign = InlineJavaUtils.CreateSignature(params) ;
				Class decl = x.getDeclaringClass() ;
				pw.append("constructor " + sign + "\n") ;
			}

			for (int j = 0 ; j < methods.length ; j++){
				Method x = methods[j] ;
				if ((pn)&&(Modifier.isNative(x.getModifiers()))){
					continue ;
				}
				String stat = (Modifier.isStatic(x.getModifiers()) ? " static " : " instance ") ;
				String sign = InlineJavaUtils.CreateSignature(x.getParameterTypes()) ;
				Class decl = x.getDeclaringClass() ;
				pw.append("method" + stat + decl.getName() + " " + x.getName() + sign + "\n") ;
			}

			for (int j = 0 ; j < fields.length ; j++){
				Field x = fields[(InlineJavaUtils.ReverseMembers() ? (fields.length - 1 - j) : j)] ;
				String stat = (Modifier.isStatic(x.getModifiers()) ? " static " : " instance ") ;
				Class decl = x.getDeclaringClass() ;
				Class type = x.getType() ;
				pw.append("field" + stat + decl.getName() + " " + x.getName() + " " + type.getName() + "\n") ;
			}
		}

		SetResponse(pw.toString()) ;
	}


	void AddClassPath(StringTokenizer st) throws InlineJavaException {
		while (st.hasMoreTokens()){
			String path = Decode(st.nextToken()) ;
			InlineJavaServer.GetInstance().GetUserClassLoader().AddClassPath(path) ;
		}
		SetResponse(null) ;
	}


	void ServerType(StringTokenizer st) throws InlineJavaException {
		SetResponse(ijs.GetType()) ;
	}


	void IsA(StringTokenizer st) throws InlineJavaException {
		String class_name = st.nextToken() ;
		Class c = ijc.ValidateClass(class_name) ;

		String is_it_a = st.nextToken() ;
		Class d = ijc.ValidateClass(is_it_a) ;

		SetResponse(new Integer(ijc.DoesExtend(c, d))) ;
	}


	void ObjectCount(StringTokenizer st) throws InlineJavaException {
		SetResponse(new Integer(ijs.ObjectCount())) ;
	}


	/*
		Creates a Java Object with the specified arguments.
	*/
	void CreateJavaObject(StringTokenizer st) throws InlineJavaException {
		String class_name = st.nextToken() ;
		Class c = ijc.ValidateClass(class_name) ;

		if (! ijc.ClassIsArray(c)){
			ArrayList f = ValidateMethod(true, c, class_name, st) ;
			Object p[] = (Object [])f.get(1) ;
			Class clist[] = (Class [])f.get(2) ;

			try {
				Object o = CreateObject(c, p, clist) ;
				SetResponse(o) ;
			}
			catch (InlineJavaInvocationTargetException ite){
				Throwable t = ite.GetThrowable() ;
				if (t instanceof InlineJavaException){
					InlineJavaException ije = (InlineJavaException)t ;
					throw ije ;
				}
				else{
					SetResponse(new InlineJavaThrown(t)) ;
				}
			}
		}
		else{
			// Here we send the type of array we want, but CreateArray
			// exception the element type.
			StringBuffer sb = new StringBuffer(class_name) ;
			// Remove the ['s
			while (sb.toString().startsWith("[")){
				sb.replace(0, 1, "") ;	
			}
			// remove the L and the ;
			if (sb.toString().startsWith("L")){
				sb.replace(0, 1, "") ;
				sb.replace(sb.length() - 1, sb.length(), "") ;
			}

			Class ec = ijc.ValidateClass(sb.toString()) ;

			InlineJavaUtils.debug(4, "array elements: " + ec.getName()) ;
			Object o = ija.CreateArray(ec, st) ;
			SetResponse(o) ;
		}
	}


	/*
		Calls a Java method
	*/
	void CallJavaMethod(StringTokenizer st) throws InlineJavaException {
		int id = Integer.parseInt(st.nextToken()) ;

		String class_name = st.nextToken() ;
		Object o = null ;
		if (id > 0){
			o = ijs.GetObject(id) ;

			// Use the class of the object
			class_name = o.getClass().getName() ;
		}

		Class c = ijc.ValidateClass(class_name) ;
		String method = st.nextToken() ;

		if ((ijc.ClassIsArray(c))&&(method.equals("getLength"))){
			int length = Array.getLength(o) ;
			SetResponse(new Integer(length)) ;
		}
		else{
			ArrayList f = ValidateMethod(false, c, method, st) ;
			Method m = (Method)f.get(0) ;
			String name = m.getName() ;	
			Object p[] = (Object [])f.get(1) ;

			try {
				Object ret = InlineJavaServer.GetInstance().GetUserClassLoader().invoke(m, o, p) ;
				SetResponse(ret) ;
			}
			catch (IllegalAccessException e){
				throw new InlineJavaException("You are not allowed to invoke method " + name + " in class " + class_name + ": " + e.getMessage()) ;
			}
			catch (IllegalArgumentException e){
				throw new InlineJavaException("Arguments for method " + name + " in class " + class_name + " are incompatible: " + e.getMessage()) ;
			}
			catch (InvocationTargetException e){
				Throwable t = e.getTargetException() ;
				String type = t.getClass().getName() ;
				String msg = t.getMessage() ;
				InlineJavaUtils.debug(1, "method " + name + " in class " + class_name + " threw exception " + type + ": " + msg) ;
				if (t instanceof InlineJavaException){
					InlineJavaException ije = (InlineJavaException)t ;
					throw ije ;
				}
				else{
					SetResponse(new InlineJavaThrown(t)) ;
				}
			}
		}
	}


	/*
		Sets a Java member variable
	*/
	void SetJavaMember(StringTokenizer st) throws InlineJavaException {
		int id = Integer.parseInt(st.nextToken()) ;

		String class_name = st.nextToken() ;
		Object o = null ;
		if (id > 0){
			o = ijs.GetObject(id) ;

			// Use the class of the object
			class_name = o.getClass().getName() ;
		}

		Class c = ijc.ValidateClass(class_name) ;
		String member = st.nextToken() ;

		if (ijc.ClassIsArray(c)){
			int idx = Integer.parseInt(member) ;
			Class type = ijc.ValidateClass(st.nextToken()) ;
			String arg = st.nextToken() ;

			String msg = "For array of type " + c.getName() + ", element " + member + ": " ;
			try {
				Object elem = ijc.CastArgument(type, arg) ;
				InlineJavaServer.GetInstance().GetUserClassLoader().array_set(o, idx, elem) ;
				SetResponse(null) ;
			}
			catch (InlineJavaCastException e){
				throw new InlineJavaCastException(msg + e.getMessage()) ;
			}
			catch (InlineJavaException e){
				throw new InlineJavaException(msg + e.getMessage()) ;
			}
		}
		else{
			ArrayList fl = ValidateMember(c, member, st) ;
			Field f = (Field)fl.get(0) ;
			String name = f.getName() ;
			Object p = (Object)fl.get(1) ;

			try {
				InlineJavaServer.GetInstance().GetUserClassLoader().set(f, o, p) ;
				SetResponse(null) ;
			}
			catch (IllegalAccessException e){
				throw new InlineJavaException("You are not allowed to set member " + name + " in class " + class_name + ": " + e.getMessage()) ;
			}
			catch (IllegalArgumentException e){
				throw new InlineJavaException("Argument for member " + name + " in class " + class_name + " is incompatible: " + e.getMessage()) ;
			}
		}
	}


	/*
		Gets a Java member variable
	*/
	void GetJavaMember(StringTokenizer st) throws InlineJavaException {
		int id = Integer.parseInt(st.nextToken()) ;

		String class_name = st.nextToken() ;
		Object o = null ;
		if (id > 0){
			o = ijs.GetObject(id) ;

			// Use the class of the object
			class_name = o.getClass().getName() ;
		}

		Class c = ijc.ValidateClass(class_name) ;
		String member = st.nextToken() ;

		if (ijc.ClassIsArray(c)){
			int idx = Integer.parseInt(member) ;
			Object ret = InlineJavaServer.GetInstance().GetUserClassLoader().array_get(o, idx) ;
			SetResponse(ret) ;
		}
		else{
			ArrayList fl = ValidateMember(c, member, st) ;

			Field f = (Field)fl.get(0) ;
			String name = f.getName() ;
			try {
				Object ret = InlineJavaServer.GetInstance().GetUserClassLoader().get(f, o) ;
				SetResponse(ret) ;
			}
			catch (IllegalAccessException e){
				throw new InlineJavaException("You are not allowed to set member " + name + " in class " + class_name + ": " + e.getMessage()) ;
			}
			catch (IllegalArgumentException e){
				throw new InlineJavaException("Argument for member " + name + " in class " + class_name + " is incompatible: " + e.getMessage()) ;
			}
		}
	}


	/*
		Deletes a Java object
	*/
	void DeleteJavaObject(StringTokenizer st) throws InlineJavaException {
		int id = Integer.parseInt(st.nextToken()) ;

		Object o = ijs.DeleteObject(id) ;

		SetResponse(null) ;
	}

	
	/*
		Creates a Java Object with the specified arguments.
	*/
	Object CreateObject(Class p, Object args[], Class proto[]) throws InlineJavaException {
		p = ijc.FindWrapper(p) ;

		String name = p.getName() ;
		Object ret = null ;
		try {
			ret = InlineJavaServer.GetInstance().GetUserClassLoader().create(p, args, proto) ;
		}
		catch (NoSuchMethodException e){
			throw new InlineJavaException("Constructor for class " + name + " with signature " + InlineJavaUtils.CreateSignature(proto) + " not found: " + e.getMessage()) ;
		}
		catch (InstantiationException e){
			throw new InlineJavaException("You are not allowed to instantiate object of class " + name + ": " + e.getMessage()) ;
		}
		catch (IllegalAccessException e){
			throw new InlineJavaException("You are not allowed to instantiate object of class " + name + " using the constructor with signature " + InlineJavaUtils.CreateSignature(proto) + ": " + e.getMessage()) ;
		}
		catch (IllegalArgumentException e){
			throw new InlineJavaException("Arguments to constructor for class " + name + " with signature " + InlineJavaUtils.CreateSignature(proto) + " are incompatible: " + e.getMessage()) ;
		}
		catch (InvocationTargetException e){
			Throwable t = e.getTargetException() ;
			String type = t.getClass().getName() ;
			String msg = t.getMessage() ;
			throw new InlineJavaInvocationTargetException(
				"Constructor for class " + name + " with signature " + InlineJavaUtils.CreateSignature(proto) + " threw exception " + type + ": " + msg,
				t) ;
		}

		return ret ;
	}


	/*
		Makes sure a method exists
	*/
	ArrayList ValidateMethod(boolean constructor, Class c, String name, StringTokenizer st) throws InlineJavaException {
		ArrayList ret = new ArrayList() ;

		// Extract signature
		String signature = st.nextToken() ;

		// Extract the arguments
		ArrayList args = new ArrayList() ;
		while (st.hasMoreTokens()){
			args.add(args.size(), st.nextToken()) ;
		}

		String key = c.getName() + "." + name + signature ;
		ArrayList ml = new ArrayList() ;
		Class params[] = null ;

		Member cached = (Member)member_cache.get(key) ;
		if (cached != null){
				InlineJavaUtils.debug(3, "method was cached") ;
				ml.add(ml.size(), cached) ;
		}
		else{
			Member ma[] = (constructor ? (Member [])c.getConstructors() : (Member [])c.getMethods()) ;
			for (int i = 0 ; i < ma.length ; i++){
				Member m = ma[i] ;

				if (m.getName().equals(name)){
					InlineJavaUtils.debug(3, "found a " + name + (constructor ? " constructor" : " method")) ;
	
					if (constructor){
						params = ((Constructor)m).getParameterTypes() ;
					}
					else{
						params = ((Method)m).getParameterTypes() ;
					}

					// Now we check if the signatures match
					String sign = InlineJavaUtils.CreateSignature(params, ",") ;
					InlineJavaUtils.debug(3, sign + " = " + signature + "?") ;

					if (signature.equals(sign)){
						InlineJavaUtils.debug(3, "has matching signature " + sign) ;
						ml.add(ml.size(), m) ;
						member_cache.put(key, m) ;
						break ;
					}
				}
			}
		}

		// Now we got a list of matching methods (actually 0 or 1). 
		// We have to figure out which one we will call.
		if (ml.size() == 0){
			// Nothing matched. Maybe we got a default constructor
			if ((constructor)&&(signature.equals("()"))){
				ret.add(0, null) ;
				ret.add(1, new Object [] {}) ;
				ret.add(2, new Class [] {}) ;
			}
			else{
				throw new InlineJavaException(
					(constructor ? "Constructor " : "Method ") + 
					name + " for class " + c.getName() + " with signature " +
					signature + " not found") ;
			}
		}
		else if (ml.size() == 1){
			// Now we need to force the arguments received to match
			// the methods signature.
			Member m = (Member)ml.get(0) ;
			if (constructor){
				params = ((Constructor)m).getParameterTypes() ;
			}
			else{
				params = ((Method)m).getParameterTypes() ;
			}

			String msg = "In method " + name + " of class " + c.getName() + ": " ;
			try {
				ret.add(0, m) ;
				ret.add(1, ijc.CastArguments(params, args)) ;
				ret.add(2, params) ;
			}
			catch (InlineJavaCastException e){
				throw new InlineJavaCastException(msg + e.getMessage()) ;
			}
			catch (InlineJavaException e){
				throw new InlineJavaException(msg + e.getMessage()) ;
			}
		}

		return ret ;
	}


	/*
		Makes sure a member exists
	*/
	ArrayList ValidateMember(Class c, String name, StringTokenizer st) throws InlineJavaException {
		ArrayList ret = new ArrayList() ;

		// Extract member type
		String type = st.nextToken() ;

		// Extract the argument
		String arg = st.nextToken() ;

		String key = type + " " + c.getName() + "." + name ;
		ArrayList fl = new ArrayList() ;
		Class param = null ;

		Member cached = (Member)member_cache.get(key) ;
		if (cached != null){
			InlineJavaUtils.debug(3, "member was cached") ;
			fl.add(fl.size(), cached) ;
		}
		else {
			Field fa[] = c.getFields() ;
			for (int i = 0 ; i < fa.length ; i++){
				Field f = fa[(InlineJavaUtils.ReverseMembers() ? (fa.length - 1 - i) : i)] ;

				if (f.getName().equals(name)){
					InlineJavaUtils.debug(3, "found a " + name + " member") ;

					param = f.getType() ;
					String t = param.getName() ;
					if (type.equals(t)){
						InlineJavaUtils.debug(3, "has matching type " + t) ;
						fl.add(fl.size(), f) ;
					}
				}
			}
		}

		// Now we got a list of matching members. 
		// We have to figure out which one we will call.
		if (fl.size() == 0){
			throw new InlineJavaException(
				"Member " + name + " of type " + type + " for class " + c.getName() +
					" not found") ;
		}
		else {
			// Now we need to force the arguments received to match
			// the methods signature.

			// If we have more that one, we use the last one, which is the most
			// specialized
			Field f = (Field)fl.get(fl.size() - 1) ;
			member_cache.put(key, f) ;
			param = f.getType() ;

			String msg = "For member " + name + " of class " + c.getName() + ": " ;
			try {
				ret.add(0, f) ;
				ret.add(1, ijc.CastArgument(param, arg)) ;
				ret.add(2, param) ;
			}
			catch (InlineJavaCastException e){
				throw new InlineJavaCastException(msg + e.getMessage()) ;
			}
			catch (InlineJavaException e){
				throw new InlineJavaException(msg + e.getMessage()) ;
			}
		}

		return ret ;
	}


	/*
		This sets the response that will be returned to the Perl
		script
	*/
	void SetResponse (Object o) throws InlineJavaException {
		response = "ok " + SerializeObject(o) ;
	}


	String SerializeObject(Object o) throws InlineJavaException {
		if (o == null){
			return "undef:" ;
		}
		else if ((ijc.ClassIsNumeric(o.getClass()))||(ijc.ClassIsChar(o.getClass()))||(ijc.ClassIsString(o.getClass()))){
			return "scalar:" + Encode(o.toString()) ;
		}
		else if (ijc.ClassIsBool(o.getClass())){
			String b = o.toString() ;
			return "scalar:" + Encode((b.equals("true") ? "1" : "0")) ;
		}
		else {
			// Here we need to register the object in order to send
			// it back to the Perl script.
			boolean thrown = false ;
			if (o instanceof InlineJavaThrown){ 
				thrown = true ;
				o = ((InlineJavaThrown)o).GetThrowable() ;
			}			
			int id = ijs.PutObject(o) ;
			return "object:" + (thrown ? "1" : "0") + ":" + String.valueOf(id) +
				":" + o.getClass().getName() ;
		}
	}


	String Decode(String s){
		StringTokenizer st = new StringTokenizer(s, ".") ;
		StringBuffer sb = new StringBuffer() ;
		while (st.hasMoreTokens()){
			String ss = st.nextToken() ; 
			char c = (char)Integer.parseInt(ss) ;
			sb.append(new String(new char [] {c})) ;
		}
	
		return sb.toString() ;
	}


	String Encode(String s){
		char c[] = new char[s.length()] ;
		s.getChars(0, c.length, c, 0) ;
		StringBuffer sb = new StringBuffer() ;
		for (int i = 0 ; i < c.length ; i++){
			if (i > 0){
				sb.append(".") ;
			}
			sb.append((int)c[i]) ;
		}

		return sb.toString() ;
	}


	String GetResponse(){
		return response ;
	}
}
