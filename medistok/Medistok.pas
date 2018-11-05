PROGRAM MediStock (INPUT, OUTPUT, batches, drugs, admin, bindex, dindex);

{$M 8132, 0, 64000}

USES Graph, Mouse, CRT, DOS, Printer;

TYPE
  date = RECORD
    day         :       BYTE;
    month       :       BYTE;
    year        :       WORD;
  END;

  batchfile = RECORD
    drug_code   :       STRING;
    lot_number  :       STRING;
    quantity    :       BYTE;
    exp_date    :       DATE;
    location    :       CHAR;
  END;

  drugfile = RECORD
    drug_code   :       STRING;
    name        :       STRING;
    manufacturer:       STRING;
    free_text   :       STRING;
    vaccine     :       BOOLEAN;
    recall_time :       DATE;
  END;

  adminfile = RECORD
    NHS_num     :       STRING;
    drug_code   :       STRING;
    lot_number  :       STRING;
    admin_date  :       DATE;
    vaccine     :       BOOLEAN;
    recall_date :       DATE;
  END;

  indarray = RECORD
    data        :       ARRAY[1..100,1..2] OF INTEGER;
    start,free  :       BYTE;
  END;

  indfile = FILE OF INTEGER;

  passarray = array[1..10] OF STRING;

CONST
  line_height=10;  {Height of text line}
  centre=320;      {Centre of screen}
  y_offset=190;    {y co-ordinate of top of box}
  errwidth=130;    {width of error box/2}
  questwidth=180;  {width of question box/2}
  boxwidth=230;    {width of display box/2}
  intext_offset=200;   {offset of text being input}
  column_width=8;  {width of character}
  path='A:\';      {Path of program}
  pass='fayzer';   {password}
  text_depth=25;   {Distance of first text line below box top}

