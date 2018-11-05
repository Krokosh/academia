#include <stdio.h>
#include <stdarg.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>

/*Label types */

#define PROC 0          /* Procedure */
#define CONT 1          /* Control structures eg if-else */
#define VAR 2           /* Variables */
#define POINT 3         /* Pointers */
#define START 4         /* Start of a block of code */
#define CONV 5          /* Convergence from an if-else statement */
#define HALFCONV 6      /* Convergence with one input filled */
#define LOOP 7          /* For when it has to be a loop. */

/* Data types- used for constants */

#define CHAR 8
#define INT 9
#define PCHAR 10
#define PINT 11
#define POTH 12
#define ARRAY 13
#define STRING 14

/* Loop types */

#define POST 1
#define PRE 2
#define INF 3


/* Data structures for operands */

typedef struct /*Register or constant*/
{
  char type;
  int value;
}uno;

typedef union thingTag
{
  char type;
  uno unas;
  struct {
    char type;
    char oper;
    uno op1;
    uno op2;
  }op;
  struct {
    char type;
    char* name;
  }var;
} thing;

/* Data structures used for the lookup table */

typedef struct
{
  char* name;
  char oper;
  int type;
} operator;
/* Simple operator type used for holding condition codes and operators. */

typedef struct
{
  char* name;
  int type;
  char oper;
  char cond;
} op;
/* Used for holding operator with condition code in lookup table */

/* Labels */

typedef struct labelType
{
  char* name;
  int loc;
  int type;
  struct nodenode *preds;
  struct nodeTypeTag *node;
  struct labelType *next;
} label;


/* Flowgraph nodes */

typedef enum { typeDyad, typeMonad, typeBranch, typeCond, typeEnd, typeLabel, typeDat, typeMem, typeInt, typeNull } nodeEnum;
/* The intermediate code format...
   Each op is represented by a character. */

typedef struct
{
  int line;
  char oper;
  thing src1;
  thing src2;
  thing dest;
  char flags;
} dyadNodeType;                    /* Dyadic operation */

typedef struct
{
  int line;
  char oper;
  thing src;
  thing dest;
  char flags;
} monadNodeType;                   /* Monadic operation */

typedef struct
{
  int line;
  char oper;
  char cond;
  char* label;
  label* target;
  struct dom *dom;
} branchNodeType;                  /* A branch- either b (>) or bl (p) */

typedef struct
{
  int line;
} endNodeType;                     /* The end... */

typedef struct
{
  int line;
  char* name;
  label* target;
} labelNodeType;                   /* Labels */

typedef struct
{
  int line;
  char oper;
  char* name;
  void* value;
} datNodeType;                     /* Data */

typedef struct
{
  int line;
  char oper;
  thing targ;
  int regs;
  int writeback;
} memNodeType;                     /* Memory access */

typedef struct intervalType
{
  struct nodeTypeTag *header;
  struct nodeTypeTag *latch;
  struct nodeTypeTag *follow;
  struct nodenode *preds;
  struct nodenode *succs;
  int count;
  int latched;
  int regsinloop;
  int regsforloop;
} intNodeType;                     /* Intervals- used later in interval
                                      graphs */

typedef struct nodeTypeTag
{
  nodeEnum type;
  union
  {
    dyadNodeType dyad;
    monadNodeType monad;
    branchNodeType branch;
    char cond; /* Condition code- if satisfied, execute next op. */
    endNodeType end;
    labelNodeType label;
    datNodeType data;
    memNodeType mem;
    intNodeType interval;
  } node;
  struct nodeTypeTag *next;
  struct nodeTypeTag *interval;
  struct dom *dom;
  int loop;
} nodeType;


/* Nodes for the 'unparse' tree */

typedef enum { typeNum, typeOper, typeNot, typeVar, typeLab } treeEnum;

typedef struct
{
  struct treeTypeTag *left;
  char op;
  struct treeTypeTag *right;
  int used;
} operTreeType;      /* ALU operation- mainly dyadic. */

typedef struct treeTypeTag
{
  treeEnum type;
  union
  {
    int num;
    operTreeType oper;
    struct treeTypeTag *not;
    char* var;
  }object;
  int vartype;
} treeType;            /* Standard format for all nodes */

/* Other data structures */

typedef struct nodenode
{
  nodeType *node;
  char cond;
  int done;
  struct nodenode *next;
}nodelist;
/* Linked list of nodes */

typedef struct dom
{
  nodeType* node;
  int regsused;
  nodeType* follow;
}dominator;
/* Used to represent conditionals */

typedef struct condnode
{
  treeType* node;
  char joint; /* Condition code of current comparison (* if unconditional) */
  struct condnode* next; /* Previous condition value (if any) */
} condlist;
/* Holds a condition value as defined by the status flag */

/* Global variables */

nodeType *start, *current, *end;

nodelist *nullnode;            /* The default values- used in comparisons */
nodeType *nullinterval;
dominator *nulldom;

label *lstart, *lcurrent;      /* The label list */

nodelist *istart, *icurrent;   /* The interval graph */

op* ops;                       /* The lookup table */

treeType *regs[16];            /* The register list */
condlist *cond;                /* The current conditional value */

int countiau, intcount;
int rmask;

extern FILE *yyin;             /* Input/output files */
FILE *out;

/* Function prototypes */

/* from armgraph.y (Bulk of parser) */
void mkdyad(op dyad, thing targ, thing src1, thing src2, int flags);
void mkmonad(op monad, thing targ, thing src, int flags);
void mkbranch(op branch, op label);
void mklabel(op label);
void mkpoint(op dat, op label);
void mkarray(op mem, void* string);
void mknull();
void mkmem(op mem, thing targ, int regs, int writeback);

/* from armgraphextra.c (extra functions used by the parser) */
void makeops();
void intersplod(operator oper, operator cond, op* op);
void init();
op* lookiau(char* wantedName);
int findlabel(char* name);
label* lookuplabel(char* name);
label* lookuplabel2(char* name, label* lab);
label* addlabel(char* name, int loc, nodeType* node);

/* from graphfix.c (Flowgraph generation and analysis) */
void labelfixer();
void defragment();
void addpred(label* lab, nodeType* node);
void readproc(label* el);
void readvar(label* lab);
void firstintervalise(nodeType* node, nodeType* interval);
nodeType* newinterval(nodeType* node, nodeType* interval);
void intervalise(nodeType* node, nodeType* interval);
void addsucc(nodeType *succnode, intNodeType *interval);
void addcondsucc(nodeType *succnode, intNodeType *interval, char cond);
void addapred(nodeType *prednode, intNodeType *interval);
void addpreds(nodelist *srcpreds, intNodeType *interval);
int loopmark(nodeType* node);
void loopmarksuper(nodeType* node);
void looptype(nodeType* node);
void loopfollow(nodeType* node);
void condstruct(nodeType* node, dominator* dom);

/* from graphc.c (code generation) */
void codegen(nodeType* noddy, nodeType* dom, nodeType* interval);
treeType* domonad(thing* src);
treeType* dodyad(thing* src1, thing* src2, char oper);
int findtype(nodeType* node, int display);
char revcond(char op);
treeType* express(uno* unas);
void desplunge(int regmask);
void condgen(condlist* conds, char cond);
void condpair(treeType* node, char cond);
void traverse(treeType* tree);
