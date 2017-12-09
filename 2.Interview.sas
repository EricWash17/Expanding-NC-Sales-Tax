/* Data (2013 - 2016) can be downloaded from https://www.bls.gov/cex/pumd_data.htm */

LIBNAME CEX "C:\Users\Eric\OneDrive\Documents\Second Year\MP\CEX";
  /*Enter Data Year*/
    %LET YEAR = 2013;
  /*Enter location of the unzipped microdata file*/
    %LET DRIVE = C:\Users\Eric\OneDrive\Documents\Second Year\MP\CEX;

	%LET YR1 = %SUBSTR(&YEAR,3,2);
%LET YR2 = %SUBSTR(%EVAL(&YEAR+1),3,2);
%LET YR3 = %SUBSTR(%EVAL(&YEAR+2),3,2);
%LET YR4 = %SUBSTR(%EVAL(&YEAR+3),3,2);
LIBNAME CEX&YR1 "&DRIVE";

/* Read in the 2013+ FMLI files */

DATA FMLI_All_Test (Sortedby=NewID);
	SET CEX&YR1..FMLI131x (in= FirstQTR) CEX&YR1..FMLI132 (in= SecondQTR) CEX&YR1..FMLI133 (in= ThirdQTR) CEX&YR1..FMLI134 CEX&YR1..FMLI141 (in= LastQTR)
	CEX&YR1..FMLI141x (in= FirstQTR) CEX&YR1..FMLI142 (in= SecondQTR) CEX&YR1..FMLI143 (in= ThirdQTR) CEX&YR1..FMLI144 CEX&YR1..FMLI151 (in= LastQTR)
	CEX&YR1..FMLI151x (in= FirstQTR) CEX&YR1..FMLI152 (in= SecondQTR) CEX&YR1..FMLI153 (in= ThirdQTR) CEX&YR1..FMLI154 CEX&YR1..FMLI161 (in= LastQTR);
	By NewID;
	RUN;

/* Demographic Data - creating new variables and collapsing by CUID */
Proc Sql;
  Create Table FMLI13_4Int AS
	Select *,
	/* Making variable 'marital' into character so it can be used in GregWeight*/ 
		Case When marital1="1" Then "1" Else "0" End as Married,
    /*Creating 3 subgroups for household income (before taxes)*/ 
        (Case When (fincbtxm <= 30000) Then "1"
             When (fincbtxm > 30000 AND fincbtxm <= 70000) Then "2"
             Else "3" End) AS INCOME_CLASS,
    /* Creating 3 subgroups for household wage and salary). Using different thresholds since, generally, salary < income*/ 
         (Case When (fsalaryx <= 15000) Then "1"
             When (fsalaryx > 15000 AND fsalaryx <= 60000) Then "2"
             Else "3" End) AS INCOME_CLASS_sal,
		case when educ_ref="00" or educ_ref="10" or educ_ref="11" then "1"/* Did not complete HS */ 
			 when educ_ref="12" then "2" /* HS Grad */
			 when educ_ref="13" or educ_ref="14" then "3" /* Some College */
			 when educ_ref="15" then "4" /* College Grad */
			 when educ_ref="16" then "5" /*Grad Degree + */ else "1" /*No one left over*/  end as Edu_Level, 
		case when cutenure="1" then "1" /* owned w mortgage */ when cutenure="2" then "2" /* owned w/o mortage */ 
			 when cutenure="3" then "3" when cutenure="4" or cutenure="5" or cutenure="6" /* rent, occupied w/o rent, & student housing */ then "4" 
			 else "3" /*3 is blank */ end as Owned 
		From FMLI_All_Test
		Order by NEWID;
 Create Table FMLI13_4Int AS
	Select *,
		case when married="1" or married="0" then "1" else "0" end as data_num,/* Making a 1 for each observation to be used in GregWeight*/
		Count(NEWID) Format=3. as Interview_Count,
		Sum(INTERI in (2,5)) as Dem_Interview_Count,
		Mean(FINLWT21)/10 as CUID_WT,
		Case When INTERI=5 Then INCOME_CLASS_sal Else "0" End as INCLASS5_sal,
		Case When INTERI=5 Then INCOME_CLASS Else "0" End as INCLASS5_5,
        /* Creating Dummy for college grad */
		Case When Edu_level = "1" or edu_level = "2" or edu_level = "3" Then "0" Else "1" End as College_Grad,
		max(age_ref) as max_age, /*Finding the max age for each CUID, to be used in GregWeight. */
		Max(calculated INCLASS5_sal) as INCLASS5sal,
		Max(calculated INCLASS5_5) as INCLASS5,
		JFS_AMT as FoodStamps
	From FMLI13_4Int 
	Group By CUID 
	having (region = "3" or region = "2") and (Interview_Count = 4 or Interview_count = 3) and (fincbtxm > 0)
	Order by NEWID;
