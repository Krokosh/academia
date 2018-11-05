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
      if ((current->node.branch.cond=='*')&(lab->type==START))
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
  printf("Added a pred to %s", lab->name);
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
  printf("/*proc*/\n");
  while ((lab!=lcurrent)&&(lab->name!="_"))
  {
    printf(lab->name);
    if (lab->type==PROC)
    {
      int i;
      fprintf(out, "int %s(int arg1, int arg2, int arg3, int arg4)\n{\nint ", lab->name);
      ending(lab->node);
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
          case POINT : {fprintf(out, "*");break;}
        }
        while(next->type==typeDat)
        {
          fputs(next->node.data.value, out);
          next=next->next;
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
  printf("First %d=%d\n",interval->node.interval.count++, node->type);
  switch (node->type)
  {
    case typeBranch :
    {
      if (node->node.branch.oper=='>')
      {
        printf("Branch %s\n", node->node.branch.label);
        {
          node->interval=interval;
          if ((node->node.branch.target->node==interval->node.interval.header)
             |(node->next==interval->node.interval.header))
          {
            printf("Latched");
            interval->node.interval.latched=1;
          }
          intervalise(node->next, interval);
          if ((node->next->interval!=interval)&(node->next->interval!=nullinterval))
            addsucc(node->next->interval, &interval->node.interval);
          if (node->node.branch.target->node!=node->next)
          {
            intervalise(node->node.branch.target->node, interval);
            if (node->node.branch.target->node->interval!=interval)
              addcondsucc(node->node.branch.target->node->interval, &interval->node.interval, node->node.branch.cond);
          }
        }
        break;
      }
      else
      {
        printf("Proc\n");
        node->interval=interval;
        intervalise(node->next, interval);
        if ((node->next->interval!=interval)&(node->next->interval!=nullinterval))
          addsucc(node->next->interval, &interval->node.interval);
      }
      break;
    }
    case typeEnd : {printf("end\n");break;}
    case typeLabel :
    {
      nodelist* preds;
      int newintreq=0;
      printf("Label %s ", node->node.label.name);
      preds=node->node.label.target->preds;
      {
        printf("needs doing\n");
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
      printf("Interval\n");
      succs=node->node.interval.succs;
      preds=node->node.interval.preds;
      node->interval=interval;
      interval->node.interval.regsinloop=interval->node.interval.regsinloop|node->node.interval.regsinloop;
      while (succs!=nullnode)
      {
        printf("Succ\n");
        if (succs->node==interval->node.interval.header)
        {
          interval->node.interval.latched=1;
          printf("Latched (to itself?!)\n");
        }
        else
        {
          intervalise(succs->node, interval);
          printf("Intervalised\n");
          if ((succs->node->interval!=interval)&&(succs->node->interval!=nullinterval))
            addsucc(succs->node->interval, &interval->node.interval);
        }
        succs=succs->next;
          printf("Next!\n");
      }
      addpreds(node->node.interval.preds, &interval->node.interval);
      printf("Preds...\n");
      break;
    }
    case typeDyad:
    {
      rmask|=1<<node->node.dyad.dest.unas.value;
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
      rmask|=1<<node->node.monad.dest.unas.value;
      if (!interval->node.interval.latched)
      {
        interval->node.interval.regsinloop|=(1<<node->node.monad.dest.unas.value);
        if (node->node.monad.src.type=='r')
          interval->node.interval.regsforloop=interval->node.interval.regsforloop|(1<<node->node.monad.src.unas.value);
      }
      node->interval=interval;
      intervalise(node->next, interval);
      if ((node->next->interval!=interval)&(node->next->interval!=nullinterval))
        addsucc(node->next->interval, &interval->node.interval);
      break;
    }
    default :
    {
      printf("Op\n");
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
  printf("New node\n");
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
  addsucc(next, &interval->node.interval);
  printf("Node added\n");
  return next;
}

void intervalise(nodeType* node, nodeType* interval)
{
  if (node->interval==nullinterval)
  {
    printf("%d=%d\n",interval->node.interval.count++, node->type);
    switch (node->type)
    {
      case typeBranch :
      {
        if (node->node.branch.oper=='>')
        {
          printf("Branch %s\n", node->node.branch.label);
          if ((interval->node.interval.latched)
             &(node->node.branch.target->node==interval->node.interval.header))
          {
            nodeType* next=newinterval(node, interval);
            printf("Secondary latch\n");
            intervalise(node->next, next);
            if ((node->next->interval!=next)&&(node->next->interval!=nullinterval))
              addsucc(node->next->interval, &next->node.interval);
            addsucc(interval, &next->node.interval);
            addapred(interval, &next->node.interval);
              printf("Done branch\n");
          }
          else
          {
            printf("No new int\n");
            node->interval=interval;
            if ((node->node.branch.target->node==interval->node.interval.header)
               |(node->next==interval->node.interval.header))
            {
              printf("Latched");
              interval->node.interval.latch=node;
              interval->node.interval.latched=1;
            }
            intervalise(node->next, interval);
            if ((node->next->interval!=interval)&(node->next->interval!=nullinterval))
              addsucc(node->next->interval, &interval->node.interval);
            if (node->node.branch.target->node!=node->next)
            {
              intervalise(node->node.branch.target->node, interval);
              if (node->node.branch.target->node->interval!=interval)
                addcondsucc(node->node.branch.target->node->interval, &interval->node.interval, node->node.branch.cond);
            }
            printf("Branched\n");
          }
          break;
        }
        else
        {
          printf("Proc\n");
          node->interval=interval;
          intervalise(node->next, interval);
          if ((node->next->interval!=interval)&(node->next->interval!=nullinterval))
            addsucc(node->next->interval, &interval->node.interval);
        }
        break;
      }
      case typeEnd : {printf("end\n");break;}
      case typeLabel :
      {
        nodelist* preds;
        int newintreq=0;
        printf("Label %s ", node->node.label.name);
        preds=node->node.label.target->preds;
        if (node->interval==nullinterval)
        {
          printf("needs doing\n");
          while ((preds!=nullnode)&&(!newintreq))
          {
            printf("Pred time...\n");
            printf("%d\n", preds);
            printf("clear\n");
            if (preds->node->interval!=interval)
              newintreq=1;
            printf("Cheackez\n");
            preds=preds->next;
          }
          printf("Done preds\n");
          if (newintreq)
          {
            nodeType* next=newinterval(node, interval);
            intervalise(node->next, next);
            addpreds(node->node.label.target->preds, &next->node.interval);
            if ((node->next->interval!=next)&&(node->next->interval!=nullinterval))
              addsucc(node->next->interval, &next->node.interval);
            printf("Added succ\n");
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
        break;
      }
      case typeInt :
      {
        nodelist *preds, *succs;
        int newintreq=0;
        printf("Interval\n");
        succs=node->node.interval.succs;
        preds=node->node.interval.preds;
        if (preds->node==nullinterval)
          printf("PANIC!!!\n");
        else
        while ((preds!=nullnode)&&!newintreq)
        {
          printf("Pred\n");
          if ((preds->node->interval!=interval)&&(preds->node!=node))
            newintreq=1;
          else printf("Countless\n");
          preds=preds->next;
        }
        printf("Intervaln\n");
        if (newintreq)
        {
          nodeType* next=newinterval(node, interval);
          next->node.interval.regsinloop=node->node.interval.regsinloop;
          printf("Added succ\n");
          while (succs!=nullnode)
          {
            printf("Checking succs...\n");
            if (succs->node==next->node.interval.header)
            {
              next->node.interval.latched=1;
              next->node.interval.latch=node;
              printf("Latched (to itself?!) \n");
            }
            else
            {
              printf("Doing succ\n");
              intervalise(succs->node, next);
              if ((succs->node->interval!=interval)&&(succs->node->interval!=nullinterval))
                addsucc(succs->node->interval, &next->node.interval);
              succs=succs->next;
            }
          }
          addpreds(node->node.interval.preds, &next->node.interval);
          printf("Preds...\n");
        }
        else
        {
          printf("No new\n");
          node->interval=interval;
          interval->node.interval.regsinloop=interval->node.interval.regsinloop|node->node.interval.regsinloop;
          printf("interval\n");
          while (succs!=nullnode)
          {
            printf("Succ...\n");

            intervalise(succs->node, interval);
            if ((succs->node->interval!=interval)&&(succs->node->interval!=nullinterval))
              addsucc(succs->node->interval, &interval->node.interval);
            else if (succs->node==interval->node.interval.header)
            {
              interval->node.interval.latched=1;
              printf("Latched int\n");
              interval->node.interval.latch=node;
            }
            succs=succs->next;
          }
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
        printf("Op\n");
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
  else printf("Already done %d=%d\n",interval->node.interval.count, node->type);
}

void addsucc(nodeType *succnode, intNodeType *interval)
/* Add succnode to interval*/
{
  addcondsucc(succnode, *interval, '*');
}

void addcondsucc(nodeType *succnode, intNodeType *interval, char cond)
{
  nodelist *targsuccs;
  int found;
  printf("Adding a succ\n");
  targsuccs=interval->succs;
  if(succnode==nullnode)
    return;
  if (&succnode->node.interval==interval)
    return;
  {
    printf("Another succ of type %d\n", succnode->type);
    if (targsuccs!=nullnode)
    {
      printf("%d\n", targsuccs);
      while ((targsuccs->next!=nullnode)&(!found))
      {
        printf("Scanning %d\n",targsuccs->node->type);
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
    else
    {
      nodelist *next;
      printf("New succ\n");
      if ((next = malloc(sizeof(nodelist))) == NULL)
        yyerror("Outta mem, 352!");
      next->node=succnode;
      next->cond=cond;
      next->next=nullnode;
      interval->succs=next;
    }
  }
  printf("Done...\n");
}

void addapred(nodeType *prednode, intNodeType *interval)
/* Add succnode to interval*/
{
  nodelist *targpreds;
  int found;
  printf("Adding a pred\n");
  if (prednode==nullinterval) printf("SEVERE PANIC TIME!!!\n");
  targpreds=interval->preds;
  printf("Another pred of type %d\n", prednode->type);
  if (targpreds!=nullnode)
  {
    while ((targpreds->next!=nullnode)&(!found))
    {
      printf("Scanning %d\n",targpreds->node->type);
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
    printf("New succ\n");
    if ((next = malloc(sizeof(nodelist))) == NULL)
      yyerror("Outta mem, 394!");
    next->node=prednode;
    next->next=nullnode;
    interval->preds=next;
  }
  printf("Done...\n");
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
          printf("Looking preds...\n");
          if (targpreds->node==srcpreds->node->interval)
            found=1;
          else
            targpreds=targpreds->next;
        }
        if (!found)
        {
          nodelist *next;
          printf("Adding...\n");
          if ((next = malloc(sizeof(nodelist))) == NULL)
            yyerror("Outta mem, 428!");
          next->node=srcpreds->node->interval;
          next->next=nullnode;
          targpreds->next=next;
        }
        else
          printf("Already there\n");
      }
      else
      {
        nodelist *next;
        printf("new list...\n");
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
  printf("Marking loop...\n");
  if (node->interval==nullinterval)
    printf("SEVERE PANIC TIME!!!\n");
  switch (node->type)
  {
    case typeInt:
    {
      int found;
      nodelist* succs=node->node.interval.succs;
      printf("Int\n");
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
              printf("latch %d\n",node->loop=1);
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
        printf("Notint- %d\n", node->type);
        if (node->next->interval!=node->interval)
          return 0;
        if(loopmark(node->next))
        {
          printf("In loop\n");
          return node->loop=1;
        }
      }
    }

    case typeEnd:
    {
      printf ("End\n");
      return 0;
    }

    default:
    {
      printf("Notint- %d\n", node->type);
      if (node->next->interval!=node->interval)
        return 0;
      if(loopmark(node->next))
      {
        printf("In loop\n");
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
    if (node->node.interval.header->interval!=node)
      printf("Severe panic time!!!");
    succs=node->node.interval.succs;
    printf("loopmarksuper...");
    if (node->node.interval.latched)
    {
      loopmark(node->node.interval.header);
      printf("Marked\n");
      looptype(node);
      loopfollow(node);
    }
    else printf("No latch\n");
    while(succs!=nullnode)
    {
      if((!succs->done)&(succs->node!=node))
      {
        printf("Marking next interval of %d\n", succs->node->type);
        succs->done=1;
        loopmarksuper(succs->node);
        printf("Marked!\n");
      }
      else printf("Don't need to mark\n");
      succs=succs->next;
    }
  }
  else
    printf("Not an interval?! %d=%s\n", node->type, node->node.branch.label);
}

void looptype(nodeType* node) /* Well, what do you think _THIS_ does? */
{
  nodeType* head;
  nodeType* latch=node->node.interval.latch;
  printf("Typing\n");
  if(node->node.interval.header->type==typeLabel)
    head=node->node.interval.header->next;
  else
    head=node->node.interval.header;
  switch (latch->type)
  {
    case typeBranch:
    {
      printf("Branch\n");
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
      printf("Interval\n");
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
      printf("Op%d\n", latch->type);
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
      printf("Posttest\n");
      if (node->node.interval.latch->type==typeBranch)
      {
        if (node->node.interval.latch->next==node->node.interval.header)
          node->node.interval.follow=node->node.interval.latch->node.branch.target->node;
        else
          node->node.interval.follow=node->node.interval.latch->next;
      }
      else /* Well, it's got to be an Interval otherwise, hasn't it? */
      {
        nodelist *succ=node->node.interval.latch->node.interval.succs;
        while (succ!=nullnode)
        {
          if (!((succ->node->loop)&(succ->node->interval==node)))
            node->node.interval.follow=succ->node;
          succ=succ->next;
        }
      }
      break;
    }
    case PRE:
    {
      printf("Pretest\n");
      if (node->node.interval.header->next->type==typeBranch)
      {
        printf("Branch\n");
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
          if (!((succ->node->loop)&(succ->node->interval==node)))
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
      printf("Branch\n");
      if(node->node.branch.oper=='>')
      {
        int count=0;
        nodeType* inter=node;
        if(node->node.branch.target->node==node->interval->node.interval.follow)
          printf("prehead%d\n",count=1);
        while ((inter->interval!=nullinterval)&!count)
        {
          printf("Check\n");
          if (inter->interval->node.interval.latch==inter)
            count++;
          else
            inter=inter->interval;
          printf("Done\n");
        }
        if ((node->loop!=node->next->loop)
          ||(node->loop!=node->node.branch.target->node->loop))
          printf("postlatch%d\n",count=1);
        if (!count)
        {
          dominator* next;
          printf("Dom\n");
          if ((next = malloc(sizeof(dominator))) == NULL)
            yyerror("Outta mem, 770!");
          next->node=node;
          node->node.branch.dom=next;
          condstruct(node->next, next);
          condstruct(node->node.branch.target->node, next);
        }
        else
        {
          printf("notadom\n");
          node->dom=dom;
          condstruct(node->next, dom);/*WARNING!*/
        }
      }
      else
      {
        printf("bl\n");
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
      printf("Label\n");
      /*do*/
      {
        while(pred!=nullnode)
        {
          printf("Checkdom\n");
          if(nator!=nulldom)
          {
            if((pred->node->dom==nator)|(pred->node==nator->node))
            {
              printf("Dom in nator= %d\n",pred->node->type);
              count++;
            }
            else printf("Non-dom=%d\n",pred->node->type);
          }
          if(count>1)
          {
            printf("Follow\n");
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
      printf("Followed\n");
      node->dom=nator;
      condstruct(node->next, nator);
      break;
    }
    case typeInt:
    {
      dominator *nator=dom;
      nodelist* pred=node->node.interval.preds;
      int count=0;
      printf("Int\n");
      while((count<2)&(pred!=nullnode))
      {
        printf("Checking...\n");
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
      printf("Dom selected\n");
      if(node->node.interval.succs!=nullnode)
      {
        int coun=0;
        nodeType* inter=node;
        printf("Checking...\n");
        while ((inter->interval!=nullinterval)&!coun)
        {
          printf("Ing...\n");
          if(inter->interval->node.interval.latch==inter)
            coun++;
          else
            inter=inter->interval;
        }
        printf("Checked...\n");
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
      printf("End\n");
      break;
    }
    case typeDyad:
    {
      printf("Dyad\n");
      if (dom!=nulldom)
        dom->regsused=dom->regsused|(1<<node->node.dyad.dest.unas.value);
      node->dom=dom;
      condstruct(node->next, dom);
      break;
    }
    case typeMonad:
    {
      printf("Monad\n");
      if (dom!=nulldom)
        dom->regsused=dom->regsused|(1<<node->node.monad.dest.unas.value);
      node->dom=dom;
      condstruct(node->next, dom);
      break;
    }
    default:
    {
      printf("Op\n");
      node->dom=dom;
      condstruct(node->next, dom);
    }
  }
}
