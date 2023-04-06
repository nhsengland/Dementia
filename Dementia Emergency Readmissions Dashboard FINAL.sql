
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
--	[Month]
--      ,[Org_Type]
--      ,[Organisation_Name]
--      ,[Region Name]
--      ,[Readmissions30days]
--      ,[Readmissions60days]
--      ,[Readmissions90days]
--      ,[AdmissionGroup])
--	  --- Delete into old refresh folder the last 12 months (i.e. 11 months preceding the latest month being added)
--where [Month]IN ('December 2022','November 2022','October 2022','September 2022','August 2022','July 2022','June 2022'
--,'May 2022','April 2022','March 2022','February 2022'
--)

IF OBJECT_ID ('[NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmissions_Unsuppressed]') IS NOT NULL DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmissions_Unsuppressed]
create table [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmissions_Unsuppressed] (
Month nvarchar(max)
,[Org_Type] varchar(max)
,[Organisation_Name] varchar(max)
,[Region Name] varchar(max)
,Readmissions30days int
,Readmissions60days int
,Readmissions90days int
,AdmissionGroup varchar(max)
)

SET NOCOUNT ON
--Offset should always be set to 0 to get the  most recent month available
DECLARE @Offset INT = 0

---------------------This should always be set at -11 to refresh the previous 12 months worth of data
DECLARE @Max_Offset INT = -11

--Execute the rest of the script once each declare has been set
---- Start loop ---------------------------------------------------------------------------------------------------------------------------------

WHILE (@Offset >= @Max_Offset) BEGIN


-- Latest Admission Time Frame
DECLARE @Period_End2 DATE 
DECLARE @Period_Start2 DATE
SET @Period_End2 = (SELECT DATEADD(MONTH,@Offset,MAX(EOMONTH([Report_Period_Start_Date]))) FROM [NHSE_SUSPlus_Live].[dbo].[tbl_Data_SEM_APCE])
SET @Period_Start2 = (SELECT DATEADD(DAY,1,EOMONTH(DATEADD(MONTH,-1,@Period_End2))))

-- Prev Admission Time frame
DECLARE @Period_Start DATE
DECLARE @Period_End DATE 
SET @Period_Start = (SELECT DATEADD(DAY,-90,@Period_Start2))
SET @Period_End = (SELECT DATEADD(DAY,-1,@Period_Start2))

PRINT @Period_Start2
PRINT @Period_End2
PRINT @Period_Start
PRINT @Period_End
-------------------Previous Admission----------------------------------

