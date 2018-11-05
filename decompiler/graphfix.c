#include "armgraph.h"

void labelfixer() /* First pass- works out what each label is */
{
  label* currentlab;
  int check=1;
  current=start;
  while (check)
  {
    switch (current->type)
    {
      case typeBranch :
      {
        label* lab=lookuplabel(current->node.branch.label);
        current->node.branch.target=lab;
        if (lab->loc!=-1)
        {
          addpred(lab,current);
          if (current->node.branch.oper=='p')
            lab->type=PROC;
          else
          {
            if (current->node.branch.cond=='*')
            {
              while((current->type!=typeLabel)&&(current->type!=typeEnd))
                current=current->next;

              if (current->type==typeEnd) break;
              /*Anything after an unconditional branch but before a label
                cannot be reached so we can ignore it*/

              if (current->node.label.target->type==-1)
                current->node.label.target->type=START;
              else
                current->node.label.target->type=CONV;
            }
            else
              if (lab->type==START)
                lab->type=CONV;
              else
                lab->type=CONT;
          }
        }
        else if (current->node.branch.oper=='>')
          yyerror("Branch to invalid label!\n");
        current=current->next;
        break;
      }
      case typeEnd : {check=0;break;}
      case typeLabel :
      {
        nodeType* next=current->next;
        currentlab=lookuplabel(current->node.label.target->name);
        if (next->type==typeDat)
        {
          currentlab->type=VAR;
          next->node.data.name=current->node.label.target->name;
        }
        current=next;
        break;
      }
      case typeDat :
      {
        nodeType* next=current->next;
        label* lab=lookuplabel(current->node.data.name);
        if (next->type==typeDat)
        {
          next->node.data.name=current->node.data.name;
        }
        else
        {
          while((current->type!=typeLabel)&&(current->type!=typeEnd))
            current=current->next;
            /*Anything after an unconditional branch but before a label
              cannot be reached so we can ignore it*/
          if (current->type==typeEnd) break;
          if (current->node.label.target->type==-1)
            current->node.label.target->type=START;
          else
            current->node.label.target->type=CONV;
        }
        current=next;
        break;
      }
      case typeMem :
      {
        if ((current->node.mem.oper=='S')
           &(current->node.mem.targ.unas.value==13)
           &&(current->node.mem.regs&16384))
        {
          currentlab->type=PROC;
          if(currentlab->preds!=nullnode)
          {
            currentlab->preds->node->next=end;
            currentlab->preds=nullnode;
          }
          currentlab->node=current;
        }
        current=current->next;
        break;
      }
      default : {current=current->next;break;}
    }
  }
}

void defragment()
{
  int check=1;
  current=start;
  while (current->type!=typeEnd)
  {
    if(current->type==typeBranch)
    {
      nodeType* next=current->next;
      label* lab=lookuplabel(current->node.branch.label);
      if ((current->node.branch.cond=='*')&&(lab->type==START))
      {
        current->next=lab->node;
        lab->type=CONT;
      }
      else if (current->next->type==typeLabel)
        addpred(current->next->node.label.target, current);
      current=next;

    }
    else if (current->next->type==typeLabel)
      addpred(current->next->node.label.target, current);
    current=current->next;
  }
}

void addpred(label* lab, nodeType* node)
{
  nodelist *new;
  nodelist *list;
  list=lab->preds;
  #ifdef YYDEBUG
  printf("Added a pred to %s", lab->name);
  #endif
  if ((new = malloc(sizeof(nodelist))) == NULL)
    yyerror("out of memory");
  new->node=node;
  new->next=nullnode;
  if (list!=nullnode)
  {
    while (list->next!=nullnode)
      list=list->next;
    list->next=new;
  }
  else
    lab->preds=new;
}

void readproc(label* el) /* Print out all the procs */
{
  label* lab=el;
  while ((lab!=lcurrent)&&(lab->name!="_"))
  {
    if (lab->type==PROC)
    {
      int i;
      fprintf(out, "int %s(int arg1, int arg2, int arg3, int arg4)\n{\nint ", lab->name);
      ending(lab->node->next);
      fprintf(out, "}\n");
    }
    lab=lab->next;
  }
}

void readvar(label* lab) /* Print out all the variables */
{
  if (lab!=lcurrent)
  {
    if (lab->type==VAR)
    {
      int type;
      nodeType *next=lab->node->next;
      type=findtype(next, 0);
      if (type<ARRAY)
      {
        char op;
        fprintf(out, " %s=",lab->name);
        switch(type)
        {
          case PCHAR :
          {
            next=(lookuplabel(next->node.data.value)->node->next);
            fprintf(out, "\"");
            break;
          }
          case CHAR : {fprintf(out, "\'");break;}
          case POINT : {fprintf(out, "&");break;}
        }
        op=next->node.data.oper;
        while(next->type==typeDat)
        {
          if(next->node.data.oper!=op)
            break;
          fputs(next->node.data.value, out);
          next=next->next;
          op=next->node.data.oper;
        }
        switch(type)
        {
          case PCHAR : {fprintf(out, "\";\n");break;}
          case CHAR : {fprintf(out, "\';\n");break;}
          default : fprintf(out, ";\n");
        }
      }
      lab->type=type;
    }
    readvar(lab->next);
  }
}

