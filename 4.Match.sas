proc sort data=CEX2013_PostGREGWT;
   by cuid;
run;


/* creating parition groups in Interview */
DATA CEX2013_PostGREGWT;
set CEX2013_PostGREGWT;
	if fam_size < 5 then famsize = fam_size; else famsize = 5;/* Topcoding famisize at 5 to allow for suffecient N within each partition group.*/  
	if fam_type = 1 then grp = 1; /*Married Couple only*/
	else if fam_type = 2 and famsize = 3 then grp = 2; /*Married Couple w/ one child under 6 years old*/
	else if fam_type = 2 and famsize = 4 or famsize = 5  then grp = 3; /* Married Couple w 2 or 3+ children all under 6 years old */
	else if fam_type = 3 and famsize =3 then grp = 4; /*Married Couple with one child between 6 & 17 years old */
	else if fam_type = 3 and famsize =4  then grp = 5; /* Married Couple, two children with the oldest being between 6 & 17 years old */
	else if fam_type = 3 and famsize =5 then grp = 6; /* Married Couple, 3+ children with the oldest being between 6 & 17 years old */
	else if fam_type = 4 and famsize =3 then grp = 7; /*Married Couple with one child older than 17 years old */
	else if fam_type = 4 and famsize =4  then grp = 8; /*Married Couple, two children with the oldest child > 17 years old */
	else if fam_type = 4 and famsize =5 then grp = 9; /*Married Couple, 3+ children with the oldest child > 17 years old */
	else if fam_type = 5 and famsize = 3 then grp = 10; /*All other Married Couple CUs with famsize = 3*/
	else if fam_type = 5 and famsize =4  then grp = 11; /*All other Married Couple CUs with famsize = 4*/
	else if fam_type = 5 and famsize =5 then grp = 12; /*All other Married Couple CUs with famsize = 5+*/
	else if fam_type = 6 or fam_type = 7 and famsize = 2 then grp = 13; /* Single parent with one child under 18 */
	else if fam_type = 6 or fam_type = 7 and famsize = 3 then grp = 14; /* Single parent with two children under 18 */
	else if (fam_type = 6 or fam_type = 7) and (famsize = 4 or famsize = 5) then grp = 15;/* Single parent with 3 or 4+ children under 18 */
	else if fam_type = 8 then grp = 16; /* Single Consumers */
	else if fam_type = 9 and famsize = 2 then grp = 17; /* Other CUs with famsize = 2 */
	else if fam_type = 9 and famsize = 3 then grp = 18; /* Other CU with famsize = 3 */
	else if fam_type = 9 and famsize = 4 then grp = 19; /* Other CU with famsize = 4 */
	else if fam_type = 9 and famsize = 5 then grp = 20; /* Other CU with famsize = 5 */
run;

/* Cross Tab of groups */
proc tabulate
data=CEX2013_PostGREGWT format=comma16.;
	var cuid;
	class fam_type famsize;
	table fam_type*cuid, famsize*(n);
run;
/* I want to include house payments (mortgage or rent vs owning outright) in the matching process since they are such large expenditures. 
   But unfortunately the small numbers in the table below seem to prohibit partioning by ownership status. As an alternative we could sort by ownership status when matching. 
  (i.e. sort by partition group, household income, home ownership status, and random number). 
  ^^^ would not be perfect (i.e. some renters would be matched with outright homeowners) but it would be better than not including ownership at all imo.
  It might also be a good idea to use CUID_Wt instead of random numer. CUID_WT and the GregWeight have a correlation of .28, which is lower than I expected.  */ 
  
proc tabulate
data=CEX2013_PostGREGWT format=comma16.;
	var cuid;
	class grp owned;
	table grp*cuid, owned*(n);
run;

proc sort data=diary2013_PostGREGWT;
   by cuid;
run;

