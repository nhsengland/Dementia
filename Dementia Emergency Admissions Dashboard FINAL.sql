
--Update the months listed - see comment below
--DELETE [NHSE_Sandbox_MentalHealth].[dbo].[Dementia_Dashboard_SUS_v2]
--OUTPUT 
--		DELETED.[Month]
--      ,DELETED.[GroupType]
--      ,DELETED.[RegionCode]
--      ,DELETED.[GeographyName]
--      ,DELETED.[Category]
--      ,DELETED.[Variable]
--      ,DELETED.[Emergency Admissions]
--      ,DELETED.[Emergency Admissions - Aged 65 Years and Over]
--      ,DELETED.[Emergency Admissions - Dementia Diagnosis]
--      ,DELETED.[Emergency Admissions - Delirium Diagnosis]
--      ,DELETED.[Emergency Admissions - MCI Diagnosis]
--      ,DELETED.[Primary Diagnosis Chapter]
--INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dementia_Dashboard_SUS_v2_Old_Refresh](
--		[Month]
--      ,[GroupType]
--      ,[RegionCode]
--      ,[GeographyName]
--      ,[Category]
--      ,[Variable]
--      ,[Emergency Admissions]
--      ,[Emergency Admissions - Aged 65 Years and Over]
--      ,[Emergency Admissions - Dementia Diagnosis]
--      ,[Emergency Admissions - Delirium Diagnosis]
--      ,[Emergency Admissions - MCI Diagnosis]
--      ,[Primary Diagnosis Chapter])
--	  --- Delete into old refresh folder the last 12 months (i.e. 11 months preceding the latest month being added)
--where [Month]IN ('2022-12-01 00:00:00.000','2022-11-01 00:00:00.000','2022-10-01 00:00:00.000','2022-09-01 00:00:00.000','2022-08-01 00:00:00.000','2022-07-01 00:00:00.000'
--,'2022-06-01 00:00:00.000','2022-05-01 00:00:00.000','2022-04-01 00:00:00.000','2022-03-01 00:00:00.000','2022-02-01 00:00:00.000'
--)

USE [NHSE_SUSPlus_Live]
--This is the Offset month so 0 would be the latest available
DECLARE @Offset int = 0

DECLARE @Period_Start DATE
DECLARE @Period_End DATE

SET @Period_End = (SELECT DATEADD(MONTH,@Offset,MAX(EOMONTH([Report_Period_Start_Date]))) FROM [tbl_Data_SEM_APCE])
SET @Period_Start = (SELECT DATEADD(DAY,1, EOMONTH(DATEADD(MONTH,-12,@Period_End))))
--Check Period Start is the beginning of the month 12 months prior to the latest month being added (means the last 12 months get refreshed each month)
--Check Period End is the end of the latest month
PRINT CAST(@Period_Start AS VARCHAR(10)) + ' <-- Period_Start'
PRINT CAST(@Period_End AS VARCHAR(10)) + ' <-- Period_end'

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
MASTER APCE TABLE 
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/
IF OBJECT_ID ('[NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Dementia_SUS_Dashboard_APCE]') IS NOT NULL DROP TABLE  [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Dementia_SUS_Dashboard_APCE]
SELECT 
	a.APCE_Ident
	,DATEADD(MONTH, DATEDIFF(MONTH, 0, a.Admission_Date), 0) AS Admission_Month
	,DATEADD(MONTH, DATEDIFF(MONTH, 0, a.Discharge_Date), 0) AS Discharge_Month
	,ISNULL(RIGHT(r1.Person_Gender_Desc, LEN(r1.Person_Gender_Desc)-3),'Missing/invalid') AS Gender
	,ISNULL(r2.Ethnic_Category_Main_Desc_Short, 'Missing/invalid') AS Ethnicity
	,ISNULL(RIGHT(r3.Admission_Source_Desc, LEN(r3.Admission_Source_Desc)-4),'Missing/invalid') AS Admission_Source
	,ISNULL(RIGHT(r4.Discharge_Destination_Desc, LEN(r4.Discharge_Destination_Desc)-4),'Missing/invalid') AS Discharge_Destination
	,r5.[ICD10_L2_Desc] AS [Primary Diagnosis]
	,r5.[ICD10_Chapter_Desc] AS [Primary Diagnosis Chapter]
	,CASE WHEN a.Admission_Date BETWEEN @Period_Start and @Period_End THEN 1 ELSE 0 END AS Der_Admission 
	,CASE WHEN a.Discharge_Date BETWEEN @Period_Start and @Period_End THEN 1 ELSE 0 END AS Der_Discharge 
	,Age_on_Admission
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
,CASE WHEN (Der_Diagnosis_All LIKE '%F050%' OR  Der_Diagnosis_All LIKE '%F058%' OR Der_Diagnosis_All LIKE '%F059%') THEN 1 ELSE 0 END as Delirium
,a.Der_Provider_Code
,o2.Organisation_Name AS [Provider Name]
,o2.Region_Name as Region_Name_Provider
,o1.Organisation_Code AS [Sub ICB Code]
,o1.Organisation_Name AS [Sub ICB Name]
,o1.STP_Name AS [ICB Name]
,o1.Region_Name as Region_Name_Commissioner
INTO [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Dementia_SUS_Dashboard_APCE]
FROM [NHSE_SUSPlus_Live].[dbo].[tbl_Data_SEM_APCE] a
LEFT JOIN [NHSE_Reference].[dbo].[tbl_Ref_DataDic_ZZZ_PersonGender] r1 ON a.Sex=r1.Person_Gender_Code
LEFT JOIN NHSE_Reference.dbo.tbl_Ref_DataDic_ZZZ_EthnicCategory r2 ON a.Ethnic_Group = r2.Ethnic_Category 
LEFT JOIN NHSE_Reference.dbo.tbl_Ref_DataDic_APC_AdmissionSource r3 ON a.Source_of_Admission = r3.Admission_Source
LEFT JOIN NHSE_Reference.dbo.tbl_Ref_DataDic_APC_DischargeDestination r4 ON a.Discharge_Destination = r4.Discharge_Destination
LEFT JOIN [NHSE_Reference].[dbo].[tbl_Ref_ClinCode_ICD10] r5 ON a.[Der_Primary_Diagnosis_Code] = r5.[ICD10_L4_Code] AND r5.[ICD10_Valid_To] IS NULL
LEFT JOIN [NHSE_Sandbox_MentalHealth].[dbo].[CCG_2020_Lookup] c ON a.Commissioner_Code = c.IC_CCG					
LEFT JOIN [NHSE_Reference].[dbo].[tbl_Ref_ODS_Commissioner_Hierarchies] o1 ON c.CCG21 = o1.Organisation_Code 
LEFT JOIN NHSE_Reference.dbo.tbl_Ref_ODS_Provider_Hierarchies o2 ON LEFT(a.Der_Provider_Code,3) = LEFT(o2.Organisation_Code,3) AND o2.Effective_To IS NULL AND LEN(o2.Organisation_Code) = 3
WHERE
([Admission_Date] BETWEEN @Period_Start and @Period_End or [Discharge_Date] BETWEEN @Period_Start AND @Period_End) 
AND a.Episode_Number = 1 
AND (Admission_Method LIKE '2%') 
AND [Patient_Classification] IN ('1','2','5') 



