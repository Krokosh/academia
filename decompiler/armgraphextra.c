#include "armgraph.h"
#include "armgraph.tab.h"
#include <stdio.h>
#include <stdlib.h>
#include <math.h>

int k;

operator opers[]=
{
  {"adc",'a',DYAD},
  {"add",'+',DYAD},
  {"and",'&',DYAD},
  {"b",'>',BRANCH},
  {"bic",'c',DYAD},
  {"bl",'p',BRANCH},
  {"cmn",'+',MONAD},
  {"cmp",'-',MONAD},
  {"eor",'%',DYAD},
  {"ldr",'L',MONDY},
  {"mov",'=',MONAD},
  {"mul",'*',DYAD},
  {"mvn",'!',MONAD},
  {"orr",'|',DYAD},
  {"rsb",'_',DYAD},
  {"sbc",'s',DYAD},
  {"str",'S',MONDY},
  {"sub",'-',DYAD},
  {"swi",'*',SWI},
  {"teq",'%',MONAD},
  {"tst",'&',MONAD}
};

operator mems[]=
{
  {"ldm",'L',MEM},
  {"stm",'S',MEM}
};

operator unconds[]=
{
  {"dcb",'b',BYTE},
  {"dcd",'d',WORD},
  {"export",'x',DAT},
  {"import",'i',DAT},
  {"align",'a',DAT},
  {"area",'A',DAT},
  {"rn",'r',RDEF},
  {"fn",'f',RDEF},
  {"asl",'*',SHIFT},
  {"asr",'/',SHIFT},
  {"lsl",'<',SHIFT},
  {"lsr",'>',SHIFT},
  {"_",'*',LABEL}
};

operator conds[]=
{
  {"",'*',0},
  {"eq",'=',0},
  {"ne",'!',0},
  {"cs",'C',0},
  {"cc",'c',0},
  {"mi",'-',0},
  {"pl",'+',0},
  {"vs",'V',0},
  {"vc",'v',0},
  {"hi",'H',0},
  {"ls",'L',0},
  {"ge",'g',0},
  {"lt",'<',0},
  {"gt",'>',0},
  {"le",'l',0},
  {"al",'*',0},
  {"nv",'0',0},
};

operator memflags[]=
{
  {"ia",'A',0},
  {"ib",'B',0},
  {"da",'a',0},
  {"db",'b',0},
  {"fa",'F',0},
  {"fd",'f',0},
  {"ea",'E',0},
  {"ed",'e',0}
};

void makeops()
{
  int i,j,l;
  k=0;
  if ((ops = malloc(sizeof(opers)*sizeof(conds))) == NULL)
    yyerror("out of memory");
  for(i=0;i<21;i++)
    for(j=0;j<16;j++)
    {
      char* stringvest;
      if ((stringvest = malloc(sizeof(opers[i].name)+sizeof(conds[j].name))) == NULL)
        yyerror("out of memory");
      strcpy(stringvest,opers[i].name);
      strcat(stringvest,conds[j].name);
      (ops+k)->name=stringvest;
      (ops+k)->type=opers[i].type;
      (ops+k)->oper=opers[i].oper;
      (ops+k++)->cond=conds[j].oper;
    }
  for(i=0;i<2;i++)
    for(j=0;j<16;j++)
      for(l=0;l<8;l++)
      {
        char* stringvest;
        if ((stringvest = malloc(sizeof(mems[i].name)+sizeof(conds[j].name)+sizeof(memflags[l].name))) == NULL)
          yyerror("out of memory");
        strcpy(stringvest,mems[i].name);
        strcat(stringvest,conds[j].name);
        strcat(stringvest,memflags[l].name);
        (ops+k)->name=stringvest;
        (ops+k)->type=mems[i].type;
        (ops+k)->oper=mems[i].oper;
        (ops+k++)->cond=conds[j].oper;
      }
  for(i=0;i<13;i++)
  {
    (ops+k)->name=unconds[i].name;
    (ops+k)->type=unconds[i].type;
    (ops+k)->oper=unconds[i].oper;
    (ops+k++)->cond='*';
  }
}


op* lookiau(char* wantedName)  /* Look up an operator */
{
  int check;
  int coun=0;
  while (1)
  {
    check=strcmp((ops+coun)->name,wantedName)*strcmp((ops+coun)->name,"_");
    if (!check)
      return(ops+coun);
    else
      coun++;
  }
}

int findlabel(char* name) /* Look up a label */
{
  printf("Looking...");
  return (findlabel2(name, lstart)!=-1);
}

int findlabel2(char* nome, label* lab)
{  int check;
    printf("Looking 2");

  if (lab==lcurrent)
    return -1;
  check=strcasecmp(lab->name,nome);
  if (!check)
    return(lab->loc);/* If we have found a match, return the location. */
  return(findlabel2(nome, lab->next)); /* Otherwise, follow the pointer. */
}

label* lookuplabel(char* name) /* Look up a label */
{
  return lookuplabel2(name, lstart);
}

label* lookuplabel2(char* nome, label* lab)
{
  int check;
  check=strcasecmp(lab->name,nome)*(lab->next!=lcurrent);
  if (!check)
    return(lab);/* If we have found a match, return the location. */
  return(lookuplabel2(nome, lab->next)); /* Otherwise, follow the pointer. */
}

label* addlabel(char* name, int loc, nodeType* node) /* Add a label to the list */
{
  label* next,*tmp;

  if ((next = malloc(sizeof(label))) == NULL)
     yyerror("out of memory");
  lcurrent->name=name;
  lcurrent->loc=loc;
  lcurrent->node=node;
  lcurrent->type=-1;
  lcurrent->next=next;
  lcurrent->preds=nullnode;
  tmp=lcurrent;
  lcurrent=next;
  return tmp;
}

#ifdef CHECKINGLOOKUP
int main()
{
  op* eek;
  op ook;
  eek=lookiau("add");
  ook=*eek;
  printf(ook.name);
  printf("%d",ook.type);

}
#endif
#ifdef PRINTOUTTABLE
int yyerror(s)
char *s;
{printf("%s\n",s);
  return 0;
}
int main()
{
  int i;
  makeops();
  for(i=0;i<k;i++)
    printf("%s\t%c\t%c\t%d\n", ops[i].name, ops[i].oper, ops[i].cond, ops[i].type);
}
#endif
