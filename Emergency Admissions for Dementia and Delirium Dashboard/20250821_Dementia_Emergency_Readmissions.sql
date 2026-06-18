/* - Emergency Admissions for Dementia and Delirium Dashboard -------------------------------------------------
   - Emergency Readmissions script ------------------------------------------------------------------------- */
 
-- Step 1 -----------------------------------------------------------------------------------------------------------------------------------
/* 

-- Current values covering the last 11 months are deleted from the dashboard table and added to an old refresh table to keep as a record. 
-- The old refresh data will be removed after one year (i.e. once it is no longer refreshed).

-- @delete_period_start is the beginning of the month 11 months prior to the latest month in the dashboard extract (to include the last 12 months in the refresh)
-- @delete_period_end is the end of the latest month in last month's dashboard extract 

*/ ---------------------------------------------------------------------------------------------------------------------------

DECLARE @delete_period_end DATE = (SELECT EOMONTH(MAX([Month])) FROM [MHDInternal].[DASHBOARD_DEM_SUS_Emergency_Readmissions_New])
DECLARE @delete_period_start DATE = (SELECT DATEADD(DAY,1,EOMONTH(DATEADD(MONTH,-11,@delete_period_end))))

PRINT CHAR(13) + 'Delete values between ' + CAST(@delete_period_start AS VARCHAR(10)) + ' and ' + CAST(@delete_period_end AS VARCHAR(10)) 
----------------------------------------------------------------------------------------------------------------------------------------------------------

DELETE [MHDInternal].[DASHBOARD_DEM_SUS_Emergency_Readmissions_New]

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

; -- End of Step 1 -------------------------------------------------------------------------------------------------------------

-- Step 2---------------------------------------------------------------------------------------------------------------------

-- Creates a table for the unsuppressed readmissions needed later

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
DECLARE @Max_Offset INT = +1 -- @Max_Offset should always be +1 to refresh 12 months worth of data

DECLARE @StartDate DATE = (SELECT DATEADD(MONTH,1,MAX([Month])) FROM [MHDInternal].[DASHBOARD_DEM_SUS_Emergency_Readmissions_New]) 
DECLARE @EndDate DATE = (SELECT EOMONTH(@StartDate)) 

DECLARE @CurrentMonthEnd DATE = EOMONTH(@StartDate)

------------------------------------------------------------------------------------------------------------------------------------------------
---- Start loop --------------------------------------------------------------------------------------------------------------------------------

WHILE (@Offset > @Max_Offset) BEGIN

-- Latest Admission Time Frame
-- This defines the time period for readmissions i.e. an admission following a discharge in the previous discharge time frame, defined below.

DECLARE @admissions_period_end DATE = @CurrentMonthEnd 
DECLARE @admissions_period_start DATE = DATEADD(DAY,1,EOMONTH(DATEADD(MONTH,-1,@admissions_period_end)))

-- Previous Discharge Time Frame (90 days prior to the latest admission time frame)
-- This defines the time period for discharges that may result in a readmission in the latest admission time frame, defined above.

DECLARE @discharges_period_start DATE = (SELECT DATEADD(DAY,-90,@admissions_period_start))
DECLARE @discharges_period_end DATE = (SELECT DATEADD(DAY,-1,@admissions_period_start))

PRINT CHAR(13)
PRINT 'Admission Time Frame: ' + CAST(@admissions_period_start AS VARCHAR) + ' - ' + CAST(@admissions_period_end AS VARCHAR)
PRINT 'Discharge Time Frame: ' + CAST(@discharges_period_start AS VARCHAR) + ' - ' + CAST(@discharges_period_end AS VARCHAR)

-------------------Previous Discharge Table----------------------------------

-- Record level table for discharges in the previous discharge time frame

IF OBJECT_ID ('[MHDInternal].[TEMP_DEM_SUS_Previous_Discharge]') IS NOT NULL 
DROP TABLE [MHDInternal].[TEMP_DEM_SUS_Previous_Discharge]

