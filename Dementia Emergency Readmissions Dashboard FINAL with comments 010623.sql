 /****** Script for emergency readmissions for the Emergency Admissions for Dementia and Delirium Dashboard ******/

 -------------------------------------------------------------------------------------------------------------
 ------------------------------------Step 1-------------------------------------------------------------------
--The last 11 months of data are refreshed each month so the current version of these months are deleted from the table used in the dashboard 
--and added to an old refresh table to keep as a record. The old refresh data will be removed after a year (i.e. once it is no longer refreshed).

--Update the months which are deleted into the old refresh table: it should be the 11 months preceding the latest month being added.
--This first step is commented out to avoid being run by mistake, since it involves deletion
--Uncomment Step 1 and execute when refreshing months in financial year for superstats:

--DELETE [NHSE_Sandbox_MentalHealth].[dbo].[Dementia_Emergency_Readmissions_All_V2]
--OUTPUT 
--		DELETED.[Month]
--      ,DELETED.[Org_Type]
--      ,DELETED.[Organisation_Name]
--      ,DELETED.[Region Name]
--      ,DELETED.[Readmissions30days]
--      ,DELETED.[Readmissions60days]
--      ,DELETED.[Readmissions90days]
--      ,DELETED.[AdmissionGroup]
--INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dementia_Emergency_Readmissions_All_V2_Old_Refresh](
--		[Month]
--      ,[Org_Type]
--      ,[Organisation_Name]
--      ,[Region Name]
--      ,[Readmissions30days]
--      ,[Readmissions60days]
--      ,[Readmissions90days]
--      ,[AdmissionGroup])
--	  -- Update months which are deleted (see comment above for details)
--WHERE [Month] IN ('February 2023','January 2023','December 2022','November 2022','October 2022','September 2022','August 2022','July 2022','June 2022'
--,'May 2022','April 2022'
--)

-------------------------------------------------End of Step 1------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------Step 2-----------------------------------------------------------------
--Run Step 2

--Creates a table for the unsuppressed readmissions table needed later
IF OBJECT_ID ('[NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmissions_Unsuppressed]') IS NOT NULL DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmissions_Unsuppressed]
CREATE TABLE [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmissions_Unsuppressed] (
	Month nvarchar(max)
	,[Org_Type] varchar(max)
	,[Organisation_Name] varchar(max)
	,[Region Name] varchar(max)
	,Readmissions30days int
	,Readmissions60days int
	,Readmissions90days int
	,AdmissionGroup varchar(max)
	)

--Defines the Offset and Max_Offset used in the loop below so that each month in the last 12 months is cycled through the loop.
SET NOCOUNT ON
--Offset should always be set to 0 to get the  most recent month available
DECLARE @Offset INT = 0

--Max_Offset should always be set at -11 to refresh the previous 12 months worth of data
DECLARE @Max_Offset INT = -11

---- Start loop ---------------------------------------------------------------------------------------------------------------------------------
WHILE (@Offset >= @Max_Offset) BEGIN	--the loop will keep running from the latest month (offset=0) until the month 12 months prior (offset=-11)

--Latest Admission Time Frame
--This defines the time period for readmissions i.e. an admission following a discharge in the previous discharge time frame, defined below.
DECLARE @Period_End2 DATE 
DECLARE @Period_Start2 DATE
SET @Period_End2 = (SELECT DATEADD(MONTH,@Offset,MAX(EOMONTH([Report_Period_Start_Date]))) FROM [NHSE_SUSPlus_Live].[dbo].[tbl_Data_SEM_APCE])
SET @Period_Start2 = (SELECT DATEADD(DAY,1,EOMONTH(DATEADD(MONTH,-1,@Period_End2))))

--Previous Discharge Time Frame (90 days prior to the latest admission time frame)
--This defines the time period for discharges that may result in a readmission in the latest admission time frame, defined above.
DECLARE @Period_Start DATE
DECLARE @Period_End DATE 
SET @Period_Start = (SELECT DATEADD(DAY,-90,@Period_Start2))
SET @Period_End = (SELECT DATEADD(DAY,-1,@Period_Start2))

PRINT @Period_Start2
PRINT @Period_End2
PRINT @Period_Start
PRINT @Period_End

