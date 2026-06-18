/* - Emergency Admissions for Dementia and Delirium Dashboard -------------------------------------------------
   - Emergency Admissions script --------------------------------------------------------------------------- */

-- Step 1 -------------------------------------------------------------------------------------------------------
/* 

-- Current values covering the last 11 months are deleted from the dashboard table and added to an old refresh table to keep as a record. 
-- The old refresh data will be removed after one year (i.e. once it is no longer refreshed).

-- @delete_period_start is the beginning of the month 11 months prior to the latest month in the dashboard extract (to include the last 12 months in the refresh)
-- @delete_period_end is the end of the latest month in last month's dashboard extract 

*/ -------------------------------------------------------------------------------------------------------------------

DECLARE @delete_period_end DATE = (SELECT EOMONTH(MAX(Month)) FROM [MHDInternal].[DASHBOARD_DEM_SUS_Emergency_Admissions_New])
DECLARE @delete_period_start DATE = (SELECT DATEADD(DAY,1,EOMONTH(DATEADD(MONTH,-11,@delete_period_end))))

PRINT CHAR(13) + 'Delete values between ' + CAST(@delete_period_start AS VARCHAR(10)) + ' and ' + CAST(@delete_period_end AS VARCHAR(10)) 
-----------------------------------------------------------------------------------------------------------------------------------------

DELETE [MHDInternal].[DASHBOARD_DEM_SUS_Emergency_Admissions_New]

OUTPUT 
	
	DELETED.[Month]
	,DELETED.[GroupType]
	,DELETED.[RegionCode]
	,DELETED.[GeographyName]
	,DELETED.[Category]
	,DELETED.[Variable]
	,DELETED.[Emergency Admissions]
	,DELETED.[Emergency Admissions - Aged 65 Years and Over]
	,DELETED.[Emergency Admissions - Dementia Diagnosis]
	,DELETED.[Emergency Admissions - Delirium Diagnosis]
	,DELETED.[Emergency Admissions - MCI Diagnosis]
	,DELETED.[Primary Diagnosis Chapter]
	,DELETED.[SnapshotDate]

INTO [MHDInternal].[STAGING_DEM_SUS_Emergency_Admissions_Old_Refresh]

	([Month]
	,[GroupType]
	,[RegionCode]
	,[GeographyName]
	,[Category]
	,[Variable]
	,[Emergency Admissions]
	,[Emergency Admissions - Aged 65 Years and Over]
	,[Emergency Admissions - Dementia Diagnosis]
	,[Emergency Admissions - Delirium Diagnosis]
	,[Emergency Admissions - MCI Diagnosis]
	,[Primary Diagnosis Chapter]
	,[SnapshotDate])

WHERE [Month] BETWEEN @delete_period_start AND @delete_period_end

GO -- End of Step 1 ---------------------------------------------------------------------------------------------------------------------------------------------

-- Step 2 -------------------------------------------------------------------------------------------------------------------------------------------------------

-- @admission_period_start is the beginning of the month 12 months prior to the latest month (the last 12 months get refreshed each month)
-- @admission_period_end is the end of the latest month

DECLARE @admission_period_end DATE = (SELECT EOMONTH(DATEADD(MONTH,+12,MAX(Month))) FROM [MHDInternal].[DASHBOARD_DEM_SUS_Emergency_Admissions_New])
DECLARE @admission_period_start DATE = (SELECT DATEADD(DAY,1, EOMONTH(DATEADD(MONTH,-12,@admission_period_end))))

PRINT CHAR(13) + 'Insert values between ' + CAST(@admission_period_start AS VARCHAR(10)) + ' and ' + CAST(@admission_period_end AS VARCHAR(10)) -- last 12 months

IF OBJECT_ID ('[MHDInternal].[TEMP_DEM_SUS_APCE_Base]') IS NOT NULL 
DROP TABLE [MHDInternal].[TEMP_DEM_SUS_APCE_Base]