SELECT 
	[Der_Pseudo_NHS_Number]
	,CAST([Admission_Date] AS DATE) AS [Admission_Date] 
	,CAST([Discharge_Date] AS DATE) AS [Discharge_Date]
	,[Provider_Code]
	,Der_Commissioner_Code AS Commissioner_Code 
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

FROM [Reporting_MESH_APC].[APCS_Core_Monthly_Snapshot] a

WHERE 
	Admission_Method LIKE '2%'	-- emergency admissions only
	AND CAST(Discharge_Date AS DATE) BETWEEN @discharges_period_start AND @discharges_period_end -- discharges in the previous admission time frame
	AND [Der_Pseudo_NHS_Number] IS NOT NULL
	AND [Patient_Classification] = 1 -- ordinary admission



------------------------------Latest Admission Table-------------------------------------

-- Record level table for admissions in the latest admission time frame but only for those records which have a discharge in the previous time frame table above

IF OBJECT_ID ('[MHDInternal].[TEMP_DEM_SUS_Latest_Admission]') IS NOT NULL 
DROP TABLE [MHDInternal].[TEMP_DEM_SUS_Latest_Admission]

SELECT 
	
	a.[Der_Pseudo_NHS_Number]
	,CAST(a.[Admission_Date] AS DATE) AS [Admission_Date]
	,CAST(a.[Discharge_Date] AS DATE) AS [Discharge_Date] 
	,CASE WHEN ph.[Organisation_Code] IS NOT NULL THEN ph.[Organisation_Code] ELSE 'Other' END AS [Provider_Code]
	,CASE WHEN ph.[Organisation_Name] IS NOT NULL THEN ph.[Organisation_Name] ELSE 'Other' END AS [Provider Name]
	,CASE WHEN ph.[Region_Name] IS NOT NULL THEN ph.[Region_Name] ELSE 'Other' END AS [Provider Region Name]
	,CASE WHEN c.[Organisation_Code] IS NOT NULL THEN c.[Organisation_Code] ELSE 'Other' END AS [Sub ICB Code]
	,CASE WHEN c.[Organisation_Name] IS NOT NULL THEN c.[Organisation_Name] ELSE 'Other' END AS [Sub ICB Name]
	,CASE WHEN c.[STP_Code] IS NOT NULL THEN c.[STP_Code] ELSE 'Other' END AS [ICB Code]
	,CASE WHEN c.[STP_Name] IS NOT NULL THEN c.[STP_Name] ELSE 'Other' END AS [ICB Name]
	,CASE WHEN c.[Region_Name] IS NOT NULL THEN c.[Region_Name] ELSE 'Other' END AS [Commissioner Region Name]
	,CASE WHEN c.[Region_Code] IS NOT NULL THEN c.[Region_Code] ELSE 'Other' END AS [Region_Code_Commissioner]
	,ROW_NUMBER() OVER(PARTITION BY a.[Der_Pseudo_NHS_Number] ORDER BY a.[Admission_Date] ASC) AS [AdmissionOrder]	--orders admission dates so the earliest admission date has a value of 1
	,a.[Commissioner_Code]

INTO [MHDInternal].[TEMP_DEM_SUS_Latest_Admission]

FROM 
	[Reporting_MESH_APC].[APCS_Core_Monthly_Snapshot] a
	--Inner join to the previous admission table means only records with a discharge in the previous admission table will be included in this table
	INNER JOIN [MHDInternal].[TEMP_DEM_SUS_Previous_Discharge] b ON a.[Der_Pseudo_NHS_Number] = b.[Der_Pseudo_NHS_Number]
	--------------------------------------------------------------
	LEFT JOIN Internal_Reference.ComCodeChanges cc ON a.Der_Commissioner_Code = cc.Org_Code 
	LEFT JOIN Internal_Hierarchies.Commissioner_Hierarchies_TCUBE c ON COALESCE(cc.New_Code, a.Der_Commissioner_Code) = c.Organisation_Code AND c.Organisation_Name NOT LIKE '%REPORTING ENTITY%' AND c.STP_Name <> 'NonSTP (Wales Region)'
	--------------------------------------------------------------
	LEFT JOIN [Internal_Reference].[Provider_Successor] ps ON  ps.Prov_original = a.Der_Provider_Code
	LEFT JOIN Internal_Hierarchies.Provider_Hierarchies_TCUBE ph ON ph.Organisation_Code =  COALESCE(ps.Prov_successor, a.Der_Provider_Code) AND ph.[Effective_To] IS NULL