void firstintervalise(nodeType* node, nodeType* interval)
{
  #ifdef YYDEBUG
  printf("First %d=%d\n",interval->node.interval.count++, node->type);
  #endif
  switch (node->type)
  {
    case typeBranch :
    {
      if (node->node.branch.oper=='>')
      {
        #ifdef YYDEBUG
        printf("Branch %s\n", node->node.branch.label);
        #endif
        {
          node->interval=interval;
          if ((node->node.branch.target->node==interval->node.interval.header)
             |(node->next==interval->node.interval.header))
          {
            #ifdef YYDEBUG
            printf("Latched");
            #endif
            interval->node.interval.latched=1;
          }
          interval->node.interval.regsforloop=node->node.interval.regsforloop;
          interval->node.interval.regsinloop=node->node.interval.regsinloop;
          intervalise(node->next, interval);
          if ((node->next->interval!=interval)&(node->next->interval!=nullinterval))
            addsucc(node->next->interval, &interval->node.interval);
          if (node->node.branch.target->node!=node->next)
          {
            intervalise(node->node.branch.target->node, interval);
            if ((node->node.branch.target->node->interval!=interval)
              &&(node->node.branch.target->node->interval!=nullinterval))
              addcondsucc(node->node.branch.target->node->interval, &interval->node.interval, node->node.branch.cond);
          }
        }
        break;
      }
      else
      {
        #ifdef YYDEBUG
        printf("Proc\n");
        #endif
        node->interval=interval;
        intervalise(node->next, interval);
        if ((node->next->interval!=interval)&(node->next->interval!=nullinterval))
          addsucc(node->next->interval, &interval->node.interval);
      }
      break;
    }
    case typeEnd :
    {
      #ifdef YYDEBUG
      printf("end\n");
      #endif
      break;
    }
    case typeLabel :
    {
      nodelist* preds;
      int newintreq=0;
      #ifdef YYDEBUG
      printf("Label %s ", node->node.label.name);
      #endif
      preds=node->node.label.target->preds;
      {
        #ifdef YYDEBUG
        printf("needs doing\n");
        #endif
        {
          node->interval=interval;
          intervalise(node->next, interval);
          if ((node->next->interval!=interval)&(node->next->interval!=nullinterval))
            addsucc(node->next->interval, &interval->node.interval);
          addpreds(node->node.label.target->preds, &interval->node.interval);
        }
      }
      break;
    }
    case typeInt :
    {
      nodelist *preds, *succs;
      #ifdef YYDEBUG
      printf("Interval\n");
      #endif
      succs=node->node.interval.succs;
      preds=node->node.interval.preds;
      node->interval=interval;
      interval->node.interval.regsinloop=interval->node.interval.regsinloop|node->node.interval.regsinloop;
      while (succs!=nullnode)
      {
        #ifdef YYDEBUG
        printf("Succ\n");
        #endif
        if (succs->node==interval->node.interval.header)
        {
          interval->node.interval.latched=1;
          #ifdef YYDEBUG
          printf("Latched (to itself?!)\n");
          #endif
        }
        else
        {
          intervalise(succs->node, interval);
          #ifdef YYDEBUG
          printf("Intervalised\n");
          #endif
          if ((succs->node->interval!=interval)&&(succs->node->interval!=nullinterval))
            addsucc(succs->node->interval, &interval->node.interval);
        }
        succs=succs->next;
        #ifdef YYDEBUG
        printf("Next!\n");
        #endif
      }
      addpreds(node->node.interval.preds, &interval->node.interval);
      #ifdef YYDEBUG
      printf("Preds...\n");
      #endif
      break;
    }
      case typeDyad:
      {
        rmask|=(1<<node->node.dyad.dest.unas.value);
        if (!interval->node.interval.latched)
        {
          interval->node.interval.regsinloop|=(1<<node->node.dyad.dest.unas.value);
          interval->node.interval.regsforloop|=(1<<node->node.dyad.src1.unas.value);
          if (node->node.dyad.src2.type=='r')
            interval->node.interval.regsforloop|=(1<<node->node.dyad.src2.unas.value);
        }
        node->interval=interval;
        intervalise(node->next, interval);
        if ((node->next->interval!=interval)&(node->next->interval!=nullinterval))
          addsucc(node->next->interval, &interval->node.interval);
        break;
      }
      case typeMonad:
      {
        rmask|=(1<<node->node.monad.dest.unas.value);
        if (!interval->node.interval.latched)
        {
          interval->node.interval.regsinloop|=(1<<node->node.monad.dest.unas.value);
          if (node->node.monad.src.type=='r')
            interval->node.interval.regsforloop|=(1<<node->node.monad.src.unas.value);
        }
        node->interval=interval;
        intervalise(node->next, interval);
        if ((node->next->interval!=interval)&(node->next->interval!=nullinterval))
          addsucc(node->next->interval, &interval->node.interval);
        break;
      }
      default :
      {
        #ifdef YYDEBUG
        printf("Op\n");
        #endif
        node->interval=interval;
        intervalise(node->next, interval);
        if ((node->next->interval!=interval)&(node->next->interval!=nullinterval))
          addsucc(node->next->interval, &interval->node.interval);
      }
    }

}

