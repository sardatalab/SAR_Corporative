**====================================================================
*project:       PEB BTN
*Author:        Laura Moreno Herrera
*Modified by:   Adriana Castillo Castillo
*Dependencies:  SAR Poverty-World Bank 
*----------------------------------------------------------------------
*Creation Date:         09/21/2021 by Laura
*Modification Date:     09/21/2023 by Adriana
*====================================================================
clear all
*------------------------------
*        Output/Export directory set up
*------------------------------
glo path "...\01.JTR\007.PEB_BGD"
*=== set up =================================================================*
	local code="BGD"
	local year2=2022
	local year1=2016
	local year0=2010
	local year0b=2005
	local year0a=2000
	local cpiversion="10"
	*local ipline=2.15
	*local ipline=3.65
	local ipline=6.85
	*postutil clear //change 
	postfile PEB str30(indicator) year rate value using "${path}\PEB_BGD.dta", replace
*=== end set up==============================================================*
*A1#=== Population from WBopendata ============================================================*
	wbopendata,  indicator(SP.POP.TOTL) clear  nometadata long  projection  
	keep if countrycode=="`code'" & inrange(year,`year0a',`year2')
	rename countrycode code
	keep code year sp_pop_totl
	tempfile WDIpop
	save `WDIpop', replace
*==end WBopendata ============================================================#A1*
*A2#=== CPI from datalibweb ====================================================*
	datalibweb, country(Support) year(2005) type(GMDRAW) surveyid(Support_2005_CPI_v`cpiversion'_M) filename(Final_CPI_PPP_to_be_used.dta)
	keep if code=="`code'" & inrange(year,`year0a',`year2')
	keep code year cpi2017 icp2017 comparability
	tempfile dlwcpi
	save `dlwcpi', replace
*==end CPI from datalibweb ===================================================#A2*
	*foreach yy of numlist `year0'(1)`year2' {
	foreach yy of numlist `year0a'(1)`year2' {
*B#=== call data ============================================================*
		noi di "--------> `yy'"
		if (`yy'==2022) {
			cap datalibweb, country(`code') year(`yy') type(SARMD) mod(GMD) local localpath(${rootdatalib})	 //change 
			if _rc cap datalibweb, country(`code') year(`yy') type(SARMD) mod(IND)
			if _rc continue
			cap gen code="BGD"
			cap rename ppp icp2017
			gen weight = wgt 
		}
		else {
			cap datalibweb, country(`code') year(`yy') type(SARMD) mod(GMD) 
			if _rc cap datalibweb, country(`code') year(`yy') type(SARMD) mod(IND)
			if _rc continue
		}
*-------*

		if (`yy'==2022) {
			*gen cpi2017=1.255452394485474 //change 
			*gen icp2017=20.4737873077393 //change
			di "nothing to do"
		}
		else{
			merge m:1 code year using `dlwcpi', keep(match) nogen
		}
		
		merge m:1 code year using `WDIpop', keep(match) nogen
	
		cap gen school=atschool
		cap gen imp_wat_rec=sar_improved_water
		cap gen imp_san_rec=sar_improved_toilet
		
*=== end call data ========================================================#B*
*C#=== Poverty and Gini, all years============================================*
		cap gen weight=weight_p
		cap gen weight=pop_wgt if year==2022
		cap gen weight=wgt if year==2010 | year==2016
		cap gen welfare=welfare_v2
		local var="welfare_ppp"
		gen `var'=(12/365)*welfare/cpi2017/icp2017 
		*-Population WDI
		sum sp_pop_totl
		local sp_pop_totl=`r(mean)'
		*1-Poverty
		apoverty `var' [aw=weight], line(`ipline') gen(poor)
		post PEB ("Poverty") (`yy') (`r(head_1)') (`=`r(head_1)'*`sp_pop_totl'') 
		gen dep_poor=poor1
		*2. Gini
		ainequal `var' [w=weight]
		post PEB ("Gini Index") (`yy') (`r(gini_1)'*100) (0)
*=== end Poverty and Gini, all years==========================================#B*
*D#=== Year1 - Year 2 =========================================================*
		if inlist(`yy', `year1', `year2') {
		*3. Average welfare
			sum `var' [w=weight] 
			post PEB ("Mean") (`yy') (`r(mean)') (`r(mean)')
			*4. Median welfare
			_pctile `var' [w=weight], p(50)
			post PEB ("Median") (`yy') (`r(r1)') (`r(r1)')
			*5-Average B40
			_pctile `var' [w=weight], p(40)
			gen b40=(`var'<=`r(r1)') & !mi(`var')
			sum `var' [w=weight] if b40==1
			post PEB ("B40") (`yy') (`r(mean)') (`r(mean)')
		}
*=== Year 1 - Year2 ============================================================#D*
*E#=== Latest year ============================================================*
		if inlist(`yy', `year1', `year2') {
		* Key indicators
			cap _pctile `var' [w=weight], p(40)
			cap gen b40=(`var'<=`r(r1)') & !mi(`var')
			recode age (0/14=1) (15/64=2) (65/100=3), gen(ageg)
*---------------------------------------------------------------------------
			sum poor1 [aw=weight] if urban==1
			post PEB ("Urban population") (`yy') (`=`r(mean)'*100') (1)
			sum poor1 [aw=weight] if urban==0
			post PEB ("Rural population") (`yy') (`=`r(mean)'*100') (1)
			sum poor1 [aw=weight] if male==1
			post PEB ("Males") (`yy') (`=`r(mean)'*100') (1)
			sum poor1 [aw=weight] if male==0
			post PEB ("Females") (`yy') (`=`r(mean)'*100') (1)
			sum poor1 [aw=weight] if ageg==1
			post PEB ("0 to 14 years old") (`yy') (`=`r(mean)'*100') (1)
			sum poor1 [aw=weight] if ageg==2
			post PEB ("15 to 64 years old") (`yy') (`=`r(mean)'*100') (1)
			sum poor1 [aw=weight] if ageg==3
			post PEB ("65 and older") (`yy') (`=`r(mean)'*100') (1)
			sum poor1 [aw=weight] if educat4==1 & age>=16
			post PEB ("Without education (16+)") (`yy') (`=`r(mean)'*100') (1)
			sum poor1 [aw=weight] if educat4==2 & age>=16
			post PEB ("Any primary (16+)") (`yy') (`=`r(mean)'*100') (1)
			sum poor1 [aw=weight] if educat4==3 & age>=16
			post PEB ("Any secondary (16+)") (`yy') (`=`r(mean)'*100') (1)
			sum poor1 [aw=weight] if educat4==4 & age>=16
			post PEB ("Tertiary education (16+)") (`yy') (`=`r(mean)'*100') (1)
*---------------------------------------------------------------------------
			sum b40 [aw=weight] if urban==1
			post PEB ("Urban population") (`yy') (`=`r(mean)'*100') (2)
			sum b40 [aw=weight] if urban==0
			post PEB ("Rural population") (`yy') (`=`r(mean)'*100') (2)
			sum b40 [aw=weight] if male==1
			post PEB ("Males") (`yy') (`=`r(mean)'*100') (2)
			sum b40 [aw=weight] if male==0
			post PEB ("Females") (`yy') (`=`r(mean)'*100') (2)
			sum b40 [aw=weight] if ageg==1
			post PEB ("0 to 14 years old") (`yy') (`=`r(mean)'*100') (2)
			sum b40 [aw=weight] if ageg==2
			post PEB ("15 to 64 years old") (`yy') (`=`r(mean)'*100') (2)
			sum b40 [aw=weight] if ageg==3
			post PEB ("65 and older") (`yy') (`=`r(mean)'*100') (2)
			sum b40 [aw=weight] if educat4==1 & age>=16
			post PEB ("Without education (16+)") (`yy') (`=`r(mean)'*100') (2)
			sum b40 [aw=weight] if educat4==2 & age>=16
			post PEB ("Any primary (16+)") (`yy') (`=`r(mean)'*100') (2)
			sum b40 [aw=weight] if educat4==3 & age>=16
			post PEB ("Any secondary (16+)") (`yy') (`=`r(mean)'*100') (2)
			sum b40 [aw=weight] if educat4==4 & age>=16
			post PEB ("Tertiary education (16+)") (`yy') (`=`r(mean)'*100') (2)
*---------------------------------------------------------------------------
			cap drop temp2 temp3 edu1
			tab school [aw=weight] if (age>=5 & age<=13)
			gen temp2=1 if (age>=5 & age<=13 & school==0) 
			*28.4% bwn 5-15 not enrolled -> 34% OF HHD
			*26.0% bwn 5-12 not enrolled -> 26% OF HHD
			*26.2% bwn 5-13 not enrolled -> 28% OF HHD
			bys hhid: egen temp3=sum(temp2)
			gen edu1=(temp3>0)	
			sum edu1 [aw=weight]
			post PEB ("At least one school-ageg child is not enrolled in school") (`yy') (`=`r(mean)'*100') (3)
			gen dep_educ_enr=edu1
			cap drop temp2 temp3 edu1
			cap drop temp4 edu2 edu3 
			gen temp4=educat7 if age>14
			bys hhid: egen edu2=max(temp4) 
			gen edu3=(edu2<=2)
			sum edu3 [aw=weight]
			post PEB ("No adult has completed primary education ") (`yy') (`=`r(mean)'*100') (3)
			gen dep_educ_com=edu3
			cap drop temp4 edu2 edu3 
			sum imp_wat_rec [aw=weight]
			post PEB ("No access to drinking water") (`yy') (`=100-`r(mean)'*100') (3)
			gen dep_infra_impw=1-imp_wat_rec
			sum imp_san_rec [aw=weight]
			post PEB ("No access to sanitation") (`yy') (`=100-`r(mean)'*100') (3)
			gen dep_infra_imps=1-imp_san_rec
			sum electricity [aw=weight]
			post PEB ("No access to electricity") (`yy') (`=100-`r(mean)'*100') (3)
			gen dep_infra_elec=1-electricity
			*---------------------------------------------------------------------------
			gen non_poor=poor1 - 1
			replace non_poor= non_poor*(-1)
			sum non_poor [aw=weight] if urban==1
			post PEB ("Urban population") (`yy') (`=`r(mean)'*100') (4)
			sum non_poor [aw=weight] if urban==0
			post PEB ("Rural population") (`yy') (`=`r(mean)'*100') (4)
			sum non_poor [aw=weight] if male==1
			post PEB ("Males") (`yy') (`=`r(mean)'*100') (4)
			sum non_poor [aw=weight] if male==0
			post PEB ("Females") (`yy') (`=`r(mean)'*100') (4)
			sum non_poor [aw=weight] if ageg==1
			post PEB ("0 to 14 years old") (`yy') (`=`r(mean)'*100') (4)
			sum non_poor [aw=weight] if ageg==2
			post PEB ("15 to 64 years old") (`yy') (`=`r(mean)'*100') (4)
			sum non_poor [aw=weight] if ageg==3
			post PEB ("65 and older") (`yy') (`=`r(mean)'*100') (4)
			sum non_poor [aw=weight] if educat4==1 & age>=16
			post PEB ("Without education (16+)") (`yy') (`=`r(mean)'*100') (4)
			sum non_poor [aw=weight] if educat4==2 & age>=16
			post PEB ("Any primary (16+)") (`yy') (`=`r(mean)'*100') (4)
			sum non_poor [aw=weight] if educat4==3 & age>=16
			post PEB ("Any secondary (16+)") (`yy') (`=`r(mean)'*100') (4)
			sum non_poor [aw=weight] if educat4==4 & age>=16
			post PEB ("Tertiary education (16+)") (`yy') (`=`r(mean)'*100') (4)
			*---------------------------------------------------------------------------
			gen t60=b40 - 1
			replace t60= t60*(-1)
			sum t60 [aw=weight] if urban==1
			post PEB ("Urban population") (`yy') (`=`r(mean)'*100') (5)
			sum t60 [aw=weight] if urban==0
			post PEB ("Rural population") (`yy') (`=`r(mean)'*100') (5)
			sum t60 [aw=weight] if male==1
			post PEB ("Males") (`yy') (`=`r(mean)'*100') (5)
			sum t60 [aw=weight] if male==0
			post PEB ("Females") (`yy') (`=`r(mean)'*100') (5)
			sum t60 [aw=weight] if ageg==1
			post PEB ("0 to 14 years old") (`yy') (`=`r(mean)'*100') (5)
			sum t60 [aw=weight] if ageg==2
			post PEB ("15 to 64 years old") (`yy') (`=`r(mean)'*100') (5)
			sum t60 [aw=weight] if ageg==3
			post PEB ("65 and older") (`yy') (`=`r(mean)'*100') (5)
			sum t60 [aw=weight] if educat4==1 & age>=16
			post PEB ("Without education (16+)") (`yy') (`=`r(mean)'*100') (5)
			sum t60 [aw=weight] if educat4==2 & age>=16
			post PEB ("Any primary (16+)") (`yy') (`=`r(mean)'*100') (5)
			sum t60 [aw=weight] if educat4==3 & age>=16
			post PEB ("Any secondary (16+)") (`yy') (`=`r(mean)'*100') (5)
			sum t60 [aw=weight] if educat4==4 & age>=16
			post PEB ("Tertiary education (16+)") (`yy') (`=`r(mean)'*100') (5)
			*---------------------------------------------------------------------------
			local edu		dep_educ_com dep_educ_enr
			local infra		dep_infra_elec dep_infra_imps dep_infra_impw
			local pov		dep_poor1
			local dims edu infra pov
			egen ndep_edu=rsum(`edu')
			egen ndep_infra=rsum(`infra')
			gen w_edu=ndep_edu/6
			gen w_infra=ndep_infra/9
			gen w_poor=1/3
			*foreach line in 215 365 685 {
			*foreach line of local ipline {
			egen ndep_ind=rsum(`edu' `infra' dep_poor)
			replace w_poor=dep_poor/3
			egen mpi=rowtotal(w_edu w_infra w_poor)
			gen dep_mpoor_1 = (mpi>=1/3) if !mi(mpi) & !mi(hsize)
			gen dep_mpoor_2 = (mpi>=2/3) if !mi(mpi) & !mi(hsize)
			la var dep_mpoor_2 "MPI 2 of 3 and `line'"
			la var dep_mpoor_1 "MPI 1 of 3 and `line'"
			*}
			sum dep_mpoor_1 [aw=weight]
			post PEB ("MPI 1 dimension") (`yy') (`=`r(mean)'*100') (`=`r(mean)'*`sp_pop_totl'') 
			sum dep_mpoor_2 [aw=weight]
			post PEB ("MPI 2 dimensions") (`yy') (`=`r(mean)'*100') (`=`r(mean)'*`sp_pop_totl'') 
		}
		*/
*=== end Latest year ============================================================#E*
	} 
*	exit 
*1#=== Export ===============================================================*
	postclose PEB
	use "${path}\PEB_`code'.dta", clear
	gen order=value
	replace order=0 if value>5
	gen by=""
	replace by="Poor"             if value==1
	replace by="B40"              if value==2
	replace by="Multidimensional" if value==3
	replace by="Non-poor"         if value==4
	replace by="T60"              if value==5
	replace value=. if value<6
	egen    key=concat(indicator year), p(" ")
	egen    key2=concat(indicator by), p(" ")
	replace key=key2 if order>0
	drop    key2
	*reshape wide value rate, i(order indicator by) j(year)
	sort    order
	order   key 
	export excel using "${path}\PEB_`code'.xlsx", firstrow(varlabels) sheet("input`ipline'", replace) keepcellfmt 
*=== end Export============================================================#1*
exit

