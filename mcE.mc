#include "mc.h"

/** ========================================================================
In this implementation all global data variables must be arrays.
We can replace a declaration

    <type>  x;

by

   <type> x[1];

and replace x by x[0] throughout the code.

An array variable x can be dynamically linked into the DLL code in such a way that assignments
to x[i] in the DLL code do the right thing.  This is not true of assignments
to x as opposed to assignments to x[i]. To support assignment to x (as opposed to x[i])
we need to be able to identify the FREE occurances of x in the code. This implementation
does not support that level of analysis of the C code.

MetaC is designed to create new languages.  The implementation of a new language will support
better code analysis of the new langauge.
======================================================================== **/

expptr file_preamble;
expptr procedures;
expptr arrays;

expptr new_procedures;
expptr new_arrays;
expptr new_statements;

int compilecount;
int symbol_count;

expptr args_variables(expptr args);
void install(expptr sig);
voidptr compile_load_file(charptr fstring);
void install_preamble(expptr);
void install_var(expptr,expptr,expptr);
void install_proc(expptr,expptr,expptr,expptr);
int symbol_index(expptr);
expptr symbol_index_exp(expptr);
void unrecognized_statement(expptr form);
expptr proc_def(expptr f);
expptr link_def(expptr f);
void install_base();
expptr procedure_insertion (expptr f, expptr g);

/** ========================================================================
The REPL inserts base procedures into the symbol_value table (the linking table) by calling the macro insert_base.
This macro is expanded by ExpandE on REPL.  Before doing any expansion, ExpandE sets the symbol indeces of the base symbols by calling install_base().
install_base must be run again by the REPL so that indeces used by the REPL match those used
by expandE (the indeces used at REPL load time must be syncronized with those used at REPL compile time).
mcE_init1 establishes base procedure indeces so that all executables built on mcE have the same base procedure indeces.

Becasue of REPL compile and load syncronization, install_base cannot be cleanly replaced with calls to install.
======================================================================== **/

void mcE_init1(){
  file_preamble = nil;
  arrays = nil;
  procedures = nil;
  symbol_count = 0;
  install_base();  //all executables built on mcE (ExpandE, REPL and IDE) have the same indeces for base functions.
  compilecount = 0;
}

void install_base(){
  dolist(sig,file_expressions("base_decls.h")){
    ucase{sig;
      {$type $f($args);}.(symbolp(type) && symbolp(f)):{
	symbol_index(f);  //establish the index
        setprop(f,`{base},`{true});
        install(sig);}
      {$type $x[$dim];}:{
	symbol_index(x);  //establish the index
	push(x,arrays);
	setprop(x,`{signature},sig);}
      {$e}:{push(e,file_preamble);}}}
}

umacro{insert_base()}{
  expptr result = nil;
  dolist(f,procedures){
    push(procedure_insertion(f,f), result);}
  dolist(X,arrays){
    push(`{symbol_value[${symbol_index_exp(X)}] = $X;}, result);}
  return result;
}

init_fun(mcE_init2)  //mcE_init2 defines the macro insert_base (without calling it).


/** ========================================================================
insertion and extraction from the linking table.  Procedure extraction is
done by defing the procedure in the DLL to go through the linking table.
======================================================================== **/

expptr procedure_insertion (expptr f, expptr g){
  return `{
    symbol_value[${symbol_index_exp(f)}] = $g;};
}

expptr new_procedure_insertion (expptr f){
  return procedure_insertion(f, getprop(f,`{gensym_name},NULL));
}

expptr new_array_insertion (expptr x){
  ucase{getprop(x,`{signature},nil);
    {$type $x[$dim];}:{return `{symbol_value[${symbol_index_exp(x)}] = malloc($dim*sizeof($type));};}}
  return nil; //avoids compiler warning
}

