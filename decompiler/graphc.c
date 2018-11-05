#include <math.h>
#include "armgraph.h"


void codegen(nodeType* noddy, nodeType* dom, nodeType* interval)
{ /* Output code using flowgraph, interval and dominator details */
  nodeType* tempint=interval;
  nodeType* node=noddy;
  if(noddy==nullinterval)
    return;
  #ifdef YYDEBUG
  printf("Noddy of %d\n", noddy->type);
  #endif
  while((node->interval!=tempint)
      &&(node->interval!=nullinterval)
      &&(tempint!=nullinterval))
  /* When jumping between intervals, we need to operate at a higher level */
  {
    node=node->interval;
    tempint=tempint->interval;
  }
  #ifdef YYDEBUG
  printf("Node of %d\n", noddy->type);
  #endif
  if (dom!=node)
    switch(node->type)
    {
      case typeInt: /* Interval */
      {
        #ifdef YYDEBUG
        printf("Interval\n");
        #endif
        switch(node->node.interval.latched)
        {
          case PRE: /* Pre-tested loop */
          {
            desplunge(node->node.interval.regsforloop&node->node.interval.regsinloop);

            fprintf(out,"while (");
            if (node->node.interval.header->type==typeBranch)
              condgen(cond, node->node.interval.header->node.branch.cond);
            else
            {
              nodelist* succs=node->node.interval.header->node.interval.succs;
              while (succs!=nullnode)
              {
                if (!succs->node->loop)
                  condgen(cond, revcond(succs->cond));
                succs=succs->next;
              }
            }
            fprintf(out, ")\n{\n");
            codegen(node->node.interval.header, dom, node);
            desplunge(node->node.interval.regsforloop);
            fprintf(out, "}\n");
            desplunge(node->node.interval.regsinloop);
            if(node->node.interval.follow!=nullnode)
              codegen(node->node.interval.follow, dom, node);
            break;
          }
          case POST: /* Post-tested loop */
          {
            desplunge(node->node.interval.regsforloop&node->node.interval.regsinloop);
            fprintf(out, "do\n{\n");
            codegen(node->node.interval.header, dom, node);
            desplunge(node->node.interval.regsforloop);
            fprintf(out, "} while(");
            if (node->node.interval.latch->type==typeBranch)
              condgen(cond, node->node.interval.latch->node.branch.cond);
            else /* Interval */
            {
              nodelist* succs=node->node.interval.latch->node.interval.succs;
              while (succs!=nullnode)
              {
                if (succs->node==node->node.interval.header)
                  condgen(cond, succs->cond);
                succs=succs->next;
              }
            }
            fprintf(out, ");\n");
            desplunge(node->node.interval.regsinloop);
            if(node->node.interval.follow!=nullnode)
            printf("%d\n",node->node.interval.follow->type);
              codegen(node->node.interval.follow, dom, node);
            break;
          }
          case INF: /* Infinite loop */
          {
            desplunge(node->node.interval.regsforloop);
            fprintf(out, "while (1)\n{\n");
            codegen(node->node.interval.header, dom, node);
            desplunge(node->node.interval.regsforloop&node->node.interval.regsinloop);
            fprintf(out, "}\n");
            desplunge(node->node.interval.regsinloop);
            if(node->node.interval.follow!=nullnode)
              codegen(node->node.interval.follow, dom, node);
            break;
          }
          default:
            codegen(node->node.interval.header, dom, node);
        }
        break;
      }


      case typeBranch: /* Branch - conditional or procedure call */
      {
        #ifdef YYDEBUG
        printf("Branch\n");
        #endif
        if (node->node.branch.oper=='>')
        {
          if (node->node.branch.target->node!=node->next)
          {
            /* We need to make sure that this isn't a latch */
            int count=((node->node.branch.cond=='*')
                     ||(node->node.branch.cond=='0'));
            nodeType* inter=node->interval;
            nodeType* targ1=node->node.branch.target->node->interval;
            nodeType* targ2=node->next->interval;
            if(inter->node.interval.latch==node)
              #ifdef YYDEBUG
              printf("latch= %d\n", count=1);
              #else
              count=1;
              #endif
            else
              while((inter->interval!=nullinterval)
                  &&(targ1->interval!=nullinterval)
                  &&!count)
              {
                nodelist* succs=inter->node.interval.succs;
                if(inter->interval==targ1->interval) /*If targ1 is in the
                                                     interval, so is targ2 */
                  while(succs!=nullnode)
                  {
                    if((inter->interval->node.interval.latch==inter)
                      &((inter->interval->node.interval.header==targ1)
                      |(inter->interval->node.interval.header==targ2)))
                      count=1;
                    succs=succs->next;
                  }
              inter=inter->interval;
              targ1=targ1->interval;
              targ2=targ2->interval;
            }
            if (!count)
              if ((node->loop)&&(node->node.branch.target->node==interval->node.interval.follow))
              {
                count=1;
                fprintf(out, "break;\n");
              }
            /* Abnormal exit? */
            if(!count)
            /* If it's just a conditional, we can treat it as such. */
            {
              if(node->node.branch.target->node==node->next)
                codegen(node->next->next, dom, node->interval);
              else
              {
                desplunge(node->node.branch.dom->regsused);
                if(node->node.branch.dom==nullnode)
                  printf("PANIC!!!\n");
                if(node->node.branch.dom->follow==node->next)
                {
                  fprintf(out, "if (");
                  condgen(cond, node->node.branch.cond);
                  fprintf(out, ")\n{\n");
                  codegen(node->node.branch.target->node, node->node.branch.dom->follow, node->interval);
                  desplunge(node->node.branch.dom->regsused);
                  fprintf(out, "}\n");
                }
                else if(node->node.branch.dom->follow==node->node.branch.target->node)
                {
                  fprintf(out, "if (");
                  condgen(cond, revcond(node->node.branch.cond));
                  fprintf(out, ")\n{\n");
                  codegen(node->next, node->node.branch.dom->follow, node->interval);
                  desplunge(node->node.branch.dom->regsused);
                  fprintf(out, "}\n");
                }
                else
                {
                  fprintf(out, "if (");
                  condgen(cond, node->node.branch.cond);
                  fprintf(out, ")\n{\n");
                  codegen(node->node.branch.target->node, node->node.branch.dom->follow, node->interval);
                  fprintf(out, "}\nelse\n{\n");
                  desplunge(node->node.branch.dom->regsused);
                  codegen(node->next, node->node.branch.dom->follow, node->interval);
                  desplunge(node->node.branch.dom->regsused);
                  fprintf(out, "}\n");
                }
                if(node->node.branch.dom->follow!=nullinterval)
                  codegen(node->node.branch.dom->follow, dom, node->interval);
              }
            }
          }
          else
            codegen(node->next, dom, node->interval);
        }
        else
        {
          int i=!strcmp(node->node.branch.label, "gccmain");
          i+=!strcmp(node->node.branch.label, "x$stack");
          if(!i)
          {
            fprintf(out, "r0=%s(", node->node.branch.label);
            for(i=0;i<4;i++)
            {
              traverse(regs[i]);
              if (i<3)
                fprintf(out, ", ");
            }
            fprintf(out, ");\n");
            if ((regs[0] = malloc(sizeof(treeType))) == NULL)
              yyerror("Outta mem, 1569!");
            regs[0]->type=typeVar;
            if((regs[0]->object.var=malloc(sizeof(char)*4))==NULL)
              yyerror("Outta mem, 1178!");
            sprintf(regs[0]->object.var,"r%d",i);
          }
          codegen(node->next, dom, node->interval);
        }
        break;
      }
      case typeEnd: break;
      case typeLabel:
      {
        #ifdef YYDEBUG
        printf("Label\n");
        #endif
        switch(node->node.label.target->type)
        {
          case PROC: return;
          case CONV:
          case CONT : /*printf("%s:\n", node->node.label.name);*/
          default: codegen(node->next, dom, node->interval);
        }
        break;
      }
      case typeMonad:
      {
        #ifdef YYDEBUG
        printf("Monad\n");
        #endif
        switch(node->node.monad.oper)
        {
          case '-':
          case '+':
          case '%':
          case '&':
          {
            cond->node=dodyad(&node->node.monad.dest, &node->node.monad.src, node->node.monad.oper);
            cond->joint='*';
            break;
          }
          case '=':
          {
            regs[node->node.monad.dest.unas.value]=domonad(&node->node.monad.src);
            break;
          }
          case '!':
          {
            if((regs[node->node.monad.dest.unas.value]=malloc(sizeof(treeType))) == NULL)
              yyerror("Outta mem, 1008!");
            regs[node->node.monad.dest.unas.value]->type=typeNot;
            regs[node->node.monad.dest.unas.value]->object.not=domonad(&node->node.monad.src);
            break;
          }
          case 'S':
          {
            switch(node->node.monad.src.type)
            {
              case 'r':
              {
                fprintf(out, "*");
                traverse(regs[node->node.monad.src.unas.value]);
                break;
              }
              case 'v':
              {
                fprintf(out, node->node.monad.src.var.name);
                break;
              }
              case 'l':
              {
                fprintf(out, node->node.monad.src.var.name);
                break;
              }
            }
            fprintf(out, "=");
            traverse(regs[node->node.monad.dest.unas.value]);
            break;
          }
          case 'L':
          {
            treeType* toreturn;
            if ((toreturn = malloc(sizeof(treeType))) == NULL)
              yyerror("Outta mem, 1016!");
            toreturn->type=typeVar;
            switch(node->node.monad.src.type)
            {
              case 'r':
              {
              if((toreturn->object.var=malloc(sizeof(char)*4))==NULL)
                yyerror("Outta mem, 1178!");
              sprintf(toreturn->object.var,"r%d",node->node.monad.dest.unas.value);
              fprintf(out, "*r%d=", node->node.monad.dest.unas.value);
              traverse(regs[node->node.monad.src.unas.value]);
              fprintf(out, ";\n");
              break;
              }
              case 'v':
              {
                if((toreturn->object.var=malloc(strlen(node->node.monad.src.var.name)+3*sizeof(char))) == NULL)
                  yyerror("out of memory");
                sprintf(regs[node->node.monad.dest.unas.value]->object.var, "*%s",node->node.monad.src.var.name);
                break;
              }
              case 'l':
              {
                toreturn->object.var=node->node.monad.src.var.name;
                break;
              }
            }
            regs[node->node.monad.dest.unas.value]=toreturn;
            break;
          }
          default: printf("/*Monad*/\n");
        }
        codegen(node->next, dom, node->interval);
        break;
      }
      case typeDyad:
      {
        #ifdef YYDEBUG
        printf("Dyad\n");
        #endif
        switch(node->node.dyad.oper)
        {
          case 'S':
          {
            fprintf(out, "*(int*)(");
            switch(node->node.dyad.src1.type)
            {
              case 'r':
              {
                traverse(regs[node->node.dyad.src1.unas.value]);
                break;
              }
              case 'v':
              {
                fprintf(out, node->node.dyad.src1.var.name);
                break;
              }
              case 'l':
              {
                fprintf(out, node->node.dyad.src1.var.name);
                break;
              }
            }
            fprintf(out, "+");
            traverse(regs[node->node.dyad.src2.unas.value]);
            fprintf(out, ")=");
            traverse(regs[node->node.dyad.dest.unas.value]);
            fprintf(out, ";\n");
            break;
          }
          case 'L' :
          {
            treeType *temptree;
            if ((temptree = malloc(sizeof(treeType))) == NULL)
              yyerror("Outta mem, 1035!");
            switch(node->node.dyad.src1.type)
            {
              case 'r':
              {
                temptree->type=typeVar;
                if((temptree->object.var=malloc(sizeof(char)*4))==NULL)
                  yyerror("Outta mem, 1178!");
                sprintf(temptree->object.var,"r%d",node->node.dyad.dest.unas.value);
              fprintf(out, "r%d=*(int*)(", node->node.dyad.dest.unas.value);
              traverse(regs[node->node.dyad.src1.unas.value]);
              fprintf(out, "+");
              traverse(domonad(&node->node.dyad.src2));
              fprintf(out, ");\n");
              break;
              }
              case 'v':
              {
                temptree->type=typeOper;
                if ((temptree->object.oper.left = malloc(sizeof(treeType))) == NULL)
                  yyerror("Outta mem, 1035!");
                temptree->object.oper.left->type=typeVar;
                if((temptree->object.oper.left->object.var=malloc(strlen(node->node.monad.src.var.name)+8*sizeof(char))) == NULL)
                  yyerror("out of memory");
                sprintf(regs[node->node.monad.dest.unas.value]->object.var, "*(int*)%s",node->node.dyad.src1.var.name);
                temptree->object.oper.right=domonad(&node->node.dyad.src2);
                break;
              }
              case 'l':
              {
                temptree->type=typeOper;
                if ((temptree->object.oper.left = malloc(sizeof(treeType))) == NULL)
                  yyerror("Outta mem, 1035!");
                temptree->object.oper.left->type=typeVar;
                temptree->object.oper.left->object.var=node->node.monad.src.var.name;
                temptree->object.oper.right=domonad(&node->node.dyad.src2);
                break;
              }
            }
            regs[node->node.monad.dest.unas.value]=temptree;
            break;
          }
          default:
          {
            regs[node->node.dyad.dest.unas.value]=dodyad(&node->node.dyad.src1, &node->node.dyad.src2, node->node.dyad.oper);
            if(node->node.dyad.dest.unas.value==node->node.dyad.src1.unas.value)
              desplunge(1<<node->node.dyad.dest.unas.value);
          }
        }
        codegen(node->next, dom, node->interval);
        break;
      }
      case typeCond:
      {
        int cmp=0;
        nodeType* next=node->next->next;
        int invcond=0;
        int nextcond=0;
        #ifdef YYDEBUG
        printf("Cond\n");
        #endif
        if (node->next->type==typeMonad)
          switch (node->next->node.monad.oper)
          {
            case '+':
            case '-':
            case '&':
            case '%':
            {
              condlist *tmpcond;
              if ((tmpcond=malloc(sizeof(condlist)))==NULL)
                yyerror("Out of memory!\n");
              tmpcond->node=dodyad(&node->next->node.monad.dest, &node->next->node.monad.src, node->next->node.monad.oper);
              tmpcond->joint=node->node.cond;
              tmpcond->next=cond;
              cond=tmpcond;
              cmp=1;
              break;
            }
          }
        if (!cmp)
        {
          int regmask=0;
          fprintf(out, "if (");
          condgen(cond, node->node.cond);
          fprintf(out, ")\n{\n");
          codegen(node->next, node->next->next, node->interval);
          if (node->next->type==typeMonad)
            regmask=(1<<node->node.monad.dest.unas.value);
          else if(node->next->type==typeDyad)
            regmask=(1<<node->node.dyad.dest.unas.value);
          while((next->type==typeCond)&!nextcond)
          {
            if ((node->node.cond==next->node.cond)&!invcond)
            {
              if (node->next->type==typeMonad)
                regmask|=(1<<node->node.monad.dest.unas.value);
              else if(node->next->type==typeDyad)
                regmask|=(1<<node->node.dyad.dest.unas.value);
              codegen(next->next, next->next->next, next->interval);
              next=next->next->next;
            }
            else if(node->node.cond==revcond(next->node.cond))
            {
              if (!invcond)
                fprintf(out, "}\nelse\n{\n");
              invcond=1;
              if (node->next->type==typeMonad)
                regmask|=(1<<node->node.monad.dest.unas.value);
              else if(node->next->type==typeDyad)
                regmask|=(1<<node->node.dyad.dest.unas.value);
              codegen(next->next, next->next->next, next->interval);
              next=next->next->next;
            }
            else
              nextcond=1;
          }
          desplunge(regmask);
          fprintf(out, "}\n");
        }
        codegen(next, dom, node->interval);
        break;
      }
      case typeMem:
      {
        #ifdef YYDEBUG
        printf("Mem\n");
        #endif
        if ((node->node.mem.oper=='L')
           &(node->node.mem.targ.unas.value==11)
           &&(node->node.mem.regs&16384))
        {
          fprintf(out, "return");
          traverse(regs[0]);
          fprintf(out, ";\n");
          break;
        }
      }
      default:
      {
        codegen(node->next, dom, node->interval);
      }
    }
}