/* creating parition groups in Diary */
DATA diary2013_PostGREGWT;
set diary2013_PostGREGWT;
	if fam_size < 5 then famsize = fam_size; else famsize = 5; /* Topcoding famisize at 5 to allow for suffecient N within each partition group.*/  
	if fam_type = 1 then grp = 1; /*Married Couple only*/
	else if fam_type = 2 and famsize = 3 then grp = 2; /*Married Couple w/ one child under 6 years old*/
	else if fam_type = 2 and famsize = 4 or famsize = 5  then grp = 3; /* Married Couple w 2 or 3+ children all under 6 years old */
	else if fam_type = 3 and famsize =3 then grp = 4; /*Married Couple with one child between 6 & 17 years old */
	else if fam_type = 3 and famsize =4  then grp = 5; /* Married Couple, two children with the oldest being between 6 & 17 years old */
	else if fam_type = 3 and famsize =5 then grp = 6; /* Married Couple, 3+ children with the oldest being between 6 & 17 years old */
	else if fam_type = 4 and famsize =3 then grp = 7; /*Married Couple with one child older than 17 years old */
	else if fam_type = 4 and famsize =4  then grp = 8; /*Married Couple, two children with the oldest child > 17 years old */
	else if fam_type = 4 and famsize =5 then grp = 9; /*Married Couple, 3+ children with the oldest child > 17 years old */
	else if fam_type = 5 and famsize = 3 then grp = 10; /*All other Married Couple CUs with famsize = 3*/
	else if fam_type = 5 and famsize =4  then grp = 11; /*All other Married Couple CUs with famsize = 4*/
	else if fam_type = 5 and famsize =5 then grp = 12; /*All other Married Couple CUs with famsize = 5+*/
	else if fam_type = 6 or fam_type = 7 and famsize = 2 then grp = 13; /* Single parent with one child under 18 */
	else if fam_type = 6 or fam_type = 7 and famsize = 3 then grp = 14; /* Single parent with two children under 18 */
	else if (fam_type = 6 or fam_type = 7) and (famsize = 4 or famsize = 5) then grp = 15;/* Single parent with 3 or 4+ children under 18 */
	else if fam_type = 8 then grp = 16; /* Single Consumers */
	else if fam_type = 9 and famsize = 2 then grp = 17; /* Other CUs with famsize = 2 */
	else if fam_type = 9 and famsize = 3 then grp = 18; /* Other CU with famsize = 3 */
	else if fam_type = 9 and famsize = 4 then grp = 19; /* Other CU with famsize = 4 */
	else if fam_type = 9 and famsize = 5 then grp = 20; /* Other CU with famsize = 5 */
run;

/* Row binding the diary and interview matricies for future matching */

data rbind; 
set CEX2013_PostGREGWT (drop=Edu_Level) diary2013_PostGREGWT;
run; 

/* Diary & Interview Comparison */
proc univariate data=rbind;
	class diary;
	var grp;
	histogram;
run; /* The partitioned distributions look similar for both data sets */

proc univariate data=rbind;
	class diary;
	var FINLWT_NCR;
	histogram;
run;


/* Creating duplicate combined data set and setting NA values eq to zero */
data _rbind_; 
retain cuid diary grp fincbtxm Perccentile housing_d operations_d food_d;
set rbind;
drop count fam_size female married_num married_own orig gender char_var;
array expend Auto_repair Auto_fees Auto_purchase Gas Auto_rent Auto_finance Utility
	Auto_lease Auto_admin Food Food_Away public_trans Alttrans Alcohol Apparel Housing
	Rent Operations babysit Water_Trash Healthcare Entertainment Boat Personal_Care P_CareServ
	Reading Edu Cigs Non_Cigs Insurance Cash_Contribu Electricity Natural_Gas telephone Misc Misc_t
	Retail N_Tran Info Fin Pro edu_he ent Other footdstamps Trans;
do over expend;
	if (expend =. or expend < 0) then expend = 0;
end;
	If Beer_d = . then Beer = 0; If Wine_d = . then Wine = 0; If Spirit_d = . then Spirit = 0;If Soda_Candy_d = . then Soda_Candy = 0;
run;
 
/*Macro for matching*/
/* Organizing data such that the households from the interview
data set assume the average diary expenditures from the households above and below them.
The groups are organized by household size and type, income, and weight */

%macro match(x,y);
proc sort data=_rbind_;
	by descending grp descending fincbtxm descending Percentile; 

data _rbind_;
set _rbind_;
	by descending grp descending fincbtxm descending Percentile;
	retain BackWard;
	if first.&x then BackWard=.;
	if &x ne . then BackWard=&x;

