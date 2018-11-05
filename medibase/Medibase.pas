PROGRAM Medical (INPUT, OUTPUT, medifile);

{OI!  Get out of my source!}

USES MOUSE, GRAPH, CRT, DOS, PRINTER;


CONST
     MaxLen=30;
     PassConst='bakewell';        {Password}

TYPE
    FileRec     =       Record  Formulation     :       STRING;     {Structure for records on disc}
                                Name            :       STRING;
                                Quantity            :       INTEGER;
                                Manufacturer    :       STRING;
                                Lot_Number      :       STRING;
                                Expire          :       RECORD  Year    :       WORD;
                                                                Month   :       WORD;
                                                                Day     :       WORD;
                                                                END;
                                Free            :       STRING;
                                END;

    ListRec     =       Record  Formulation     :       STRING;     {Structure for records in memory}
                                Name            :       STRING;
                                Quantity            :       INTEGER;
                                Manufacturer    :       STRING;
                                Lot_Number      :       STRING;
                                Expire          :       RECORD  Year    :       WORD;
                                                                Month   :       WORD;
                                                                Day     :       WORD;
                                                                END;
                                Free            :       STRING;
                                Pointer         :       INTEGER;
                                END;



VAR
	Graphdriver  :       integer;
   	Graphmode    :       integer;
   	MaxX, MaxY   :       Word;
   	Errorcode    :       Integer;
   	MaxColor     :       Word;
        year,month,day:      WORD;
        mstatus      : locrec;
        i            : INTEGER;
        Options      : ARRAY [1..10] OF STRING;
        medifile     : FILE of FileRec;
        List         : ARRAY [1..maxlen] OF ListRec;
    loop	:	INTEGER;
    Temp	:	FileRec;
    FrePtr,StartPtr	:	INTEGER;
    Found           :       INTEGER;
    Lst             :       TEXT;
   Located      :       Boolean;
   Prev         :       Integer;

PROCEDURE Option; {Null procedure: Used to test menubar}

BEGIN
     GOTOXY(1,10);
     WriteLN('Not implemented yet');
     END;

PROCEDURE InitMouse; {Initialise mouse}
        VAR
             mreport : resetrec;

        BEGIN
             MRESET(mreport);
             IF (mreport.exists=FALSE) THEN
             BEGIN
                WRITELN ('Pointing Device not connected');
                HALT(1);
             END;
             MSHOW;
             MMOVETO(40,12);
        END;

Procedure Initialise; {Initialise graphics}
Var
   PathToDriver : String;

Begin
     Graphdriver := detect;
     InitGraph(Graphdriver, GraphMode, PathToDriver);
     ErrorCode := Graphresult;
     If ErrorCode <>grOK then Halt(1);
     MaxColor := GetMaxColor;
     MaxX := GetMaxX+1;
     MaxY := GetMaxY+1;
End;

PROCEDURE InitOptions; {Initialise options for menubar}
        BEGIN
           Options[1] := 'Dispense';
           Options[2] := 'Remove  ';
           Options[3] := 'Search  ';
           Options[4] := 'Add     ';
           Options[5] := 'Display ';
           Options[6] := 'Print   ';
           Options[7] := 'Check   ';
           Options[8] := 'NULL    ';
           Options[9] := 'NULL    ';
           Options[10] := 'Quit    ';
        END;

FUNCTION Stringy(I : LONGINT): STRING; {Turns a numerical value into a string}

VAR
   S    :       STRING;

BEGIN
     Str(I,S);
     Stringy:=S;
END;

PROCEDURE PutText(x,y : INTEGER; letter : STRING; col : WORD); {Interesting text effect}

VAR
   loop :       INTEGER;

BEGIN
     FOR loop:=1 to 8 DO BEGIN
         SetColor(col+loop);
         OutTextXY(x,y,letter);
         Delay(100);
     END;
END;

PROCEDURE Alarm; {Designed to attract attention if someone enters the wrong password.}

VAR
	pitch	:	WORD;


{Burglars beware!}


BEGIN
	setgraphmode(graphmode);
	pitch:=0;
    REPEAT
    OutTextXY(210,205,'INTRUDER ALERT!');
	REPEAT
    	Sound (pitch*100);
        SetBkColor (pitch);
        DELAY (100);
        pitch:=pitch+1;
    UNTIL pitch=MaxColor;
    CLEARDEVICE;
    OutTextXY(210,205,'ACCESS VIOLATION!');
    REPEAT
    	Sound (pitch*100);
        SetBkColor (pitch);
        DELAY (200);
        pitch:=pitch-1;
    UNTIL pitch=0;
    CLEARDEVICE;
    UNTIL keypressed;
    NoSound;
END;

