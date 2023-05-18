clear all
version 18
set more off
capture log close

log using "max_like_tester.log", replace


sysuse nlsw88, clear
gen lnwage = ln(wage)
gen occ_agg = occ
recode occ_agg (9 10 11 12 = 13)
*replace occ_agg = 9 if occ_agg==13

*--------------------------------------
* Program to run with ml max that allows variance to be different across wage types
*--------------------------------------
global dumbo occ_agg
levelsof ${dumbo}, local(dumbolevels)
di `dumbolevels'
di "`dumbolevels'"
foreach i of local dumbolevels {
    di `i'
}
global dumbolevels = "`dumbolevels'"
di $dumbolevels

capture program drop normal
program normal
	version 13.1
	args lnf Xb sigma1 sigma2 sigma3 sigma4 sigma5 sigma6 sigma7 sigma8 sigma13
	quietly replace `lnf'=( ${dumbo}==1 )*ln(normalden(${ML_y1}, `Xb', `sigma1'))+ /// 
                          ( ${dumbo}==2 )*ln(normalden(${ML_y1}, `Xb', `sigma2'))+ ///
                          ( ${dumbo}==3 )*ln(normalden(${ML_y1}, `Xb', `sigma3'))+ ///
                          ( ${dumbo}==4 )*ln(normalden(${ML_y1}, `Xb', `sigma4'))+ ///
                          ( ${dumbo}==5 )*ln(normalden(${ML_y1}, `Xb', `sigma5'))+ ///
                          ( ${dumbo}==6 )*ln(normalden(${ML_y1}, `Xb', `sigma6'))+ ///
                          ( ${dumbo}==7 )*ln(normalden(${ML_y1}, `Xb', `sigma7'))+ ///
                          ( ${dumbo}==8 )*ln(normalden(${ML_y1}, `Xb', `sigma8'))+ ///
                          ( ${dumbo}==13)*ln(normalden(${ML_y1}, `Xb', `sigma13'))
end

/*
capture program drop normal
program normal
    version 13.1
    local argy = "" 
    foreach i in 1 2 3 4 5 6 7 8 13 {
        local argy = "`argy' sigma`i'"
    }
    di "`argy'"
    args lnf Xb `argy'
    quietly replace `lnf' = 0
    foreach i in 1 2 3 4 5 6 7 8 13 {
        quietly replace `lnf' = `lnf' + ( ${dumbo}==`i')*ln(normalden(${ML_y1}, `Xb', ``sigma'`i''))
    }
end
*/

/*
capture program drop normal
program normal
    version 13.1
    args lnf Xb
    quietly replace `lnf' = 0
    foreach i of global dumbolevels {
        quietly replace `lnf' = `lnf' + ( ${dumbo}==`i')*ln(normalden(${ML_y1}, `Xb', ``sigma'`i''))
    }
end
*/


ml model lf normal (lnwage = i.occ_agg i.race c.age##c.age union ) /sigma1 /sigma2 /sigma3 /sigma4 /sigma5 /sigma6 /sigma7 /sigma8 /sigma13 if race<3
ml max
asge

ml model lf normal (lnwage = i.race i.occ_agg#c.age i.occ_agg#c.age#c.age union ) /sigma1 /sigma2 /sigma3 /sigma4 /sigma5 /sigma6 /sigma7 /sigma8 /sigma9
ml max

ml model lf normal (lnwage = i.occ_agg i.race i.occ_agg##c.age##c.age union ) /sigma1 /sigma2 /sigma3 /sigma4 /sigma5 /sigma6 /sigma7 /sigma8 /sigma9
ml max

log close
