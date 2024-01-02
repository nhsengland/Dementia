 /****** Script for emergency admissions for the Emergency Admissions for Dementia and Delirium Dashboard ******/

 -------------------------------------------------------------------------------------------------------------
 ------------------------------------Step 1-------------------------------------------------------------------
--The last 11 months of data are refreshed each month so the current version of these months are deleted from the table used in the dashboard 
--and added to an old refresh table to keep as a record. The old refresh data will be removed after a year (i.e. once it is no longer refreshed).

DECLARE @Period_Start1 DATE
DECLARE @Period_End1 DATE

--Period Start1 is the beginning of the month 11 months prior to the latest month in the extract of the data used in the dashboard (as the last 12 months get refreshed each month)
--Period End1 is the end of the latest month in last month's extract of the data used in the dashboard
SET @Period_End1 = (SELECT EOMONTH(MAX(Month)) FROM [MHDInternal].[DASHBOARD_DEM_SUS_Emergency_Admissions])
SET @Period_Start1 = (SELECT DATEADD(DAY,1, EOMONTH(DATEADD(MONTH,-11,@Period_End1))))

PRINT CAST(@Period_Start1 AS VARCHAR(10)) + ' <-- Period_Start'
PRINT CAST(@Period_End1 AS VARCHAR(10)) + ' <-- Period_End'