create table FMLI13_4Int AS
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
/* Adjusting Salary and Income for inflation */
	 (case when QINTRVYR = "2012" then 1.03222
		   when QINTRVYR = "2013" then 1.01743
		   when QINTRVYR = "2014" then 1.00119
		   when QINTRVYR = "2015" then 1 else 1 end) as CPI_F
     From FMLI13_4INT
	 Order by NEWID, cuid;
  Quit;
/* Adjusting Salary and Income for inflation */
data FMLI13_4INT; retain cuid; set FMLI13_4INT;
	fsalaryx = fsalaryx*CPI_F;
	FINCBTAX = FINCBTAX*CPI_F;
	FINCBTXM = FINCBTXM*CPI_F;
run;
  

/* Expenditure Data */
DATA EXPEND_ANN (KEEP=NEWID UCC COST ref_yr);
  SET CEX&YR1..MTBI&YR1.1X
      CEX&YR1..MTBI&YR1.2
      CEX&YR1..MTBI&YR1.3
      CEX&YR1..MTBI&YR1.4
      CEX&YR1..MTBI&YR2.1
	  CEX&YR1..MTBI&YR2.1X
      CEX&YR1..MTBI&YR2.2
      CEX&YR1..MTBI&YR2.3
      CEX&YR1..MTBI&YR2.4
      CEX&YR1..MTBI&YR3.1
	  CEX&YR1..MTBI&YR3.1X
      CEX&YR1..MTBI&YR3.2
      CEX&YR1..MTBI&YR3.3
      CEX&YR1..MTBI&YR3.4
      CEX&YR1..MTBI&YR4.1

      CEX&YR1..ITBI&YR1.1X (RENAME=(VALUE=COST))
      CEX&YR1..ITBI&YR1.2  (RENAME=(VALUE=COST))
      CEX&YR1..ITBI&YR1.3  (RENAME=(VALUE=COST))
      CEX&YR1..ITBI&YR1.4  (RENAME=(VALUE=COST))
      CEX&YR1..ITBI&YR2.1  (RENAME=(VALUE=COST))
	  CEX&YR1..ITBI&YR2.1X (RENAME=(VALUE=COST))
      CEX&YR1..ITBI&YR2.2  (RENAME=(VALUE=COST))
      CEX&YR1..ITBI&YR2.3  (RENAME=(VALUE=COST))
      CEX&YR1..ITBI&YR2.4  (RENAME=(VALUE=COST))
      CEX&YR1..ITBI&YR3.1  (RENAME=(VALUE=COST))
	  CEX&YR1..ITBI&YR3.1X (RENAME=(VALUE=COST))
      CEX&YR1..ITBI&YR3.2  (RENAME=(VALUE=COST))
      CEX&YR1..ITBI&YR3.3  (RENAME=(VALUE=COST))
      CEX&YR1..ITBI&YR3.4  (RENAME=(VALUE=COST))
      CEX&YR1..ITBI&YR4.1  (RENAME=(VALUE=COST));
  
   /*IF REFYR = "&YEAR" OR  REF_YR = "&YEAR"*/;
   IF UCC = '710110'  THEN  
      COST = (COST * 4); 
   /* Adjusting for inflation */
   If ref_yr = '2012' then cost = (cost * 1.03222);
   	  else if ref_yr = '2013' then cost = (cost * 1.01743);
	  else if ref_yr = '2014' then cost = (cost * 1.00119);
   /* READ IN MTAB AND ITAB EXPENDITURE AND INCOME DATA */
   /* Annualize 710110 */
