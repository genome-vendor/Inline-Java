package Inline::Java::Protocol ;


use strict ;

$Inline::Java::Protocol::VERSION = '0.22' ;

use Inline::Java::Object ;
use Inline::Java::Array ;
use Carp ;


sub new {
	my $class = shift ;
	my $obj = shift ;
	my $inline = shift ;

	my $this = {} ;
	$this->{obj_priv} = $obj || {} ;
	$this->{module} = $inline->get_api('modfname') ;

	bless($this, $class) ;
	return $this ;
}


sub Report {
	my $this = shift ;
	my $classes = shift ;

	Inline::Java::debug("reporting on $classes") ;

	my $data = join(" ", 
		"report", 
		$this->ValidateArgs([$classes]),
	) ;

	return $this->Send($data, 1) ;
}


sub ISA {
	my $this = shift ;
	my $proto = shift ;

	my $id = $this->{obj_priv}->{id} ;
	my $class = $this->{obj_priv}->{java_class} ;

	Inline::Java::debug("checking if $class is a $proto") ;

	my $data = join(" ", 
		"isa", 
		$id,
		Inline::Java::Class::ValidateClass($class),
		Inline::Java::Class::ValidateClass($proto),
	) ;

	return $this->Send($data, 1) ;
}


# Called to create a Java object
sub CreateJavaObject {
	my $this = shift ;
	my $class = shift ;
	my $proto = shift ;
	my $args = shift ;

	Inline::Java::debug("creating object new $class" . $this->CreateSignature($args)) ; 	

	my $data = join(" ", 
		"create_object", 
		Inline::Java::Class::ValidateClass($class),
		$this->CreateSignature($proto, ","),
		$this->ValidateArgs($args),
	) ;

	return $this->Send($data, 1) ;
}


# Calls a Java method.
sub CallJavaMethod {
	my $this = shift ;
	my $method = shift ;
	my $proto = shift ;
	my $args = shift ;

	my $id = $this->{obj_priv}->{id} ;
	my $class = $this->{obj_priv}->{java_class} ;
	Inline::Java::debug("calling object($id).$method" . $this->CreateSignature($args)) ;

	my $data = join(" ", 
		"call_method", 
		$id,
		Inline::Java::Class::ValidateClass($class),
		$this->ValidateMethod($method),
		$this->CreateSignature($proto, ","),
		$this->ValidateArgs($args),
	) ;

	return $this->Send($data) ;
}


# Sets a member variable.
sub SetJavaMember {
	my $this = shift ;
	my $member = shift ;
	my $proto = shift ;
	my $arg = shift ;

	my $id = $this->{obj_priv}->{id} ;
	my $class = $this->{obj_priv}->{java_class} ;
	Inline::Java::debug("setting object($id)->{$member} = " . ($arg->[0] || '')) ;
	my $data = join(" ", 
		"set_member", 
		$id,
		Inline::Java::Class::ValidateClass($class),
		$this->ValidateMember($member),
		Inline::Java::Class::ValidateClass($proto->[0]),
		$this->ValidateArgs($arg),
	) ;

	return $this->Send($data) ;
}


# Gets a member variable.
sub GetJavaMember {
	my $this = shift ;
	my $member = shift ;
	my $proto = shift ;

	my $id = $this->{obj_priv}->{id} ;
	my $class = $this->{obj_priv}->{java_class} ;
	Inline::Java::debug("getting object($id)->{$member}") ;

	my $data = join(" ", 
		"get_member", 
		$id,
		Inline::Java::Class::ValidateClass($class),
		$this->ValidateMember($member),
		Inline::Java::Class::ValidateClass($proto->[0]),
		"undef:",
	) ;

	return $this->Send($data) ;
}


