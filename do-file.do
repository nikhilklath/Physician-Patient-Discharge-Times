*****************************************
* Name: Nikhil Kumar					*
* Date: 11/09/2020						*
*****************************************

/*
Physicians work in shifts, in which they begin work at a set time and stay until they discharge their patients
(usually past the end of shift). Patients arrive and are immediately assigned to a physician, unless if the
physician has not started his or her shift yet. In the latter case, the patient is assigned to the physician at the
beginning of the shift. 

In the dataset test_data.txt, you will see comma-separated data in which each row
represents a patient visit. The variables are as follows:
1. visit_num: Row identifier for the patient visit
2. phys_name: Physician
3. shiftid: String variable denoting the date and beginning and end times of the physician’s shift. If the shift spans midnight, the date corresponds to the beginning time.
4. ed_tc: Date and time of patient arrival to ED
5. dcord_tc: Date and time of patient discharge order
6. xb_lntdc: Measure of expected log length of stay, where length of stay is the difference between dcord_tc and ed_tc, based on patient demographics and medical conditions (you can think of this as “patient severity”)
*/

* set path of the working folder
global projdir "C:\Users\nikhi\Downloads\"

* data folder
global raw "$projdir\Task package"

* folder where final data is saved
global final "$projdir\final_data"

cd "$raw"
import delimited "Task package\test_data.txt", clear 

/* 
The variable shiftid contains string data on start and end of shift time and date
First, I convert this string into datetime format so that 
it is in the same format at patient arrival and departure date and times
*/

* split the shiftid into different parts to convert it into datetime format
split shiftid, p(" ")

* convert the shift start date into date format
gen shift_start_date = clock(shiftid1, "DMY")
format shift_start_date %tcnn/dd/ccYY_hh:MM

* generate a shift end date which is same as start date if shift ends on same day
gen shift_end_date = clock(shiftid1, "DMY")
format shift_end_date %tcnn/dd/ccYY_hh:MM

* if shift ends on a different day, then add a day to the start date to get end date
gen flag = ((shiftid3=="p.m.") & (shiftid6=="a.m."))
replace shift_end_date = shift_start_date + msofminutes(1440) if flag == 1

format shift_start_date %tcnn/dd/ccYY_hh:MM
format shift_end_date %tcnn/dd/ccYY_hh:MM

* construct date-time for the doctor's shift
* start shift time
gen shift_s_time = shiftid2+shiftid3
replace shift_s_time = "12p.m." if shift_s_time=="noonto"

* shift end time
gen shift_e_time = shiftid5+shiftid6
replace shift_e_time = shiftid4 +shiftid5 if shiftid3 == "to"
replace shift_e_time = "12p.m." if shift_e_time=="noon"

* change date-time to readable format
gen shift_start_time=clock(shift_s_time, "h")
format shift_start_time %tcHH:MM

gen shift_end_time=clock(shift_e_time, "h")
format shift_end_time %tcHH:MM

gen double shift_s_dt = shift_start_date + shift_start_time
format shift_s_dt %tcnn/dd/ccYY_hh:MM

gen double shift_e_dt = shift_end_date + shift_end_time
format shift_e_dt %tcnn/dd/ccYY_hh:MM

* generate doctor's length of shift
gen doc_stay_len = round((shift_e_dt - shift_s_dt)/3600000)

* drop extra variables
drop shiftid2 shiftid3 shiftid4 shiftid5 shiftid6 flag shift_s_time shift_e_time

************************Question 0*******************************
* 					Summarize the data        					*

* summarize doctor's shift length for each doctor
tab phys_name, sum(doc_stay_len)

* convert patient arrival and departure times into datetime format
gen pat_arr = clock(ed_tc, "DMYhms")
gen pat_dep = clock(dcord_tc, "DMYhms")
format pat_arr %tcnn/dd/ccYY_hh:MM
format pat_dep %tcnn/dd/ccYY_hh:MM

* In order to check for data entry errors, considering two situations: check 1 & 
* check 2 : 
* check1 -  if patient leaves before doctor arrives
gen check1 = shift_s_dt >= pat_dep 
tab check1
********* 4 observations appear to be data entry errors *********

* check2 - if doctor leaves before patient arrives
gen check2 = shift_e_dt <= pat_arr
tab check2
********* 0 observations belong to this case******************

*************************Question 1******************************
/*
Some patients may arrive before their physician’s shift starts and therefore would have to wait.
Other patients may be discharged after their physician’s shift ends (and the physician would have
to stay past the end of shift). What percentages of visits fall in these categories?
*/

