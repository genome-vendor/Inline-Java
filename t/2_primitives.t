use strict ;
use Test ;

use Inline Config => 
           DIRECTORY => './_Inline_test';

use Inline(
	Java => 'DATA'
) ;


BEGIN {
	plan(tests => 106) ;
}


my $t = new types() ;

my $max = undef ;
my $min = undef ;

$max = 127 ;
$min = -128 ;
ok($t->_byte(undef) == 1) ;
ok($t->_byte(0) == 1) ;
ok($t->_byte($max - 1) == $max) ;
ok($t->_byte("$min") == $min + 1) ;
eval {$t->_byte($max + 1)} ; ok($@, qr/out of range/) ;
eval {$t->_byte($min - 1)} ; ok($@, qr/out of range/) ;
ok($t->_Byte(undef) == 0) ;
ok($t->_Byte(0) == 0) ;
ok($t->_Byte($max) == $max) ;
ok($t->_Byte("$min") == $min) ;
eval {$t->_Byte($max + 1)} ; ok($@, qr/out of range/) ;
eval {$t->_Byte($min - 1)} ; ok($@, qr/out of range/) ;

$max = 32767 ;
$min = -32768 ;
ok($t->_short(undef) == 1) ;
ok($t->_short(0) == 1) ;
ok($t->_short($max - 1) == $max) ;
ok($t->_short("$min") == $min + 1) ;
eval {$t->_short($max + 1)} ; ok($@, qr/out of range/) ;
eval {$t->_short($min - 1)} ; ok($@, qr/out of range/) ;
ok($t->_Short(undef) == 0) ;
ok($t->_Short(0) == 0) ;
ok($t->_Short($max) == $max) ;
ok($t->_Short("$min") == $min) ;
eval {$t->_Short($max + 1)} ; ok($@, qr/out of range/) ;
eval {$t->_Short($min - 1)} ; ok($@, qr/out of range/) ;

$max = 2147483647 ;
$min = -2147483648 ;
ok($t->_int(undef) == 1) ;
ok($t->_int(0) == 1) ;
ok($t->_int($max - 1) == $max) ;
ok($t->_int("$min") == $min + 1) ;
eval {$t->_int($max + 1)} ; ok($@, qr/out of range/) ;
eval {$t->_int($min - 1)} ; ok($@, qr/out of range/) ;
ok($t->_Integer(undef) == 0) ;
ok($t->_Integer(0) == 0) ;
ok($t->_Integer($max) == $max) ;
ok($t->_Integer("$min") == $min) ;
eval {$t->_Integer($max + 1)} ; ok($@, qr/out of range/) ;
eval {$t->_Integer($min - 1)} ; ok($@, qr/out of range/) ;

$max = 2147483647 ;
$min = -2147483648 ;
ok($t->_long(undef) == 1) ;
ok($t->_long(0) == 1) ;
ok($t->_long($max - 1) == $max) ;
ok($t->_long("$min") == $min + 1) ;
eval {$t->_long($max + 1)} ; ok($@, qr/out of range/) ;
eval {$t->_long($min - 1)} ; ok($@, qr/out of range/) ;
ok($t->_Long(undef) == 0) ;
ok($t->_Long(0) == 0) ;
ok($t->_Long($max) == $max) ;
ok($t->_Long("$min") == $min) ;
eval {$t->_Long($max + 1)} ; ok($@, qr/out of range/) ;
eval {$t->_Long($min - 1)} ; ok($@, qr/out of range/) ;

$max = 3.4028235e38 ;
$min = -3.4028235e38 ;
ok($t->_float(undef) == 1) ;
ok($t->_float(0) == 1) ;
ok($t->_float($max - 1) == $max) ;
ok($t->_float("$min") == $min + 1) ;
eval {$t->_float($max + $max)} ; ok($@, qr/out of range/) ;
eval {$t->_float($min + $min)} ; ok($@, qr/out of range/) ;
ok($t->_Float(undef) == 0) ;
ok($t->_Float(0) == 0) ;
ok($t->_Float($max) == $max) ;
ok($t->_Float("$min") == $min) ;
eval {$t->_Float($max + $max)} ; ok($@, qr/out of range/) ;
eval {$t->_Float($min + $min)} ; ok($@, qr/out of range/) ;

