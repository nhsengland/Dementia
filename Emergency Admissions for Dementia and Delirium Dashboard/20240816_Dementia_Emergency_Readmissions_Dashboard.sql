
/* - Emergency Admissions for Dementia and Delirium Dashboard -------------------------------------------------
   - Emergency Readmissions script ------------------------------------------------------------------------- */
 
-- Step 1 -----------------------------------------------------------------------------------------------------------------------------------

/* 

-- Current values covering the last 11 months are deleted from the dashboard table and added to an old refresh table to keep as a record. 
-- The old refresh data will be removed after one year (i.e. once it is no longer refreshed).

-- @delete_period_start is the beginning of the month 11 months prior to the latest month in the dashboard extract (to include the last 12 months in the refresh)
-- @delete_period_end is the end of the latest month in last month's dashboard extract 

*/

--------------------------------------------------------------------------------------------------------------------------------------------------------
DECLARE @delete_period_end DATE = (SELECT EOMONTH(MAX([Month])) FROM [MHDInternal].[DASHBOARD_DEM_SUS_Emergency_Readmissions])
DECLARE @delete_period_start DATE = (SELECT DATEADD(DAY,1, EOMONTH(DATEADD(MONTH,-11,@delete_period_end))))

PRINT CHAR(13) + 'Delete values between ' + CAST(@delete_period_start AS VARCHAR(10)) + ' and ' + CAST(@delete_period_end AS VARCHAR(10)) 
--------------------------------------------------------------------------------------------------------------------------------------------------------

DELETE [MHDInternal].[DASHBOARD_DEM_SUS_Emergency_Readmissions]

OUTPUT 
	
	DELETED.[Month]
    ,DELETED.[Org_Type]
    ,DELETED.[Organisation_Name]
    ,DELETED.[Region Name]
    ,DELETED.[Readmissions30days]
    ,DELETED.[Readmissions60days]
    ,DELETED.[Readmissions90days]
    ,DELETED.[AdmissionGroup]
	,DELETED.[SnapshotDate]

INTO [MHDInternal].[STAGING_DEM_SUS_Emergency_Readmissions_Old_Refresh]

	([Month]
     ,[Org_Type]
     ,[Organisation_Name]
     ,[Region Name]
     ,[Readmissions30days]
     ,[Readmissions60days]
     ,[Readmissions90days]
     ,[AdmissionGroup]
	,[SnapshotDate])

WHERE [Month] BETWEEN @delete_period_start AND @delete_period_end
GO

-- End of Step 1 -------------------------------------------------------------------------------------------------------------

-- Step 2---------------------------------------------------------------------------------------------------------------------

-- Creates a table for the unsuppressed readmissions table needed later

IF OBJECT_ID ('[MHDInternal].[TEMP_DEM_SUS_Readmissions_Unsuppressed]') IS NOT NULL DROP TABLE [MHDInternal].[TEMP_DEM_SUS_Readmissions_Unsuppressed]

CREATE TABLE [MHDInternal].[TEMP_DEM_SUS_Readmissions_Unsuppressed] 

	([Month] DATE
	,[Org_Type] varchar(max)
	,[Organisation_Name] varchar(max)
	,[Region Name] varchar(max)
	,[Readmissions30days] int
	,[Readmissions60days] int
	,[Readmissions90days] int
	,AdmissionGroup varchar(max))

SET NOCOUNT ON
SET ANSI_WARNINGS OFF

-- Defines the Offset and Max_Offset used in the loop below so that each month in the last 12 months is cycled through the loop.

DECLARE @Offset INT = +12 -- @Offset should always be +12 to get the most recent month available
DECLARE @Max_Offset INT = +1 -- @Max_Offset should always be  +1 to refresh 12 months worth of data

------------------------------------------------------------------------------------------------------------------------------------------------
---- Start loop --------------------------------------------------------------------------------------------------------------------------------

WHILE (@Offset >= @Max_Offset) BEGIN

-- Latest Admission Time Frame
-- This defines the time period for readmissions i.e. an admission following a discharge in the previous discharge time frame, defined below.
 
DECLARE @admissions_period_end DATE = (SELECT DATEADD(MONTH,@Offset,EOMONTH(MAX([Month]))) FROM [MHDInternal].[DASHBOARD_DEM_SUS_Emergency_Readmissions])
DECLARE @admissions_period_start DATE = (SELECT DATEADD(DAY,1,EOMONTH(DATEADD(MONTH,-1,@admissions_period_end))))

-- Previous Discharge Time Frame (90 days prior to the latest admission time frame)
-- This defines the time period for discharges that may result in a readmission in the latest admission time frame, defined above.

DECLARE @discharges_period_start DATE = (SELECT DATEADD(DAY,-90,@admissions_period_start))
DECLARE @discharges_period_end DATE = (SELECT DATEADD(DAY,-1,@admissions_period_start))