SELECT 
	a.[APCE_Ident]
	,DATEADD(MONTH, DATEDIFF(MONTH, 0, a.[Admission_Date]), 0) AS [Admission_Month]
	,DATEADD(MONTH, DATEDIFF(MONTH, 0, a.[Discharge_Date]), 0) AS [Discharge_Month]
	-- Data is later presented AS the Categories of Gender, Ethnicity, Admission Source and Discharge Destination
	,ISNULL(r1.[Main_Description],'Missing/invalid') AS [Gender]
	,ISNULL(r2.[Main_Description],'Missing/invalid') AS [Ethnicity]
	,ISNULL(r3.[Main_Description],'Missing/invalid') AS [Admission_Source]
	,ISNULL(r4.[Main_Description],'Missing/invalid') AS [Discharge_Destination]
	-- For Primary Diagnosis and Chapter filters	
	,CASE WHEN r5.[Category_2_Code] IS NOT NULL AND r5.[Category_2_Description] IS NOT NULL THEN CONCAT(r5.[Category_2_Code],': ', r5.[Category_2_Description]) ELSE NULL END AS [Primary Diagnosis]
	,CASE WHEN r5.[Chapter_Code] IS NOT NULL AND r5.[Chapter_Description] IS NOT NULL THEN CONCAT(r5.[Chapter_Code],': ', r5.[Chapter_Description]) ELSE NULL END AS [Primary Diagnosis Chapter]
	-- Defines Admissions and Discharges
	,CASE WHEN a.[Admission_Date] BETWEEN @admission_period_start and @admission_period_end THEN 1 ELSE 0 END AS [Der_Admission]
	,CASE WHEN a.[Discharge_Date] BETWEEN @admission_period_start and @admission_period_end THEN 1 ELSE 0 END AS [Der_Discharge]
	,a.[Age_on_Admission] -- For emergency admissions over 65 group defined later
	,CASE WHEN -- Dementia/MCI ICD10 codes from Page 13 of Dementia Care Pathway Appendices
		a.[Der_Diagnosis_All] LIKE '%F000%' OR 
		a.[Der_Diagnosis_All] LIKE '%F001%' OR 
		a.[Der_Diagnosis_All] LIKE '%F002%' OR 
		a.[Der_Diagnosis_All] LIKE '%F009%' OR 
		a.[Der_Diagnosis_All] LIKE '%F010%' OR 
		a.[Der_Diagnosis_All] LIKE '%F011%' OR 
		a.[Der_Diagnosis_All] LIKE '%F012%' OR 
		a.[Der_Diagnosis_All] LIKE '%F013%' OR 
		a.[Der_Diagnosis_All] LIKE '%F018%' OR 
		a.[Der_Diagnosis_All] LIKE '%F019%' OR 
		a.[Der_Diagnosis_All] LIKE '%F020%' OR 
		a.[Der_Diagnosis_All] LIKE '%F021%' OR 
		a.[Der_Diagnosis_All] LIKE '%F022%' OR 
		a.[Der_Diagnosis_All] LIKE '%F023%' OR 
		a.[Der_Diagnosis_All] LIKE '%F024%' OR 
		a.[Der_Diagnosis_All] LIKE '%F028%' OR
	   (a.[Der_Diagnosis_All] LIKE '%F028%' AND a.[Der_Diagnosis_All] LIKE '%G318%') OR
		a.[Der_Diagnosis_All] LIKE '%F03%' OR
		a.[Der_Diagnosis_All] LIKE '%F051%' THEN 1 ELSE 0 END 
	AS [Dementia]
	,CASE WHEN a.[Der_Diagnosis_All] LIKE '%F067%' THEN 1 ELSE 0 END AS [MCI]
	,CASE WHEN (a.[Der_Diagnosis_All] LIKE '%F050%' OR a.[Der_Diagnosis_All] LIKE '%F058%' OR a.[Der_Diagnosis_All] LIKE '%F059%') THEN 1 ELSE 0 END AS [Delirium]
	--------------------------------------------------
	,CASE WHEN ph.[Organisation_Code] IS NOT NULL THEN ph.[Organisation_Code] ELSE 'Other' END AS [Provider_Code]
	,CASE WHEN ph.[Organisation_Name] IS NOT NULL THEN ph.[Organisation_Name] ELSE 'Other' END AS [Provider Name]
	,CASE WHEN ph.[Region_Name] IS NOT NULL THEN ph.[Region_Name] ELSE 'Other' END AS [Region_Name_Provider]
	,CASE WHEN c.Organisation_Code IS NULL THEN 'Other ' ELSE c.Organisation_Code END AS [Sub ICB Code]
	,CASE WHEN c.Organisation_Code IS NULL THEN 'Other ' ELSE c.Organisation_Name END AS [Sub ICB Name]
	,CASE WHEN c.Organisation_Code IS NULL THEN 'Other' ELSE c.Region_Code END AS [Region Code]
	,CASE WHEN c.Organisation_Code IS NULL THEN 'Other' ELSE c.Region_Name END AS [Region Name]

INTO [MHDInternal].[TEMP_DEM_SUS_APCE_Base]

FROM 
	[Reporting_MESH_APC].[APCE_Core_Monthly_Snapshot] a
	--------------------------------------------------
	LEFT JOIN [UKHD_Data_Dictionary].[Person_Gender_Code_SCD] r1 ON a.[Sex] = r1.[Main_Code_Text] AND r1.[Effective_To] IS NULL
	LEFT JOIN [UKHD_Data_Dictionary].[Ethnic_Category_Code_SCD] r2 ON a.[Ethnic_Group] = r2.[Main_Code_Text] AND r2.[Effective_To] IS NULL
	LEFT JOIN [UKHD_Data_Dictionary].[Source_Of_Admission_SCD] r3 ON a.[Source_of_Admission] = r3.[Main_Code_Text] AND r3.[Effective_To] IS NULL AND r3.[Valid_From] IS NULL
	LEFT JOIN [UKHD_Data_Dictionary].[Discharge_Destination_SCD] r4 ON a.[Discharge_Destination] = r4.[Main_Code_Text] AND r4.[Effective_To] IS NULL
	--------------------------------------------------
	LEFT JOIN [UKHD_ICD10].[Codes_And_Titles_And_MetaData] r5 ON a.[Der_Primary_Diagnosis_Code] = r5.[Alt_Code] AND r5.[Effective_To] IS NULL
	--------------------------------------------------
	LEFT JOIN Internal_Reference.ComCodeChanges cc ON a.Der_Commissioner_Code = cc.Org_Code 
	LEFT JOIN Internal_Hierarchies.Commissioner_Hierarchies_TCUBE c ON COALESCE(cc.New_Code, a.Der_Commissioner_Code) = c.Organisation_Code AND c.Organisation_Name NOT LIKE '%REPORTING ENTITY%' AND c.STP_Name <> 'NonSTP (Wales Region)'
	--------------------------------------------------
	LEFT JOIN [Internal_Reference].[Provider_Successor] ps ON  ps.Prov_original = a.Der_Provider_Code
	LEFT JOIN Internal_Hierarchies.Provider_Hierarchies_TCUBE ph ON ph.Organisation_Code =  COALESCE(ps.Prov_successor, a.Der_Provider_Code) AND ph.[Effective_To] IS NULL

WHERE
	(a.[Admission_Date] BETWEEN @admission_period_start AND @admission_period_end OR a.[Discharge_Date] BETWEEN @admission_period_start AND @admission_period_end) 
	AND a.Episode_Number = 1 
	AND (a.Admission_Method LIKE '2%')	--Filters for emergency admissions only
	AND a.[Patient_Classification] IN ('1','2','5')	-- Filters for: 1 = Ordinary admission, 2 = Day case admission, 5 = Mothers and babies using only delivery facilities  