WHERE 
	(a.[Admission_Method] LIKE '2%') -- emergency admissions only
	AND CAST(a.[Admission_Date] AS DATE) BETWEEN @admissions_period_start AND @admissions_period_end -- discharges in the latest admission time frame
	AND (a.[Patient_Classification] = 1) -- ordinary admission

-- Readmissions Base Table -----------------------------------------------------------------------------------------------------------------

-- Base table (record level values that can be aggregated later) which combines the previous admission and latest admission table. 

IF OBJECT_ID ('[MHDInternal].[TEMP_DEM_SUS_Readmission_Base]') IS NOT NULL 
DROP TABLE [MHDInternal].[TEMP_DEM_SUS_Readmission_Base]


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
	,b.Region_Code_Commissioner 
	,b.[Provider Region Name]
	,b.[Sub ICB Name]
	,b.[Sub ICB Code]
	,b.[Provider Name]
	,b.Provider_Code
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

--- Aggregate to old subICB level first 
IF OBJECT_ID ('[MHDInternal].[Temp_SUS_Readmissions_AggSICB]') IS NOT NULL 
DROP TABLE [MHDInternal].Temp_SUS_Readmissions_AggSICB

SELECT 
	b.[Month]
	,b.[Sub ICB Code]
	,b.[Sub ICB Name]
	,ISNULL(r.SubICB26_Code,'Other') AS SubICB26_Code
	,ISNULL(r.SubICB26_Name,'Other') AS SubICB26_Name
	,ISNULL(r.ICB_Code,'Other') AS ICB_Code
	,ISNULL(r.ICB_Name,'Other') AS ICB_Name
	,ISNULL(r.Region_Code,'Other') AS Region_Code
	,ISNULL(r.Region_Name,'Other') AS Region_Name
	,ISNULL(r.PopWeight,1) AS PopWeight
	-- Totals 
	,SUM (CASE WHEN [TimeBetweenAdmissions] <= 30 THEN 1 END)*ISNULL(r.PopWeight,1) AS [Total - Readmissions30days]
	,SUM (CASE WHEN [TimeBetweenAdmissions] BETWEEN 31 AND 60 THEN 1 END)*ISNULL(r.PopWeight,1) AS [Total - Readmissions60days]
	,SUM (CASE WHEN [TimeBetweenAdmissions] BETWEEN 61 AND 90 THEN 1 END)*ISNULL(r.PopWeight,1) AS [Total - Readmissions90days]
	-- Dementia 
	,SUM (CASE WHEN [TimeBetweenAdmissions] <= 30 THEN Dementia END)*ISNULL(r.PopWeight,1) AS [Dem - Readmissions30days]
	,SUM (CASE WHEN [TimeBetweenAdmissions] BETWEEN 31 AND 60 THEN Dementia END)*ISNULL(r.PopWeight,1) AS [Dem - Readmissions60days]
	,SUM (CASE WHEN [TimeBetweenAdmissions] BETWEEN 61 AND 90 THEN Dementia END)*ISNULL(r.PopWeight,1) AS [Dem - Readmissions90days]
	-- MCI 
	,SUM (CASE WHEN [TimeBetweenAdmissions] <= 30 THEN MCI END)*ISNULL(r.PopWeight,1) AS [MCI - Readmissions30days]
	,SUM (CASE WHEN [TimeBetweenAdmissions] BETWEEN 31 AND 60 THEN MCI END)*ISNULL(r.PopWeight,1) AS [MCI - Readmissions60days]
	,SUM (CASE WHEN [TimeBetweenAdmissions] BETWEEN 61 AND 90 THEN MCI END)*ISNULL(r.PopWeight,1) AS [MCI - Readmissions90days]
	-- Delirium 
	,SUM (CASE WHEN [TimeBetweenAdmissions] <= 30 THEN Delirium END)*ISNULL(r.PopWeight,1) AS [Delirium - Readmissions30days]
	,SUM (CASE WHEN [TimeBetweenAdmissions] BETWEEN 31 AND 60 THEN Delirium END)*ISNULL(r.PopWeight,1) AS [Delirium - Readmissions60days]
	,SUM (CASE WHEN [TimeBetweenAdmissions] BETWEEN 61 AND 90 THEN Delirium END)*ISNULL(r.PopWeight,1) AS [Delirium - Readmissions90days]
	-- Over 65 
	,SUM (CASE WHEN [TimeBetweenAdmissions] <= 30 THEN Age65 END)*ISNULL(r.PopWeight,1) AS [Age65 - Readmissions30days]
	,SUM (CASE WHEN [TimeBetweenAdmissions] BETWEEN 31 AND 60 THEN Age65 END)*ISNULL(r.PopWeight,1) AS [Age65 - Readmissions60days]
	,SUM (CASE WHEN [TimeBetweenAdmissions] BETWEEN 61 AND 90 THEN Age65 END)*ISNULL(r.PopWeight,1) AS [Age65 - Readmissions90days]