PRINT CHAR(13)
PRINT 'Admission Time Frame: ' + CAST(@admissions_period_start AS VARCHAR) + ' - ' + CAST(@admissions_period_end AS VARCHAR)
PRINT 'Discharge Time Frame: ' + CAST(@discharges_period_start AS VARCHAR) + ' - ' + CAST(@discharges_period_end AS VARCHAR)

-------------------Previous Discharge Table----------------------------------

-- Record level table for discharges in the previous discharge time frame

IF OBJECT_ID ('[MHDInternal].[TEMP_DEM_SUS_Previous_Discharge]') IS NOT NULL DROP TABLE [MHDInternal].[TEMP_DEM_SUS_Previous_Discharge]

SELECT 
	[Der_Pseudo_NHS_Number]
	,CAST([Admission_Date] AS DATE) AS [Admission_Date] 
	,CAST([Discharge_Date] AS DATE) AS [Discharge_Date]
	,[Provider_Code]
	,[Commissioner_Code]
	,ROW_NUMBER() OVER(PARTITION BY [Der_Pseudo_NHS_Number] ORDER BY [Discharge_Date], Extract_Date_Time, Der_Diagnosis_Count DESC) AS DischargeOrder	--Orders discharge dates so the latest discharge date has a value of 1
	-- Dementia/MCI ICD10 codes from Page 13 of Dementia Care Pathway Appendices
	,CASE 
		WHEN Der_Diagnosis_All LIKE '%F000%' OR 
			 Der_Diagnosis_All LIKE '%F001%' OR 
			 Der_Diagnosis_All LIKE '%F002%' OR 
			 Der_Diagnosis_All LIKE '%F009%' OR 
			 Der_Diagnosis_All LIKE '%F010%' OR 
			 Der_Diagnosis_All LIKE '%F011%' OR 
			 Der_Diagnosis_All LIKE '%F012%' OR 
			 Der_Diagnosis_All LIKE '%F013%' OR 
			 Der_Diagnosis_All LIKE '%F018%' OR 
			 Der_Diagnosis_All LIKE '%F019%' OR 
			 Der_Diagnosis_All LIKE '%F020%' OR 
			 Der_Diagnosis_All LIKE '%F021%' OR 
			 Der_Diagnosis_All LIKE '%F022%' OR 
			 Der_Diagnosis_All LIKE '%F023%' OR 
			 Der_Diagnosis_All LIKE '%F024%' OR 
			 Der_Diagnosis_All LIKE '%F028%' OR
			(Der_Diagnosis_All LIKE '%F028%' AND Der_Diagnosis_All LIKE '%G318%') OR
			 Der_Diagnosis_All LIKE '%F03%' OR
			 Der_Diagnosis_All LIKE '%F051%' THEN 1 ELSE 0 END 
		AS [Dementia]
	,CASE WHEN [Der_Diagnosis_All] LIKE '%F067%' THEN 1 ELSE 0 END AS [MCI]
	,CASE WHEN [Der_Diagnosis_All] LIKE '%F050%' OR [Der_Diagnosis_All] LIKE '%F058%' OR [Der_Diagnosis_All] LIKE '%F059%' THEN 1 ELSE 0 END AS [Delirium]
	,CASE WHEN [Age_At_Start_of_Spell_SUS] >= 65 THEN 1 ELSE 0 END AS [Age65]

INTO [MHDInternal].[TEMP_DEM_SUS_Previous_Discharge]

FROM [Reporting_MESH_APC].[APCS_Core_Daily_Snapshot] a

WHERE 
	Admission_Method LIKE '2%'	-- emergency admissions only
	AND CAST(Discharge_Date AS DATE) BETWEEN @discharges_period_start AND @discharges_period_end -- discharges in the previous admission time frame
	AND [Der_Pseudo_NHS_Number] IS NOT NULL
	AND [Patient_Classification] = 1 -- = ordinary admission

------------------------------Latest Admission Table-------------------------------------

-- Record level table for admissions in the latest admission time frame but only for those records which have a discharge in the previous time frame table above

IF OBJECT_ID ('[MHDInternal].[TEMP_DEM_SUS_Latest_Admission]') IS NOT NULL DROP TABLE [MHDInternal].[TEMP_DEM_SUS_Latest_Admission]