VAR
  optionsb     :        ARRAY [1..11] OF STRING;        {Options arrays for buttonbars}
  selcharb     :        ARRAY [1..11] OF INTEGER;
  optionsd     :        ARRAY [1..4] OF STRING;
  selchard     :        ARRAY [1..4] OF INTEGER;
  optionsa     :        ARRAY [1..4] OF STRING;
  selchara     :        ARRAY [1..4] OF INTEGER;
  mstatus      :        locrec;                         {location of mouse}
  graphdriver  :        INTEGER;                        {details from graphics unit}
  graphmode    :        INTEGER;
  pathtodriver :        STRING;
  errorcode    :        INTEGER;
  batches      :        FILE of batchfile;              {Files}
  drugs        :        FILE of drugfile;
  admin        :        FILE of adminfile;
  bindexfile   :        indfile;
  dindexfile   :        indfile;
  bindex       :        indarray;                       {Index files}
  dindex       :        indarray;
  today        :        date;                           {Today's date}
  bugnum       :        INTEGER;                        {Used for debugging}

FUNCTION FIdentDrug(searchdrug:STRING):STRING;          {Finds a drug code given name}

VAR
  count        :       INTEGER;
  temprec      :       drugfile;

BEGIN
  RESET (drugs);
  count:=dindex.start;
  temprec.name:='NULL';
  WHILE (count>0) AND (temprec.name<>searchdrug) DO BEGIN
    SEEK (drugs,dindex.data[count,1]-1);
    READ (drugs,temprec);
    bugnum:=count;
    count:=dindex.data[count,2];
  END;
  IF temprec.name<>searchdrug THEN FIdentDrug:='FAILED!' ELSE FIdentDrug:=temprec.drug_code;
END;

FUNCTION FFindDrug(searchcode:STRING):STRING;                   {Finds drug name given code}

VAR
  count        :       INTEGER;
  temprec      :       drugfile;

BEGIN
  RESET(drugs);
  count:=dindex.start;
  temprec.drug_code:='NULL';
  WHILE (count>0) AND (temprec.drug_code<>searchcode) DO BEGIN
    SEEK (drugs,dindex.data[count,1]-1);
    READ (drugs,temprec);
    bugnum:=count;
    count:=dindex.data[count,2];
  END;
  IF temprec.drug_code<>searchcode THEN FFindDrug:='FAILED!' ELSE FFindDrug:=temprec.name;
END;

Procedure SSPInitgraph;         {Initialises graphics}

BEGIN
  graphdriver:=detect;
  Initgraph(graphdriver, graphMode, PathToDriver);
  ErrorCode:=graphresult;
  IF ErrorCode <>grOK THEN Halt(1);
END;

PROCEDURE SSPInitFiles;                {Initialises files}

VAR
  count        :       INTEGER;

BEGIN
  ASSIGN(batches, path+'batches.med');
  ASSIGN(drugs, path+'drugs.med');
  ASSIGN(admin, path+'admin.med');
  ASSIGN(bindexfile,path+'batches.ind');
  ASSIGN(dindexfile,path+'drugs.ind');
  FOR count:=1 to 99 DO BEGIN
    bindex.data[count,1]:=0;
    bindex.data[count,2]:=count+1;
  END;
  bindex.data[100,1]:=0;
  RESET (bindexfile);
  count:=0;
  WHILE NOT EOF(bindexfile) DO BEGIN
    count:=count+1;
    READ(bindexfile,bindex.data[count,1]);
  END;
  CASE count OF
    0 : BEGIN
      bindex.start:=0;
      bindex.free:=1;
    END;
    100 : BEGIN;
      bindex.start:=1;
      bindex.free:=0;
      bindex.data[count,2]:=0;
    END;
    ELSE BEGIN
      bindex.Start:=1;
      bindex.data[count,2]:=0;
      bindex.free:=count+1;
    END;
  END;
  FOR count:=1 to 99 DO BEGIN
    dindex.data[count,1]:=0;
    dindex.data[count,2]:=count+1;
  END;
  dindex.data[100,1]:=0;
  RESET (dindexfile);
  count:=0;
  WHILE NOT EOF(dindexfile) DO BEGIN
    count:=count+1;
    READ(dindexfile,dindex.data[count,1]);
  END;
  CASE count OF
    0 : BEGIN
      dindex.start:=0;
      dindex.free:=1;
    END;
    100 : BEGIN;
      dindex.start:=1;
      dindex.free:=0;
      dindex.data[count,2]:=0;
    END;
    ELSE BEGIN
      dindex.Start:=1;
      dindex.data[count,2]:=0;
      dindex.free:=count+1;
    END;
  END;
END;

PROCEDURE SSPInitMouse;         {Initialises mouse}

VAR
  mreport       :       RESETREC;

BEGIN
  MRESET(mreport);
  IF (mreport.exists=FALSE) THEN WRITELN ('Pointing Device not connected');
  MSHOW;
  MMOVETO(40,12);
END;

PROCEDURE SSPInitOptions;       {Initialises menu bars}

VAR
  loop          :       INTEGER;

BEGIN
  optionsb[1]:='Record';        {Options for menu bars}
  optionsb[2]:='Add';
  optionsb[3]:='Delete';
  optionsb[4]:='Find';
  optionsb[5]:='List';
  optionsb[6]:='Print';
  optionsb[7]:='Backup';
  optionsb[8]:='Check';
  optionsb[9]:='Drugs';
  optionsb[10]:='Admin';
  optionsb[11]:='Quit';
  optionsd[1]:='Add';
  optionsd[2]:='Delete';
  optionsd[3]:='Find';
  optionsd[4]:='Return';
  optionsa[1]:='Find';
  optionsa[2]:='List';
  optionsa[3]:='Print';
  optionsa[4]:='Return';
  selcharb[1]:=1;               {Position of hilighted letter for each option}
  selcharb[2]:=1;               {This allows greater flexibility and less scope}
  selcharb[3]:=1;               {for error than referring to the letters}
  selcharb[4]:=1;               {directly from the menubar procedures}
  selcharb[5]:=1;
  selcharb[6]:=1;
  selcharb[7]:=1;
  selcharb[8]:=1;
  selcharb[9]:=3;
  selcharb[10]:=3;
  selcharb[11]:=1;
  selchard[1]:=1;
  selchard[2]:=1;
  selchard[3]:=1;
  selchard[4]:=1;
  selchara[1]:=1;
  selchara[2]:=1;
  selchara[3]:=1;
  selchara[4]:=1;
END;

Procedure SSPShowBBar;  {Displays the Batches buttonbar}

VAR
  opt           :       INTEGER;

BEGIN
  MHIDE;
  CLEARDEVICE;
  SETBKCOLOR(blue);
  SETCOLOR (Cyan);
  RECTANGLE (0,0,639,10);
  SETFILLSTYLE (1,Cyan);
  FLOODFILL (320,8,Cyan);
  FOR opt :=1 TO 11 DO BEGIN
    SETCOLOR(Yellow);
    OUTTEXTXY ((opt-1)*58,2,optionsb[opt]);
    SETCOLOR(Red);
    OUTTEXTXY ((opt-1)*58+((selcharb[opt]-1)*column_width),2,optionsb[opt][selcharb[opt]]);
  END;
  MSHOW;
END;

Procedure SSPShowDBar;  {Displays the Drugs buttonbar}

VAR
  opt           :       INTEGER;

BEGIN
  MHIDE;
  CLEARDEVICE;
  SETBKCOLOR(blue);
  SETCOLOR (Cyan);
  RECTANGLE (0,0,639,10);
  SETFILLSTYLE (1,Cyan);
  FLOODFILL (320,8,Cyan);
  FOR opt :=1 TO 4 DO BEGIN
    SETCOLOR(Yellow);
    OUTTEXTXY (2+(opt-1)*160,2,optionsd[opt]);
    SETCOLOR(Red);
    OUTTEXTXY (2+(opt-1)*160+((selchard[opt]-1)*column_width),2,optionsd[opt][selchard[opt]]);
  END;
  MSHOW;
END;

Procedure SSPShowABar;  {Displays the Admin buttonbar}

VAR
  opt           :       INTEGER;

BEGIN
  MHIDE;
  CLEARDEVICE;
  SETBKCOLOR(blue);
  SETCOLOR (Cyan);
  RECTANGLE (0,0,639,10);
  SETFILLSTYLE (1,Cyan);
  FLOODFILL (320,8,Cyan);
  FOR opt :=1 TO 4 DO BEGIN
    SETCOLOR(Yellow);
    OUTTEXTXY (2+(opt-1)*160,2,optionsa[opt]);
    SETCOLOR(Red);
    OUTTEXTXY (2+(opt-1)*160+((selchara[opt]-1)*column_width),2,optionsa[opt][selchara[opt]]);
  END;
  MSHOW;
END;

Procedure SSSPGetText(pos:INTEGER; VAR texline:STRING);         {Inputs a line of text}

VAR
  letter       :       CHAR;
  count        :       INTEGER;

BEGIN
  letter:=chr(0);
  count:=1;
  SETCOLOR(10);
  texline :='';
  WHILE letter<>chr(13) DO BEGIN
    letter:=READKEY;
    IF letter<>chr(13) THEN texline:=CONCAT(texline,letter);
    IF letter=chr(8) THEN BEGIN
      IF (count>1) THEN BEGIN
        SETCOLOR(cyan);
        OUTTEXTXY(intext_offset+column_width*(count-1),y_offset+text_depth+(pos)*10,CHR(219));
        SETCOLOR(10);
        DEC(count);
        DEC(texline[0]);
      END;
      DEC(texline[0]);
    END ELSE IF ord(letter) > 31 THEN BEGIN
      count:=count+1;
      OUTTEXTXY(intext_offset+column_width*(count-1),y_offset+text_depth+(pos)*10,letter);
    END;
  END;
END;

PROCEDURE SSSPGetDate(pos:INTEGER; VAR dateline:DATE);          {Inputs a date}

VAR
  letter       :       CHAR;
  texline      :       STRING;
  count        :       INTEGER;
  code         :       INTEGER;
  accept       :       BOOLEAN;

BEGIN
  letter:=chr(0);
  SETCOLOR(2);
  OUTTEXTXY(intext_offset+column_width,y_offset+text_depth+(pos)*10,'  -  -');
  texline :='';
  accept:=false;
  REPEAT
    SETCOLOR(10);
    FOR count:=1 TO 2 DO BEGIN
      letter:=READKey;
      texline:=CONCAT(texline,letter);
      OUTTEXTXY(intext_offset+column_width*count,y_offset+text_depth+pos*10,letter);
    END;
    VAL(texline,dateline.day,code);
    IF (dateline.day>31) OR (dateline.day<1) THEN BEGIN
      SETCOLOR(red);
      OUTTEXTXY(intext_offset+column_width*11,y_offset+text_depth+pos*10,'Please re-enter day');
      SETCOLOR(cyan);
      SOUND(200);
      DELAY(100);
      NOSOUND;
      OUTTEXTXY(intext_offset+column_width,y_offset+text_depth+pos*10,'лл');
    END ELSE accept:=true;
    texline :='';
  UNTIL accept;
  SETCOLOR(cyan);
  FOR count:=1 TO 20 DO OUTTEXTXY(intext_offset+(count+10)*column_width,y_offset+text_depth+pos*10,'л');
  accept:=FALSE;
  REPEAT
    SETCOLOR(10);
    FOR count:=1 TO 2 DO BEGIN
      letter:=READKey;
      texline:=CONCAT(texline,letter);
      OUTTEXTXY(intext_offset+column_width*(count+3),y_offset+text_depth+(pos)*10,letter);
    END;
    VAL(texline,dateline.month,code);
    IF (dateline.month>12) OR (dateline.month<1) THEN BEGIN
      SETCOLOR(red);
      OUTTEXTXY(intext_offset+column_width*11,y_offset+text_depth+pos*10,'Please re-enter month');
      SETCOLOR(cyan);
      SOUND(200);
      DELAY(100);
      NOSOUND;
      OUTTEXTXY(intext_offset+column_width*4, y_offset+text_depth+pos*10, 'лл');
    END ELSE accept:=true;
    texline :='';
  UNTIL accept;
  SETCOLOR(cyan);
  FOR count:=1 TO 22 DO OUTTEXTXY(intext_offset+(count+10)*column_width,y_offset+text_depth+pos*10,'л');
  accept:=FALSE;
  REPEAT
    SETCOLOR(10);
    FOR count:=1 TO 4 DO BEGIN
      letter:=READKEY;
      texline:=CONCAT(texline,letter);
      OUTTEXTXY(intext_offset+column_width*(count+6),y_offset+text_depth+(pos)*10,letter);
    END;
    VAL(texline,dateline.year,code);
    IF dateline.year<today.year THEN BEGIN
      SETCOLOR(red);
      OUTTEXTXY(intext_offset+column_width*11,y_offset+text_depth+pos*10,'Please re-enter year');
      SETCOLOR(cyan);
      SOUND(200);
      DELAY(100);
      NOSOUND;
      OUTTEXTXY(intext_offset+column_width*7,y_offset+text_depth+pos*10, 'лллл');
    END ELSE accept:=true;
    texline :='';
  UNTIL accept;
  SETCOLOR(cyan);
  FOR count:=1 TO 21 DO OUTTEXTXY(intext_offset+(count+10)*column_width,y_offset+text_depth+pos*10,'л');
END;


Procedure SSSPGetBool(VAR boolline:BOOLEAN);    {Gets a BOOLEAN variable}

VAR
  letter        :       CHAR;

BEGIN
  letter:=READKEY;
  IF UpCase(letter)='Y' THEN boolline:=TRUE ELSE boolline:=FALSE;
END;

Procedure SSSPError(Heading,text: STRING);      {Error message}

VAR
  temp          :       CHAR;

BEGIN
  MHIDE;
  SETCOLOR (Red);
  RECTANGLE (centre-errwidth,y_offset,centre+errwidth,250);
  SETFILLSTYLE (1,Cyan);
  FLOODFILL (centre-(errwidth-10),y_offset+line_height,Red);
  SETCOLOR (yellow);
  RECTANGLE (centre-(errwidth-10),y_offset+40,centre-95,245);
  SETFILLSTYLE (1,red);
  FLOODFILL (centre-(errwidth-20),y_offset+45,yellow);
  SETCOLOR (White);
  OUTTEXTXY (centre-(errwidth-10),y_offset+line_height,Heading);
  OUTTEXTXY (centre-(errwidth-10),y_offset+line_height*2,text);
  OUTTEXTXY (centre-(errwidth-10),y_offset+line_height*3,'Press a key or click OK');
  SOUND (200);
  DELAY(1000);
  SETCOLOR (Yellow);
  OUTTEXTXY (centre-(errwidth-15),y_offset+45,'OK');
  NOSOUND;
  MSHOW;
  REPEAT
    MPOS(mstatus);
  UNTIL (keypressed) OR
  ((mstatus.buttonstatus=1) AND (y_offset+60>mstatus.row) AND (mstatus.row>y_offset+40)
  AND (centre-100>mstatus.column) AND (mstatus.column>centre-120));
  IF keypressed THEN temp:=READKEY;
END;

Procedure SSSPGetAns(Heading,text: STRING; VAR response : BOOLEAN);     {Gets a BOOLEAN variable from an error box}

VAR
  temp          :       CHAR;

BEGIN
  response:=FALSE;
  MHIDE;
  SETCOLOR (Red);
  RECTANGLE (centre-questwidth,y_offset,centre+questwidth,250);
  SETFILLSTYLE (1,Cyan);
  FLOODFILL (centre-(questwidth-10),y_offset+line_height,Red);
  SETCOLOR (yellow);
  RECTANGLE (centre-(questwidth-10),y_offset+40,centre-140,245);
  SETFILLSTYLE (1,red);
  FLOODFILL (centre-(questwidth-20),y_offset+45,yellow);
  RECTANGLE (centre-70,y_offset+40,centre-45,245);
  FLOODFILL (centre-65,y_offset+45,yellow);
  SETCOLOR (White);
  OUTTEXTXY (150,200,Heading);
  OUTTEXTXY (150,210,text);
  OUTTEXTXY (150,220,'Press a key or click a button to choose');
  SOUND (300);
  DELAY (1000);
  SETCOLOR (Yellow);
  OUTTEXTXY (155,235,'Yes');
  OUTTEXTXY (255,235,'No');
  NOSOUND;
  MSHOW;
  REPEAT
    MPOS(mstatus);
  UNTIL (keypressed) OR
  ((mstatus.buttonstatus=1) AND (250>mstatus.row) AND (mstatus.row>230) AND
  (170>mstatus.column) AND (mstatus.column>150)) OR
  ((mstatus.buttonstatus=1) AND (250>mstatus.row) AND (mstatus.row>230) AND
  (270>mstatus.column) AND (mstatus.column>250));
  IF keypressed THEN BEGIN
    temp:=READKEY;
    IF upcase(temp)='Y' THEN response:=TRUE;
  END;
  IF (mstatus.buttonstatus=1) AND (170>mstatus.column) AND
  (mstatus.column>150) THEN response:=true;
END;

Procedure SSSPDisplayBox(header : STRING; count: INTEGER; data : passarray);    {Displays a box containing data}

VAR
  loop          :       INTEGER;
  temp          :       CHAR;

BEGIN
  MHIDE;
  SETCOLOR (Red);
  RECTANGLE (centre-boxwidth,y_offset,centre+boxwidth,230+count*line_height);
  SETFILLSTYLE (1,Cyan);
  FLOODFILL (centre-(boxwidth-10),y_offset+10,Red);
  SETCOLOR(White);
  OUTTEXTXY (centre-(boxwidth-10),y_offset+10,Header);
  FOR loop:=1 TO count DO OUTTEXTXY(centre-(boxwidth-10),y_offset+text_depth+loop*10,data[loop]);
  MSHOW;
END;

PROCEDURE TNull(Opt:STRING);    {Test code for debugging}

BEGIN
  SSSPError ('Debugging test code- RED ALERT! PANIC!',Opt);
END;

Procedure SPTitle;      {Startup screen}

BEGIN
  SETCOLOR(9);
  SETTEXTSTYLE(9,0,4);
  OUTTEXTXY(200,200,'MediStock');
  SETTEXTSTYLE(0,0,1);
  OUTTEXTXY(200,300,'Press ENTER to continue');
  READLN;
END;

PROCEDURE SSPAlarm; {Designed to attract attention if someone enters the wrong password.}

VAR
  pitch	        :	WORD;

BEGIN
  pitch:=0;
  REPEAT
    OUTTEXTXY(210,205,'Wrong password!');
    REPEAT
      SOUND (pitch*100);
      SETBKCOLOR (pitch);
      DELAY (200);
      INC(pitch);
    UNTIL pitch=15;
    CLEARDEVICE;
    OUTTEXTXY(210,205,'Intruder alert!');
    REPEAT
      SOUND (pitch*200);
      SETBKCOLOR (pitch);
      DELAY (100);
      DEC(pitch);
    UNTIL pitch=0;
    CLEARDEVICE;
  UNTIL keypressed;
  NOSOUND;
  HALT;
END;

Procedure SPPass;       {Asks FOR password}

VAR
  password     :       STRING;
  count        :       INTEGER;
  letter       :       CHAR;
  loop         :       INTEGER;

BEGIN
  password:='';
  SETCOLOR(9);
  OUTTEXTXY(10,10,'Please enter the password.');
  count:=1;
  letter:='?';
  WHILE letter<>chr(13) DO BEGIN
    Repeat until keypressed;
    letter:=READKEY;
    IF letter<>chr(13) THEN password:=CONCAT(password,letter);
    IF letter=chr(8) THEN BEGIN
      IF (count>1) THEN BEGIN
        SETCOLOR(0);
        OUTTEXTXY(column_width*count,20,'*');
        SETCOLOR(9);
        count:=count-1;
        DEC(password[0]);
      END;
      DEC(password[0]);
    END ELSE BEGIN
      count:=count+1;
      OUTTEXTXY(column_width*count,20,'*');
    END;
  END;
  IF password<>pass THEN SSPAlarm;
END;

PROCEDURE OBCheck;      {Perform stock checks}

VAR
  temprecb      :       batchfile;
  Err           :       STRING;
  count         :       INTEGER;

BEGIN
  count:=bindex.start;
  WHILE count >0 DO BEGIN
    RESET (Batches);
    SEEK(Batches,count-1);
    READ(Batches,temprecB);
    IF (temprecB.exp_date.year<today.year)
    OR ((temprecB.exp_date.year=today.year) AND (temprecB.exp_date.month<today.month))
    OR ((temprecB.exp_date.year=today.year) AND (temprecB.exp_date.month=today.month)
    AND (temprecB.exp_date.day<today.day))
      THEN BEGIN
        Err:=CONCAT(FFindDrug(temprecB.drug_code),' expired');
        SSSPError ('Stock error!',err);
        CLEARDEVICE;
      END;
    IF temprecB.quantity<1 THEN BEGIN
      Err:=CONCAT('No more ',FFindDrug(temprecB.drug_code));
      SSSPError ('Stock error!',Err);
      CLEARDEVICE;
    END;
    count:=bindex.data[count,2];
  END;
END;

PROCEDURE PStartup;     {Startup procedure}

VAR
  day,month,null        :       WORD;

BEGIN
  SSPInitgraph;
  SSPInitMouse;
  SSPInitOptions;
  SSPInitFiles;
  SPTitle;
  CLEARDEVICE;
  SPPass;
  CLEARDEVICE;
  GetDate (today.year,month,day,null);
  today.month:=month;
  today.day:=day;
  OBCheck;
END;

PROCEDURE SPPrintBRec(Brec:BatchFile);  {Prints a record from the Batches file}

VAR
  Quantext,daytex,montex,yeatex,datex     :        STRING;
  temprec                                 :        Drugfile;
  count,prev                              :        INTEGER;

BEGIN
  CLEARDEVICE;
  WITH BRec DO BEGIN
    STR(quantity,quantext);
    STR(exp_date.day,daytex);
    STR(exp_date.month,montex);
    STR(exp_date.year,yeatex);
    datex:=CONCAT(daytex,'-',montex,'-',yeatex);
  END;
  count:=dindex.start;
  prev:=0;
  RESET(Drugs);
  WHILE (temprec.drug_code<>Brec.drug_code) and (count>0) DO BEGIN
    SEEK(Drugs,dindex.data[count,1]-1);
    READ(Drugs,temprec);
    IF temprec.drug_code<>BRec.drug_code THEN BEGIN
      prev:=count;
      count:=dindex.data[count,2]
    END;
  END;
  WRITELN(lst,'Name: ',temprec.name);
  WRITELN(lst,'Lot Number: ',BRec.lot_number);
  WRITELN(lst,'Manufacturer: ',temprec.manufacturer);
  WRITELN(lst,'Quantity: ', quantext);
  WRITELN(lst,'Expiry: ', datex);
  WRITELN(lst,'Notes: ',temprec.free_text);
  IF temprec.VACCINE THEN WRITELN(lst,'Vaccine: Yes') ELSE WRITELN(lst,'Vaccine: No');
  WRITELN(lst);
END;

PROCEDURE SPDispBRec(Brec:BatchFile);   {Displays a record from the batches file}

VAR
  Quantext,daytex,montex,yeatex,datex     :        STRING;
  temprec                                 :        Drugfile;
  count,prev                              :        INTEGER;
  data                                    :        passarray;
  temp                                    :        char;

BEGIN
  CLEARDEVICE;
  WITH BRec DO BEGIN
    STR(quantity,quantext);
    STR(exp_date.day,daytex);
    STR(exp_date.month,montex);
    STR(exp_date.year,yeatex);
    datex:=CONCAT(daytex,'-',montex,'-',yeatex);
  END;
  count:=dindex.start;
  prev:=0;
  RESET(Drugs);
  WHILE (temprec.drug_code<>Brec.drug_code) and (count>0) DO BEGIN
    SEEK(Drugs,dindex.data[count,1]-1);
    READ(Drugs,temprec);
    IF temprec.drug_code<>BRec.drug_code THEN BEGIN
      prev:=count;
      count:=dindex.data[count,2]
    END;
  END;
  CLEARDEVICE;
  data[1]:=CONCAT('Name: ',temprec.name);
  data[2]:=CONCAT('Lot Number: ',BRec.lot_number);
  data[3]:=CONCAT('Manufacturer: ',temprec.manufacturer);
  data[4]:=CONCAT('Quantity: ', quantext);
  data[5]:=CONCAT('Expiry: ', datex);
  data[6]:=CONCAT('Notes: ',temprec.free_text);
  IF temprec.VACCINE THEN data[7]:='Vaccine: Yes' ELSE data[7]:='Vaccine: No';
  SSSPDisplayBox('Record details',7, data);
  REPEAT
    MPOS(mstatus);
  UNTIL (keypressed) OR (mstatus.buttonstatus=1);
  IF keypressed THEN temp:=READKEY;
END;

PROCEDURE SPPrintDRec(Drec:DrugFile);   {Prints a record from the drugs file}

VAR
  Quantext,daytex,montex,yeatex,datex     :        STRING;
  count                                   :        INTEGER;

BEGIN
  CLEARDEVICE;
  WITH DRec DO BEGIN
    WRITELN(lst,'Code: ',drug_code);
    WRITELN(lst,'Name: ',name);
    WRITELN(lst,'Manufacturer: ',Manufacturer);
    WRITELN(lst,'Notes: ',free_text);
    IF vaccine THEN BEGIN
      WRITELN(lst,'Vaccine: Yes');
      STR(recall_time.day,daytex);
      STR(recall_time.month,montex);
      STR(recall_time.year,yeatex);
      WRITELN(lst,'Recall time: ',daytex,' days, ',montex,' months, ',yeatex,' years');
    END ELSE WRITELN(lst,'Vaccine: No');
  END;
END;

PROCEDURE SPDispDRec(Drec:DrugFile);    {Displays a record from the drugs file}

VAR
  Quantext,daytex,montex,yeatex,datex     :        STRING;
  data                                    :        PASSARRAY;
  count                                   :        INTEGER;
  temp                                    :        char;

BEGIN
  CLEARDEVICE;
  WITH DRec DO BEGIN
    data[1]:=CONCAT('Code: ',drug_code);
    data[2]:=CONCAT('Name: ',name);
    data[3]:=CONCAT('Manufacturer: ',manufacturer);
    data[4]:=CONCAT('Notes: ',free_text);
    data[5]:='Vaccine: No';
    count:=5;
    IF vaccine THEN BEGIN
      data[5]:='Vaccine: Yes';
      STR(recall_time.day,daytex);
      STR(recall_time.month,montex);
      STR(recall_time.year,yeatex);
      data[6]:=CONCAT('Recall time: ',daytex,' days, ',montex,' months, ',yeatex,' years');
      count:=6;
    END;
    SSSPDisplayBox('Record details',count, data);
  END;
  REPEAT
    MPOS(mstatus);
  UNTIL (keypressed) OR (mstatus.buttonstatus=1);
  IF keypressed THEN temp:=READKEY;
END;

PROCEDURE SPPrintARec(Arec:AdminFile);  {Prints a record from the Admin file}

VAR
  quantext,daytex,montex,yeatex,datex,name     :        STRING;

BEGIN
  name:=FFindDrug(Arec.drug_code);
  WRITELN(lst,'Name: ',name);
  WITH ARec DO BEGIN
    WRITELN(lst,'NHS Number: ',NHS_num);
    STR(admin_date.day,daytex);
    STR(admin_date.month,montex);
    STR(admin_date.year,yeatex);
    datex:=CONCAT(daytex,'-',montex,'-',yeatex);
    WRITELN(lst,'Admin date: ',datex);
    IF vaccine THEN BEGIN
      STR(recall_date.day,daytex);
      STR(recall_date.month,montex);
      STR(recall_date.year,yeatex);
      datex:=CONCAT(daytex,'-',montex,'-',yeatex);
      WRITELN(lst,'Recall date: ',datex);
    END;
  END;
  WRITELN(lst);
END;


PROCEDURE SPDispARec(Arec:AdminFile);   {Displays a record from the Admin file}

VAR
  quantext,daytex,montex,yeatex,datex,name:        STRING;
  size                                    :        INTEGER;
  data                                    :        passarray;
  temp                                    :        char;

BEGIN
  name:=FFindDrug(ARec.drug_code);
  data[1]:=CONCAT('Name: ',name);
  WITH ARec DO BEGIN
    data[2]:=CONCAT('NHS Number: ',NHS_num);
    STR(admin_date.day,daytex);
    STR(admin_date.month,montex);
    STR(admin_date.year,yeatex);
    data[3]:=CONCAT('Admin date: ',daytex,'-',montex,'-',yeatex);
    IF vaccine THEN BEGIN
      size:=4;
      STR(recall_date.day,daytex);
      STR(recall_date.month,montex);
      STR(recall_date.year,yeatex);
      data[4]:=CONCAT('Recall date: ',daytex,'-',montex,'-',yeatex);
    END ELSE size:=3;
  END;
  SSSPDisplayBox('Record details',size,data);
  REPEAT
    MPOS(mstatus);
  UNTIL (keypressed) OR (mstatus.buttonstatus=1);
  IF keypressed THEN temp:=READKEY;
END;

Procedure SPFindBat(VAR recloc,prev : INTEGER); {Finds a record from the Batches file}

VAR
   SearchName   :       STRING;
   FoundCode    :       STRING;
   temprec      :       BatchFile;
   answer       :       BOOLEAN;
   count        :       INTEGER;
   data         :       PassARRAY;
   countext     :       STRING;

BEGIN
  answer:=FALSE;
  data[1]:='Name:';
  SSSPDisplayBox('Please enter drug name',1,data);
  SSSPGetText(1,SearchName);
  CLEARDEVICE;
  prev:=0;
  FoundCode:=FIdentDrug(SearchName);
  IF FoundCode='FAILED!' THEN BEGIN
    SSSPError('Search error','Drug does not exist!');
    CLEARDEVICE;
    recloc:=0;
  END ELSE BEGIN
    count:=bindex.start;
    REPEAT
      CLEARDEVICE;
      temprec.drug_code:='NULL';
      WHILE (temprec.drug_code<>FoundCode) and (count>0) DO BEGIN
        RESET(Batches);
        SEEK(Batches,bindex.data[count,1]-1);
        READ(Batches,temprec);
        IF temprec.drug_code<>FoundCode THEN BEGIN
          prev:=count;
          count:=bindex.data[count,2]
        END;
      END;
      IF temprec.drug_code=FoundCode THEN BEGIN
        SPDispBRec(temprec);
        CLEARDEVICE;
        SSSPGetAns('Question','Is this it?',answer);
        CLEARDEVICE;
        IF NOT answer THEN BEGIN
          prev:=count;
          count:=bindex.data[count,2]
        END;
      END;
    UNTIL answer or (count=0);
    recloc:=count;
    bugnum:=recloc;
  END;
END;

Procedure SPFindDrug(VAR recloc,prev:INTEGER);  {Finds a record from the drugs file}

VAR
  SearchName   :       STRING;
  FoundCode    :       STRING;
  FoundName    :       STRING;
  temprec      :       DrugFile;
  answer       :       BOOLEAN;
  count        :       INTEGER;
  data         :       PassArray;

BEGIN
  answer:=FALSE;
  data[1]:='Name:';
  SSSPDisplayBox('Please enter drug name',1,data);
  SSSPGetText(1,SearchName);
  CLEARDEVICE;
  count:=dindex.start;
  prev:=0;
  REPEAT
    temprec.name:='NULL';
    RESET(Drugs);
    WHILE (temprec.name<>SearchName) and (count>0) DO BEGIN
      SEEK(Drugs,dindex.data[count,1]-1);
      READ(Drugs,temprec);
      IF temprec.name<>SearchName THEN BEGIN
        prev:=count;
        count:=dindex.data[count,2]
      END;
    END;
    IF temprec.name=SearchName THEN BEGIN
      SPDispDRec(temprec);
      CLEARDEVICE;
      SSSPGetAns('Question','Is this it?',answer);
      CLEARDEVICE;
      IF NOT answer THEN BEGIN
        prev:=count;
        count:=dindex.data[count,2]
      END;
    END;
    CLEARDEVICE;
  UNTIL answer or (count=0);
  recloc:=count;
  bugnum:=recloc;
END;

PROCEDURE SPFindAdmin;          {Finds a record from the Admin file}

VAR
  AdRec        :       AdminFile;
  SearchName   :       STRING;
  FOundCode    :       STRING;
  data         :       PassARRAY;

BEGIN
  data[1]:='Name:';
  SSSPDisplayBox('Please enter drug name',1,data);
  SSSPGetText(1,SearchName);
  FoundCode:=FIdentDrug(SearchName);
  IF FoundCode='FAILED!' THEN BEGIN
    CLEARDEVICE;
    SSSPError('Search error','Drug does not exist!');
  END ELSE BEGIN
    AdRec.drug_code:='NULL';
    RESET(Admin);
    WHILE (AdRec.drug_code<>FoundCode) AND NOT EOF(Admin) DO READ(Admin,AdRec);
    SPDispARec(AdRec);
  END;
END;

Procedure SPAddBRec(temprec : BatchFile);       {Adds a record to the Batches file}

VAR
  NullRec              :       BatchFile;
  count,prev           :       INTEGER;
  IndLoc,FileLoc       :       INTEGER;

BEGIN
  RESET (Batches);
  FileLoc:=1;
  WHILE NOT (EOF (Batches) OR (NullRec.drug_code='DELETED')) DO BEGIN
    READ (Batches,NullRec);
    INC(FileLoc);
  END;
  IF NullRec.drug_code='DELETED' THEN BEGIN
    DEC (Fileloc);
    RESET (Batches);
    SEEK(Batches,Fileloc-1);
  END;
  WRITE (Batches,temprec);
  IndLoc:=bindex.Free;
  bindex.data[indloc,1]:=fileloc;
  bindex.free:=bindex.data[IndLoc,2];
  IF bindex.start=0 THEN BEGIN
    bindex.Start:=IndLoc;
    bindex.data[IndLoc,2]:=0;
  END ELSE BEGIN
    count:=bindex.Start;
    prev:=0;
    RESET (Batches);
    SEEK(Batches,bindex.data[count,1]-1);
    READ(Batches,NullRec);
    WHILE (NullRec.drug_code < temprec.drug_code) AND (count>0) DO BEGIN
      prev:=count;
      count:=bindex.data[count,2];
      RESET (Batches);
      SEEK(Batches,bindex.data[count,1]-1);
      READ(Batches,NullRec);
    END; 
    bindex.data[IndLoc,2]:=count;
    IF prev=0 THEN bindex.start:=IndLoc ELSE bindex.data[prev,2]:=IndLoc;
  END;
  CLEARDEVICE;
  SSSPError('Notice','Record added');
END;

Procedure SPAddDRec(temprec : DrugFile);        {Adds a record to the Drugs file}

VAR
  count,prev           :       INTEGER;
  IndLoc,FileLoc       :       INTEGER;
  NullRec              :       DrugFile;

BEGIN
  RESET (Drugs);
  FileLoc:=1;
  WHILE NOT (EOF (drugs) OR (NullRec.drug_code='DELETED')) DO BEGIN
    READ (drugs,NullRec);
    INC(FileLoc);
  END;
  IF NullRec.drug_code='DELETED' THEN BEGIN
    DEC (Fileloc);
    RESET (drugs);
    SEEK(Drugs,Fileloc-1);
  END;
  WRITE (drugs,temprec);
  IndLoc:=dindex.Free;
  dindex.data[indloc,1]:=fileloc;
  dindex.free:=dindex.data[IndLoc,2];
  IF dindex.start=0 THEN BEGIN
    dindex.Start:=IndLoc;
    dindex.data[IndLoc,2]:=0;
  END ELSE BEGIN
    count:=dindex.Start;
    prev:=0;
    RESET(drugs);
    SEEK(drugs,dindex.data[count,1]-1);
    READ(drugs,NullRec);
    WHILE (NullRec.drug_code < temprec.drug_code) AND (count>0) DO BEGIN
      prev:=count;
      count:=dindex.data[count,2];
      RESET(drugs);
      SEEK(drugs,dindex.data[count,1]-1);
      READ(drugs,NullRec);
    END;
    dindex.data[IndLoc,2]:=count;
    IF prev=0 THEN dindex.start:=IndLoc ELSE dindex.data[prev,2]:=IndLoc;
  END;
  CLEARDEVICE;
  SSSPError('Notice','Record added');
END;

PROCEDURE OBDispense;           {Records a dispensation}

VAR
  Loc, prev    :       INTEGER;
  temprec      :       BatchFile;
  WRITERec     :       AdminFile;
  READRec      :       DrugFile;
  NullRec      :       AdminFile;
  data         :       PassARRAY;
  maxday       :       INTEGER;

BEGIN
  data[1]:='NHS Number:';
  SPFindBat(loc, prev);
  IF loc>0 THEN BEGIN
    SEEK(Batches,bindex.data[loc,1]-1);
    READ(Batches,temprec);
    DEC(temprec.quantity);
    SEEK(Batches,bindex.data[loc,1]-1);
    WRITE(Batches,temprec);
    SSSPDisplayBox('Please enter the patient`s NHS number',1,data);
    SSSPGetText(1,WRITERec.NHS_Num);
    WRITERec.drug_code:=temprec.drug_code;
    WRITERec.lot_number:=temprec.Lot_number;
    WRITErec.admin_date:=today;
    Loc:=dindex.start;
    prev:=0;
    RESET(Drugs);
    READRec.drug_code:='NULL';
    WHILE (READRec.drug_code<>temprec.drug_code) and (loc>0) DO BEGIN
      SEEK(Drugs,dindex.data[loc,1]-1);
      READ(Drugs,READRec);
      IF READrec.drug_code<>temprec.drug_code THEN BEGIN
        prev:=loc;
        loc:=dindex.data[loc,2]
      END;
    END;
    IF READrec.vaccine THEN BEGIN
      WRITErec.recall_date.day:=today.day+READrec.recall_time.day;
      WRITErec.recall_date.month:=today.month+READrec.recall_time.month;
      WRITErec.recall_date.year:=today.year+READrec.recall_time.year;
      Case WRITErec.recall_date.month of
        1,3,5,7,8,10,12 : maxday:=31;
        4,6,9,11 : maxday:=30;
        2 : IF WRITErec.recall_date.year mod 4 = 0 THEN maxday:=29 ELSE maxday:=28;
      END;
      WHILE WRITErec.recall_date.day>maxday DO BEGIN
        inc(WRITErec.recall_date.month);
        DEC(WRITErec.recall_date.day,maxday);
        Case WRITErec.recall_date.month of
          1,3,5,7,8,10,12 : maxday:=31;
          4,6,9,11 : maxday:=30;
          2 : IF WRITErec.recall_date.year mod 4 = 0 THEN maxday:=29 ELSE maxday:=28;
        END;
      END;
      WHILE WRITErec.recall_date.month>12 DO BEGIN
        INC(WRITErec.recall_date.year);
        DEC(WRITErec.recall_date.month,12);
      END;
    END ELSE WRITErec.vaccine:=FALSE;
    RESET(Admin);
    WHILE not EOF(admin) DO READ(admin,NullRec);
    WRITE(Admin,WRITERec);
  END ELSE SSSPError('Search error','Not found');
END;

PROCEDURE OBAdd;        {Adds a record to the Batches file}

VAR
  drug_name            :       STRING;
  drug_code            :       STRING;
  temprec              :       BatchFile;
  TempText             :       STRING;
  code,count           :       INTEGER;
  data                 :       Passarray;
  accept               :       BOOLEAN;

BEGIN
  IF bindex.free>0 THEN BEGIN
    data[1]:='Name: ';
    data[2]:='Lot number: ';
    data[3]:='Quantity: ';
    data[4]:='Expiry date: ';
    SSSPDisplayBox('Please enter batch details',4,data);
    SSSPGetText(1,drug_name);
    temprec.drug_code:=FIdentDrug(drug_name);
    IF temprec.drug_code='FAILED!' THEN BEGIN
      CLEARDEVICE;
      SSSPError('Input error','Drug does not exist!');
    END ELSE BEGIN
      SSSPGetText(2,temprec.lot_number);
      REPEAT
        SSSPGetText(3,TempText);
        VAL(TempText,temprec.quantity,code);
        STR(temprec.quantity,TempText);
        IF temprec.quantity<1 THEN BEGIN
          SETCOLOR(red);
          OUTTEXTXY(intext_offset+column_width*11,215+3*10,'Please re-enter quantity');
          SETCOLOR(cyan);
          SOUND(200);
          DELAY(100);
          NOSOUND;
          OUTTEXTXY(intext_offset+column_width,215+3*10,'лл');
        END ELSE accept:=TRUE;
      UNTIL accept;
      SETCOLOR(cyan);
      FOR count:=1 TO 25 DO OUTTEXTXY(intext_offset+(count+10)*column_width,215+3*10,'л');
      accept:=FALSE;
      SSSPGetDate(4,temprec.exp_date);
      SPAddBRec(temprec);
    END;
  END ELSE SSSPError('Addition error','Batches file full');
END;

PROCEDURE OBRemove;     {Removes a record from the Batches file}

VAR
  Loc, prev    :       INTEGER;
  temprec      :       BatchFile;

BEGIN
  SPFindBat(loc,prev);
  IF loc>0 THEN BEGIN
    bugnum:=loc;
    IF prev>0 THEN bindex.data[prev,2]:=bindex.data[loc,2] ELSE bindex.start:=bindex.data[Loc,2];
    bindex.data[loc,2]:=bindex.free;
    bindex.free:=loc;
    temprec.drug_code:='DELETED';
    RESET(Batches);
    SEEK(Batches,bindex.data[loc,1]-1);
    WRITE(Batches,temprec);  
  END ELSE SSSPError('Search Error','Not found');
END;

PROCEDURE OBSearch;     {Searches the Batches file}

VAR
  Loc, prev    :       INTEGER;
  likeprint    :       BOOLEAN;
  temprec      :       batchfile;

BEGIN
  SPFindBat(loc,prev);
  IF Loc>0 THEN BEGIN
    SSSPGetAns('Question','Would you like to print?',likeprint);
    IF likeprint THEN BEGIN
      RESET(batches);
      SEEK(batches,bindex.data[loc,1]-1);
      READ(batches,temprec);
      SPPrintBRec(temprec);
      WRITELN(lst,chr(12));
    END;
  END ELSE SSSPError('Search Error','Not found');
END;

PROCEDURE OBDisplay;    {Displays the contents of the Batches file}

VAR
  count        :       INTEGER;
  temprec      :       batchfile;

BEGIN
  count:=bindex.start;
  WHILE count >0 DO BEGIN
    RESET (Batches);
    SEEK(Batches,bindex.data[count,1]-1);
    READ(Batches,temprec);
    SPDispBRec(temprec);
    count:=bindex.data[count,2];
  END;
END;

PROCEDURE OBPrint;      {Prints the contents of the Batches file}

VAR
  count        :       INTEGER;
  temprec      :       batchfile;
  countext     :       STRING;

BEGIN
  count:=bindex.start;
  WHILE count >0 DO BEGIN
    STR(count,countext);
    RESET (Batches);
    SEEK(Batches,bindex.data[count,1]-1);
    READ(Batches,temprec);
    WRITELN(lst,countext);
    SPPrintBRec(temprec);
    count:=bindex.data[count,2];
  END;
  WRITELN(lst,chr(12));
END;

PROCEDURE OBBackup;     {Backs up datafiles}

BEGIN
  SWAPVECTORS;
  EXEC(getenv('COMSPEC'),' /c COPY '+path+'*.MED A:\*.MEB');
  EXEC(getenv('COMSPEC'),' /c COPY '+path+'*.IND A:\*.INB');
  SWAPVECTORS;
END;

Procedure ODAdd;        {Adds a record to the Drugs file}

VAR
  temprec              :       DrugFile;
  TempText             :       STRING;
  code                 :       INTEGER;
  data                 :       PassArray;
  LastChar             :       Char;

BEGIN
  IF dindex.free>0 THEN BEGIN
    data[1]:='Name: ';
    data[2]:='Manufacturer: ';
    data[3]:='Notes: ';
    data[4]:='Vaccine?';
    SSSPDisplayBox('Please enter drug details',4,data);
    SSSPGetText(1,temprec.name);
    SSSPGetText(2,temprec.manufacturer);
    SSSPGetText(3,temprec.free_text);
    SSSPGetBool(temprec.vaccine);
    CLEARDEVICE;
    IF temprec.vaccine=TRUE THEN BEGIN
      data[1]:='Days:';
      data[2]:='Months:';
      data[3]:='Years:';
      SSSPDisplayBox('Please enter recall time',3,data);
      SSSPGetText(1,TempText);
      VAL(TempText,temprec.recall_time.day,code);
      SSSPGetText(2,TempText);
      VAL(TempText,temprec.recall_time.month,code);
      SSSPGetText(3,TempText);
      VAL(TempText,temprec.recall_time.year,code);
      CLEARDEVICE;
    END;
    LastChar:='!';
    REPEAT
      WITH temprec DO drug_code:=CONCAT(name[1],name[2],name[3],name[4],manufacturer[1],lastchar);
      INC(lastchar);
    UNTIL FFindDrug(temprec.drug_code)='FAILED!';
    SPAddDrec(temprec);
  END ELSE SSSPError('Addition error','Drugs file full');
END;

Procedure ODRemove;     {Removes a record from the Drugs file}

VAR
  loc,prev      :       INTEGER;
  temprec       :       DrugFile;

BEGIN
  SPFindDrug(loc,prev);
  IF loc>0 THEN BEGIN
    IF prev>0 THEN dindex.data[prev,2]:=dindex.data[loc,2] ELSE dindex.start:=dindex.data[Loc,2];
    dindex.data[loc,2]:=dindex.free;
    dindex.free:=loc;
    temprec.drug_code:='DELETED';
    RESET(Batches);
    SEEK(drugs,dindex.data[loc,1]-1);
    WRITE(drugs,temprec);
  END ELSE SSSPError('Search Error','Not found');
END;

Procedure ODSearch;     {Searches the Drugs file}

VAR
  loc,prev      :       INTEGER;
  temprec       :       drugfile;
  likeprint     :       BOOLEAN;

BEGIN
  SPFindDrug(loc,prev);
  IF loc>0 THEN BEGIN
    SSSPGetAns('Question','Would you like to print?',likeprint);
    IF likeprint THEN BEGIN
      RESET(drugs);
      SEEK(drugs,dindex.data[loc,1]-1);
      READ(drugs,temprec);
      SPPrintDRec(temprec);
      WRITELN(lst,chr(12));
    END;
  END ELSE SSSPError('Search Error','Not found');
END;

PROCEDURE OBDrugs;      {Brings up Drugs menu}

VAR
   xpos, ypos   :       INTEGER;
   key          :       CHAR;
   loop         :       INTEGER;

BEGIN
  DELAY (1000);
  REPEAT
    SSPShowDbar {Display button bar};
    REPEAT
      MPOS(mstatus);
    UNTIL (KeyPressed) OR (mstatus.buttonstatus=1);
    IF keypressed THEN BEGIN
      key:=UpCase(READKEY);
      IF key=UpCase(optionsd[1,selchard[1]]) THEN ODAdd;       {This would not work as a CASE statement}
      IF key=UpCase(optionsd[2,selchard[2]]) THEN ODRemove;
      IF key=UpCase(optionsd[3,selchard[3]]) THEN ODSearch;
    END;
    IF (mstatus.buttonstatus=1) THEN BEGIN
      xpos := mstatus.column;
      ypos := mstatus.row;
      IF (ypos>=0) AND (ypos<10) THEN BEGIN			{Different options when mouse is clicked on dIFferent places}
        IF (xpos>0) AND (xpos<159) THEN ODAdd;
        IF (xpos>128) AND (xpos<319) THEN ODRemove;
        IF (xpos>256) AND (xpos<479) THEN ODSearch;
      END;
    END;
    DELAY (1000)
  UNTIL ((xpos>480) AND (xpos<638) AND (ypos>=0) AND (ypos<10)) OR (key=UpCase(optionsd[4][selchard[4]]));
  DELAY (1000);
END;

PROCEDURE OASearch;     {Searches Admin file}

VAR
   AdRec        :       AdminFile;
   SearchName   :       STRING;
   FOundCode    :       STRING;
   answer       :       BOOLEAN;
   data         :       passarray;

BEGIN
  data[1]:='Name:';
  SSSPDisplayBox('Please enter drug name',1,data);
  SSSPGetText(1,SearchName);
  FoundCode:=FIdentDrug(SearchName);
  IF FoundCode='FAILED' THEN SSSPError('Search Error','Drug does not exist!');
  AdRec.drug_code:='NULL';
  RESET(Admin);
  answer:=FALSE;
  WHILE NOT (EOF(ADMIN) OR answer) DO BEGIN
    WHILE AdRec.drug_code<>FoundCode DO READ(Admin,AdRec);
    SPDispARec(AdRec);
    CLEARDEVICE;
    SSSPGetAns('Question','Is this it?',answer);
    CLEARDEVICE;
  END;
END;

PROCEDURE OADisplay;    {Displays contents of Admin file}

VAR
   AdRec        :       Adminfile;

BEGIN
  RESET(Admin);
  While NOT EOF(Admin) DO BEGIN
    READ(Admin,AdRec);
    SPDispARec(AdRec);
    CLEARDEVICE;
  END;
END;

PROCEDURE OAPrint;      {Prints contents of Admin file}

VAR
   AdRec        :       Adminfile;

BEGIN
  RESET(Admin);
  While NOT EOF(Admin) DO BEGIN
    READ(Admin,AdRec);
    SPPrintARec(AdRec);
  END;
END;

PROCEDURE OBAdmin;      {Brings up Admin menu}

VAR
   xpos, ypos   :       INTEGER;
   key          :       CHAR;

BEGIN
  REPEAT
    DELAY (1000);
    SSPShowAbar {Display button bar};
    REPEAT
      MPOS(mstatus);
    UNTIL (KeyPressed) OR (mstatus.buttonstatus=1);
    IF keypressed THEN BEGIN
      key:=UpCase(READKEY);
      IF key=UpCase(optionsa[1,selchara[1]]) THEN OASearch;    {This would not work as a CASE statement}
      IF key=UpCase(optionsa[2,selchara[2]]) THEN OADisplay;
      IF key=UpCase(optionsa[3,selchara[3]]) THEN OAPrint;
    END;
    IF (mstatus.buttonstatus=1) THEN BEGIN
      xpos := mstatus.column;
      ypos := mstatus.row;
      IF (ypos>=0) AND (ypos<10) THEN BEGIN			{Different options when mouse is clicked on dIFferent places}
        IF (xpos>0) AND (xpos<159) THEN OASearch;
        IF (xpos>160) AND (xpos<319) THEN OADisplay;
        IF (xpos>320) AND (xpos<479) THEN OAPrint;
      END;
    END;
    DELAY(1000);
  UNTIL ((xpos>480) AND (xpos<638) AND (ypos>=0) AND (ypos<10)) OR (key=UpCase(optionsa[4][selchara[4]]));
  DELAY (1000);
END;

PROCEDURE PMainProg;    {Main (Batches) menu}

VAR
   xpos, ypos   :       INTEGER;
   key          :       CHAR;

BEGIN
  REPEAT
    SSPShowBbar {Display button bar};
    REPEAT
      MPOS(mstatus);
    UNTIL (KeyPressed) OR (mstatus.buttonstatus=1);
    IF KeyPressed THEN BEGIN
      key:=(UpCase(READKEY));
      IF key=UpCase(optionsb[1,selcharb[1]]) THEN OBDispense;   {This would not work as a CASE statement}
      IF key=UpCase(optionsb[2,selcharb[2]]) THEN OBAdd;
      IF key=UpCase(optionsb[3,selcharb[3]]) THEN OBRemove;
      IF key=UpCase(optionsb[4,selcharb[4]]) THEN OBSearch;
      IF key=UpCase(optionsb[5,selcharb[5]]) THEN OBDisplay;
      IF key=UpCase(optionsb[6,selcharb[6]]) THEN OBPrint;
      IF key=UpCase(optionsb[7,selcharb[7]]) THEN OBBackup;
      IF key=UpCase(optionsb[8,selcharb[8]]) THEN OBCheck;
      IF key=UpCase(optionsb[9,selcharb[9]]) THEN OBDrugs;
      IF key=UpCase(optionsb[10,selcharb[10]]) THEN OBAdmin;
    END;
    IF (mstatus.buttonstatus=1) THEN BEGIN
      xpos := mstatus.column;
      ypos := mstatus.row;
      IF (ypos>=0) AND (ypos<10) THEN BEGIN			{Different options when mouse is clicked on dIFferent places}
        IF (xpos>1) AND (xpos<59) THEN OBDispense;
        IF (xpos>60) AND (xpos<117) THEN OBAdd;
        IF (xpos>118) AND (xpos<175) THEN OBRemove;
        IF (xpos>176) AND (xpos<233) THEN OBSearch;
        IF (xpos>234) AND (xpos<291) THEN OBDisplay;
        IF (xpos>292) AND (xpos<349) THEN OBPrint;
        IF (xpos>350) AND (xpos<407) THEN OBBackup;
        IF (xpos>408) AND (xpos<465) THEN OBCheck;
        IF (xpos>466) AND (xpos<523) THEN OBDrugs;
        IF (xpos>524) AND (xpos<581) THEN OBAdmin;
      END;
    END;
    DELAY(1000);
  UNTIL ((xpos>582) AND (xpos<639) AND (ypos>=0) AND (ypos<10)) OR (key=UpCase(optionsb[11][selcharb[11]]));
END;

PROCEDURE PQuit;        {ShutDown procedure}

VAR
   count,code   :       INTEGER;
   countext     :       STRING;

BEGIN
  CLEARDEVICE;
  OBCheck;
  REWRITE (bindexfile);
  count:=bindex.start;
  WHILE count>0 DO BEGIN
    WRITE(bindexfile,bindex.data[count,1]);
    STR(count,countext);
    count:=bindex.data[count,2];
  END;
  REWRITE (dindexfile);
  count:=dindex.start;
  WHILE count>0 DO BEGIN
    WRITE(dindexfile,dindex.data[count,1]);
    STR(count,countext);
    count:=dindex.data[count,2];
  END;
  CLEARDEVICE;
  SWAPVECTORS;
  EXEC(getenv('COMSPEC'),' /c '+path+'restart.bat');
  SWAPVECTORS;
END;

BEGIN
  PStartup;
  PMainProg;
  PQuit;
END.




                    