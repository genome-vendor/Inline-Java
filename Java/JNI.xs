#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "stdarg.h"


/* Include the JNI header file */
#include "jni.h"


/* JNI structure */
typedef struct {
	JavaVM *jvm ;
	jclass ijs_class ;
	jclass string_class ;
	jobject	ijs ;
	jmethodID jni_main_mid ;
	jmethodID process_command_mid ;
	jint debug ;
	int embedded ;
	int destroyed ;
} InlineJavaJNIVM ;


void shutdown_JVM(InlineJavaJNIVM *this){
	if ((! this->embedded)&&(! this->destroyed)){
		(*(this->jvm))->DestroyJavaVM(this->jvm) ;
		this->destroyed = 1 ;
	}
}


JNIEnv *get_env(InlineJavaJNIVM *this){
	JNIEnv *env ;

	(*(this->jvm))->AttachCurrentThread(this->jvm, ((void **)&env), NULL) ;

	return env ;	
}


/*
	This is only used to trap exceptions from Perl.
*/
void check_exception_from_perl(JNIEnv *env, char *msg){
	if ((*(env))->ExceptionCheck(env)){
		(*(env))->ExceptionDescribe(env) ;
		(*(env))->ExceptionClear(env) ;
		croak(msg) ;
	}
}


void throw_ije(JNIEnv *env, char *msg){
	jclass ije ;

	ije = (*(env))->FindClass(env, "org/perl/inline/java/InlineJavaException") ;
	if ((*(env))->ExceptionCheck(env)){
		(*(env))->ExceptionDescribe(env) ;
		(*(env))->ExceptionClear(env) ;
		(*(env))->FatalError(env, "Can't find class InlineJavaException: exiting...") ;
	}
	(*(env))->ThrowNew(env, ije, msg) ;
}


jstring JNICALL jni_callback(JNIEnv *env, jobject obj, jstring cmd){
	dSP ;
	jstring resp ;
	char *c = (char *)((*(env))->GetStringUTFChars(env, cmd, NULL)) ;
	char *r = NULL ;
	int count = 0 ;
	SV *hook = NULL ;
	char msg[128] ;

	ENTER ;
	SAVETMPS ;

	PUSHMARK(SP) ;
	XPUSHs(&PL_sv_undef) ;
	XPUSHs(sv_2mortal(newSVpv(c, 0))) ;
	PUTBACK ;

	(*(env))->ReleaseStringUTFChars(env, cmd, c) ;
	count = perl_call_pv("Inline::Java::Callback::InterceptCallback", 
		G_ARRAY|G_EVAL) ;

	SPAGAIN ;

	/* Check the eval */
	if (SvTRUE(ERRSV)){
		STRLEN n_a ;
		throw_ije(env, SvPV(ERRSV, n_a)) ;
	}
	else{
		if (count != 2){
			sprintf(msg, "%s", "Invalid return value from Inline::Java::Callback::InterceptCallback: %d",
				count) ;
			throw_ije(env, msg) ;
		}
	}

	/* 
		The first thing to pop is a reference to the returned object,
		which we must keep around long enough so that it is not deleted
		before control gets back to Java. This is because this object
		may be returned be the callback, and when it gets back to Java
		it will already be deleted.
	*/
	hook = perl_get_sv("Inline::Java::Callback::OBJECT_HOOK", FALSE) ;
	sv_setsv(hook, POPs) ;

	r = (char *)POPp ;
	resp = (*(env))->NewStringUTF(env, r) ;

	PUTBACK ;
	FREETMPS ;
	LEAVE ;

	return resp ;
}



/*****************************************************************************/



MODULE = Inline::Java::JNI   PACKAGE = Inline::Java::JNI


PROTOTYPES: DISABLE