/* - APCS Base Table ----------------------------------------------------------------------------------------------------------------------------------------------------- */


-- Record level values of APCS data for the 12 month period defined by @admission_period_start and @admission_period_end above (that are aggregated later) 

IF OBJECT_ID ('[MHDInternal].[TEMP_DEM_SUS_APCS_Base]') IS NOT NULL 
DROP TABLE [MHDInternal].[TEMP_DEM_SUS_APCS_Base]

SELECT
	b.[APCS_Ident]
	,DATEADD(MONTH, DATEDIFF(MONTH, 0, b.Admission_Date), 0) AS [Admission_Month]
	,b.[Age_At_Start_of_Spell_SUS] -- for emergency admissions over 65 group defined later
	,CASE -- for length of stay groupings
		WHEN [Der_Spell_LoS] <= 1 THEN '1 Day or less'
		WHEN [Der_Spell_LoS] BETWEEN 2 and 3 THEN 'Between 2 and 3 Days'
		WHEN [Der_Spell_LoS] BETWEEN 4 AND 10 THEN 'Between 4 and 10 Days'
		WHEN [Der_Spell_LoS] BETWEEN 11 AND 21 THEN 'Between 11 and 21 Days'
		WHEN [Der_Spell_LoS] > 21 THEN 'More than 21 Days' END 
	AS [LengthOfStay]
	--Dementia/MCI ICD10 codes from Page 13 of Dementia Care Pathway Appendices
	,CASE WHEN
		b.Der_Diagnosis_All LIKE '%F000%'  OR 
		b.Der_Diagnosis_All LIKE '%F001%' OR 
		b.Der_Diagnosis_All LIKE '%F002%' OR 
		b.Der_Diagnosis_All LIKE '%F009%' OR 
		b.Der_Diagnosis_All LIKE '%F010%' OR 
		b.Der_Diagnosis_All LIKE '%F011%' OR 
		b.Der_Diagnosis_All LIKE '%F012%' OR 
		b.Der_Diagnosis_All LIKE '%F013%' OR 
		b.Der_Diagnosis_All LIKE '%F018%' OR 
		b.Der_Diagnosis_All LIKE '%F019%' OR 
		b.Der_Diagnosis_All LIKE '%F020%' OR 
		b.Der_Diagnosis_All LIKE '%F021%'  OR 
		b.Der_Diagnosis_All LIKE '%F022%'  OR 
		b.Der_Diagnosis_All LIKE '%F023%'  OR 
		b.Der_Diagnosis_All LIKE '%F024%'  OR 
		b.Der_Diagnosis_All LIKE '%F028%' OR
	   (b.Der_Diagnosis_All LIKE '%F028%' AND b.Der_Diagnosis_All LIKE '%G318%') OR
		b.Der_Diagnosis_All LIKE '%F03%' OR
		b.Der_Diagnosis_All LIKE '%F051%' THEN 1 ELSE 0 END 
	AS [Dementia]
	,CASE WHEN b.Der_Diagnosis_All LIKE '%F067%' THEN 1 ELSE 0 END AS [MCI]
	,CASE WHEN (b.Der_Diagnosis_All LIKE '%F050%' OR b.Der_Diagnosis_All LIKE '%F058%' OR b.Der_Diagnosis_All LIKE '%F059%') THEN 1 ELSE 0 END AS [Delirium]
	--------------------------------------------------
	,CASE WHEN ph.[Organisation_Code] IS NOT NULL THEN ph.[Organisation_Code] ELSE 'Other' END AS [Provider_Code]
	,CASE WHEN ph.[Organisation_Name] IS NOT NULL THEN ph.[Organisation_Name] ELSE 'Other' END AS [Provider Name]
	,CASE WHEN ph.[Region_Name] IS NOT NULL THEN ph.[Region_Name] ELSE 'Other' END AS [Region_Name_Provider]
	,CASE WHEN c.Organisation_Code IS NULL THEN 'Other ' ELSE c.Organisation_Code END AS [Sub ICB Code]
	,CASE WHEN c.Organisation_Code IS NULL THEN 'Other ' ELSE c.Organisation_Name END AS [Sub ICB Name]
	,CASE WHEN c.Organisation_Code IS NULL THEN 'Other' ELSE c.Region_Code END AS [Region Code]
	,CASE WHEN c.Organisation_Code IS NULL THEN 'Other' ELSE c.Region_Name END AS [Region Name]

INTO [MHDInternal].[TEMP_DEM_SUS_APCS_Base]

FROM 
	[Reporting_MESH_APC].[APCS_Core_Monthly_Snapshot] b
	--------------------------------------------------
	LEFT JOIN Internal_Reference.ComCodeChanges cc ON b.Der_Commissioner_Code = cc.Org_Code 
	LEFT JOIN Internal_Hierarchies.Commissioner_Hierarchies_TCUBE c ON COALESCE(cc.New_Code, b.Der_Commissioner_Code) = c.Organisation_Code AND c.Organisation_Name NOT LIKE '%REPORTING ENTITY%' AND c.STP_Name <> 'NonSTP (Wales Region)'
	--------------------------------------------------
	LEFT JOIN [Internal_Reference].[Provider_Successor] ps ON  ps.Prov_original = b.Der_Provider_Code
	LEFT JOIN Internal_Hierarchies.Provider_Hierarchies_TCUBE ph ON ph.Organisation_Code =  COALESCE(ps.Prov_successor, b.Der_Provider_Code) AND ph.[Effective_To] IS NULL

