%{
    #include <stdlib.h>
    #include <ctype.h>
    #include "armgraph.h"
    #include "armgraph.tab.h"
%}
%%


"eof" return EOF; /* Useful when using the parser as an interpreter */

"_"*[rR][0-9]+ {
  yylval.var.unas.type='r';
  yylval.var.unas.value=atoi(yytext+strlen(yytext)-1);
  return REG;}

"_"*"a"[1-4] {
  yylval.var.unas.type='r';
  yylval.var.unas.value=atoi(yytext+strlen(yytext)-1)-1;
  return REG;}
"_"*"v"[1-8] {
  yylval.var.unas.type='r';
  yylval.var.unas.value=atoi(yytext+strlen(yytext)-1)+3;
  return REG;}
"_"*"sl" {yylval.var.unas.type='r';yylval.var.unas.value=10;return REG;}
"_"*"fp" {yylval.var.unas.type='r';yylval.var.unas.value=11;return REG;}
"_"*"ip" {yylval.var.unas.type='r';yylval.var.unas.value=12;return REG;}
"_"*"sp" {yylval.var.unas.type='r';yylval.var.unas.value=13;return REG;}
"_"*"lr" {yylval.var.unas.type='r';yylval.var.unas.value=14;return REG;}
"_"*"pc" {yylval.var.unas.type='r';yylval.var.unas.value=15;return REG;}
"_"*"f"[0-7] {
  yylval.var.unas.type='r';
  yylval.var.unas.value=atoi(yytext+strlen(yytext)-1)+15;
  return REG;}


"#"[0-9]+ {
  yylval.var.unas.type='c';
  yylval.var.unas.value=atoi(yytext+sizeof(char));
  return CONST;}

"[" {return SQLEFT;}
"]" {return SQRIGHT;}

[a-zA-Z][a-zA-Z0-9$'.']* { /* Treat any character string as an operation */
  op* rator;
  int i;
  if ((rator = malloc(sizeof(op))) == NULL)
    yyerror("out of memory");
  for(i=0;i<strlen(yytext);i++)
  {
    if (yytext[i]=='.')
      yytext[i]='x';
    else
      yytext[i]=tolower(yytext[i]);
  }
  #ifdef YYDEBUG
  printf("Looking up %s",yytext);
  #endif
  rator= (op*) lookiau(yytext);
  #ifdef YYDEBUG
  printf("Got a %d",rator->type);
  #endif
  yylval.erator=*rator;
  if (!strcmp(yylval.erator.name,"_")) /* "_" is used to indicate a label */
  {
    char* tempstring;
    if ((tempstring = malloc(strlen(yytext)+4*sizeof(char))) == NULL)
      yyerror("out of memory");
    #ifdef YYDEBUG
    printf("%d %s\n", strlen(yytext), yytext);
    #endif
    sprintf(tempstring,yytext);
    yylval.erator.name=tempstring;
  }
  return rator->type;
}

"\"".+"\"" {
  yylval.byte=yytext+1;
  return STRING;
}

"\'"."\'" {
  yylval.letter=*(yytext+1);
  return CHARAC;
}

[0-9]+ {
  yylval.num=atoi(yytext);
  return NUM;
}

&[0-9a-fA-F]+ {
  yylval.num=strtol(yytext+1, (char**)NULL, 16);
  return NUM;
}

-[0-9]+ {
  yylval.num=-atoi(yytext);
  return NUM;
}

"|" ;
"," ; /* There seems to be a problem with commas... */
"_" ; /* Underscores are used a lot by RISC OS gcc and get in the way! */
"." ; /* And Linux GCC has a full stop fetish. */
":" ; /* Colons seem to be optional. */
" " ; /* Ignore spaces */
"!" ; return PLING;
"-" ; return DASH;

";".*"\n" return EOL; /* Space for comments between ; and \n */

"\n" return EOL; /* Or just a newline if we don't like semi-colons... */
