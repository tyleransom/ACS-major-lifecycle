clear all
version 18
set more off
capture log close

log using "analysis_no_adv_deg.log", replace

global datpath "../data/"

* load data
use ${datpath}acs0919cleaned.dta, clear

* keep only undergrads (no advanced degrees)
keep if educd==101

* generate missing indicator for wage
gen mi_wage = incwage==0
tab sex, sum(mi_wage)

* how often are wages imputed?
sum bad_wage, d

* what fraction of sample are FTFY workers?
sum ftfy, d

* generate top 15 most frequent majors
tempfile top15
preserve
    keep cipH incwage ftfy bad_wage
    keep if ftfy & !bad_wage
    collapse (count) freqcip = incwage, by(cipH)
    gsort -freqcip
    gen top15 = _n<=15
    save `top15', replace
restore
merge m:1 cipH using `top15', keep(match master) nogen
tab top15, mi

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

/*
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
*/


*-------------------------------------------------------------------------------
* Graphs: age-earnings profiles by major
* 
* Extensions:
* 1. do analysis in logs
* 2. drop qincwage>0 instances
* 3. focus on full-time, full-year workers
* 4. add foreign_born and more flexible race/sex/survey-year interactions
*-------------------------------------------------------------------------------

reg employed i.cipH              b5.race b1.sex i.year foreign_born, r
local b0 = _b[_cons]
predict empstatresid, resid

reg logwage i.cipH              b5.race b1.sex i.year foreign_born if ftfy & !bad_wage, r
local b0 = _b[_cons]
predict myresid, resid