DELETE [MHDInternal].[DASHBOARD_DEM_SUS_Emergency_Admissions]
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
INTO [MHDInternal].[STAGING_DEM_SUS_Emergency_Admissions_Old_Refresh](
	[Month]
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
WHERE [Month] BETWEEN @Period_Start1 AND @Period_End1 --last 11 months
GO
-------------------------------------------------End of Step 1------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------Step 2-----------------------------------------------------------------
--Run Step 2
DECLARE @Period_Start DATE
DECLARE @Period_End DATE

--Period Start is the beginning of the month 12 months prior to the latest month (meaning the last 12 months get refreshed each month)
--Period End is the end of the latest month
SET @Period_End = (SELECT DATEADD(MONTH,+12,EOMONTH(MAX(Month))) FROM [MHDInternal].[DASHBOARD_DEM_SUS_Emergency_Admissions])
SET @Period_Start = (SELECT DATEADD(DAY,1, EOMONTH(DATEADD(MONTH,-12,@Period_End))))

PRINT CAST(@Period_Start AS VARCHAR(10)) + ' <-- Period_Start'
PRINT CAST(@Period_End AS VARCHAR(10)) + ' <-- Period_End'

----------------------------------------------APCE Base Table-----------------------------------------------------------------------------------------------------
--Creates a base table (this a record level table that can be aggregated later) of APCE data for the 12 month period defined by @Period_Start and @Period_End above.
IF OBJECT_ID ('[MHDInternal].[TEMP_DEM_SUS_APCE_Base]') IS NOT NULL DROP TABLE [MHDInternal].[TEMP_DEM_SUS_APCE_Base]
SELECT 
	a.APCE_Ident
	,DATEADD(MONTH, DATEDIFF(MONTH, 0, a.Admission_Date), 0) AS Admission_Month
	,DATEADD(MONTH, DATEDIFF(MONTH, 0, a.Discharge_Date), 0) AS Discharge_Month
--Data is later presented as the Categories of Gender, Ethnicity, Admission Source and Discharge Destination
	,ISNULL(r1.Main_Description,'Missing/invalid') AS Gender
	,ISNULL(r2.Main_Description, 'Missing/invalid') AS Ethnicity
	,ISNULL(r3.Main_Description,'Missing/invalid') AS Admission_Source
	,ISNULL(r4.Main_Description,'Missing/invalid') AS Discharge_Destination
--For Primary Diagnosis and Chapter filters	
	,CASE WHEN r5.Category_2_Code IS NOT NULL AND r5.Category_2_Description IS NOT NULL THEN CONCAT(r5.[Category_2_Code],': ', r5.Category_2_Description) ELSE NULL 
	END AS [Primary Diagnosis]
	,CASE WHEN r5.Chapter_Code IS NOT NULL AND r5.Chapter_Description IS NOT NULL THEN CONCAT(r5.Chapter_Code,': ', r5.Chapter_Description) ELSE NULL 
	END AS [Primary Diagnosis Chapter]
--Defines Admissions and Discharges
	,CASE WHEN a.Admission_Date BETWEEN @Period_Start and @Period_End THEN 1 ELSE 0 END AS Der_Admission 
	,CASE WHEN a.Discharge_Date BETWEEN @Period_Start and @Period_End THEN 1 ELSE 0 END AS Der_Discharge 
	,a.Age_on_Admission	--For emergency admissions over 65 group defined later
--Dementia/MCI ICD10 codes from Page 13 of Dementia Care Pathway Appendices
	,CASE WHEN
		a.Der_Diagnosis_All LIKE '%F000%'  OR 
		a.Der_Diagnosis_All LIKE '%F001%' OR 
		a.Der_Diagnosis_All LIKE '%F002%' OR 
		a.Der_Diagnosis_All LIKE '%F009%' OR 
		a.Der_Diagnosis_All LIKE '%F010%' OR 
		a.Der_Diagnosis_All LIKE '%F011%' OR 
		a.Der_Diagnosis_All LIKE '%F012%' OR 
		a.Der_Diagnosis_All LIKE '%F013%' OR 
		a.Der_Diagnosis_All LIKE '%F018%' OR 
		a.Der_Diagnosis_All LIKE '%F019%' OR 
		a.Der_Diagnosis_All LIKE '%F020%' OR 
		a.Der_Diagnosis_All LIKE '%F021%'  OR 
		a.Der_Diagnosis_All LIKE '%F022%'  OR 
		a.Der_Diagnosis_All LIKE '%F023%'  OR 
		a.Der_Diagnosis_All LIKE '%F024%'  OR 
		a.Der_Diagnosis_All LIKE '%F028%' OR
		(a.Der_Diagnosis_All LIKE '%F028%' AND a.Der_Diagnosis_All LIKE '%G318%') OR
		a.Der_Diagnosis_All LIKE '%F03%' OR
		a.Der_Diagnosis_All LIKE '%F051%' THEN 1 ELSE 0 
	END as Dementia
	,CASE WHEN a.Der_Diagnosis_All LIKE '%F067%' THEN 1 ELSE 0 
	END as MCI
	,CASE WHEN (a.Der_Diagnosis_All LIKE '%F050%' OR a.Der_Diagnosis_All LIKE '%F058%' OR a.Der_Diagnosis_All LIKE '%F059%') THEN 1 ELSE 0 
	END as Delirium

	,CASE WHEN ph.[Organisation_Code] IS NOT NULL THEN ph.[Organisation_Code] ELSE 'Other' END AS 'Provider_Code'
	,CASE WHEN ph.[Organisation_Name] IS NOT NULL THEN ph.[Organisation_Name] ELSE 'Other' END AS 'Provider Name'
	,CASE WHEN ph.[Region_Name] IS NOT NULL THEN ph.[Region_Name] ELSE 'Other' END AS 'Region_Name_Provider'
	,CASE WHEN ch.[Organisation_Code] IS NOT NULL THEN ch.[Organisation_Code] ELSE 'Other' END AS 'Sub ICB Code'
	,CASE WHEN ch.[Organisation_Name] IS NOT NULL THEN ch.[Organisation_Name] ELSE 'Other' END AS 'Sub ICB Name'
	,CASE WHEN ch.[STP_Code] IS NOT NULL THEN ch.[STP_Code] ELSE 'Other' END AS 'ICB Code'
	,CASE WHEN ch.[STP_Name] IS NOT NULL THEN ch.[STP_Name] ELSE 'Other' END AS 'ICB Name'
	,CASE WHEN ch.[Region_Name] IS NOT NULL THEN ch.[Region_Name] ELSE 'Other' END AS'Region_Name_Commissioner'
	,CASE WHEN ch.[Region_Code] IS NOT NULL THEN ch.[Region_Code] ELSE 'Other' END AS 'Region_Code_Commissioner'

INTO [MHDInternal].[TEMP_DEM_SUS_APCE_Base]
FROM [SUS_APC].[APCE_Core] a
	LEFT JOIN [UKHD_Data_Dictionary].[Person_Gender_Code_SCD] r1 ON a.Sex=r1.Main_Code_Text AND r1.Effective_To IS NULL
	LEFT JOIN [UKHD_Data_Dictionary].[Ethnic_Category_Code_SCD] r2 ON a.Ethnic_Group = r2.Main_Code_Text AND r2.Effective_To IS NULL
	LEFT JOIN [UKHD_Data_Dictionary].[Source_Of_Admission_SCD] r3 ON a.Source_of_Admission = r3.Main_Code_Text AND r3.Effective_To IS NULL AND r3.Valid_From IS NULL
	LEFT JOIN [UKHD_Data_Dictionary].[Discharge_Destination_SCD] r4 ON a.Discharge_Destination = r4.Main_Code_Text AND r4.Effective_To IS NULL
	LEFT JOIN [UKHD_ICD10].[Codes_And_Titles_And_MetaData] r5 ON a.[Der_Primary_Diagnosis_Code] = r5.Alt_Code AND r5.[Effective_To] IS NULL
--Four tables joined to get Provider, Sub-ICB, ICB and Region codes and names
	LEFT JOIN [Internal_Reference].[ComCodeChanges] cc ON (CASE WHEN a.Commissioner_Code LIKE '%00' THEN LEFT(a.Commissioner_Code,3) ELSE a.Commissioner_Code END)= cc.Org_Code COLLATE database_default
	LEFT JOIN [Reporting].[Ref_ODS_Commissioner_Hierarchies_ICB] ch ON COALESCE(cc.New_Code, (CASE WHEN a.Commissioner_Code LIKE '%00' THEN LEFT(a.Commissioner_Code,3) ELSE a.Commissioner_Code END)) = ch.Organisation_Code COLLATE database_default 
		AND ch.Effective_To IS NULL
	LEFT JOIN [Internal_Reference].[Provider_Successor] ps ON (CASE WHEN a.Der_Provider_Code LIKE '%00' THEN LEFT(a.Der_Provider_Code,3) ELSE a.Der_Provider_Code END) = ps.Prov_original COLLATE database_default
	LEFT JOIN [Reporting].[Ref_ODS_Provider_Hierarchies_ICB] ph ON COALESCE(ps.Prov_Successor, (CASE WHEN a.Der_Provider_Code LIKE '%00' THEN LEFT(a.Der_Provider_Code,3) ELSE a.Der_Provider_Code END)) = ph.Organisation_Code COLLATE database_default
		AND ph.Effective_To IS NULL
	--Lots of Commissioner and Provider codes in APCE/APCS are 5 character codes ending in 00 which will not match to a code so these are truncated to the 3 character code that will match with the reference tables
	--For Providers, 5 character codes are used for sites and 3 chracter codes are used for trusts. 5 character codes ending in 00 mean a generic site within a trust so the trust code needs to be used for it to match to the reference tables

WHERE (a.[Admission_Date] BETWEEN @Period_Start AND @Period_End OR a.[Discharge_Date] BETWEEN @Period_Start AND @Period_End) 
	AND a.Episode_Number = 1 
	AND (a.Admission_Method LIKE '2%')	--Filters for emergency admissions only
	AND a.[Patient_Classification] IN ('1','2','5')	-- Filters for: 1 = Ordinary admission, 2 = Day case admission, 5 = Mothers and babies using only delivery facilities  


----------------------------------------------APCS Base Table-----------------------------------------------------------------------------------------------------
--Creates a base table (this a record level table that can be aggregated later) of APCS data for the 12 month period defined by @Period_Start and @Period_End above.
IF OBJECT_ID ('[MHDInternal].[TEMP_DEM_SUS_APCS_Base]') IS NOT NULL DROP TABLE [MHDInternal].[TEMP_DEM_SUS_APCS_Base]
SELECT
	b.APCS_Ident
	,DATEADD(MONTH, DATEDIFF(MONTH, 0, b.Admission_Date), 0) AS Admission_Month
	,b.Age_At_Start_of_Spell_SUS	--For emergency admissions over 65 group defined later
	--For Length of Stay groupings
	,CASE WHEN [Der_Spell_LoS] <= 1 THEN '1 Day or less'
		WHEN [Der_Spell_LoS] BETWEEN 2 and 3 THEN 'Between 2 and 3 Days'
		WHEN [Der_Spell_LoS] BETWEEN 4 AND 10 THEN 'Between 4 and 10 Days'
		WHEN [Der_Spell_LoS] BETWEEN 11 AND 21 THEN 'Between 11 and 21 Days'
		WHEN [Der_Spell_LoS] > 21 THEN 'More than 21 Days'
	END AS LengthOfStay
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
		b.Der_Diagnosis_All LIKE '%F051%' THEN 1 ELSE 0 
	END as Dementia
	,CASE WHEN b.Der_Diagnosis_All LIKE '%F067%' THEN 1 ELSE 0 
	END as MCI
	,CASE WHEN (b.Der_Diagnosis_All LIKE '%F050%' OR b.Der_Diagnosis_All LIKE '%F058%' OR b.Der_Diagnosis_All LIKE '%F059%') THEN 1 ELSE 0 
	END as Delirium

	,CASE WHEN ph.[Organisation_Code] IS NOT NULL THEN ph.[Organisation_Code] ELSE 'Other' END AS 'Provider_Code'
	,CASE WHEN ph.[Organisation_Name] IS NOT NULL THEN ph.[Organisation_Name] ELSE 'Other' END AS 'Provider Name'
	,CASE WHEN ph.[Region_Name] IS NOT NULL THEN ph.[Region_Name] ELSE 'Other' END AS 'Region_Name_Provider'
	,CASE WHEN ch.[Organisation_Code] IS NOT NULL THEN ch.[Organisation_Code] ELSE 'Other' END AS 'Sub ICB Code'
	,CASE WHEN ch.[Organisation_Name] IS NOT NULL THEN ch.[Organisation_Name] ELSE 'Other' END AS 'Sub ICB Name'
	,CASE WHEN ch.[STP_Code] IS NOT NULL THEN ch.[STP_Code] ELSE 'Other' END AS 'ICB Code'
	,CASE WHEN ch.[STP_Name] IS NOT NULL THEN ch.[STP_Name] ELSE 'Other' END AS 'ICB Name'
	,CASE WHEN ch.[Region_Name] IS NOT NULL THEN ch.[Region_Name] ELSE 'Other' END AS'Region_Name_Commissioner'
	,CASE WHEN ch.[Region_Code] IS NOT NULL THEN ch.[Region_Code] ELSE 'Other' END AS 'Region_Code_Commissioner'

INTO [MHDInternal].[TEMP_DEM_SUS_APCS_Base]
FROM [SUS_APC].[APCS_Core] b
	--Four tables joined to get Provider, Sub-ICB, ICB and Region codes and names
	LEFT JOIN [Internal_Reference].[ComCodeChanges] cc ON (CASE WHEN b.Commissioner_Code LIKE '%00' THEN LEFT(b.Commissioner_Code,3) ELSE b.Commissioner_Code END)= cc.Org_Code COLLATE database_default
	LEFT JOIN [Reporting].[Ref_ODS_Commissioner_Hierarchies_ICB] ch ON COALESCE(cc.New_Code, (CASE WHEN b.Commissioner_Code LIKE '%00' THEN LEFT(b.Commissioner_Code,3) ELSE b.Commissioner_Code END)) = ch.Organisation_Code COLLATE database_default 
		AND ch.Effective_To IS NULL
	LEFT JOIN [Internal_Reference].[Provider_Successor] ps ON (CASE WHEN b.Der_Provider_Code LIKE '%00' THEN LEFT(b.Der_Provider_Code,3) ELSE b.Der_Provider_Code END) = ps.Prov_original COLLATE database_default
	LEFT JOIN [Reporting].[Ref_ODS_Provider_Hierarchies_ICB] ph ON COALESCE(ps.Prov_Successor, (CASE WHEN b.Der_Provider_Code LIKE '%00' THEN LEFT(b.Der_Provider_Code,3) ELSE b.Der_Provider_Code END)) = ph.Organisation_Code COLLATE database_default
		AND ph.Effective_To IS NULL
	--Lots of Commissioner and Provider codes in APCE/APCS are 5 character codes ending in 00 which will not match to a code so these are truncated to the 3 character code that will match with the reference tables
	--For Providers, 5 character codes are used for sites and 3 chracter codes are used for trusts. 5 character codes ending in 00 mean a generic site within a trust so the trust code needs to be used for it to match to the reference tables

WHERE ([Admission_Date] between @Period_Start and @Period_End) 
	AND (Admission_Method LIKE '2%')	--Filters for emergency admissions only
	AND [Patient_Classification] IN ('1','2','5')	-- Filters for: 1 = Ordinary admission, 2 = Day case admission, 5 = Mothers and babies using only delivery facilities  

---------------------------------Unsuppressed Aggregated Table------------------------------------------------
--This table aggregates the base APCE and base APCS tables at Provider/Sub-ICB/ICB/National levels for the categories Gender, Ethnicity, Admission Source, Discharge Destination, Length of Stay,
--Primary Diagnosis and Total.

---------------------------------National, Gender-----------------------------------------------------------------------------------------------------------------
IF OBJECT_ID ('[MHDInternal].[TEMP_DEM_SUS_Admissions_Unsuppressed]') IS NOT NULL DROP TABLE [MHDInternal].[TEMP_DEM_SUS_Admissions_Unsuppressed]
--INSERT INTO [MHDInternal].[TEMP_DEM_SUS_Admissions_Unsuppressed]
SELECT 
	Admission_Month AS [Month]
	,'National' AS GroupType
	,CAST('All Regions' AS VARCHAR(MAX)) AS RegionCode
	,CAST('England' AS VARCHAR(MAX)) AS GeographyName
	,CAST('Gender' AS VARCHAR(MAX)) AS Category
	,CAST(Gender AS VARCHAR(MAX)) AS Variable
	,COUNT(*) AS Num_Emergency_Admissions
	,SUM(CASE WHEN Age_on_Admission >= 65 THEN 1 ELSE 0 END) AS Num_Emergency_Admissions_65andOver
	,SUM(Dementia) AS Num_Emergency_Admissions_Dementia
	,SUM(Delirium) AS Num_Emergency_Admissions_Delirium
	,SUM(MCI) AS Num_Emergency_Admissions_MCI
	,CAST(NULL AS VARCHAR(MAX)) AS [Primary Diagnosis Chapter]
INTO [MHDInternal].[TEMP_DEM_SUS_Admissions_Unsuppressed]
FROM [MHDInternal].[TEMP_DEM_SUS_APCE_Base] a
WHERE Der_Admission=1
GROUP BY 
Admission_Month
,Gender
---------------------------------National, Ethnicity-----------------------------------------------------------------------------------------------------------
INSERT INTO [MHDInternal].[TEMP_DEM_SUS_Admissions_Unsuppressed]
SELECT 
	Admission_Month AS [Month]
	,'National' AS GroupType
	,'All Regions' AS RegionCode
	,'England'AS GeographyName
	,'Ethnicity'AS Category
	,Ethnicity AS Variable
	,COUNT(*) AS Num_Emergency_Admissions
	,SUM(CASE WHEN Age_on_Admission >= 65 THEN 1 ELSE 0 END) AS Num_Emergency_Admissions_65andOver
	,SUM(Dementia) AS Num_Emergency_Admissions_Dementia
	,SUM(Delirium) AS Num_Emergency_Admissions_Delirium
	,SUM(MCI) AS Num_Emergency_Admissions_MCI
	,NULL AS [Primary Diagnosis Chapter]
FROM [MHDInternal].[TEMP_DEM_SUS_APCE_Base] a
WHERE Der_Admission=1
GROUP BY 
Admission_Month
,Ethnicity
---------------------------------National, Admission Source-------------------------------------------------------------------------------------------------
INSERT INTO [MHDInternal].[TEMP_DEM_SUS_Admissions_Unsuppressed]
SELECT 
	Admission_Month AS [Month]
	,'National' AS GroupType
	,'All Regions' AS RegionCode
	,'England'AS GeographyName
	,'Admission Source'AS Category
	,Admission_Source AS Variable
	,COUNT(*) AS Num_Emergency_Admissions
	,SUM(CASE WHEN Age_on_Admission >= 65 THEN 1 ELSE 0 END) AS Num_Emergency_Admissions_65andOver
	,SUM(Dementia) AS Num_Emergency_Admissions_Dementia
	,SUM(Delirium) AS Num_Emergency_Admissions_Delirium
	,SUM(MCI) AS Num_Emergency_Admissions_MCI
	,NULL AS [Primary Diagnosis Chapter]
FROM [MHDInternal].[TEMP_DEM_SUS_APCE_Base] a
WHERE Der_Admission=1
GROUP BY 
Admission_Month
,Admission_Source
---------------------------------National, Discharge Destination--------------------------------------------------------------------------------
INSERT INTO [MHDInternal].[TEMP_DEM_SUS_Admissions_Unsuppressed]
SELECT 
	Discharge_Month AS [Month]
	,'National' AS GroupType
	,'All Regions' AS RegionCode
	,'England'AS GeographyName
	,'Discharge Destination'AS Category
	,Discharge_Destination AS Variable
	,COUNT(*) AS Num_Emergency_Admissions
	,SUM(CASE WHEN Age_on_Admission >= 65 THEN 1 ELSE 0 END) AS Num_Emergency_Admissions_65andOver
	,SUM(Dementia) AS Num_Emergency_Admissions_Dementia
	,SUM(Delirium) AS Num_Emergency_Admissions_Delirium
	,SUM(MCI) AS Num_Emergency_Admissions_MCI
	,NULL AS [Primary Diagnosis Chapter]
FROM [MHDInternal].[TEMP_DEM_SUS_APCE_Base] a
WHERE Der_Discharge=1
GROUP BY 
Discharge_Month
,Discharge_Destination
-------------------------------National, Length of Stay---------------------------------------------------------------------------------------
INSERT INTO [MHDInternal].[TEMP_DEM_SUS_Admissions_Unsuppressed]
SELECT 
	Admission_Month AS [Month]
	,'National' AS GroupType
	,'All Regions' AS RegionCode
	,'England'AS GeographyName
	,'Length of Stay'AS Category
	,LengthOfStay AS Variable
	,COUNT(*) AS Num_Emergency_Admissions
	,SUM(CASE WHEN Age_At_Start_of_Spell_SUS >= 65 THEN 1 ELSE 0 END) AS Num_Emergency_Admissions_65andOver
	,SUM(Dementia) AS Num_Emergency_Admissions_Dementia
	,SUM(Delirium) AS Num_Emergency_Admissions_Delirium
	,SUM(MCI) AS Num_Emergency_Admissions_MCI
	,NULL AS [Primary Diagnosis Chapter]
FROM [MHDInternal].[TEMP_DEM_SUS_APCS_Base] a
GROUP BY 
Admission_Month
,LengthOfStay

-------------------------------National, Total---------------------------------------------------------------------------------------------------
INSERT INTO [MHDInternal].[TEMP_DEM_SUS_Admissions_Unsuppressed]
SELECT 
	Admission_Month AS [Month]
	,'National' AS GroupType
	,'All Regions' AS RegionCode
	,'England' AS GeographyName
	,'Total'AS Category
	,'Total' AS Variable
	,COUNT(*) AS Num_Emergency_Admissions
	,SUM(CASE WHEN Age_on_Admission >= 65 THEN 1 ELSE 0 END) AS Num_Emergency_Admissions_65andOver
	,SUM(Dementia) AS Num_Emergency_Admissions_Dementia
	,SUM(Delirium) AS Num_Emergency_Admissions_Delirium
	,SUM(MCI) AS Num_Emergency_Admissions_MCI
	,NULL AS [Primary Diagnosis Chapter]
FROM [MHDInternal].[TEMP_DEM_SUS_APCE_Base] a
WHERE Der_Admission=1
GROUP BY 
Admission_Month
-------------------------------National, Primary Diagnosis------------------------------------------------------------------------------
INSERT INTO [MHDInternal].[TEMP_DEM_SUS_Admissions_Unsuppressed]
SELECT 
	Admission_Month AS [Month]
	,'National' AS GroupType
	,'All Regions' AS RegionCode
	,'England'AS GeographyName
	,'Primary Diagnosis'AS Category
	,[Primary Diagnosis] AS Variable
	,COUNT(*) AS Num_Emergency_Admissions
	,SUM(CASE WHEN Age_on_Admission >= 65 THEN 1 ELSE 0 END) AS Num_Emergency_Admissions_65andOver
	,SUM(Dementia) AS Num_Emergency_Admissions_Dementia
	,SUM(Delirium) AS Num_Emergency_Admissions_Delirium
	,SUM(MCI) AS Num_Emergency_Admissions_MCI
	,[Primary Diagnosis Chapter]
FROM [MHDInternal].[TEMP_DEM_SUS_APCE_Base] a
WHERE Der_Admission=1
GROUP BY 
Admission_Month
,[Primary Diagnosis]
,[Primary Diagnosis Chapter]
---------------------------------ICB, Gender------------------------------------------------------------------------------------------------------
INSERT INTO [MHDInternal].[TEMP_DEM_SUS_Admissions_Unsuppressed]
SELECT 
	Admission_Month AS [Month]
	,'ICB' AS GroupType
	,Region_Name_Commissioner AS RegionCode
	,[ICB Name] AS GeographyName
	,'Gender' AS Category
	,Gender AS Variable
	,COUNT(*) AS Num_Emergency_Admissions
	,SUM(CASE WHEN Age_on_Admission >= 65 THEN 1 ELSE 0 END) AS Num_Emergency_Admissions_65andOver
	,SUM(Dementia) AS Num_Emergency_Admissions_Dementia
	,SUM(Delirium) AS Num_Emergency_Admissions_Delirium
	,SUM(MCI) AS Num_Emergency_Admissions_MCI
	,NULL AS [Primary Diagnosis Chapter]
FROM [MHDInternal].[TEMP_DEM_SUS_APCE_Base] a
WHERE Der_Admission=1
GROUP BY 
Admission_Month
,Region_Name_Commissioner
,[ICB Name]
,Gender
---------------------------------ICB, Ethnicity---------------------------------------------------------------------------
INSERT INTO [MHDInternal].[TEMP_DEM_SUS_Admissions_Unsuppressed]
SELECT 
	Admission_Month AS [Month]
	,'ICB' AS GroupType
	,Region_Name_Commissioner AS RegionCode
	,[ICB Name] AS GeographyName
	,'Ethnicity' AS Category
	,Ethnicity AS Variable
	,COUNT(*) AS Num_Emergency_Admissions
	,SUM(CASE WHEN Age_on_Admission >= 65 THEN 1 ELSE 0 END) AS Num_Emergency_Admissions_65andOver
	,SUM(Dementia) AS Num_Emergency_Admissions_Dementia
	,SUM(Delirium) AS Num_Emergency_Admissions_Delirium
	,SUM(MCI) AS Num_Emergency_Admissions_MCI
	,NULL AS [Primary Diagnosis Chapter]
FROM [MHDInternal].[TEMP_DEM_SUS_APCE_Base] a
WHERE Der_Admission=1
GROUP BY 
Admission_Month
,Region_Name_Commissioner
,[ICB Name]
,Ethnicity
---------------------------------ICB, Admission Source------------------------------------------------------------------------------------------
INSERT INTO [MHDInternal].[TEMP_DEM_SUS_Admissions_Unsuppressed]
SELECT 
	Admission_Month AS [Month]
	,'ICB' AS GroupType
	,Region_Name_Commissioner AS RegionCode
	,[ICB Name] AS GeographyName
	,'Admission Source' AS Category
	,Admission_Source AS Variable
	,COUNT(*) AS Num_Emergency_Admissions
	,SUM(CASE WHEN Age_on_Admission >= 65 THEN 1 ELSE 0 END) AS Num_Emergency_Admissions_65andOver
	,SUM(Dementia) AS Num_Emergency_Admissions_Dementia
	,SUM(Delirium) AS Num_Emergency_Admissions_Delirium
	,SUM(MCI) AS Num_Emergency_Admissions_MCI
	,NULL AS [Primary Diagnosis Chapter]
FROM [MHDInternal].[TEMP_DEM_SUS_APCE_Base] a
WHERE Der_Admission=1
GROUP BY 
Admission_Month
,Region_Name_Commissioner
,[ICB Name]
,Admission_Source
---------------------------------ICB, Discharge Destination------------------------------------------------------------------------
INSERT INTO [MHDInternal].[TEMP_DEM_SUS_Admissions_Unsuppressed]
SELECT 
	Discharge_Month AS [Month]
	,'ICB' AS GroupType
	,Region_Name_Commissioner AS RegionCode
	,[ICB Name] AS GeographyName
	,'Discharge Destination' AS Category
	,Discharge_Destination AS Variable
	,COUNT(*) AS Num_Emergency_Admissions
	,SUM(CASE WHEN Age_on_Admission >= 65 THEN 1 ELSE 0 END) AS Num_Emergency_Admissions_65andOver
	,SUM(Dementia) AS Num_Emergency_Admissions_Dementia
	,SUM(Delirium) AS Num_Emergency_Admissions_Delirium
	,SUM(MCI) AS Num_Emergency_Admissions_MCI
	,NULL AS [Primary Diagnosis Chapter]
FROM [MHDInternal].[TEMP_DEM_SUS_APCE_Base] a
WHERE Der_Discharge=1
GROUP BY 
Discharge_Month
,Region_Name_Commissioner
,[ICB Name]
,Discharge_Destination
-------------------------------ICB, Length of Stay--------------------------------------------------------------------------------------
INSERT INTO [MHDInternal].[TEMP_DEM_SUS_Admissions_Unsuppressed]
SELECT 
	Admission_Month AS [Month]
	,'ICB' AS GroupType
	,Region_Name_Commissioner AS RegionCode
	,[ICB Name] AS GeographyName
	,'Length of Stay' AS Category
	,LengthOfStay AS Variable
	,COUNT(*) AS Num_Emergency_Admissions
	,SUM(CASE WHEN Age_At_Start_of_Spell_SUS >= 65 THEN 1 ELSE 0 END) AS Num_Emergency_Admissions_65andOver
	,SUM(Dementia) AS Num_Emergency_Admissions_Dementia
	,SUM(Delirium) AS Num_Emergency_Admissions_Delirium
	,SUM(MCI) AS Num_Emergency_Admissions_MCI
	,NULL AS [Primary Diagnosis Chapter]
FROM [MHDInternal].[TEMP_DEM_SUS_APCS_Base] a
GROUP BY 
Admission_Month
,Region_Name_Commissioner
,[ICB Name]
,LengthOfStay
---------------------------------ICB, Total-------------------------------------------------------------------------------
INSERT INTO [MHDInternal].[TEMP_DEM_SUS_Admissions_Unsuppressed]
SELECT 
	Admission_Month AS [Month]
	,'ICB' AS GroupType
	,Region_Name_Commissioner AS RegionCode
	,[ICB Name] AS GeographyName
	,'Total' AS Category
	,'Total' AS Variable
	,COUNT(*) AS Num_Emergency_Admissions
	,SUM(CASE WHEN Age_on_Admission >= 65 THEN 1 ELSE 0 END) AS Num_Emergency_Admissions_65andOver
	,SUM(Dementia) AS Num_Emergency_Admissions_Dementia
	,SUM(Delirium) AS Num_Emergency_Admissions_Delirium
	,SUM(MCI) AS Num_Emergency_Admissions_MCI
	,NULL AS [Primary Diagnosis Chapter]
FROM [MHDInternal].[TEMP_DEM_SUS_APCE_Base] a
WHERE Der_Admission=1
GROUP BY 
Admission_Month
,Region_Name_Commissioner
,[ICB Name]
---------------------------------ICB, Primary Diagnosis-------------------------------------------------------------------------------------
INSERT INTO [MHDInternal].[TEMP_DEM_SUS_Admissions_Unsuppressed]
SELECT 
	Admission_Month AS [Month]
	,'ICB' AS GroupType
	,[Region_Name_Commissioner] AS RegionCode
	,[ICB Name] AS GeographyName
	,'Primary Diagnosis' AS Category
	,[Primary Diagnosis] AS Variable
	,COUNT(*) AS Num_Emergency_Admissions
	,SUM(CASE WHEN Age_on_Admission >= 65 THEN 1 ELSE 0 END) AS Num_Emergency_Admissions_65andOver
	,SUM(Dementia) AS Num_Emergency_Admissions_Dementia
	,SUM(Delirium) AS Num_Emergency_Admissions_Delirium
	,SUM(MCI) AS Num_Emergency_Admissions_MCI
	,[Primary Diagnosis Chapter]
FROM [MHDInternal].[TEMP_DEM_SUS_APCE_Base] a
WHERE Der_Admission=1
GROUP BY 
Admission_Month
,Region_Name_Commissioner
,[ICB Name]
,[Primary Diagnosis]
,[Primary Diagnosis Chapter]
---------------------------------Sub-ICB, Gender------------------------------------------------------------------------------------------------------
INSERT INTO [MHDInternal].[TEMP_DEM_SUS_Admissions_Unsuppressed]
SELECT 
	Admission_Month AS [Month]
	,'Sub ICB' AS GroupType
	,Region_Name_Commissioner AS RegionCode
	,[Sub ICB Name] AS GeographyName
	,'Gender' AS Category
	,Gender AS Variable
	,COUNT(*) AS Num_Emergency_Admissions
	,SUM(CASE WHEN Age_on_Admission >= 65 THEN 1 ELSE 0 END) AS Num_Emergency_Admissions_65andOver
	,SUM(Dementia) AS Num_Emergency_Admissions_Dementia
	,SUM(Delirium) AS Num_Emergency_Admissions_Delirium
	,SUM(MCI) AS Num_Emergency_Admissions_MCI
	,NULL AS [Primary Diagnosis Chapter]
FROM [MHDInternal].[TEMP_DEM_SUS_APCE_Base] a
WHERE Der_Admission=1
GROUP BY 
Admission_Month
,Region_Name_Commissioner
,[Sub ICB Name]
,Gender
---------------------------------Sub-ICB, Ethnicity---------------------------------------------------------------------------
INSERT INTO [MHDInternal].[TEMP_DEM_SUS_Admissions_Unsuppressed]
SELECT 
	Admission_Month AS [Month]
	,'Sub ICB' AS GroupType
	,Region_Name_Commissioner AS RegionCode
	,[Sub ICB Name] AS GeographyName
	,'Ethnicity' AS Category
	,Ethnicity AS Variable
	,COUNT(*) AS Num_Emergency_Admissions
	,SUM(CASE WHEN Age_on_Admission >= 65 THEN 1 ELSE 0 END) AS Num_Emergency_Admissions_65andOver
	,SUM(Dementia) AS Num_Emergency_Admissions_Dementia
	,SUM(Delirium) AS Num_Emergency_Admissions_Delirium
	,SUM(MCI) AS Num_Emergency_Admissions_MCI
	,NULL AS [Primary Diagnosis Chapter]
FROM [MHDInternal].[TEMP_DEM_SUS_APCE_Base] a
WHERE Der_Admission=1
GROUP BY 
Admission_Month
,Region_Name_Commissioner
,[Sub ICB Name]
,Ethnicity
---------------------------------Sub-ICB, Admission Source------------------------------------------------------------------------------------------
INSERT INTO [MHDInternal].[TEMP_DEM_SUS_Admissions_Unsuppressed]
SELECT 
	Admission_Month AS [Month]
	,'Sub ICB' AS GroupType
	,Region_Name_Commissioner AS RegionCode
	,[Sub ICB Name] AS GeographyName
	,'Admission Source' AS Category
	,Admission_Source AS Variable
	,COUNT(*) AS Num_Emergency_Admissions
	,SUM(CASE WHEN Age_on_Admission >= 65 THEN 1 ELSE 0 END) AS Num_Emergency_Admissions_65andOver
	,SUM(Dementia) AS Num_Emergency_Admissions_Dementia
	,SUM(Delirium) AS Num_Emergency_Admissions_Delirium
	,SUM(MCI) AS Num_Emergency_Admissions_MCI
	,NULL AS [Primary Diagnosis Chapter]
FROM [MHDInternal].[TEMP_DEM_SUS_APCE_Base] a
WHERE Der_Admission=1
GROUP BY 
Admission_Month
,Region_Name_Commissioner
,[Sub ICB Name]
,Admission_Source
---------------------------------Sub-ICB, Discharge Destination------------------------------------------------------------------------
INSERT INTO [MHDInternal].[TEMP_DEM_SUS_Admissions_Unsuppressed]
SELECT 
	Discharge_Month AS [Month]
	,'Sub ICB' AS GroupType
	,Region_Name_Commissioner AS RegionCode
	,[Sub ICB Name] AS GeographyName
	,'Discharge Destination' AS Category
	,Discharge_Destination AS Variable
	,COUNT(*) AS Num_Emergency_Admissions
	,SUM(CASE WHEN Age_on_Admission >= 65 THEN 1 ELSE 0 END) AS Num_Emergency_Admissions_65andOver
	,SUM(Dementia) AS Num_Emergency_Admissions_Dementia
	,SUM(Delirium) AS Num_Emergency_Admissions_Delirium
	,SUM(MCI) AS Num_Emergency_Admissions_MCI
	,NULL AS [Primary Diagnosis Chapter]
FROM [MHDInternal].[TEMP_DEM_SUS_APCE_Base] a
WHERE Der_Discharge=1
GROUP BY 
Discharge_Month
,Region_Name_Commissioner
,[Sub ICB Name]
,Discharge_Destination
-------------------------------Sub-ICB, Length of Stay--------------------------------------------------------------------------------------
INSERT INTO [MHDInternal].[TEMP_DEM_SUS_Admissions_Unsuppressed]
SELECT 
	Admission_Month AS [Month]
	,'Sub ICB' AS GroupType
	,Region_Name_Commissioner AS RegionCode
	,[Sub ICB Name] AS GeographyName
	,'Length of Stay' AS Category
	,LengthOfStay AS Variable
	,COUNT(*) AS Num_Emergency_Admissions
	,SUM(CASE WHEN Age_At_Start_of_Spell_SUS >= 65 THEN 1 ELSE 0 END) AS Num_Emergency_Admissions_65andOver
	,SUM(Dementia) AS Num_Emergency_Admissions_Dementia
	,SUM(Delirium) AS Num_Emergency_Admissions_Delirium
	,SUM(MCI) AS Num_Emergency_Admissions_MCI
	,NULL AS [Primary Diagnosis Chapter]
FROM [MHDInternal].[TEMP_DEM_SUS_APCS_Base] a
GROUP BY 
Admission_Month
,Region_Name_Commissioner
,[Sub ICB Name]
,LengthOfStay
---------------------------------Sub-ICB, Total-------------------------------------------------------------------------------
INSERT INTO [MHDInternal].[TEMP_DEM_SUS_Admissions_Unsuppressed]
SELECT 
	Admission_Month AS [Month]
	,'Sub ICB' AS GroupType
	,Region_Name_Commissioner AS RegionCode
	,[Sub ICB Name] AS GeographyName
	,'Total' AS Category
	,'Total' AS Variable
	,COUNT(*) AS Num_Emergency_Admissions
	,SUM(CASE WHEN Age_on_Admission >= 65 THEN 1 ELSE 0 END) AS Num_Emergency_Admissions_65andOver
	,SUM(Dementia) AS Num_Emergency_Admissions_Dementia
	,SUM(Delirium) AS Num_Emergency_Admissions_Delirium
	,SUM(MCI) AS Num_Emergency_Admissions_MCI
	,NULL AS [Primary Diagnosis Chapter]
FROM [MHDInternal].[TEMP_DEM_SUS_APCE_Base] a
WHERE Der_Admission=1
GROUP BY 
Admission_Month
,Region_Name_Commissioner
,[Sub ICB Name]
---------------------------------Sub-ICB, Primary Diagnosis -------------------------------------------------------------------------------------
INSERT INTO [MHDInternal].[TEMP_DEM_SUS_Admissions_Unsuppressed]
SELECT 
	Admission_Month AS [Month]
	,'Sub ICB' AS GroupType
	,[Region_Name_Commissioner] AS RegionCode
	,[Sub ICB Name] AS GeographyName
	,'Primary Diagnosis' AS Category
	,[Primary Diagnosis] AS Variable
	,COUNT(*) AS Num_Emergency_Admissions
	,SUM(CASE WHEN Age_on_Admission >= 65 THEN 1 ELSE 0 END) AS Num_Emergency_Admissions_65andOver
	,SUM(Dementia) AS Num_Emergency_Admissions_Dementia
	,SUM(Delirium) AS Num_Emergency_Admissions_Delirium
	,SUM(MCI) AS Num_Emergency_Admissions_MCI
	,[Primary Diagnosis Chapter]
FROM [MHDInternal].[TEMP_DEM_SUS_APCE_Base] a
WHERE Der_Admission=1
GROUP BY 
Admission_Month
,Region_Name_Commissioner
,[Sub ICB Name]
,[Primary Diagnosis]
,[Primary Diagnosis Chapter]
---------------------------------Provider, Gender------------------------------------------------------------------------------------------------------
INSERT INTO [MHDInternal].[TEMP_DEM_SUS_Admissions_Unsuppressed]
SELECT 
	Admission_Month AS [Month]
	,'Provider' AS GroupType
	,[Region_Name_Provider] AS RegionCode
	,[Provider Name] AS GeographyName
	,'Gender'AS Category
	,Gender AS Variable
	,COUNT(*) AS Num_Emergency_Admissions
	,SUM(CASE WHEN Age_on_Admission >= 65 THEN 1 ELSE 0 END) AS Num_Emergency_Admissions_65andOver
	,SUM(Dementia) AS Num_Emergency_Admissions_Dementia
	,SUM(Delirium) AS Num_Emergency_Admissions_Delirium
	,SUM(MCI) AS Num_Emergency_Admissions_MCI
	,NULL AS [Primary Diagnosis Chapter]
FROM [MHDInternal].[TEMP_DEM_SUS_APCE_Base] a
WHERE Der_Admission=1
GROUP BY 
Admission_Month
,Region_Name_Provider
,[Provider Name]
,Gender
---------------------------------Provider, Ethnicity---------------------------------------------------------------------------
INSERT INTO [MHDInternal].[TEMP_DEM_SUS_Admissions_Unsuppressed]
SELECT 
	Admission_Month AS [Month]
	,'Provider' AS GroupType
	,[Region_Name_Provider] AS RegionCode
	,[Provider Name] AS GeographyName
	,'Ethnicity'AS Category
	,Ethnicity AS Variable
	,COUNT(*) AS Num_Emergency_Admissions
	,SUM(CASE WHEN Age_on_Admission >= 65 THEN 1 ELSE 0 END) AS Num_Emergency_Admissions_65andOver
	,SUM(Dementia) AS Num_Emergency_Admissions_Dementia
	,SUM(Delirium) AS Num_Emergency_Admissions_Delirium
	,SUM(MCI) AS Num_Emergency_Admissions_MCI
	,NULL AS [Primary Diagnosis Chapter]
FROM [MHDInternal].[TEMP_DEM_SUS_APCE_Base] a
WHERE Der_Admission=1
GROUP BY 
Admission_Month
,Region_Name_Provider
,[Provider Name]
,Ethnicity
---------------------------------Provider, Admission Source------------------------------------------------------------------------------------------
INSERT INTO [MHDInternal].[TEMP_DEM_SUS_Admissions_Unsuppressed]
SELECT 
	Admission_Month AS [Month]
	,'Provider' AS GroupType
	,[Region_Name_Provider] AS RegionCode
	,[Provider Name] AS GeographyName
	,'Admission Source'AS Category
	,[Admission_Source] AS Variable
	,COUNT(*) AS Num_Emergency_Admissions
	,SUM(CASE WHEN Age_on_Admission >= 65 THEN 1 ELSE 0 END) AS Num_Emergency_Admissions_65andOver
	,SUM(Dementia) AS Num_Emergency_Admissions_Dementia
	,SUM(Delirium) AS Num_Emergency_Admissions_Delirium
	,SUM(MCI) AS Num_Emergency_Admissions_MCI
	,NULL AS [Primary Diagnosis Chapter]
FROM [MHDInternal].[TEMP_DEM_SUS_APCE_Base] a
WHERE Der_Admission=1
GROUP BY 
Admission_Month
,Region_Name_Provider
,[Provider Name]
,Admission_Source
---------------------------------Provider, Discharge Destination------------------------------------------------------------------------
INSERT INTO [MHDInternal].[TEMP_DEM_SUS_Admissions_Unsuppressed]
SELECT 
	Discharge_Month AS [Month]
	,'Provider' AS GroupType
	,Region_Name_Provider AS RegionCode
	,[Provider Name] AS GeographyName
	,'Discharge Destination' AS Category
	,Discharge_Destination AS Variable
	,COUNT(*) AS Num_Emergency_Admissions
	,SUM(CASE WHEN Age_on_Admission >= 65 THEN 1 ELSE 0 END) AS Num_Emergency_Admissions_65andOver
	,SUM(Dementia) AS Num_Emergency_Admissions_Dementia
	,SUM(Delirium) AS Num_Emergency_Admissions_Delirium
	,SUM(MCI) AS Num_Emergency_Admissions_MCI
	,NULL AS [Primary Diagnosis Chapter]
FROM [MHDInternal].[TEMP_DEM_SUS_APCE_Base] a
WHERE Der_Discharge=1
GROUP BY 
Discharge_Month
,Region_Name_Provider
,[Provider Name]
,Discharge_Destination
-------------------------------Provider, Length of Stay--------------------------------------------------------------------------------------
INSERT INTO [MHDInternal].[TEMP_DEM_SUS_Admissions_Unsuppressed]
SELECT 
	Admission_Month AS [Month]
	,'Provider' AS GroupType
	,Region_Name_Provider AS RegionCode
	,[Provider Name] AS GeographyName
	,'Length of Stay'AS Category
	,LengthOfStay AS Variable
	,COUNT(*) AS Num_Emergency_Admissions
	,SUM(CASE WHEN Age_At_Start_of_Spell_SUS >= 65 THEN 1 ELSE 0 END) AS Num_Emergency_Admissions_65andOver
	,SUM(Dementia) AS Num_Emergency_Admissions_Dementia
	,SUM(Delirium) AS Num_Emergency_Admissions_Delirium
	,SUM(MCI) AS Num_Emergency_Admissions_MCI
	,NULL AS [Primary Diagnosis Chapter]
FROM [MHDInternal].[TEMP_DEM_SUS_APCS_Base] a
GROUP BY 
Admission_Month
,Region_Name_Provider
,[Provider Name]
,LengthOfStay
---------------------------------Provider, Total-------------------------------------------------------------------------------
INSERT INTO [MHDInternal].[TEMP_DEM_SUS_Admissions_Unsuppressed]
SELECT 
	Admission_Month AS [Month]
	,'Provider' AS GroupType
	,[Region_Name_Provider] AS RegionCode
	,[Provider Name] AS GeographyName
	,'Total'AS Category
	,'Total' AS Variable
	,COUNT(*) AS Num_Emergency_Admissions
	,SUM(CASE WHEN Age_on_Admission >= 65 THEN 1 ELSE 0 END) AS Num_Emergency_Admissions_65andOver
	,SUM(Dementia) AS Num_Emergency_Admissions_Dementia
	,SUM(Delirium) AS Num_Emergency_Admissions_Delirium
	,SUM(MCI) AS Num_Emergency_Admissions_MCI
	,NULL AS [Primary Diagnosis Chapter]
FROM [MHDInternal].[TEMP_DEM_SUS_APCE_Base] a
WHERE Der_Admission=1
GROUP BY 
Admission_Month
,Region_Name_Provider
,[Provider Name]
---------------------------------Provider, Primary Diagnosis-------------------------------------------------------------------------------------
INSERT INTO [MHDInternal].[TEMP_DEM_SUS_Admissions_Unsuppressed]
SELECT 
	Admission_Month AS [Month]
	,'Provider' AS GroupType
	,[Region_Name_Provider] AS RegionCode
	,[Provider Name] AS GeographyName
	,'Primary Diagnosis'AS Category
	,[Primary Diagnosis] AS Variable
	,COUNT(*) AS Num_Emergency_Admissions
	,SUM(CASE WHEN Age_on_Admission >= 65 THEN 1 ELSE 0 END) AS Num_Emergency_Admissions_65andOver
	,SUM(Dementia) AS Num_Emergency_Admissions_Dementia
	,SUM(Delirium) AS Num_Emergency_Admissions_Delirium
	,SUM(MCI) AS Num_Emergency_Admissions_MCI
	,[Primary Diagnosis Chapter]
FROM [MHDInternal].[TEMP_DEM_SUS_APCE_Base] a
WHERE Der_Admission=1
GROUP BY 
Admission_Month
,Region_Name_Provider
,[Provider Name]
,[Primary Diagnosis]
,[Primary Diagnosis Chapter]


---------------------------------Suppressed, Output Table------------------------------------------------
--This table suppresses metrics that are less than 7 and it is the table used in the dashboard

--IF OBJECT_ID ('[MHDInternal].[DASHBOARD_DEM_SUS_Emergency_Admissions]') IS NOT NULL DROP TABLE [MHDInternal].[DASHBOARD_DEM_SUS_Emergency_Admissions]
INSERT INTO [MHDInternal].[DASHBOARD_DEM_SUS_Emergency_Admissions]
SELECT 
	[Month]
	,GroupType
	,RegionCode
	,GeographyName
	,Category
	,Variable
	,CASE WHEN Num_Emergency_Admissions < 7 THEN '*' ELSE CAST((Num_Emergency_Admissions) AS VARCHAR) END AS 'Emergency Admissions'
	,CASE WHEN Num_Emergency_Admissions_65andOver  < 7 THEN '*' ELSE CAST((Num_Emergency_Admissions_65andOver) AS VARCHAR) END AS 'Emergency Admissions - Aged 65 Years and Over'
	,CASE WHEN Num_Emergency_Admissions_Dementia  < 7 THEN '*' ELSE CAST((Num_Emergency_Admissions_Dementia) AS VARCHAR) END AS 'Emergency Admissions - Dementia Diagnosis' 
	,CASE WHEN Num_Emergency_Admissions_Delirium  < 7 THEN '*' ELSE CAST((Num_Emergency_Admissions_Delirium) AS VARCHAR) END AS 'Emergency Admissions - Delirium Diagnosis'
	,CASE WHEN Num_Emergency_Admissions_MCI  < 7 THEN '*' ELSE CAST((Num_Emergency_Admissions_MCI) AS VARCHAR) END AS 'Emergency Admissions - MCI Diagnosis'
	,[Primary Diagnosis Chapter]
	,GETDATE() AS SnapshotDate
--INTO [MHDInternal].[DASHBOARD_DEM_SUS_Emergency_Admissions]
FROM [MHDInternal].[TEMP_DEM_SUS_Admissions_Unsuppressed]
GO

----------------------------------End of Step 2------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------
------------------------------Step 3---------------------------------------------------------------------
--Execute to drop the temporary tables used in the query, once you are happy the previous steps have run correctly

DROP TABLE [MHDInternal].[TEMP_DEM_SUS_APCE_Base]
DROP TABLE [MHDInternal].[TEMP_DEM_SUS_APCS_Base]
DROP TABLE [MHDInternal].[TEMP_DEM_SUS_Admissions_Unsuppressed]

----------------------------------End of Step 3------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------

----------------------------------End of Script------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------