-------------------Previous Discharge Table----------------------------------
--This produces a record level table for discharges in the previous discharge time frame
IF OBJECT_ID ('[NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Previous_Discharge]') IS NOT NULL DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Previous_Discharge]
SELECT 
	[Der_Pseudo_NHS_Number]
	,CAST([Admission_Date] AS DATE) AS [Admission_Date] 
	,CAST([Discharge_Date] AS DATE) AS [Discharge_Date]
	,[Provider_Code]
	,[Commissioner_Code]
	,ROW_NUMBER() OVER(PARTITION BY [Der_Pseudo_NHS_Number] ORDER BY [Discharge_Date] DESC) AS DischargeOrder	--Orders discharge dates so the latest discharge date has a value of 1
--Dementia/MCI ICD10 codes from Page 13 of Dementia Care Pathway Appendices
	,CASE WHEN
		Der_Diagnosis_All LIKE '%F000%' OR 
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
		Der_Diagnosis_All LIKE '%F051%' THEN 1 ELSE 0 
	END AS Dementia
	,CASE WHEN Der_Diagnosis_All LIKE '%F067%' THEN 1 ELSE 0 
	END AS MCI
	,CASE WHEN Der_Diagnosis_All LIKE '%F050%' OR Der_Diagnosis_All LIKE '%F058%' OR Der_Diagnosis_All LIKE '%F059%' THEN 1 ELSE 0 
	END AS Delirium
	,CASE WHEN [Age_At_Start_of_Spell_SUS] >= 65 THEN 1 ELSE 0 
	END AS Age65
INTO [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Previous_Discharge]
FROM [NHSE_SUSPlus_Live].[dbo].[tbl_Data_SEM_APCS] a
WHERE Admission_Method LIKE '2%'	--Filters for emergency admissions only
	AND CAST(Discharge_Date AS DATE) BETWEEN @Period_Start AND @Period_End	--Filters for discharges in the previous admission time frame
	AND [Der_Pseudo_NHS_Number] IS NOT NULL
	AND [Patient_Classification] = 1	-- Filters for: 1 = Ordinary admission

------------------------------Latest Admission Table-------------------------------------
--This produces a record level table for admissions in the latest admission time frame but only for those records which have a discharge in the previous time frame table above 
IF OBJECT_ID ('[NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Latest_Admission]') IS NOT NULL DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Latest_Admission]
SELECT 
	a.[Der_Pseudo_NHS_Number]
	,CAST(a.[Admission_Date] AS DATE) AS [Admission_Date]
	, CAST(a.[Discharge_Date] AS DATE) AS [Discharge_Date] 
	,CASE WHEN o1.Region_Name IS NOT NULL THEN o1.Region_Name ELSE 'Other' 
	END AS 'Provider Region Name'
	,CASE WHEN o2.Region_Name IS NOT NULL THEN o2.Region_Name ELSE 'Other' 
	END AS 'Commissioner Region Name'
	,CASE WHEN o2.Organisation_Name IS NOT NULL THEN o2.Organisation_Name ELSE 'Other' 
	END AS 'Sub ICB Name'
	,CASE WHEN o1.Organisation_Name IS NOT NULL THEN o1.Organisation_Name ELSE 'Other' 
	END AS 'Provider Name'
	,CASE WHEN o2.STP_Name IS NOT NULL THEN o2.STP_Name ELSE 'Other' 
	END AS 'ICB Name'
	,ROW_NUMBER() OVER(PARTITION BY a.[Der_Pseudo_NHS_Number] ORDER BY a.[Admission_Date] ASC) AS AdmissionOrder	--Orders admission dates so the earliest admission date has a value of 1
	,a.Commissioner_Code
INTO [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Latest_Admission]
FROM [NHSE_SUSPlus_Live].[dbo].[tbl_Data_SEM_APCS] a
--Inner join to the previous admission table means only records with a discharge in the previous admission table will be included in this table
	INNER JOIN [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Previous_Discharge] b ON a.[Der_Pseudo_NHS_Number] = b.[Der_Pseudo_NHS_Number]
