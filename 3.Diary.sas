
/* DIARY */

LIBNAME CEX "C:\Users\Eric\OneDrive\Documents\Second Year\MP\CEX";
  /*Enter Data Year*/
    %LET YEAR = 2013;
  /*Enter location of the unzipped microdata file*/
    %LET DRIVE = C:\Users\Eric\OneDrive\Documents\MP\CEX;

	%LET YR1 = %SUBSTR(&YEAR,3,2);
%LET YR2 = %SUBSTR(%EVAL(&YEAR+1),3,2);
%LET YR3 = %SUBSTR(%EVAL(&YEAR+2),3,2);
%LET YR4 = %SUBSTR(%EVAL(&YEAR+3),3,2);

/* Read in the 2013+ FMLD files */

DATA FMLD13_All_Test (Sortedby=NewID);
	SET CEX&YR1..FMLD131 (in= FirstQTR) CEX&YR1..FMLD132 (in= SecondQTR) CEX&YR1..FMLD133 (in= ThirdQTR) CEX&YR1..FMLD134 (in= LastQTR)
	    CEX&YR1..FMLD141 (in= FirstQTR) CEX&YR1..FMLD142 (in= SecondQTR) CEX&YR1..FMLD143 (in= ThirdQTR) CEX&YR1..FMLD144 (in= LastQTR)
	    CEX&YR1..FMLD151 (in= FirstQTR) CEX&YR1..FMLD152 (in= SecondQTR) CEX&YR1..FMLD153 (in= ThirdQTR) CEX&YR1..FMLD154 (in= LastQTR);
	By NewID;
	
	RUN;

/* Demographic Data - creating new variables and collapsing by CUID */
Proc Sql;
  Create Table FMLD13 AS
	Select *,
	/*Creating Dummy variable for marriage. Used in regression match, not sure if still needed*/ 
		 Case When marital1="1" Then "1" Else "0" End as Married,
	/* Creating subgroups based on household income before taxes and wages before taxes*/ 
		(Case When (fincbefm <= 30000) Then "1"
             When (fincbefm > 30000 AND fincbefm <= 70000) Then "2"
             Else "3" End) AS INCLASS5,
		(Case When (FWAGEX <= 15000) Then "1"
             When (FWAGEX > 15000 AND FWAGEX <= 60000) Then "2"
             Else "3" End) AS INCLASS5sal,
		case when educ_ref="00" or educ_ref="10" or educ_ref="11" then "1" /* Did not complete HS */
			 when educ_ref="12" then "2" /* HS Grad */
			 when educ_ref="13" or educ_ref="14" then "3" /* Some College */
			 when educ_ref="15" then "4" /* College Grad */
			 when educ_ref="16" then "5" else "1" end as Edu_Level, /*Grad Degree + */ /*No one was left over */
		case when cutenure="1" then "1" /* owned w mortgage */ when cutenure="2" then "2" /* owned w/o mortage */ 
			 when cutenure="3" then "3" when cutenure="4" or cutenure="5" or cutenure="6" /* rent, occupied w/o rent, student housing */ then "4" 
			 else "5" end as Owned 
		From FMLD13_All_Test
		Order by NEWID;
Create Table FMLD13 AS
Select *,
		case when married = "1" or married = "0" then "1" else "0" end as data_num,/*Creating a one for each observation */
		Count(NEWID) Format=3. as Interview_Count,
		Mean(FINLWT21)/10 as CUID_WT, 
/* Dummy for graduating college (1 = College Graduate) */
		Case When Edu_level = "1" or edu_level = "2" or edu_level = "3" Then "0" Else "1" End as College_Grad,
		max(age_ref) as max_age /*Finding the max age for each CUID, to be used in GregWeight. */
	From FMLD13
	Group By CUID
	having (region = "3" or region = "2") and (fincbefm > 0)
	order by newid;
create table FMLD13 AS
select *,
/* Creating Age Groups */
	 Case When max_age <= 35 Then "1" 
           when max_age > 35 and max_age <= 50 then "2"
           when max_age > 50 and max_age <= 65 then "3"
           Else "4" End AS AGE_GROUP,