IF OBJECT_ID ('[NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Dementia_SUS_Dashboard_APCS]') IS NOT NULL DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Dementia_SUS_Dashboard_APCS]
SELECT
	b.APCS_Ident
	,DATEADD(MONTH, DATEDIFF(MONTH, 0, b.Admission_Date), 0) AS Admission_Month
	,b.Age_At_Start_of_Spell_SUS
	, CASE WHEN [Der_Spell_LoS] <= 1 THEN '1 Day or less'
			WHEN [Der_Spell_LoS] BETWEEN 2 and 3 THEN 'Between 2 and 3 Days'
			WHEN [Der_Spell_LoS] BETWEEN 4 AND 10 THEN 'Between 4 and 10 Days'
			WHEN [Der_Spell_LoS] BETWEEN 11 AND 21 THEN 'Between 11 and 21 Days'
			WHEN [Der_Spell_LoS] > 21 THEN 'More than 21 Days'
			 END AS LengthOfStay
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
,CASE WHEN (Der_Diagnosis_All LIKE '%F050%' OR  Der_Diagnosis_All LIKE '%F058%' OR Der_Diagnosis_All LIKE '%F059%') THEN 1 ELSE 0 END as Delirium
,b.Der_Provider_Code
,o2.Organisation_Name AS [Provider Name]
,o2.Region_Name as Region_Name_Provider
,o1.Organisation_Code AS [Sub ICB Code]
,o1.Organisation_Name AS [Sub ICB Name]
,o1.STP_Name AS [ICB Name]
,o1.Region_Name as Region_Name_Commissioner
--,CASE WHEN DATEDIFF(dd,Discharge_Ready_Date,Discharge_Date)<=3 THEN '3 Days or less'
--WHEN DATEDIFF(dd,Discharge_Ready_Date,Discharge_Date) BETWEEN 4 and 10 THEN 'Between 4 and 10 Days' 
--WHEN DATEDIFF(dd,Discharge_Ready_Date,Discharge_Date) BETWEEN 11 and 21 THEN 'Between 11 and 21 Days' 
--WHEN DATEDIFF(dd,Discharge_Ready_Date,Discharge_Date) > 21 THEN 'More than 21 Days' 
--END AS DTOC_Group
--,DATEDIFF(dd,Discharge_Ready_Date,Discharge_Date) as DTOC
INTO [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Dementia_SUS_Dashboard_APCS]
FROM[NHSE_SUSPlus_Live].[dbo].[tbl_Data_SEM_APCS] b
LEFT JOIN [NHSE_Sandbox_MentalHealth].[dbo].[CCG_2020_Lookup] c ON b.Commissioner_Code = c.IC_CCG					
LEFT JOIN [NHSE_Reference].[dbo].[tbl_Ref_ODS_Commissioner_Hierarchies] o1 ON c.CCG21 = o1.Organisation_Code 
LEFT JOIN NHSE_Reference.dbo.tbl_Ref_ODS_Provider_Hierarchies o2 ON LEFT(b.Der_Provider_Code,3) = LEFT(o2.Organisation_Code,3) AND o2.Effective_To IS NULL AND LEN(o2.Organisation_Code) = 3
Where
([Admission_Date] between @Period_Start and @Period_End) and
(Admission_Method LIKE '2%') AND [Patient_Classification] IN ('1','2','5')

