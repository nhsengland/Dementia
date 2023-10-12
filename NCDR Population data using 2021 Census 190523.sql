/****** Script to produce populations by different protected characteristics (age, gender and ethnicity) and geographies (National, ICB and Sub-ICB) using the 2021 census data.
		This is used in the Memory Assessment Services (MAS) dashboard to produce the rates of open referrals per 100,000 population graph. ******/

------------------------Age Group-------------------------------
--This produces a base table with the population for each age grouping for each MSOA and it is matched to the Sub-ICB, ICB and Region that MSOA belongs to.
--Age data wasn't available at LSOA level so MSOA was used instead
IF OBJECT_ID ('[NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Population_Age_Base_Table]') IS NOT NULL DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Population_Age_Base_Table]
SELECT DISTINCT
	l.MSOA21
	,l.[SubICBName]
	,l.[ICBName]
	,l.[Region_Name]
	,a.Measure_Name
    ,a.[Count]
INTO [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Population_Age_Base_Table]
FROM [NHSE_UKHF].[Census].[vw_Age_By_Single_Year_Of_Age_V21] a
	INNER JOIN  [NHSE_Sandbox_MentalHealth].[dbo].[Lookup_LSOA21_MSOA21_ICB] l ON l.MSOA21= a.Geography_Code COLLATE DATABASE_DEFAULT
	--Inner joins to a lookup table which matches LSOA 2021 codes with MSOA 2021 codes, Sub-ICB names, ICB names and Region names 
	--so the census populations can be aggregated to Sub-ICB and ICB levels
WHERE a.[Effective_Snapshot_Date] = '2021-03-21' and a.Geography_Type='msoa' and Geography_Code like'E%'
	and Measure_Name in ('Aged 4 years and under','Aged 5 to 9 years','Aged 10 to 15 years','Aged 16 to 19 years','Aged 20 to 24 years' 
	,'Aged 25 to 34 years','Aged 35 to 49 years','Aged 50 to 64 years','Aged 65 to 74 years','Aged 75 to 84 years','Aged 85 years and over')
	--Filters for date (there is currently only one date available)
	--Filters for MSOAs and for English geography codes (there are Welsh codes included in the data)
	--Filters for age groupings as the data also contains a total population and populations for single year of age

	
--This table aggregates the populations to Sub-ICB, ICB and National levels based on the age base table above
--Ages are grouped into Under 65s, 65 to 74, 75 to 84 and 85+ as these are the age groupings used in the Memory Assessment Services dashboard this table is used in
IF OBJECT_ID ('[NHSE_Sandbox_MentalHealth].[dbo].[OPMH_PopsData]') IS NOT NULL DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].[OPMH_PopsData]
SELECT
	Org_Type
	,Org_Name
	,Category
	,cast(Variable as varchar(255)) as Variable
	,Pop
INTO [NHSE_Sandbox_MentalHealth].[dbo].[OPMH_PopsData]
FROM
(--Sub-ICB
	SELECT
		'Sub-ICB' AS [Org_Type]
		,[SubICBName] AS [Org_Name]
		,'Age Group' as [Category]
		,CASE WHEN [Measure_Name] IN ('Aged 4 years and under','Aged 5 to 9 years','Aged 10 to 15 years','Aged 16 to 19 years','Aged 20 to 24 years' 
									,'Aged 25 to 34 years','Aged 35 to 49 years','Aged 50 to 64 years') THEN 'Under65' 
			WHEN [Measure_Name]='Aged 65 to 74 years' THEN '65to74'
			WHEN [Measure_Name]='Aged 75 to 84 years' THEN '75to84'
			WHEN [Measure_Name]='Aged 85 years and over' THEN '85+'
			END AS Variable
		,SUM([Count]) AS [Pop]
	FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Population_Age_Base_Table]
	GROUP BY 
		[SubICBName],
		CASE WHEN [Measure_Name] IN ('Aged 4 years and under','Aged 5 to 9 years','Aged 10 to 15 years','Aged 16 to 19 years','Aged 20 to 24 years' 
									,'Aged 25 to 34 years','Aged 35 to 49 years','Aged 50 to 64 years') THEN 'Under65' 
			WHEN [Measure_Name]='Aged 65 to 74 years' THEN '65to74'
			WHEN [Measure_Name]='Aged 75 to 84 years' THEN '75to84'
			WHEN [Measure_Name]='Aged 85 years and over' THEN '85+'
			END 
 