tempfile coefs
preserve
    drop _all
    set obs 31
    gen cipH = _n
    gen coef = .
    forvalues i = 1/31 {
        local temp : di e(b)[1,`i']
        qui replace coef = `temp' in `i'
    }
    l
    save `coefs', replace
restore

reg logwage i.cipH c.age##c.age b5.race b1.sex i.year foreign_born if ftfy & !bad_wage, r
predict fullresid, resid
predict myxb, xb


* collapse raw earnings by major
tempfile rawmean
preserve
    collapse (median) median_inc = incwage (mean) mean_inc = incwage if top15, by(cipH age)
    replace mean_inc = mean_inc/1000
    save `rawmean', replace
restore

* collapse raw ftfy earnings by major
tempfile rawmeanftfy
preserve
    collapse (median) median_ftfy_inc = incwage (mean) mean_ftfy_inc = incwage if top15 & ftfy & !bad_wage, by(cipH age)
    replace mean_ftfy_inc = mean_ftfy_inc/1000
    save `rawmeanftfy', replace
restore

* collapse residual earnings by major
tempfile residmean
preserve
    collapse (median) median_resid_inc = myresid (mean) mean_resid_inc = myresid if ftfy & !bad_wage & top15, by(cipH age)
    save `residmean', replace
restore

* collapse residual earnings by major -- all (not just top 15)
tempfile residmeanall
preserve
    collapse (median) median_resid_inc = myresid (mean) mean_resid_inc = myresid if ftfy & !bad_wage, by(cipH age)
    save `residmeanall', replace
restore

* collapse fitted vales by major
tempfile xbmean
preserve
    collapse (median) median_xb_inc = myxb (mean) mean_xb_inc = myxb if ftfy & !bad_wage & top15, by(cipH age)
    save `xbmean', replace
restore

* collapse residual empstat by major
tempfile residmeanemp
preserve
    collapse (median) median_resid_emp = empstatresid (mean) mean_resid_emp = empstatresid if top15, by(cipH age)
    save `residmeanemp', replace
restore

* collapse residual empstat by major -- all (not just top 15)
tempfile residmeanempall
preserve
    collapse (median) median_resid_emp = empstatresid (mean) mean_resid_emp = empstatresid , by(cipH age)
    save `residmeanempall', replace
restore

* create a graph where the y-axis is the average earings, the x-axis is age,
* and there is a different-colored or different shaped dot for each major's avg earnings at each age
preserve
    use `rawmean', clear
    * mean
    twoway (scatter mean_inc age if cipH==7, mcolor(midgreen) msymbol(triangle)) (scatter mean_inc age if cipH==15, mcolor(ebblue) msymbol(diamond)) (scatter mean_inc age if cipH==30, mcolor(dkorange) msymbol(square)), ytitle("Average Raw Earnings ($1,000), Including Zeros") xtitle("Age") legend(position(6) rows(1) label(1 "Education") label(2 "Biology") label(3 "Business")) graphregion(color(white%0))
    graph export "../exhibits/avg_earnings_by_major_and_age_no_adv_deg.pdf", replace
    * median
    twoway (scatter median_inc age if cipH==7, mcolor(midgreen) msymbol(triangle)) (scatter median_inc age if cipH==15, mcolor(ebblue) msymbol(diamond)) (scatter median_inc age if cipH==30, mcolor(dkorange) msymbol(square)), ytitle("Median Raw Earnings ($1,000), Including Zeros") xtitle("Age") legend(position(6) rows(1) label(1 "Education") label(2 "Biology") label(3 "Business")) graphregion(color(white%0))
    graph export "../exhibits/med_earnings_by_major_and_age_no_adv_deg.pdf", replace
restore

preserve
    use `rawmeanftfy', clear
    * mean
    twoway (scatter mean_ftfy_inc age if cipH==7, mcolor(midgreen) msymbol(triangle)) (scatter mean_ftfy_inc age if cipH==15, mcolor(ebblue) msymbol(diamond)) (scatter mean_ftfy_inc age if cipH==30, mcolor(dkorange) msymbol(square)), ytitle("Average Raw FTFY Earnings ($1,000)") xtitle("Age") legend(position(6) rows(1) label(1 "Education") label(2 "Biology") label(3 "Business")) graphregion(color(white%0))
    graph export "../exhibits/avg_ftfy_earnings_by_major_and_age_no_adv_deg.pdf", replace
    * median
    twoway (scatter median_ftfy_inc age if cipH==7, mcolor(midgreen) msymbol(triangle)) (scatter median_ftfy_inc age if cipH==15, mcolor(ebblue) msymbol(diamond)) (scatter median_ftfy_inc age if cipH==30, mcolor(dkorange) msymbol(square)), ytitle("Median Raw FTFY Earnings ($1,000)") xtitle("Age") legend(position(6) rows(1) label(1 "Education") label(2 "Biology") label(3 "Business")) graphregion(color(white%0))
    graph export "../exhibits/med_ftfy_earnings_by_major_and_age_no_adv_deg.pdf", replace
restore

preserve
    use `residmean', clear
    * mean
    * all ages
    twoway (scatter mean_resid_inc age if cipH==7, mcolor(midgreen) msymbol(triangle)) (scatter mean_resid_inc age if cipH==15, mcolor(ebblue) msymbol(diamond)) (scatter mean_resid_inc age if cipH==30, mcolor(dkorange) msymbol(square)), ytitle("Average FTFY Log Earnings Residuals") xtitle("Age") legend(position(6) rows(1) label(1 "Education") label(2 "Biology") label(3 "Business")) graphregion(color(white%0))
    graph export "../exhibits/avg_resid_earnings_by_major_and_age_no_adv_deg.pdf", replace
    * age 26+
    twoway (scatter mean_resid_inc age if cipH==7 & age>=26, mcolor(midgreen) msymbol(triangle)) (scatter mean_resid_inc age if cipH==15 & age>=26, mcolor(ebblue) msymbol(diamond)) (scatter mean_resid_inc age if cipH==30 & age>=26, mcolor(dkorange) msymbol(square)), ytitle("Average FTFY Log Earnings Residuals, Age 26+") xtitle("Age") legend(position(6) rows(1) label(1 "Education") label(2 "Biology") label(3 "Business")) graphregion(color(white%0))
    graph export "../exhibits/avg_resid_earnings_by_major_and_age26_no_adv_deg.pdf", replace
    * median
    * all ages
    twoway (scatter median_resid_inc age if cipH==7, mcolor(midgreen) msymbol(triangle)) (scatter median_resid_inc age if cipH==15, mcolor(ebblue) msymbol(diamond)) (scatter median_resid_inc age if cipH==30, mcolor(dkorange) msymbol(square)), ytitle("Median FTFY Log Earnings Residuals") xtitle("Age") legend(position(6) rows(1) label(1 "Education") label(2 "Biology") label(3 "Business")) graphregion(color(white%0))
    graph export "../exhibits/med_resid_earnings_by_major_and_age_no_adv_deg.pdf", replace
    * age 26+
    twoway (scatter median_resid_inc age if cipH==7 & age>=26, mcolor(midgreen) msymbol(triangle)) (scatter median_resid_inc age if cipH==15 & age>=26, mcolor(ebblue) msymbol(diamond)) (scatter median_resid_inc age if cipH==30 & age>=26, mcolor(dkorange) msymbol(square)), ytitle("Median FTFY Log Earnings Residuals, Age 26+") xtitle("Age") legend(position(6) rows(1) label(1 "Education") label(2 "Biology") label(3 "Business")) graphregion(color(white%0))
    graph export "../exhibits/med_resid_earnings_by_major_and_age26_no_adv_deg.pdf", replace
restore

preserve
    use `residmeanemp', clear
    * mean
    * all ages
    twoway (scatter mean_resid_emp age if cipH==7, mcolor(midgreen) msymbol(triangle)) (scatter mean_resid_emp age if cipH==15, mcolor(ebblue) msymbol(diamond)) (scatter mean_resid_emp age if cipH==30, mcolor(dkorange) msymbol(square)), ytitle("Average Pr(work FTFY) Residuals") xtitle("Age") legend(position(6) rows(1) label(1 "Education") label(2 "Biology") label(3 "Business")) graphregion(color(white%0))
    graph export "../exhibits/avg_resid_employed_by_major_and_age_no_adv_deg.pdf", replace
    * age 26+
    twoway (scatter mean_resid_emp age if cipH==7 & age>=26, mcolor(midgreen) msymbol(triangle)) (scatter mean_resid_emp age if cipH==15 & age>=26, mcolor(ebblue) msymbol(diamond)) (scatter mean_resid_emp age if cipH==30 & age>=26, mcolor(dkorange) msymbol(square)), ytitle("Average Pr(work FTFY) Residuals, Age 26+") xtitle("Age") legend(position(6) rows(1) label(1 "Education") label(2 "Biology") label(3 "Business")) graphregion(color(white%0))
    graph export "../exhibits/avg_resid_employed_by_major_and_age26_no_adv_deg.pdf", replace
    * median
    * all ages
    twoway (scatter median_resid_emp age if cipH==7, mcolor(midgreen) msymbol(triangle)) (scatter median_resid_emp age if cipH==15, mcolor(ebblue) msymbol(diamond)) (scatter median_resid_emp age if cipH==30, mcolor(dkorange) msymbol(square)), ytitle("Median Pr(work FTFY) Residuals") xtitle("Age") legend(position(6) rows(1) label(1 "Education") label(2 "Biology") label(3 "Business")) graphregion(color(white%0))
    graph export "../exhibits/med_resid_employed_by_major_and_age_no_adv_deg.pdf", replace
    * age 26+
    twoway (scatter median_resid_emp age if cipH==7 & age>=26, mcolor(midgreen) msymbol(triangle)) (scatter median_resid_emp age if cipH==15 & age>=26, mcolor(ebblue) msymbol(diamond)) (scatter median_resid_emp age if cipH==30 & age>=26, mcolor(dkorange) msymbol(square)), ytitle("Median Pr(work FTFY) Residuals, Age 26+") xtitle("Age") legend(position(6) rows(1) label(1 "Education") label(2 "Biology") label(3 "Business")) graphregion(color(white%0))
    graph export "../exhibits/med_resid_employed_by_major_and_age26_no_adv_deg.pdf", replace
restore

preserve
    use `xbmean', clear
    * all ages
    twoway (scatter mean_xb_inc age if cipH==7, mcolor(midgreen) msymbol(triangle)) (scatter mean_xb_inc age if cipH==15, mcolor(ebblue) msymbol(diamond)) (scatter mean_xb_inc age if cipH==30, mcolor(dkorange) msymbol(square)), ytitle("Average FTFY Log Earnings Fitted Values") xtitle("Age") legend(position(6) rows(1) label(1 "Education") label(2 "Biology") label(3 "Business")) graphregion(color(white%0))
    graph export "../exhibits/avg_xb_earnings_by_major_and_age_no_adv_deg.pdf", replace
    * age 26+
    twoway (scatter mean_xb_inc age if cipH==7 & age>=26, mcolor(midgreen) msymbol(triangle)) (scatter mean_xb_inc age if cipH==15 & age>=26, mcolor(ebblue) msymbol(diamond)) (scatter mean_xb_inc age if cipH==30 & age>=26, mcolor(dkorange) msymbol(square)), ytitle("Average FTFY Log Earnings Fitted Values, Age 26+") xtitle("Age") legend(position(6) rows(1) label(1 "Education") label(2 "Biology") label(3 "Business")) graphregion(color(white%0))
    graph export "../exhibits/avg_xb_earnings_by_major_and_age26_no_adv_deg.pdf", replace
restore


*-------------------------------------------------------------------------------
* Graphs: trade-off between lifetime and early career earnings profile
*-------------------------------------------------------------------------------

* compute frequencies by major
tempfile counts
preserve
    collapse (count) N = myresid if ftfy & !bad_wage, by(cipH)
    save `counts', replace
restore

/*
* compute liftime residualized earnings by major (focusing only on FTFY workers with valid earnings)
tempfile lifetime
preserve
    replace myresid = myresid + 0.5 if ftfy & !bad_wage // to avoid negative values
    collapse (mean) mean_inc = myresid if ftfy & !bad_wage, by(cipH age)
    collapse (sum) lifetime_inc = mean_inc, by(cipH)
    replace lifetime_inc = lifetime_inc
    save `lifetime', replace
    l
restore
*/

* compute growth in average earnings between ages 25-27 and 40-42
tempfile growth
preserve
    replace myresid = myresid + 0.5 if ftfy & !bad_wage // to avoid negative values
    collapse (mean) mean_inc = myresid if ftfy & !bad_wage, by(cipH age)
    reshape wide mean_inc, i(cipH) j(age)
    gen growth = mean_inc40 - mean_inc25
    gen growthavg = (mean_inc40+mean_inc41+mean_inc42)/3 - (mean_inc25+mean_inc26+mean_inc27)/3
    gen lifetime_inc = (mean_inc45+mean_inc46+mean_inc47)/3
    gen initial_inc = (mean_inc25+mean_inc26+mean_inc27)/3
    save `growth', replace
restore

tempfile lifetime_and_growth
preserve
    use `growth', clear
    merge 1:1 cipH using `counts', nogen
    merge 1:1 cipH using `coefs', nogen
    merge 1:1 cipH using `top15', nogen
    save `lifetime_and_growth', replace
restore

* scatter plot of lifetime earnings vs. growth in earnings
use `lifetime_and_growth', clear
reg lifetime_inc initial_inc
reg lifetime_inc initial_inc
reg lifetime_inc initial_inc [fweight=N]
/*
twoway (scatter lifetime_inc growth) , ytitle("Lifetime FTFY Log Earnings Residuals") xtitle("Change in FTFY Log Earnings Residuals, Ages 25-40") legend(off) graphregion(color(white%0))
graph export "../exhibits/lifetime_vs_growth_no_adv_deg.pdf", replace
twoway (scatter lifetime_inc growth [fweight=N], msymbol(Oh)) (lfit lifetime_inc growth [fweight=N] ) , ytitle("Lifetime FTFY Log Earnings Residuals") xtitle("Change in FTFY Log Earnings Residuals, Ages 25-40") legend(off) graphregion(color(white%0)) 
graph export "../exhibits/lifetime_vs_growth_sized_no_adv_deg.pdf", replace
twoway (scatter coef growth [fweight=N], msymbol(Oh)) (lfit coef growth [fweight=N] ) , ytitle("Log Earnings Coefficient") xtitle("Change in FTFY Log Earnings Residuals, Ages 25-40") legend(off) graphregion(color(white%0)) 
graph export "../exhibits/coef_vs_growth_sized_no_adv_deg.pdf", replace
twoway (scatter lifetime_inc growthavg) , ytitle("Lifetime FTFY Log Earnings Residuals") xtitle("Change in FTFY Log Earnings Residuals, Ages 25-27 vs. 40-42") legend(off) graphregion(color(white%0))
graph export "../exhibits/lifetime_vs_avg_growth_no_adv_deg.pdf", replace
twoway (scatter lifetime_inc growthavg [fweight=N], msymbol(Oh)) (lfit lifetime_inc growthavg [fweight=N] ) , ytitle("Lifetime FTFY Log Earnings Residuals") xtitle("Change in FTFY Log Earnings Residuals, Ages 25-27 vs. 40-42") legend(off) graphregion(color(white%0)) 
graph export "../exhibits/lifetime_vs_avg_growth_sized_no_adv_deg.pdf", replace
twoway (scatter coef growthavg [fweight=N], msymbol(Oh)) (lfit coef growthavg [fweight=N] ) , ytitle("Log Earnings Coefficient") xtitle("Change in FTFY Log Earnings Residuals, Ages 25-27 vs. 40-42") legend(off) graphregion(color(white%0)) 
graph export "../exhibits/coef_vs_avg_growth_sized_no_adv_deg.pdf", replace
twoway (scatter lifetime_inc growth if top15, mlabel(cipH)) , ytitle("Lifetime FTFY Log Earnings Residuals") xtitle("Change in FTFY Log Earnings Residuals, Ages 25-40") legend(off) graphregion(color(white%0))
graph export "../exhibits/lifetime_vs_growth_top15_no_adv_deg.pdf", replace
twoway (scatter lifetime_inc growth [fweight=N] if top15, msymbol(Oh) mlabel(cipH)) (lfit lifetime_inc growth [fweight=N] if top15 ) , ytitle("Lifetime FTFY Log Earnings Residuals") xtitle("Change in FTFY Log Earnings Residuals, Ages 25-40") legend(off) graphregion(color(white%0)) 
graph export "../exhibits/lifetime_vs_growth_sized_top15_no_adv_deg.pdf", replace
twoway (scatter coef growth [fweight=N] if top15, msymbol(Oh) mlabel(cipH)) (lfit coef growth [fweight=N] if top15 ) , ytitle("Log Earnings Coefficient") xtitle("Change in FTFY Log Earnings Residuals, Ages 25-40") legend(off) graphregion(color(white%0)) 
graph export "../exhibits/coef_vs_growth_sized_top15_no_adv_deg.pdf", replace
twoway (scatter lifetime_inc growthavg if top15 & !inlist(cipH,7,15,30), mlabel(cipH)) (scatter lifetime_inc growthavg if inlist(cipH,7,15,30), mlabel(cipH) mcolor(blue) mlabcolor(black) mlabgap(0.3cm) mlabpos(12)), ytitle("Lifetime FTFY Log Earnings Residuals") xtitle("Change in FTFY Log Earnings Residuals, Ages 25-27 vs. 40-42") legend(off) graphregion(color(white%0))
graph export "../exhibits/lifetime_vs_avg_growth_top15_no_adv_deg.pdf", replace
twoway (scatter lifetime_inc growthavg [fweight=N] if top15 & !inlist(cipH,7,15,30), msymbol(Oh)) (lfit lifetime_inc growthavg [fweight=N] if top15 ) (scatter lifetime_inc growthavg [fweight=N] if inlist(cipH,7,15,30), msymbol(O) mcolor(blue)) (scatter lifetime_inc growthavg [fweight=N] if inlist(cipH,7,15,30), mlabel(cipH) mcolor(blue) mlabcolor(black) mlabgap(0.3cm) mlabpos(12)) , ytitle("Lifetime FTFY Log Earnings Residuals") xtitle("Change in FTFY Log Earnings Residuals, Ages 25-27 vs. 40-42") legend(off) graphregion(color(white%0)) 
graph export "../exhibits/lifetime_vs_avg_growth_sized_top15_no_adv_deg.pdf", replace
twoway (scatter coef growthavg [fweight=N] if top15 & !inlist(cipH,7,15,30), msymbol(Oh)) (lfit coef growthavg [fweight=N] if top15 ) (scatter coef growthavg [fweight=N] if inlist(cipH,7,15,30), msymbol(O) mcolor(blue)) (scatter coef growthavg [fweight=N] if inlist(cipH,7,15,30), mlabel(cipH) mcolor(blue) mlabcolor(black) mlabgap(0.3cm) mlabpos(12)) , ytitle("Log Earnings Coefficient") xtitle("Change in FTFY Log Earnings Residuals, Ages 25-27 vs. 40-42") legend(off) graphregion(color(white%0)) 
graph export "../exhibits/coef_vs_avg_growth_sized_top15_no_adv_deg.pdf", replace
*/
twoway (scatter lifetime_inc initial_inc if top15 & !inlist(cipH,7,15,30), mlabel(cipH)) (scatter lifetime_inc initial_inc if inlist(cipH,7,15,30), mlabel(cipH) mcolor(blue) mlabcolor(black) mlabgap(0.3cm) mlabpos(12)), ytitle("FTFY Log Earnings Residuals, Ages 45-47") xtitle("FTFY Log Earnings Residuals, Ages 25-27") legend(off) graphregion(color(white%0))
graph export "../exhibits/age46v26_top15_no_adv_deg.pdf", replace
twoway (scatter lifetime_inc initial_inc [fweight=N] if top15 & !inlist(cipH,7,15,30), msymbol(Oh)) (lfit lifetime_inc initial_inc [fweight=N] if top15 ) (scatter lifetime_inc initial_inc [fweight=N] if inlist(cipH,7,15,30), msymbol(O) mcolor(blue)) (scatter lifetime_inc initial_inc [fweight=N] if inlist(cipH,7,15,30), mlabel(cipH) mcolor(blue) mlabcolor(black) mlabgap(0.3cm) mlabpos(12)) , ytitle("FTFY Log Earnings Residuals, Ages 45-47") xtitle("FTFY Log Earnings Residuals, Ages 25-27") legend(off) graphregion(color(white%0)) 
graph export "../exhibits/age46v26_sized_top15_no_adv_deg.pdf", replace



log close
 