/*Creating variables for college grad and home ownership status to be used for GregWeight */
	  case when college_grad = "0" and Owned = "1" then "1" /*Not a Grad + Homeowner w/ mortgage */
	  	   when college_grad = "0" and Owned = "2" then "2" /*Not a Grad + Homeowner w/o mortgage */
		   when college_grad = "0" and Owned = "4" then "3" /*Not a Grad + Rents */
		   when college_grad = "1" and Owned = "1" then "4" /*Grad + Homeowner w/ mortgage */
		   when college_grad = "1" and Owned = "2" then "5" /*Grad + Homeowner w/o mortgage */
		   when college_grad = "1" and Owned = "4" then "6" /*Grad + Rents */
		   else "7" end as College_own,
/*Creating variables for marital and home ownership status to be used for GregWeight */
	  case when married = "0" and Owned = "1" or Owned = "2" then "1" /*Not married + Homeowner */
	  	   when married = "0" and Owned = "4" then "2" /*Not married + Rents */
		   when married = "1" and Owned = "1" or Owned = "2" then "3" /*Married + Homeowner */
		   when married = "1" and Owned = "4" then "4" /*Married + Rents */
		   else "7" end as married_own,
     (case when STRTYEAR = "2012" then 1.03222
		   when STRTYEAR = "2013" then 1.01743
		   when STRTYEAR = "2014" then 1.00119
		   when STRTYEAR = "2015" then 1 else 1 end) as CPI_F
From FMLD13
	Order by newid, cuid;
quit;

data FMLD13; retain cuid; set FMLD13; 
fincbefm = fincbefm * CPI_F;
FWAGEX = FWAGEX * CPI_F;

run; /* Making CUID the first variable */
/* Retaining only one weeks worth of observations for each household. */

data FMLD13;
   set FMLD13;
   by cuid;
  if last.cuid;
run; 


/* Expenditure Data */

DATA DiaryEXPEND_ANN (KEEP=NEWID UCC COST expnyr);

  SET CEX&YR1..EXPD&YR1.1
      CEX&YR1..EXPD&YR1.2
      CEX&YR1..EXPD&YR1.3
      CEX&YR1..EXPD&YR1.4
      CEX&YR1..EXPD&YR2.1
      CEX&YR1..EXPD&YR2.2
      CEX&YR1..EXPD&YR2.3
      CEX&YR1..EXPD&YR2.4
      CEX&YR1..EXPD&YR3.1
	  CEX&YR1..EXPD&YR3.2
      CEX&YR1..EXPD&YR3.3
      CEX&YR1..EXPD&YR3.4
      CEX&YR1..DTBD&YR1.1 
      CEX&YR1..DTBD&YR1.2 
      CEX&YR1..DTBD&YR1.3  
      CEX&YR1..DTBD&YR1.4  
      CEX&YR1..DTBD&YR2.1
	  CEX&YR1..DTBD&YR2.2 
      CEX&YR1..DTBD&YR2.3  
      CEX&YR1..DTBD&YR2.4 
	  CEX&YR1..DTBD&YR3.1
	  CEX&YR1..DTBD&YR3.2 
      CEX&YR1..DTBD&YR3.3  
      CEX&YR1..DTBD&YR3.4 
;
  
   /*IF REFYR = "&YEAR" OR  REF_YR = "&YEAR"*/;
   IF UCC = '710110'  THEN  
      COST = (COST * 4); 
	  If expnyr = '2012' then cost = (cost * 1.03222);
   	  else if expnyr = '2013' then cost = (cost * 1.01743);
	  else if expnyr = '2014' then cost = (cost * 1.00119);
   /* READ IN MTAB AND ITAB EXPENDITURE AND INCOME DATA */
   /* Annualize 710110 */
RUN;
/* Merging Demographic and Expenditure data and Creating Expenditure categories */

PROC SORT DATA=DiaryEXPEND_ANN;
	BY NEWID;
RUN;
DATA Diary2013_Entries (KEEP = NEWID CUID INTERI INCLASS5 INCLASS5sal UCC UCC_GRP Cost_W Cost FINLWT21 CUID_WT Married data_num Interview_count FWAGEX);
  MERGE FMLD13          (IN = INFAM)
        diaryEXPEND_ANN (IN = INEXP);