PROCEDURE DispRec(ShRec:ListRec); {Display a record}
BEGIN
        ClrScr;
        With ShRec DO BEGIN
	WriteLN('Formulation:      ',Formulation);
        WriteLN('Name:             ',Name);
        WriteLN('Quantity:         ',Quantity);
        WriteLN('Manufacturer:     ',Manufacturer);
        WriteLN('Lot Number:       ',Lot_Number);
        WriteLN('Expiry date:      ',Expire.Day,'-',Expire.Month,'-',Expire.Year);
        WriteLN('Additional notes: ',Free);
    END;
END;

PROCEDURE PrOutRec(ShRec:ListRec); {Display a record}
BEGIN
    	WriteLN(Lst,'Formulation:      ',ShRec.Formulation);
	WriteLN(Lst,'Name:             ',ShRec.Name);
        WriteLN(Lst,'Quantity:         ',ShRec.Quantity);
        WriteLN(Lst,'Manufacturer:     ',ShRec.Manufacturer);
        WriteLN(Lst,'Lot Number:       ',ShRec.Lot_Number);
        WriteLN(Lst,'Expiry date:      ',ShRec.Expire.Day,'-',SHREC.Expire.Month,'-',SHREC.Expire.Year);
        WriteLN(Lst,'Additional notes: ',ShRec.Free);
        ReadLN;
END;

Procedure ShowBar; {Displays the buttonbar}

VAR
              opt : INTEGER;

BEGIN
		ClrScr;
             TEXTBACKGROUND (Blue);
             FOR opt :=1 TO 10 DO BEGIN
                 GOTOXY((opt-1)*8+1,1);
                 TEXTCOLOR(Yellow);
                 WRITE (Options[opt]);
                 GOTOXY((opt-1)*8+1,1);
                 TEXTCOLOR(Red);
                 WRITE(Options[opt][1]);
             END;
END;

Procedure QuitBase; {Re-enters records into database file on shutdown}

BEGIN
     Rewrite (medifile);
     loop:=StartPtr;
     Repeat
     Temp.Formulation:=List[loop].Formulation;       {Write record from list into temporary record}
     Temp.Name:=List[loop].Name;
     Temp.Quantity:=List[loop].Quantity;
     Temp.Manufacturer:=List[loop].Manufacturer;
     Temp.Lot_Number:=List[loop].Lot_Number;
     Temp.Expire.Year:=List[loop].Expire.Year;
     Temp.Expire.Month:=List[loop].Expire.Month;
     Temp.Expire.Day:=List[loop].Expire.Day;
     Temp.Free:=List[loop].Free;
     Write (Medifile,Temp);                   {Write temporary record to file on disc}
     loop:=List[loop].Pointer;
     Until loop=0;
END;

PROCEDURE Check; {Startup checks- Expiry, quantity}

VAR
   Ptr  :       Integer;

BEGIN
     Ptr:=StartPtr;
    REPEAT
    	IF List[Ptr].Quantity<1 THEN BEGIN       {If the surgery is out of  the drug, produce an alarm}
                                     WriteLN('You are out of ',List[Ptr].Name);
                                     WriteLN('Press any key to continue.');
                                     WriteLN('Remove the record to prevent this warning from appearing again');
                                     REPEAT
                                           Sound(220);
                                           Delay(10);
                                           Sound(180);
                                           Delay(10);
                                     UNTIL KeyPressed;
                                     END;
        IF (List[Ptr].Expire.Year<year) OR ((List[Ptr].Expire.Year=year) AND (List[Ptr].Expire.Month<month))
        OR ((List[Ptr].Expire.Year=year) AND (List[Ptr].Expire.Month=month) AND (List[Ptr].Expire.Day<day)) THEN BEGIN
                                       WriteLN(List[Ptr].Name,'Has expired');     {If it has expired, produce an alarm.}
                                       WriteLN('Press any key to continue.');
                                       WriteLN('Remove the record to prevent this warning from appearing again');
                                       REPEAT
                                             Sound(220);
                                             Delay(10);
                                             Sound(180);
                                             Delay(10);
                                       UNTIL KeyPressed;
                                       END;
        Ptr:=List[Ptr].Pointer;
    UNTIL Ptr=0;
     Showbar {Display button bar};
END;

PROCEDURE Search; {Find a record}

VAR
   SearchName   :       String;
   Select       :       Boolean;
   Choice       :       Char;

BEGIN
     Found:=StartPtr;
     Located:=FALSE;
     WriteLN('Please enter the name of the drug you wish to find');
     ReadLN(SearchName);
     REPEAT
           WHILE (List[Found].Name<>SearchName) AND (Found<>0) DO BEGIN
                 Prev:=Found;
                 Found:=List[Found].Pointer;
                 END;
           IF List[Found].Name=SearchName THEN BEGIN
                                                    Located:=TRUE;
                                                    DispRec(List[Found]);
                                                    WriteLN('Is this the record you want?');
                                                    Choice:=ReadKey;
                                                    If (Choice='Y') OR (Choice='y') THEN Select:=TRUE;
                                                    END
                                          ELSE WriteLN ('Not Found.');
           UNTIL (Select=TRUE) OR (Found=0);
     Showbar {Display button bar};
