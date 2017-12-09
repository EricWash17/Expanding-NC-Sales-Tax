/* http://www.dornc.com/taxes/sales/taxrates.html
http://www.dor.state.nc.us/taxes/sales/overview.html 

/*Adjusting Income. Making income equal to the max of expenditures or CEX reported income
Needed because reporting of income is historically undereported and 
that must be the case with many of the observations */

data fused_tax;
set fused;
	if total_exp - debt > fincbtxm then Income = total_exp; else Income = fincbtxm;
run;


proc sort data=fused_tax;
by Income;run;

DATA fused_tax;
set fused_tax;
/* Setting Cap for boat expenditures */
if .03*boat > 1500 then boat_tax = 1500; else boat_tax = .03*boat;

Total_stax = .0693 * (food_away + Alt_Trans + P_care + Alcohol + Apparel + Housing + Entertainment + reading + cigs + non_cigs + telephone + misc_t + Soda_Candy + _Beer_ + _Wine_ + _Healthcare_ + (.85*_restaurant_) /*adjusting for tips */ + auto);
/* Determing taxes paid to the state  */
Total_stax1 = .0475/.0693 * Total_stax;

/* Expenditures subject to 7% state tax only */
Total_stax2 = .07 * (_spirit_ + Utility);
/* Exempting food purchased with food stamps*/
if (food - foodstamps) > 0 then Total_stax2 = Total_stax2 + .02 * (food - foodstamps); else Total_stax2 = Total_stax2;
/*Taxes on Boats and auto purchases */
Total_stax3 = (.03 * Auto_p) + boat_tax;
/*Total sales tax expenditure per household*/
Total_stax = Total_stax + Total_stax2 + Total_stax3;
Wt_Stax = FINLWT_NCR * Total_stax; /*Total weighted tax per observationn*/
/* Total sales tax expenditures paid to the state */
Total_excel = Total_stax1 + Total_stax2 + Total_stax3; 

/* The variables below are used to determine the new revenue neutral rate */
services = operations + P_careserv + Misc;
wt_services = services*FINLWT_NCR;
/* Goods and services currently taxed */
taxable = boat + food_away + Alt_Trans + P_care + Alcohol + Apparel + Housing + Entertainment + reading + edu + cigs + non_cigs + telephone + misc_t + Soda_Candy + _Beer_ + _Wine_ + _Healthcare_ + (.85*_restaurant_) + auto;
wt_taxable = FINLWT_NCR*taxable;
/* Tax expenditures from boats and cars */
caps = .03*auto_p + boat_tax;
wt_caps_tax = caps * FINLWT_NCR;
/* Total expenditures from Boats and Cars. These variables are used to determine the 
revenue neutral rate for cars and boats if they were taxed at the standard rate */
adj_caps = auto_p + boat;
wt_adj_caps = adj_caps*FINLWT_NCR;
wt_gov_tax = Total_stax2*FINLWT_NCR;

/* Excise Taxes. Computed using the BLS average price*/
/* i.e beer is taxed at 61.7 cents per gallon --> .0617/avg. beer price per gallon */
Beer_excise = _beer_ * .06283836;
Wine_excise = _wine_ * .02285632;
Spirit_excise = _spirit_ * .30;
Alcohol_Excise = Alcohol * .06283836;
Alcohol_Excise = Beer_excise + Wine_excise + Spirit_excise + Alcohol_Excise;

cigs_excise = Cigs * .082568807;
NonCigs_excise = Non_Cigs * .128;
smoke_excise = Cigs_excise + NonCigs_excise;

Gas_Excise = Gas * 0.117398841;

Total_excise = smoke_excise + Gas_Excise + Alcohol_Excise;
wt_excise = Total_excise*FINLWT_NCR;

/* Cascading Taxes */
Retail_Cas = &retail.  * Retail;
Trans_cas = &trans. * Trans;
Pro_cas =  &pro. * (Pro);
Edu_Cas =  &edu. * (edu_he);
Fin_cas = &finance. * fin;
ent_cas = &ent. * ent;
other_cas = &other. * other;

