package Inline::Java::Array ;
@Inline::Java::Array::ISA = qw(Inline::Java::Array::Tie) ;


use strict ;

$Inline::Java::Array::VERSION = '0.31' ;

use Carp ;


# Here we store as keys the knots and as values our blessed objects
my $OBJECTS = {} ;


sub new {
	my $class = shift ;
	my $object = shift ;

	my @this = () ;
	my $knot = tie @this, $class ;
	my $this = bless (\@this, $class) ;

	$OBJECTS->{$knot} = $object ;

	Inline::Java::debug("this = '$this'") ; 
	Inline::Java::debug("knot = '$knot'") ; 

	return $this ;
}


sub __get_object {
	my $this = shift ;

	my $knot = tied @{$this} || $this ;

	my $ref = $OBJECTS->{$knot} ;
	if (! defined($ref)){
		croak "Unknown Java array reference '$knot'" ;
	}
	
	return $ref ;
}


sub __isa {
	my $this = shift ;
	my $proto = shift ;

	return $this->__get_object()->__isa($proto) ;
}


sub length {
	my $this = shift ;

	my $obj = $this->__get_object() ;

	my $ret = undef ;
	eval {
		# Check the cached value
		$ret = $obj->__get_private()->{array_length} ;
		if (! defined($ret)){
			$ret = $obj->__get_private()->{proto}->CallJavaMethod('getLength', [], []) ;
			$obj->__get_private()->{array_length} = $ret ;
		}
		else{
			Inline::Java::debug("Using cached array length $ret") ;
		}
	} ;
	croak $@ if $@ ;

	return $ret  ;
}


sub __get_element {
 	my $this = shift ;
 	my $idx = shift ;

	my $max = $this->length() - 1 ;
	if ($idx > $max){
		croak("Java array index out of bounds ($idx > $max)")
	}

	my $obj = $this->__get_object() ; 

	my $ret = undef ;
	eval {
		$ret = $obj->__get_private()->{proto}->GetJavaMember($idx, ['java.lang.Object'], [undef]) ;
	} ;
	croak $@ if $@ ;

	return $ret ;
}


