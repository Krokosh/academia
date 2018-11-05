%{
#include <stdio.h>
#include <stdarg.h>
#include <stdlib.h>
#include <string.h>
#include "armgraph.h"

int count = 0;

char* mkdyad(op dyad, thing targ, thing src1, thing src2);
char* mkmonad(op monad, thing targ, thing src);
char* mkbranch(op branch, op label);
char* mklabel(op label);

nodeType *current;

%}

%union
{
  op erator;
  thing var;
  char* action;
};

%token <var> REG CONST
%token <erator> MONAD DYAD LABEL BRANCH
%right EOL ' '



%type <action> actn
%type <var> expr

%%

comm: comm EOL comm
    |
    | line
    | line line
    | error {yyerrok;printf("AARGH!  It's all broken!\n");}
    ;

line: actn {printf($1);}
    | LABEL {printf(mklabel($1));}
    ;

actn: DYAD REG REG expr{$$=mkdyad($1,$2,$3,$4);}
    | MONAD REG expr {$$=mkmonad($1,$2,$3);}
    | MONAD REG expr expr {$$=mkmonad($1,$2,$3);}
    | BRANCH LABEL {$$=mkbranch($1,$2);}
    ;

expr: REG
    | CONST
    ;

%%

char* mkdyad(op dyad, thing targ, thing src1, thing src2)
{

  char* dyop;
  int pos;
  if ((dyop = malloc(sizeof(char)*10)) == NULL)
        yyerror("out of memory");

  pos = sprintf(dyop, "%d", count++);

  if (dyad.cond != '*') {
    pos += sprintf(dyop + pos, "%c\n%d", dyad.cond, count++);

  }

  sprintf(dyop + pos, "%c%d=%c%d%c%c%d\n",
    targ.type, targ.value, src1.type, src1.value, dyad.oper, src2.type, src2.value);

  return(dyop);
}

char* mkmonad(op monad, thing targ, thing src)
{
  char* monop;
  int pos;
  if ((monop = malloc(sizeof(char)*8)) == NULL)
        yyerror("out of memory");

  pos = sprintf(monop, "%d", count++);

  if (monad.cond != '*')
    pos += sprintf(monop + pos, "%c\n%d", monad.cond, count++);

  sprintf(monop + pos, "%c%d%c%c%d\n",
    targ.type, targ.value, monad.oper, src.type, src.value);


  return(monop);
}

char* mkbranch(op branch, op label)
{
  char* brop;
  int pos;
  if ((brop = malloc(sizeof(char)*8)) == NULL)
        yyerror("out of memory");

  pos = sprintf(brop, "%d", count++);

  if (branch.cond != '*')
    pos += sprintf(brop + pos, "%c\n%d", branch.cond, count++);

  sprintf(brop + pos, "%c%s\n", branch.oper, label.name);

  return(brop);

}

char* mklabel(op label)
{
  char* lab;
  int pos;
  if ((lab = malloc(sizeof(char)*8)) == NULL)
        yyerror("out of memory");

  pos = sprintf(lab, "%d", count);
  if (lookuplabel(label.name)>=0)
  {
    yyerror("Label declared twice");
    return "INVALID!";
  }
  else
  {
    pos+=sprintf(lab + pos, "%s%d\n",label.name,addlabel(label.name, count++));
    return lab;
  }
}


int yyerror(s)
char *s;
{printf("%s\n",s);
  return 0;
}


int main()
{
  init();
  if ((current = malloc(sizeof(nodeType))) == NULL)
    yyerror("out of memory");
  #ifdef YYDEBUG
  yydebug=1;
  #endif
  return yyparse();
}