INTO [MHDInternal].Temp_SUS_Readmissions_AggSICB
	
FROM [MHDInternal].[TEMP_DEM_SUS_Readmission_Base] b 

LEFT JOIN #SICB_Reference r ON b.[Sub ICB Code]= r.SubICB_Code

GROUP BY b.[Month]
	,b.[Sub ICB Code]
	,b.[Sub ICB Name]
	,ISNULL(r.SubICB26_Code,'Other') 
	,ISNULL(r.SubICB26_Name,'Other') 
	,ISNULL(r.ICB_Code,'Other')
	,ISNULL(r.ICB_Name,'Other') 
	,ISNULL(r.Region_Code,'Other') 
	,ISNULL(r.Region_Name,'Other') 
	,ISNULL(r.PopWeight,1) 
 
 --- Aggregate to proper subICB and ICBs 
IF OBJECT_ID ('[MHDInternal].[TEMP_DEM_SUS_Readmissions_Unsuppressed_Wide]') IS NOT NULL 
DROP TABLE [MHDInternal].[TEMP_DEM_SUS_Readmissions_Unsuppressed_Wide] 

 SELECT 
	[Month] 
	,CASE 
		WHEN GROUPING([SubICB26_Code])=0 THEN CAST('Sub ICB' AS VARCHAR(MAX))
		WHEN GROUPING(ICB_Code) = 0 THEN CAST('ICB' AS VARCHAR(MAX)) 
	END AS [Org_Type]
	,CASE 
		WHEN GROUPING([SubICB26_Code])=0 THEN SubICB26_Name
		WHEN GROUPING(ICB_Code) = 0 THEN ICB_Name
	END AS [Organisation_Name]
	,Region_Name AS [Region Name]
	,SUM([Total - Readmissions30days]) AS [Total - Readmissions30days]
	,SUM([Total - Readmissions60days]) AS [Total - Readmissions60days]
	,SUM([Total - Readmissions90days]) AS [Total - Readmissions90days]
	,SUM([Dem - Readmissions30days]) AS [Dem - Readmissions30days]
	,SUM([Dem - Readmissions60days]) AS [Dem - Readmissions60days]
	,SUM([Dem - Readmissions90days]) AS [Dem - Readmissions90days]
	,SUM([MCI - Readmissions30days]) AS [MCI - Readmissions30days]
	,SUM([MCI - Readmissions60days]) AS [MCI - Readmissions60days]
	,SUM([MCI - Readmissions90days]) AS [MCI - Readmissions90days]
	,SUM([Delirium - Readmissions30days]) AS [Delirium - Readmissions30days]
	,SUM([Delirium - Readmissions60days]) AS [Delirium - Readmissions60days]
	,SUM([Delirium - Readmissions90days]) AS [Delirium - Readmissions90days]
	,SUM([Age65 - Readmissions30days]) AS [Age65 - Readmissions30days]
	,SUM([Age65 - Readmissions60days]) AS [Age65 - Readmissions60days]
	,SUM([Age65 - Readmissions90days]) AS [Age65 - Readmissions90days]