WHERE 
	([Admission_Date] BETWEEN @admission_period_start AND @admission_period_end) 
	AND (Admission_Method LIKE '2%') -- emergency admissions only
	AND [Patient_Classification] IN ('1','2','5') -- 1 = Ordinary admission, 2 = Day case admission, 5 = Mothers and babies using only delivery facilities  



--- Map any old SICBs to new SICBs with relevant population weighting 
IF OBJECT_ID ('tempdb..#SICB_Reference') IS NOT NULL
DROP TABLE #SICB_Reference

SELECT 
	Sub_ICB_Location_ODS_Code AS SubICB_Code 
	,Sub_ICB_Location_Name AS SubICB_Name 
	,CAST(1 as float) AS PopWeight 
	 ,Sub_ICB_Location_ODS_Code AS SubICB26_Code 
	 ,Sub_ICB_Location_Name AS SubICB26_Name
	,ICB_Code 
	,Integrated_Care_Board_Name AS ICB_Name 
	,Region_Code
	,CASE 
		WHEN Region_Name = 'EAST OF ENGLAND COMMISSIONING REGION' THEN 'East Of England'
		WHEN Region_Name = 'LONDON COMMISSIONING REGION' THEN 'London'
		WHEN Region_Name = 'MIDLANDS COMMISSIONING REGION' THEN 'Midlands'
		WHEN Region_Name = 'NORTH EAST AND YORKSHIRE COMMISSIONING REGION' THEN 'North East And Yorkshire'
		WHEN Region_Name = 'NORTH WEST COMMISSIONING REGION' THEN 'North West'
		WHEN Region_Name = 'SOUTH EAST COMMISSIONING REGION' THEN 'South East'
		WHEN Region_Name = 'SOUTH WEST COMMISSIONING REGION' THEN 'South West'
	END AS Region_Name

INTO #SICB_Reference 

FROM Internal_Hierarchies.SICBL_Apr2026 

INSERT INTO #SICB_Reference
VALUES
('D4U1Y','NHS FRIMLEY (D4U1Y)', 0.18204175443292, '92A','NHS SURREY AND SUSSEX ICB - 92A', 'S9B9J', 'NHS SURREY AND SUSSEX INTEGRATED CARE BOARD','Y59','South East'),
('D4U1Y','NHS FRIMLEY (D4U1Y)', 0.229339252148803, 'D9Y0V','NHS HAMPSHIRE AND ISLE OF WIGHT ICB - D9Y0V', 'QRL', 'NHS HAMPSHIRE AND ISLE OF WIGHT INTEGRATED CARE BOARD','Y59','South East'),
('D4U1Y','NHS FRIMLEY (D4U1Y)', 0.588618993418278,'U2G6B','NHS THAMES VALLEY ICB - U2G6B','S0E4D', 'NHS THAMES VALLEY INTEGRATED CARE BOARD','Y59','South East')


SELECT *FROM #SICB_Reference 

---- Aggregate to subICBs, weighting Frimley as needed 

-- 1.1 APCE Admissions 

IF OBJECT_ID ('[MHDInternal].[AggSICB_APCE_Base_Admissions]') IS NOT NULL 
DROP TABLE [MHDInternal].[AggSICB_APCE_Base_Admissions]

SELECT 
	b.Admission_Month
	,b.[Sub ICB Code]
	,b.[Sub ICB Name]
	,ISNULL(r.SubICB26_Code,'Other') AS SubICB26_Code
	,ISNULL(r.SubICB26_Name,'Other') AS SubICB26_Name
	,ISNULL(r.ICB_Code,'Other') AS ICB_Code
	,ISNULL(r.ICB_Name,'Other') AS ICB_Name
	,ISNULL(r.Region_Code,'Other') AS Region_Code
	,ISNULL(r.Region_Name,'Other') AS Region_Name
	,CASE 
		WHEN GROUPING(Gender) = 0 THEN 'Gender' 
		WHEN GROUPING(Ethnicity) = 0 THEN 'Ethnicity' 
		WHEN GROUPING(Admission_Source) = 0 THEN 'Admission Source'
		WHEN GROUPING([Primary Diagnosis]) = 0 THEN 'Primary Diagnosis'
	ELSE 'Totals' 
	END AS Category  
	,CASE 
		WHEN GROUPING(Gender) = 0 THEN Gender
		WHEN GROUPING(Ethnicity) = 0 THEN Ethnicity
		WHEN GROUPING(Admission_Source) = 0 THEN Admission_Source
		WHEN GROUPING([Primary Diagnosis]) = 0 THEN [Primary Diagnosis]
	ELSE 'Totals' 
	END AS Variable  
	,MAX(ISNULL(r.PopWeight,1)) AS PopWeight
	,SUM(ISNULL(r.PopWeight,1)) AS Num_Emergency_Admissions
	,SUM(CASE WHEN [Age_on_Admission] >= 65 THEN 1 * ISNULL(r.PopWeight,1) ELSE 0 END) AS Num_Emergency_Admissions_65andOver
	,SUM([Dementia] *  ISNULL(r.PopWeight,1)) AS Num_Emergency_Admissions_Dementia
	,SUM(Delirium * ISNULL(r.PopWeight,1)) AS Num_Emergency_Admissions_Delirium
	,SUM([MCI] * ISNULL(r.PopWeight,1)) AS [Num_Emergency_Admissions_MCI]
	,CASE WHEN GROUPING([Primary Diagnosis]) = 0 THEN [Primary Diagnosis Chapter] ELSE NULL END AS [Primary Diagnosis Chapter]

INTO [MHDInternal].[AggSICB_APCE_Base_Admissions]

FROM [MHDInternal].[TEMP_DEM_SUS_APCE_Base] b 

LEFT JOIN #SICB_Reference r ON b.[Sub ICB Code]= r.SubICB_Code

