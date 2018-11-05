%{
#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include "armgraph.h"

int count = 0;

char* mkdyad(op dyad, thing targ, thing src1, thing src2);
char* mkmonad(op dyad, thing targ, thing src);

%}

%union
{
  thing data;
  op erator;
  char* action;
};

%token <data> REG CONST
%token <erator> MONAD DYAD LABEL
%token EOL

%type <action> actn
%type <data> expr

%%

line: line EOL
    |
    | line LABEL actn EOL {printf($3);}
    ;

actn: DYAD REG ',' REG ',' expr {$$=mkdyad($1,$2,$4,$6);}
    | MONAD REG ',' expr {$$=mkmonad($1,$2,$4);}
    ;


expr: REG
    | CONST
    ;

%%

char* mkdyad(op dyad, thing targ, thing src1, thing src2)
{

  char* dyop;
  char* value;
  if ((dyop = malloc(sizeof(char)*8)) == NULL)
        yyerror("out of memory");
  if ((value = malloc(sizeof(char)*3)) == NULL)
        yyerror("out of memory");
  sprintf(dyop,"%d",count++);

  if (dyad.cond!='*')
  {
    strcat(dyop, dyad.cond);
    strcat(dyop, '\n');
    sprintf(value,"%d",count++);
    strcat(dyop, value);
  }
  strcat(dyop, targ.type);
  sprintf(value,"%d", targ.value);
  strcat(dyop, value);
  strcat(dyop, '=');
  strcat(dyop, src1.type);
  sprintf(value,"%d", src1.value);
  strcat(dyop, value);
  strcat(dyop, dyad.oper);
  strcat(dyop, src2.type);
  sprintf(value,"%d", src2.value);
  strcat(dyop, value);
  return(dyop);
}

char* mkmonad(op monad, thing targ, thing src)
{
  char* monop;
  char* value;
  if ((monop = malloc(sizeof(char)*6)) == NULL)
        yyerror("out of memory");
  if ((value = malloc(sizeof(char)*3)) == NULL)
        yyerror("out of memory");

  sprintf(monop,"%d",count++);
  if (monad.cond!='*')
  {
    strcat(monop, monad.cond);
    strcat(monop, '\n');
    sprintf(value,"%d",count++);
    strcat(monop, value);
  }
  strcat(monop, targ.type);
  sprintf(value,"%d", targ.value);
  strcat(monop, value);
  strcat(monop, monad.oper);
  strcat(monop, src.type);
  sprintf(value,"%d", src.value);
  strcat(monop, value);
  return(monop);
}

int yyerror(s)
char *s;
{printf("%s\n",s);
  return 0;
}


int main()
{
  yydebug=1;
  return yyparse();
}