proc sort data=_rbind_;
by grp fincbtxm Percentile;

data _rbind_;
 set _rbind_;
	by grp fincbtxm Percentile;
	retain ForWard;
	if first.&x then ForWard=.;
	if &x ne . then ForWard=&x;

data _rbind_ (drop=ForWard BackWard);
set _rbind_;
	if first.grp then backward=.;
	if last.grp then forward = .;
	if &x ne . then &y= &x;
	else &y=((ForWard+backWard)/2);
	if &y eq . then &y = ((ForWard+backWard)/2);  

proc sort data=_rbind_;
by cuid;
%mend match;

/* Using Macro */
data _rbind_; set _rbind_;
	%match(Food_d, _Food_);
	%match(Soda_Candy_d, _SodaCandy_);
	%match(Beer_D, _Beer_);
	%match(Wine_D, _Wine_);
	%match(Spirit_D, _Spirit_);
	%match(Housing_D, _Housing_);
	%match(Operations_D, _Operations_);
	%match(Food_Away_D, _Food_Away_);
	%match(Apparel_D, _Apparel_);
	%match(Healthcare_D, _Healthcare_);
	%match(Entertain_D, _Entertainment_);
	%match(Education_D, _Edu_);
	%match(Auto_repair_D, _Auto_Repair_);
	%match(Auto_fees_D, _Auto_Fees_);
	%match(AltTrans_D, _AltTrans_);
	%match(Personal_D, _PCare_);
	%match(Misc_D, _Misc_);
	%match(restaurant_d, _restaurant_)
	%match(Retail_D, _retail_)
	%match(N_Trans_D, _Trans_)
	%match(ent_D, _ent_)
	%match(Other_D, _Other_);
	run;

data _rbind_; 
retain cuid diary grp fincbtxm Perccentile housing_d _Housing_ operations_d _Operations_ food_d _Food_;
set _rbind_;
array expend _Food_ _SodaCandy_ _Beer_ _Wine_ _Spirit_ _Housing_ _Operations_ _Food_Away_
	_Apparel_ _Healthcare_ _Entertainment_ _Edu_ _Auto_Repair_ _Auto_Fees_ _AltTrans_ _PCare_ _Misc_ _restaurant_ Food
	_retail_ _Trans_ _ent_ _Other_;
do over expend;
	if (expend =. or expend < 0) then expend = 0;
end;
run;
/* Duplicate check. No duplicates. */
proc sql;
create table cuid as
select cuid,
n(cuid) as count
from _rbind_
group by cuid 
order by cuid desc;quit;


/* Deleting diary entries */
data combined;
set _rbind_;
by cuid;
if diary = 1 then delete;/* deleting diary observation */
run; 

/* Fusing data */
Data Fused (drop=Auto_fees_D Auto_repair_D healthcare_d Housing_D Food_Away_D Food_D Apparel_D Entertainment_D 
Education_D Misc_D Public_D Personal_D Beer_D Wine_D Spirit_D Beer Wine Spirit Retail_D N_Trans_D ent_d Other_D);
set combined;
	Operations = Operations + _Operations_;
	Housing = housing + _housing_;
	Soda_Candy = Soda_Candy + _SodaCandy_;
	Food = food + _food_;
	Food_Away = Food_Away + _Food_Away_;
	Beer = Beer + _Beer_;
	Wine = Wine + _Wine_;
	Spirit = Spirit + _Spirit_;
	Apparel = Apparel + _Apparel_;
	Healthcare= healthcare + _healthcare_;
	Entertainment = entertainment + _entertainment_;
	Edu = edu + _edu_;
	Misc = Misc + _Misc_;
	Alt_trans = AltTrans + _AltTrans_;
	Auto_Repair = Auto_Repair + _Auto_Repair_;
	Auto_fees = Auto_fees + _Auto_fees_;
	P_care = personal_care + _PCare_ ;
	Retail = Retail + _retail_;
	Trans = N_Trans + _Trans_;
	Ent = Ent + _ent_; 
	Other = Other + _Other_;
run;