WHERE Der_Admission = 1 

GROUP BY GROUPING SETS ( 
	(b.Admission_Month,b.[Sub ICB Code],b.[Sub ICB Name],ISNULL(r.SubICB26_Code,'Other') ,ISNULL(r.SubICB26_Name,'Other') ,ISNULL(r.ICB_Code,'Other'),ISNULL(r.ICB_Name,'Other') ,ISNULL(r.Region_Code,'Other') ,ISNULL(r.Region_Name,'Other')),
	(Gender,b.Admission_Month,b.[Sub ICB Code],b.[Sub ICB Name],ISNULL(r.SubICB26_Code,'Other') ,ISNULL(r.SubICB26_Name,'Other') ,ISNULL(r.ICB_Code,'Other'),ISNULL(r.ICB_Name,'Other') ,ISNULL(r.Region_Code,'Other') ,ISNULL(r.Region_Name,'Other')),
	(Ethnicity,b.Admission_Month,b.[Sub ICB Code],b.[Sub ICB Name],ISNULL(r.SubICB26_Code,'Other') ,ISNULL(r.SubICB26_Name,'Other') ,ISNULL(r.ICB_Code,'Other'),ISNULL(r.ICB_Name,'Other') ,ISNULL(r.Region_Code,'Other') ,ISNULL(r.Region_Name,'Other')),
	(Admission_Source,b.Admission_Month,b.[Sub ICB Code],b.[Sub ICB Name],ISNULL(r.SubICB26_Code,'Other') ,ISNULL(r.SubICB26_Name,'Other') ,ISNULL(r.ICB_Code,'Other'),ISNULL(r.ICB_Name,'Other') ,ISNULL(r.Region_Code,'Other') ,ISNULL(r.Region_Name,'Other')),
	([Primary Diagnosis],[Primary Diagnosis Chapter],b.Admission_Month,b.[Sub ICB Code],b.[Sub ICB Name],ISNULL(r.SubICB26_Code,'Other') ,ISNULL(r.SubICB26_Name,'Other ') ,ISNULL(r.ICB_Code,'Other'),ISNULL(r.ICB_Name,'Other') ,ISNULL(r.Region_Code,'Other') ,ISNULL(r.Region_Name,'Other'))
	)

--- 1.2 APCE Base discharges 

IF OBJECT_ID ('[MHDInternal].[AggSICB_APCE_Base_Discharges]') IS NOT NULL 
DROP TABLE [MHDInternal].[AggSICB_APCE_Base_Discharges]

SELECT 
	b.Discharge_Month
	,b.[Sub ICB Code]
	,b.[Sub ICB Name]
	,ISNULL(r.SubICB26_Code,'Other') AS SubICB26_Code
	,ISNULL(r.SubICB26_Name,'Other') AS SubICB26_Name
	,ISNULL(r.ICB_Code,'Other') AS ICB_Code
	,ISNULL(r.ICB_Name,'Other') AS ICB_Name
	,ISNULL(r.Region_Code,'Other') AS Region_Code
	,ISNULL(r.Region_Name,'Other') AS Region_Name
	,CASE 
		WHEN GROUPING(Discharge_Destination) = 0 THEN 'Discharge Destination' 
	ELSE 'Totals' 
	END AS Category  
	,CASE 
		WHEN GROUPING(Discharge_Destination) = 0 THEN Discharge_Destination
	ELSE 'Totals' 
	END AS Variable  
	,MAX(ISNULL(r.PopWeight,1)) AS PopWeight
	,SUM(ISNULL(r.PopWeight,1)) AS Num_Emergency_Admissions
	,SUM(CASE WHEN [Age_on_Admission] >= 65 THEN 1 * ISNULL(r.PopWeight,1) ELSE 0 END) AS Num_Emergency_Admissions_65andOver
	,SUM([Dementia] *  ISNULL(r.PopWeight,1)) AS Num_Emergency_Admissions_Dementia
	,SUM(Delirium * ISNULL(r.PopWeight,1)) AS Num_Emergency_Admissions_Delirium
	,SUM([MCI] * ISNULL(r.PopWeight,1)) AS [Num_Emergency_Admissions_MCI]

INTO [MHDInternal].[AggSICB_APCE_Base_Discharges]

FROM [MHDInternal].[TEMP_DEM_SUS_APCE_Base] b 

LEFT JOIN #SICB_Reference r ON b.[Sub ICB Code]= r.SubICB_Code

WHERE Der_Discharge = 1 

GROUP BY GROUPING SETS ( 
	(Discharge_Destination,b.Discharge_Month,b.[Sub ICB Code],b.[Sub ICB Name],ISNULL(r.SubICB26_Code,'Other') ,ISNULL(r.SubICB26_Name,'Other') ,ISNULL(r.ICB_Code,'Other'),ISNULL(r.ICB_Name,'Other') ,ISNULL(r.Region_Code,'Other') ,ISNULL(r.Region_Name,'Other'))
	)

-- 1.3 APCE Length of stay 

IF OBJECT_ID ('[MHDInternal].[AggSICB_APCS_LOS]') IS NOT NULL 
DROP TABLE [MHDInternal].[AggSICB_APCS_LOS]