treeType* domonad(thing* src)
{
  treeType* toreturn;
  switch(src->type)
  {
    case 'r':
    {
      toreturn=regs[src->unas.value];
      break;
    }
    case 'c':
    {
      if ((toreturn = malloc(sizeof(treeType))) == NULL)
        yyerror("Outta mem, 1016!");
      toreturn->type=typeNum;
      toreturn->object.num=src->unas.value;
      toreturn->vartype=INT;
      break;
    }
    case 'e':
    {
      if ((toreturn = malloc(sizeof(treeType))) == NULL)
        yyerror("Outta mem, 1016!");
      toreturn->type=typeOper;
      toreturn->object.oper.op=src->op.oper;
      toreturn->object.oper.left=express(&src->op.op1);
      toreturn->object.oper.right=express(&src->op.op2);
      break;
    }
    case 'v':
    {
      if ((toreturn = malloc(sizeof(treeType))) == NULL)
        yyerror("Outta mem, 1016!");
      toreturn->type=typeVar;
      toreturn->object.var=src->var.name;
      toreturn->vartype=lookuplabel(src->var.name)->type;
      break;
    }
    case 'l':
    {
      if ((toreturn = malloc(sizeof(treeType))) == NULL)
        yyerror("Outta mem, 1016!");
      toreturn->type=typeLab;
      toreturn->object.var=malloc(sizeof(src->var.name)+sizeof(char));
      sprintf(toreturn->object.var,"&%s",src->var.name);
      toreturn->vartype=lookuplabel(src->var.name)->type;
      break;
    }

    default: printf("/*Something odd has happened*/");
  }
  return toreturn;
}