* check if patient arrives before doctor arrives
gen check3 = (shift_s_dt - pat_arr)>0
tab check3
******** 7.5% of the observations have patients arriving before doctor's shift starts *********

* check if doctor's shift ends before patient departs
gen check4 = (shift_e_dt - pat_dep)<0
tab check4
******** 19% of the observations have patients departing after doctor's shift ends *********

***********************Question 2******************************
/* 
Describe hourly patterns of patient arrivals and the average severity of these patients.
*/

* to find the arrival of patient, split the patient arrival datetime
split ed_tc, p(" ", ":")
destring ed_tc2, gen(pat_arr_hr)
drop ed_tc1 ed_tc2 ed_tc3 ed_tc4

* plot number of arrivals in each hour
hist pat_arr_hr, freq xtitle("Hour of Day") ytitle("Number of Patient Arriving") xlabel(0[2]24)

* find mean severity of patients arriving every hour
bys pat_arr_hr: egen avg_sev = mean(xb_lntdc)

* plot of patient severity by hour
twoway bar avg_sev pat_arr_hr, xtitle("Hour of Day") ytitle("Avg. Severity of Patient Arriving") xlabel(0[2]24)

* find number of patients arriving every hour
bys pat_arr_hr: egen count = count(visit_num)

twoway (scatter avg_sev pat_arr_hr [w=count], msymbol(circle_hollow))||(lfitci avg_sev pat_arr_hr), xtitle("Hour of Day (Patient Arrival)") ytitle("Average patient severity") note("size of bubble is number of patients") xlabel(0[2]24)

reg avg_sev pat_arr_hr
* There seems to be no relationship between hour of day and severity of patients arriving that hour.
* The R2 for this regression is 0.0045 i.e. the variation in hours of day 
* explains only about 4.5 % of the variance in average patient severity. So, this is not predictive.

**********************Question 3******************************

/*
Create and include with your solutions a dataset recording the “census,” or number of patients under
a physician’s care (patients who have arrived and have not yet been discharged), during each hour
of a physician’s shift from beginning to 4 hours past the end of shift. The observations in this dataset
should correspond to the shift (shiftid), physician (phys_name), and the hour of shift (index).
index should be defined as follows, so that it should mostly negative values and have a maximum
of 3 in the dataset: The hour ending at the same time as shift end is indexed -1, the hour beginning
at shift end is indexed 0, and the hour beginning one hour after shift end is indexed 1, etc.
*/

* drop observation where data entry is wrong
drop if check1==1

* relative to end of doctor's shift, find which hour did patient depart
gen hour_diff1 = (pat_dep - shift_e_dt)/3600000
gen d1 = floor(hour_diff1)

* if patient departed later than 4 hours after end of doctor's shift, drop the observation
drop if d1>=4

* relative to start of doctor's shift, which hour did patient arrive
gen i1 = (pat_arr-shift_s_dt)/3600000
gen in1 = ceil(i1)

* if patient arrived before doctor's shift started, this would their first hour under doctor's care
replace in1 = 1 if in1<=0

* relative to start of doctor's shift, which hour did patient depart
gen i2 = (pat_dep - shift_s_dt)/3600000
gen in2 = ceil(i2)

* generate variables for 'index' which indicates 
* which hours relative to start of shift was the patient in doctor's care
forvalues x= 1/14{
	gen index`x' = 0
}

* in1 = hour of the shift when the patient first got into doctor's care
* in2 = hour of shift when patient was discharged
mkmat in1 in2, mat(A)
forvalues i=1/8196{
	local a = A[`i',1]
	local b = A[`i',2]
	forvalues j = `a'/`b'{
		replace index`j'=1 in `i'
	}
}
preserve
* reshape data so that there is an index for each hour that a patient was in the hospital
reshape long index, i(shiftid phys_name visit_num) j(ind)
drop if index==0

* change the index to make it relative to end of shift by subtrating the length of hours of the doctor's shift
replace ind = ind-doc_stay_len

* find the number of patients which were under doctor's care for each index
collapse (sum) count=index, by(shiftid phys_name ind)
rename ind index
rename count census
save census.dta

hist ind, freq xtitle("Time relative to end of shift") ytitle("Number(census) of patients under physician's care") xlabel(-9[1]4)
restore

**************************Question 4***********************************
/*
Which physician appears to be the fastest at discharging patients?
*/

* find the log of discharge time for each patient
gen discharge_time = log((pat_dep - pat_arr)/3600000)
* encode physician's name
encode phys_name, gen(phy)

* simple fixed effects regression
reg discharge_time i.phy
est store spec1

* fixed effects regression with control for patient severity
reg discharge_time i.phy xb_lntdc
est store spec2

* hausman test
hausman spec1 spec2