BY NEWID;
  IF INEXP AND INFAM;
  IF UCC IN (000001:999999);
  IF COST = .  THEN 
     COST = 0;

  IF UCC IN (480212,490000,490316) 
  Then UCC_Grp = 'Auto_Repair_D';

  If UCC IN (500110)
  then UCC_GRP = 'Auto_fees_D';


  IF UCC IN (530412) 
  Then UCC_Grp = 'AltTrans_D'; /* Public Transportation */

/* Housing */
	if ucc in (300900,320310,320320,320340,320350,320360,320345,320370,320380,320130,320140,320150,320220:320221,320232:320233,320410,320420,320902,320904,430130,690120,320430,
             320905,340913,340520,330110,330210,330310,330510,330610,330410,340110,340120,280110,280120,280130,280140,280900) 
	then ucc_grp = "Housing_D";

  IF UCC IN (340530)
  Then UCC_Grp = 'Operations_D';/*
 
  /* Food */
  IF UCC IN (010110:140420, 150211:160320, 170520:180720, 200112)
  Then UCC_Grp = 'Food_D';
  IF UCC IN (190111,190113,190114,190211,190213,190214,190311:190314,190321,190323,190324)
  Then UCC_Grp = 'Food_Away_D';
  if ucc in (190112,190212,190322)
  then Ucc_grp = 'restaurant_d';
  IF UCC IN (150110,170110,170210) /* Soda and Candy taxed at different rate than food */
  Then UCC_Grp = 'Soda_Candy_D';
  IF UCC IN (200111,200511:200516)
  Then UCC_Grp = 'Beer_D';
  IF UCC IN (200310,200521:200526)
  Then UCC_Grp = 'Wine_D';
  IF UCC IN (200210,200410, 200531:200536)
  Then UCC_Grp = 'Spirit_D';
   
  /* Apparel */
   IF UCC IN (360210,360311,360312,360330,360340,360350,360410,360420,360513,370120,370125,370130,370211,370213,370220,370311,380110,380210,380312,380313,380315,380320,380333,380340,380410,
             380420,380430,380901,390110,390120,390210,390230,390310,390321,390322,410120,410130,410140,410901,400110,400210,400310,400220,420110,420120,420115,430110)
  Then UCC_Grp = 'Apparel_D';

    /* Healthcare - All Taxed */
  IF UCC IN (550210,550410,550310,620420)
  Then UCC_Grp = 'Healthcare_D';

  /* Entertainment */
  IF UCC IN (620121,310312,310313,310331,310335,310332,310315,310220,310232,620912,
			610310,610110,600210,600410,600420,600903,610220,610901:610903,620913,640110,
             640210,640220,640310,640410,640420,650900)
  Then UCC_Grp = 'Entertain_D';

  /* Other */
  IF UCC IN (660000) 
  Then UCC_Grp = 'Education_D';
  if ucc in (620925,620926,630220,680903,620420,650900) /* Added vet services */
  then ucc_grp = "Misc_D";
  if ucc in (640110,640120,640210,640220,640310,640410,640420,570902)
  then ucc_grp ="Personal_D"; 


Cost_W = Cost * CUID_WT;

Run;
/* Testing for missing UCCs. None in IntStub file */
proc sql;
create table missing as
select distinct ucc
from Diary2013_Entries
where Ucc_grp = " "
order by ucc;
quit;

/* Data Transformation */

Proc Summary data=Diary2013_Entries nway;
 	class CUID UCC_GRP;
	var cost cost_w;
	output out=Diary2013_Sums (drop=_:)
			sum = cost cost_w;
Run;
/* Extrapolating yearly expenditures from the diary data */ 

Proc SQL;
  Create Table Diary2013_Sums2 AS
  	Select	CUID,
			UCC_GRP,
			Sum(Cost)*52 as Ann_Cost, /* potential for outlying weeks to have disproportinate impact (ex vacation) Further investigation needed. */
			Sum(Cost_W)*52 as ANN_Cost_W,
			Mean(CUID_WT) as Mean_CUID_WT,
			MEAN(FINLWT21) as Mean_FINLWT21
	From diary2013_Entries
	Group by cuid,UCC_GRP;
  QUIT; 