IF OBJECT_ID ('[NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Previous_Admission]') IS NOT NULL DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Previous_Admission]
SELECT 
[Der_Pseudo_NHS_Number]
,CAST([Admission_Date] AS DATE) AS [Admission_Date] 
,CAST([Discharge_Date] AS DATE) AS [Discharge_Date]
,[Provider_Code]
,[Commissioner_Code]
,ROW_NUMBER() OVER(PARTITION BY [Der_Pseudo_NHS_Number] ORDER BY [Discharge_Date] DESC) AS DischargeOrder
,CASE WHEN
Der_Diagnosis_All LIKE '%F000%'  OR 
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
Der_Diagnosis_All LIKE '%F021%'  OR 
Der_Diagnosis_All LIKE '%F022%'  OR 
Der_Diagnosis_All LIKE '%F023%'  OR 
Der_Diagnosis_All LIKE '%F024%'  OR 
Der_Diagnosis_All LIKE '%F028%' OR
(Der_Diagnosis_All LIKE '%F028%' AND Der_Diagnosis_All LIKE '%G318%') OR
Der_Diagnosis_All LIKE '%F03%' OR
Der_Diagnosis_All LIKE '%F051%' THEN 1 ELSE 0 END as Dementia
,CASE WHEN Der_Diagnosis_All LIKE '%F067%' THEN 1 ELSE 0 END as MCI
,CASE WHEN Der_Diagnosis_All LIKE '%F050%' OR  Der_Diagnosis_All LIKE '%F058%' OR Der_Diagnosis_All LIKE '%F059%' THEN 1 ELSE 0 END as Delirium
,CASE WHEN [Age_At_Start_of_Spell_SUS] >= 65 then 1 else 0 end as Age65
INTO [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Previous_Admission]
FROM [NHSE_SUSPlus_Live].[dbo].[tbl_Data_SEM_APCS] a
WHERE
Admission_Method LIKE '2%'
AND CAST(Discharge_Date AS DATE) BETWEEN @Period_Start AND @Period_End
AND [Der_Pseudo_NHS_Number] IS NOT NULL
AND [Patient_Classification] = 1
------------------------------Latest Admission-------------------------------------
IF OBJECT_ID ('[NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Latest_Admission]') IS NOT NULL DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Latest_Admission]
SELECT 
a.[Der_Pseudo_NHS_Number]
,CAST(a.[Admission_Date] AS DATE) AS [Admission_Date]
, CAST(a.[Discharge_Date] AS DATE) AS [Discharge_Date] 
,CASE WHEN o1.Region_Name IS NOT NULL THEN o1.Region_Name ELSE 'Other' END AS 'Provider Region Name'
,CASE WHEN o2.Region_Name IS NOT NULL THEN o2.Region_Name ELSE 'Other' END AS 'Commissioner Region Name'
,CASE WHEN o2.Organisation_Name IS NOT NULL THEN o2.Organisation_Name ELSE 'Other' END AS 'Sub ICB Name'
,CASE WHEN o1.Organisation_Name IS NOT NULL THEN o1.Organisation_Name ELSE 'Other' END AS 'Provider Name'
,CASE WHEN o2.STP_Name IS NOT NULL THEN o2.STP_Name ELSE 'Other' END AS 'ICB Name'
,ROW_NUMBER() OVER(PARTITION BY a.[Der_Pseudo_NHS_Number] ORDER BY a.[Admission_Date] ASC) AS AdmissionOrder
,a.Commissioner_Code
INTO [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Latest_Admission]
FROM [NHSE_SUSPlus_Live].[dbo].[tbl_Data_SEM_APCS] a
INNER JOIN [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Previous_Admission] b ON a.[Der_Pseudo_NHS_Number] = b.[Der_Pseudo_NHS_Number]
LEFT JOIN [NHSE_Sandbox_MentalHealth].[dbo].[CCG_2020_Lookup] c2 ON CASE WHEN a.[Commissioner_Code] LIKE '%00' THEN LEFT(a.[Commissioner_Code],3) ELSE a.[Commissioner_Code] END = c2.IC_CCG
LEFT JOIN NHSE_Reference.dbo.tbl_Ref_ODS_Provider_Hierarchies o1 ON LEFT(Der_Provider_Code,3) = LEFT(o1.Organisation_Code,3) AND Effective_To IS NULL AND LEN(o1.Organisation_Code) = 3
LEFT JOIN [NHSE_Reference].[dbo].[tbl_Ref_ODS_Commissioner_Hierarchies] o2 ON c2.CCG21 = o2.Organisation_Code 
WHERE
(Admission_Method LIKE '2%')
AND CAST(a.[Admission_Date] AS DATE) BETWEEN @Period_Start2 AND @Period_End2 
AND ([Patient_Classification] = 1)

IF OBJECT_ID ('[NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmission_Master]') IS NOT NULL DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmission_Master]
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
, DATEDIFF(DD, a.[Discharge_Date], b.Admission_Date) AS TimeBetweenAdmissions
INTO [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmission_Master]
FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Previous_Admission] a
INNER JOIN [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Latest_Admission] b ON a.[Der_Pseudo_NHS_Number] = b.[Der_Pseudo_NHS_Number] 
WHERE DischargeOrder = 1 AND AdmissionOrder = 1