nodeType* newinterval(nodeType* node, nodeType* interval)
{
  nodeType* next;
  intcount++;
  #ifdef YYDEBUG
  printf("New node\n");
  #endif
  if (((next = malloc(sizeof(nodeType))) == NULL))
    yyerror("Outta mem at 117!");
  next->type=typeInt;
  next->node.interval.header=node;
  next->node.interval.count=0;
  next->node.interval.latched=0;
  next->node.interval.succs=nullnode;
  next->node.interval.preds=nullnode;
  next->interval=nullinterval;
  node->interval=next;
  #ifdef YYDEBUG
  printf("Node added\n");
  #endif
  return next;
}

void intervalise(nodeType* node, nodeType* interval)
{
  if (node->interval==nullinterval)
  {
    #ifdef YYDEBUG
    printf("%d=%d\n",interval->node.interval.count++, node->type);
    #endif
    switch (node->type)
    {
      case typeBranch :
      {
        if (node->node.branch.oper=='>')
        {
          #ifdef YYDEBUG
          printf("Branch %s\n", node->node.branch.label);
          #endif
          if ((interval->node.interval.latched)
             &(node->node.branch.target->node==interval->node.interval.header))
          {
            nodeType* next=newinterval(node, interval);
            addcondsucc(interval, &next->node.interval, node->node.branch.cond);
            #ifdef YYDEBUG
            printf("Secondary latch\n");
            #endif
            intervalise(node->next, next);
            if ((node->next->interval!=next)&&(node->next->interval!=nullinterval))
              addsucc(node->next->interval, &next->node.interval);
            addsucc(interval, &next->node.interval);
            addapred(interval, &next->node.interval);
            #ifdef YYDEBUG
            printf("Done branch\n");
            #endif
          }
          else
          {
            #ifdef YYDEBUG
            printf("No new int\n");
            #endif
            node->interval=interval;
            if ((node->node.branch.target->node==interval->node.interval.header)
               |(node->next==interval->node.interval.header))
            {
              #ifdef YYDEBUG
              printf("Latched");
              #endif
              interval->node.interval.latch=node;
              interval->node.interval.latched=1;
            }
            intervalise(node->next, interval);
            if ((node->next->interval!=interval)&(node->next->interval!=nullinterval))
              addsucc(node->next->interval, &interval->node.interval);
            if (node->node.branch.target->node!=node->next)
            {
              intervalise(node->node.branch.target->node, interval);
              if ((node->node.branch.target->node->interval!=interval)
                &&(node->node.branch.target->node->interval!=nullinterval))
                addcondsucc(node->node.branch.target->node->interval, &interval->node.interval, node->node.branch.cond);
            }
            #ifdef YYDEBUG
            printf("Branched\n");
            #endif
          }
          break;
        }
        else
        {
          #ifdef YYDEBUG
          printf("Proc\n");
          #endif
          node->interval=interval;
          intervalise(node->next, interval);
          if ((node->next->interval!=interval)&(node->next->interval!=nullinterval))
            addsucc(node->next->interval, &interval->node.interval);
        }
        break;
      }
      case typeEnd :
      {
        #ifdef YYDEBUG
        printf("end\n");
        #endif
        break;
      }
      case typeLabel :
      {
        nodelist* preds;
        int newintreq=0;
        #ifdef YYDEBUG
        printf("Label %s ", node->node.label.name);
        #endif
        preds=node->node.label.target->preds;
        if (node->interval==nullinterval)
        {
          #ifdef YYDEBUG
          printf("needs doing\n");
          #endif
          while ((preds!=nullnode)&&(!newintreq))
          {
            #ifdef YYDEBUG
            printf("Pred time...\n");
            printf("%d\n", preds);
            printf("clear\n");
            #endif
            if (preds->node->interval!=interval)
              newintreq=1;
            #ifdef YYDEBUG
            printf("Cheackez\n");
            #endif
            preds=preds->next;
          }
          #ifdef YYDEBUG
          printf("Done preds\n");
          #endif
          if (newintreq)
          {
            nodeType* next=newinterval(node, interval);
            intervalise(node->next, next);
            addpreds(node->node.label.target->preds, &next->node.interval);
            if ((node->next->interval!=next)&&(node->next->interval!=nullinterval))
              addsucc(node->next->interval, &next->node.interval);
            #ifdef YYDEBUG
            printf("Added succ\n");
            #endif
          }
          else
          {
            node->interval=interval;
            intervalise(node->next, interval);
            if ((node->next->interval!=interval)&(node->next->interval!=nullinterval))
              addsucc(node->next->interval, &interval->node.interval);
            addpreds(node->node.label.target->preds, &interval->node.interval);
          }
        }
        #ifdef YYDEBUG
        printf("Fin %s\n", node->node.label.name);
        #endif
        break;
      }
      case typeInt :
      {
        nodelist *preds, *succs;
        int newintreq=0;
        #ifdef YYDEBUG
        printf("Interval\n");
        #endif
        succs=node->node.interval.succs;
        preds=node->node.interval.preds;
        if (preds->node==nullinterval)
          #ifdef YYDEBUG
          printf("PANIC!!!\n");
          #else
          {}
          #endif
        else
        while ((preds!=nullnode)&&!newintreq)
        {
          #ifdef YYDEBUG
          printf("Pred\n");
          #endif
          if ((preds->node->interval!=interval)&&(preds->node!=node))
            newintreq=1;
          #ifdef YYDEBUG
          else printf("Countless\n");
          #endif
          preds=preds->next;
        }
        #ifdef YYDEBUG
        printf("Intervaln\n");
        #endif
        if (newintreq)
        {
          nodeType* next=newinterval(node, interval);
          next->node.interval.regsforloop=node->node.interval.regsforloop;
          next->node.interval.regsinloop=node->node.interval.regsinloop;
          #ifdef YYDEBUG
          printf("Added succ\n");
          #endif
          while (succs!=nullnode)
          {
            #ifdef YYDEBUG
            printf("Checking succs...\n");
            #endif
            if (succs->node==next->node.interval.header)
            {
              next->node.interval.latched=1;
              next->node.interval.latch=node;
              #ifdef YYDEBUG
              printf("Latched (to itself?!) \n");
              #endif
            }
            else
            {
              #ifdef YYDEBUG
              printf("Doing succ\n");
              #endif
              intervalise(succs->node, next);
              if ((succs->node->interval!=interval)&&(succs->node->interval!=nullinterval))
                addsucc(succs->node->interval, &next->node.interval);
              succs=succs->next;
            }
          }
          addpreds(node->node.interval.preds, &next->node.interval);
          #ifdef YYDEBUG
          printf("Preds...\n");
          #endif
        }
        else
        {
          #ifdef YYDEBUG
          printf("No new\n");
          #endif
          node->interval=interval;
          #ifdef YYDEBUG
          printf("interval\n");
          #endif
          while (succs!=nullnode)
          {
            #ifdef YYDEBUG
            printf("Succ...\n");
            #endif
            intervalise(succs->node, interval);
            if ((succs->node->interval!=interval)&&(succs->node->interval!=nullinterval))
              addsucc(succs->node->interval, &interval->node.interval);
            else if (succs->node==interval->node.interval.header)
            {
              interval->node.interval.latched=1;
              #ifdef YYDEBUG
              printf("Latched int\n");
              #endif
              interval->node.interval.latch=node;
            }
            succs=succs->next;
          }
        interval->node.interval.regsforloop|=node->node.interval.regsforloop;
        interval->node.interval.regsinloop|=node->node.interval.regsinloop;
        addpreds(node->node.interval.preds, &interval->node.interval);
        }
        break;
      }
      case typeDyad:
      {
        rmask|=(1<<node->node.dyad.dest.unas.value);
        if (!interval->node.interval.latched)
        {
          interval->node.interval.regsinloop|=(1<<node->node.dyad.dest.unas.value);
          interval->node.interval.regsforloop|=(1<<node->node.dyad.src1.unas.value);
          if (node->node.dyad.src2.type=='r')
            interval->node.interval.regsforloop|=(1<<node->node.dyad.src2.unas.value);
        }
        node->interval=interval;
        intervalise(node->next, interval);
        if ((node->next->interval!=interval)&(node->next->interval!=nullinterval))
          addsucc(node->next->interval, &interval->node.interval);
        break;
      }
      case typeMonad:
      {
        rmask|=(1<<node->node.monad.dest.unas.value);
        if (!interval->node.interval.latched)
        {
          interval->node.interval.regsinloop|=(1<<node->node.monad.dest.unas.value);
          if (node->node.monad.src.type=='r')
            interval->node.interval.regsforloop|=(1<<node->node.monad.src.unas.value);
        }
        node->interval=interval;
        intervalise(node->next, interval);
        if ((node->next->interval!=interval)&(node->next->interval!=nullinterval))
          addsucc(node->next->interval, &interval->node.interval);
        break;
      }
      default :
      {
        #ifdef YYDEBUG
        printf("Op\n");
        #endif
        node->interval=interval;
        intervalise(node->next, interval);
        if ((node->next->interval!=interval)&(node->next->interval!=nullinterval))
          addsucc(node->next->interval, &interval->node.interval);
      }
    }
    if (node->type!=typeInt)
      if (node->next==interval->node.interval.header)
      {
        interval->node.interval.latched=1;
        interval->node.interval.latch=node;
      }
  }
  #ifdef YYDEBUG
  else printf("Already done %d=%d\n",interval->node.interval.count, node->type);
  #endif
}