expptr array_extraction (expptr x){
  return `{$x = symbol_value[${symbol_index_exp(x)}];};
}

/** ========================================================================
The load function is given a list of fully macro-expanded expressions.
======================================================================== **/

expptr load(expptr forms){ // forms must be fully macro expanded.

  compilecount ++; //should not be inside sformat --- sformat duplicates.
  char * s = sformat("/tmp/TEMP%d.c",compilecount);
  fileout = fopen(s, "w");

  new_procedures = nil;
  new_arrays = nil;
  new_statements = nil;
  
  mapc(install,forms);
  dolist(form,reverse(file_preamble)){pprint(form,fileout,rep_column);}
  fputc('\n',fileout);
  pprint(`{void * * symbol_value_copy;},fileout,0);

  //variable declarations
  dolist(f,procedures){pprint(getprop(f,`{signature},NULL),fileout,0);}
  dolist(x,arrays){
    ucase{getprop(x,`{signature},NULL);
      {$type $x[$dim];}:{pprint(`{$type * $x;},fileout,0);}}}

  //procedure value extractions.  array extractions are done in doit.

  dolist(f,procedures){
    pprint(link_def(f),fileout,0);}
  dolist(f,new_procedures){
    pprint(proc_def(f),fileout,0);} 

  pprint(`{
      expptr _mc_doit(voidptr * symbol_value){
	symbol_value_copy = symbol_value;
	${mapcar(new_procedure_insertion, new_procedures)}
	${mapcar(new_array_insertion, new_arrays)}
	${mapcar(array_extraction, arrays)} // procedure extractions are done by linkdefs and procdefs above
	${reverse(new_statements)}
	return string_atom("done");}},
    fileout,0);
  fclose(fileout);
  
  void * header = compile_load_file(sformat("/tmp/TEMP%d",compilecount));

  if(in_ide){send_emacs_tag(ignore_tag);}
   expptr (* _mc_doit)(voidptr *);
  _mc_doit = dlsym(header,"_mc_doit");

  in_doit = 1;
  return (*_mc_doit)(symbol_value);
}

int whitespace(char *s){
  for(int i=0; s[i]; i++){if (!whitep(s[i])) return 0;}
  return 1;
}

void install(expptr statement){ //only the following patterns are allowed.
  ucase{statement;
    {typedef $def;}:{install_preamble(statement);}
    {typedef $def1,$def2;}:{install_preamble(statement);}
    {#define $def}:{install_preamble(statement);}
    {#include <$file>}:{install_preamble(statement);}
    {#include $x}:{install_preamble(statement);}
    {return $e;}:{push(statement,new_statements);}
    {$type $X[0];}.(symbolp(type) && symbolp(X)):{install_var(type,X,`{1});}
    {$type $X[0] = $e;}.(symbolp(type) && symbolp(X)):{install_var(type,X,`{1}); push(`{$X[0] = $e;},new_statements);}
    {$type $X[$dim];}.(symbolp(type) && symbolp(X)):{install_var(type,X,dim);}
    {$type $f($args){$body}}.(symbolp(type) && symbolp(f)):{install_proc(type, f, args, body);}
    {$type $f($args);}.(symbolp(type) && symbolp(f)):{install_proc(type, f, args, NULL);}
    {$e;}:{push(statement,new_statements)}
    {{$e}}:{push(statement,new_statements)}
    {$e}:{push(`{return $e;},new_statements)}}
}

void install_preamble(expptr e){
  if(!getprop(e,`{installed},NULL)){
    push(e,file_preamble);
    setprop(e,`{installed},`{true});}
}

void install_var(expptr type, expptr X, expptr dim){
  expptr oldsig = getprop(X,`{signature}, NULL);
  expptr newsig = `{$type $X[$dim];};
  if(oldsig != NULL && newsig != oldsig)uerror(`{attempt to change the type declaration, $oldsig , to $newsig});
  if(oldsig == NULL){
    setprop(X,`{signature},newsig);
    push(X, arrays);
    push(X,new_arrays);}
}

void install_proc(expptr type, expptr f, expptr args, expptr newbody){
  expptr oldsig = getprop(f,`{signature}, NULL);
  expptr oldbody = getprop(f,`{body},NULL);
  expptr newsig = `{$type $f($args);};
  if(oldsig != NULL && newsig != oldsig)uerror(`{attempt to change $oldsig to \n $newsig});
  if(oldsig == NULL){
    setprop(f,`{signature},newsig);
    push(f,procedures);}

  if(oldbody != newbody && newbody){
    push(f, new_procedures);
    if (getprop(f,`{base},NULL)) uerror(`{attempt to change base function $f});
    setprop(f,`{gensym_name},gensym(atom_string(f)));
    setprop(f,`{body},newbody);
    symbol_value[symbol_index(f)] = NULL; //this will catch semi-defined functions without segmentation fault.
  }
}

void unrecognized_statement(expptr form){
  uerror( `{unrecognized statement,
	$form ,
	types must be single symbols,
	all global variables must be arrays,
    });
}

int symbol_index(expptr sym){
  int index = (int) getprop_int(sym, `{index}, -1);
  if(index == -1){
    if(symbol_count == SYMBOL_DIM){berror("Mc symbol table exhausted");}
    index = symbol_count++;
    setprop_int(sym,`{index}, index);
  }
  return index;
}

expptr symbol_index_exp(expptr sym){
  return int_exp(symbol_index(sym));
}

expptr link_def(expptr f){
  ucase{getprop(f,`{signature},NULL);
    {$type $f($args);}:{
      return
	`{$type $f($args){
	  $type (* _mc_f)($args);
	  _mc_f = symbol_value_copy[${symbol_index_exp(f)}];

	  if(!_mc_f){berror("call to undefined procedure");}
	  
	  ${(type == `{void} ?
	     `{(* _mc_f)(${args_variables(args)});}
	     : `{return (* _mc_f)(${args_variables(args)});})}}};}
    {$e}:{return NULL;}}
  return NULL;
}

expptr proc_def(expptr f){
  ucase{getprop(f,`{signature},NULL);
    {$type $f($args);}:{
      return `{$type ${getprop(f,`{gensym_name},NULL)}($args){${getprop(f,`{body},NULL)}}};}
    {$e}:{return NULL;}}
}

void comp_error(){
  fflush(stderr);
  if(in_ide){
    dolist(f,new_procedures){
      setprop(f,`{body},NULL);}
    fprintf(stdout,"%s",comp_error_tag);}
  else{
    fprintf(stdout,"\n evaluation aborted\n\n");}
  throw_error();}

voidptr compile_load_file(charptr fstring){
  int flg;
  
  char * s1 = sformat("cc -g -fPIC -Wall -c -Werror %s.c -o %s.o",fstring,fstring);
  flg = system(s1);
  if(flg != 0)comp_error();

  char * s2 = sformat("cc -g -fPIC -shared -lm -Werror %s.o -o %s.so",fstring,fstring);
  flg = system(s2);
  if(flg != 0)comp_error();

  char * s3 = sformat("%s.so",fstring);
  voidptr header = dlopen(s3, RTLD_LAZY|RTLD_GLOBAL);
  if(header == NULL){
    fprintf(stdout,"\nunable to open shared library %s with error %s\n", s3, dlerror());
    comp_error();}
  return header;
}
