%{
#include <stdio.h>
#include <stdarg.h>
#include <stdlib.h>
#include <string.h>
#include "armgraph.h"


nodeType *start;
nodeType *current;

%}

%union
{
  op erator;
  thing var;
  char* byte;
  int* word;
  int num;
  char letter;
};

%token <var> REG CONST
%token <data> VARIABLE
%token <erator> MONAD DYAD MONDY LABEL BRANCH MEM SWI WORD BYTE DAT RDEF SHIFT
%token <byte> STR
%token <letter> CHARAC
%token <num> NUM
%token SQLEFT SQRIGHT PLING DASH
%right EOL



%type <var> expr
%type <num> registers
%type <byte> belements blist
%type <letter> belement
%type <word> wlist
%type <erator> labels

%%

comm: comm EOL
    |
    | comm EOL line           /*A standard line*/
    | comm EOL line line      /*Crude hack to handle labels*/
    | comm EOL error {yyerrok;printf("AARGH!  It's all broken!\n");}
    ;

line: LABEL {mklabel($1);}
    | DYAD REG REG expr{mkdyad($1,$2,$3,$4,0);}
    | MONAD REG expr {mkmonad($1,$2,$3,0);}
    | MONAD REG REG expr {mkmonad($1,$2,$3,0);}
    | MONDY REG SQLEFT REG expr SQRIGHT {mkdyad($1,$2,$4,$5,0);} /*Post-indexed*/
    | MONDY REG SQLEFT REG SQRIGHT expr {mkdyad($1,$2,$4,$6,(0||'\08'));} /*Pre-indexed*/
    | MONDY REG SQLEFT expr SQRIGHT {mkmonad($1,$2,$4,0);}
    | MONDY REG expr {mkmonad($1,$2,$3,0);}
    | BRANCH LABEL {mkbranch($1,$2);}
    | SWI LABEL {printf("SWI");}
    | MEM REG registers {mkmem($1,$2,$3,0);}
    | MEM REG PLING registers {mkmem($1,$2,$4,1);}
    | DAT {mknull();}                /* Assembler pseudo-ops are not welcome here */
    | DAT labels {}          /* Unless they bear data */
    | REG RDEF NUM {}
    | WORD LABEL {mkpoint($1,$2);}
    | BYTE blist {mkarray($1,$2);}
    | WORD wlist {mkarray($1,$2);}
    ;

registers: REG registers {$$=$2|(1<<$1.unas.value);}
         |               {$$=0;}
         | REG DASH REG registers
               {
                 int i;
                 int val=$4;
                 for(i=$1.unas.value;i<=$3.unas.value;i++)
                   val|=(1<<i);
                 $$=val;
               }
         ;

blist:  belements
     |  STR
     |  blist ',' blist {$$=strcat($1, $3);}
     ;

belements: belement belements
                    {
                      if (($$ = malloc(sizeof(char)+sizeof($2))) == NULL)
                        yyerror("out of memory");
                      sprintf($$, "%c%s", $1, $2);
                      if($2!="")
                        free($2);
                    }
         |          {$$=""}
         ;

belement: CHARAC
        | NUM     {$$=(char)$1;}
        ;

wlist: NUM wlist
           {
             if (($$ = malloc(sizeof(int)+sizeof($2)))==NULL)
               yyerror("out of memory");
             *$$ = $1;
             memcpy($$, $2, sizeof($2));
             free($2);
           }

     | NUM {
             if (($$ = malloc(sizeof(int)))==NULL)
               yyerror("out of memory");
             *$$ = $1;
           }
     ;

expr: REG
    | CONST
    | REG SHIFT expr
                {
                  $$.type='e';
                  $$.op.oper=$2.oper;
                  $$.op.op1=$1.unas;
                  $$.op.op2=$3.unas;
                }
    | LABEL
      {
        $$.type='l';
        $$.var.name=$1.name
      }
    ;

labels: LABEL labels {$$=$1}
      | LABEL
      ;
%%

