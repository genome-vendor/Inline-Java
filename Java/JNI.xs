#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"


/* Include the JNI header file */
#include "jni.h"


/* JNI structure */
typedef struct {
	JNIEnv 	*env ;
	JavaVM 	*jvm ;
	jclass	ijs_class ;
	jobject	ijs ;
	jboolean debug ;
} InlineJavaJNIVM ;


void debug_ex(InlineJavaJNIVM *this){
	(*(this->env))->ExceptionDescribe(this->env) ; 	
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
	JavaVMOption options[2] ;
	jint res ;
	char * cp ;

    CODE:
	RETVAL = (InlineJavaJNIVM *)safemalloc(sizeof(InlineJavaJNIVM)) ;
	if (RETVAL == NULL){
		croak("Can't create InlineJavaJNIVM") ;
	}
	RETVAL->ijs = NULL ;
	RETVAL->debug = debug ;

	options[0].optionString = (RETVAL->debug ? "-verbose" : "-verbose:") ;
	cp = (char *)malloc((strlen(classpath) + 128) * sizeof(char)) ;
	sprintf(cp, "-Djava.class.path=%s", classpath) ;
	options[1].optionString = cp ;

	vm_args.version = JNI_VERSION_1_2 ;
	vm_args.options = options ;
	vm_args.nOptions = 2 ;
	vm_args.ignoreUnrecognized = JNI_FALSE ;

	/* Create the Java VM */
	res = JNI_CreateJavaVM(&(RETVAL->jvm), (void **)&(RETVAL->env), &vm_args) ;
	if (res < 0) {
		croak("Can't create Java interpreter using JNI") ;
	}

	free(cp) ;

    OUTPUT:
	RETVAL


void
DESTROY(this)
	InlineJavaJNIVM * this

	CODE:
	(*(this->jvm))->DestroyJavaVM(this->jvm) ;


void
create_ijs(this)
	InlineJavaJNIVM * this

	PREINIT:
	jmethodID mid ;

	CODE:
	this->ijs_class = (*(this->env))->FindClass(this->env, "InlineJavaServer") ;
	if (this->ijs_class == NULL){
		croak("Can't find class InlineJavaServer") ;
	}

	mid = (*(this->env))->GetStaticMethodID(this->env, this->ijs_class, "jni_main", "(Z)LInlineJavaServer;") ;
	if (mid == NULL) {
		croak("Can't find method jni_main in class InlineJavaServer") ;
	}

	this->ijs = (*(this->env))->CallStaticObjectMethod(this->env, this->ijs_class, mid, this->debug) ;
	if ((*(this->env))->ExceptionOccurred(this->env)){
		(*(this->env))->ExceptionDescribe(this->env) ;
		croak("Exception occured") ;
	}


char *
process_command(this, data)
	InlineJavaJNIVM * this
	char * data

	PREINIT:
	jmethodID mid ;
	jstring cmd ;
	jstring resp ;

	CODE:
	mid = (*(this->env))->GetMethodID(this->env, this->ijs_class, "ProcessCommand", "(Ljava/lang/String;)Ljava/lang/String;") ;
	if (mid == NULL) {
		croak("Can't find method ProcessCommand in class InlineJavaServer") ;
	}

	cmd = (*(this->env))->NewStringUTF(this->env, data) ;
	if (cmd == NULL){
		croak("Can't create java.lang.String") ;
	}

	resp = (*(this->env))->CallObjectMethod(this->env, this->ijs, mid, cmd) ;
	if ((*(this->env))->ExceptionOccurred(this->env)){
		(*(this->env))->ExceptionDescribe(this->env) ;
		croak("Exception occured") ;
	}
	RETVAL = (char *)((*(this->env))->GetStringUTFChars(this->env, resp, NULL)) ;
	
    OUTPUT:
	RETVAL

	CLEANUP:
	(*(this->env))->ReleaseStringUTFChars(this->env, resp, RETVAL) ;


void
report(this, module, classes, nb_classes)
	InlineJavaJNIVM * this
	char * module
	char * classes
	int nb_classes

	PREINIT:
	jmethodID mid ;
	jclass class ;
	jobject args ;
	jstring arg ;
	jstring resp ;
	char * cl ;
	char * ptr ;
	int idx ;

	CODE:
	mid = (*(this->env))->GetMethodID(this->env, this->ijs_class, "Report", "([Ljava/lang/String;I)V") ;
	if (mid == NULL) {
		croak("Can't find method Report in class InlineJavaServer") ;
	}

	class = (*(this->env))->FindClass(this->env, "java/lang/String") ;
	if (class == NULL){
		croak("Can't find class java.lang.String") ;
	}

	idx = 0 ;
	args = (*(this->env))->NewObjectArray(this->env, nb_classes + 1, class, NULL) ;
	if (args == NULL){
		croak("Can't create array of java.lang.String of length %i", nb_classes + 1) ;
	}

	arg = (*(this->env))->NewStringUTF(this->env, module) ;
	if (arg == NULL){
		croak("Can't create java.lang.String") ;
	}
	(*(this->env))->SetObjectArrayElement(this->env, args, idx++, arg) ;
	if ((*(this->env))->ExceptionOccurred(this->env)){
		(*(this->env))->ExceptionDescribe(this->env) ;
		croak("Exception occured") ;
	}

	cl = strdup(classes) ;
	ptr = strtok(cl, " ") ;

	idx = 1 ;
	while (ptr != NULL){
		arg = (*(this->env))->NewStringUTF(this->env, ptr) ;
		if (arg == NULL){
			croak("Can't create java.lang.String") ;
		}
		(*(this->env))->SetObjectArrayElement(this->env, args, idx, arg) ;
		if ((*(this->env))->ExceptionOccurred(this->env)){
			(*(this->env))->ExceptionDescribe(this->env) ;
			croak("Exception occured") ;
		}

		idx++ ;
		ptr = strtok(NULL, " ") ;
	}
	free(cl) ;	

	(*(this->env))->CallVoidMethod(this->env, this->ijs, mid, args, 0) ;
	if ((*(this->env))->ExceptionOccurred(this->env)){
		(*(this->env))->ExceptionDescribe(this->env) ;
		croak("Exception occured") ;
	}