RUN;
PROC SORT DATA=EXPEND_ANN;
	BY NEWID;
RUN;

/* Merging Demographic and Expenditure data and Creating Expenditure categories */
DATA CEX2013_Entries (KEEP = NEWID CUID INTERI INCLASS5 INCLASS5sal UCC UCC_GRP Cost_W Cost FINLWT21 CUID_WT Married data_num Interview_count fincbtax fsalaryx foodstamps);
  MERGE FMLI13_4Int   (IN = INFAM)
        EXPEND_ANN (IN = INEXP);
  BY NEWID;
  IF INEXP AND INFAM;
  IF UCC IN (000001:999999);
  IF COST = .  THEN 
     COST = 0;
/* Transportation */

If UCC IN (450110,450210,460110,460901,450220,460902,460903, 450900)
then UCC_GRP = 'Auto_purchase'; 

If UCC IN (470111:470212)
then UCC_GRP = 'Gas'; 

If UCC IN (470220:490900,520410,480110)
then UCC_GRP = 'Auto_Repair';

If UCC IN (510901:510902,850300)
then UCC_GRP = 'Auto_finance';

If UCC IN (520511:520905)
then UCC_GRP = 'Auto_rent';

If UCC IN (450310:450414)
then UCC_GRP = 'Auto_lease';

If UCC IN (520310,520541,520542)
then UCC_GRP = 'Auto_admin';

If UCC IN (520531:520532,520550,520560,620113:620114)
then UCC_GRP = 'Auto_fees';

If ucc in (530210,530311,530312,530510,530901,530902)
then ucc_grp = "Public_Trans";

If ucc in (530110,530411,530901,530902)
then ucc_grp = "AltTrans";


/* Housing */

if ucc in (240111:240323,290110,290120,290210,290310,290320,290410,290420,290430,290440,320111,300211,300212,300221,300222,300331,300332,300411,300412,320330,
            320120,320901,340904,690111,690117,690119,690120,690115,690116,690210,690230,690241:690245,280110,280120,280130,280210,280220,280230,280900,
			230117,230118,300111,300112,300211,300212,300216,300217,300311,300312,300321,300322,320511,320512,320310,320320,320330,320340,320350,320360,320370,320521,320522
			260211,260212,260213,260214,250111:250114,250211:250214,250911:250914,340520,340620,340630,340901,340907,340908,690113:690114,790690,
  			690310,990900,990920,990930,990940,270211:270214, 270411:270414, 270901:270904, 320611:320633,320903 /*RMIs*/ 230112:230115, 230121:230152)
then ucc_grp = "Housing";

/* Rent/Mortgage */  
  IF UCC IN (220311,220313,880110,220211,220121,210901,230901,340911,220901,210110,800710,350110,220312,220314,880310,220212,220122,210902,230902,340912,220902,210310) 
  Then UCC_GRP = 'Rent';
      /*Utilities*/
  IF UCC IN (260111:260114) Then UCC_Grp ='Electricity';
  IF UCC IN (260211:260214) Then UCC_GRP = 'Natural_Gas';
  /*IF UCC IN (250111:250114,250911:250914,250211:250214) Then UCC_GRP = 'Fuel';*/
  If UCC IN (270101:270106) Then UCC_GRP = 'Telephone';
  
     /* Household operations*/
  IF UCC IN (340210,340212, 340906,340910,670310,340310,340410,340420,340530,340914,340915,340903,330511,340510)
  Then UCC_GRP = 'Operations';
  IF UCC IN (340211)
  then ucc_grp = 'babysit'; /* Will consider home babysitters untaxable */