Cascade = Retail_Cas + Pro_cas + Edu_Cas + Fin_cas + ent_cas + other_cas;

WT_Cascade = FINLWT_NCR*Cascade;

/* Totals */
total_tax = Total_Stax + Total_excise + Cascade;

wt_total = total_tax*FINLWT_NCR;
wt_income = income * FINLWT_NCR;

Incidence = Total_tax/(Income);
Incidence_excise = Total_excise/(income);
incidence_stax = Total_Stax/income;
incidence_cascade = Cascade/income;

drop NonCigs_excise cigs_excise;
type = 1;
/* Creating Income Deciles */
rownum = _N_;
Percentile = rownum/3365;
if percentile < .1 then decile = 1; 
	else if percentile < .2 then decile = 2; else if percentile < .3 then decile = 3; else if percentile < .4 then decile = 4;
	else if percentile < .5 then decile = 5; else if percentile < .6 then decile = 6; else if percentile < .7 then decile = 7;
	else if percentile < .8 then decile = 8; else if percentile < .9 then decile = 9; else if percentile <= 1 then decile = 10;
run;
proc sort data=fused_tax;
by decile;
proc univariate data=fused_tax;
var Total_stax;
weight FINLWT_NCR;
run;
Proc means data=fused_tax;
var Income total_exp incidence fincbtxm;
by decile;
weight FINLWT_NCR;
run;
Proc means data=fused_tax sum;
var Total_excel;
weight FINLWT_NCR;
run;

data excel(keep = cuid type  WT_Cascade Wt_Stax wt_excise wt_caps_tax wt_gov_tax wt_adj_caps wt_services wt_taxable wt_total wt_income wt_exp FINLWT_NCR);
set fused_tax;
run;
/* Summing weighted total to find new rev neutral rates */
PROC SQL;
CREATE TABLE Opt AS
	SELECT
	SUM(Wt_Stax) format=comma15. as StaxRev,
	Sum(wt_services) format=comma15. as Services,
	Sum(wt_taxable) format=comma15. as TOT_goods,
	Sum(WT_Cascade) format=comma15. as Cascade,
	Sum(wt_excise) format=comma15. as Excise,
	Sum(wt_caps_tax) format=comma15. as Caps,
	Sum(wt_gov_tax) format=comma15. as Utilities,
	Sum(wt_adj_caps) format=comma15. as No_Caps
from excel
group by type
order by type;
quit;
/* Solving for the new revenue neutral tax rates */
data opt;
set opt;
r_1 = (StaxRev -  Caps - Utilities)/(Services + TOT_goods); /* Tax services */
r_2 = (StaxRev -  Utilities)/(Services + TOT_goods + No_Caps); /*Tax services and tax cars and boats at standard rate */
r_3 = (StaxRev +  Cascade - Caps - Utilities)/(Services + TOT_goods); /*Tax services and exempt all business-to-business transactions */ 
r_4 = (StaxRev +  Cascade - Utilities)/(Services + TOT_goods + No_Caps);/*Tax services, tax cars and boats at standard rate, exempt all business-to-business transactions */
run;
/* Saving new tax rates to global env. */
data _null_;
	set opt;
	call symput('NTR1',r_1);
	call symput('NTR2',r_2);
	call symput('NTR3',r_3);
	call symput('NTR4',r_4);
run;


/* Calculating reformed incidence*/
data tax;
set fused_tax;

total_a = (taxable + services)* &NTR1. + caps + Total_stax2 + Total_excise + Cascade;
total_b = (taxable + services + adj_caps) * &NTR2. + Total_stax2 + Total_excise + Cascade;

incidence_a = total_a/(income);
incidence_b = total_b/(income);
run;
/* Incidence by decile */
proc means data=tax mean min max;
var incidence_a incidence_b incidence incidence_stax Incidence_excise Incidence_cascade income;
class decile;
weight FINLWT_NCR;
run;
/* Total Sales Tax Revenue by Decile */
proc means data=tax sum;
var Total_Stax Total_excise Cascade;
class decile;
weight FINLWT_NCR;
run;