SELECT 
	
	a.[Der_Pseudo_NHS_Number]
	,CAST(a.[Admission_Date] AS DATE) AS [Admission_Date]
	,CAST(a.[Discharge_Date] AS DATE) AS [Discharge_Date] 
	,CASE WHEN ph.[Organisation_Code] IS NOT NULL THEN ph.[Organisation_Code] ELSE 'Other' END AS [Provider_Code]
	,CASE WHEN ph.[Organisation_Name] IS NOT NULL THEN ph.[Organisation_Name] ELSE 'Other' END AS [Provider Name]
	,CASE WHEN ph.[Region_Name] IS NOT NULL THEN ph.[Region_Name] ELSE 'Other' END AS [Provider Region Name]
	,CASE WHEN ch.[Organisation_Code] IS NOT NULL THEN ch.[Organisation_Code] ELSE 'Other' END AS [Sub ICB Code]
	,CASE WHEN ch.[Organisation_Name] IS NOT NULL THEN ch.[Organisation_Name] ELSE 'Other' END AS [Sub ICB Name]
	,CASE WHEN ch.[STP_Code] IS NOT NULL THEN ch.[STP_Code] ELSE 'Other' END AS [ICB Code]
	,CASE WHEN ch.[STP_Name] IS NOT NULL THEN ch.[STP_Name] ELSE 'Other' END AS [ICB Name]
	,CASE WHEN ch.[Region_Name] IS NOT NULL THEN ch.[Region_Name] ELSE 'Other' END AS [Commissioner Region Name]
	,CASE WHEN ch.[Region_Code] IS NOT NULL THEN ch.[Region_Code] ELSE 'Other' END AS [Region_Code_Commissioner]
	,ROW_NUMBER() OVER(PARTITION BY a.[Der_Pseudo_NHS_Number] ORDER BY a.[Admission_Date] ASC) AS [AdmissionOrder]	--Orders admission dates so the earliest admission date has a value of 1
	,a.[Commissioner_Code]

INTO [MHDInternal].[TEMP_DEM_SUS_Latest_Admission]

FROM 
	[Reporting_MESH_APC].[APCS_Core_Daily_Snapshot] a
	--Inner join to the previous admission table means only records with a discharge in the previous admission table will be included in this table
	INNER JOIN [MHDInternal].[TEMP_DEM_SUS_Previous_Discharge] b ON a.[Der_Pseudo_NHS_Number] = b.[Der_Pseudo_NHS_Number]
	--------------------------------------------------------------
	LEFT JOIN [Internal_Reference].[ComCodeChanges] cc ON (CASE WHEN a.Commissioner_Code LIKE '%00' THEN LEFT(a.Commissioner_Code,3) ELSE a.Commissioner_Code END)= cc.Org_Code COLLATE database_default
	LEFT JOIN [Reporting].[Ref_ODS_Commissioner_Hierarchies_ICB] ch ON COALESCE(cc.New_Code, (CASE WHEN a.Commissioner_Code LIKE '%00' THEN LEFT(a.Commissioner_Code,3) ELSE a.Commissioner_Code END)) = ch.Organisation_Code COLLATE database_default  AND ch.Effective_To IS NULL
	--------------------------------------------------------------
	LEFT JOIN [Internal_Reference].[Provider_Successor] ps ON (CASE WHEN a.Der_Provider_Code LIKE '%00' THEN LEFT(a.Der_Provider_Code,3) ELSE a.Der_Provider_Code END) = ps.Prov_original COLLATE database_default
	LEFT JOIN [Reporting].[Ref_ODS_Provider_Hierarchies_ICB] ph ON COALESCE(ps.Prov_Successor, (CASE WHEN a.Der_Provider_Code LIKE '%00' THEN LEFT(a.Der_Provider_Code,3) ELSE a.Der_Provider_Code END)) = ph.Organisation_Code COLLATE database_default AND ph.Effective_To IS NULL
	--Lots of Commissioner and Provider codes in APCE/APCS are 5 character codes ending in 00 which will not match to a code so these are truncated to the 3 character code that will match with the reference tables
	--For Providers, 5 character codes are used for sites and 3 chracter codes are used for trusts. 5 character codes ending in 00 mean a generic site within a trust so the trust code needs to be used for it to match to the reference tables

WHERE 
	(a.[Admission_Method] LIKE '2%') -- emergency admissions only
	AND CAST(a.[Admission_Date] AS DATE) BETWEEN @admissions_period_start AND @admissions_period_end -- discharges in the latest admission time frame
	AND (a.[Patient_Classification] = 1) -- = ordinary admission

-- Readmissions Base Table -----------------------------------------------------------------------------------------------------------------

-- Base table (record level values that can be aggregated later) which combines the previous admission and latest admission table. 

IF OBJECT_ID ('[MHDInternal].[TEMP_DEM_SUS_Readmission_Base]') IS NOT NULL DROP TABLE [MHDInternal].[TEMP_DEM_SUS_Readmission_Base]