--------Provider, Dementia-------------
INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmissions_Unsuppressed] 
SELECT
Month
,'Provider' AS [Org_Type]
,[Provider Name] AS [Organisation_Name]
,[Provider Region Name] AS [Region Name]
,SUM (CASE WHEN TimeBetweenAdmissions <= 30 THEN Dementia  END) AS Readmissions30days
,SUM (CASE WHEN TimeBetweenAdmissions BETWEEN 31 AND 60 THEN Dementia END) AS Readmissions60days
,SUM (CASE WHEN TimeBetweenAdmissions BETWEEN 61 AND 90 THEN Dementia END) AS Readmissions90days
,'Emergency Admissions - Dementia Diagnosis' AS AdmissionGroup
FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmission_Master]
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
FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmission_Master]
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
FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmission_Master]
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
FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmission_Master]
GROUP BY Month


--------------------------Provider, Age 65+---------------------------
INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmissions_Unsuppressed] 
SELECT 
Month
,'Provider' AS [Org_Type]
,[Provider Name] AS [Organisation_Name]
,[Provider Region Name] AS [Region Name]
,SUM(CASE WHEN TimeBetweenAdmissions <= 30 THEN Age65  END) AS Readmissions30days
,SUM(CASE WHEN TimeBetweenAdmissions BETWEEN 31 AND 60 THEN Age65 END) AS Readmissions60days
,SUM(CASE WHEN TimeBetweenAdmissions BETWEEN 61 AND 90 THEN Age65 END) AS Readmissions90days
,'Emergency Admissions - 65+' AS AdmissionGroup 
FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmission_Master]
GROUP BY [Provider Region Name],[Provider Name], Month


--------------------------Sub ICB, Age 65+---------------------------
INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmissions_Unsuppressed] 
SELECT 
Month
,'Sub ICB' AS [Org_Type]
,[Sub ICB Name] AS [Organisation_Name]
,[Commissioner Region Name] AS [Region Name]
,SUM(CASE WHEN TimeBetweenAdmissions <= 30 THEN Age65  END) AS Readmissions30days
,SUM(CASE WHEN TimeBetweenAdmissions BETWEEN 31 AND 60 THEN Age65 END) AS Readmissions60days
,SUM(CASE WHEN TimeBetweenAdmissions BETWEEN 61 AND 90 THEN Age65 END) AS Readmissions90days
,'Emergency Admissions - 65+' AS AdmissionGroup 
FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmission_Master]
GROUP BY [Commissioner Region Name],[Sub ICB Name], Month


--------------------------ICB, Age 65+---------------------------
INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmissions_Unsuppressed] 
SELECT 
Month
,'ICB' AS [Org_Type]
,[ICB Name] AS [Organisation_Name]
,[Commissioner Region Name] AS [Region Name]
,SUM(CASE WHEN TimeBetweenAdmissions <= 30 THEN Age65  END) AS Readmissions30days
,SUM(CASE WHEN TimeBetweenAdmissions BETWEEN 31 AND 60 THEN Age65 END) AS Readmissions60days
,SUM(CASE WHEN TimeBetweenAdmissions BETWEEN 61 AND 90 THEN Age65 END) AS Readmissions90days
,'Emergency Admissions - 65+' AS AdmissionGroup 
FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmission_Master]
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
FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmission_Master]
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
FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmission_Master]
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
FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmission_Master]
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
FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmission_Master]
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
FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmission_Master]
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
FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmission_Master]
GROUP BY [Provider Region Name],[Provider Name], Month


--------------------------------------Sub ICB, DMCI-----------------------------------------------------------
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
FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmission_Master]
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
FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmission_Master]
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
FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmission_Master]
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
FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmission_Master]
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
FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmission_Master]
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
FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmission_Master]
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
FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmission_Master]
GROUP BY Month
--------------------------------------------------------------------
SET @Offset = @Offset - 1
DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Previous_Admission]
DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Latest_Admission]
DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmission_Master]
END; 


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

--DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_SUS_Readmissions_Unsuppressed] 