/* Food */
if ucc in (190904)
then Ucc_grp = 'Food';

if ucc in (190901:190903,790430,800700)
then Ucc_grp = 'Food_Away'; /* food away */

IF UCC IN (200900) 
Then UCC_GRP = 'Alcohol';

/* Apparel */
IF UCC IN (360110,360120,360320,360901,360902,370110,370212,370311,370314,370902:370904,380311,380510,380902,380903,390110,390223,390901,390902,410110,430120,440120,440140,
           440900,360110,360120,360320)
Then UCC_GRP = 'Apparel';

 /* Healthcare */ 
IF UCC IN (580111:580116,580312,580904,580906,580311,580901,580907,580903,580905,580400,560110,560210,560310,560400,560330,570111,570240,570220,570230,540000,550110,550340,640430,
             550320,550330,570901,570903) 
Then UCC_GRP = 'Healthcare';

/* Entertainment */
IF UCC IN (610900,620111,620122,620211:620214,620221,620222,620310,620903,310311,310316,310140,270310,270311,
			620930,310210,310231,310240,310400,340902,310314,310320,310334,310340,310350,340905,
		    610130,620904,620917,620918,610320,620410,610140,610120,600122,600141,600142,
			520904,520907,620909,620919,620906,620921,620922,600110,520901,600430
			600310,600901,600902,620908,610210,620330,620905,610230,680310,680320)
Then UCC_GRP = 'Entertainment';



/* Other */
IF UCC IN (600121,600132) 
Then UCC_GRP = 'Boat';
IF UCC IN (640130) 
Then UCC_GRP = 'Personal_Care';
IF UCC IN (650310) 
Then UCC_GRP = 'P_CareServ';
IF UCC IN (590111,590112,590211,590212,590220,590230,660310,590310,590410,690118,660110,660210,660410,660901,660902) 
Then UCC_GRP = 'Reading';
IF UCC IN (670110,670210,670410,670901,670902) 
Then UCC_GRP = 'Edu';
/*IF UCC IN (670110) 
Then UCC_GRP = 'College';*/
IF UCC IN (630110) 
Then UCC_GRP = 'Cigs';
IF UCC IN (630210) 
Then UCC_GRP = 'Non_Cigs';/* Seperating bc different excise rates */
if ucc in (800804,800111,800121,800811,800821,800831,800841,800851,800861)
then ucc_grp = "Cash_Contributions";
if ucc in (700110,002120,800910,800920,800931:800932,800940)/*including auto insurance */
then ucc_grp = "Insurance";


if ucc in (620925,620925,680110,680140,680220,680902,680904,005420,005520,005620,900002,790600,880210,620112,620115,680905,440110,440130,440150,440210,
			/*installation/repair from entertainment*/690320,690330,690340,690350,340610,620320/*photographer*/,670903/*tutor*/,620410 /*pet services*/)/* Needs further investigation */
then ucc_grp = "Misc"; 

if ucc in (680210,680901,210210)/* Services already subject to tax */
then ucc_grp = "Misc_T"; 


Cost_W = Cost * CUID_WT;
Run;


/* Data Transformation */
Proc Summary data=CEX2013_Entries nway;
 	class CUID Interview_Count UCC_GRP;
	var cost cost_w;
	output out=CEX2013_Sums (drop=_:)
			sum = cost cost_w;
Run;
/* Extrapolating expenditures for people who only had 3 interviews */
proc sql;
create table CEX2013_Sums as 
	select*,
	case when Interview_Count=3 then cost*(4/3) else cost end as Ann_cost2,
	case when Interview_Count=3 then cost_W*(4/3) else cost_w end as Ann_costW2
	from CEX2013_Sums
	order by cuid;