--Three tables joined to get Provider, Sub-ICB, ICB and Region names
	LEFT JOIN [NHSE_Sandbox_MentalHealth].[dbo].[CCG_2020_Lookup] c2 ON CASE WHEN a.[Commissioner_Code] LIKE '%00' THEN LEFT(a.[Commissioner_Code],3) ELSE a.[Commissioner_Code] END = c2.IC_CCG
	LEFT JOIN NHSE_Reference.dbo.tbl_Ref_ODS_Provider_Hierarchies o1 ON LEFT(Der_Provider_Code,3) = LEFT(o1.Organisation_Code,3) AND Effective_To IS NULL AND LEN(o1.Organisation_Code) = 3
	LEFT JOIN [NHSE_Reference].[dbo].[tbl_Ref_ODS_Commissioner_Hierarchies] o2 ON c2.CCG21 = o2.Organisation_Code 
WHERE (Admission_Method LIKE '2%')	--Filters for emergency admissions only
	AND CAST(a.[Admission_Date] AS DATE) BETWEEN @Period_Start2 AND @Period_End2 --Filters for discharges in the latest admission time frame
	AND ([Patient_Classification] = 1)	-- Filters for: 1 = Ordinary admission

-----------------------------------Readmissions Base Table--------------------------------------------------------------------------------
--This produces a base table  (this a record level table that can be aggregated later) that combines the previous admission and latest admission table. 
IF OBJECT_ID ('[NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmission_Base]') IS NOT NULL DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmission_Base]
SELECT 
	DATENAME(m, @Period_Start2) + ' ' + CAST(DATEPART(yyyy, @Period_Start2) AS varchar) AS Month
	,a.[Der_Pseudo_NHS_Number]
	,a.Admission_Date AS PreviousAdmission_Date 
	,a.Discharge_Date AS PreviousDischarge_Date
	,b.Admission_Date AS LatestAdmission_Date 
	,b.Discharge_Date AS LatestDischarge_Date
	,a.Dementia
	,a.MCI
	,a.Delirium
	,a.Age65
	,b.[Commissioner Region Name]
	,b.[Provider Region Name]
	,b.[Sub ICB Name]
	,b.[Provider Name]
	,b.[ICB Name]
	,DATEDIFF(DD, a.[Discharge_Date], b.Admission_Date) AS TimeBetweenAdmissions
INTO [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmission_Base]
FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Previous_Discharge] a
	INNER JOIN [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Latest_Admission] b ON a.[Der_Pseudo_NHS_Number] = b.[Der_Pseudo_NHS_Number] 
WHERE DischargeOrder = 1	--Only includes the latest discharge date 
	AND AdmissionOrder = 1	--Only includes the earliest admission date

------------------------------------------------Unsuppressed Readmissions Table---------------------------------------------------
--This table aggregates the Readmissions base table at Provider/Sub-ICB/ICB/National levels for the emergency readmission types of Dementia, Age 65+, Delerium, MCI and All

--------Provider, Dementia-------------
INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmissions_Unsuppressed] 
SELECT
	Month
	,'Provider' AS [Org_Type]
	,[Provider Name] AS [Organisation_Name]
	,[Provider Region Name] AS [Region Name]
	,SUM (CASE WHEN TimeBetweenAdmissions <= 30 THEN Dementia END) AS Readmissions30days
	,SUM (CASE WHEN TimeBetweenAdmissions BETWEEN 31 AND 60 THEN Dementia END) AS Readmissions60days
	,SUM (CASE WHEN TimeBetweenAdmissions BETWEEN 61 AND 90 THEN Dementia END) AS Readmissions90days
	,'Emergency Admissions - Dementia Diagnosis' AS AdmissionGroup
FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmission_Base]
GROUP BY [Provider Region Name],[Provider Name], Month


--------Sub ICB, Dementia-------------
INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmissions_Unsuppressed] 
SELECT
	Month
	,'Sub ICB' AS [Org_Type]
	,[Sub ICB Name]AS [Organisation_Name]
	,[Commissioner Region Name] AS [Region Name]
	,SUM(CASE WHEN TimeBetweenAdmissions <= 30 THEN Dementia END) AS Readmissions30days
	,SUM(CASE WHEN TimeBetweenAdmissions BETWEEN 31 AND 60 THEN Dementia END) AS Readmissions60days
	,SUM(CASE WHEN TimeBetweenAdmissions BETWEEN 61 AND 90 THEN Dementia END) AS Readmissions90days
	,'Emergency Admissions - Dementia Diagnosis' AS AdmissionGroup
FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmission_Base]
GROUP BY [Commissioner Region Name],[Sub ICB Name], Month