/* Making variable names the same for the Interview and Diary file */

DATA FMLD13;
set FMLD13;
	char_var = married;
	married_d = input(char_var, 1.);
	Gender = input(orig, 1.);
	female = gender - 1;
	count = input(data_num, 1.);
	education = input(edu_level, 1.);
	diary = 1;
	fsalaryx = FWAGEX;
	FINCBTAX = FINCBEFX;
	fincbtxm = fincbefm;
run; 

Proc Transpose  data=diary2013_Sums2
	out=diary2013_CUExp (drop= _NAME_);
	id UCC_GRP;
	var Ann_Cost;
	by CUID ;
Run;
/* Setting blank diary values to zero for future fusion */

DATA diary2013_CUExp;
  set diary2013_CUExp;
  array expend_d Auto_repair_D Auto_fees_D Housing_D Operations_D Food_D Food_Away_D Soda_Candy_D Apparel_D Healthcare_D
  				 Entertain_D Education_D Beer_D Wine_D Spirit_D AltTrans_D Personal_D Misc_D;
  do over expend_d;
  	if (expend_d =. or expend_d < 0) then expend_d = 0;
  end;
  run;
 
/* Combing the diary's demographic data with expenditure data by CUID. The merged data set will be used for fusing the intrerview and diary data */

proc sql;
Create Table diary2013_PreGREGWT AS
	Select  t1.CUID,
			t1.Auto_repair_D,
			t1.Auto_fees_D,
			t1.Housing_D,
			t1.Operations_D,
			t1.Food_D,
			t1.Food_Away_D,
			t1.restaurant_d,
			t1.Soda_Candy_D,
			t1.Apparel_D,
			t1.Healthcare_D,
			t1.Entertain_D,
			t1.Education_D,
			t1.Beer_D,
			t1.Wine_D,
			t1.Spirit_D,
			t1.AltTrans_D,
			t1.Personal_D,
			t1.Misc_D,
			t2.Fam_Type,
			t2.Fam_size,
			t2.INCLASS5,
			t2.INCLASS5sal,
			t2.edu_level,
			t2.fsalaryx,
			t2.FINCBTAX,
			t2.fincbtxm,
			t2.married,
			t2.data_num,
			t2.age_group,
			t2.diary,
			t2.max_age,
			t2.sex_ref,
			t2.married_own,
			t2.Owned,
			t2.college_own,
			t2.CUID_WT
	From diary2013_CUExp as t1, FMLD13 as t2
	Where t1.CUID = t2.CUID 
order by Cuid;
QUIT;

/*Reorganizing data so pertinent demographic and identifying data appears first */
data diary2013_PreGREGWT;
retain cuid edu_level fsalaryx FINCBTAX married female owned fam_type fam_size;
set diary2013_PreGREGWT;
run;
proc sort data=diary2013_PreGREGWT;
by FINCBTAX;run;

proc sort data=diary2013_PreGREGWT;
   by cuid;
run;
/* Deleting duplicates. The merge caused 406 record to be duplicated for unkown reasons. Given the data looks identical, I deleted duplicate CUIDs. 
   https://communities.sas.com/t5/SAS-Procedures/Delete-duplicate-rows-if-two-variables-match/td-p/39453
   ^^^ may provide insight into what caused the duplicates. */
data diary2013_PreGREGWT;
   set diary2013_PreGREGWT;
   by cuid;
  if last.cuid;
run;

proc sort data=diary2013_PreGREGWT;
   by cuid;
run;


/* Changing character variable to numeric. The changes were originally intended to facilitate regression matching, so I'm not sure if they are still needed */
DATA diary2013_PreGREGWT;
set diary2013_PreGREGWT;
diary = 1;run;

/*B1 - # of CUs per CEX family type */
Data Fam_Type_NC;
	Input Fam_Type $ NC_Families;
	Datalines;
1 876606
2 145019
3 436728
4 222658
5 147484
6 33810
7 172927
8 1105523
9 702892
;

/*B2 - Total expenditures (including natural gas) in NC */
Data Tot_Elec;
	Input Data_num $ Elec;
	Datalines;
