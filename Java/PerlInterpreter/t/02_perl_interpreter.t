use strict ;

use Test ;
use File::Spec ;

BEGIN {
    plan(tests => 7) ;
}


use Inline Config =>
           DIRECTORY => './_Inline_test' ;

use Inline (
	Java => 'DATA',
	NAME => 'Tests'
) ;
use Inline::Java::Portable ;
ok(1) ;


my $inline = $org::perl::inline::java::InlineJavaPerlInterpreterTests::INLINE ;
$inline = $org::perl::inline::java::InlineJavaPerlInterpreterTests::INLINE ; # stupid warning...

my $install_dir = File::Spec->catdir($inline->get_api('install_lib'),
        'auto', $inline->get_api('modpname')) ;

require Inline::Java->find_default_j2sdk() ;
my $server_jar = Inline::Java::Portable::get_server_jar() ;

run_java($install_dir, $server_jar) ;


#################################################


sub run_java {
	my @cps = @_ ;

	$ENV{CLASSPATH} = Inline::Java::Portable::make_classpath(@cps) ;
	Inline::Java::debug(1, "CLASSPATH is $ENV{CLASSPATH}\n") ;

	my $java = File::Spec->catfile(
		Inline::Java::get_default_j2sdk(),
		'bin', 'java' . Inline::Java::Portable::portable("EXE_EXTENSION")) ;

	my $debug = $ENV{PERL_INLINE_JAVA_DEBUG} || 0 ;
	my $cmd = Inline::Java::Portable::portable("SUB_FIX_CMD_QUOTES", "\"$java\" " . 
		"org.perl.inline.java.InlineJavaPerlInterpreterTests $debug") ;
	Inline::Java::debug(1, "Command is $cmd\n") ;
	print `$cmd` ;
}


__END__

__Java__
package org.perl.inline.java ;

class InlineJavaPerlInterpreterTests extends InlineJavaPerlInterpreter {
	private static int cnt = 2 ;
	private InlineJavaPerlInterpreterTests() throws InlineJavaException, InlineJavaPerlException {
	}

	private static void ok(Object o1, Object o2){
		if (o1.equals(o2)){
			String comment = " # " + o1 + " == " + o2 ;
			System.out.println("ok " + cnt + comment) ;
		}
		else {
			String comment = " # " + o1 + " != " + o2 ;
			System.out.println("nok " + cnt + comment) ;
		}
		cnt++ ;
	}

	public static void main(String args[]){
		try {
			int debug = 0 ;
			if (args.length > 0){
				debug = Integer.parseInt(args[0]) ;
				InlineJavaUtils.debug = debug ;
			}

			init("test") ;
			InlineJavaPerlInterpreter pi = InlineJavaPerlInterpreter.create() ; 

			pi.require("t/Tests.pl") ;
			ok("1", "1") ;
			pi.require("Carp") ;
			ok("1", "1") ;
			Integer sum = (Integer)pi.eval("34 + 56", Integer.class) ;
			ok(sum, new Integer(90)) ;
			String name = (String)pi.CallPerlSub("whats_your_name", null, String.class) ;
			ok(name, "perl") ;

			pi.destroy() ;
			ok("1", "1") ;
		}
		catch (Exception e){
			e.printStackTrace() ;
			System.exit(1) ;
		}
		ok("1", "1") ;
	}
}
