#include "premacros.h"

typedef char * charptr;
typedef void * voidptr;

typedef struct pliststruct{
  void * key;
  struct expstruct * data;
  struct pliststruct * rest;
}pliststruct,*plist;

typedef struct expstruct{
  plist data;
  char constructor;
  struct expstruct * arg1;
  struct expstruct * arg2;
}expstruct,*expptr;


/** ========================================================================
push_memory_frame, pop_memory_frame, and stack_alloc
========================================================================**/

void * stack_alloc(int size);
void push_memory_frame();
void pop_memory_frame();

/** ========================================================================
undo
======================================================================== **/

typedef struct undopair{
  void * * location;
  void * oldval;
}undopair;

#define UNDO_TRAIL_DIM  (1 << 16)
undopair undo_trail[UNDO_TRAIL_DIM];
int undo_trail_freeptr;

//in undo_set(p,v) it is important that sizeof(p) = sizeof(v) = 8 ----  8 bytes will be written at undo time.

#define undo_set(p, v) {if(undo_trail_freeptr >= UNDO_TRAIL_DIM)berror("undo trail exhausted"); undo_trail[undo_trail_freeptr].location = (void *) &(p);undo_trail[undo_trail_freeptr++].oldval = (void *) p;p=v;}

void * undo_alloc(int size);

void push_undo_frame();

void pop_undo_frame();

expptr exp_from_undo_frame(expptr exp);
expptr clean_undo_frame(expptr exp);
expptr stack_copy_memo_hits();
expptr intern_memo_hits ();



/** ========================================================================
cbreak, berror and macro_error

see berror and macro_error in mcA.mc
========================================================================**/

void cbreak();

void breakpt(char * s);

void berror(char *s);

/** ========================================================================
expressions
========================================================================**/

expptr string_atom(char * s);

int atomp(expptr e);

int symbolp(expptr e);

char * atom_string(expptr a);

expptr cons(expptr x, expptr y);

int cellp(expptr e);

expptr car(expptr x);

expptr cdr(expptr x);

expptr intern_paren(char openchar, expptr arg);

int parenp(expptr e);

expptr paren_inside(expptr e);

static inline char constructor(expptr e){
  if(e == NULL)berror("attempt to take the constructor of a null expression");
  return e-> constructor;}

expptr int_exp(int i);
int exp_int(expptr s);


/** ========================================================================
gensym
========================================================================**/

expptr gensym(char * s);

/** ========================================================================
properties
========================================================================**/

expptr getprop(expptr e, expptr key, expptr defaultval);
void setprop(expptr e, expptr key, void * val);
void addprop(expptr e, expptr key, expptr val);

int getprop_int(expptr e, expptr key, int defaultval);
void setprop_int(expptr e, expptr key, int x);


/** ========================================================================
expansion
========================================================================**/

void mcexpand(char * source, char * destination);
void mcexpand1(char * source, char * destination);

/** ========================================================================
io
========================================================================**/
FILE * fileout;
FILE * filein;

void open_input_file(char * s);
void open_output_file(char * s);

expptr read_from_repl();
expptr read_from_ide();
expptr read_from_file();

expptr file_expressions(char * fname);
void pprint(expptr e, FILE * f, int i);
void pp(expptr e);
char * exp_string(expptr);

/** ========================================================================
macros
========================================================================**/
void set_macro(expptr sym, expptr f(expptr));
expptr macroexpand(expptr e);
expptr macroexpand1(expptr e);

expptr preamble;
void add_preamble(expptr e);

expptr init_forms;
void add_init_form(expptr e);

expptr args_variables(expptr args);

void match_failure(expptr,expptr);

expptr top_atom(expptr e);

/** ========================================================================
utilities
========================================================================**/

int containsp(expptr e1, expptr e2);

void mapc(void f(expptr), expptr l);
expptr mapcar(expptr f(expptr), expptr l);
int length(expptr);
expptr append(expptr,expptr);
expptr reverse(expptr);

FILE * writestrm;

void indent(int i);

#define SYMBOL_DIM 10000

/** ========================================================================
initialization
========================================================================**/

void install(expptr);

void mcA_init();
void mcB_init();
void mcC_init();
void mcD_init();
void mcE_init1();
void mcE_init2();

int rep_column;


/** ========================================================================
expression_constants
======================================================================== **/

expptr period, comma, colon, semi, backquote, dollar, backslash, exclam, question, any, nil;
expptr nil, macro;

expptr bquote_code(expptr);
expptr quote_code(expptr);
expptr constructor_code(char);

void uerror(expptr);


/** ========================================================================
The following "source flags" are currently used in berror and, to a very minor extent, in printing.
======================================================================== **/

int in_doit;
int in_repl;
int in_expand;
int in_ide;

char *  ignore_tag;
char *  result_tag;
char *  reader_error_tag;
char *  expansion_error_tag;
char *  comp_error_tag;
char *  exec_error_tag;
char *  breakpoint_tag;
char *  request_input_tag;
char * print_tag;

void send_emacs_tag(char *);
void send_print_tag();
int in_ide_proc();
void return_to_NIDE();

void mcpprint(expptr);

char * MetaC_directory;

expptr intern_from_stack(expptr stack_exp);

expptr stack_copy_exp(expptr exp);