quit;
/*Transposing Data */
Proc Transpose  data=CEX2013_Sums
	out=CEX2013_CUExp (drop= _NAME_);
	id UCC_GRP;
	var Ann_cost2; 
	by CUID ;
Run;
/* Combing demographic data with expenditure data by CUID. The merged data set will be used for fusing the intrerview and diary data */
Proc SQL;
Create Table CEX2013_PreGREGWT AS
	Select 	t1.CUID,
			t1.Auto_repair,
			t1.Auto_fees,
			t1.Auto_purchase,
			t1.Gas,
			t1.Auto_rent,
			t1.Auto_finance,
			t1.Auto_lease,
			t1.Auto_admin,
			t1.Food,
			t1.Food_Away,
			t1.public_trans,
			t1.Alttrans,
			t1.Alcohol,
			t1.Apparel,
			t1.Housing,
			t1.Rent,
			t1.Operations,
			t1.babysit,
			/*t1.Water_Trash,*/
			t1.Healthcare,
			t1.Entertainment,
			t1.Boat,
			t1.Personal_Care,
			t1.P_CareServ,
			t1.Reading,
			t1.Edu,
			t1.Cigs,
			t1.Non_Cigs,
			t1.Insurance,
			t1.Cash_Contribu,
			t1.Electricity,
			t1.Natural_Gas,
			t1.Telephone,
			t1.Misc,
			t1.Misc_T,
			t2.Fam_Type,
			t2.Fam_size,
			t2.HH_CU_Q,
			t2.INCLASS5,
			t2.INCLASS5sal,
			t2.Edu_Level,
			t2.fsalaryx,
			t2.FINCBTAX,
			t2.FINCBTXM,
			t2.married,
			t2.data_num,
			t2.age_group,
			t2.max_age,
			t2.sex_ref,
			t2.married_own,
			t2.Owned,
			t2.college_own,
			t2.FoodStamps,
			t2.CUID_WT
	From CEX2013_CUExp as t1, FMLI13_4Int as t2
	Where t1.CUID = t2.CUID AND t2.INTERI = 5
order by Cuid;
QUIT; 
proc sort data=CEX2013_PreGREGWT;
   by cuid;
run;
/* Deleting duplicates. The merge caused 406 record to be duplicated for unkown reasons. Given the data looks identical, I deleted duplicate CUIDs. 
   https://communities.sas.com/t5/SAS-Procedures/Delete-duplicate-rows-if-two-variables-match/td-p/39453
   ^^^ may provide insight into what caused the duplicates. */
data CEX2013_PreGREGWT;
   set CEX2013_PreGREGWT;
   by cuid;
  if last.cuid;
run;

proc sort data=CEX2013_PreGREGWT;
   by cuid;
run;


/* Changing character variable to numeric for later regression matching */
DATA CEX2013_PreGREGWT;
set CEX2013_PreGREGWT;
	char_var = married;
	married_d = input(char_var, 1.);
	Gender = input(orig, 1.);
	female = gender - 1;
	count = input(data_num, 1.);
	education = input(edu_level, 1.);
	diary = 0;
run;
/* REWEIGHTING */
/* The Macro used, Greg Weight, is a proprietary function that
I'm not allowed to share. The code below is intended to demonstrate the process */

/* Inputting North Carolina Census data to 
set benchmarks for reweighting CEX data */

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
	Input INCLASS5 $ Inc_CUs;
	Datalines;
1 1238254
2 1333827
3 1271566
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
Data Income;
	Input INCLASS5 $ money;
	Datalines;
1 20499294970
2 64201094991
3 174884829810
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