UNION

--ICB
	SELECT
		'ICB' AS [Org_Type]
		,[ICBName] AS [Org_Name]
		,'Age Group' as [Category]
		,CASE WHEN [Measure_Name] IN ('Aged 4 years and under','Aged 5 to 9 years','Aged 10 to 15 years','Aged 16 to 19 years','Aged 20 to 24 years' 
									,'Aged 25 to 34 years','Aged 35 to 49 years','Aged 50 to 64 years') THEN 'Under65' 
			WHEN [Measure_Name]='Aged 65 to 74 years' THEN '65to74'
			WHEN [Measure_Name]='Aged 75 to 84 years' THEN '75to84'
			WHEN [Measure_Name]='Aged 85 years and over' THEN '85+'
			END AS Variable
		,SUM([Count]) AS [Pop]
	FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Population_Age_Base_Table]
	GROUP BY [ICBName]
			,CASE WHEN [Measure_Name] IN ('Aged 4 years and under','Aged 5 to 9 years','Aged 10 to 15 years','Aged 16 to 19 years','Aged 20 to 24 years' 
										,'Aged 25 to 34 years','Aged 35 to 49 years','Aged 50 to 64 years') THEN 'Under65' 
				WHEN [Measure_Name]='Aged 65 to 74 years' THEN '65to74'
				WHEN [Measure_Name]='Aged 75 to 84 years' THEN '75to84'
				WHEN [Measure_Name]='Aged 85 years and over' THEN '85+'
				END

 UNION

 --National
	SELECT
		'National' AS [Org_Type]
		,'England' AS [Org_Name]
		,'Age Group' as [Category]
		,CASE WHEN [Measure_Name] IN ('Aged 4 years and under','Aged 5 to 9 years','Aged 10 to 15 years','Aged 16 to 19 years','Aged 20 to 24 years' 
									,'Aged 25 to 34 years','Aged 35 to 49 years','Aged 50 to 64 years') THEN 'Under65' 
			WHEN [Measure_Name]='Aged 65 to 74 years' THEN '65to74'
			WHEN [Measure_Name]='Aged 75 to 84 years' THEN '75to84'
			WHEN [Measure_Name]='Aged 85 years and over' THEN '85+'
			END AS Variable
		,SUM([Count]) AS [Pop]
	FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Population_Age_Base_Table]
	GROUP BY CASE WHEN [Measure_Name] IN ('Aged 4 years and under','Aged 5 to 9 years','Aged 10 to 15 years','Aged 16 to 19 years','Aged 20 to 24 years' 
										,'Aged 25 to 34 years','Aged 35 to 49 years','Aged 50 to 64 years') THEN 'Under65' 
				WHEN [Measure_Name]='Aged 65 to 74 years' THEN '65to74'
				WHEN [Measure_Name]='Aged 75 to 84 years' THEN '75to84'
				WHEN [Measure_Name]='Aged 85 years and over' THEN '85+'
				END)_

 ----------------------------------------Gender---------------------------------------------------------------
 --This produces a base table with the population for each gender for each LSOA and it is matched to the Sub-ICB, ICB and Region that LSOA belongs to
IF OBJECT_ID ('[NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Population_Gender_Base_Table]') IS NOT NULL DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Population_Gender_Base_Table]
SELECT DISTINCT
	l.LSOA21
	,l.[SubICBName]
	,l.[ICBName]
	,l.[Region_Name]
	,g.[Sex]
    ,g.[Count]
INTO [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Population_Gender_Base_Table]
FROM [NHSE_UKHF].[Census].[vw_Sex1] g
	INNER JOIN [NHSE_Sandbox_MentalHealth].[dbo].[Lookup_LSOA21_MSOA21_ICB] l ON l.LSOA21= g.Geography_Code COLLATE DATABASE_DEFAULT
	--Inner joins to a lookup table which matches LSOA 2021 codes with MSOA 2021 codes, Sub-ICB names, ICB names and Region names 
	--so the census populations can be aggregated to Sub-ICB and ICB levels
WHERE g.[Effective_Snapshot_Date] = '2021-03-21' and g.Geography_Code LIKE 'E01%' and Sex <> 'All persons'
	--Filters for date (there is currently only one date available)
	--Filters for English geography codes (there are Welsh codes included in the data)
	--Filters out 'All persons' population so only the gender groups are included