void addsucc(nodeType *succnode, intNodeType *interval)
/* Add succnode to interval*/
{
  addcondsucc(succnode, interval, '*');
}

void addcondsucc(nodeType *succnode, intNodeType *interval, char cond)
{
  nodelist *targsuccs;
  int found;
  #ifdef YYDEBUG
  printf("Adding a succ\n");
  #endif
  targsuccs=interval->succs;
  if(succnode==nullnode)
    return;
  if (&succnode->node.interval==interval)
    return;
  {
    #ifdef YYDEBUG
    printf("Another succ of type %d\n", succnode->type);
    #endif
    if (targsuccs>1000)
    {
      #ifdef YYDEBUG
      printf("%d\n", targsuccs);
      #endif
      while ((targsuccs->next!=nullnode)&(!found))
      {
        #ifdef YYDEBUG
        printf("Scanning %d\n",targsuccs->node->type);
        #endif
        if (targsuccs->node==succnode)
          found=1;
        else
          targsuccs=targsuccs->next;
      }
      if (!found)
      {
        nodelist *next;
        if ((next = malloc(sizeof(nodelist))) == NULL)
          yyerror("Outta mem, 341!");
        next->node=succnode;
        next->cond=cond;
        next->next=nullnode;
        targsuccs->next=next;
      }
    }
    else if (targsuccs==nullnode)
    {
      nodelist *next;
      #ifdef YYDEBUG
      printf("New succ\n");
      #endif
      if ((next = malloc(sizeof(nodelist))) == NULL)
        yyerror("Outta mem, 352!");
      next->node=succnode;
      next->cond=cond;
      next->next=nullnode;
      interval->succs=next;
    }
    #ifdef YYDEBUG
    else printf("SEVERE PANIC TIME!!!%d= %d, %d, %d\n", interval, interval->header, interval->preds, interval->succs);
  }
  printf("Done...\n");
  #else
  }
  #endif
}

