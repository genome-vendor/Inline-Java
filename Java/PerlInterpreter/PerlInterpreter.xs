#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"


/* Include the JNI header file */
#include "jni.h"

/* The PerlInterpreter handle */
PerlInterpreter *interp = NULL ;


/* XS initialisation stuff */
void boot_DynaLoader(pTHX_ CV* cv) ;


static void xs_init(pTHX){
    char *file = __FILE__ ;
    dXSUB_SYS ;
    newXS("DynaLoader::boot_DynaLoader", boot_DynaLoader, file) ;
}



void throw_ijp(JNIEnv *env, char *msg){
	jclass ije ;

	ije = (*(env))->FindClass(env, "org/perl/inline/java/InlineJavaPerlException") ;
	if ((*(env))->ExceptionCheck(env)){
		(*(env))->ExceptionDescribe(env) ;
		(*(env))->ExceptionClear(env) ;
		(*(env))->FatalError(env, "Can't find class InlineJavaPerlException: exiting...") ;
	}
	(*(env))->ThrowNew(env, ije, msg) ;
}


JNIEXPORT void JNICALL Java_org_perl_inline_java_InlineJavaPerlInterpreter_construct(JNIEnv *env, jclass cls){
	char *args[] = {"inline-java", "-e1"} ;

	interp = perl_alloc() ;
	perl_construct(interp) ;
	perl_parse(interp, xs_init, 2, args, NULL) ;
	perl_run(interp) ;
}


JNIEXPORT void JNICALL Java_org_perl_inline_java_InlineJavaPerlInterpreter_destruct(JNIEnv *env, jclass cls){
	if (interp != NULL){
		perl_destruct(interp) ;
		perl_free(interp) ;
		interp = NULL ;
	}
}


JNIEXPORT void JNICALL Java_org_perl_inline_java_InlineJavaPerlInterpreter_evalNoReturn(JNIEnv *env, jclass cls, jstring code){
	SV *sv = NULL ;
	char *pcode = NULL ;

	pcode = (char *)((*(env))->GetStringUTFChars(env, code, NULL)) ;
	sv = sv_2mortal(newSVpv(pcode, 0)) ;
	/* sv = eval_pv(pcode, FALSE) ; */
	eval_sv(sv, G_EVAL|G_KEEPERR) ;
	(*(env))->ReleaseStringUTFChars(env, code, pcode) ;
	if (SvTRUE(ERRSV)){
		STRLEN n_a ;
		throw_ijp(env, SvPV(ERRSV, n_a)) ;
	}
}



MODULE = Inline::Java::PerlInterpreter   PACKAGE = Inline::Java::PerlInterpreter

PROTOTYPES: DISABLE