--------ICB, Dementia-------------
INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmissions_Unsuppressed] 
SELECT
	Month
	,'ICB' AS [Org_Type]
	,[ICB Name]AS [Organisation_Name]
	,[Commissioner Region Name] AS [Region Name]
	,SUM(CASE WHEN TimeBetweenAdmissions <= 30 THEN Dementia END) AS Readmissions30days
	,SUM(CASE WHEN TimeBetweenAdmissions BETWEEN 31 AND 60 THEN Dementia END) AS Readmissions60days
	,SUM(CASE WHEN TimeBetweenAdmissions BETWEEN 61 AND 90 THEN Dementia END) AS Readmissions90days
	,'Emergency Admissions - Dementia Diagnosis' AS AdmissionGroup
FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmission_Base]
GROUP BY [Commissioner Region Name],[ICB Name], Month

--------National, Dementia-------------
INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmissions_Unsuppressed] 
SELECT
	Month
	,'National' AS [Org_Type]
	,'England' AS [Organisation_Name]
	,'All Regions' as [Region Name]
	,SUM(CASE WHEN TimeBetweenAdmissions <= 30 THEN Dementia END) AS Readmissions30days
	,SUM(CASE WHEN TimeBetweenAdmissions BETWEEN 31 AND 60 THEN Dementia END) AS Readmissions60days
	,SUM(CASE WHEN TimeBetweenAdmissions BETWEEN 61 AND 90 THEN Dementia END) AS Readmissions90days
	,'Emergency Admissions - Dementia Diagnosis' AS AdmissionGroup
FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmission_Base]
GROUP BY Month


--------------------------Provider, Age 65+---------------------------
INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmissions_Unsuppressed] 
SELECT 
	Month
	,'Provider' AS [Org_Type]
	,[Provider Name] AS [Organisation_Name]
	,[Provider Region Name] AS [Region Name]
	,SUM(CASE WHEN TimeBetweenAdmissions <= 30 THEN Age65 END) AS Readmissions30days
	,SUM(CASE WHEN TimeBetweenAdmissions BETWEEN 31 AND 60 THEN Age65 END) AS Readmissions60days
	,SUM(CASE WHEN TimeBetweenAdmissions BETWEEN 61 AND 90 THEN Age65 END) AS Readmissions90days
	,'Emergency Admissions - 65+' AS AdmissionGroup 
FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmission_Base]
GROUP BY [Provider Region Name],[Provider Name], Month


--------------------------Sub ICB, Age 65+---------------------------
INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmissions_Unsuppressed] 
SELECT 
	Month
	,'Sub ICB' AS [Org_Type]
	,[Sub ICB Name] AS [Organisation_Name]
	,[Commissioner Region Name] AS [Region Name]
	,SUM(CASE WHEN TimeBetweenAdmissions <= 30 THEN Age65 END) AS Readmissions30days
	,SUM(CASE WHEN TimeBetweenAdmissions BETWEEN 31 AND 60 THEN Age65 END) AS Readmissions60days
	,SUM(CASE WHEN TimeBetweenAdmissions BETWEEN 61 AND 90 THEN Age65 END) AS Readmissions90days
	,'Emergency Admissions - 65+' AS AdmissionGroup 
FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmission_Base]
GROUP BY [Commissioner Region Name],[Sub ICB Name], Month


--------------------------ICB, Age 65+---------------------------
INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmissions_Unsuppressed] 
SELECT 
	Month
	,'ICB' AS [Org_Type]
	,[ICB Name] AS [Organisation_Name]
	,[Commissioner Region Name] AS [Region Name]
	,SUM(CASE WHEN TimeBetweenAdmissions <= 30 THEN Age65 END) AS Readmissions30days
	,SUM(CASE WHEN TimeBetweenAdmissions BETWEEN 31 AND 60 THEN Age65 END) AS Readmissions60days
	,SUM(CASE WHEN TimeBetweenAdmissions BETWEEN 61 AND 90 THEN Age65 END) AS Readmissions90days
	,'Emergency Admissions - 65+' AS AdmissionGroup 
FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmission_Base]
GROUP BY [Commissioner Region Name],[ICB Name], Month