void addapred(nodeType *prednode, intNodeType *interval)
/* Add succnode to interval*/
{
  nodelist *targpreds;
  int found;
  #ifdef YYDEBUG
  printf("Adding a pred\n");
  if (prednode==nullinterval) printf("SEVERE PANIC TIME!!!\n");
  #endif
  targpreds=interval->preds;
  #ifdef YYDEBUG
  printf("Another pred of type %d\n", prednode->type);
  #endif
  if (targpreds!=nullnode)
  {
    while ((targpreds->next!=nullnode)&(!found))
    {
      #ifdef YYDEBUG
      printf("Scanning %d\n",targpreds->node->type);
      #endif
      if (targpreds->node==prednode)
        found=1;
      else
        targpreds=targpreds->next;
    }
    if (!found)
    {
      nodelist *next;
      if ((next = malloc(sizeof(nodelist))) == NULL)
        yyerror("Outta mem, 383!");
      next->node=prednode;
      next->next=nullnode;
      targpreds->next=next;
    }
  }
  else
  {
    nodelist *next;
    #ifdef YYDEBUG
    printf("New succ\n");
    #endif
    if ((next = malloc(sizeof(nodelist))) == NULL)
      yyerror("Outta mem, 394!");
    next->node=prednode;
    next->next=nullnode;
    interval->preds=next;
  }
  #ifdef YYDEBUG
  printf("Done...\n");
  #endif
}

void addpreds(nodelist *srcpreds, intNodeType *interval)
/* Add predlist srcpreds to interval */
{
  nodelist *targpreds;
  int found;
  while (srcpreds!=nullnode)
  {
    if (srcpreds->node!=nullinterval)
    {
      found=0;
      targpreds=interval->preds;
      if (targpreds!=nullnode)
      {
        while ((targpreds->next!=nullnode)&(!found))
        {
          #ifdef YYDEBUG
          printf("Looking preds...\n");
          #endif
          if (targpreds->node==srcpreds->node->interval)
            found=1;
          else
            targpreds=targpreds->next;
        }
        if (!found)
        {
          nodelist *next;
          #ifdef YYDEBUG
          printf("Adding...\n");
          #endif
          if ((next = malloc(sizeof(nodelist))) == NULL)
            yyerror("Outta mem, 428!");
          next->node=srcpreds->node->interval;
          next->next=nullnode;
          targpreds->next=next;
        }
        #ifdef YYDEBUG
        else
          printf("Already there\n");
        #endif
      }
      else
      {
        nodelist *next;
        #ifdef YYDEBUG
        printf("new list...\n");
        #endif
        if ((next = malloc(sizeof(nodelist))) == NULL)
          yyerror("Outta mem, 441!");
        next->node=srcpreds->node->interval;
        next->next=nullnode;
        interval->preds=next;
      }
    }
    srcpreds=srcpreds->next;
  }
}