END;

PROCEDURE PrOut; {Print records}

VAR
   AllOr1       :       Char;
   Ptr          :       Integer;

BEGIN
     WriteLN('Do you wish to print one record or all of them?');
     WriteLN('Please type "1" for  one record and "A" for all of them.');
     AllOr1:=ReadKey;
     If AllOr1='1' THEN BEGIN
                           Search;
                           IF Located=TRUE THEN PrOutRec (List[found]);
                           END
                 ELSE BEGIN
                           Ptr:=StartPtr;
                           REPEAT
    	                         PrOutRec (List[Ptr]);
                                 Ptr:=List[Ptr].Pointer;
                           UNTIL Ptr=0;
                           END;
     Showbar {Display button bar};
END;

PROCEDURE Display; {Display all records}

VAR
	Ptr	:	INTEGER;

BEGIN
	Ptr:=StartPtr;           {Go to start of list}
    REPEAT
    	DispRec (List[Ptr]);          {Display record}
        Ptr:=List[Ptr].Pointer;       {Go to next record}
        WriteLN ('Please press Enter');
        ReadLN;                       {Wait for user}
    UNTIL Ptr=0;
    Showbar {Display button bar};
END;

PROCEDURE Add; {Add a record}

Var
	Ptr1, Ptr2, PtrT	:	INTEGER;