void mkdyad(op dyad, thing targ, thing src1, thing src2, int flags)
{
  nodeType* next;
  if ((next = malloc(sizeof(nodeType))) == NULL)
    yyerror("out of memory");
  if (dyad.cond != '0')      /* If it never happens, we don't want it! */
  {
    if (dyad.cond != '*')    /* If it is a conditional dyad, we create the
                                conditional as an extra command and then
                                process the dyad as the next operation. */
    {
      current->type=typeCond;
      current->node.cond=dyad.cond;
      dyad.cond='*';
      current->next=next;
      current->interval=nullinterval;
      current->dom=nulldom;
      current=next;
      mkdyad(dyad,targ,src1,src2, flags);
    }
    else
    {
      current->type=typeDyad;
      current->node.dyad.oper=dyad.oper;
      current->node.dyad.src1=src1;
      current->node.dyad.src2=src2;
      current->node.dyad.dest=targ;
      current->next=next;
      current->interval=nullinterval;
      current->dom=nulldom;
      current=next;
    }
  }
}

void mkmonad(op monad, thing targ, thing src, int flags)
{
  nodeType* next;
  if ((next = malloc(sizeof(nodeType))) == NULL)
    yyerror("out of memory");
  if (monad.cond != '0')
  {
    if (monad.cond != '*')
    {
      current->type=typeCond;
      current->node.cond=monad.cond;
      monad.cond='*';
      current->next=next;
      current->interval=nullinterval;
      current->dom=nulldom;
      current=next;
      mkmonad(monad,targ,src,flags);
    }
   else
   {
      current->type=typeMonad;
      current->node.monad.oper=monad.oper;
      current->node.monad.src=src;
      current->node.monad.dest=targ;
      current->next=next;
      current->interval=nullinterval;
      current->dom=nulldom;
      current=next;
   }
  }
}

void mkbranch(op branch, op label)
{
  nodeType* next;
  if ((next = malloc(sizeof(nodeType))) == NULL)
    yyerror("out of memory");
  if (branch.cond != '0')
  {
    if ((branch.cond != '*')&(branch.oper != '>')) /* Branching is slightly
                                                    different.  A conditional
                                                    branch would be used in
                                                    a control structure.
                                                    Note that this does not
                                                    apply to bl */
    {
      current->type=typeCond;
      current->node.cond=branch.cond;
      branch.cond='*';
      current->next=next;
      current->interval=nullinterval;
      current=next;
      mkbranch(branch,label);
    }
    else
    {
      char* nom;
      if ((nom = malloc(sizeof(char)*10)) == NULL)
        yyerror("out of memory");
      strcpy(nom,label.name);
      current->type=typeBranch;
      current->node.branch.oper=branch.oper;
      current->node.branch.label=nom;
      current->node.branch.cond=branch.cond;
      current->next=next;
      current->interval=nullinterval;
      current->dom=nulldom;
      current=next;
    }
  }
}

void mklabel(op lab)
{
  nodeType* next;
  char* nom;
  if ((next = malloc(sizeof(nodeType))) == NULL)
    yyerror("out of memory");
  if ((nom = malloc(sizeof(char)*10)) == NULL)
     yyerror("out of memory");
  #ifdef YYDEBUG
  if(findlabel(lab.name))
    printf("Label %s declared twice",lab.name);
  else
  #endif
  {
    strcpy(nom,lab.name);           /* We want to mention the label in the
                                       output */
    current->type=typeLabel;
    current->node.label.name=nom;
    current->next=next;
    current->interval=nullinterval;
    current->dom=nulldom;
    current->node.label.target=addlabel(nom, countiau++, current);
    current=next;                   /* But we also want to add it to the
                                       lookup table... */
  }
}

void mkpoint(op dat, op label)
{
  nodeType* next;
  if ((next = malloc(sizeof(nodeType))) == NULL)
    yyerror("out of memory");
  if (dat.cond != '0')
  {
    if (dat.cond != '*')
    {
      char tempcond;
      current->type=typeCond;
      current->node.cond=tempcond=dat.cond;
      dat.cond='*';
      current->next=next;
      current->interval=nullinterval;
      current->dom=nulldom;
      current=next;
      mkpoint(dat, label);
    }
    else
    {
      current->type=typeDat;
      current->node.data.oper='p';
      current->node.data.name="_";
      current->node.data.value=label.name;
      current->next=next;
      current->interval=nullinterval;
      current->dom=nulldom;
      current=next;
    }
  }
}