1 7404500000
;

/* B3 - # of Households by Income class (based on salaries) */
Data Income_CUS;
	Input INCLASS5sal $ Inc_CUs;
	Datalines;
1 1398591
2 1314371
3 1130685
;

/* B4 - Total Age by age groups */
Data Age_Groups;
     Input Age_Group $ total_age;
     Datalines;
1 22954864
2 45676852
3 64144776
4 65394167
;

/* B5- # of Households by marriage status */ 
Data Mar_Tot;
	Input Married $ Mar_Tot;
	Datalines;
0 1935472
1 1908175
;

/*B6 - CUs by College grad & home ownership status */
Data CollegeHome;
	Input college_own $ Col_CUs;
	Datalines;
1 909231
2 655143
3 1060855
4 664486
5 231534
6 322398
;

/* B7 - # of households by head of household's education attainment*/
Data Edu_Groups;
     Input Edu_Level $ HH;
     Datalines;
1 451661
2 914278
3 1259290
4 759527
5 458891
;

/* B8 - Aggregate Salary by head of household's education attainment */
Data Edu_Inc;
     Input Edu_Level $ Edu_TotInc;
     Datalines;
1 8686011648
2 27914137332
3 53680193589
4 56891328680
5 42355552376
;
/*B9 - # of households by homeowner status*/
Data HomeOwner;
     Input Owned $ Homes;
     Datalines;
1 1573717
2 886677
3 0
4 1383253
;

/*B10 - Aggregated expenditures by income class (based on income)*/
Data Income_exp;
	Input INCLASS5 $ Inc_Totexp;
	Datalines;
1 34629311398 
2 56131771658 
3 86718201353 

;
/* Tested but not used */
/*B - households by marriage and home ownership */
Data MarryOwn;
	Input married_own $ marown_CUs;
	Datalines;
1 956174
2 963385
3 1482184
4 388623
;

/*B - Aggregated Income by sex (based on INcome)*/
Data Sex_Inc;
	Input sex_ref $ sex_TotInc;
	Datalines;
1 1845363
2 1945002
;

/*B - Aggregated Household Income in NC*/
Data Tot_Inc;
	Input Data_num $ Inc;
	Datalines;
1 240875728599
;

Run;
/* Again, I cannot share the GREGWT macro, so please substitute FINLWT_NCR for cuid_wt  */

%GREGWT(UNITDSN=diary2013_PreGREGWT, OUTDSN=diary2013_PostGREGWT, 
         INWEIGHT=CUID_WT, WEIGHT=FINLWT_NCR,
         B1DSN=Fam_Type_NC, B1CLASS=Fam_Type, 
         B1TOT=NC_Families, 
		 B2DSN=Income_CUS, B2CLASS=INCLASS5sal, 
         B2TOT=Inc_CUs,
		 B3DSN=Age_Groups, B3CLASS=AGE_GROUP,
		 B3VAR=max_age,    B3TOT=total_age,
		 B4DSN=Mar_Tot, B4CLASS=Married, 
         B4TOT=Mar_Tot,
		 B5DSN=CollegeHome, B5CLASS=college_own, 
         B5TOT=Col_CUs,
		 B6DSN=Edu_Groups, B6CLASS=Edu_Level, 
         B6TOT=HH,
		 B7DSN=Edu_Inc, B7CLASS=Edu_Level, 
         B7VAR=fsalaryx, B7TOT=Edu_TotInc,
		 LOWER=100, UPPER=10000, EPSILON=0.02,
         ID=_ALL_)
		 run;

DATA diary2013_PostGREGWT;
set diary2013_PostGREGWT;
	count = input(data_num, 1.);
	education = input(edu_level, 1.);
	char_var = married;
	married_d = input(char_var, 1.);
run;
proc sort data=diary2013_PostGREGWT;
by FINLWT_NCR; run;
proc means data=diary2013_PostGREGWT N;
var FINLWT_NCR;
run;
/* Using percentile for later matching */
data diary2013_PostGREGWT;
set diary2013_PostGREGWT;
	rownum = _N_;
	Percentile = rownum/11157;
run;

/* NAICS Industries
These categories will be used to compute cascading taxes */

