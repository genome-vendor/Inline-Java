package Inline::Java::Object ;
@Inline::Java::Object::ISA = qw(Tie::StdHash) ;


use strict ;

$Inline::Java::Object::VERSION = '0.01' ;

use Carp ;
use Tie::Hash ;
use Inline::Java::Protocol ;



# Bogus constructor. We fall here if no public constructor is defined
# in the Java class.
sub new {
	my $class = shift ;
	
	croak "No public constructor defined for class $class" ;
}


# Constructor. Here we create a new object that will be linked
# to a real Java object.
sub __new {
	my $class = shift ;
	my $java_class = shift ;
	my $inline = shift ;
	my $objid = shift ;
	my @args = @_ ;

	my %this = () ;
	tie %this, 'Inline::Java::Object' ;
	bless (\%this, $class) ;

	my $this = \%this ;
	$this->{private} = {} ;
	$this->{private}->{class} = $class ;
	$this->{private}->{java_class} = $java_class ;
	$this->{private}->{module} = $inline->{modfname} ;
	$this->{private}->{proto} = new Inline::Java::Protocol($this->{private}, $inline) ;
	if ($objid <= 0){
		eval {
			$this->{private}->{proto}->CreateJavaObject($java_class, @args) ;
		} ;		
		croak "In method new of class $class: $@" if $@ ;

		Inline::Java::debug("Object created in perl script ($class):") ;
	}
	else{
		$this->{private}->{id} = $objid ;
		Inline::Java::debug("Object created in java ($class):") ;
	}
	Inline::Java::debug_obj($this) ;

	return $this ;
}


# Checks to make sure all the arguments can be "cast" to prototype
# types.
sub __validate_prototype {
	my $class = shift ;
	my $method = shift ;
	my $args = shift ;
	my $proto = shift ;

	my $new_args = undef ;
	eval {
		$new_args = Inline::Java::Class::CastArguments($args, $proto) ;
	} ;
	my $name = (ref($class) ? $class->{private}->{class} : $class) ;
	croak "In method $method of class $name: $@" if $@ ;

	return @{$new_args} ;
}


sub AUTOLOAD {
	my $this = shift ;
	my @args = @_ ;

	use vars qw($AUTOLOAD) ;
	my $func_name = $AUTOLOAD ;
	# Strip package from $func_name, Java will take of finding the correct
	# method.
	$func_name =~ s/^(.*)::// ;

	Inline::Java::debug("$func_name") ;

	croak "No public method $func_name defined for class $this->{private}->{class}" ;	
}


# Here an object in destroyed. this function seems to be called twice
# for each object. I think it's because the $this reference is both blessed
# and tied to the same package.
sub DESTROY {
	my $this = shift ;

	if (! $Inline::Java::DONE){
		if (! $this->{private}->{deleted}){
			$this->{private}->{deleted} = 1 ;
			eval {
				$this->{private}->{proto}->DeleteJavaObject() ;
			} ;
			croak "In method DESTROY of class $this->{private}->{class}: $@" if $@ ;
		}
		else{
			Inline::Java::debug("Object destructor called more than once!") ;
		}
	}
}


######################## Hash methods ########################


sub TIEHASH {
	my $class = shift ;

	return $class->SUPER::TIEHASH(@_) ;
}


sub STORE {
	my $this = shift ;
	my $key = shift ;
	my $value = shift ;

	if ($key eq "private"){
		return $this->SUPER::STORE($key, $value) ;
	}

	my $inline = $Inline::Java::INLINE->{$this->{private}->{module}} ;
	my $fields = $inline->get_fields($this->{private}->{java_class}) ;

	if ($fields->{$key}){
		croak "Setting of public member variables for Java objects is not yet implemented" ;		
	}
	else{
		croak "No public member variable $key defined for class $this->{private}->{class}" ;
	}
}


sub FETCH {
 	my $this = shift ;
 	my $key = shift ;

 	if ($key eq "private"){
 		return $this->SUPER::FETCH($key) ;
 	}

	my $inline = $Inline::Java::INLINE->{$this->{private}->{module}} ;
	my $fields = $inline->get_fields($this->{private}->{java_class}) ;

	if ($fields->{$key}){
		return undef ;
	}
	else{
		croak "No public member variable $key defined for class $this->{private}->{class}" ;
	}
}


sub FIRSTKEY { 
	my $this = shift ;

	return $this->SUPER::FIRSTKEY() ;
}


sub NEXTKEY { 
	my $this = shift ;

	return $this->SUPER::NEXTKEY() ;
}


sub EXISTS { 
 	my $this = shift ;
 	my $key = shift ;

	my $inline = $Inline::Java::INLINE->{$this->{private}->{module}} ;
	my $fields = $inline->get_fields($this->{private}->{java_class}) ;

	if ($fields->{$key}){
		return 1 ;
	}
	
	return 0 ;
}


sub DELETE { 
 	my $this = shift ;
 	my $key = shift ;

	croak "Operation DELETE not supported on Java object" ;
}


sub CLEAR { 
 	my $this = shift ;

	croak "Operation CLEAR not supported on Java object" ;
}



1 ;



__DATA__

