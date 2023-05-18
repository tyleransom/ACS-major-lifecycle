version 18
set more off
capture log close

log using "analysis_big.log", replace

global datpath "../data/"

* load data
use ${datpath}acs0919cleaned.dta, clear

* generate missing indicator for wage
gen mi_wage = incwage==0
tab sex, sum(mi_wage)

* how often are wages imputed?
sum bad_wage, d

* what fraction of sample are FTFY workers?
sum ftfy, d

*-------------------------------------------------------------------------------
* Replication
*-------------------------------------------------------------------------------

* wage variables
gen log1pwage = log(1+incwage)
gen logwage   = log(incwage)

* race variable
ren race race_disag
generat race = .
replace race = 1 if hispan==0 & race_disag==1
replace race = 2 if hispan==0 & race_disag==2
replace race = 3 if hispan==1
replace race = 4 if hispan==0 & inrange(race_disag,4,6)
tab race, mi
replace race = 5 if mi(race)

lab def vlrace 1 "Non-Hispanic White" 2 "African American" 3 "Hispanic" 4 "Asian" 5 "Other"
lab val race vlrace
tab race, mi

* descriptive statistics
sum incwage, d
sum log1pwage, d

* initial mincer regressions
local covars c.age##c.age b5.race b1.sex i.year 
reg incwage `covars', r
reg log1pwage `covars', r
predict log1pwage_hat, xb
gen eps = incwage - (exp(log1pwage_hat)-1)
sum eps, d

reg eps i.cipH, r

* average residuals by major
tempfile eps_by_major
preserve
    collapse (mean) mu = eps (sd) sd = eps (mean) raw_mean = incwage, by(cipH)
    gen coef_var = sd/mu
    gsort -mu
    l, sep(0)
    save `eps_by_major', replace
restore

merge m:1 cipH using `eps_by_major', keep(match) nogen

*-------------------------------------------------------------------------------
* Extensions:
* 1. do analysis in logs
* 2. drop qincwage>0 instances
* 3. focus on full-time, full-year workers
* 4. add foreign_born and race/sex/survey-year interactions
*-------------------------------------------------------------------------------

reg logwage i.cipH `covars' foreign_born if ftfy & !bad_wage, r


*-------------------------------------------------------------------------------
* Extensions:
* do everything in a likelihood-based model
*-------------------------------------------------------------------------------
global dumbo cipH
capture program drop normal
program normal
	version 13.1
	args lnf Xb sigma1 sigma2 sigma3 sigma4 sigma5 sigma6 sigma7 sigma8 sigma9 sigma10 sigma11 sigma12 sigma13 sigma14 sigma15 sigma16 sigma17 sigma18 sigma19 sigma20 sigma21 sigma22 sigma23 sigma24 sigma25 sigma26 sigma27 sigma28 sigma29 sigma30 sigma31
	quietly replace `lnf'=( ${dumbo}==1 )*ln(normalden(${ML_y1}, `Xb', `sigma1' ))+ /// 
                          ( ${dumbo}==2 )*ln(normalden(${ML_y1}, `Xb', `sigma2' ))+ ///
                          ( ${dumbo}==3 )*ln(normalden(${ML_y1}, `Xb', `sigma3' ))+ ///
                          ( ${dumbo}==4 )*ln(normalden(${ML_y1}, `Xb', `sigma4' ))+ ///
                          ( ${dumbo}==5 )*ln(normalden(${ML_y1}, `Xb', `sigma5' ))+ ///
                          ( ${dumbo}==6 )*ln(normalden(${ML_y1}, `Xb', `sigma6' ))+ ///
                          ( ${dumbo}==7 )*ln(normalden(${ML_y1}, `Xb', `sigma7' ))+ ///
                          ( ${dumbo}==8 )*ln(normalden(${ML_y1}, `Xb', `sigma8' ))+ ///
                          ( ${dumbo}==9 )*ln(normalden(${ML_y1}, `Xb', `sigma9' ))+ ///
                          ( ${dumbo}==10)*ln(normalden(${ML_y1}, `Xb', `sigma10'))+ ///
                          ( ${dumbo}==11)*ln(normalden(${ML_y1}, `Xb', `sigma11'))+ ///
                          ( ${dumbo}==12)*ln(normalden(${ML_y1}, `Xb', `sigma12'))+ ///
                          ( ${dumbo}==13)*ln(normalden(${ML_y1}, `Xb', `sigma13'))+ ///
                          ( ${dumbo}==14)*ln(normalden(${ML_y1}, `Xb', `sigma14'))+ ///
                          ( ${dumbo}==15)*ln(normalden(${ML_y1}, `Xb', `sigma15'))+ ///
                          ( ${dumbo}==16)*ln(normalden(${ML_y1}, `Xb', `sigma16'))+ ///
                          ( ${dumbo}==17)*ln(normalden(${ML_y1}, `Xb', `sigma17'))+ ///
                          ( ${dumbo}==18)*ln(normalden(${ML_y1}, `Xb', `sigma18'))+ ///
                          ( ${dumbo}==19)*ln(normalden(${ML_y1}, `Xb', `sigma19'))+ ///
                          ( ${dumbo}==20)*ln(normalden(${ML_y1}, `Xb', `sigma20'))+ ///
                          ( ${dumbo}==21)*ln(normalden(${ML_y1}, `Xb', `sigma21'))+ ///
                          ( ${dumbo}==22)*ln(normalden(${ML_y1}, `Xb', `sigma22'))+ ///
                          ( ${dumbo}==23)*ln(normalden(${ML_y1}, `Xb', `sigma23'))+ ///
                          ( ${dumbo}==24)*ln(normalden(${ML_y1}, `Xb', `sigma24'))+ ///
                          ( ${dumbo}==25)*ln(normalden(${ML_y1}, `Xb', `sigma25'))+ ///
                          ( ${dumbo}==26)*ln(normalden(${ML_y1}, `Xb', `sigma26'))+ ///
                          ( ${dumbo}==27)*ln(normalden(${ML_y1}, `Xb', `sigma27'))+ ///
                          ( ${dumbo}==28)*ln(normalden(${ML_y1}, `Xb', `sigma28'))+ ///
                          ( ${dumbo}==29)*ln(normalden(${ML_y1}, `Xb', `sigma29'))+ ///
                          ( ${dumbo}==30)*ln(normalden(${ML_y1}, `Xb', `sigma30'))+ ///
                          ( ${dumbo}==31)*ln(normalden(${ML_y1}, `Xb', `sigma31'))
end

ml model lf normal (logwage = i.cipH `covars' foreign_born ) ///
            /sigma1 /sigma2 /sigma3 /sigma4 /sigma5 /sigma6 /sigma7 /sigma8 /sigma9 /sigma10 /sigma11 /sigma12 /sigma13 /sigma14 /sigma15 /sigma16 /sigma17 /sigma18 /sigma19 /sigma20 /sigma21 /sigma22 /sigma23 /sigma24 /sigma25 /sigma26 /sigma27 /sigma28 /sigma29 /sigma30 /sigma31 ///
            if ftfy & !bad_wage
ml max

log close
 