InlineJavaJNIVM *
new(CLASS, classpath, args, embedded, debug)
	char * CLASS
	char * classpath
	char * args
	int	embedded
	int	debug

	PREINIT:
	JavaVMInitArgs vm_args ;
	JavaVMOption options[8] ;
	JNIEnv *env ;
	JNINativeMethod nm ;
	jint res ;
	char *cp ;

    CODE:
	RETVAL = (InlineJavaJNIVM *)safemalloc(sizeof(InlineJavaJNIVM)) ;
	if (RETVAL == NULL){
		croak("Can't create InlineJavaJNIVM") ;
	}
	RETVAL->ijs = NULL ;
	RETVAL->embedded = embedded ;
	RETVAL->debug = debug ;
	RETVAL->destroyed = 0 ;

	vm_args.version = JNI_VERSION_1_2 ;
	vm_args.options = options ;
	vm_args.nOptions = 2 ;
	vm_args.ignoreUnrecognized = JNI_FALSE ;

	options[0].optionString = ((RETVAL->debug > 5) ? "-verbose" : "-verbose:") ;
	cp = (char *)malloc((strlen(classpath) + 128) * sizeof(char)) ;
	sprintf(cp, "-Djava.class.path=%s", classpath, args) ;
	options[1].optionString = cp ;
	if (strlen(args) > 0){
		options[2].optionString = args ;
		vm_args.nOptions++ ;
	}

	/* Embedded patch and idea by Doug MacEachern */
	if (RETVAL->embedded) {
		/* We are already inside a JVM */
		jint n = 0 ;

		res = JNI_GetCreatedJavaVMs(&(RETVAL->jvm), 1, &n) ;
		if (n <= 0) {
			/* res == 0 even if no JVMs are alive */
			res = -1;
		}
		if (res < 0) {
			croak("Can't find any created Java JVMs") ;
		}

		env = get_env(RETVAL) ;
	}
	else {
		/* Create the Java VM */
		res = JNI_CreateJavaVM(&(RETVAL->jvm), (void **)&(env), &vm_args) ;
		if (res < 0) {
			croak("Can't create Java JVM using JNI") ;
		}
	}

	free(cp) ;


	/* Load the classes that we will use */
	RETVAL->ijs_class = (*(env))->FindClass(env, "org/perl/inline/java/InlineJavaServer") ;
	check_exception_from_perl(env, "Can't find class InlineJavaServer") ;
	RETVAL->string_class = (*(env))->FindClass(env, "java/lang/String") ;
	check_exception_from_perl(env, "Can't find class java.lang.String") ;

	/* Get the method ids that are needed later */
	RETVAL->jni_main_mid = (*(env))->GetStaticMethodID(env, RETVAL->ijs_class, "jni_main",
		"(I)Lorg/perl/inline/java/InlineJavaServer;") ;
	check_exception_from_perl(env, "Can't find method jni_main in class InlineJavaServer") ;
	RETVAL->process_command_mid = (*(env))->GetMethodID(env, RETVAL->ijs_class, "ProcessCommand",
		"(Ljava/lang/String;)Ljava/lang/String;") ;
	check_exception_from_perl(env, "Can't find method ProcessCommand in class InlineJavaServer") ;

	/* Register the callback function */
	nm.name = "jni_callback" ;
	nm.signature = "(Ljava/lang/String;)Ljava/lang/String;" ;
	nm.fnPtr = jni_callback ;
	(*(env))->RegisterNatives(env, RETVAL->ijs_class, &nm, 1) ;
	check_exception_from_perl(env, "Can't register method jni_callback in class InlineJavaServer") ;

    OUTPUT:
	RETVAL



void
shutdown(this)
	InlineJavaJNIVM * this

	CODE:
	shutdown_JVM(this) ;



void
DESTROY(this)
	InlineJavaJNIVM * this

	CODE:
	shutdown_JVM(this) ;
	free(this) ;



void
create_ijs(this)
	InlineJavaJNIVM * this

	PREINIT:
	JNIEnv *env ;

	CODE:
	env = get_env(this) ;
	this->ijs = (*(env))->CallStaticObjectMethod(env, this->ijs_class, this->jni_main_mid, this->debug) ;
	check_exception_from_perl(env, "Can't call jni_main in class InlineJavaServer") ;



char *
process_command(this, data)
	InlineJavaJNIVM * this
	char * data

	PREINIT:
	JNIEnv *env ;
	jstring cmd ;
	jstring resp ;
	SV *hook = NULL ;

	CODE:
	env = get_env(this) ;
	cmd = (*(env))->NewStringUTF(env, data) ;
	check_exception_from_perl(env, "Can't create java.lang.String") ;

	resp = (*(env))->CallObjectMethod(env, this->ijs, this->process_command_mid, cmd) ;
	/* Thanks Dave Blob for spotting this. This is necessary since this codes never really returns to Java
	   It simply calls into Java and comes back. */
	(*(env))->DeleteLocalRef(env, cmd);
	check_exception_from_perl(env, "Can't call ProcessCommand in class InlineJavaServer") ;

	hook = perl_get_sv("Inline::Java::Callback::OBJECT_HOOK", FALSE) ;
	sv_setsv(hook, &PL_sv_undef) ;

	RETVAL = (char *)((*(env))->GetStringUTFChars(env, resp, NULL)) ;
	
    OUTPUT:
	RETVAL

	CLEANUP:
	(*(env))->ReleaseStringUTFChars(env, resp, RETVAL) ;
