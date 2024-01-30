**====================================================================
*project:       PEB PAK
*Author:        Laura Moreno Herrera
*Modified by:   Adriana Castillo Castillo
*Dependencies:  SAR Poverty-World Bank 
*----------------------------------------------------------------------
*Creation Date:         09/21/2021 by Laura
*Modification Date:     01/29/2024 by Adriana
*====================================================================
clear all
*------------------------------
*        Output/Export directory set up
*------------------------------
glo path "...\007.PEB\007.PEB_PAK\AM2023\Input_forPE"
*=== set up =================================================================*
	local code="PAK"
	local year2=2018
	local year1=2013
	local year0=2001
	local cpiversion="10"

	postfile PEB str30(indicator) year rate value using "${path}\PEB_PAK.dta", replace
*=== end set up==============================================================*
*A1#=== Population from WBopendata ============================================================*
	wbopendata,  indicator(SP.POP.TOTL) clear  nometadata long
	keep if countrycode=="`code'" & inrange(year,`year0',`year2')
	rename countrycode code
	keep code year sp_pop_totl
	tempfile WDIpop
	save `WDIpop', replace
*==end WBopendata ============================================================#A1*
*A2#=== CPI from datalibweb ====================================================*
	datalibweb, country(Support) year(2005) type(GMDRAW) surveyid(Support_2005_CPI_v`cpiversion'_M) filename(Final_CPI_PPP_to_be_used.dta)
	keep if code=="`code'" & inrange(year,`year0',`year2')
	keep code year cpi* icp* comparability
	tempfile dlwcpi
	save `dlwcpi', replace
*==end CPI from datalibweb ===================================================#A2*
	
 
	foreach yy of numlist `year0'(1)`year2' {
*B#=== call data ============================================================*
		noi di "--------> `yy'"
		cap datalibweb, country(`code') year(`yy') type(SARMD) mod(GMD) 
		if _rc cap datalibweb, country(`code') year(`yy') type(SARMD) mod(ALL)
		if _rc continue
*-------*
		merge m:1 code year using `dlwcpi', keep(match) nogen
		merge m:1 code year using `WDIpop', keep(match) nogen
*=== end call data ========================================================#B*
*C#=== Poverty and Gini, all years============================================*
		cap gen weight=weight_p
		cap rename weights weight
		local var="welfare_ppp"
		cap drop cpi2011 icp2011
		cap drop cpi2011_*
		cap drop cpi2017_* 
		gen `var'=(12/365)*welfare/cpi2017/icp2017
		
		*-Population WDI
		sum sp_pop_totl
		local sp_pop_totl=`r(mean)'
		*1-Poverty
		apoverty `var' [aw=weight], line(2.15) gen(poor)
		post PEB ("Poverty") (`yy') (`r(head_1)') (`=`r(head_1)'*`sp_pop_totl'') 
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
		if (`yy'==`year2') {
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
			cap drop temp2 temp3 edu1
			cap drop temp4 edu2 edu3 
			gen temp4=educat7 if age>14
			bys hhid: egen edu2=max(temp4) 
			gen edu3=(edu2<=2)
			sum edu3 [aw=weight]
			post PEB ("No adult has completed primary education ") (`yy') (`=`r(mean)'*100') (3)
			cap drop temp4 edu2 edu3 
			sum imp_wat_rec [aw=weight]
			post PEB ("No access to drinking water") (`yy') (`=100-`r(mean)'*100') (3)
			sum imp_san_rec [aw=weight]
			post PEB ("No access to sanitation") (`yy') (`=100-`r(mean)'*100') (3)
			sum electricity [aw=weight]
			post PEB ("No access to electricity") (`yy') (`=100-`r(mean)'*100') (3)
		}
*=== end Latest year ============================================================#E*
	}
*1#=== Export ===============================================================*
	postclose PEB
	use "${path}\PEB_PAK.dta", clear
	gen order=value
	replace order=0 if value>3
	gen by=""
	replace by="Poor" if value==1
	replace by="B40" if value==2
	replace by="Multidimensional" if value==3
	replace value=. if value<4
	egen key=concat(indicator year), p(" ")
	egen key2=concat(indicator by), p(" ")
	replace key=key2 if order>0
	drop key2
	*reshape wide value rate, i(order indicator by) j(year)
	sort order
	order key 
	export excel using "$PEB_PAK.xlsx", firstrow(varlabels) sheet("input", replace) keepcellfmt 
*=== end Export============================================================#1*
exit