--------------------------National, Age 65+---------------------------
INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmissions_Unsuppressed]  
SELECT 
	Month
	,'National' AS [Org_Type]
	,'England' AS [Organisation_Name]
	,'All Regions' as [Region Name]
	,SUM(CASE WHEN TimeBetweenAdmissions <= 30 THEN Age65  END) AS Readmissions30days
	,SUM(CASE WHEN TimeBetweenAdmissions BETWEEN 31 AND 60 THEN Age65 END) AS Readmissions60days
	,SUM(CASE WHEN TimeBetweenAdmissions BETWEEN 61 AND 90 THEN Age65 END) AS Readmissions90days
	,'Emergency Admissions - 65+' AS AdmissionGroup 
FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmission_Base]
GROUP BY Month

--------------------------------------Provider, Delirium-----------------------------------------------------------
INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmissions_Unsuppressed] 
SELECT 
	Month
	,'Provider' AS [Org_Type]
	,[Provider Name] AS [Organisation_Name]
	,[Provider Region Name] AS [Region Name]
	,SUM(CASE WHEN TimeBetweenAdmissions <= 30 THEN Delirium END) AS Readmissions30days
	,SUM(CASE WHEN TimeBetweenAdmissions BETWEEN 31 AND 60 THEN Delirium END) AS Readmissions60days
	,SUM(CASE WHEN TimeBetweenAdmissions BETWEEN 61 AND 90 THEN Delirium END) AS Readmissions90days
	,'Emergency Admissions - Delirium Diagnosis' AS AdmissionGroup 
FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmission_Base]
GROUP BY [Provider Region Name],[Provider Name], Month

--------------------------------------Sub ICB, Delirium-----------------------------------------------------------
INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmissions_Unsuppressed] 
SELECT 
	Month
	,'Sub ICB' AS [Org_Type]
	,[Sub ICB Name] AS [Organisation_Name]
	,[Commissioner Region Name] AS [Region Name]
	,SUM(CASE WHEN TimeBetweenAdmissions <= 30 THEN Delirium END) AS Readmissions30days
	,SUM(CASE WHEN TimeBetweenAdmissions BETWEEN 31 AND 60 THEN Delirium END) AS Readmissions60days
	,SUM(CASE WHEN TimeBetweenAdmissions BETWEEN 61 AND 90 THEN Delirium END) AS Readmissions90days
	,'Emergency Admissions - Delirium Diagnosis' AS AdmissionGroup 
FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmission_Base]
GROUP BY [Commissioner Region Name],[Sub ICB Name], Month


--------------------------------------ICB, Delirium-----------------------------------------------------------
INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmissions_Unsuppressed]  
SELECT 
	Month
	,'ICB' AS [Org_Type]
	,[ICB Name] AS [Organisation_Name]
	,[Commissioner Region Name] AS [Region Name]
	,SUM(CASE WHEN TimeBetweenAdmissions <= 30 THEN Delirium END) AS Readmissions30days
	,SUM(CASE WHEN TimeBetweenAdmissions BETWEEN 31 AND 60 THEN Delirium END) AS Readmissions60days
	,SUM(CASE WHEN TimeBetweenAdmissions BETWEEN 61 AND 90 THEN Delirium END) AS Readmissions90days
	,'Emergency Admissions - Delirium Diagnosis' AS AdmissionGroup 
FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmission_Base]
GROUP BY [Commissioner Region Name],[ICB Name], Month

--------------------------------------National, Delirium-----------------------------------------------------------
INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmissions_Unsuppressed] 
SELECT 
	Month
	,'National' AS [Org_Type]
	,'England' AS [Organisation_Name]
	,'All Regions' as [Region Name]
	,SUM(CASE WHEN TimeBetweenAdmissions <= 30 THEN Delirium END) AS Readmissions30days
	,SUM(CASE WHEN TimeBetweenAdmissions BETWEEN 31 AND 60 THEN Delirium END) AS Readmissions60days
	,SUM(CASE WHEN TimeBetweenAdmissions BETWEEN 61 AND 90 THEN Delirium END) AS Readmissions90days
	,'Emergency Admissions - Delirium Diagnosis' AS AdmissionGroup 
FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmission_Base]
GROUP BY Month

