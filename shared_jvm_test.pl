use strict ;

use blib ;


BEGIN {
	mkdir('./_Inline_test', 0777) unless -e './_Inline_test';
}


use Inline Config => 
           DIRECTORY => './_Inline_test' ;


use Inline(
	Java => 'DATA',
	SHARED_JVM => 1,
) ;


$t::i = 0 ;

my $nb = 10 ;
my $sum = (($nb) * ($nb + 1)) / 2 ;
for (my $i = 0 ; $i < $nb ; $i++){
	if (! fork()){
		print STDERR "." ;
		do_child($i) ;
	}
}


# Wait for kids to finish
for (my $i = 0 ; $i < 5 ; $i++){
	sleep(1) ;
	print STDERR "." ;
}
print STDERR "\n" ;

if ($t::i == $sum){
	print STDERR "Test succeeded\n" ;
}
else{
	print STDERR "Test failed\n" ;
}


sub do_child {
	my $i = shift ;

	Inline::Java::reconnect_JVM() ;

	my $t = new t() ;
	my $j = 0 ;
	for ( ; $j <= $i ; $j++){
		$t->incr_i() ;
	}
	exit ;
}


__END__

__Java__


import java.util.* ;

class t {
	static public int i = 0 ;

	public t(){
	}

	public void incr_i(){
		i++ ;
	}
}
