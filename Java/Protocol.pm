package Inline::Java::Protocol ;


use strict ;

$Inline::Java::Protocol::VERSION = '0.01' ;

use Carp ;


sub new {
	my $class = shift ;
	my $obj = shift ;
	my $inline = shift ;

	my $this = {} ;
	$this->{obj_priv} = $obj || {} ;
	$this->{module} = $inline->{modfname} ;

	bless($this, $class) ;
	return $this ;
}


# Called to create a Java object
sub CreateJavaObject {
	my $this = shift ;
	my $class = shift ;
	my @args = @_ ;

	Inline::Java::debug("creating object new $class(" . join(", ", @args) . ")") ; 	

	my $data = join(" ", 
		"create_object", 
		Inline::Java::Class::ValidateClass($class),
		$this->ValidateArgs(@args),
	) ;

	Inline::Java::debug("  packet sent is $data") ;		

	return $this->Send($data, 1) ;
}


# Called to call a static Java method
sub CallStaticJavaMethod {
	my $this = shift ;
	my $class = shift ;
	my $method = shift ;
	my @args = @_ ;

	Inline::Java::debug("calling $class.$method(" . join(", ", @args) . ")") ;

	my $data = join(" ", 
		"call_static_method", 
		Inline::Java::Class::ValidateClass($class),
		$this->ValidateMethod($method),
		$this->ValidateArgs(@args),
	) ;

	Inline::Java::debug("  packet sent is $data") ;		

	return $this->Send($data) ;
}


# Calls a regular Java method.
sub CallJavaMethod {
	my $this = shift ;
	my $method = shift ;
	my @args = @_ ;

	my $id = $this->{obj_priv}->{id} ;
	my $class = $this->{obj_priv}->{java_class} ;
	Inline::Java::debug("calling object($id).$method(" . join(", ", @args) . ")") ;

	my $data = join(" ", 
		"call_method", 
		$id,
		Inline::Java::Class::ValidateClass($class),
		$this->ValidateMethod($method),
		$this->ValidateArgs(@args),
	) ;

	Inline::Java::debug("  packet sent is $data") ;

	return $this->Send($data) ;
}