SELECT 

	CAST(DATENAME(m, @admissions_period_start) + ' ' + CAST(DATEPART(yyyy, @admissions_period_start) AS varchar) AS DATE) AS [Month]
	,a.[Der_Pseudo_NHS_Number]
	,a.[Admission_Date] AS [PreviousAdmission_Date]
	,a.[Discharge_Date] AS [PreviousDischarge_Date]
	,b.[Admission_Date] AS [LatestAdmission_Date]
	,b.[Discharge_Date] AS [LatestDischarge_Date]
	,a.[Dementia]
	,a.[MCI]
	,a.[Delirium]
	,a.[Age65]
	,b.[Commissioner Region Name]
	,b.[Provider Region Name]
	,b.[Sub ICB Name]
	,b.[Provider Name]
	,b.[ICB Name]
	,DATEDIFF(DD, a.[Discharge_Date], b.[Admission_Date]) AS [TimeBetweenAdmissions]

INTO [MHDInternal].[TEMP_DEM_SUS_Readmission_Base]

FROM 
	[MHDInternal].[TEMP_DEM_SUS_Previous_Discharge] a
	--------------------------------------------------
	INNER JOIN [MHDInternal].[TEMP_DEM_SUS_Latest_Admission] b ON a.[Der_Pseudo_NHS_Number] = b.[Der_Pseudo_NHS_Number] 

WHERE 
	a.DischargeOrder = 1 -- Only includes the latest discharge date 
	AND b.AdmissionOrder = 1 -- Only includes the earliest admission date

-- Unsuppressed Readmissions Table-------------------------------------------------------------------------------------------------

/* This table aggregates the Readmissions base table at Provider/Sub-ICB/ICB/National levels for the emergency readmission types of Dementia, Age 65+, Delirium, MCI and All */

--------Provider, Dementia-------------

INSERT INTO [MHDInternal].[TEMP_DEM_SUS_Readmissions_Unsuppressed] 

SELECT

	[Month]
	,'Provider' AS [Org_Type]
	,[Provider Name] AS [Organisation_Name]
	,[Provider Region Name] AS [Region Name]
	,SUM (CASE WHEN [TimeBetweenAdmissions] <= 30 THEN Dementia END) AS [Readmissions30days]
	,SUM (CASE WHEN [TimeBetweenAdmissions] BETWEEN 31 AND 60 THEN Dementia END) AS [Readmissions60days]
	,SUM (CASE WHEN [TimeBetweenAdmissions] BETWEEN 61 AND 90 THEN Dementia END) AS [Readmissions90days]
	,'Emergency Admissions - Dementia Diagnosis' AS AdmissionGroup

FROM [MHDInternal].[TEMP_DEM_SUS_Readmission_Base]

GROUP BY [Provider Region Name],[Provider Name], [Month]

--------Sub ICB, Dementia-------------

INSERT INTO [MHDInternal].[TEMP_DEM_SUS_Readmissions_Unsuppressed] 

SELECT

	[Month]
	,'Sub ICB' AS [Org_Type]
	,[Sub ICB Name]AS [Organisation_Name]
	,[Commissioner Region Name] AS [Region Name]
	,SUM(CASE WHEN [TimeBetweenAdmissions] <= 30 THEN Dementia END) AS [Readmissions30days]
	,SUM(CASE WHEN [TimeBetweenAdmissions] BETWEEN 31 AND 60 THEN Dementia END) AS [Readmissions60days]
	,SUM(CASE WHEN [TimeBetweenAdmissions] BETWEEN 61 AND 90 THEN Dementia END) AS [Readmissions90days]
	,'Emergency Admissions - Dementia Diagnosis' AS AdmissionGroup

FROM [MHDInternal].[TEMP_DEM_SUS_Readmission_Base]

GROUP BY [Commissioner Region Name],[Sub ICB Name], [Month]

--------ICB, Dementia-------------

INSERT INTO [MHDInternal].[TEMP_DEM_SUS_Readmissions_Unsuppressed] 

SELECT

	[Month]
	,'ICB' AS [Org_Type]
	,[ICB Name]AS [Organisation_Name]
	,[Commissioner Region Name] AS [Region Name]
	,SUM(CASE WHEN [TimeBetweenAdmissions] <= 30 THEN Dementia END) AS [Readmissions30days]
	,SUM(CASE WHEN [TimeBetweenAdmissions] BETWEEN 31 AND 60 THEN Dementia END) AS [Readmissions60days]
	,SUM(CASE WHEN [TimeBetweenAdmissions] BETWEEN 61 AND 90 THEN Dementia END) AS [Readmissions90days]
	,'Emergency Admissions - Dementia Diagnosis' AS AdmissionGroup

FROM [MHDInternal].[TEMP_DEM_SUS_Readmission_Base]

GROUP BY [Commissioner Region Name],[ICB Name], [Month]

--------National, Dementia-------------

INSERT INTO [MHDInternal].[TEMP_DEM_SUS_Readmissions_Unsuppressed] 