SELECT 
	b.Admission_Month
	,b.[Sub ICB Code]
	,b.[Sub ICB Name]
	,ISNULL(r.SubICB26_Code,'Other') AS SubICB26_Code
	,ISNULL(r.SubICB26_Name,'Other') AS SubICB26_Name
	,ISNULL(r.ICB_Code,'Other') AS ICB_Code
	,ISNULL(r.ICB_Name,'Other') AS ICB_Name
	,ISNULL(r.Region_Code,'Other') AS Region_Code
	,ISNULL(r.Region_Name,'Other') AS Region_Name
	,CASE 
		WHEN GROUPING(LengthOfStay) = 0 THEN 'Length of Stay' 
	ELSE 'Totals' 
	END AS Category  
	,CASE 
		WHEN GROUPING(LengthOfStay) = 0 THEN LengthOfStay
	ELSE 'Totals' 
	END AS Variable  
	,MAX(ISNULL(r.PopWeight,1)) AS PopWeight
	,SUM(ISNULL(r.PopWeight,1)) AS Num_Emergency_Admissions
	,SUM(CASE WHEN Age_At_Start_of_Spell_SUS >= 65 THEN 1 * ISNULL(r.PopWeight,1) ELSE 0 END) AS Num_Emergency_Admissions_65andOver
	,SUM([Dementia] *  ISNULL(r.PopWeight,1)) AS Num_Emergency_Admissions_Dementia
	,SUM(Delirium * ISNULL(r.PopWeight,1)) AS Num_Emergency_Admissions_Delirium
	,SUM([MCI] * ISNULL(r.PopWeight,1)) AS [Num_Emergency_Admissions_MCI]

INTO [MHDInternal].[AggSICB_APCS_LOS]

FROM [MHDInternal].[TEMP_DEM_SUS_APCS_Base] b 

LEFT JOIN #SICB_Reference r ON b.[Sub ICB Code]= r.SubICB_Code

GROUP BY GROUPING SETS ( 
	(LengthOfStay,b.Admission_Month,b.[Sub ICB Code],b.[Sub ICB Name],ISNULL(r.SubICB26_Code,'Other') ,ISNULL(r.SubICB26_Name,'Other') ,ISNULL(r.ICB_Code,'Other'),ISNULL(r.ICB_Name,'Other') ,ISNULL(r.Region_Code,'Other') ,ISNULL(r.Region_Name,'Other'))
	)



--- 2.0 Aggregate for final unsuppressed output table 
-- 2.1 Aggregate base tables for provider and England level counts 
-- 2.1.1 APCE Admissions 

IF OBJECT_ID ('[MHDInternal].[TEMP_DEM_SUS_Admissions_Unsuppressed_New]') IS NOT NULL 
DROP TABLE [MHDInternal].[TEMP_DEM_SUS_Admissions_Unsuppressed_New]

SELECT 
	[Admission_Month] AS [Month]
	,CASE 
		WHEN GROUPING([Provider Name])=0 THEN 'Provider'
	ELSE 'National' 
	END AS [GroupType]
	,CASE 
		WHEN GROUPING([Provider Name])=0 THEN Region_Name_Provider
	ELSE 'All Regions' 
	END AS RegionCode 
	,CASE 
		WHEN GROUPING([Provider Name])=0 THEN [Provider Name] 
	ELSE 'England'
	END AS GeographyName 
	,CASE 
		WHEN GROUPING([Provider Name])=0 THEN Provider_Code 
	ELSE 'England'
	END AS GeographyCode
	,CASE
		WHEN GROUPING(Gender)=0 THEN CAST('Gender' AS VARCHAR(MAX))
		WHEN GROUPING(Ethnicity)=0 THEN CAST('Ethnicity' AS VARCHAR(MAX))
		WHEN GROUPING(Admission_Source)=0 THEN CAST('Admission Source' AS VARCHAR(MAX))
		WHEN GROUPING([Primary Diagnosis])=0 THEN CAST('Primary Diagnosis' AS VARCHAR(MAX))
	ELSE CAST('Total' AS VARCHAR(MAX))
	END AS [Category]
	,CASE
		WHEN GROUPING(Gender)=0 THEN CAST(Gender AS VARCHAR(MAX))
		WHEN GROUPING(Ethnicity)=0 THEN  CAST(Ethnicity AS VARCHAR(MAX))
		WHEN GROUPING(Admission_Source)=0 THEN  CAST(Admission_Source AS VARCHAR(MAX))
		WHEN GROUPING([Primary Diagnosis])=0 THEN CAST([Primary Diagnosis] AS VARCHAR(MAX))
	ELSE  CAST('Total' AS VARCHAR(MAX))
	END AS [Variable]
	,CAST(COUNT(*) AS FLOAT) AS [Num_Emergency_Admissions]
	,CAST(SUM(CASE WHEN [Age_on_Admission] >= 65 THEN 1 ELSE 0 END) AS FLOAT) AS [Num_Emergency_Admissions_65andOver]
	,CAST(SUM([Dementia]) AS FLOAT) AS [Num_Emergency_Admissions_Dementia]
	,CAST(SUM([Delirium]) AS FLOAT) AS [Num_Emergency_Admissions_Delirium]
	,CAST(SUM([MCI]) AS FLOAT) AS [Num_Emergency_Admissions_MCI]
	,CASE WHEN GROUPING([Primary Diagnosis]) = 0 THEN [Primary Diagnosis Chapter] ELSE NULL END AS [Primary Diagnosis Chapter]

INTO [MHDInternal].[TEMP_DEM_SUS_Admissions_Unsuppressed_New]

FROM [MHDInternal].[TEMP_DEM_SUS_APCE_Base] b 

WHERE Der_Admission = 1  

GROUP BY GROUPING SETS ( 
	(Admission_Month), -- England, totals 
	(Admission_Month, Gender), -- England, gender 
	(Admission_Month, Ethnicity), -- England, ethnicity
	(Admission_Month, Admission_Source), -- England, admission source	
	(Admission_Month, [Primary Diagnosis], [Primary Diagnosis Chapter]), -- England, diagnosis
	(Admission_Month, [Provider Name], Region_Name_Provider, Provider_Code), -- provider, totals 
	(Admission_Month, [Provider Name], Region_Name_Provider, Provider_Code,Gender), -- provider, gender 
	(Admission_Month, [Provider Name], Region_Name_Provider, Provider_Code, Ethnicity), -- provider, ethnicity
	(Admission_Month, [Provider Name], Region_Name_Provider, Provider_Code, Admission_Source), -- provider, admission source	
	(Admission_Month, [Provider Name], Region_Name_Provider, Provider_Code, [Primary Diagnosis], [Primary Diagnosis Chapter]) -- provider, diagnosis
	) 