int loopmark(nodeType* node)
{
  #ifdef YYDEBUG
  printf("Marking loop...\n");
  if (node->interval==nullinterval)
    printf("SEVERE PANIC TIME!!!\n");
  #endif
  switch (node->type)
  {
    case typeInt:
    {
      int found;
      nodelist* succs=node->node.interval.succs;
      #ifdef YYDEBUG
      printf("Int\n");
      #endif
      while ((succs!=nullnode)&(!found))
      {
        if (succs->node==node->interval->node.interval.header)
          found=1;
        else
          succs=succs->next;
      }
      if (!found)
      {
        succs=node->node.interval.succs;
        while (succs!=nullnode)
        {
          if (succs->node->interval==node->interval)
            if (loopmark(succs->node))
              #ifdef YYDEBUG
              printf("latch %d\n",node->loop=1);
              #else
              node->loop=1;
              #endif
              succs=succs->next;
        }
        return node->loop;
      }
      else return node->loop=1;
    }
    case typeBranch:
    {
      if (node->node.branch.oper=='>')
      {
        if ((node->node.branch.target->node==node->interval->node.interval.header)
           |(node->next==node->interval->node.interval.header))
          return 1;
        return node->loop=((loopmark(node->next))|(loopmark(node->node.branch.target->node)));
      }
      else
      {
        #ifdef YYDEBUG
        printf("Notint- %d\n", node->type);
        #endif
        if (node->next->interval!=node->interval)
          return 0;
        if(loopmark(node->next))
        {
          #ifdef YYDEBUG
          printf("In loop\n");
          #endif
          return node->loop=1;
        }
      }
    }

    case typeEnd:
    {
      #ifdef YYDEBUG
      printf ("End\n");
      #endif
      return 0;
    }

    default:
    {
      #ifdef YYDEBUG
      printf("Notint- %d\n", node->type);
      #endif
      if (node->next->interval!=node->interval)
        return 0;
      if(loopmark(node->next))
      {
        #ifdef YYDEBUG
        printf("In loop\n");
        #endif
        return node->loop=1;
      }
    }
  }
}


void loopmarksuper(nodeType* node) /* Wrapper for all the loop structuring
                                      stuff */
{
  nodelist *succs;
  if(node->type==typeInt)
  {
    #ifdef YYDEBUG
    if (node->node.interval.header->interval!=node)
      printf("Severe panic time!!!");
    #endif
    succs=node->node.interval.succs;
    #ifdef YYDEBUG
    printf("loopmarksuper...");
    #endif
    if (node->node.interval.latched)
    {
      loopmark(node->node.interval.header);
      #ifdef YYDEBUG
      printf("Marked\n");
      #endif
      looptype(node);
      loopfollow(node);
    }
    #ifdef YYDEBUG
    else printf("No latch\n");
    #endif
    while(succs!=nullnode)
    {
      if((!succs->done)&(succs->node!=node))
      {
        #ifdef YYDEBUG
        printf("Marking next interval of %d\n", succs->node->type);
        #endif
        succs->done=1;
        loopmarksuper(succs->node);
        #ifdef YYDEBUG
        printf("Marked!\n");
        #endif
      }
      #ifdef YYDEBUG
      else printf("Don't need to mark\n");
      #endif
      succs=succs->next;
    }
    loopmarksuper(node->node.interval.header);
  }
}