DATA NAICS2013_Entries (KEEP = NEWID CUID INTERI INCLASS5 INCLASS5sal UCC UCC_GRP Cost_W Cost CUID_WT FINLWT21 Interview_count);
  MERGE FMLD13          (IN = INFAM)
        diaryEXPEND_ANN (IN = INEXP);
BY NEWID;
  IF INEXP AND INFAM;
  IF UCC IN (000001:999999);
  IF COST = .  THEN 
     COST = 0;

if ucc in (320310,320320,320340,320350,320360,320345,320370,320380,320130,320140,320150,320220:320221,320232:320233,320410,320420,
			320902,320904,430130,690120,320430,320905,340520,330110,330210,330310,330510,330610,330410,340110,280110,
			280120,280130,280140,280900,010110:140420, 150211:160320, 170520:180720, 200112, 
			200111,200511:200516,200111,200511:200516,200310,200521:200526,360311,360312,360330,360350,360420,360513,370125,370211,
			370213,370220,370311,380110,380210,380315,380320,380333,380340,380410, 380420,380430,380901,390110,390120,390210,390230,
			390310,390321,390322,410120,410130,410140,410901,400110,400210,400310,400220,420115,430110,
			310313,310331,310335,310332,310315,310220,310232,610310,610110,600210,600410,600420,600903,610220,610901:610903,
			640110,640120,640210,640220,640310,640410,640420,550210,550410,550310)
 Then UCC_Grp = 'Retail_D';

if ucc in (530412,340120)
then ucc_grp = "N_Trans_D";

if ucc in (620121,190111,190113,190114,190211,190213,190214,190311:190314,190321,190323,190324)
then ucc_grp = "ent_d";

if ucc in (680903,340913,570902,650900)
then ucc_grp = "Other_D";

Cost_W = Cost * CUID_WT;
run;
proc sql;
create table missing as
select distinct ucc
from NAICS2013_Entries
where Ucc_grp = " "
order by ucc;
quit;

/* Data Transformation */

Proc Summary data=NAICS2013_Entries nway;
 	class CUID UCC_GRP;
	var cost cost_w;
	output out=NAICS2013_Sums (drop=_:)
			sum = cost cost_w;
Run;
/* Extrapolating yearly expenditures from the diary data */ 

Proc SQL;
  Create Table NAICS2013_Sums2 AS
  	Select	CUID,
			UCC_GRP,
			Sum(Cost)*52 as Ann_Cost, /* potential for outlying weeks to have disproportinate impact (ex vacation) Further investigation needed. */
			Sum(Cost_W)*52 as ANN_Cost_W,
			Mean(CUID_WT) as Mean_CUID_WT,
			MEAN(FINLWT21) as Mean_FINLWT21
	From NAICS2013_Entries
	Group by cuid,UCC_GRP;
  QUIT; 

Proc Transpose  data=NAICS2013_Sums2
	out=NAICS2013_CUExp (drop= _NAME_);
	id UCC_GRP;
	var Ann_Cost;
	by CUID ;
Run;
/* Setting blank diary values to zero for future fusion */

DATA NAICS2013_CUExp;
  set NAICS2013_CUExp;
  array expend_d CUID Retail_D N_Trans_D ent_d Other_D;
  do over expend_d;
  	if (expend_d =. or expend_d < 0) then expend_d = 0;
  end;
  run;
/* Merging in Cascading columns */
proc sql;
Create Table NAICS2013_PreGREGWT AS
	Select t1.CUID,
		   t1.Retail_D,
		   t1.N_Trans_D,
		   t1.ent_d,
		   t1.Other_D,
		   t2.CUID_WT
From NAICS2013_CUExp as t1, FMLD13 as t2
Where t1.CUID = t2.CUID
order by Cuid;
QUIT;

proc sort data=diary2013_PostGREGWT;
   by cuid;
run;

DATA diary2013_PostGREGWT;
  MERGE diary2013_PostGREGWT
        NAICS2013_PreGREGWT;
  BY CUID;
run;
data diary2013_PostGREGWT;
   set diary2013_PostGREGWT;
   by cuid;
  if last.cuid;
run;