%GREGWT(UNITDSN=CEX2013_PreGREGWT, OUTDSN=CEX2013_PostGREGWT, 
         INWEIGHT=CUID_WT, WEIGHT=FINLWT_NCR,
         B1DSN=Fam_Type_NC, B1CLASS=Fam_Type, 
         B1TOT=NC_Families, 
		 B2DSN=Tot_Elec, B2CLASS=Data_num, 
         B2VAR=Electricity, B2TOT=Elec,
	     B3DSN=Income_CUS, B3CLASS=INCLASS5, 
         B3TOT=Inc_CUs,
		 B4DSN=Age_Groups, B4CLASS=AGE_GROUP,
		 B4VAR=max_age, B4TOT=total_age,
		 B5DSN=Mar_Tot, B5CLASS=Married, 
         B5TOT=Mar_Tot,
		 B6DSN=CollegeHome, B6CLASS=college_own, 
         B6TOT=Col_CUs,
		 B7DSN=Edu_Groups, B7CLASS=Edu_Level, 
         B7TOT=HH,
		 B8DSN=Edu_Inc, B8CLASS=Edu_Level, 
         B8VAR=fsalaryx, B8TOT=Edu_TotInc,
		 B9DSN=HomeOwner, B9CLASS=Owned, 
         B9TOT=Homes,
		 B10DSN=Income, B10CLASS=INCLASS5, 
         B10VAR=fincbtxm, B10TOT=money,
		 LOWER=100, UPPER=10000, EPSILON=0.02,
         ID=_ALL_)
		 run;
/* If rerunning the code w/o Greg Weight Macro, substitute FINLWT_NCR with cuid_wt */

proc sort data=CEX2013_PostGREGWT;
by FINLWT_NCR; run;
proc means data=CEX2013_PostGREGWT N;
	var FINLWT_NCR;
run;
/*Creating Percentile by weight. Percentile used later for matching */
data CEX2013_PostGREGWT;
set CEX2013_PostGREGWT;
	rownum = _N_;
	Percentile = rownum/3365;
run;
/*Deleting datasets */
proc datasets nolist;
delete Benout1 Benout2 Benout3 Benout4 Benout5 Benout6 Benout7 Benout8 Benout9 Age_groups collegehome cuid edu_groups edu_inc homeowners marryown mar_tot missing sex_inc tot_inc tot_elec _byout_ _extout_ ;
quit;run;

proc univariate data=FMLI13_4Int;
	var fincbtax fincbtxm;
run;
proc means data=CEX2013_PostGREGWT mean;
	var fincbtax fincbtxm;
	weight FINLWT_NCR;
run;

Proc Sql;
  Create Table problem AS
	Select *
	from CEX2013_PostGREGWT
	having cuid = 260451 or cuid = 279187;
quit;


/* NAICS Industries - Cascading Taxes */
/* Compiling broader categories to correspond to NAICS categories.
These categories will be used later to compute cascading taxes 
The steps to preparing this data are essentially the same as preparing the expenditure data*/

DATA NAICS (KEEP = NEWID CUID INTERI INCLASS5 INCLASS5sal Interview_count UCC UCC_GRP Cost_W Cost CUID_WT);
  MERGE FMLI13_4Int   (IN = INFAM)
        EXPEND_ANN (IN = INEXP);
  BY NEWID;
  IF INEXP AND INFAM;
  IF UCC IN (000001:999999);
  IF COST = .  THEN 
     COST = 0;