--create table [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Dementia_SUS_Dashboard_Unsuppressed](
--[Month] datetime
--      ,[GroupType] varchar(max)
--      ,[RegionCode] varchar(max)
--      ,[GeographyName] varchar(max)
--      ,[Category] varchar(max)
--      ,[Variable] varchar(max)
--      ,[Num_Emergency_Admissions] int
--      ,[Num_Emergency_Admissions_65andOver] int
--      ,[Num_Emergency_Admissions_Dementia] int
--      ,[Num_Emergency_Admissions_Delirium] int
--      ,[Num_Emergency_Admissions_MCI] int
--      ,[Primary Diagnosis Chapter] varchar(max))
---------------------------------Unsuppressed Table------------------------------------------------
---------------------------------National, Gender-----------------------------------------------------------------------------------------------------------------
IF OBJECT_ID ('[NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Dementia_SUS_Dashboard_Unsuppressed]') IS NOT NULL DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Dementia_SUS_Dashboard_Unsuppressed]
--INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Dementia_SUS_Dashboard_Unsuppressed]
SELECT 
	Admission_Month AS [Month]
	,'National' AS GroupType
	,cast('All Regions'as varchar(max)) AS RegionCode
	,cast('England' as varchar(max)) AS GeographyName
	,cast('Gender' as varchar(max)) AS Category
	,cast(Gender as varchar(max)) AS Variable
	,COUNT(*) as Num_Emergency_Admissions
	,SUM(CASE WHEN Age_on_Admission >= 65 THEN 1 ELSE 0 END) as Num_Emergency_Admissions_65andOver
	,SUM(Dementia) as Num_Emergency_Admissions_Dementia
	,SUM(Delirium) as Num_Emergency_Admissions_Delirium
	,SUM(MCI) as Num_Emergency_Admissions_MCI
	,cast(null as varchar(max)) as [Primary Diagnosis Chapter]
INTO [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Dementia_SUS_Dashboard_Unsuppressed]
FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Dementia_SUS_Dashboard_APCE] a
where Der_Admission=1
Group by 
Admission_Month
,Gender
---------------------------------National, Ethnicity-----------------------------------------------------------------------------------------------------------
INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Dementia_SUS_Dashboard_Unsuppressed]
SELECT 
	Admission_Month AS [Month]
	,'National' AS GroupType
	,'All Regions' AS RegionCode
	,'England'AS GeographyName
	,'Ethnicity'AS Category
	,Ethnicity AS Variable
	,COUNT(*) as Num_Emergency_Admissions
	,SUM(CASE WHEN Age_on_Admission >= 65 THEN 1 ELSE 0 END) as Num_Emergency_Admissions_65andOver
	,SUM(Dementia) as Num_Emergency_Admissions_Dementia
	,SUM(Delirium) as Num_Emergency_Admissions_Delirium
	,SUM(MCI) as Num_Emergency_Admissions_MCI
	,null as [Primary Diagnosis Chapter]
FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Dementia_SUS_Dashboard_APCE] a
where Der_Admission=1
Group by 
Admission_Month
,Ethnicity
---------------------------------National, Admission Source-------------------------------------------------------------------------------------------------
INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Dementia_SUS_Dashboard_Unsuppressed]
SELECT 
	Admission_Month AS [Month]
	,'National' AS GroupType
	,'All Regions' AS RegionCode
	,'England'AS GeographyName
	,'Admission Source'AS Category
	,Admission_Source AS Variable
	,COUNT(*) as Num_Emergency_Admissions
	,SUM(CASE WHEN Age_on_Admission >= 65 THEN 1 ELSE 0 END) as Num_Emergency_Admissions_65andOver
	,SUM(Dementia) as Num_Emergency_Admissions_Dementia
	,SUM(Delirium) as Num_Emergency_Admissions_Delirium
	,SUM(MCI) as Num_Emergency_Admissions_MCI
	,null as [Primary Diagnosis Chapter]
FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Dementia_SUS_Dashboard_APCE] a
where Der_Admission=1
Group by 
Admission_Month
,Admission_Source
---------------------------------National, Discharge Destination--------------------------------------------------------------------------------
INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Dementia_SUS_Dashboard_Unsuppressed]
SELECT 
	Discharge_Month AS [Month]
	,'National' AS GroupType
	,'All Regions' AS RegionCode
	,'England'AS GeographyName
	,'Discharge Destination'AS Category
	,Discharge_Destination AS Variable
	,COUNT(*) as Num_Emergency_Admissions
	,SUM(CASE WHEN Age_on_Admission >= 65 THEN 1 ELSE 0 END) as Num_Emergency_Admissions_65andOver
	,SUM(Dementia) as Num_Emergency_Admissions_Dementia
	,SUM(Delirium) as Num_Emergency_Admissions_Delirium
	,SUM(MCI) as Num_Emergency_Admissions_MCI
	,null as [Primary Diagnosis Chapter]
FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Dementia_SUS_Dashboard_APCE] a
where Der_Discharge=1
Group by 
Discharge_Month
,Discharge_Destination
-------------------------------National, Length of Stay---------------------------------------------------------------------------------------
INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Dementia_SUS_Dashboard_Unsuppressed]
SELECT 
	Admission_Month as [Month]
	,'National' AS GroupType
	,'All Regions' AS RegionCode
	,'England'AS GeographyName
	,'Length of Stay'AS Category
	,LengthOfStay AS Variable
	,COUNT(*) as Num_Emergency_Admissions
	,SUM(CASE WHEN Age_At_Start_of_Spell_SUS >= 65 THEN 1 ELSE 0 END) as Num_Emergency_Admissions_65andOver
	,SUM(Dementia) as Num_Emergency_Admissions_Dementia
	,SUM(Delirium) as Num_Emergency_Admissions_Delirium
	,SUM(MCI) as Num_Emergency_Admissions_MCI
	,null as [Primary Diagnosis Chapter]
FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Dementia_SUS_Dashboard_APCS] a
Group by 
Admission_Month
,LengthOfStay

---------------------------------National, DTOC---------------------------------------------------------------------------------------
--INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Dementia_SUS_Dashboard_Unsuppressed]
--SELECT 
--	Admission_Month as [Month]
--	,'National' AS GroupType
--	,'All Regions' AS RegionCode
--	,'England'AS GeographyName
--	,'Delayed Transfer of Care'AS Category
--	,DTOC AS Variable
--	,COUNT(*) as Num_Emergency_Admissions
--	,SUM(CASE WHEN Age_At_Start_of_Spell_SUS >= 65 THEN 1 ELSE 0 END) as Num_Emergency_Admissions_65andOver
--	,SUM(Dementia) as Num_Emergency_Admissions_Dementia
--	,SUM(Delirium) as Num_Emergency_Admissions_Delirium
--	,SUM(MCI) as Num_Emergency_Admissions_MCI
--	,null as [Primary Diagnosis Chapter]
--FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Dementia_SUS_Dashboard_APCS] a
--Group by 
--Admission_Month
--,LengthOfStay
-------------------------------National, Total---------------------------------------------------------------------------------------------------
INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Dementia_SUS_Dashboard_Unsuppressed]
SELECT 
	Admission_Month AS [Month]
	,'National' AS GroupType
	,'All Regions' AS RegionCode
	,'England' AS GeographyName
	,'Total'AS Category
	,'Total' AS Variable
	,COUNT(*) as Num_Emergency_Admissions
	,SUM(CASE WHEN Age_on_Admission >= 65 THEN 1 ELSE 0 END) as Num_Emergency_Admissions_65andOver
	,SUM(Dementia) as Num_Emergency_Admissions_Dementia
	,SUM(Delirium) as Num_Emergency_Admissions_Delirium
	,SUM(MCI) as Num_Emergency_Admissions_MCI
	,null as [Primary Diagnosis Chapter]
FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Dementia_SUS_Dashboard_APCE] a
where Der_Admission=1
Group by 
Admission_Month
-------------------------------National, Primary Diagnosis------------------------------------------------------------------------------
INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Dementia_SUS_Dashboard_Unsuppressed]
SELECT 
	Admission_Month AS [Month]
	,'National' AS GroupType
	,'All Regions' AS RegionCode
	,'England'AS GeographyName
	,'Primary Diagnosis'AS Category
	,[Primary Diagnosis] AS Variable
	,COUNT(*) as Num_Emergency_Admissions
	,SUM(CASE WHEN Age_on_Admission >= 65 THEN 1 ELSE 0 END) as Num_Emergency_Admissions_65andOver
	,SUM(Dementia) as Num_Emergency_Admissions_Dementia
	,SUM(Delirium) as Num_Emergency_Admissions_Delirium
	,SUM(MCI) as Num_Emergency_Admissions_MCI
	,[Primary Diagnosis Chapter]
FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Dementia_SUS_Dashboard_APCE] a
where Der_Admission=1
Group by 
Admission_Month
,[Primary Diagnosis]
,[Primary Diagnosis Chapter]
---------------------------------ICB, Gender------------------------------------------------------------------------------------------------------
INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Dementia_SUS_Dashboard_Unsuppressed]
SELECT 
	Admission_Month AS [Month]
	,'ICB' AS GroupType
	,Region_Name_Commissioner AS RegionCode
	,[ICB Name] AS GeographyName
	,'Gender' AS Category
	,Gender AS Variable
	,COUNT(*) as Num_Emergency_Admissions
	,SUM(CASE WHEN Age_on_Admission >= 65 THEN 1 ELSE 0 END) as Num_Emergency_Admissions_65andOver
	,SUM(Dementia) as Num_Emergency_Admissions_Dementia
	,SUM(Delirium) as Num_Emergency_Admissions_Delirium
	,SUM(MCI) as Num_Emergency_Admissions_MCI
	,null as [Primary Diagnosis Chapter]
FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Dementia_SUS_Dashboard_APCE] a
where Der_Admission=1
Group by 
Admission_Month
,Region_Name_Commissioner
,[ICB Name]
,Gender
---------------------------------ICB, Ethnicity---------------------------------------------------------------------------
INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Dementia_SUS_Dashboard_Unsuppressed]
SELECT 
	Admission_Month AS [Month]
	,'ICB' AS GroupType
	,Region_Name_Commissioner AS RegionCode
	,[ICB Name] AS GeographyName
	,'Ethnicity' AS Category
	,Ethnicity AS Variable
	,COUNT(*) as Num_Emergency_Admissions
	,SUM(CASE WHEN Age_on_Admission >= 65 THEN 1 ELSE 0 END) as Num_Emergency_Admissions_65andOver
	,SUM(Dementia) as Num_Emergency_Admissions_Dementia
	,SUM(Delirium) as Num_Emergency_Admissions_Delirium
	,SUM(MCI) as Num_Emergency_Admissions_MCI
	,null as [Primary Diagnosis Chapter]
FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Dementia_SUS_Dashboard_APCE] a
where Der_Admission=1
Group by 
Admission_Month
,Region_Name_Commissioner
,[ICB Name]
,Ethnicity
---------------------------------ICB, Admission Source------------------------------------------------------------------------------------------
INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Dementia_SUS_Dashboard_Unsuppressed]
SELECT 
	Admission_Month AS [Month]
	,'ICB' AS GroupType
	,Region_Name_Commissioner AS RegionCode
	,[ICB Name] AS GeographyName
	,'Admission Source' AS Category
	,Admission_Source AS Variable
	,COUNT(*) as Num_Emergency_Admissions
	,SUM(CASE WHEN Age_on_Admission >= 65 THEN 1 ELSE 0 END) as Num_Emergency_Admissions_65andOver
	,SUM(Dementia) as Num_Emergency_Admissions_Dementia
	,SUM(Delirium) as Num_Emergency_Admissions_Delirium
	,SUM(MCI) as Num_Emergency_Admissions_MCI
	,null as [Primary Diagnosis Chapter]
FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Dementia_SUS_Dashboard_APCE] a
where Der_Admission=1
Group by 
Admission_Month
,Region_Name_Commissioner
,[ICB Name]
,Admission_Source
---------------------------------ICB, Discharge Destination------------------------------------------------------------------------
INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Dementia_SUS_Dashboard_Unsuppressed]
SELECT 
	Discharge_Month AS [Month]
	,'ICB' AS GroupType
	,Region_Name_Commissioner AS RegionCode
	,[ICB Name] AS GeographyName
	,'Discharge Destination' AS Category
	,Discharge_Destination AS Variable
	,COUNT(*) as Num_Emergency_Admissions
	,SUM(CASE WHEN Age_on_Admission >= 65 THEN 1 ELSE 0 END) as Num_Emergency_Admissions_65andOver
	,SUM(Dementia) as Num_Emergency_Admissions_Dementia
	,SUM(Delirium) as Num_Emergency_Admissions_Delirium
	,SUM(MCI) as Num_Emergency_Admissions_MCI
	,null as [Primary Diagnosis Chapter]
FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Dementia_SUS_Dashboard_APCE] a
where Der_Discharge=1
Group by 
Discharge_Month
,Region_Name_Commissioner
,[ICB Name]
,Discharge_Destination
-------------------------------ICB, Length of Stay--------------------------------------------------------------------------------------
INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Dementia_SUS_Dashboard_Unsuppressed]
SELECT 
	Admission_Month as [Month]
	,'ICB' AS GroupType
	,Region_Name_Commissioner AS RegionCode
	,[ICB Name] AS GeographyName
	,'Length of Stay' AS Category
	,LengthOfStay AS Variable
	,COUNT(*) as Num_Emergency_Admissions
	,SUM(CASE WHEN Age_At_Start_of_Spell_SUS >= 65 THEN 1 ELSE 0 END) as Num_Emergency_Admissions_65andOver
	,SUM(Dementia) as Num_Emergency_Admissions_Dementia
	,SUM(Delirium) as Num_Emergency_Admissions_Delirium
	,SUM(MCI) as Num_Emergency_Admissions_MCI
	,null as [Primary Diagnosis Chapter]
FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Dementia_SUS_Dashboard_APCS] a
Group by 
Admission_Month
,Region_Name_Commissioner
,[ICB Name]
,LengthOfStay
---------------------------------ICB, Total-------------------------------------------------------------------------------
INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Dementia_SUS_Dashboard_Unsuppressed]
SELECT 
	Admission_Month AS [Month]
	,'ICB' AS GroupType
	,Region_Name_Commissioner AS RegionCode
	,[ICB Name] AS GeographyName
	,'Total' AS Category
	,'Total' AS Variable
	,COUNT(*) as Num_Emergency_Admissions
	,SUM(CASE WHEN Age_on_Admission >= 65 THEN 1 ELSE 0 END) as Num_Emergency_Admissions_65andOver
	,SUM(Dementia) as Num_Emergency_Admissions_Dementia
	,SUM(Delirium) as Num_Emergency_Admissions_Delirium
	,SUM(MCI) as Num_Emergency_Admissions_MCI
	,null as [Primary Diagnosis Chapter]
FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Dementia_SUS_Dashboard_APCE] a
where Der_Admission=1
Group by 
Admission_Month
,Region_Name_Commissioner
,[ICB Name]
---------------------------------ICB, Primary Diagnosis-------------------------------------------------------------------------------------
INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Dementia_SUS_Dashboard_Unsuppressed]
SELECT 
	Admission_Month AS [Month]
	,'ICB' AS GroupType
	,[Region_Name_Commissioner] AS RegionCode
	,[ICB Name] AS GeographyName
	,'Primary Diagnosis' AS Category
	,[Primary Diagnosis] AS Variable
	,COUNT(*) as Num_Emergency_Admissions
	,SUM(CASE WHEN Age_on_Admission >= 65 THEN 1 ELSE 0 END) as Num_Emergency_Admissions_65andOver
	,SUM(Dementia) as Num_Emergency_Admissions_Dementia
	,SUM(Delirium) as Num_Emergency_Admissions_Delirium
	,SUM(MCI) as Num_Emergency_Admissions_MCI
	,[Primary Diagnosis Chapter]
FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Dementia_SUS_Dashboard_APCE] a
where Der_Admission=1
Group by 
Admission_Month
,Region_Name_Commissioner
,[ICB Name]
,[Primary Diagnosis]
,[Primary Diagnosis Chapter]
---------------------------------Sub ICB, Gender------------------------------------------------------------------------------------------------------
INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Dementia_SUS_Dashboard_Unsuppressed]
SELECT 
	Admission_Month AS [Month]
	,'Sub ICB' AS GroupType
	,Region_Name_Commissioner AS RegionCode
	,[Sub ICB Name] AS GeographyName
	,'Gender' AS Category
	,Gender AS Variable
	,COUNT(*) as Num_Emergency_Admissions
	,SUM(CASE WHEN Age_on_Admission >= 65 THEN 1 ELSE 0 END) as Num_Emergency_Admissions_65andOver
	,SUM(Dementia) as Num_Emergency_Admissions_Dementia
	,SUM(Delirium) as Num_Emergency_Admissions_Delirium
	,SUM(MCI) as Num_Emergency_Admissions_MCI
	,null as [Primary Diagnosis Chapter]
FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Dementia_SUS_Dashboard_APCE] a
where Der_Admission=1
Group by 
Admission_Month
,Region_Name_Commissioner
,[Sub ICB Name]
,Gender
---------------------------------Sub ICB, Ethnicity---------------------------------------------------------------------------
INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Dementia_SUS_Dashboard_Unsuppressed]
SELECT 
	Admission_Month AS [Month]
	,'Sub ICB' AS GroupType
	,Region_Name_Commissioner AS RegionCode
	,[Sub ICB Name] AS GeographyName
	,'Ethnicity' AS Category
	,Ethnicity AS Variable
	,COUNT(*) as Num_Emergency_Admissions
	,SUM(CASE WHEN Age_on_Admission >= 65 THEN 1 ELSE 0 END) as Num_Emergency_Admissions_65andOver
	,SUM(Dementia) as Num_Emergency_Admissions_Dementia
	,SUM(Delirium) as Num_Emergency_Admissions_Delirium
	,SUM(MCI) as Num_Emergency_Admissions_MCI
	,null as [Primary Diagnosis Chapter]
FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Dementia_SUS_Dashboard_APCE] a
where Der_Admission=1
Group by 
Admission_Month
,Region_Name_Commissioner
,[Sub ICB Name]
,Ethnicity
---------------------------------Sub ICB, Admission Source------------------------------------------------------------------------------------------
INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Dementia_SUS_Dashboard_Unsuppressed]
SELECT 
	Admission_Month AS [Month]
	,'Sub ICB' AS GroupType
	,Region_Name_Commissioner AS RegionCode
	,[Sub ICB Name] AS GeographyName
	,'Admission Source' AS Category
	,Admission_Source AS Variable
	,COUNT(*) as Num_Emergency_Admissions
	,SUM(CASE WHEN Age_on_Admission >= 65 THEN 1 ELSE 0 END) as Num_Emergency_Admissions_65andOver
	,SUM(Dementia) as Num_Emergency_Admissions_Dementia
	,SUM(Delirium) as Num_Emergency_Admissions_Delirium
	,SUM(MCI) as Num_Emergency_Admissions_MCI
	,null as [Primary Diagnosis Chapter]
FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Dementia_SUS_Dashboard_APCE] a
where Der_Admission=1
Group by 
Admission_Month
,Region_Name_Commissioner
,[Sub ICB Name]
,Admission_Source
---------------------------------Sub ICB, Discharge Destination------------------------------------------------------------------------
INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Dementia_SUS_Dashboard_Unsuppressed]
SELECT 
	Discharge_Month AS [Month]
	,'Sub ICB' AS GroupType
	,Region_Name_Commissioner AS RegionCode
	,[Sub ICB Name] AS GeographyName
	,'Discharge Destination' AS Category
	,Discharge_Destination AS Variable
	,COUNT(*) as Num_Emergency_Admissions
	,SUM(CASE WHEN Age_on_Admission >= 65 THEN 1 ELSE 0 END) as Num_Emergency_Admissions_65andOver
	,SUM(Dementia) as Num_Emergency_Admissions_Dementia
	,SUM(Delirium) as Num_Emergency_Admissions_Delirium
	,SUM(MCI) as Num_Emergency_Admissions_MCI
	,null as [Primary Diagnosis Chapter]
FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Dementia_SUS_Dashboard_APCE] a
where Der_Discharge=1
Group by 
Discharge_Month
,Region_Name_Commissioner
,[Sub ICB Name]
,Discharge_Destination
-------------------------------Sub ICB, Length of Stay--------------------------------------------------------------------------------------
INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Dementia_SUS_Dashboard_Unsuppressed]
SELECT 
	Admission_Month as [Month]
	,'Sub ICB' AS GroupType
	,Region_Name_Commissioner AS RegionCode
	,[Sub ICB Name] AS GeographyName
	,'Length of Stay' AS Category
	,LengthOfStay AS Variable
	,COUNT(*) as Num_Emergency_Admissions
	,SUM(CASE WHEN Age_At_Start_of_Spell_SUS >= 65 THEN 1 ELSE 0 END) as Num_Emergency_Admissions_65andOver
	,SUM(Dementia) as Num_Emergency_Admissions_Dementia
	,SUM(Delirium) as Num_Emergency_Admissions_Delirium
	,SUM(MCI) as Num_Emergency_Admissions_MCI
	,null as [Primary Diagnosis Chapter]
FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Dementia_SUS_Dashboard_APCS] a
Group by 
Admission_Month
,Region_Name_Commissioner
,[Sub ICB Name]
,LengthOfStay
---------------------------------Sub ICB, Total-------------------------------------------------------------------------------
INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Dementia_SUS_Dashboard_Unsuppressed]
SELECT 
	Admission_Month AS [Month]
	,'Sub ICB' AS GroupType
	,Region_Name_Commissioner AS RegionCode
	,[Sub ICB Name] AS GeographyName
	,'Total' AS Category
	,'Total' AS Variable
	,COUNT(*) as Num_Emergency_Admissions
	,SUM(CASE WHEN Age_on_Admission >= 65 THEN 1 ELSE 0 END) as Num_Emergency_Admissions_65andOver
	,SUM(Dementia) as Num_Emergency_Admissions_Dementia
	,SUM(Delirium) as Num_Emergency_Admissions_Delirium
	,SUM(MCI) as Num_Emergency_Admissions_MCI
	,null as [Primary Diagnosis Chapter]
FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Dementia_SUS_Dashboard_APCE] a
where Der_Admission=1
Group by 
Admission_Month
,Region_Name_Commissioner
,[Sub ICB Name]
---------------------------------Sub ICB, Primary Diagnosis -------------------------------------------------------------------------------------
INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Dementia_SUS_Dashboard_Unsuppressed]
SELECT 
	Admission_Month AS [Month]
	,'Sub ICB' AS GroupType
	,[Region_Name_Commissioner] AS RegionCode
	,[Sub ICB Name] AS GeographyName
	,'Primary Diagnosis' AS Category
	,[Primary Diagnosis] AS Variable
	,COUNT(*) as Num_Emergency_Admissions
	,SUM(CASE WHEN Age_on_Admission >= 65 THEN 1 ELSE 0 END) as Num_Emergency_Admissions_65andOver
	,SUM(Dementia) as Num_Emergency_Admissions_Dementia
	,SUM(Delirium) as Num_Emergency_Admissions_Delirium
	,SUM(MCI) as Num_Emergency_Admissions_MCI
	,[Primary Diagnosis Chapter]
FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Dementia_SUS_Dashboard_APCE] a
where Der_Admission=1
Group by 
Admission_Month
,Region_Name_Commissioner
,[Sub ICB Name]
,[Primary Diagnosis]
,[Primary Diagnosis Chapter]
---------------------------------Provider, Gender------------------------------------------------------------------------------------------------------
INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Dementia_SUS_Dashboard_Unsuppressed]
SELECT 
	Admission_Month AS [Month]
	,'Provider' AS GroupType
	,[Region_Name_Provider] AS RegionCode
	,[Provider Name] AS GeographyName
	,'Gender'AS Category
	,Gender AS Variable
	,COUNT(*) as Num_Emergency_Admissions
	,SUM(CASE WHEN Age_on_Admission >= 65 THEN 1 ELSE 0 END) as Num_Emergency_Admissions_65andOver
	,SUM(Dementia) as Num_Emergency_Admissions_Dementia
	,SUM(Delirium) as Num_Emergency_Admissions_Delirium
	,SUM(MCI) as Num_Emergency_Admissions_MCI
	,null as [Primary Diagnosis Chapter]
FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Dementia_SUS_Dashboard_APCE] a
where Der_Admission=1
Group by 
Admission_Month
,Region_Name_Provider
,[Provider Name]
,Gender
---------------------------------Provider, Ethnicity---------------------------------------------------------------------------
INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Dementia_SUS_Dashboard_Unsuppressed]
SELECT 
	Admission_Month AS [Month]
	,'Provider' AS GroupType
	,[Region_Name_Provider] AS RegionCode
	,[Provider Name] AS GeographyName
	,'Ethnicity'AS Category
	,Ethnicity AS Variable
	,COUNT(*) as Num_Emergency_Admissions
	,SUM(CASE WHEN Age_on_Admission >= 65 THEN 1 ELSE 0 END) as Num_Emergency_Admissions_65andOver
	,SUM(Dementia) as Num_Emergency_Admissions_Dementia
	,SUM(Delirium) as Num_Emergency_Admissions_Delirium
	,SUM(MCI) as Num_Emergency_Admissions_MCI
	,null as [Primary Diagnosis Chapter]
FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Dementia_SUS_Dashboard_APCE] a
where Der_Admission=1
Group by 
Admission_Month
,Region_Name_Provider
,[Provider Name]
,Ethnicity
---------------------------------Provider, Admission Source------------------------------------------------------------------------------------------
INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Dementia_SUS_Dashboard_Unsuppressed]
SELECT 
	Admission_Month AS [Month]
	,'Provider' AS GroupType
	,[Region_Name_Provider] AS RegionCode
	,[Provider Name] AS GeographyName
	,'Admission Source'AS Category
	,[Admission_Source] AS Variable
	,COUNT(*) as Num_Emergency_Admissions
	,SUM(CASE WHEN Age_on_Admission >= 65 THEN 1 ELSE 0 END) as Num_Emergency_Admissions_65andOver
	,SUM(Dementia) as Num_Emergency_Admissions_Dementia
	,SUM(Delirium) as Num_Emergency_Admissions_Delirium
	,SUM(MCI) as Num_Emergency_Admissions_MCI
	,null as [Primary Diagnosis Chapter]
FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Dementia_SUS_Dashboard_APCE] a
where Der_Admission=1
Group by 
Admission_Month
,Region_Name_Provider
,[Provider Name]
,Admission_Source
---------------------------------Provider, Discharge Destination------------------------------------------------------------------------
INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Dementia_SUS_Dashboard_Unsuppressed]
SELECT 
	Discharge_Month AS [Month]
	,'Provider' AS GroupType
	,Region_Name_Provider AS RegionCode
	,[Provider Name] AS GeographyName
	,'Discharge Destination' AS Category
	,Discharge_Destination AS Variable
	,COUNT(*) as Num_Emergency_Admissions
	,SUM(CASE WHEN Age_on_Admission >= 65 THEN 1 ELSE 0 END) as Num_Emergency_Admissions_65andOver
	,SUM(Dementia) as Num_Emergency_Admissions_Dementia
	,SUM(Delirium) as Num_Emergency_Admissions_Delirium
	,SUM(MCI) as Num_Emergency_Admissions_MCI
	,null as [Primary Diagnosis Chapter]
FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Dementia_SUS_Dashboard_APCE] a
where Der_Discharge=1
Group by 
Discharge_Month
,Region_Name_Provider
,[Provider Name]
,Discharge_Destination
-------------------------------Provider, Length of Stay--------------------------------------------------------------------------------------
INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Dementia_SUS_Dashboard_Unsuppressed]
SELECT 
	Admission_Month as [Month]
	,'Provider' AS GroupType
	,Region_Name_Provider AS RegionCode
	,[Provider Name] AS GeographyName
	,'Length of Stay'AS Category
	,LengthOfStay AS Variable
	,COUNT(*) as Num_Emergency_Admissions
	,SUM(CASE WHEN Age_At_Start_of_Spell_SUS >= 65 THEN 1 ELSE 0 END) as Num_Emergency_Admissions_65andOver
	,SUM(Dementia) as Num_Emergency_Admissions_Dementia
	,SUM(Delirium) as Num_Emergency_Admissions_Delirium
	,SUM(MCI) as Num_Emergency_Admissions_MCI
	,null as [Primary Diagnosis Chapter]
FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Dementia_SUS_Dashboard_APCS] a
Group by 
Admission_Month
,Region_Name_Provider
,[Provider Name]
,LengthOfStay
---------------------------------Provider, Total-------------------------------------------------------------------------------
INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Dementia_SUS_Dashboard_Unsuppressed]
SELECT 
	Admission_Month AS [Month]
	,'Provider' AS GroupType
	,[Region_Name_Provider] AS RegionCode
	,[Provider Name] AS GeographyName
	,'Total'AS Category
	,'Total' AS Variable
	,COUNT(*) as Num_Emergency_Admissions
	,SUM(CASE WHEN Age_on_Admission >= 65 THEN 1 ELSE 0 END) as Num_Emergency_Admissions_65andOver
	,SUM(Dementia) as Num_Emergency_Admissions_Dementia
	,SUM(Delirium) as Num_Emergency_Admissions_Delirium
	,SUM(MCI) as Num_Emergency_Admissions_MCI
	,null as [Primary Diagnosis Chapter]
FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Dementia_SUS_Dashboard_APCE] a
where Der_Admission=1
Group by 
Admission_Month
,Region_Name_Provider
,[Provider Name]
---------------------------------Provider, Primary Diagnosis-------------------------------------------------------------------------------------
INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Dementia_SUS_Dashboard_Unsuppressed]
SELECT 
	Admission_Month AS [Month]
	,'Provider' AS GroupType
	,[Region_Name_Provider] AS RegionCode
	,[Provider Name] AS GeographyName
	,'Primary Diagnosis'AS Category
	,[Primary Diagnosis] AS Variable
	,COUNT(*) as Num_Emergency_Admissions
	,SUM(CASE WHEN Age_on_Admission >= 65 THEN 1 ELSE 0 END) as Num_Emergency_Admissions_65andOver
	,SUM(Dementia) as Num_Emergency_Admissions_Dementia
	,SUM(Delirium) as Num_Emergency_Admissions_Delirium
	,SUM(MCI) as Num_Emergency_Admissions_MCI
	,[Primary Diagnosis Chapter]
FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Dementia_SUS_Dashboard_APCE] a
where Der_Admission=1
Group by 
Admission_Month
,Region_Name_Provider
,[Provider Name]
,[Primary Diagnosis]
,[Primary Diagnosis Chapter]
--------------------------------------------------------------------------------------------------------------------
---------------------------------Suppressed, Output Table------------------------------------------------
--IF OBJECT_ID ('[NHSE_Sandbox_MentalHealth].[dbo].[Dementia_Dashboard_SUS_Dec_Update]') IS NOT NULL DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].[Dementia_Dashboard_SUS_Dec_Update]
INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dementia_Dashboard_SUS_v2]
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
--INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dementia_Dashboard_SUS_Dec_Update]
FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Dementia_SUS_Dashboard_Unsuppressed]

---------------------------------Drop temporary tables
--DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Dementia_SUS_Dashboard_APCE]
--DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Dementia_SUS_Dashboard_APCS]
--DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_Dementia_SUS_Dashboard_Unsuppressed]