treeType* dodyad(thing* src1, thing* src2, char oper)
{ /* produce the result of a dyadic operation */
  treeType* temptree;
  if ((temptree = malloc(sizeof(treeType))) == NULL)
    yyerror("Outta mem, 1035!");
  temptree->type=typeOper;
  temptree->object.oper.left=regs[src1->unas.value];
  switch(src2->type)
  {
    case 'r':
    {
      temptree->object.oper.right=regs[src2->unas.value];
      break;
    }
    case 'c':
    {
      if((temptree->object.oper.right=malloc(sizeof(treeType)))==NULL)
        yyerror("Outta mem, 1050!");
      temptree->object.oper.right->type=typeNum;
      temptree->object.oper.right->object.num=src2->unas.value;
      break;
    }
    case 'e':
    {
      if((temptree->object.oper.right=malloc(sizeof(treeType)))==NULL)
        yyerror("Outta mem, 1059!");
      temptree->object.oper.right->type=typeOper;
      temptree->object.oper.right->object.oper.op=src2->op.oper;
      temptree->object.oper.right->object.oper.left=express(&src2->op.op1);
      temptree->object.oper.right->object.oper.right=express(&src2->op.op2);
      break;
    }
    case 'v':
    {
      if ((temptree->object.oper.right = malloc(sizeof(treeType))) == NULL)
        yyerror("Outta mem, 1016!");
      temptree->object.oper.right->type=typeVar;
      temptree->object.oper.right->object.var=src2->var.name;
      temptree->object.oper.right->type=lookuplabel(src2->var.name)->type;
      break;
    }
    case 'l':
    {
      if ((temptree = malloc(sizeof(treeType))) == NULL)
        yyerror("Outta mem, 1016!");
      temptree->object.oper.right->type=typeLab;
      temptree->object.oper.right->object.var=malloc(sizeof(src2->var.name)+sizeof(char));
      sprintf(temptree->object.oper.right->object.var,"&%s",src2->var.name);
      temptree->object.oper.right->vartype=lookuplabel(src2->var.name)->type;
      break;
    }
  }
  switch(oper)
  {
    default: temptree->object.oper.op=oper;
  }
  return temptree;
}

