use strict ;
use Test ;

use Inline Config => 
           DIRECTORY => './_Inline_test';

use Inline(
	Java => 'DATA'
) ;


BEGIN {
	plan(tests => 21) ;
}


my $t = new types() ;
ok($t->_byte("123"),124) ;
ok($t->_Byte("123"), 123) ;
ok($t->_short("123"), 124) ;
ok($t->_Short("123"), 123) ;
ok($t->_int("123"), 124) ;
ok($t->_Integer("123"), 123) ;
ok($t->_long("123"), 124) ;
ok($t->_Long("123"), 123) ;
ok($t->_float("123.456"), 124.456) ;
ok($t->_Float("123.456"), 123.456) ;
ok($t->_double("123.456"), 124.456) ;
ok($t->_Double("123.456"), 123.456) ;

ok($t->_boolean("true"), 1) ;
ok($t->_Boolean("true"), 1) ; 
ok($t->_boolean(""), 0) ;
ok($t->_Boolean("0"), 0) ; 
ok($t->_char("1"), '1') ;
ok($t->_Character("1"), '1') ;

ok($t->_String("string"), 'string') ;
ok($t->_StringBuffer("string_buffer"), 'string_buffer') ;

# Test if scalars can pass as java.lang.Object (they should).
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