--This table aggregates the populations to Sub-ICB, ICB and National levels based on the gender base table above
--Gender is grouped into Females, Males and Other/Not Stated/Not Known as these are the gender groups used in the Memory Assessment Services dashboard this table is used in
INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[OPMH_PopsData]
SELECT 
*
FROM
(--Sub-ICB
	SELECT
		'Sub-ICB' AS [Org_Type]
		,[SubICBName] AS [Org_Name]
		,'Gender' AS [Category]
		,CASE WHEN [Sex]='Female' THEN 'Females'
			WHEN [Sex]='Male' THEN 'Males'
			ELSE 'Other/ Not Stated/ Not Known'
			END AS Variable
		,SUM([Count]) AS [Pop]
	FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Population_Gender_Base_Table]
	GROUP BY [SubICBName]
			,CASE WHEN [Sex]='Female' THEN 'Females'
				WHEN [Sex]='Male' THEN 'Males'
				ELSE 'Other/ Not Stated/ Not Known'
				END
 
UNION

--ICB
	SELECT
		'ICB' AS [Org_Type]
		,[ICBName] AS [Org_Name]
		,'Gender' AS [Category]
		,CASE WHEN [Sex]='Female' THEN 'Females'
			WHEN [Sex]='Male' THEN 'Males'
			ELSE 'Other/ Not Stated/ Not Known'
			END AS Variable
		,SUM([Count]) AS [Pop]
	FROM NHSE_Sandbox_MentalHealth.dbo.TEMP_Population_Gender_Base_Table
	GROUP BY [ICBName]
			,CASE WHEN [Sex]='Female' THEN 'Females'
				WHEN [Sex]='Male' THEN 'Males'
				ELSE 'Other/ Not Stated/ Not Known'
				END

UNION

--National
	SELECT
		'National' AS [Org_Type]
		,'England' AS [Org_Name]
		,'Gender' AS [Category]
		,CASE WHEN [Sex]='Female' THEN 'Females'
			WHEN [Sex]='Male' THEN 'Males'
			ELSE 'Other/ Not Stated/ Not Known'
			END AS Variable
		,SUM([Count]) AS [Pop]
	FROM NHSE_Sandbox_MentalHealth.dbo.TEMP_Population_Gender_Base_Table
	GROUP BY CASE WHEN [Sex]='Female' THEN 'Females'
				WHEN [Sex]='Male' THEN 'Males'
				ELSE 'Other/ Not Stated/ Not Known'
				END)_

--------------------------------------------Ethnicity--------------------------------------------------------------------------
--This produces a base table with the population for each ethnicity group for each LSOA and it is matched to the Sub-ICB, ICB and Region that LSOA belongs to.
IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.TEMP_Population_Ethnicity_Base_Table') IS NOT NULL DROP TABLE NHSE_Sandbox_MentalHealth.dbo.TEMP_Population_Ethnicity_Base_Table
SELECT DISTINCT
	l.LSOA21
	,l.[SubICBName]
	,l.[ICBName]
	,l.[Region_Name]
	,e.Measure
    ,e.Measure_Value
INTO NHSE_Sandbox_MentalHealth.dbo.TEMP_Population_Ethnicity_Base_Table
FROM [NHSE_UKHF].[Census].[vw_Ethnic_Group_V21] e
	INNER JOIN [NHSE_Sandbox_MentalHealth].[dbo].[Lookup_LSOA21_MSOA21_ICB] l ON l.LSOA21= e.Geography_Code COLLATE DATABASE_DEFAULT
	--Inner joins to a lookup table which matches LSOA 2021 codes with MSOA 2021 codes, Sub-ICB names, ICB names and Region names 
	--so the census populations can be aggregated to Sub-ICB and ICB levels
WHERE e.[Effective_Snapshot_Date] = '2021-03-21' and e.Geography_Code like 'E01%' and e.Geography_Type='lsoa' 
	and Measure IN ('Ethnic_group:_Asian_Asian_British_or_Asian_Welsh','Ethnic_group:_Black_Black_British_Black_Welsh_Caribbean_or_African','Ethnic_group:_Mixed_or_Multiple_ethnic_groups'
	,'Ethnic_group:_Other_ethnic_group','Ethnic_group:_White')
	--Filters for date (there is currently only one date available)
	--Filters for MSOAs and for English geography codes (there are Welsh codes included in the data)
	--Filters for age groupings as the data also contains a total population and populations for single year of age
	