int findtype(nodeType* node, int display) /* Find the type of a constant via DCx*/
{
  switch (node->node.data.oper)
  {
    case 'b' :
      if (!(node->node.data.value+sizeof(char))|display)
      {
        fprintf(out, "char");
        return CHAR;
      }
      else return STRING;
    case 'd' :
      if (!(node->node.data.value+sizeof(int))|display)
      {
        fprintf(out, "int");
        return INT;
      }
      else return ARRAY;
    case 'p' :
    {
      int type;
      label* lab = lookuplabel(node->node.data.value);
      type=findtype(lab->node->next, 1);
      fprintf(out, "*");
      switch (type)
      {
        case CHAR :
        case STRING : return PCHAR;
        case INT :
        case ARRAY : return PINT;
        default : return POINT;
      }
    }
    case 'x' : return 100;
    default : fprintf(out, "void");
  }
}


char revcond(char op) /* Return the inverse of a condition code */
{
  switch(op)
  {
    case '=': return '!';
    case '!': return '=';
    case 'C': return 'c';
    case 'c': return 'C';
    case '-': return '+';
    case '+': return '-';
    case 'V': return 'v';
    case 'v': return 'V';
    case 'H': return 'L';
    case 'L': return 'H';
    case 'g': return '<';
    case '<': return 'g';
    case '>': return 'l';
    case 'l': return '>';
    case '*': return '0';
    case '0': return '*';
    default : return '?';
  }
}