void looptype(nodeType* node) /* Well, what do you think _THIS_ does? */
{
  nodeType* head;
  nodeType* latch=node->node.interval.latch;
  #ifdef YYDEBUG
  printf("Typing\n");
  #endif
  if(node->node.interval.header->type==typeLabel)
    head=node->node.interval.header->next;
  else
    head=node->node.interval.header;
  switch (latch->type)
  {
    case typeBranch:
    {
      #ifdef YYDEBUG
      printf("Branch\n");
      #endif
      if (latch->node.branch.oper=='p')
      {
        if((head->type==typeBranch)|(head->type==typeInt))
          node->node.interval.latched=PRE;
        else
          node->node.interval.latched=INF;
        break;
      }
    }
    case typeInt: /* Also works on Branch, hence no break ;-) */
    {
      #ifdef YYDEBUG
      printf("Interval\n");
      #endif
      switch (head->type)
      {
        case typeBranch:
        {
          if (head->node.branch.oper=='>')
          {
            if ((head->next->loop)&(head->next->interval==node)
               &(head->node.branch.target->node->loop)
               &(head->node.branch.target->node->interval==node))
              node->node.interval.latched=POST;
            else
              node->node.interval.latched=PRE;
          }
          else
            node->node.interval.latched=PRE;
          break;
        }
        case typeInt:
        {
          int post=1;
          nodelist *succ=head->node.interval.succs;
          while (post&(succ!=nullnode))
          {
            post=(succ->node->loop)&(succ->node->interval==node);
            succ=succ->next;
          if (post)
            node->node.interval.latched=POST;
          else
            node->node.interval.latched=PRE;
          }
        }
        default:
          node->node.interval.latched=POST;
      }
      break;
    }
    default :
    {
      #ifdef YYDEBUG
      printf("Op%d\n", latch->type);
      #endif
      switch(head->type)
      {
        case typeBranch:
        {
          if ((head->node.branch.oper=='>')&(head->node.branch.cond!='*'))
            node->node.interval.latched=POST;
          else
            node->node.interval.latched=PRE;
          break;
        }
        case typeInt:
        {
          node->node.interval.latched=PRE;
          break;
        }
        default:
          node->node.interval.latched=INF;
      }
    }
  }
}

void loopfollow(nodeType* node)
{
  switch (node->node.interval.latched)
  {
    case POST:
    {
      #ifdef YYDEBUG
      printf("Posttest\n");
      #endif
      if (node->node.interval.latch->type==typeBranch)
      {
        if (node->node.interval.latch->next==node->node.interval.header)
          node->node.interval.follow=node->node.interval.latch->node.branch.target->node;
        else
        {
          node->node.interval.follow=node->node.interval.latch->next;
        }
      }
      else /* Well, it's got to be an Interval otherwise, hasn't it? */
      {
        nodelist *succ=node->node.interval.latch->node.interval.succs;
        while (succ!=nullnode)
        {
          if (!((succ->node->loop)
             &&(succ->node->interval==node)
             &&(succ->node!=nullnode)))
            node->node.interval.follow=succ->node;
          succ=succ->next;
        }
      }
      break;
    }
    case PRE:
    {
      #ifdef YYDEBUG
      printf("Pretest\n");
      #endif
      if (node->node.interval.header->next->type==typeBranch)
      {
        #ifdef YYDEBUG
        printf("Branch\n");
        #endif
        if ((node->node.interval.header->next->interval==node)
           &(node->node.interval.header->next->loop))
          node->node.interval.follow=node->node.interval.header->node.branch.target->node;
        else
          node->node.interval.follow=node->node.interval.header->next;
      }
      else /* Well, it's got to be an Interval otherwise, hasn't it? */
      {
        nodelist *succ=node->node.interval.header->node.interval.succs;
        while (succ!=nullnode)
        {
          if (!succ->node->loop)
            node->node.interval.follow=succ->node;
          succ=succ->next;
        }
      }
      break;
    }
    case INF:
    {
      if (node->node.interval.header->type==typeLabel)
      {
        nodeType *currentnode=node->node.interval.header;
        int found=0;
        while(!found&(currentnode->loop))
        {
          while(currentnode->type!=typeBranch)
            currentnode=currentnode->next;
          if (currentnode->node.branch.oper=='>')
          {
            if ((currentnode->interval!=node)|(!currentnode->loop))
            {
              found=1;
              node->node.interval.follow=currentnode->node.branch.target->node;
            }
            else
              currentnode=currentnode->next;
          }
          else
            currentnode=currentnode->next;
        }
      }
      else /* Well, it's got to be an Interval otherwise, hasn't it? */
        node->node.interval.follow=findfollow(node->node.interval.header, node);
    }
    default : {printf("Vot ze heck is ziss?!\n");}
  }
}

nodeType* findfollow(nodeType *nod, nodeType *inter)
{
  nodelist *succ=nod->node.interval.succs;
  if ((nod->interval!=inter)|(!nod->loop))
    return nod;
  while (succ!=nullnode)
  {
    nodeType *suck=findfollow(succ->node, inter);
    if (suck!=nullinterval)
      return suck;
    succ=succ->next;
  }
  return nullinterval;
}