--This table aggregates the populations to Sub-ICB, ICB and National levels based on the ethnicity base table above
--Ethnicity is grouped into Asian, Black, Mixed, White and Other as these are the ethnicity groups used in the Memory Assessment Services dashboard this table is used in
INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[OPMH_PopsData]
SELECT
*
FROM
(--Sub-ICB
	SELECT
		'Sub-ICB' AS [Org_Type]
		,[SubICBName] AS [Org_Name]
		,'Ethnicity' as [Category]
		,CASE WHEN Measure like '%Asian%' THEN 'Asian'
			WHEN Measure  like'%Black%' THEN 'Black'
			WHEN Measure like'%Mixed%' THEN 'Mixed'
			WHEN Measure like'%White%' THEN 'White'
			WHEN Measure  like '%Other%' THEN 'Other'
			ELSE 'Not Stated/ Not Known'
			END AS Variable
		,ROUND(SUM(Measure_Value),0) AS [Pop]
	FROM NHSE_Sandbox_MentalHealth.dbo.TEMP_Population_Ethnicity_Base_Table
	GROUP BY [SubICBName]
			,CASE WHEN Measure like '%Asian%' THEN 'Asian'
				WHEN Measure  like'%Black%' THEN 'Black'
				WHEN Measure like'%Mixed%' THEN 'Mixed'
				WHEN Measure like'%White%' THEN 'White'
				WHEN Measure  like '%Other%' THEN 'Other'
				ELSE 'Not Stated/ Not Known'
				END
 
UNION

--ICB
	SELECT
		'ICB' AS [Org_Type]
		,[ICBName] AS [Org_Name]
		,'Ethnicity' as [Category]
		,CASE WHEN Measure like '%Asian%' THEN 'Asian'
			WHEN Measure  like'%Black%' THEN 'Black'
			WHEN Measure like'%Mixed%' THEN 'Mixed'
			WHEN Measure like'%White%' THEN 'White'
			WHEN Measure  like '%Other%' THEN 'Other'
			ELSE 'Not Stated/ Not Known'
			END AS Variable
		,ROUND(SUM(Measure_Value),0) AS [Pop]
	FROM NHSE_Sandbox_MentalHealth.dbo.TEMP_Population_Ethnicity_Base_Table
	GROUP BY [ICBName]
		,CASE WHEN Measure like '%Asian%' THEN 'Asian'
			WHEN Measure  like'%Black%' THEN 'Black'
			WHEN Measure like'%Mixed%' THEN 'Mixed'
			WHEN Measure like'%White%' THEN 'White'
			WHEN Measure  like '%Other%' THEN 'Other'
			ELSE 'Not Stated/ Not Known'
			END

UNION
--National
	SELECT
		'National' AS [Org_Type]
		,'England' AS [Org_Name]
		,'Ethnicity' as [Category]
		,CASE WHEN Measure like '%Asian%' THEN 'Asian'
			WHEN Measure  like'%Black%' THEN 'Black'
			WHEN Measure like'%Mixed%' THEN 'Mixed'
			WHEN Measure like'%White%' THEN 'White'
			WHEN Measure  like '%Other%' THEN 'Other'
			ELSE 'Not Stated/ Not Known'
			END as Variable
		,ROUND(SUM(Measure_Value),0) AS [Pop]
	FROM NHSE_Sandbox_MentalHealth.dbo.TEMP_Population_Ethnicity_Base_Table
	GROUP BY CASE WHEN Measure like '%Asian%' THEN 'Asian'
			WHEN Measure  like'%Black%' THEN 'Black'
			WHEN Measure like'%Mixed%' THEN 'Mixed'
			WHEN Measure like'%White%' THEN 'White'
			WHEN Measure  like '%Other%' THEN 'Other'
			ELSE 'Not Stated/ Not Known'
			END)_

----------------------------------------------------------------------------------------
--Drops temporary tables used in the query
DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Population_Age_Base_Table]
DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Population_Gender_Base_Table]
DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Population_Ethnicity_Base_Table]
