use strict ;
use Test ;

use Inline Config => 
           DIRECTORY => './_Inline_test';

use Inline(
	Java => 'DATA'
) ;


BEGIN {
	plan(tests => 15) ;
}


my $o1 = new obj_test() ;
my $o2 = new obj_test() ;
ok($o1->get_data(), "data") ;
ok($o2->get_data(), "data") ;
ok($o1->get_this()->get_data(), "data") ;
ok($o1->get_that($o2)->get_data(), "data") ;

$o1->set_data("new data") ;
ok($o1->get_data(), "new data") ;
ok($o2->get_data(), "new data") ;

obj_test->set_data("new new data") ;
ok($o1->get_data(), "new new data") ;
ok($o2->get_data(), "new new data") ;

my $so1 = new sub_obj_test(5) ;
my $so2 = new sub_obj_test(6) ;
ok($so1->get_data(), "new new data") ;
ok($so1->get_number(), 5) ;
ok($so2->get_number(), 6) ;

$so1->set_number(7) ;
ok($so1->get_number(), 7) ;

my $io = new obj_test::inner_obj_test($o1) ;
ok($io->get_data(), "new new data") ;

my $al = $o1->new_arraylist() ;
$o1->set_arraylist($al, "array data") ;
ok($o1->get_arraylist($al), "array data") ;


my $so3 = new sub_obj_test(100) ;
my $ow = new obj_wrap($so3) ;
my $do = new obj_do($ow) ;
$do->get_obj()->set_obj($so2) ;
ok($do->get_obj_data()->get_number(), 6) ;

__END__

__Java__

import java.util.* ;


class obj_test {
	public static String data = "data" ;

	public obj_test(){
	}

	public obj_test get_this(){
		return this ;
	}

	public obj_test get_that(obj_test o){
		return o ;
	}

	public static String get_data(){
		return data ;
	}

	public static void set_data(String d){
		data = d ;
	}
	
	public ArrayList new_arraylist(){
		return new ArrayList() ;
	}

	public void set_arraylist(ArrayList a, String s){
		a.add(0, s) ;
	}

	public String get_arraylist(ArrayList a){
		return (String)a.get(0) ;
	}

	
	class inner_obj_test {
		public inner_obj_test(){
		}

		public String get_data(){
			return obj_test.this.get_data() ;
		}
	}
}


class sub_obj_test extends obj_test {
	public int number ;

	public sub_obj_test(int num){
		super() ;
		number = num ;
	}

	public int get_number(){
		return number ;
	}

	public void set_number(int num){
		number = num ;
	}
}


/* Has an object as a member variable */
class obj_wrap {
	public sub_obj_test obj ;

	public obj_wrap(sub_obj_test o){
		obj = o ;
	}

	public void set_obj(sub_obj_test o){
		obj = o ;
	}
}


class obj_do {
	public obj_wrap obj ;

	public obj_do(obj_wrap o){
		obj = o ;
	}

	public obj_wrap get_obj(){
		return obj ;
	}
	public sub_obj_test get_obj_data(){
		return obj.obj ;
	}
}
