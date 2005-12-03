use strict ;
use Test ;

use Inline Config => 
           DIRECTORY => './_Inline_test' ;

use Inline (
	Java => 'DATA',
	NATIVE_DOUBLES => 2,
) ;


BEGIN {
	plan(tests => 2) ;
}


my $t = new t15() ;

{
	ok($t->_Double(0.056200000000000028) == 0.056200000000000028) ;
}

ok($t->__get_private()->{proto}->ObjectCount(), 1) ;




__END__

__Java__

class t15 {
	public t15(){
	}

	public Double _Double(Double d){
		return d ;
	}
}