-- 2.1.1 APCE Discharges  
INSERT INTO [MHDInternal].[TEMP_DEM_SUS_Admissions_Unsuppressed_New]

SELECT 
	Discharge_Month AS [Month]
	,CASE 
		WHEN GROUPING([Provider Name])=0 THEN 'Provider'
	ELSE 'National' 
	END AS [GroupType]
	,CASE 
		WHEN GROUPING([Provider Name])=0 THEN Region_Name_Provider
	ELSE 'All Regions' 
	END AS RegionCode 
	,CASE 
		WHEN GROUPING([Provider Name])=0 THEN [Provider Name] 
	ELSE 'England'
	END AS GeographyName 
	,CASE 
		WHEN GROUPING([Provider Name])=0 THEN Provider_Code 
	ELSE 'England'
	END AS GeographyCode
	,'Discharge Destination' AS [Category]
	,Discharge_Destination AS [Variable]
	,COUNT(*) AS [Num_Emergency_Admissions]
	,SUM(CASE WHEN [Age_on_Admission] >= 65 THEN 1 ELSE 0 END) AS [Num_Emergency_Admissions_65andOver]
	,SUM([Dementia]) AS [Num_Emergency_Admissions_Dementia]
	,SUM([Delirium]) AS [Num_Emergency_Admissions_Delirium]
	,SUM([MCI]) AS [Num_Emergency_Admissions_MCI]
	,NULL AS [Primary Diagnosis Chapter]

FROM [MHDInternal].[TEMP_DEM_SUS_APCE_Base] b 

WHERE Der_Discharge = 1  

GROUP BY GROUPING SETS ( 
	(Discharge_Month, Discharge_Destination), -- England, discharge destination 
	(Discharge_Month, [Provider Name], Provider_Code, Region_Name_Provider, Discharge_Destination) -- provider, discharge destination 
	) 

-- 2.1.1 APCS Length of stay   
INSERT INTO [MHDInternal].[TEMP_DEM_SUS_Admissions_Unsuppressed_New]

SELECT 
	Admission_Month AS [Month]
	,CASE 
		WHEN GROUPING([Provider Name])=0 THEN 'Provider'
	ELSE 'National' 
	END AS [GroupType]
	,CASE 
		WHEN GROUPING([Provider Name])=0 THEN Region_Name_Provider
	ELSE 'All regions' 
	END AS RegionCode 
	,CASE 
		WHEN GROUPING([Provider Name])=0 THEN [Provider Name] 
	ELSE 'England'
	END AS GeographyName 
	,CASE 
		WHEN GROUPING([Provider Name])=0 THEN Provider_Code 
	ELSE 'England'
	END AS GeographyCode
	,'Length of Stay' AS [Category]
	,LengthOfStay AS [Variable]
	,COUNT(*) AS [Num_Emergency_Admissions]
	,SUM(CASE WHEN Age_At_Start_of_Spell_SUS >= 65 THEN 1 ELSE 0 END) AS [Num_Emergency_Admissions_65andOver]
	,SUM([Dementia]) AS [Num_Emergency_Admissions_Dementia]
	,SUM([Delirium]) AS [Num_Emergency_Admissions_Delirium]
	,SUM([MCI]) AS [Num_Emergency_Admissions_MCI]
	,NULL AS [Primary Diagnosis Chapter]

FROM [MHDInternal].[TEMP_DEM_SUS_APCS_Base] b 

GROUP BY GROUPING SETS ( 
	(Admission_Month, LengthOfStay), -- England, LOS 
	(Admission_Month, [Provider Name], Provider_Code, Region_Name_Provider, LengthOfStay) -- provider, LOS 
	) 

--- 3.0 Aggregate ICB and Sub-ICB from staging table 
--- 3.1 APCE Admissions 

INSERT INTO [MHDInternal].[TEMP_DEM_SUS_Admissions_Unsuppressed_New]

SELECT 
	[Admission_Month] AS [Month]
	,CASE 
		WHEN GROUPING([SubICB26_Name])=0 THEN 'Sub ICB' 
		WHEN GROUPING([ICB_Name])=0 THEN 'ICB' 
	END AS GroupType 
	,Region_Name AS RegionCode 
	,CASE 
		WHEN GROUPING([SubICB26_Name])=0 THEN SubICB26_Name
		WHEN GROUPING([ICB_Name])=0 THEN ICB_Name
	END AS GeographyName 
	,CASE 
		WHEN GROUPING([SubICB26_Name])=0 THEN SubICB26_Code
		WHEN GROUPING([ICB_Name])=0 THEN ICB_Code
	END AS GeographyCode
	,Category
	,Variable
	,SUM([Num_Emergency_Admissions]) AS [Num_Emergency_Admissions]
	,SUM([Num_Emergency_Admissions_65andOver]) AS [Num_Emergency_Admissions_65andOver]
	,SUM([Num_Emergency_Admissions_Dementia]) AS [Num_Emergency_Admissions_Dementia]
	,SUM([Num_Emergency_Admissions_Delirium]) AS [Num_Emergency_Admissions_Delirium]
	,SUM([Num_Emergency_Admissions_MCI]) AS [Num_Emergency_Admissions_MCI]
	,[Primary Diagnosis Chapter]

FROM [MHDInternal].[AggSICB_APCE_Base_Admissions] b 