--------------------------------------Provider, MCI-----------------------------------------------------------
INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmissions_Unsuppressed] 
SELECT 
	Month
	,'Provider' AS [Org_Type]
	,[Provider Name] AS [Organisation_Name]
	,[Provider Region Name] AS [Region Name]
	,SUM(CASE WHEN TimeBetweenAdmissions <= 30 THEN MCI END) AS Readmissions30days
	,SUM(CASE WHEN TimeBetweenAdmissions BETWEEN 31 AND 60 THEN MCI END) AS Readmissions60days
	,SUM(CASE WHEN TimeBetweenAdmissions BETWEEN 61 AND 90 THEN MCI END) AS Readmissions90days
	,'Emergency Admissions - MCI Diagnosis' AS AdmissionGroup 
FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmission_Base]
GROUP BY [Provider Region Name],[Provider Name], Month


--------------------------------------Sub ICB, MCI-----------------------------------------------------------
INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmissions_Unsuppressed] 
SELECT 
	Month
	,'Sub ICB' AS [Org_Type]
	,[Sub ICB Name] AS [Organisation_Name]
	,[Commissioner Region Name] AS [Region Name]
	,SUM(CASE WHEN TimeBetweenAdmissions <= 30 THEN MCI END) AS Readmissions30days
	,SUM(CASE WHEN TimeBetweenAdmissions BETWEEN 31 AND 60 THEN MCI END) AS Readmissions60days
	,SUM(CASE WHEN TimeBetweenAdmissions BETWEEN 61 AND 90 THEN MCI END) AS Readmissions90days
	,'Emergency Admissions - MCI Diagnosis' AS AdmissionGroup 
FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmission_Base]
GROUP BY [Commissioner Region Name],[Sub ICB Name], Month


--------------------------------------ICB, MCI-----------------------------------------------------------
INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmissions_Unsuppressed] 
SELECT 
	Month
	,'ICB' AS [Org_Type]
	,[ICB Name] AS [Organisation_Name]
	,[Commissioner Region Name] AS [Region Name]
	,SUM(CASE WHEN TimeBetweenAdmissions <= 30 THEN MCI END) AS Readmissions30days
	,SUM(CASE WHEN TimeBetweenAdmissions BETWEEN 31 AND 60 THEN MCI END) AS Readmissions60days
	,SUM(CASE WHEN TimeBetweenAdmissions BETWEEN 61 AND 90 THEN MCI END) AS Readmissions90days
	,'Emergency Admissions - MCI Diagnosis' AS AdmissionGroup 
FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmission_Base]
GROUP BY [Commissioner Region Name],[ICB Name], Month

--------------------------------------National, MCI-----------------------------------------------------------
INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmissions_Unsuppressed] 
SELECT 
	Month
	,'National' AS [Org_Type]
	,'England' AS [Organisation_Name]
	,'All Regions' as [Region Name]
	,SUM(CASE WHEN TimeBetweenAdmissions <= 30 THEN MCI END) AS Readmissions30days
	,SUM(CASE WHEN TimeBetweenAdmissions BETWEEN 31 AND 60 THEN MCI END) AS Readmissions60days
	,SUM(CASE WHEN TimeBetweenAdmissions BETWEEN 61 AND 90 THEN MCI END) AS Readmissions90days
	,'Emergency Admissions - MCI Diagnosis' AS AdmissionGroup 
FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmission_Base]
GROUP BY Month

------------------------------------Provider, All-------------------------------------
INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmissions_Unsuppressed] 
SELECT 
	Month
	,'Provider' AS [Org_Type]
	,[Provider Name] AS [Organisation_Name]
	,[Provider Region Name] AS [Region Name]
	,COUNT(CASE WHEN TimeBetweenAdmissions <= 30 THEN [Der_Pseudo_NHS_Number]  END) AS Readmissions30days
	,COUNT(CASE WHEN TimeBetweenAdmissions BETWEEN 31 AND 60 THEN [Der_Pseudo_NHS_Number] END) AS Readmissions60days
	,COUNT(CASE WHEN TimeBetweenAdmissions BETWEEN 61 AND 90 THEN [Der_Pseudo_NHS_Number] END) AS Readmissions90days
	,'Emergency Admissions' AS AdmissionGroup
FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmission_Base]
GROUP BY [Provider Region Name],[Provider Name], Month