SELECT

	[Month]
	,'National' AS [Org_Type]
	,'England' AS [Organisation_Name]
	,'All Regions' AS [Region Name]
	,SUM(CASE WHEN [TimeBetweenAdmissions] <= 30 THEN Dementia END) AS [Readmissions30days]
	,SUM(CASE WHEN [TimeBetweenAdmissions] BETWEEN 31 AND 60 THEN Dementia END) AS [Readmissions60days]
	,SUM(CASE WHEN [TimeBetweenAdmissions] BETWEEN 61 AND 90 THEN Dementia END) AS [Readmissions90days]
	,'Emergency Admissions - Dementia Diagnosis' AS AdmissionGroup

FROM [MHDInternal].[TEMP_DEM_SUS_Readmission_Base]

GROUP BY [Month]

--------------------------Provider, Age 65+---------------------------

INSERT INTO [MHDInternal].[TEMP_DEM_SUS_Readmissions_Unsuppressed] 

SELECT 

	[Month]
	,'Provider' AS [Org_Type]
	,[Provider Name] AS [Organisation_Name]
	,[Provider Region Name] AS [Region Name]
	,SUM(CASE WHEN [TimeBetweenAdmissions] <= 30 THEN Age65 END) AS [Readmissions30days]
	,SUM(CASE WHEN [TimeBetweenAdmissions] BETWEEN 31 AND 60 THEN Age65 END) AS [Readmissions60days]
	,SUM(CASE WHEN [TimeBetweenAdmissions] BETWEEN 61 AND 90 THEN Age65 END) AS [Readmissions90days]
	,'Emergency Admissions - 65+' AS AdmissionGroup 

FROM [MHDInternal].[TEMP_DEM_SUS_Readmission_Base]

GROUP BY [Provider Region Name],[Provider Name], [Month]

--------------------------Sub ICB, Age 65+---------------------------

INSERT INTO [MHDInternal].[TEMP_DEM_SUS_Readmissions_Unsuppressed] 

SELECT 

	[Month]
	,'Sub ICB' AS [Org_Type]
	,[Sub ICB Name] AS [Organisation_Name]
	,[Commissioner Region Name] AS [Region Name]
	,SUM(CASE WHEN [TimeBetweenAdmissions] <= 30 THEN Age65 END) AS [Readmissions30days]
	,SUM(CASE WHEN [TimeBetweenAdmissions] BETWEEN 31 AND 60 THEN Age65 END) AS [Readmissions60days]
	,SUM(CASE WHEN [TimeBetweenAdmissions] BETWEEN 61 AND 90 THEN Age65 END) AS [Readmissions90days]
	,'Emergency Admissions - 65+' AS AdmissionGroup 

FROM [MHDInternal].[TEMP_DEM_SUS_Readmission_Base]

GROUP BY [Commissioner Region Name],[Sub ICB Name], [Month]

--------------------------ICB, Age 65+---------------------------

INSERT INTO [MHDInternal].[TEMP_DEM_SUS_Readmissions_Unsuppressed] 

SELECT 

	[Month]
	,'ICB' AS [Org_Type]
	,[ICB Name] AS [Organisation_Name]
	,[Commissioner Region Name] AS [Region Name]
	,SUM(CASE WHEN [TimeBetweenAdmissions] <= 30 THEN Age65 END) AS [Readmissions30days]
	,SUM(CASE WHEN [TimeBetweenAdmissions] BETWEEN 31 AND 60 THEN Age65 END) AS [Readmissions60days]
	,SUM(CASE WHEN [TimeBetweenAdmissions] BETWEEN 61 AND 90 THEN Age65 END) AS [Readmissions90days]
	,'Emergency Admissions - 65+' AS AdmissionGroup 

FROM [MHDInternal].[TEMP_DEM_SUS_Readmission_Base]

GROUP BY [Commissioner Region Name],[ICB Name], [Month]

--------------------------National, Age 65+---------------------------

INSERT INTO [MHDInternal].[TEMP_DEM_SUS_Readmissions_Unsuppressed]

SELECT 

	[Month]
	,'National' AS [Org_Type]
	,'England' AS [Organisation_Name]
	,'All Regions' AS [Region Name]
	,SUM(CASE WHEN [TimeBetweenAdmissions] <= 30 THEN Age65  END) AS [Readmissions30days]
	,SUM(CASE WHEN [TimeBetweenAdmissions] BETWEEN 31 AND 60 THEN Age65 END) AS [Readmissions60days]
	,SUM(CASE WHEN [TimeBetweenAdmissions] BETWEEN 61 AND 90 THEN Age65 END) AS [Readmissions90days]
	,'Emergency Admissions - 65+' AS AdmissionGroup 

FROM [MHDInternal].[TEMP_DEM_SUS_Readmission_Base]

GROUP BY [Month]

--------------------------------------Provider, Delirium-----------------------------------------------------------

