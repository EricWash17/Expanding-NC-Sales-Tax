/* Wizard Import Use.csv */

/* Excluding international trade and scraps */
data use;
set use;
	if _n_ >= 16 then delete;
run;
/* n{i}/sum(of n[*]) = the percent value of an input into an industry.
In other words the percentage value of a car that comes from steel.
.3744353 is the amount of sales taxes that come from businesses 
Multplying together to later find the tax exclusive value. */
data use_adj;
set use (drop = total__output);
	array n {*} _numeric_;
	do i=1 to dim(n);
 		n{i} = (n{i}/sum(of n[*])* 0.3744353244);
 		end;
	drop i;
run;

proc sort data = use;
	by name;
run;
/* NC's GDP for the industries in the Use table. */
Data NC_GDP;
Input GDP;
Datalines;
0.029
0.025
0.025
0.026
0.026
0.030
0.019
0.045
0.001
0.025
0.026
0.025
0.021
0.026
0.026
;run;

proc contents data = use position short;
run;

%let vars = Agriculture Mining Utilities Construction Manufacturing Wholesale Retail 
Transportation Information Finance Professional Education_Healthcare Entertainment 
Other Government Final_Use; run;

/* Adjusting the I/O table to reflect NC's economy 
i.e multiplying each industry (row) by NC GDP*/
data nc_use;
set NC_GDP; 
set use (drop = total__output);
array n {*} &vars;
	do i=1 to dim(n);
 		n{i} = n{i}*Gdp;
 		end;
	drop i GDP;
run;
proc sort data = use_adj;
by name; run;

proc sort data = nc_use;
by name; run;
/* Merging two tables to multiply the corresponding values */
data combo;
merge use_adj nc_use(rename=(Agriculture = Agriculture_nc Mining = Mining_nc Utilities = Utilities_nc
					 Construction = Construction_nc Manufacturing = Manufacturing_nc Wholesale = Wholesale_nc
					 Retail = Retail_nc Transportation = Transportation_nc Information = Information_nc
                     Finance = Finance_nc Professional = Professional_nc Education_Healthcare = Education_Healthcare_nc
					 Entertainment = Entertainment_nc Other = Other_nc Government = Government_nc Final_Use = Final_Use_nc));
by Name;
run;
proc contents data = tax position short;
run;
%let vars_nc = Agriculture_nc Mining_nc Utilities_nc Construction_nc Manufacturing_nc Wholesale_nc Retail_nc 
			   Transportation_nc Information_nc Finance_nc Professional_nc Education_Healthcare_nc Entertainment_nc Other_nc 
               Government_nc Final_Use_nc;
run;
/* Multiplying tables */
data tax;
set combo; 
array v {*} &vars;
array nc{*} &vars_nc;
	do i=1 to dim(v);
 		v{i} = v{i}*nc{i};
 		end;
	drop i &vars_nc;
run;
proc sort data = tax;
by name; run;

data rate;
merge combo(keep = name &vars_nc) tax;
by name;
run;

data rate;
set rate; 
array v {*} &vars;
array nc{*} &vars_nc;
	do i=1 to dim(v);
 		v{i} = nc{i}/(nc{i}-v{i})-1;
 		end;
	drop i &vars_nc;
run;
/* Rates passed onto consumers. 
NC Businesses only charged for Utilities and Informatin services */
data  rate;
set rate;
where name = "Utilities" or name = "Information";
run;
/* Summing down columns to determine amount paid passed onto consumers
by each industry */
proc means data = rate noprint;
	vars retail Transportation information finance 
		 professional education_healthcare entertainment other;
	output out = exp sum = retail Transportation information finance 
		 professional education_healthcare entertainment Other;
run;

/* Saving Rates to apply to consumer expenditure data */
data _null_;
	set rate;
	call symput('retail',retail);
	call symput('trans',Transportation);
	call symput('pro',professional);
	call symput('edu',education_healthcare);
	call symput('finance',finance);
	call symput('ent',entertainment);
	call symput('other',other);
run;