sub __set_element {
 	my $this = shift ;
 	my $idx = shift ;
 	my $s = shift ;

	my $max = $this->length() - 1 ;
	if ($idx > $max){
		croak("Java array index out of bounds ($idx > $max)")
	}

	my $obj = $this->__get_object() ; 

	# Now we need to find out if what we are trying to set matches
	# the array.
	my $java_class = $obj->__get_private()->{java_class} ;
	my $elem_class = $java_class ;
	my $an = Inline::Java::Array::Normalizer->new($java_class) ;
	if ($an->{req_nb_dim} > 1){
		$elem_class =~ s/^\[// ;
	}
	else{
		$elem_class = $an->{req_element_class} ;
	}

	my $ret = undef ;
	eval {
		my ($new_args, $score) = Inline::Java::Class::CastArguments([$s], [$elem_class], $obj->__get_private()->{module}) ;
		$ret = $obj->__get_private()->{proto}->SetJavaMember($idx, [$elem_class], $new_args) ;
	} ;
	croak $@ if $@ ;

	return $ret ;
}


sub AUTOLOAD {
	my $this = shift ;
	my @args = @_ ;

	use vars qw($AUTOLOAD) ;
	my $func_name = $AUTOLOAD ;
	# Strip package from $func_name, Java will take of finding the correct
	# method.
	$func_name =~ s/^(.*)::// ;

	croak "Can't call method '$func_name' on Java arrays" ;
}


sub DESTROY {
	my $this = shift ;

	my $knot = tied @{$this} ;
	if (! $knot){
		Inline::Java::debug("Destroying Inline::Java::Array::Tie") ;

		$OBJECTS->{$this} = undef ;
	}
	else{
		# Here we can't untie because we still have a reference in $OBJECTS
		# untie @{$this} ;
		Inline::Java::debug("Destroying Inline::Java::Array") ;
	}
}




######################## Array methods ########################
package Inline::Java::Array::Tie ;
@Inline::Java::Array::Tie::ISA = qw(Tie::StdArray) ;


use Tie::Array ;
use Carp ;


sub TIEARRAY {
	my $class = shift ;

	return $class->SUPER::TIEARRAY(@_) ;
}


sub FETCHSIZE { 
 	my $this = shift ;

	my $array = $this->length() ;
}


sub STORE { 
 	my $this = shift ;
 	my $idx = shift ;
 	my $s = shift ;

	return $this->__set_element($idx, $s) ;
} 


sub FETCH { 
 	my $this = shift ;
 	my $idx = shift ;

	return $this->__get_element($idx) ;
}


sub EXISTS {
 	my $this = shift ;
 	my $idx = shift ;

	return $this->SUPER::EXISTS($idx) ;
}


sub STORESIZE {
 	my $this = shift ;
 	my $size = shift ;

	croak "Operation STORESIZE not supported on Java array" ;
}


sub CLEAR {
 	my $this = shift ;

	croak "Operation CLEAR not supported on Java array" ;
}


sub POP {
 	my $this = shift ;

	croak "Operation POP not supported on Java array" ;
}


sub PUSH {
 	my $this = shift ;
	my @list = @_ ;

	croak "Operation PUSH not supported on Java array" ;
}


sub SHIFT {
 	my $this = shift ;

	croak "Operation SHIFT not supported on Java array" ;
} 


sub UNSHIFT {
 	my $this = shift ;
	my @list = @_ ;

	croak "Operation UNSHIFT not supported on Java array" ;
} 


sub DELETE {
 	my $this = shift ;
	my $idx = shift ;

	croak "Operation DELETE not supported on Java array" ;
}


sub EXTEND {
 	my $this = shift ;
	my $count = shift ;

	croak "Operation EXTEND not supported on Java array" ;
}


sub SPLICE {
	my $this = shift ;
	my $offset = shift ;
	my $length = shift ;
	my @LIST = @_ ;

	croak "Operation SPLICE not supported on Java array" ;
}


sub DESTROY {
 	my $this = shift ;
}



######################## Inline::Java::Array::Normalizer ########################
package Inline::Java::Array::Normalizer ;


use Carp ;


sub new {
	my $class = shift ;
	my $java_class = shift ;
	my $ref = shift ;

	if (! Inline::Java::Class::ClassIsArray($java_class)){
		croak "Can't create Java array of non-array class '$java_class'" ;
	}

	my $this = {} ;
	$this->{class} = $class ;
	$this->{java_class} = $java_class ;
	$this->{map} = {} ;
	$this->{ref} = $ref ;
	$this->{array} = [] ;
	$this->{score} = 0 ;
	
	bless ($this, $class) ;

	# The first thing we want to do is figure out what kind of array we want,
	# and how many dimensions it should have.
	$this->AnalyzeArrayClass() ;

	if ($ref){
		$this->InitFromArray($this->{array}) ;
	}

	return $this ;
}


sub InitFromArray {
	my $this = shift ;
	my $array = shift ;
	my $level = shift ;

	my $ref = $this->{ref} ;

	$this->ValidateArray($ref, $array) ;

	if (! $level){
		Inline::Java::debug_obj($this) ;
	}
}


sub InitFromFlat {
	my $this = shift ;
	my $dims = shift ;
	my $list = shift ;
	my $level = shift ;

	my $nb_list = scalar(@{$list}) ;
	my $parts = $dims->[0] ;

	my $req_nb_elem = 1 ;
	foreach my $d (@{$dims}){
		$req_nb_elem *= $d ;
	}
	if ($req_nb_elem != $nb_list){
		my $ds = "[" . join("][", @{$dims}) . "]" ;
		croak "Corrupted array: $ds should contain $req_nb_elem elements, has $nb_list" ;
	}

	for (my $i = 0 ; $i < $parts ; $i++){
		my $elem = undef ;
		if (scalar(@{$dims}) == 1){
			# We are at the bottom of the list.
			$elem = $list->[$i] ;
		}
		else{
			my $nb_elems = $nb_list / $parts ;
			my @sub = splice(@{$list}, 0, $nb_elems) ;

			my $java_class = $this->{java_class} ;
			$java_class =~ s/^\[// ;

			my @dims = @{$dims} ;
			shift @dims ;
			my $obj = Inline::Java::Array::Normalizer->new($java_class) ;
			$obj->InitFromFlat(\@dims, \@sub, $level + 1) ;
			$elem = $obj->{array} ;
		}
		my $nb = scalar(@{$this->{array}}) ;
		$this->{array}->[$nb] = $elem ;
	}

	if (! $level){
		# Inline::Java::debug_obj($this) ;
	}
}


# Checks if the contents of the Array match the ones prescribed
# by the Java prototype.
sub AnalyzeArrayClass {
	my $this = shift ;
	
	my $java_class = $this->{java_class} ;

	my ($depth_str, $type, $class) = Inline::Java::Class::ValidateClassSplit($java_class) ;
	$depth_str =~ /^(\[+)/ ;
	my $depth = length($depth_str) ;

	my %map = (
		B => 'byte',
		S => 'short',
		I => 'int',
		J => 'long',
		F => 'float',
		D => 'double',
		C => 'char',
		Z => 'boolean',
		L => $class,
	) ;

	my $pclass = $map{$type} ;
	if (! $pclass){
		croak "Can't determine array type for '$java_class'" ;
	}

	$this->{req_element_class} = $pclass ;
	$this->{req_nb_dim} = $depth ;

	return ;
}


# This method makes sure that we have a valid array that
# can be used in a Java function. It will return an array
# That contains either all scalars or all object references
# at the lowest level.
sub ValidateArray {
	my $this = shift ;
	my $ref = shift ;
	my $array = shift ;
	my $level = shift || 0 ;

	if (! ((defined($ref))&&(UNIVERSAL::isa($ref, "ARRAY")))){
		# We must start with an array of some kind...
		croak "'$ref' is not an array reference" ;
	}

	$this->ValidateElements($ref, $array, $level) ;

	my $map = $this->{map} ;
	foreach my $elem (@{$ref}){
		if ((defined($elem))&&(UNIVERSAL::isa($elem, "ARRAY"))){
			# All the elements at this level are sub-arrays.
			my $sarray = [] ;
			$this->ValidateArray($elem, $sarray, $level + 1) ;
			push @{$array}, $sarray ;
		}
	}

	$this->FillArray($array, $level) ;

	if (! $level){
		my @levels = (sort {$a <=> $b} keys %{$map}) ;
		my $nbl = scalar(@levels) ;

		my $last = $levels[$nbl - 1] ;
		my @dims = () ;
		my $max_cells = 1 ;
		foreach my $l (@levels){
			push @dims, ($map->{$l}->{max} || 0) ;
			$max_cells *= $map->{$l}->{max} ;
		}
		my $nb_cells = ($map->{$last}->{count} || 0) ;
		Inline::Java::debug("array is [" . join("][", @dims) . "]") ;
		Inline::Java::debug("array has         $nb_cells declared cells") ;
		Inline::Java::debug("array should have $max_cells declared cells") ;
		$this->{dim} = \@dims ;
		$this->{nb_dim} = scalar(@dims) ;

		if ($this->{nb_dim} != $this->{req_nb_dim}){
			croak "Java array should have $this->{req_nb_dim} instead of " .
				"$this->{nb_dim} dimensions" ;
		}
		
		Inline::Java::debug_obj($this) ;
	}
}


# Makes sure that all the elements are of the same type.
sub ValidateElements {
	my $this = shift ;
	my $ref = shift ;
	my $array = shift ;
	my $level = shift ;

	my $map = $this->{map} ;

	my $cnt = scalar(@{$ref}) ;
	my $max = $map->{$level}->{max} || 0 ;

	if ($cnt > $max){
		$map->{$level}->{max} = $cnt ;
	}

	for (my $i = 0 ; $i < $cnt ; $i++){
		my $elem = $ref->[$i] ;
		if (defined($elem)){
			if (UNIVERSAL::isa($elem, "ARRAY")){
				$this->CheckMap("SUB_ARRAY", $level) ;
			}
			elsif (
				(UNIVERSAL::isa($elem, "Inline::Java::Object"))||
				(! ref($elem))){
				$this->CheckMap("BASE_ELEMENT", $level) ;
				my @ret = $this->CastArrayArgument($elem) ;
				$array->[$i] = $ret[0] ;
				$this->{score} += $ret[1] ;
			}
			else{
				croak "A Java array can only contain scalars, Java objects or array references" ;
			}
		}
		$map->{$level}->{count}++ ;
	}
}


sub CheckMap {
	my $this = shift ;
	my $type = shift ;
	my $level = shift ;

	my $map = $this->{map} ;

	if (! exists($map->{$level}->{type})){
		$map->{$level}->{type} = $type ;
	}
	elsif ($map->{$level}->{type} ne $type){
		croak "Java array contains mixed types in dimension $level ($type != $map->{$level}->{type})" ;
	}
}


sub CastArrayArgument {
	my $this = shift ;
	my $arg = shift ;

	my $element_class = $this->{req_element_class} ;

	my ($new_arg, $score) = Inline::Java::Class::CastArgument($arg, $element_class) ;

	return ($new_arg, $score) ;
}


# Makes sure that all the dimensions of the array have the same number of elements
sub FillArray {
	my $this = shift ;
	my $array = shift ;
	my $level = shift ;

	my $map = $this->{map} ;

	my $max = $map->{$level}->{max} ;
	my $nb = scalar(@{$array}) ;

	if ($map->{$level}->{type} eq "SUB_ARRAY"){
		foreach my $elem (@{$array}){
			if (! defined($elem)){
				$elem = [] ;
				$this->FillArray($elem, $level + 1) ;
			}
		}
	}

	if ($nb < $max){
		# We must stuff...
		for (my $i = $nb ; $i < $max ; $i++){
			if ($map->{$level}->{type} eq "SUB_ARRAY"){
				my $elem = [] ;
				$this->FillArray($elem, $level + 1) ;
				push @{$array}, $elem ;
			}
			else{
				push @{$array}, undef ;
			}			
		}
	}
}


sub FlattenArray {
	my $this = shift ;
	my $level = shift ;

	my $list = $this->MakeElementList($this->{array}) ;

	my $dim = $this->{dim} ;
	my $req_nb_elem = 1 ;
	foreach my $d (@{$dim}){
		$req_nb_elem *= $d ;
	}

	my $nb_elem = scalar(@{$list}) ;
	if ($req_nb_elem != $nb_elem){
		my $ds = "[" . join("][", @{$dim}) . "]" ;
		croak "Corrupted array: $ds should contain $req_nb_elem elements, has $nb_elem" ;
	}

	my $ret = [$dim, $list] ;

	Inline::Java::debug_obj($ret) ;

	return $ret ;
}


sub MakeElementList {
	my $this = shift ;
	my $array = shift ;

	my @ret = () ;
	foreach my $elem (@{$array}){
		if ((defined($elem))&&(UNIVERSAL::isa($elem, "ARRAY"))){
			my $sret = $this->MakeElementList($elem) ;
			push @ret, @{$sret} ;			
		}
		else{
			# All elements here are base level elements.
			push @ret, @{$array} ;
			last ;
		}
	}

	return \@ret ;
}



package Inline::Java::Array ;


1 ; 


__DATA__


class InlineJavaArray {
	private InlineJavaServer ijs ;
	private InlineJavaClass ijc ;


	InlineJavaArray(InlineJavaServer _ijs, InlineJavaClass _ijc){
		ijs = _ijs ;
		ijc = _ijc ;
	}


	Object CreateArray(Class c, StringTokenizer st) throws InlineJavaException {
		StringBuffer sb = new StringBuffer(st.nextToken()) ;
		sb.replace(0, 1, "") ;
		sb.replace(sb.length() - 1, sb.length(), "") ;

		StringTokenizer st2 = new StringTokenizer(sb.toString(), ",") ;
		ArrayList al = new ArrayList() ;
		while (st2.hasMoreTokens()){
			al.add(al.size(), st2.nextToken()) ;
		}

		int size = al.size() ;
		int dims[] = new int[size] ;
		for (int i = 0 ; i < size ; i++){
			dims[i] = Integer.parseInt((String)al.get(i)) ;
			ijs.debug("    array dimension: " + (String)al.get(i)) ;
		}

		Object array = null ;
		try {
			array = Array.newInstance(c, dims) ;

			ArrayList args = new ArrayList() ;
			while (st.hasMoreTokens()){
				args.add(args.size(), st.nextToken()) ;
			}

			// Now we need to fill it. Since we have an arbitrary number
			// of dimensions, we can do this recursively.

			PopulateArray(array, c, dims, args) ;
		}
		catch (IllegalArgumentException e){
			throw new InlineJavaException("Arguments to array constructor for class " + c.getName() + " are incompatible: " + e.getMessage()) ;
		}

		return array ;
	}


	void PopulateArray (Object array, Class elem, int dims[], ArrayList args) throws InlineJavaException {
		if (dims.length > 1){
			int nb_args = args.size() ;
			int nb_sub_dims = dims[0] ;
			int nb_args_per_sub_dim = nb_args / nb_sub_dims ;

			int sub_dims[] = new int[dims.length - 1] ;
			for (int i = 1 ; i < dims.length ; i++){
				sub_dims[i - 1] = dims[i] ;
			}
	
			for (int i = 0 ; i < nb_sub_dims ; i++){
				// We want the args from i*nb_args_per_sub_dim -> 
				ArrayList sub_args = new ArrayList() ; 
				for (int j = (i * nb_args_per_sub_dim) ; j < ((i + 1) * nb_args_per_sub_dim) ; j++){
					sub_args.add(sub_args.size(), (String)args.get(j)) ;
				}
				PopulateArray(((Object [])array)[i], elem, sub_dims, sub_args) ;
			}
		}
		else{
			String msg = "In creation of array of " + elem.getName() + ": " ;
			try {
				for (int i = 0 ; i < dims[0] ; i++){
					String arg = (String)args.get(i) ;

					Object o = ijc.CastArgument(elem, arg) ;
					Array.set(array, i, o) ;
					if (o != null){
						ijs.debug("      setting array element " + String.valueOf(i) + " to " + o.toString()) ;
					}
					else{
						ijs.debug("      setting array element " + String.valueOf(i) + " to " + o) ;
					}
		 		}
			}
			catch (InlineJavaCastException e){
				throw new InlineJavaCastException(msg + e.getMessage()) ;
			}
			catch (InlineJavaException e){
				throw new InlineJavaException(msg + e.getMessage()) ;
			}
		}
	}
}
	
	