INSERT INTO [MHDInternal].[TEMP_DEM_SUS_Readmissions_Unsuppressed] 

SELECT 

	[Month]
	,'Provider' AS [Org_Type]
	,[Provider Name] AS [Organisation_Name]
	,[Provider Region Name] AS [Region Name]
	,SUM(CASE WHEN [TimeBetweenAdmissions] <= 30 THEN Delirium END) AS [Readmissions30days]
	,SUM(CASE WHEN [TimeBetweenAdmissions] BETWEEN 31 AND 60 THEN Delirium END) AS [Readmissions60days]
	,SUM(CASE WHEN [TimeBetweenAdmissions] BETWEEN 61 AND 90 THEN Delirium END) AS [Readmissions90days]
	,'Emergency Admissions - Delirium Diagnosis' AS AdmissionGroup 

FROM [MHDInternal].[TEMP_DEM_SUS_Readmission_Base]

GROUP BY [Provider Region Name],[Provider Name], [Month]

--------------------------------------Sub ICB, Delirium-----------------------------------------------------------

INSERT INTO [MHDInternal].[TEMP_DEM_SUS_Readmissions_Unsuppressed] 

SELECT 

	[Month]
	,'Sub ICB' AS [Org_Type]
	,[Sub ICB Name] AS [Organisation_Name]
	,[Commissioner Region Name] AS [Region Name]
	,SUM(CASE WHEN [TimeBetweenAdmissions] <= 30 THEN Delirium END) AS [Readmissions30days]
	,SUM(CASE WHEN [TimeBetweenAdmissions] BETWEEN 31 AND 60 THEN Delirium END) AS [Readmissions60days]
	,SUM(CASE WHEN [TimeBetweenAdmissions] BETWEEN 61 AND 90 THEN Delirium END) AS [Readmissions90days]
	,'Emergency Admissions - Delirium Diagnosis' AS AdmissionGroup 

FROM [MHDInternal].[TEMP_DEM_SUS_Readmission_Base]

GROUP BY [Commissioner Region Name],[Sub ICB Name], [Month]

--------------------------------------ICB, Delirium-----------------------------------------------------------

INSERT INTO [MHDInternal].[TEMP_DEM_SUS_Readmissions_Unsuppressed]  

SELECT 

	[Month]
	,'ICB' AS [Org_Type]
	,[ICB Name] AS [Organisation_Name]
	,[Commissioner Region Name] AS [Region Name]
	,SUM(CASE WHEN [TimeBetweenAdmissions] <= 30 THEN Delirium END) AS [Readmissions30days]
	,SUM(CASE WHEN [TimeBetweenAdmissions] BETWEEN 31 AND 60 THEN Delirium END) AS [Readmissions60days]
	,SUM(CASE WHEN [TimeBetweenAdmissions] BETWEEN 61 AND 90 THEN Delirium END) AS [Readmissions90days]
	,'Emergency Admissions - Delirium Diagnosis' AS AdmissionGroup 

FROM [MHDInternal].[TEMP_DEM_SUS_Readmission_Base]

GROUP BY [Commissioner Region Name],[ICB Name], [Month]

--------------------------------------National, Delirium-----------------------------------------------------------

INSERT INTO [MHDInternal].[TEMP_DEM_SUS_Readmissions_Unsuppressed] 

SELECT 

	[Month]
	,'National' AS [Org_Type]
	,'England' AS [Organisation_Name]
	,'All Regions' AS [Region Name]
	,SUM(CASE WHEN [TimeBetweenAdmissions] <= 30 THEN Delirium END) AS [Readmissions30days]
	,SUM(CASE WHEN [TimeBetweenAdmissions] BETWEEN 31 AND 60 THEN Delirium END) AS [Readmissions60days]
	,SUM(CASE WHEN [TimeBetweenAdmissions] BETWEEN 61 AND 90 THEN Delirium END) AS [Readmissions90days]
	,'Emergency Admissions - Delirium Diagnosis' AS AdmissionGroup 

FROM [MHDInternal].[TEMP_DEM_SUS_Readmission_Base]

GROUP BY [Month]

--------------------------------------Provider, MCI-----------------------------------------------------------

INSERT INTO [MHDInternal].[TEMP_DEM_SUS_Readmissions_Unsuppressed] 

SELECT 

	[Month]
	,'Provider' AS [Org_Type]
	,[Provider Name] AS [Organisation_Name]
	,[Provider Region Name] AS [Region Name]
	,SUM(CASE WHEN [TimeBetweenAdmissions] <= 30 THEN MCI END) AS [Readmissions30days]
	,SUM(CASE WHEN [TimeBetweenAdmissions] BETWEEN 31 AND 60 THEN MCI END) AS [Readmissions60days]
	,SUM(CASE WHEN [TimeBetweenAdmissions] BETWEEN 61 AND 90 THEN MCI END) AS [Readmissions90days]
	,'Emergency Admissions - MCI Diagnosis' AS AdmissionGroup 