if ucc in (190904,200900,360110,360120,360320,360901,360902,370110,370212,370311,370314,370902:370904,380311,380510,380902:380903,390110,390223,390901,390902,410110,430120,440130,
           440150,440900,640130,600121,600132,450110,450210,460110,460901,450220,460902,460903, 450900,470111:470212,510901:510902,850300,450310:450414,
		   290110,290120,290210,290310,290320,290410,290420,290430,290440,320111,300211:300212,300221:300222,300331:300332,300411:300412,320330,
            320120,320901,690111,690117,690119,690120,690115:690116,690210,690230,690241:690245,280110,280120,280130,280210,280220,280230,280900,
			230117,230118,300111,300112,300216,300217,300311,300312,300321,300322,320511,320512,320310,320320,320330,320340,320350,320360,320370,320521,320522
			260211,260212,260213,260214,250111:250114,250211:250214,250911:250914,340520,340620,340630,690113:690114,
  			690310,270211:270214, 270411:270414, 270901:270904,310311,310316,310140,270310,620930,310210,310231,310240,310400,310314,310320,310334,310340,310350,340905,
		    610130,620904,610320,610140,610120,600122,600141,600142, 520901,600310,600901,600902,
			610210,620330,610230,680310,670110,670210,670410,670903,670901,670902,630110,630210,600110)
then ucc_grp = "Retail";

if ucc in (530110,530411,530901,530902)
then ucc_grp = "N_Tran";

if ucc in (270101:270106,690114)
then ucc_grp = "Info";

if ucc in (700110,002120,580903,580905,580400,580906,220121:220122,350110,
		   340901,340907:340908,990900,340904,440140,520511:520905,340902,340905,620904,620912,
			620917,620918,520904,520907,620909,620919,620906,620921,620922,620908,620905,680320,680210
			680220)
then ucc_grp = "Fin";

if ucc in (680110,680902) /*Legal & accounting services*/

then ucc_grp = "Pro";


if ucc in (670110,670210,670410,670901,670902,580111:580116,580312,580904,580906,580311,
			580901,580907,580903,580905,580400,560110,560210,560310,560400,560330,570111,570240,
			570220,570230,540000,550110,550340,640430, 550320,550330,570901,570903)
then ucc_grp = "edu_he";

if ucc in (610900,620111,620122,620211:620214,620221,620222,620310,620903,680310,210210,
			190901:190903,790430,800700)
then ucc_grp = "ent";

if ucc in (270311,470220:490900,520410,340212,340210,340906,340910,440110,
			340310,340410,340420,340520,340903,340620,340630,340901,690310,
			 690320,690330,690340,690350,620320,670903,680140,680904,620410)
then ucc_grp = "other";

Cost_W = Cost * CUID_WT;
Run;
Proc Summary data=NAICS nway;
 	class CUID Interview_Count UCC_GRP;
	var cost cost_w;
	output out=NAICS_Sums (drop=_:)
			sum = cost cost_w;
Run;
/* Extrapolating expenditures for people who only had 3 interviews */
proc sql;
	create table NAICS_Sums as 
	select*,
	case when Interview_Count=3 then cost*(4/3) else cost end as Ann_cost2,
	case when Interview_Count=3 then cost_W*(4/3) else cost_w end as Ann_costW2
	from NAICS_Sums
	order by cuid;
quit;
/*Transposing Data */
Proc Transpose  data=NAICS_Sums
	out=NAICS_CUExp (drop= _NAME_);
	id UCC_GRP;
	var Ann_cost2; 
	by CUID ;
Run;
proc sql;
Create Table NAICS_PreGREGWT AS
	Select 	t1.CUID,
			t1.Retail,
			t1.N_Tran,
			t1.Info,
			t1.Fin,
			t1.Pro,
			t1.edu_he,
			t1.ent,
			t1.Other,
			t2.CUID_WT
From NAICS_CUExp as t1, FMLI13_4Int as t2
Where t1.CUID = t2.CUID AND t2.INTERI = 5
order by Cuid;
QUIT; 

proc sort data=CEX2013_PostGREGWT;
   by cuid;
run;
/*Merging cascading columns */
DATA CEX2013_PostGREGWT;
  MERGE CEX2013_PostGREGWT
        NAICS_PreGREGWT;
  BY CUID;
run;
data CEX2013_PostGREGWT;
   set CEX2013_PostGREGWT;
   by cuid;
  if last.cuid;
run;