# Deletes a Java object
sub DeleteJavaObject {
	my $this = shift ;
	my $obj = shift ;

	if (defined($this->{obj_priv}->{id})){
		my $id = $this->{obj_priv}->{id} ;
		my $class = $this->{obj_priv}->{java_class} ;

		Inline::Java::debug("deleting object $obj $id ($class)") ;

		my $data = join(" ", 
			"delete_object", 
			$id,
		) ;

		$this->Send($data) ;
	}
}


# This method makes sure that the method we are asking for
# has the correct form for a Java method.
sub ValidateMethod {
	my $this = shift ;
	my $method = shift ;

	if ($method !~ /^(\w+)$/){
		croak "Invalid Java method name $method" ;
	}	

	return $method ;
}


# This method makes sure that the member we are asking for
# has the correct form for a Java member.
sub ValidateMember {
	my $this = shift ;
	my $member = shift ;

	if ($member !~ /^(\w+)$/){
		croak "Invalid Java member name $member" ;
	}	

	return $member ;
}


# Validates the arguments to be used in a method call.
sub ValidateArgs {
	my $this = shift ;
	my $args = shift ;

	my @ret = () ;
	foreach my $arg (@{$args}){
		if (! defined($arg)){
			push @ret, "undef:" ;
		}
		elsif (ref($arg)){
			if ((! UNIVERSAL::isa($arg, "Inline::Java::Object"))&&(! UNIVERSAL::isa($arg, "Inline::Java::Array"))){
				croak "A Java method or member can only have Java objects, Java arrays or scalars as arguments" ;
			}

			my $obj = $arg ;
			if (UNIVERSAL::isa($arg, "Inline::Java::Array")){
				$obj = $arg->__get_object() ; 
			}
			my $class = $obj->__get_private()->{java_class} ;
			my $id = $obj->__get_private()->{id} ;
			push @ret, "object:$class:$id" ;
		}
		else{
			push @ret, "scalar:" . join(".", unpack("C*", $arg)) ;
		}
	}

	return @ret ;
}


sub CreateSignature {
	my $this = shift ;
	my $proto = shift ;
	my $del = shift || ", " ;

	my @p = map {$_ || ''} @{$proto} ;

	return "(" . join($del, @p) . ")" ;
}


# This actually sends the request to the Java program. It also takes
# care of registering the returned object (if any)
sub Send {
	my $this = shift ;
	my $data = shift ;
	my $const = shift ;

	my $resp = Inline::Java::get_JVM()->process_command($data) ;

	if ($resp =~ /^error scalar:([\d.]*)$/){
		my $msg = pack("C*", split(/\./, $1)) ;
		Inline::Java::debug("  packet recv error: $msg") ;
		croak $msg ;
	}
	elsif ($resp =~ /^ok scalar:([\d.]*)$/){
		return pack("C*", split(/\./, $1)) ; 
	}
	elsif ($resp =~ /^ok undef:$/){
		return undef ;
	}
	elsif ($resp =~ /^ok object:(\d+):(.*)$/){
		# Create the Perl object wrapper and return it.
		my $id = $1 ;
		my $class = $2 ;

		if ($const){
			$this->{obj_priv}->{java_class} = $class ;
			$this->{obj_priv}->{id} = $id ;

			return undef ;
		}
		else{
			my $inline = Inline::Java::get_INLINE($this->{module}) ;
			my $pkg = $inline->get_api('pkg') ;

			my $obj = undef ;
			my $elem_class = $class ;

			Inline::Java::debug("checking if stub is array...") ;
			if (Inline::Java::Class::ClassIsArray($class)){
				my @d = Inline::Java::Class::ValidateClassSplit($class) ;
				$elem_class = $d[2] ;
			}

			my $perl_class = Inline::Java::java2perl($pkg, $elem_class) ;
			if (Inline::Java::Class::ClassIsReference($elem_class)){
				if (! Inline::Java::known_to_perl($pkg, $elem_class)){
					if ($inline->get_java_config('AUTOSTUDY')){
						$inline->_study([$elem_class]) ;
					}
					else{
						$perl_class = "Inline::Java::Object" ;
					}
			 	}
			}
			else{
				# We should only get here if an array of primitives types
				# was returned, and there is nothing to do since
				# the block below will handle it.
			}

			if (Inline::Java::Class::ClassIsArray($class)){
				Inline::Java::debug("creating array object...") ;
				$obj = Inline::Java::Object->__new($class, $inline, $id) ;
				$obj = new Inline::Java::Array($obj) ;
				Inline::Java::debug("array object created...") ;
			}
			else{
				$obj = $perl_class->__new($class, $inline, $id) ;
			}

			Inline::Java::debug("returning stub...") ;
			return $obj ;
		}
	}
}