------------------------------------Sub ICB, All-------------------------------------
INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmissions_Unsuppressed] 
SELECT 
	Month
	,'Sub ICB' AS [Org_Type]
	,[Sub ICB Name] AS [Organisation_Name]
	,[Commissioner Region Name] AS [Region Name]
	,COUNT(CASE WHEN TimeBetweenAdmissions <= 30 THEN [Der_Pseudo_NHS_Number]  END) AS Readmissions30days
	,COUNT(CASE WHEN TimeBetweenAdmissions BETWEEN 31 AND 60 THEN [Der_Pseudo_NHS_Number] END) AS Readmissions60days
	,COUNT(CASE WHEN TimeBetweenAdmissions BETWEEN 61 AND 90 THEN [Der_Pseudo_NHS_Number] END) AS Readmissions90days
	,'Emergency Admissions' AS AdmissionGroup
FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmission_Base]
GROUP BY [Commissioner Region Name],[Sub ICB Name], Month


------------------------------------ICB, All-------------------------------------
INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmissions_Unsuppressed] 
SELECT 
	Month
	,'ICB' AS [Org_Type]
	,[ICB Name] AS [Organisation_Name]
	,[Commissioner Region Name] AS [Region Name]
	,COUNT(CASE WHEN TimeBetweenAdmissions <= 30 THEN [Der_Pseudo_NHS_Number]  END) AS Readmissions30days
	,COUNT(CASE WHEN TimeBetweenAdmissions BETWEEN 31 AND 60 THEN [Der_Pseudo_NHS_Number] END) AS Readmissions60days
	,COUNT(CASE WHEN TimeBetweenAdmissions BETWEEN 61 AND 90 THEN [Der_Pseudo_NHS_Number] END) AS Readmissions90days
	,'Emergency Admissions' AS AdmissionGroup
FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmission_Base]
GROUP BY [Commissioner Region Name],[ICB Name], Month


------------------------------------National, All-------------------------------------
INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmissions_Unsuppressed] 
SELECT 
	Month
	,'National' AS [Org_Type]
	,'England' AS [Organisation_Name]
	,'All Regions' as [Region Name]
	,COUNT(CASE WHEN TimeBetweenAdmissions <= 30 THEN [Der_Pseudo_NHS_Number]  END) AS Readmissions30days
	,COUNT(CASE WHEN TimeBetweenAdmissions BETWEEN 31 AND 60 THEN [Der_Pseudo_NHS_Number] END) AS Readmissions60days
	,COUNT(CASE WHEN TimeBetweenAdmissions BETWEEN 61 AND 90 THEN [Der_Pseudo_NHS_Number] END) AS Readmissions90days
	,'Emergency Admissions' AS AdmissionGroup
FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmission_Base]
GROUP BY Month
--------------------------------------------------------------------
SET @Offset = @Offset - 1	--This changes the offset by one month for the loop to start again with the next month
DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Previous_Discharge]
DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Latest_Admission]
DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmission_Base]
END;	--End of loop


----------------Emergency Readmissions Output Table-----------------------------------------------------------
--This table uses the unsuppressed table produced above and suppresses any metrics that are less than 7.This is the final output table used in the dashboard. 

--IF OBJECT_ID ('[NHSE_Sandbox_MentalHealth].[dbo].[Dementia_Emergency_Readmissions_All_Dec_Update]') IS NOT NULL DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].[Dementia_Emergency_Readmissions_All_Dec_Update]
INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dementia_Emergency_Readmissions_All_V2]
SELECT 
	[Month]
	,Org_Type
	,[Organisation_Name]
	,[Region Name]
	,CASE WHEN Readmissions30days < 7 THEN '*' ELSE CAST((Readmissions30days) AS VARCHAR) END AS Readmissions30days
	,CASE WHEN Readmissions60days  < 7 THEN '*' ELSE CAST((Readmissions60days) AS VARCHAR) END AS Readmissions60days
	,CASE WHEN  Readmissions90days  < 7 THEN '*' ELSE CAST((Readmissions90days) AS VARCHAR) END AS  Readmissions90days
	,[AdmissionGroup]
--INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dementia_Emergency_Readmissions_All_Dec_Update]
FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmissions_Unsuppressed] 

----------------------------------End of Step 3------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------
-------------------------------------Step 3---------------------------------------------------------------
--Uncomment Step 3 and execute to drop the temporary tables used in the query, once you are happy the previous steps have run correctly

--DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmissions_Unsuppressed] 

----------------------------------End of Step 3------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------

----------------------------------End of Script------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------