/* Summing the imputed diary values with the interview values to produce total expenditures for UCC_group*/
Data Compare (drop=Auto_fees_D Auto_repair_D healthcare_d Housing_D Food_Away_D Food_D Apparel_D Entertainment_D 
Education_D Misc_D Public_D Personal_D Beer_D Wine_D Spirit_D Beer Wine Spirit _retail_ _Trans_ N_Trans _ent_ _Other_);
set fused;
	Utility = Electricity + Natural_Gas + Telephone;
	Housing = housing + Operations + Rent + babysit + utility;
	Food = food + _SodaCandy_;
	Food_Away = Food_Away + _restaurant_;
	Tot_Food = Food + Food_Away; 
	Entertainment = entertainment + boat;
	Misc = Misc + misc_t;
	Auto = Auto_rent + Auto_fees + Auto_repair;
	Auto_P = Auto_purchase + Auto_finance + Auto_lease;
	Public_trans = Alt_Trans + public_trans;
	Transportation = Auto + Gas + Auto_p + Public_trans;
	P_care = P_care + P_CareServ;
	Smoke = Cigs + Non_Cigs; 
	Alcohol = Alcohol + _Beer_ + _Wine_ + _Spirit_;
	Total_exp= tot_food + Alcohol + Housing + Apparel + Transportation + Healthcare + Entertainment + P_care + Reading + Edu + Misc + Cash_contribu + Insurance + Smoke;
	Debt = fincbtxm - total_exp;
run;
Data fused 
(drop=Auto_fees_D Auto_repair_D healthcare_d Housing_D Food_Away_D Food_D Apparel_D Entertainment_D Education_D 
Misc_D Public_D Personal_D Beer_D Wine_D Spirit_D Beer Wine Spirit edu_level operations_d restaurant_d soda_candy_d alttrans_d);
set fused;
	Utility = Electricity + Natural_Gas;
	Housing = housing + telephone;
	Auto = Auto_rent + Auto_repair;
	Auto_P = Auto_purchase + Auto_finance + Auto_lease;
run;
proc sql;
create table tot_exp as 
	select cuid,total_exp,debt
	from compare
	order by cuid;
quit;
data fused (drop= _Operations_ _housing_ _SodaCandy_ _food_ _Food_Away_ _Apparel_ _entertainment_ _edu_ _Misc_ _AltTrans_ rownum 
_Auto_Repair_ _Auto_fees_ personal_care _PCare_ Auto_rent Auto_fees Auto_repair Auto_purchase Auto_finance Auto_lease AltTrans Alt Trans);
merge fused tot_exp;
by cuid;
run;

/*Deleting datasets */
proc datasets nolist;
delete Auto_repair_d auto_fees_d Housing_D Food_Away_D Food_D Apparel_D Healthcare_D Entertainment_D Education_D Misc_D AltTrans_D Personal_D Beer_D Wine_D Spirit_D Beer_d Wine_d Spirit_d
Benout1 Benout2 Benout3 Benout4 Benout5 Benout6 Benout7 Benout8 Benout9 Benout10 Age_groups collegehome cuid edu_groups edu_inc homeowners marryown mar_tot missing sex_inc tot_inc tot_elec _byout_ _extout_ 
NAICS NAICS_Sums NAICS_CUExp NAICS_PreGREGWT NAICS2013_Entries NAICS2013_Sums NAICS2013_Sums2 NAICS2013_CUExp NAICS2013_PreGREGWT Income Income_cus Income_exp;
quit;run;
data fused; 
retain cuid;
set fused;
array expend Operations Housing Soda_Candy Food Food_Away Beer Wine Spirit Apparel Healthcare Entertainment
Edu Misc Alt_trans Auto_Repair Auto_fees P_care;
do over expend;
	if (expend =. or expend < 0) then expend = 0;
end;
run;

/* Avergae Expenditure by Category*/

proc means data=compare mean maxdec=2;
var fincbtxm FINCBTAX Total_exp tot_food food_away alcohol housing utility apparel transportation healthcare entertainment p_care reading edu smoke misc misc_t Cash_contribu Insurance;
weight FINLWT_NCR;
run;
proc sort data = _rbind_;
by descending grp descending fincbtxm descending Percentile; ;
run;
