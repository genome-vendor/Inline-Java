#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"


/* Include the JNI header file */
#include "jni.h"


/* JNI structure */
typedef struct {
	JavaVM 	*jvm ;
	jclass	ijs_class ;
	jclass	string_class ;
	jobject	ijs ;
	jmethodID jni_main_mid ;
	jmethodID process_command_mid ;
	jint debug ;
	int destroyed ;
} InlineJavaJNIVM ;


void shutdown_JVM(InlineJavaJNIVM *this){
	if (! this->destroyed){
		(*(this->jvm))->DestroyJavaVM(this->jvm) ;
		this->destroyed = 1 ;
	}
}


JNIEnv *get_env(InlineJavaJNIVM *this){
	JNIEnv *env ;

	(*(this->jvm))->AttachCurrentThread(this->jvm, ((void **)&env), NULL) ;

	return env ;	
}


void check_exception(JNIEnv *env, char *msg){
	if ((*(env))->ExceptionCheck(env)){
		(*(env))->ExceptionDescribe(env) ;
		croak(msg) ;
	}
}


jstring JNICALL jni_callback(JNIEnv *env, jobject obj, jstring cmd){
	dSP ;
	jstring resp ;
	char *c = (char *)((*(env))->GetStringUTFChars(env, cmd, NULL)) ;
	char *r = NULL ;
	int count = 0 ;
	SV *hook = NULL ;

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

	/*
		Here is is important to understand that we cannot croak,
		because our caller is Java and not Perl. Croaking here
		screws up the Java stack royally and causes crashes.
	*/

	/* Check the eval */
	if (SvTRUE(ERRSV)){
		STRLEN n_a ;
		fprintf(stderr, "%s", SvPV(ERRSV, n_a)) ;
		exit(-1) ;
	}
	else{
		if (count != 2){
			fprintf(stderr, "%s", "Invalid return value from Inline::Java::Callback::InterceptCallback: %d",
				count) ;
			exit(-1) ;
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



MODULE = Inline::Java::JNI   PACKAGE = Inline::Java::JNI


PROTOTYPES: DISABLE


InlineJavaJNIVM * 
new(CLASS, classpath, debug)
	char * CLASS
	char * classpath
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
	RETVAL->debug = debug ;
	RETVAL->destroyed = 0 ;

	options[0].optionString = ((RETVAL->debug > 5) ? "-verbose" : "-verbose:") ;
	cp = (char *)malloc((strlen(classpath) + 128) * sizeof(char)) ;
	sprintf(cp, "-Djava.class.path=%s", classpath) ;
	options[1].optionString = cp ;

	vm_args.version = JNI_VERSION_1_2 ;
	vm_args.options = options ;
	vm_args.nOptions = 2 ;
	vm_args.ignoreUnrecognized = JNI_FALSE ;

	/* Create the Java VM */
	res = JNI_CreateJavaVM(&(RETVAL->jvm), (void **)&(env), &vm_args) ;
	if (res < 0) {
		croak("Can't create Java interpreter using JNI") ;
	}
	free(cp) ;


	/* Load the classes that we will use */
	RETVAL->ijs_class = (*(env))->FindClass(env, "InlineJavaServer") ;
	check_exception(env, "Can't find class InlineJavaServer") ;
	RETVAL->string_class = (*(env))->FindClass(env, "java/lang/String") ;
	check_exception(env, "Can't find class java.lang.String") ;
	
	/* Get the method ids that are needed later */
	RETVAL->jni_main_mid = (*(env))->GetStaticMethodID(env, RETVAL->ijs_class, "jni_main", "(I)LInlineJavaServer;") ;
	check_exception(env, "Can't find method jni_main in class InlineJavaServer") ;
	RETVAL->process_command_mid = (*(env))->GetMethodID(env, RETVAL->ijs_class, "ProcessCommand", "(Ljava/lang/String;)Ljava/lang/String;") ;
	check_exception(env, "Can't find method ProcessCommand in class InlineJavaServer") ;

	/* Register the callback function */
	nm.name = "jni_callback" ;
	nm.signature = "(Ljava/lang/String;)Ljava/lang/String;" ;
	nm.fnPtr = jni_callback ;
	(*(env))->RegisterNatives(env, RETVAL->ijs_class, &nm, 1) ;	
	check_exception(env, "Can't register method jni_callback in class InlineJavaServer") ;
	
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
	check_exception(env, "Can't call jni_main in class InlineJavaServer") ;



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
	check_exception(env, "Can't create java.lang.String") ;

	resp = (*(env))->CallObjectMethod(env, this->ijs, this->process_command_mid, cmd) ;
	check_exception(env, "Can't call ProcessCommand in InlineJavaServer") ;

	hook = perl_get_sv("Inline::Java::Callback::OBJECT_HOOK", FALSE) ;
	sv_setsv(hook, &PL_sv_undef) ;

	RETVAL = (char *)((*(env))->GetStringUTFChars(env, resp, NULL)) ;
	
    OUTPUT:
	RETVAL

	CLEANUP:
	(*(env))->ReleaseStringUTFChars(env, resp, RETVAL) ;