FROM [MHDInternal].[TEMP_DEM_SUS_Readmission_Base]

GROUP BY [Provider Region Name],[Provider Name], [Month]

--------------------------------------Sub ICB, MCI-----------------------------------------------------------

INSERT INTO [MHDInternal].[TEMP_DEM_SUS_Readmissions_Unsuppressed] 

SELECT 

	[Month]
	,'Sub ICB' AS [Org_Type]
	,[Sub ICB Name] AS [Organisation_Name]
	,[Commissioner Region Name] AS [Region Name]
	,SUM(CASE WHEN [TimeBetweenAdmissions] <= 30 THEN MCI END) AS [Readmissions30days]
	,SUM(CASE WHEN [TimeBetweenAdmissions] BETWEEN 31 AND 60 THEN MCI END) AS [Readmissions60days]
	,SUM(CASE WHEN [TimeBetweenAdmissions] BETWEEN 61 AND 90 THEN MCI END) AS [Readmissions90days]
	,'Emergency Admissions - MCI Diagnosis' AS AdmissionGroup 

FROM [MHDInternal].[TEMP_DEM_SUS_Readmission_Base]

GROUP BY [Commissioner Region Name],[Sub ICB Name], [Month]

--------------------------------------ICB, MCI-----------------------------------------------------------

INSERT INTO [MHDInternal].[TEMP_DEM_SUS_Readmissions_Unsuppressed] 

SELECT 

	[Month]
	,'ICB' AS [Org_Type]
	,[ICB Name] AS [Organisation_Name]
	,[Commissioner Region Name] AS [Region Name]
	,SUM(CASE WHEN [TimeBetweenAdmissions] <= 30 THEN MCI END) AS [Readmissions30days]
	,SUM(CASE WHEN [TimeBetweenAdmissions] BETWEEN 31 AND 60 THEN MCI END) AS [Readmissions60days]
	,SUM(CASE WHEN [TimeBetweenAdmissions] BETWEEN 61 AND 90 THEN MCI END) AS [Readmissions90days]
	,'Emergency Admissions - MCI Diagnosis' AS AdmissionGroup 

FROM [MHDInternal].[TEMP_DEM_SUS_Readmission_Base]

GROUP BY [Commissioner Region Name],[ICB Name], [Month]

--------------------------------------National, MCI-----------------------------------------------------------

INSERT INTO [MHDInternal].[TEMP_DEM_SUS_Readmissions_Unsuppressed] 

SELECT 

	[Month]
	,'National' AS [Org_Type]
	,'England' AS [Organisation_Name]
	,'All Regions' AS [Region Name]
	,SUM(CASE WHEN [TimeBetweenAdmissions] <= 30 THEN MCI END) AS [Readmissions30days]
	,SUM(CASE WHEN [TimeBetweenAdmissions] BETWEEN 31 AND 60 THEN MCI END) AS [Readmissions60days]
	,SUM(CASE WHEN [TimeBetweenAdmissions] BETWEEN 61 AND 90 THEN MCI END) AS [Readmissions90days]
	,'Emergency Admissions - MCI Diagnosis' AS AdmissionGroup 

FROM [MHDInternal].[TEMP_DEM_SUS_Readmission_Base]

GROUP BY [Month]

------------------------------------Provider, All-------------------------------------

INSERT INTO [MHDInternal].[TEMP_DEM_SUS_Readmissions_Unsuppressed] 

SELECT

	[Month]
	,'Provider' AS [Org_Type]
	,[Provider Name] AS [Organisation_Name]
	,[Provider Region Name] AS [Region Name]
	,COUNT(CASE WHEN [TimeBetweenAdmissions] <= 30 THEN [Der_Pseudo_NHS_Number] END) AS [Readmissions30days]
	,COUNT(CASE WHEN [TimeBetweenAdmissions] BETWEEN 31 AND 60 THEN [Der_Pseudo_NHS_Number] END) AS [Readmissions60days]
	,COUNT(CASE WHEN [TimeBetweenAdmissions] BETWEEN 61 AND 90 THEN [Der_Pseudo_NHS_Number] END) AS [Readmissions90days]
	,'Emergency Admissions' AS [AdmissionGroup]

FROM [MHDInternal].[TEMP_DEM_SUS_Readmission_Base]

GROUP BY [Provider Region Name],[Provider Name], [Month]


------------------------------------Sub ICB, All-------------------------------------

INSERT INTO [MHDInternal].[TEMP_DEM_SUS_Readmissions_Unsuppressed] 