treeType* express(uno* unas)
{
  printf("/*Expressing*/");
  switch(unas->type)
  {
    case 'r':
    {
      return(regs[unas->value]);
    }
    case 'c':
    {
      treeType* expression;
      if ((expression = malloc(sizeof(treeType))) == NULL)
        yyerror("Outta mem, 1154!");
      expression->type=typeNum;
      expression->object.num=unas->value;
      return expression;
    }
    default: fprintf(out, "/*False parameters passed*/\n");
  }
}

void desplunge(int regmask)
{
  int i;
  char* output="";
  for(i=0;i<16;i++)
  {
    if ((regmask>>i) % 2)
    {
      int flag=0;
      if (regs[i]->type==typeVar)
        if ((regs[i]->object.var[0]=='r')&&(regs[i]->object.var[1]==i+'0'))
          flag=1;
      if (!flag)
      {
        fprintf(out, "r%d=",i);
        traverse(regs[i]);
        fprintf(out, ";\n");
      }
    }
  }
  for(i=0;i<16;i++)   /* Yes, it looks bad but it's for the best! */
  {
    if ((regmask>>i) % 2)
    {
      if ((regs[i] = malloc(sizeof(treeType))) == NULL)
        yyerror("Outta mem, 1569!");
      regs[i]->type=typeVar;
      if((regs[i]->object.var=malloc(sizeof(char)*4))==NULL)
        yyerror("Outta mem, 1178!");
      sprintf(regs[i]->object.var,"r%d",i);
    }
  }
}