void mkarray(op dat, void* string)
{
  nodeType* next;
  if ((next = malloc(sizeof(nodeType))) == NULL)
    yyerror("out of memory");
  if (dat.cond != '0')
  {
    if (dat.cond != '*')
    {
      char tempcond;
      current->type=typeCond;
      current->node.cond=tempcond=dat.cond;
      dat.cond='*';
      current->next=next;
      current->interval=nullinterval;
      current->dom=nulldom;
      current=next;
      mkarray(dat, string);
    }
    else
    {
      current->type=typeDat;
      current->node.data.oper=dat.oper;
      current->node.data.name="_";
      current->node.data.value=string;
      current->next=next;
      current->interval=nullinterval;
      current->dom=nulldom;
      current=next;
    }
  }
}

void mknull()
{
  nodeType* next;
  if ((next = malloc(sizeof(nodeType))) == NULL)
    yyerror("out of memory");
  current->type=typeNull;
  current->node.data.oper='x';
  current->node.data.name="_";
  current->node.data.value="_";
  current->next=next;
  current->interval=nullinterval;
  current->dom=nulldom;
  current=next;
}

void mkmem(op mem, thing targ, int regs, int writeback)
{
  nodeType* next;
  if ((next = malloc(sizeof(nodeType))) == NULL)
    yyerror("out of memory");
  if (mem.cond != '0')
  {
    if (mem.cond != '*')
    {
      char tempcond;
      current->type=typeCond;
      current->node.cond=tempcond=mem.cond;
      mem.cond='*';
      current->next=next;
      current->interval=nullinterval;
      current->dom=nulldom;
      current=next;
      mkmem(mem, targ, regs, writeback);
    }
    else
    {
      current->type=typeMem;
      current->node.mem.oper=mem.oper;
      current->node.mem.targ=targ;
      current->node.mem.regs=regs;
      current->node.mem.writeback=writeback;
      current->next=next;
      current->interval=nullinterval;
      current->dom=nulldom;
      current=next;
    }
  }
}

int yyerror(s)
char *s;
{printf("%s\n",s);
  return 0;
}


int main(int argc, char **argv)
{
  char* inname, *outname;
  int i;
  countiau=0;
  #ifdef YYDEBUG
  printf("Setting up\n");
  #endif
  if ((start = malloc(sizeof(nodeType))) == NULL)
    yyerror("out of memory");
  current=start;
  if ((lstart = malloc(sizeof(label))) == NULL)
    yyerror("out of memory");
  lcurrent=lstart;  /* Set up the start of the list */
  makeops();
  #ifdef YYDEBUG
  printf("Parsing\n");
  yydebug=1;
  #endif
  inname=argv[1];
  if((yyin = fopen(inname,"r"))==NULL)
    yyerror("It ain't there, guv!");
  printf(inname);
  yyparse();
  fclose(yyin);
  #ifdef YYDEBUG
  printf("Setting end\n");
  #endif
  current->type=typeEnd;
  current->next=current;
  end=current;
  #ifdef YYDEBUG
  printf("Adding null label\n");
  #endif
  addlabel("_",-1,current);
  /*if ((nullnode = malloc(sizeof(nodelist))) == NULL)
    yyerror("out of memory");*/
  #ifdef YYDEBUG
  printf("Fixing labels\n");
  #endif
  labelfixer();
  #ifdef YYDEBUG
  printf("Defragmenting code\n");
  #endif
  defragment();
  #ifdef YYDEBUG
  printf("Finishing\n");
  #endif
  if ((outname = malloc(strlen(inname)+2)) == NULL)
    yyerror("out of memory");
  strncpy(outname, inname, strlen(inname)-2);
  strcat(outname, ".c");
  out=fopen(outname, "w");
  readvar(lstart);
  readproc(lstart);
  fclose(out);
  return countiau;
}