INTO [MHDInternal].[TEMP_DEM_SUS_Readmissions_Unsuppressed_Wide] 

 FROM [MHDInternal].Temp_SUS_Readmissions_AggSICB a 

 GROUP BY GROUPING SETS (
	([Month], [SubICB26_Code], SubICB26_Name ,Region_Code, Region_Name), -- sub ICBs 
	([Month], ICB_Code, ICB_Name ,Region_Code, Region_Name)
	) 

-- Aggregate provider and England 
INSERT INTO [MHDInternal].[TEMP_DEM_SUS_Readmissions_Unsuppressed_Wide] 

SELECT 
	b.[Month]
	,CASE 
		WHEN GROUPING(Provider_Code)=0 THEN 'Provider'
	ELSE 'National' 
	END AS Org_Type 
	,CASE 
		WHEN GROUPING(Provider_Code)=0 THEN [Provider Name]
	ELSE 'England' 
	END AS Organisation_Name 
	,CASE 
		WHEN GROUPING(Provider_Code)=0 THEN [Provider Region Name]
	ELSE 'All Regions' 
	END AS [Region Name] 
	-- Totals 
	,SUM (CASE WHEN [TimeBetweenAdmissions] <= 30 THEN 1 ELSE 0 END) AS [Total - Readmissions30days]
	,SUM (CASE WHEN [TimeBetweenAdmissions] BETWEEN 31 AND 60 THEN 1 ELSE 0 END) AS [Total - Readmissions60days]
	,SUM (CASE WHEN [TimeBetweenAdmissions] BETWEEN 61 AND 90 THEN 1 ELSE 0 END) AS [Total - Readmissions90days]
	-- Dementia 
	,SUM (CASE WHEN [TimeBetweenAdmissions] <= 30 THEN Dementia ELSE 0 END) AS [Dem - Readmissions30days]
	,SUM (CASE WHEN [TimeBetweenAdmissions] BETWEEN 31 AND 60 THEN Dementia ELSE 0 END) AS [Dem - Readmissions60days]
	,SUM (CASE WHEN [TimeBetweenAdmissions] BETWEEN 61 AND 90 THEN Dementia ELSE 0 END) AS [Dem - Readmissions90days]
	-- MCI 
	,SUM (CASE WHEN [TimeBetweenAdmissions] <= 30 THEN MCI ELSE 0 END) AS [MCI - Readmissions30days]
	,SUM (CASE WHEN [TimeBetweenAdmissions] BETWEEN 31 AND 60 THEN MCI ELSE 0 END) AS [MCI - Readmissions60days]
	,SUM (CASE WHEN [TimeBetweenAdmissions] BETWEEN 61 AND 90 THEN MCI ELSE 0 END) AS [MCI - Readmissions90days]
	-- Delirium 
	,SUM (CASE WHEN [TimeBetweenAdmissions] <= 30 THEN Delirium ELSE 0 END) AS [Delirium - Readmissions30days]
	,SUM (CASE WHEN [TimeBetweenAdmissions] BETWEEN 31 AND 60 THEN Delirium ELSE 0 END) AS [Delirium - Readmissions60days]
	,SUM (CASE WHEN [TimeBetweenAdmissions] BETWEEN 61 AND 90 THEN Delirium ELSE 0 END) AS [Delirium - Readmissions90days]
	-- Over 65 
	,SUM (CASE WHEN [TimeBetweenAdmissions] <= 30 THEN Age65 ELSE 0 END) AS [Age65 - Readmissions30days]
	,SUM (CASE WHEN [TimeBetweenAdmissions] BETWEEN 31 AND 60 THEN Age65 ELSE 0 END) AS [Age65 - Readmissions60days]
	,SUM (CASE WHEN [TimeBetweenAdmissions] BETWEEN 61 AND 90 THEN Age65 ELSE 0 END) AS [Age65 - Readmissions90days]
	