GROUP BY GROUPING SETS ( 
	(Admission_Month, Category, Variable, [Primary Diagnosis Chapter], Region_Name, SubICB26_Code, [SubICB26_Name]), -- all sub ICBs 
	(Admission_Month, Category, Variable, [Primary Diagnosis Chapter], Region_Name, ICB_Code,ICB_Name) -- all ICBs
	)



-- 3.2 APCE Discharges 

INSERT INTO [MHDInternal].[TEMP_DEM_SUS_Admissions_Unsuppressed_New]

SELECT 
	Discharge_Month AS [Month]
	,CASE 
		WHEN GROUPING([SubICB26_Name])=0 THEN 'Sub ICB' 
		WHEN GROUPING([ICB_Name])=0 THEN 'ICB' 
	END AS GroupType 
	,Region_Name AS RegionCode 
	,CASE 
		WHEN GROUPING([SubICB26_Name])=0 THEN SubICB26_Name
		WHEN GROUPING([ICB_Name])=0 THEN ICB_Name
	END AS GeographyName 
	,CASE 
		WHEN GROUPING([SubICB26_Name])=0 THEN SubICB26_Code
		WHEN GROUPING([ICB_Name])=0 THEN ICB_Code
	END AS GeographyCode
	,Category
	,Variable
	,SUM([Num_Emergency_Admissions]) AS [Num_Emergency_Admissions]
	,SUM([Num_Emergency_Admissions_65andOver]) AS [Num_Emergency_Admissions_65andOver]
	,SUM([Num_Emergency_Admissions_Dementia]) AS [Num_Emergency_Admissions_Dementia]
	,SUM([Num_Emergency_Admissions_Delirium]) AS [Num_Emergency_Admissions_Delirium]
	,SUM([Num_Emergency_Admissions_MCI]) AS [Num_Emergency_Admissions_MCI]
	,NULL [Primary Diagnosis Chapter]

FROM [MHDInternal].[AggSICB_APCE_Base_Discharges] b 

GROUP BY GROUPING SETS ( 
	(Discharge_Month, Category, Variable , Region_Name, SubICB26_Code, [SubICB26_Name]), -- all sub ICBs 
	(Discharge_Month, Category, Variable, Region_Name, ICB_Code,ICB_Name) -- all ICBs
	)


-- 3.3 APCS Length of Stay  

INSERT INTO [MHDInternal].[TEMP_DEM_SUS_Admissions_Unsuppressed_New]

SELECT 
	Admission_Month AS [Month]
	,CASE 
		WHEN GROUPING([SubICB26_Name])=0 THEN 'Sub ICB' 
		WHEN GROUPING([ICB_Name])=0 THEN 'ICB' 
	END AS GroupType 
	,Region_Name AS RegionCode 
	,CASE 
		WHEN GROUPING([SubICB26_Name])=0 THEN SubICB26_Name
		WHEN GROUPING([ICB_Name])=0 THEN ICB_Name
	END AS GeographyName 
	,CASE 
		WHEN GROUPING([SubICB26_Name])=0 THEN SubICB26_Code
		WHEN GROUPING([ICB_Name])=0 THEN ICB_Code
	END AS GeographyCode
	,Category
	,Variable
	,SUM([Num_Emergency_Admissions]) AS [Num_Emergency_Admissions]
	,SUM([Num_Emergency_Admissions_65andOver]) AS [Num_Emergency_Admissions_65andOver]
	,SUM([Num_Emergency_Admissions_Dementia]) AS [Num_Emergency_Admissions_Dementia]
	,SUM([Num_Emergency_Admissions_Delirium]) AS [Num_Emergency_Admissions_Delirium]
	,SUM([Num_Emergency_Admissions_MCI]) AS [Num_Emergency_Admissions_MCI]
	,NULL [Primary Diagnosis Chapter]

FROM [MHDInternal].[AggSICB_APCS_LOS] b 

GROUP BY GROUPING SETS ( 
	(Admission_Month, Category, Variable , Region_Name, SubICB26_Code,[SubICB26_Name]), -- all sub ICBs 
	(Admission_Month, Category, Variable, Region_Name, ICB_Code, ICB_Name) -- all ICBs
	)




--- Suppress output and put into backing table 

INSERT INTO [MHDInternal].[DASHBOARD_DEM_SUS_Emergency_Admissions_New]

SELECT
	[Month]
	,[GroupType]
	,[RegionCode]
	,[GeographyName]
	,[Category]
	,[Variable]
	,CASE WHEN [Num_Emergency_Admissions] < 7 THEN '*' ELSE CAST((Num_Emergency_Admissions) AS VARCHAR) END AS [Emergency Admissions]
	,CASE WHEN [Num_Emergency_Admissions_65andOver] < 7 THEN '*' ELSE CAST((Num_Emergency_Admissions_65andOver) AS VARCHAR) END AS [Emergency Admissions - Aged 65 Years and Over]
	,CASE WHEN [Num_Emergency_Admissions_Dementia] < 7 THEN '*' ELSE CAST((Num_Emergency_Admissions_Dementia) AS VARCHAR) END AS [Emergency Admissions - Dementia Diagnosis] 
	,CASE WHEN [Num_Emergency_Admissions_Delirium] < 7 THEN '*' ELSE CAST((Num_Emergency_Admissions_Delirium) AS VARCHAR) END AS [Emergency Admissions - Delirium Diagnosis]
	,CASE WHEN [Num_Emergency_Admissions_MCI] < 7 THEN '*' ELSE CAST((Num_Emergency_Admissions_MCI) AS VARCHAR) END AS [Emergency Admissions - MCI Diagnosis]
	,[Primary Diagnosis Chapter]
	,GETDATE() AS [SnapshotDate]
	
FROM [MHDInternal].[TEMP_DEM_SUS_Admissions_Unsuppressed_New]
