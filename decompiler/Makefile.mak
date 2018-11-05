#!/bin/make

all: armc

lex.yy.c: armgraph.l
	flex armgraph.l

armgraph.c: armgraph.y
	bison -d armgraph.y

armgraph.tab.o: armgraph.tab.c armgraph.h armgraph.tab.h armgraph.y

armgraphextra.o: armgraphextra.c armgraph.h

graphfix.o: graphfix.c 

graphc.o: graphc.c 

lex.yy.o: lex.yy.c armgraph.h armgraph.tab.h

.c.o: gcc -c

armc: armgraph.tab.o armgraphextra.o graphfix.o graphc.o lex.yy.o
	gcc armgraph.tab.o armgraphextra.o graphfix.o graphc.o lex.yy.o -lfl -lm -lefence -o armc