sub DESTROY {
	my $this = shift ;

	Inline::Java::debug("Destroying Inline::Java::Protocol") ;
}



1 ;



__DATA__


/*
	This is where most of the work of Inline Java is done. Here determine
	the request type and then we proceed to serve it.
*/
class InlineJavaProtocol {
	InlineJavaServer ijs ;
	InlineJavaClass ijc ;
	InlineJavaArray ija ;
	String cmd ;
	String response ;

	InlineJavaProtocol(InlineJavaServer _ijs, String _cmd) {
		ijs = _ijs ;
		ijc = new InlineJavaClass(ijs, this) ;
		ija = new InlineJavaArray(ijs, ijc) ;

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
		else if (c.equals("report")){
			Report(st) ;
		}
		else if (c.equals("isa")){
			ISA(st) ;
		}
		else if (c.equals("create_object")){
			CreateJavaObject(st) ;
		}
		else if (c.equals("delete_object")){
			DeleteJavaObject(st) ;
		}
		else if (c.equals("die")){
			ijs.debug("  received a request to die...") ;
			System.exit(0) ;
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

		StringTokenizer st3 = new StringTokenizer(pack(st2.nextToken()), " ") ;

		ArrayList class_list = new ArrayList() ;
		while (st3.hasMoreTokens()){
			String c = st3.nextToken() ;
			class_list.add(class_list.size(), c) ;
		}

		for (int i = 0 ; i < class_list.size() ; i++){
			String name = (String)class_list.get(i) ;
			Class c = ijc.ValidateClass(name) ;

			ijs.debug("reporting for " + c) ;
													
			pw.append("class " + c.getName() + "\n") ;
			Constructor constructors[] = c.getConstructors() ;
			Method methods[] = c.getMethods() ;
			Field fields[] = c.getFields() ;

			int pub = c.getModifiers() & Modifier.PUBLIC ;
			if (pub != 0){
				// If the class is public and has no constructors,
				// we provide a default no-arg constructors.
				if (c.getDeclaredConstructors().length == 0){
					String noarg_sign = CreateSignature(new Class [] {}) ;
					pw.append("constructor " + noarg_sign + "\n") ;	
				}
			}
			for (int j = 0 ; j < constructors.length ; j++){
				Constructor x = constructors[j] ;
				Class params[] = x.getParameterTypes() ;
				String sign = CreateSignature(params) ;
				Class decl = x.getDeclaringClass() ;
				pw.append("constructor " + sign + "\n") ;
			}

			for (int j = 0 ; j < methods.length ; j++){
				Method x = methods[j] ;
				String stat = (Modifier.isStatic(x.getModifiers()) ? " static " : " instance ") ;
				String sign = CreateSignature(x.getParameterTypes()) ;
				Class decl = x.getDeclaringClass() ;
				pw.append("method" + stat + decl.getName() + " " + x.getName() + sign + "\n") ;
			}

			for (int j = 0 ; j < fields.length ; j++){
				Field x = fields[j] ;
				String stat = (Modifier.isStatic(x.getModifiers()) ? " static " : " instance ") ;
				Class decl = x.getDeclaringClass() ;
				Class type = x.getType() ;
				pw.append("field" + stat + decl.getName() + " " + x.getName() + " " + type.getName() + "\n") ;
			}
		}

		SetResponse(pw.toString()) ;
	}


	void ISA(StringTokenizer st) throws InlineJavaException {
		int id = Integer.parseInt(st.nextToken()) ;

		String class_name = st.nextToken() ;
		Class c = ijc.ValidateClass(class_name) ;

		String is_it_a = st.nextToken() ;
		Class d = ijc.ValidateClass(is_it_a) ;

		Integer oid = new Integer(id) ;
		Object o = ijs.objects.get(oid) ;
		if (o == null){
			throw new InlineJavaException("Object " + oid.toString() + " is not in HashMap!") ;
		}

		SetResponse(new Integer(ijc.DoesExtend(c, d))) ;
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

			Object o = CreateObject(c, p, clist) ;
			SetResponse(o) ;
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

			ijs.debug("    array elements: " + ec.getName()) ;
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
			Integer oid = new Integer(id) ;
			o = ijs.objects.get(oid) ;
			if (o == null){
				throw new InlineJavaException("Object " + oid.toString() + " is not in HashMap!") ;
			}

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
				Object ret = m.invoke(o, p) ;
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
				throw new InlineJavaException(
					"Method " + name + " in class " + class_name + " threw exception " + type + ": " + msg) ;
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
			Integer oid = new Integer(id) ;
			o = ijs.objects.get(oid) ;
			if (o == null){
				throw new InlineJavaException("Object " + oid.toString() + " is not in HashMap!") ;
			}

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
				Array.set(o, idx, elem) ;
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
				f.set(o, p) ;
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
			Integer oid = new Integer(id) ;
			o = ijs.objects.get(oid) ;
			if (o == null){
				throw new InlineJavaException("Object " + oid.toString() + " is not in HashMap!") ;
			}

			// Use the class of the object
			class_name = o.getClass().getName() ;
		}

		Class c = ijc.ValidateClass(class_name) ;
		String member = st.nextToken() ;

		if (ijc.ClassIsArray(c)){
			int idx = Integer.parseInt(member) ;
			SetResponse(Array.get(o, idx)) ;
		}
		else{
			ArrayList fl = ValidateMember(c, member, st) ;

			Field f = (Field)fl.get(0) ;
			String name = f.getName() ;
			try {
				Object ret = f.get(o) ;
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

		Integer oid = new Integer(id) ;
		Object o = ijs.objects.remove(oid) ;

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
			// This will allow usage of the default no-arg constructor
			if (proto.length == 0){
				ret = p.newInstance() ;
			}
			else{
				Constructor con = (Constructor)p.getConstructor(proto) ;
				ret = con.newInstance(args) ;
			}
		}
		catch (NoSuchMethodException e){
			throw new InlineJavaException("Constructor for class " + name + " with signature " + ijs.CreateSignature(proto) + " not found: " + e.getMessage()) ;
		}
		catch (InstantiationException e){
			throw new InlineJavaException("You are not allowed to instantiate object of class " + name + ": " + e.getMessage()) ;
		}
		catch (IllegalAccessException e){
			throw new InlineJavaException("You are not allowed to instantiate object of class " + name + " using the constructor with signature " + ijs.CreateSignature(proto) + ": " + e.getMessage()) ;
		}
		catch (IllegalArgumentException e){
			throw new InlineJavaException("Arguments to constructor for class " + name + " with signature " + ijs.CreateSignature(proto) + " are incompatible: " + e.getMessage()) ;
		}
		catch (InvocationTargetException e){
			Throwable t = e.getTargetException() ;
			String type = t.getClass().getName() ;
			String msg = t.getMessage() ;
			throw new InlineJavaException(
				"Constructor for class " + name + " with signature " + ijs.CreateSignature(proto) + " threw exception " + type + ": " + msg) ;
		}

		return ret ;
	}


	/*
		Makes sure a method exists
	*/
	ArrayList ValidateMethod(boolean constructor, Class c, String name, StringTokenizer st) throws InlineJavaException {
		Member ma[] = (constructor ? (Member [])c.getConstructors() : (Member [])c.getMethods()) ;
		ArrayList ret = new ArrayList() ;

		// Extract signature
		String signature = st.nextToken() ;

		// Extract the arguments
		ArrayList args = new ArrayList() ;
		while (st.hasMoreTokens()){
			args.add(args.size(), st.nextToken()) ;
		}

		ArrayList ml = new ArrayList(ma.length) ;
		Class params[] = null ;
		for (int i = 0 ; i < ma.length ; i++){
			Member m = ma[i] ;

			if (m.getName().equals(name)){
				ijs.debug("found a " + name + (constructor ? " constructor" : " method")) ;

				if (constructor){
					params = ((Constructor)m).getParameterTypes() ;
				}
				else{
					params = ((Method)m).getParameterTypes() ;
				}

				// Now we check if the signatures match
				String sign = ijs.CreateSignature(params, ",") ;
				ijs.debug(sign + " = " + signature + "?") ;

				if (signature.equals(sign)){
					ijs.debug("  has matching signature " + sign) ;
					ml.add(ml.size(), m) ;
					break ;
				}
			}
		}

		// Now we got a list of matching methods. 
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
		Field fa[] = c.getFields() ;
		ArrayList ret = new ArrayList() ;

		// Extract member type
		String type = st.nextToken() ;

		// Extract the argument
		String arg = st.nextToken() ;

		ArrayList fl = new ArrayList(fa.length) ;
		Class param = null ;
		for (int i = 0 ; i < fa.length ; i++){
			Field f = fa[i] ;

			if (f.getName().equals(name)){
				ijs.debug("found a " + name + " member") ;

				param = f.getType() ;
				String t = param.getName() ;
				if (type.equals(t)){
					ijs.debug("  has matching type " + t) ;
					fl.add(fl.size(), f) ;
					break ;
				}
			}
		}

		// Now we got a list of matching methods. 
		// We have to figure out which one we will call.
		if (fl.size() == 0){
			throw new InlineJavaException(
				"Member " + name + " of type " + type + " for class " + c.getName() +
					" not found") ;
		}
		else if (fl.size() == 1){
			// Now we need to force the arguments received to match
			// the methods signature.
			Field f = (Field)fl.get(0) ;
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
	void SetResponse (Object o){
		if (o == null){
			response = "ok undef:" ;
		}
		else if ((ijc.ClassIsNumeric(o.getClass()))||(ijc.ClassIsChar(o.getClass()))||(ijc.ClassIsString(o.getClass()))){
			response = "ok scalar:" + unpack(o.toString()) ;
		}
		else if (ijc.ClassIsBool(o.getClass())){
			String b = o.toString() ;
			response = "ok scalar:" + unpack((b.equals("true") ? "1" : "0")) ;
		}
		else {
			// Here we need to register the object in order to send
			// it back to the Perl script.
			ijs.objects.put(new Integer(ijs.objid), o) ;
			response = "ok object:" + String.valueOf(ijs.objid) +
				":" + o.getClass().getName() ;
			ijs.objid++ ;
		}
	}


	/* Equivalent to Perl pack */
	public String pack(String s){
		StringTokenizer st = new StringTokenizer(s, ".") ;
		StringBuffer sb = new StringBuffer() ;
		while (st.hasMoreTokens()){
			String ss = st.nextToken() ; 
			byte b[] = {(byte)Integer.parseInt(ss)} ;
			sb.append(new String(b)) ;
		}
	
		return sb.toString() ;
	}


	/* Equivalent to Perl unpack */
	public String unpack(String s){
		byte b[] = s.getBytes() ;
		StringBuffer sb = new StringBuffer() ;
		for (int i = 0 ; i < b.length ; i++){
			if (i > 0){
				sb.append(".") ;
			}
			sb.append(String.valueOf(b[i])) ;
		}

		return sb.toString() ;
	}
}