# Deletes a Java object
sub DeleteJavaObject {
	my $this = shift ;

	if (defined($this->{obj_priv}->{id})){
		my $id = $this->{obj_priv}->{id} ;
		my $class = $this->{obj_priv}->{java_class} ;

		Inline::Java::debug("deleting object $this $id ($class)") ;

		my $data = join(" ", 
			"delete_object", 
			$id,
		) ;

		Inline::Java::debug("  packet sent is $data") ;		

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


# Validates the arguments to be used in a method call.
sub ValidateArgs {
	my $this = shift ;
	my @args = @_ ;

	my @ret = () ;
	foreach my $arg (@args){
		if (! defined($arg)){
			push @ret, "undef:" ;
		}
		elsif (ref($arg)){
			if (! UNIVERSAL::isa($arg, "Inline::Java::Object")){
				croak "A Java method can only have Java objects or scalars as arguments" ;
			}
			my $class = $arg->{private}->{java_class} ;
			my $id = $arg->{private}->{id} ;
			push @ret, "object:$class:$id" ;
		}
		else{
			push @ret, "scalar:" . join(".", unpack("C*", $arg)) ;
		}
	}

	return @ret ;
}


# This actually sends the request to the Java program. It also takes
# care of registering the returned object (if any)
sub Send {
	my $this = shift ;
	my $data = shift ;
	my $const = shift ;

	my $inline = $Inline::Java::INLINE->{$this->{module}} ;
	my $sock = $inline->{Java}->{socket} ;
	print $sock $data . "\n" or
		croak "Can't send packet over socket: $!" ;

	my $resp = <$sock> ;
	Inline::Java::debug("  packet recv is $resp") ;

	if (! $resp){
		croak "Can't receive packet over socket: $!" ;
	}
	elsif ($resp =~ /^error scalar:([\d.]*)$/){
		croak pack("C*", split(/\./, $1)) ;
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
		}
		else{
			my $perl_class = $class ;
			$perl_class =~ s/[.\$]/::/g ;
			my $pkg = $inline->{pkg} ;
			$perl_class = $pkg . "::" . $perl_class ;
			Inline::Java::debug($perl_class) ;

			my $obj = undef ;
			no strict 'refs' ;
			if (defined(${$perl_class . "::" . "EXISTS"})){
				Inline::Java::debug("  returned class exists!") ;
				$obj = $perl_class->__new($class, $inline, $id) ;
			}
			else{
				Inline::Java::debug("  returned class doesn't exist!") ;
				$obj = Inline::Java::Object->__new($class, $inline, $id) ;
			}
			return $obj ;
		}
	}
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
	String cmd ;
	String response ;

	InlineJavaProtocol(InlineJavaServer _ijs, String _cmd) {
		ijs = _ijs ;
		ijc = new InlineJavaClass(ijs, this) ;

		cmd = _cmd ;		
	}


	/*
		Starts the analysis of the command line
	*/
	void Do() throws InlineJavaException {
		StringTokenizer st = new StringTokenizer(cmd, " ") ;
		String c = st.nextToken() ;

		if (c.equals("call_static_method")){
			CallStaticJavaMethod(st) ;
		}		
		else if (c.equals("call_method")){
			CallJavaMethod(st) ;
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
	}


	/*
		Calls a static Java method
	*/
	void CallStaticJavaMethod(StringTokenizer st) throws InlineJavaException {
		String class_name = st.nextToken() ;
		String method = st.nextToken() ;
		Class c = ijc.ValidateClass(class_name) ;
		ArrayList f = ValidateMethod(false, c, method, st) ;

		Method m = (Method)f.get(0) ;
		String name = m.getName() ;
		Object p[] = (Object [])f.get(1) ;
		try {
			Object ret = m.invoke(null, p) ;
			SetResponse(ret) ;
		}
		catch (IllegalAccessException e){
			throw new InlineJavaException("You are not allowed to invoke static method " + name + " in class " + class_name + ": " + e.getMessage()) ;
		}
		catch (IllegalArgumentException e){
			throw new InlineJavaException("Arguments for static method " + name + " in class " + class_name + " are incompatible: " + e.getMessage()) ;
		}
		catch (InvocationTargetException e){
			Throwable t = e.getTargetException() ;
			String type = t.getClass().getName() ;
			String msg = t.getMessage() ;
			throw new InlineJavaException(
				"Static method " + name + " in class " + class_name + " threw exception " + type + ": " + msg) ;
		}
	}


	/*
		Calls a regular Java method
	*/
	void CallJavaMethod(StringTokenizer st) throws InlineJavaException {
		int id = Integer.parseInt(st.nextToken()) ;
		String class_name = st.nextToken() ;
		String method = st.nextToken() ;
		Class c = ijc.ValidateClass(class_name) ;
		ArrayList f = ValidateMethod(false, c, method, st) ;

		Method m = (Method)f.get(0) ;
		String name = m.getName() ;
		Integer oid = new Integer(id) ;
		Object o = ijs.objects.get(oid) ;
		if (o == null){
			throw new InlineJavaException("Object " + oid.toString() + " is not in HashMap!") ;
		}
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


	/*
		Creates a Java Object with the specified arguments.
	*/
	void CreateJavaObject(StringTokenizer st) throws InlineJavaException {
		String class_name = st.nextToken() ;
		Class c = ijc.ValidateClass(class_name) ;

		ArrayList f = ValidateMethod(true, c, class_name, st) ;

		Constructor con = (Constructor)f.get(0) ;
		String name = class_name ;
		Object p[] = (Object [])f.get(1) ;
		Class clist[] = (Class [])f.get(2) ;

		Object o = CreateObject(c, p, clist) ;
		SetResponse(o) ;
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
			Constructor con = (Constructor)p.getConstructor(proto) ;
			ret = con.newInstance(args) ;
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
		ArrayList ret = new ArrayList(ma.length) ;

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
			 	if (params.length == args.size()){
					// We have the same number of arguments
					ml.add(ml.size(), m) ;
					ijs.debug("  has the correct number of params (" +  String.valueOf(args.size()) + ") and signature is " + ijs.CreateSignature(params)) ;
				}
			}
		}

		// Now we got a list of matching methods. 
		// We have to figure out which one we will call.
		if (ml.size() == 0){
			throw new InlineJavaException(
				(constructor ? "Constructor " : "Method ") + 
				name + " for class " + c.getName() + " with signature " +
				ijs.CreateSignature(params) + " not found") ;
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
		else{
			throw new InlineJavaException("Automatic method selection when multiple signatures are found not yet implemented") ;
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