$max = 3.4028235e38 ;
$min = -3.4028235e38 ;
ok($t->_double(undef) == 1) ;
ok($t->_double(0) == 1) ;
ok($t->_double($max - 1) == $max) ;
ok($t->_double("$min") == $min + 1) ;
eval {$t->_double($max + $max)} ; ok($@, qr/out of range/) ;
eval {$t->_double($min + $min)} ; ok($@, qr/out of range/) ;
ok($t->_Double(undef) == 0) ;
ok($t->_Double(0) == 0) ;
ok($t->_Double($max) == $max) ;
ok($t->_Double("$min") == $min) ;
eval {$t->_Double($max + $max)} ; ok($@, qr/out of range/) ;
eval {$t->_Double($min + $min)} ; ok($@, qr/out of range/) ;

# Number is forced to Double
$max = 3.4028235e38 ;
$min = -3.4028235e38 ;
ok($t->_Number(undef) == 0) ;
ok($t->_Number(0) == 0) ;
ok($t->_Number($max) == $max) ;
ok($t->_Number("$min") == $min) ;
eval {$t->_Number($max + $max)} ; ok($@, qr/out of range/) ;
eval {$t->_Number($min + $min)} ; ok($@, qr/out of range/) ;

ok(! $t->_boolean(undef)) ;
ok(! $t->_boolean(0)) ;
ok(! $t->_boolean("")) ;
ok($t->_boolean("true")) ;
ok($t->_boolean(1)) ;
ok(! $t->_Boolean(undef)) ; 
ok(! $t->_Boolean(0)) ; 
ok(! $t->_Boolean("")) ; 
ok($t->_Boolean("true")) ; 
ok($t->_Boolean(1)) ; 

ok($t->_char(undef), "\0") ;
ok($t->_char(0), "0") ;
ok($t->_char("1"), '1') ;
eval {$t->_char("10")} ; ok($@, qr/Can't convert/) ;
ok($t->_Character(undef), "\0") ;
ok($t->_Character(0), "0") ;
ok($t->_Character("1"), '1') ;
eval {$t->_Character("10")} ; ok($@, qr/Can't convert/) ;

ok($t->_String(undef), undef) ;
ok($t->_String(0), "0") ;
ok($t->_String("string"), 'string') ;
ok($t->_StringBuffer(undef), undef) ;
ok($t->_StringBuffer(0), "0") ;
ok($t->_StringBuffer("stringbuffer"), 'stringbuffer') ;

# Test if scalars can pass as java.lang.Object.
# They should be converted to strings.
ok($t->_Object(undef), undef) ;
ok($t->_Object(0), "0") ;
ok($t->_Object(666) == 666) ;
ok($t->_Object("object"), 'object') ;




__END__

__Java__

class types {
	public types(){
	}

	public byte _byte(byte b){
		return (byte)(b + (byte)1) ;
	}

	public Byte _Byte(Byte b){
		return b ;
	}

	public short _short(short s){
		return (short)(s + (short)1) ;
	}

	public Short _Short(Short s){
		return s ;
	}

	public int _int(int i){
		return i + 1 ;
	}

	public Integer _Integer(Integer i){
		return i ;
	}

	public long _long(long l){
		return l + 1 ;
	}

	public Long _Long(Long l){
		return l ;
	}

	public float _float(float f){
		return f + 1 ;
	}

	public Float _Float(Float f){
		return f ;
	}

	public double _double(double d){
		return d + 1 ;
	}

	public Double _Double(Double d){
		return d ;
	}

	public Number _Number(Number n){
		return n ;
	}

	public boolean _boolean(boolean b){
		return b ;
	}

	public Boolean _Boolean(Boolean b){
		return b ;
	}

	public char _char(char c){
		return c ;
	}

	public Character _Character(Character c){
		return c ;
	}

	public String _String(String s){
		return s ;
	}

	public StringBuffer _StringBuffer(StringBuffer sb){
		return sb ;
	}

	public Object _Object(Object o){
		return o ;
	}
}