void condgen(condlist* conds, char cond)
{
  switch (conds->joint)
  {
    case '*' : {condpair(conds->node, cond);break;}
    default :
    {
      fprintf(out, "(");
      condpair(conds->node, cond);
      fprintf(out, "&&");
      condgen(conds->next, conds->joint);
      fprintf(out, ")||");
      condgen(conds->next, cond);
    }
  }
}

void condpair(treeType* node, char cond)
{

  switch (node->object.oper.op)
  {
    case '-' :
    {
      switch (cond)
      {
        case '=' :
        case '!' :
        {
          traverse(node->object.oper.left);
          fprintf(out, "%c=", cond);
          traverse(node->object.oper.right);
          break;
        }
        case 'C' :
        case 'c' :
        case '-' :
        case '+' :
        case 'V' :
        case 'v' :{fprintf(out, "1/*Something happens which we can't handle*/");break;}
        case 'H' :
        {
          fprintf(out, "(");
          traverse(node->object.oper.left);
          fprintf(out, ">");
          traverse(node->object.oper.right);
          fprintf(out, ")|(");
          traverse(node->object.oper.left);
          fprintf(out, "<0)");
          break;
        }
        case 'L' :
        {
          fprintf(out, "(");
          traverse(node->object.oper.left);
          fprintf(out, "<=");
          traverse(node->object.oper.right);
          fprintf(out, ")&(");
          traverse(node->object.oper.left);
          fprintf(out, ">=0)");
          break;
        }
        case 'g' :
        {
          traverse(node->object.oper.left);
          fprintf(out, ">=");
          traverse(node->object.oper.right);
          break;
        }
        case '<' :
        case '>' :
        {
          traverse(node->object.oper.left);
          fprintf(out, "%c", cond);
          traverse(node->object.oper.right);
          break;
        }
        case 'l' :
        {
          traverse(node->object.oper.left);
          fprintf(out, "<=");
          traverse(node->object.oper.right);
          break;
        }
        default : fprintf(out, "- /*Invalid condition code %c */",cond);
      }
      break;
    }
    case '+' :
    {
      switch (cond)
      {
        case '=' :
        case '!' :
        {
          traverse(node->object.oper.left);
          fprintf(out, "%c= -", cond);
          traverse(node->object.oper.right);
          break;
        }
        case 'C' :
        case 'c' :
        case '-' :
        case '+' :
        case 'V' :
        case 'v' :
        case 'H' :
        case 'L' : {fprintf(out, "/*Help!*/");break;}
        case 'g' :
        {
          traverse(node->object.oper.left);
          fprintf(out, ">= -");
          traverse(node->object.oper.right);
          break;
        }
        case '<' :
        case '>' :
        {
          traverse(node->object.oper.left);
          fprintf(out, "%c -", cond);
          traverse(node->object.oper.right);
          break;
        }
        case 'l' :
        {
          traverse(node->object.oper.left);
          fprintf(out, "<= -");
          traverse(node->object.oper.right);
          break;
        }
        default : fprintf(out, "+ /*Invalid condition code %c */",cond);
      }
      break;
    }
    case '%' :
    {
      switch (cond)
      {
        case '=' :
        case '!' :
        {
          traverse(node->object.oper.left);
          fprintf(out, "%c=", cond);
          traverse(node->object.oper.right);
          break;
        }
        case 'C' :
        case 'c' :
        case '-' :
        case '+' :
        case 'V' :
        case 'v' :
        case 'H' :
        case 'L' : {fprintf(out, "/*Help!*/");break;}
        case 'g' :
        case '<' : {fprintf(out, "/*DANGER!*/");break;}
        case '>' :
        {
          traverse(node->object.oper.left);
          fprintf(out, "%!=", cond);
          traverse(node->object.oper.right);
          break;
        }
        case 'l' :
        {
          traverse(node->object.oper.left);
          fprintf(out, "%==", cond);
          traverse(node->object.oper.right);
          break;
        }
        default : fprintf(out, "% /*Invalid condition code %c */",cond);
      }
      break;
    }
    case '&' :
    {
      switch (cond)
      {
        case '=' :
        {
          fprintf(out, "!(");
          traverse(node->object.oper.left);
          fprintf(out, ")&(");
          traverse(node->object.oper.right);
          fprintf(out, ")");
          break;}
        case '!' : {fprintf(out, "&");break;}
        case 'C' :
        case 'c' :
        case '-' :
        case '+' :
        case 'V' :
        case 'v' :
        case 'H' :
        case 'L' : {fprintf(out, "/*Help!*/");break;}
        case 'g' : {fprintf(out, "");break;}
        case '<' : {fprintf(out, "");break;}
        case '>' : {fprintf(out, "> -");break;}
        case 'l' : {fprintf(out, "<= -");break;}
        default : fprintf(out, "- /*Invalid condition code %c */",cond);
      }
      break;
    }
    default: fprintf(out, "/*unknown comparison*/");
  }
}

