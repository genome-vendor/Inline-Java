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
	plan(tests => 8) ;
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
ok($a->sa()->[1], 'titi') ;
ok($a->sb()->[0]->get('toto'), 'titi') ;
ok($a->sb()->[1]->get('error'), undef) ;


__DATA__

__Java__

import java.util.* ;

class a {
	public int i = 50 ;
	
	public a(){
	}

	public boolean truth(){
		return true ;
	}

	public String [] sa(){
		String a[] = {"toto", "titi"} ;
		return a ;
	}

	public HashMap [] sb(){
		HashMap h1 = new HashMap() ;
		HashMap h2 = new HashMap() ;
		h1.put("toto", "titi") ;
		h2.put("tata", "tete") ;

		HashMap a[] = {h1, h2} ;
		return a ;
	}
}

