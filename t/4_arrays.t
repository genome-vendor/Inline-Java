use strict ;
use Test ;

use Inline Config => 
           DIRECTORY => './_Inline_test';

use Inline(
	Java => 'DATA'
) ;


BEGIN {
	plan(tests => 2) ;
}


my $a = new array_test() ;
my $data = $a->get_data() ;
ok($a->do_data($data), 'data') ;
my $sdata = $a->get_sdata() ;
ok($a->do_sdata($sdata), 'sdata') ;


__END__

__Java__

class array_test {
	public String data[] = {"d", "a", "t", "a"} ;
	public static String sdata[][] = {{"s"}, {"d"}, {"a"}, {"t"}, {"a"}} ;

	public array_test(){
	}

	public String [] get_data(){
		return data ;
	}

	public StringBuffer do_data(String d[]){
		StringBuffer sb = new StringBuffer() ;
		for (int i = 0 ; i < d.length ; i++){
			sb.append(d[i]) ;
		}

		return sb ;
	}

	public static String [][] get_sdata(){
		return sdata ;
	}

	public StringBuffer do_sdata(String d[][]){
		StringBuffer sb = new StringBuffer() ;
		for (int i = 0 ; i < d.length ; i++){
			sb.append(d[i][0]) ;
		}

		return sb ;
	}
}