void traverse(treeType* tree)
{
  switch (tree->type)
  {
    case typeNum :
    {
      fprintf(out, "%d", tree->object.num);
      break;
    }
    case typeOper :
    {
      if(tree->object.oper.op=='_')
      {
        fprintf(out, "(");
        traverse(tree->object.oper.right);
        fprintf(out, "-",tree->object.oper.op);
        traverse(tree->object.oper.left);
        fprintf(out, ")");
      }
      else
      {
        fprintf(out, "(");
        traverse(tree->object.oper.left);
        fprintf(out, "%c",tree->object.oper.op);
        traverse(tree->object.oper.right);
        fprintf(out, ")");
      }
      break;
    }
    case typeNot :
    {
      fprintf(out, "!");
      traverse(tree->object.not);
      break;
    }
    case typeLab :
    case typeVar :{fputs(tree->object.var, out);break;}
    default: fprintf(out, "PANIC!%d\n", tree->type);
  }
}

void ending(nodeType* nstart)
{
  dominator* dom;
  int i;
  int prevcount=101;
  intcount=100;
  rmask=1;
  if ((cond=malloc(sizeof(condlist)))==NULL)
    yyerror("Not enough mem for cond");
  cond->joint='*';
  for (i=0;i<16;i++)
  {
      if ((regs[i] = malloc(sizeof(treeType))) == NULL)
        yyerror("Outta mem, 1569!");
    if (i<4)
    {
      regs[i]->type=typeVar;
      if((regs[i]->object.var=malloc(sizeof(char)*5))==NULL)
        yyerror("Outta mem, 1178!");
      sprintf(regs[i]->object.var,"arg%d",i+1);
    }
    else
    {
      regs[i]->type=typeNum;
      regs[i]->object.num=0;
    }
  }
  if ((istart = malloc(sizeof(nodelist))) == NULL)
    yyerror("Outta mem, 1574!");
  if ((dom = malloc(sizeof(dominator))) == NULL)
    yyerror("Outta mem, 1576!");
  istart->node=nstart;
  icurrent=istart;
  while((prevcount>intcount)&&(intcount>1))
  {
    nodelist *inext;
    nodeType *nnext=newinterval(icurrent->node, nullinterval);
    #ifdef YYDEBUG
    printf("Next graph...\n");
    #endif
    if ((inext = malloc(sizeof(nodelist))) == NULL)
      yyerror("Outta mem, guv!");
    #ifdef YYDEBUG
    printf("Allocated\n");
    #endif
    inext->node=nnext;
    icurrent->next=inext;
    #ifdef YYDEBUG
    printf("Count=%d\n",prevcount=intcount);
    #else
    prevcount=intcount;
    #endif
    intcount=0;
    #ifdef YYDEBUG
    printf("Constructed\n");
    #endif
    firstintervalise(icurrent->node, inext->node);
    if (inext->node->node.interval.header->interval!=inext->node)
    {
      if (inext->node->type!=typeInt)
        inext->node=inext->node->next;
    }
    #ifdef YYDEBUG
    printf("Built\n");
    #endif
    icurrent=icurrent->next;
  }
  icurrent->next=nullnode;
  icurrent=istart->next;
  dom->node=nstart;
  #ifdef YYDEBUG
  printf("Starting cond structure\n");
  #endif
  condstruct(nstart, nulldom);
  while (icurrent->next!=nullnode)
  {
    dominator* nextdom;
    icurrent=icurrent->next;
    if ((nextdom = malloc(sizeof(dominator))) == NULL)
      yyerror("Outta mem, guv!");
    #ifdef YYDEBUG
    printf("Marking graph\n");
    #endif
    icurrent->done=1;
    #ifdef YYDEBUG
    printf("Starting loop structure\n");
    #endif
    loopmarksuper(icurrent->node);
    #ifdef YYDEBUG
    printf("Starting cond structure\n");
    #endif
    condstruct(icurrent->node, nextdom);
  }
  dom->follow=current;
      for(i=15;i>0;i--)
        if ((rmask>>i) % 2)
          fprintf(out, "r%d, ",i);
      fprintf(out, "r0;\n");
  codegen(icurrent->node, current, nullinterval);
}