FROM [MHDInternal].[TEMP_DEM_SUS_Readmission_Base] b 

GROUP BY GROUPING SETS ( 
	([Month]), -- England 
	([Month], Provider_Code, [Provider Name], [Provider Region Name]) -- Provider 
	)

--- Unpivot to long format 
IF OBJECT_ID ('[MHDInternal].[TEMP_DEM_SUS_Readmissions_Unsuppressed_Long]') IS NOT NULL 
DROP TABLE [MHDInternal].[TEMP_DEM_SUS_Readmissions_Unsuppressed_Long] 

SELECT 
	w.[Month]
	,w.[Org_Type]
	,w.Organisation_Name 
	,w.[Region Name]
	,ROUND(v.Readmissions30days,0) AS Readmissions30days
	,ROUND(v.Readmissions60days,0) AS Readmissions60days
	,ROUND(v.Readmissions90days,0) AS Readmissions90days
	,v.AdmissionGroup

INTO [MHDInternal].[TEMP_DEM_SUS_Readmissions_Unsuppressed_Long] 

FROM [MHDInternal].[TEMP_DEM_SUS_Readmissions_Unsuppressed_Wide] w

CROSS APPLY (VALUES
	('Emergency Admissions - Dementia Diagnosis', w.[Dem - Readmissions30days], w.[Dem - Readmissions60days], w.[Dem - Readmissions90days]), 
	('Emergency Admissions - 65+', w.[Age65 - Readmissions30days], w.[Age65 - Readmissions60days], w.[Age65 - Readmissions90days]), 
	('Emergency Admissions - Delirium Diagnosis', w.[Delirium - Readmissions30days], w.[Delirium - Readmissions60days], w.[Delirium - Readmissions90days]), 
	('Emergency Admissions - MCI Diagnosis', w.[MCI - Readmissions30days], w.[MCI - Readmissions60days], w.[MCI - Readmissions90days]), 
	('Emergency Admissions', w.[Total - Readmissions30days], w.[Total - Readmissions60days], w.[Total - Readmissions90days])
	) v 
	(AdmissionGroup, [Readmissions30days], [Readmissions60days], [Readmissions90days]) 


SET @Offset = @Offset - 1
SET @CurrentMonthEnd = EOMONTH(DATEADD(MONTH,1,@CurrentMonthEnd))

DROP TABLE [MHDInternal].[TEMP_DEM_SUS_Previous_Discharge]
DROP TABLE [MHDInternal].[TEMP_DEM_SUS_Latest_Admission]
DROP TABLE [MHDInternal].[TEMP_DEM_SUS_Readmission_Base]
DROP TABLE [MHDInternal].[TEMP_DEM_SUS_Readmissions_Unsuppressed_Wide]
DROP TABLE [MHDInternal].[TEMP_DEM_SUS_Readmissions_AggSICB]


----- Unsuppress for final output 
--IF OBJECT_ID ('[MHDInternal].[DASHBOARD_DEM_SUS_Emergency_Readmissions_New]') IS NOT NULL 
--DROP TABLE [MHDInternal].[DASHBOARD_DEM_SUS_Emergency_Readmissions_New]

INSERT INTO [MHDInternal].[DASHBOARD_DEM_SUS_Emergency_Readmissions_New]

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

--INTO [MHDInternal].[DASHBOARD_DEM_SUS_Emergency_Readmissions_New]

FROM [MHDInternal].[TEMP_DEM_SUS_Readmissions_Unsuppressed_Long] 

END; -- End loop ----------------------------------------------------------------------------------------------------
