#include "mc.h"

expptr casecode1(expptr,expptr,expptr,expptr);
expptr casecode2(expptr,expptr,expptr);
expptr casecode3(expptr,expptr,expptr);

void match_failure(expptr value, expptr patterns){
  fprintf(stderr,"\n match error: the value \n\n");
  printexp(value);
  fprintf(stderr,"does not match any of\n\n");
  printexp(patterns);
  berror("");
}

expptr ucase_macro(expptr e){
  expptr ucase_pattern = `{{ucase{\$exp;\$rules}}};
  if(!(cellp(e)
       && constructor(cdr(e)) == '{'
       &&     cellp(paren_inside(cdr(e)))
       && cellp(car(paren_inside(cdr(e))))
       &&   cdr(car(paren_inside(cdr(e)))) == semi))
    match_failure(e,ucase_pattern);
  expptr exp = car(car(paren_inside(cdr(e))));
  expptr rules =   cdr(paren_inside(cdr(e)));

  expptr donelabel = gensym("done");
  expptr topvar = gensym("top");
  return `{{expptr $topvar = $exp;
      ${casecode1(rules, topvar, donelabel, nil)}
      ${donelabel}: ;}};
}

expptr casecode1(expptr rules, expptr topvar, expptr donelabel, expptr patterns){
  expptr rules_patterns = `{{{\$pattern}:{\$body}} {{\$pattern}:{\$body} \$rest}};
  if(!(cellp(rules)
       && cellp(car(rules))))
    match_failure(rules,rules_patterns);
  if(cdr(car(rules)) == colon){ //only first pattern possible
    return cons(casecode2(rules,topvar,donelabel),
		`{match_failure($topvar, ${quote_code(cons(car(rules), patterns))});});}
  //only second pattern possible
  return cons(casecode2(car(rules),topvar,donelabel),
	      casecode1(cdr(rules),topvar,donelabel,cons(car(car(rules)), patterns)));
}

expptr casecode2(expptr rule, expptr topvar, expptr donelabel){
  expptr rule_pattern = `{{\$pattern}:{\$body}};
  if(!(cellp(rule)
       && cellp(car(rule))
       && cdr(car(rule)) == colon
       && constructor(car(car(rule))) == '{'
       && constructor(cdr(rule)) == '{'))
    match_failure(rule, rule_pattern);
  expptr pattern = paren_inside(car(car(rule)));
  expptr body = paren_inside(cdr(rule));
  
  return casecode3(pattern, topvar, `{$body goto $donelabel;});
}

expptr casecode3(expptr pattern, expptr valvar , expptr body){

  if(atomp(pattern))return `{if($valvar == `{$pattern}){$body}};
  
  if(parenp(pattern)){
    expptr inside_var = gensym("");
    return `{if(parenp($valvar) && constructor($valvar) == ${constructor_code(constructor(pattern))}){
	expptr $inside_var = paren_inside($valvar);
	${casecode3(paren_inside(pattern), inside_var, body)}}};}
  
  if(car(pattern) == dollar){
    if(!(atomp(cdr(pattern)) && alphap(atom_string(cdr(pattern))[0])))
      berror("illegal syntax for variable in ucase pattern");
    return `{{expptr ${cdr(pattern)} = ${valvar}; ${body}}};}
    
  expptr leftvar = gensym("");
  expptr rightvar = gensym("");
  return `{if(cellp($valvar)){
      expptr ${leftvar} = car(${valvar});
      expptr ${rightvar} = cdr(${valvar});
      ${casecode3(car(pattern),leftvar,casecode3(cdr(pattern),rightvar,body))}}};
}

void mcB_init(){
  set_macro(`{ucase}, ucase_macro);
}