void condstruct(nodeType* node, dominator* dom)
{
  switch(node->type)
  {
    case typeBranch :
    {
      #ifdef YYDEBUG
      printf("Branch\n");
      #endif
      if(node->node.branch.oper=='>')
      {
        int count=0;
        nodeType* inter=node;
        if(node->node.branch.target->node==node->interval->node.interval.follow)
          #ifdef YYDEBUG
          printf("prehead%d\n",count=1);
          #else
          count=1;
          #endif
        while ((inter->interval!=nullinterval)&!count)
        {
          #ifdef YYDEBUG
          printf("Check\n");
          #endif
          if (inter->interval->node.interval.latch==inter)
            count++;
          else
            inter=inter->interval;
          #ifdef YYDEBUG
          printf("Done\n");
          #endif
        }
        if ((node->loop!=node->next->loop)
          ||(node->loop!=node->node.branch.target->node->loop))
          #ifdef YYDEBUG
          printf("postlatch%d\n",count=1);
          #else
          count=1;
          #endif
        if (!count)
        {
          dominator* next;
          #ifdef YYDEBUG
          printf("Dom\n");
          #endif
          if ((next = malloc(sizeof(dominator))) == NULL)
            yyerror("Outta mem, 770!");
          next->node=node;
          node->node.branch.dom=next;
          condstruct(node->next, next);
          condstruct(node->node.branch.target->node, next);
        }
        else
        {
          #ifdef YYDEBUG
          printf("notadom\n");
          #endif
          node->dom=dom;
          condstruct(node->next, dom);/*WARNING!*/
        }
      }
      else
      {
        #ifdef YYDEBUG
        printf("bl\n");
        #endif
        node->dom=dom;
        condstruct(node->next, dom);
      }
      node->dom=dom;
      break;
    }
    case typeLabel:
    {
      dominator *nator=dom;
      nodelist* pred=node->node.label.target->preds;
      int predcount=0;
      int count=0;
      int domcount=0;
      #ifdef YYDEBUG
      printf("Label\n");
      #endif
      /*do*/
      {
        while(pred!=nullnode)
        {
          #ifdef YYDEBUG
          printf("Checkdom\n");
          #endif
          if(nator!=nulldom)
          {
            if((pred->node->dom==nator)|(pred->node==nator->node))
            {
              #ifdef YYDEBUG
              printf("Dom in nator= %d\n",pred->node->type);
              #endif
              count++;
            }
            #ifdef YYDEBUG
            else printf("Non-dom=%d\n",pred->node->type);
            #endif
          }
          if(count>1)
          {
            #ifdef YYDEBUG
            printf("Follow\n");
            #endif
            nator->follow=node;
            nator=nator->node->dom; /* For nested conditionals */
            count=predcount=0;      /* with shared follow node */
            pred=node->node.label.target->preds;
            domcount++;
          }
          else
          {
            if(pred->node!=node->interval->node.interval.latch)
              predcount++;
            pred=pred->next;
          }
        }
        /*if((predcount>1)&&!domcount)
        {
          nator->follow=node;
          pred=node->node.label.target->preds;
        }*/
      }/*while((predcount>1)&&!domcount);*/
      #ifdef YYDEBUG
      printf("Followed\n");
      #endif
      node->dom=nator;
      condstruct(node->next, nator);
      break;
    }
    case typeInt:
    {
      dominator *nator=dom;
      nodelist* pred=node->node.interval.preds;
      int count=0;
      #ifdef YYDEBUG
      printf("Int\n");
      #endif
      while((count<2)&(pred!=nullnode))
      {
        #ifdef YYDEBUG
        printf("Checking...\n");
        #endif
        if(pred->node->dom==nator)
          count++;
        if(count>1)
        {
          nator->follow=node;
          nator=nator->node->dom; /* For nested conditionals */
          count=0;                /* with shared follow node */
          pred=node->node.interval.preds;
        }
        else
          pred=pred->next;
      }
      #ifdef YYDEBUG
      printf("Dom selected\n");
      #endif
      if(node->node.interval.succs!=nullnode)
      {
        int coun=0;
        nodeType* inter=node;
        #ifdef YYDEBUG
        printf("Checking...\n");
        #endif
        while ((inter->interval!=nullinterval)&!coun)
        {
          #ifdef YYDEBUG
          printf("Ing...\n");
          #endif
          if(inter->interval->node.interval.latch==inter)
            coun++;
          else
            inter=inter->interval;
        }
        #ifdef YYDEBUG
        printf("Checked...\n");
        #endif
        if (!coun)
        {
          nodelist *succ=node->node.interval.succs;
          while (succ!=nullnode)
          {
            condstruct(succ->node, nator);
            succ=succ->next;
          }
        }
      }
      break;
    }
    case typeEnd:
    {
      #ifdef YYDEBUG
      printf("End\n");
      #endif
      break;
    }
    case typeDyad:
    {
      #ifdef YYDEBUG
      printf("Dyad\n");
      #endif
      if (dom!=nulldom)
        dom->regsused=dom->regsused|(1<<node->node.dyad.dest.unas.value);
      node->dom=dom;
      condstruct(node->next, dom);
      break;
    }
    case typeMonad:
    {
      #ifdef YYDEBUG
      printf("Monad\n");
      #endif
      if (dom!=nulldom)
        dom->regsused=dom->regsused|(1<<node->node.monad.dest.unas.value);
      node->dom=dom;
      condstruct(node->next, dom);
      break;
    }
    default:
    {
      #ifdef YYDEBUG
      printf("Op\n");
      #endif
      node->dom=dom;
      condstruct(node->next, dom);
    }
  }
}