SELECT 

	[Month]
	,'Sub ICB' AS [Org_Type]
	,[Sub ICB Name] AS [Organisation_Name]
	,[Commissioner Region Name] AS [Region Name]
	,COUNT(CASE WHEN [TimeBetweenAdmissions] <= 30 THEN [Der_Pseudo_NHS_Number] END) AS [Readmissions30days]
	,COUNT(CASE WHEN [TimeBetweenAdmissions] BETWEEN 31 AND 60 THEN [Der_Pseudo_NHS_Number] END) AS [Readmissions60days]
	,COUNT(CASE WHEN [TimeBetweenAdmissions] BETWEEN 61 AND 90 THEN [Der_Pseudo_NHS_Number] END) AS [Readmissions90days]
	,'Emergency Admissions' AS [AdmissionGroup]

FROM [MHDInternal].[TEMP_DEM_SUS_Readmission_Base]

GROUP BY [Commissioner Region Name],[Sub ICB Name], [Month]

------------------------------------ICB, All-------------------------------------

INSERT INTO [MHDInternal].[TEMP_DEM_SUS_Readmissions_Unsuppressed] 

SELECT 

	[Month]
	,'ICB' AS [Org_Type]
	,[ICB Name] AS [Organisation_Name]
	,[Commissioner Region Name] AS [Region Name]
	,COUNT(CASE WHEN [TimeBetweenAdmissions] <= 30 THEN [Der_Pseudo_NHS_Number] END) AS [Readmissions30days]
	,COUNT(CASE WHEN [TimeBetweenAdmissions] BETWEEN 31 AND 60 THEN [Der_Pseudo_NHS_Number] END) AS [Readmissions60days]
	,COUNT(CASE WHEN [TimeBetweenAdmissions] BETWEEN 61 AND 90 THEN [Der_Pseudo_NHS_Number] END) AS [Readmissions90days]
	,'Emergency Admissions' AS [AdmissionGroup]

FROM [MHDInternal].[TEMP_DEM_SUS_Readmission_Base]

GROUP BY [Commissioner Region Name],[ICB Name], [Month]

------------------------------------National, All-------------------------------------

INSERT INTO [MHDInternal].[TEMP_DEM_SUS_Readmissions_Unsuppressed] 

SELECT 

	[Month]
	,'National' AS [Org_Type]
	,'England' AS [Organisation_Name]
	,'All Regions' AS [Region Name]
	,COUNT(CASE WHEN [TimeBetweenAdmissions] <= 30 THEN [Der_Pseudo_NHS_Number] END) AS [Readmissions30days]
	,COUNT(CASE WHEN [TimeBetweenAdmissions] BETWEEN 31 AND 60 THEN [Der_Pseudo_NHS_Number] END) AS [Readmissions60days]
	,COUNT(CASE WHEN [TimeBetweenAdmissions] BETWEEN 61 AND 90 THEN [Der_Pseudo_NHS_Number] END) AS [Readmissions90days]
	,'Emergency Admissions' AS [AdmissionGroup]

FROM [MHDInternal].[TEMP_DEM_SUS_Readmission_Base]

GROUP BY [Month]
--------------------------------------------------------------------

SET @Offset = @Offset - 1

DROP TABLE [MHDInternal].[TEMP_DEM_SUS_Previous_Discharge]
DROP TABLE [MHDInternal].[TEMP_DEM_SUS_Latest_Admission]
DROP TABLE [MHDInternal].[TEMP_DEM_SUS_Readmission_Base]

END; -- End loop ----------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------

----------------Emergency Readmissions Output Table------------------------------------------------------------------

-- Final output table used in the dashboard containing suppressed values (where less than 7)

INSERT INTO [MHDInternal].[DASHBOARD_DEM_SUS_Emergency_Readmissions]

SELECT 
	
	[Month]
	,[Org_Type]
	,[Organisation_Name]
	,[Region Name]
	,CASE WHEN [Readmissions30days] < 7 THEN '*' ELSE CAST(([Readmissions30days]) AS VARCHAR) END AS [Readmissions30days]
	,CASE WHEN [Readmissions60days] < 7 THEN '*' ELSE CAST(([Readmissions60days]) AS VARCHAR) END AS [Readmissions60days]
	,CASE WHEN [Readmissions90days] < 7 THEN '*' ELSE CAST(([Readmissions90days]) AS VARCHAR) END AS [Readmissions90days]
	,[AdmissionGroup]
	,GETDATE() AS [SnapshotDate]

--INTO [MHDInternal].[DASHBOARD_DEM_SUS_Emergency_Readmissions]

FROM [MHDInternal].[TEMP_DEM_SUS_Readmissions_Unsuppressed] 

-- End of Step 2 ------------------------------------------------------------

-- Step 3 -------------------------------------------------------------------

DROP TABLE [MHDInternal].[TEMP_DEM_SUS_Readmissions_Unsuppressed]