BEGIN
	IF FrePtr=0 	THEN BEGIN                {Checks to see whether there is a free list.}
						GOTOXY(1,10);
						WriteLN('Sorry! File full.');
                        END
			ELSE BEGIN
                        WriteLN('Please enter the formulation');
                		ReadLN(List[FrePtr].Formulation);
                        WriteLN('Please enter the name of the drug');
           				ReadLN(List[FrePtr].Name);
                        WriteLN('Please enter the Quantity');
           				ReadLN(List[FrePtr].Quantity);
                                        WHILE List[FrePtr].Quantity<1 DO BEGIN
                                              WriteLN ('This cannot be correct.  Please retype.');
                                              ReadLN(List[FrePtr].Quantity);
                                              END; {Quantity cannot be<1}
                        WriteLN('Please enter the manufacturer');
           				ReadLN(List[FrePtr].Manufacturer);
                        WriteLN('Please enter the lot number');
           				ReadLN(List[FrePtr].Lot_Number);
                        WriteLN('Please enter the Expiry date');
                        WriteLN('Year (4-digit)');
           				ReadLN(List[FrePtr].Expire.Year);
                        While List[FrePtr].Expire.Year<Year DO BEGIN
                        		WriteLN('This cannot be correct.  Please retype.');
								ReadLN(List[FrePtr].Expire.Year);
                                END;          {Date cannot be<today's date}
                        WriteLN('Month');
           				ReadLN(List[FrePtr].Expire.Month);
                        While ((List[FrePtr].Expire.Year=Year) AND (List[FrePtr].Expire.Month<Month))
						OR (List[FrePtr].Expire.Month>12) DO BEGIN
                        		WriteLN('This cannot be correct.  Please retype.');
								ReadLN(List[FrePtr].Expire.Month);
                                END;          {Date cannot be<today's date and Month cannot be>12}
                        WriteLN('Day');
           				ReadLN(List[FrePtr].Expire.Day);
                        While ((List[FrePtr].Expire.Year=Year) AND (List[FrePtr].Expire.Month=Month)
						AND (List[FrePtr].Expire.Day<Day)) OR (List[FrePtr].Expire.Day>31) DO BEGIN
                        		WriteLN('This cannot be correct.  Please retype.');    {Date cannot be<today's and Day cannot be>31}
								ReadLN(List[FrePtr].Expire.Day);
                                END;
                        WriteLN('Please add any free text. (Only press Enter at the end.)');
           				ReadLN(List[FrePtr].Free);
                        Ptr2:=StartPtr;
                        	If StartPtr=0 THEN StartPtr:=FrePtr
                        					ELSE While Ptr2<>0 DO BEGIN
							Ptr1:=Ptr2;
                            Ptr2:=List[Ptr1].Pointer;
                        END;
                        List[Ptr1].Pointer:=FrePtr;
                        PtrT:=List[FrePtr].Pointer;
                        List[FrePtr].Pointer:=0;
                        FrePtr:=PtrT;
                        Showbar {Display button bar};
                    END;
END;


PROCEDURE Remove; {Delete a record}

BEGIN
     Search;
     IF Located=TRUE THEN BEGIN
                               List[Prev].Pointer:=List[Found].Pointer; {Change pointers to skip record}
                               List[Found].Pointer:=FrePtr;
                               FrePtr:=Found;     {Change pointers to add record to free list}
                          END;
     Showbar {Display button bar};
END;

PROCEDURE Dispense; {Dispense a drug-  Deduct 1 from quantity}

BEGIN
     Search;
     IF Located=TRUE THEN BEGIN
                               Dec(List[Found].Quantity);
                               WriteLN('Don`t forget to record it!')
                          END;
     Showbar {Display button bar};
END;

PROCEDURE MenuBar; {Menubar procedure, courtesy of SSFC}
        VAR
              xpos, ypos : INTEGER;

        BEGIN
             Showbar {Display button bar};
             REPEAT
                MPOS(mstatus);
                IF (mstatus.buttonstatus=1) THEN
                   BEGIN
                      xpos := mstatus.column;
                      ypos := mstatus.row;
                      IF (ypos>=0) AND (ypos<8) THEN BEGIN			{Different options when mouse is clicked on different places}
                         IF (xpos>0) AND (xpos<64) THEN Dispense;
                         IF (xpos>63) AND (xpos<128) THEN Remove;
                         IF (xpos>127) AND (xpos<192) THEN Search;
                         IF (xpos>191) AND (xpos<256) THEN Add;
                         IF (xpos>255) AND (xpos<320) THEN Display;
                         IF (xpos>319) AND (xpos<384) THEN PrOut;
                         IF (xpos>383) AND (xpos<448) THEN Check;
                         IF (xpos>447) AND (xpos<512) THEN Option;
                         IF (xpos>511) AND (xpos<576) THEN Option;
                         IF (xpos>575) AND (xpos<640) THEN QuitBase;
                      END;
                   END;
             UNTIL (xpos>575) AND (xpos<640);

        END;


PROCEDURE GetPass; {Asks for password.  Triggers alarm if >3 failures.}

VAR
	Password	:	STRING;
        Tries           :       INTEGER;

BEGIN
	RestoreCRTMode;
        Tries:=0;
        REPEAT
	      WRITE ('Please enter password >>> ');
	      READLN (Password);
              Tries:=Tries+1;
        UNTIL (Password=PassConst) OR (Tries>3);
    IF Password<>PassConst THEN Alarm
                          ELSE BEGIN
                               WriteLN ('Access permitted');
                               InitMouse;     {Initialise mouse}
                               InitOptions;   {Initialise buttonbar options}
                               Check;         {Check database for out of date/stock records}
                               MenuBar;       {Start buttonbar}
                          END;
END;

PROCEDURE LoadFile; {Loads records from file into linked list}

BEGIN
	For loop:=1 TO 29 DO List[loop].Pointer:=loop+1;
    List[30].Pointer:=0;
    RESET (medifile);
    loop:=0;
    StartPtr:=0;
    FrePtr:=1;
    WHILE (NOT EOF(medifile)) DO BEGIN
           READ (medifile, Temp); {Put record from file into temporary record}
           StartPtr:=1;
           loop:=loop+1;          {Put temporary record into list}
           List[loop].Formulation:=Temp.Formulation;
           List[loop].Name:=Temp.Name;
           List[loop].Quantity:=Temp.Quantity;
           List[loop].Manufacturer:=Temp.Manufacturer;
           List[loop].Lot_Number:=Temp.Lot_Number;
           List[loop].Expire.Year:=Temp.Expire.Year;
           List[loop].Expire.Month:=Temp.Expire.Month;
           List[loop].Expire.Day:=Temp.Expire.Day;
           List[loop].Free:=Temp.Free;
    END;
    List[loop].Pointer:=0;
    FrePtr:=loop+1;    {Set free pointer to first free space}
END;


PROCEDURE Startup; {Nice startup sequence.}

VAR
   week :       WORD;

BEGIN
     PutText(210,205,'Crokulex Developments presents:',2);
     Delay (1000);
     PutText(210,220,'M',3);
     Delay (100);
     PutText(220,220,'E',3);
     Delay (100);
     PutText(230,220,'D',3);
     Delay (100);
     PutText(240,220,'I',3);
     Delay (100);
     PutText(250,220,'Base',1);
     Delay (1000);
     GetDate(year, month,day,week);
     PutText(210,250,Stringy(day),4);
     PutText(230,250,'-',5);
     PutText(250,250,Stringy(month),4);
     PutText(270,250,'-',5);
     PutText(290,250,Stringy(year),4);
     Delay (5000);
END;

{This is the main program.  You've seen the procedures, which are the best bits.}

BEGIN
     ASSIGN (medifile, 'C:\medifile.dat');
     Initialise;          {Initialise graphics}
     LoadFile;            {Load records into linked list}
     Startup;             {Display startup screen}
     GetPass;             {Get password}
END.