package study ;

use strict ;
use Test ;


use Inline Config => 
           DIRECTORY => './_Inline_test';

use Inline(
	Java => 'DATA',
	AUTOSTUDY => 1,
	CLASSPATH => '.',
) ;
use Inline::Java qw(study_classes) ;



BEGIN {
	plan(tests => 5) ;
}


study_classes([
	't.types', 
	't.no_const'
]) ;

my $t = new study::t::types() ;
ok($t->func(), "study") ;
ok($t->hm()->get("key"), "value") ;

my $nc = new study::t::no_const() ;
ok($nc->{i}, 5) ;

my $a = new study::a() ;
ok($a->{i}, 50) ;
ok($a->truth()) ;


__DATA__

__Java__

class a {
	public int i = 50 ;
	
	public a(){
	}

	public boolean truth(){
		return true ;
	}
}

