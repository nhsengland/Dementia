   /****** Script for reformatting Dementia Record and Rate Data and then calculating pbar (mean), Upper Control Limit (UCL) and Lower Control Limit (LCL) for statistical process control chart ******/

--This table provides the latest Sub-ICB Codes (which currently are the same as 2021 CCG Codes) and provides the Sub-ICB Name, ICB and Region names and codes for that Sub-ICB code
--It contains 106 rows for the 106 Sub-ICBs
IF OBJECT_ID ('[MHDInternal].[TEMP_SubICBtoRegion]') IS NOT NULL DROP TABLE [MHDInternal].[TEMP_SubICBtoRegion]
SELECT DISTINCT 
	[Organisation_Code] AS 'Sub ICB Code'
	,[Organisation_Name] AS 'Sub ICB Name' 
    ,[STP_Code] AS 'ICB Code'
	,[STP_Name] AS 'ICB Name'
	,[Region_Code] AS 'Region Code' 
	,[Region_Name] AS 'Region Name'
INTO [MHDInternal].[TEMP_SubICBtoRegion]
FROM [Reporting].[Ref_ODS_Commissioner_Hierarchies_ICB]
--Effective_To has the date the Organisation_Code is applicable to so the codes currently in use have null in this column.
--Filtering for just clinical commissioning group organisation type - this means commissioning hubs are excluded
WHERE [Effective_To] IS NULL AND [NHSE_Organisation_Type]='CLINICAL COMMISSIONING GROUP'


--Since October 2022 there has been a change in data collection:
--[NHSE_UKHF].[Rec_Dementia_Diag].[vw_Diag_Rate_By_NHS_Org_65Plus1] is the old data collection so contains data until September 2022
--[NHSE_UKHF].[Primary_Care_Dementia].[vw_Diag_Rate_By_NHS_Org_65Plus1] is the new data collection so contains data from October 2022
--This table combines the two data collections into one place
IF OBJECT_ID ('[MHDInternal].[TEMP_DEM_DDR_Base]') IS NOT NULL DROP TABLE [MHDInternal].[TEMP_DEM_DDR_Base]
SELECT
		[Org_Type]
		,[Org_Code]
		,[Measure]
		,[Measure_Value]
		,[Effective_Snapshot_Date]
		into [MHDInternal].[TEMP_DEM_DDR_Base]
	FROM [UKHF_Rec_Dementia_Diag].[Diag_Rate_By_NHS_Org_65Plus1]

INSERT INTO [MHDInternal].[TEMP_DEM_DDR_Base]
SELECT
	[Org_Type]
	,[Org_Code]
	,[Measure]
	,[Measure_Value]
	,[Effective_Snapshot_Date]
FROM [UKHF_Primary_Care_Dementia].[Diag_Rate_By_NHS_Org_65Plus1]


--Creates table TEMP_DEM_DDRStep1 to get the data into a pivoted format 
--It also recalculates the dementia estimate 65 plus, the dementia register 65 plus and dementia diagnosis rate 65 plus, based on the latest 2021 CCG (now Sub-ICB) codes and 2022 Sub-ICB names
IF OBJECT_ID ('[MHDInternal].[TEMP_DEM_DDRStep1]') IS NOT NULL DROP TABLE [MHDInternal].[TEMP_DEM_DDRStep1]
SELECT *
INTO [MHDInternal].[TEMP_DEM_DDRStep1]
FROM(
-----------------------------------Sub-ICBs (recalculated based on CCG2021 codes and 2022 Sub-ICB names)----------------------------------------------------------------------------------------
SELECT
    [Effective_Snapshot_Date]
--CAST AS FLOAT used to remove the excess 0s
--Summing the dementia estimate and register grouped by the effective snapshot date, the CCG2021 code, 2022 Sub-ICB name and ICB name in order to recalculate these for any mergers/splits that have occurred
    ,SUM(CAST([DEMENTIA_ESTIMATE_65_PLUS] AS FLOAT)) AS [DEMENTIA_ESTIMATE_65_PLUS]
    ,SUM(CAST([DEMENTIA_REGISTER_65_PLUS] AS FLOAT)) AS [DEMENTIA_REGISTER_65_PLUS]
--Recalculating the DDR grouped by the effective snapshot date, the CCG2021 code, 2022 Sub-ICB name and ICB name in order to recalculate these for any mergers/splits that have occurred
	,(SUM([DEMENTIA_REGISTER_65_PLUS])/SUM([DEMENTIA_ESTIMATE_65_PLUS])) AS [DEMENTIA_RATE_65_PLUS]
	,'Sub ICB' AS [Org Type]
	,b.[Sub ICB Code] AS [Org Code]
    ,b.[Sub ICB Name] AS [Org Name]
	,b.[ICB Name]
	,null AS [Region Name]
FROM
    --For pivoting the UKHF DDR data:
	(SELECT
		[Org_Type]
		,[Org_Code]
		,[Measure]
		,[Measure_Value]
		,[Effective_Snapshot_Date]
	FROM [MHDInternal].[TEMP_DEM_DDR_Base]
		) AS SourceTable
		PIVOT(
		--Have to use an aggregate function for pivot to work so used max to work around this
		MAX([Measure_Value])
		FOR [Measure] IN ([DEMENTIA_ESTIMATE_65_PLUS], [DEMENTIA_REGISTER_65_PLUS])
		) AS PivotTable
		--Pivot section end
--Joins to the CCG lookup table to match any old CCG codes with the latest CCG2021 codes
--The datatypes didn't match as UKHF data doesn't accept nulls and the lookup table does so collate database_default changes that to allow the join
LEFT JOIN [MHDInternal].[REFERENCE_CCG_2020_Lookup] a ON Org_Code= a.IC_CCG COLLATE DATABASE_DEFAULT
--Joins to the TEMP_SubICBtoRegion table (from above) to get the latest (2022) Sub-ICB codes, Sub-ICB names and matches to ICB codes, ICB names and Region codes and Region names
LEFT JOIN [MHDInternal].[TEMP_SubICBtoRegion] b ON a.CCG21 = b.[Sub ICB Code]
--Filter for CCGs or Sub-ICBs - the UKHF data has all geography types in the column Org_Type i.e. Region, STP, CCG and we only want CCG or Sub-ICB
WHERE Org_Type='CCG' or Org_Type='SUB_ICB_LOC'
--This relates to the summing of dementia register and dementia estimate to recalculate these based on CCG21 code, 2022 Sub-ICB name, ICB name and the effective snapshot date
GROUP BY [Sub ICB Code], [Sub ICB Name], [Effective_Snapshot_Date],[ICB Name]

--Add this table to the next one for ICBs (will match column names and then just add the new rows for ICBs below)
UNION
---------------------------------------------------------------------ICBs (recalculated based on 2021 CCG (now Sub-ICB) codes and 2022 Sub-ICB names)---------------------------------------------------------------------
SELECT
    [Effective_Snapshot_Date]
--CAST AS FLOAT used to remove the excess 0s
--Summing the dementia estimate and register grouped by the effective snapshot date, the ICB code, ICB name and Region name in order to recalculate these for any Sub-ICB mergers/splits that have occurred
    ,SUM(CAST([DEMENTIA_ESTIMATE_65_PLUS] AS FLOAT)) AS [DEMENTIA_ESTIMATE_65_PLUS]
    ,SUM(CAST([DEMENTIA_REGISTER_65_PLUS] AS FLOAT)) AS [DEMENTIA_REGISTER_65_PLUS]
--Recalculating the DDR grouped by the effective snapshot date, the ICB code, ICB name and Region name in order to recalculate these for any Sub-ICB mergers/splits that have occurred
	,(SUM([DEMENTIA_REGISTER_65_PLUS])/SUM([DEMENTIA_ESTIMATE_65_PLUS])) AS [DEMENTIA_RATE_65_PLUS]
	,'ICB' AS [Org Type]
	,b.[ICB Code] AS [Org Code]
    ,b.[ICB Name] AS [Org Name]
	,b.[ICB Name]
	,b.[Region Name]
FROM
    --For pivoting the UKHF DDR data:
	(SELECT
		[Org_Type]
		,[Org_Code]
		,[Measure]
		,[Measure_Value]
		,[Effective_Snapshot_Date]
	FROM [MHDInternal].[TEMP_DEM_DDR_Base]
		) AS SourceTable
		PIVOT(
		--Have to use an aggregate function for pivot to work so used max to work around this
		MAX([Measure_Value])
		FOR [Measure] IN ([DEMENTIA_ESTIMATE_65_PLUS], [DEMENTIA_REGISTER_65_PLUS])
		) AS PivotTable
		--Pivot section end
--Joins to the CCG lookup table to match any old CCG codes with the latest CCG2021 codes
--The datatypes didn't match as UKHF data doesn't accept nulls and the lookup table does so collate database_default changes that to allow the join
LEFT JOIN [MHDInternal].[REFERENCE_CCG_2020_Lookup] a ON Org_Code= a.IC_CCG COLLATE DATABASE_DEFAULT
--Joins to the TEMP_SubICBtoRegion table (from above) to get the latest (2022) Sub-ICB codes, Sub-ICB names and matches to ICB codes, ICB names and Region codes and Region names
LEFT JOIN [MHDInternal].[TEMP_SubICBtoRegion] b ON a.CCG21 = b.[Sub ICB Code]
--Filter for CCGs or Sub-ICBs - the UKHF data has all geography types in the column Org_Type i.e. Region, STP, CCG and we only want CCG or Sub-ICB
WHERE Org_Type='CCG' or Org_Type='SUB_ICB_LOC'
--This relates to the summing of dementia register and dementia estimate to recalculate these based on ICB code, ICB name, Region name and the effective snapshot date
GROUP BY [ICB Code], [ICB Name], [Region Name], [Effective_Snapshot_Date]

--Add this table to the next one for Regions (will match column names and then just add the new rows for Regions below)
UNION
----------------------------------------------------------------------------Regions (recalculated based on 2021 CCG (now Sub-ICB) codes and 2022 Sub-ICB names)-------------------------------------------------------------------------------------
SELECT
    [Effective_Snapshot_Date]
--CAST AS FLOAT used to remove the excess 0s
--Summing the dementia estimate and register grouped by the effective snapshot date, the Region code and Region namein order to recalculate these for any Sub-ICB mergers/splits that have occurred
    ,SUM(CAST([DEMENTIA_ESTIMATE_65_PLUS] AS FLOAT)) AS [DEMENTIA_ESTIMATE_65_PLUS]
    ,SUM(CAST([DEMENTIA_REGISTER_65_PLUS] AS FLOAT)) AS [DEMENTIA_REGISTER_65_PLUS]
--Recalculating the DDR grouped by the effective snapshot date, the Region code and Region name in order to recalculate these for any Sub-ICB mergers/splits that have occurred
	,(SUM([DEMENTIA_REGISTER_65_PLUS])/SUM([DEMENTIA_ESTIMATE_65_PLUS])) AS [DEMENTIA_RATE_65_PLUS]
	,'Region' AS [Org Type]
	,b.[Region Code] AS [Org Code]
    ,b.[Region Name] AS [Org Name]
	,null AS [ICB Name]
	,b.[Region Name]
FROM
    --For pivoting the UKHF DDR data:
	(SELECT
		[Org_Type]
		,[Org_Code]
		,[Measure]
		,[Measure_Value]
		,[Effective_Snapshot_Date]
	FROM [MHDInternal].[TEMP_DEM_DDR_Base]
		) AS SourceTable
		PIVOT(
		--Have to use an aggregate function for pivot to work so used max to work around this
		MAX([Measure_Value])
		FOR [Measure] IN ([DEMENTIA_ESTIMATE_65_PLUS], [DEMENTIA_REGISTER_65_PLUS])
		) AS PivotTable
		--Pivot section end
--Joins to the CCG lookup table to match any old CCG codes with the latest CCG2021 codes 
--The datatypes didn't match as UKHF data doesn't accept nulls and the lookup table does so collate database_default changes that to allow the join
LEFT JOIN [MHDInternal].[REFERENCE_CCG_2020_Lookup] a ON Org_Code= a.IC_CCG COLLATE DATABASE_DEFAULT
--Joins to the TEMP_SubICBtoRegion table (from above) to get the latest (2022) Sub-ICB codes, Sub-ICB names and matches to ICB codes, ICB names and Region codes and Region names
LEFT JOIN [MHDInternal].[TEMP_SubICBtoRegion] b ON a.CCG21 = b.[Sub ICB Code] 
--Filter for CCGs or Sub-ICBs - the UKHF data has all geography types in the column Org_Type i.e. Region, STP, CCG and we only want CCG or Sub-ICB
WHERE Org_Type='CCG' or Org_Type='SUB_ICB_LOC'
--This relates to the summing of dementia register and dementia estimate to recalculate these based on ICB code, ICB name, Region name and the effective snapshot date
GROUP BY [Region Code], [Region Name], [Effective_Snapshot_Date]

--Add this table to the next one for National (will match column names and then just add the new rows for National below)
UNION
----------------------------------------------National (just filtered for what has been reported for England in UKHF data as shouldn't be impacted by CCG mergers etc)----------------------------------------

SELECT
    [Effective_Snapshot_Date]
	--CAST AS FLOAT used to remove the excess 0s
	--Summing the dementia estimate and register grouped by the effective snapshot date to get National figure
    ,SUM(CAST([DEMENTIA_ESTIMATE_65_PLUS] AS FLOAT)) AS [DEMENTIA_ESTIMATE_65_PLUS]
    ,SUM(CAST([DEMENTIA_REGISTER_65_PLUS] AS FLOAT)) AS [DEMENTIA_REGISTER_65_PLUS]
	--Recalculating the DDR to get National figure
	,(SUM([DEMENTIA_REGISTER_65_PLUS])/SUM([DEMENTIA_ESTIMATE_65_PLUS])) AS [DEMENTIA_RATE_65_PLUS]
	,'National' AS [Org Type]
	,'England'AS [Org Code]
    ,'England' AS [Org Name]
	,null AS [STP Name]
	,null AS [Region Name]
FROM
    --For pivoting the UKHF DDR data:
	(SELECT
		[Org_Type]
		,[Org_Code]
		,[Measure]
		,[Measure_Value]
		,[Effective_Snapshot_Date]
	FROM [MHDInternal].[TEMP_DEM_DDR_Base]
		) AS SourceTable
		PIVOT(
		--Have to use an aggregate function for pivot to work so used max to work around this
		MAX([Measure_Value])
		FOR [Measure] IN ([DEMENTIA_ESTIMATE_65_PLUS], [DEMENTIA_REGISTER_65_PLUS])
		) AS PivotTable
		--Pivot section end
--Filter for National - the UKHF data has all geography types in the column Org_Type i.e. Region, STP, CCG and we only want National
WHERE Org_Type='COUNTRY_RESPONSIBILITY' 
--This relates to the summing of register and estimate to recalculate these based the effective snapshot date
GROUP BY [Effective_Snapshot_Date]
)_

-----------------------------
--Creates table TEMP_DEM_DDRStep2 to calculate the pbar (mean), Upper Control Limit (UCL) and Lower Control Limit (LCL) for the full time period (as opposed to pre- and post-Covid as calculated in the next table)
--These calculated columns will be referred to as pbar2, UCL2, LCL2 to distinguish from the pre- and post- Covid versions in the next table
IF OBJECT_ID ('[MHDInternal].[TEMP_DEM_DDRStep2]') IS NOT NULL DROP TABLE [MHDInternal].[TEMP_DEM_DDRStep2]
SELECT *
INTO [MHDInternal].[TEMP_DEM_DDRStep2]
FROM(

SELECT
	b.[Org Type]
	,b.[Org Name]
	,b.[Org Code]
	,b.[ICB Name]
	,b.[Region Name]
--pbar2 is calculated below
	,b.[pbar2]
--Calculations for UCL2 and LCL2
	,b.[pbar2]+(3*SQRT(b.[pbar2]*(1-b.[pbar2])/a.[DEMENTIA_ESTIMATE_65_PLUS])) AS [UCL2]
	,b.[pbar2]-(3*SQRT(b.[pbar2]*(1-b.[pbar2])/a.[DEMENTIA_ESTIMATE_65_PLUS])) AS [LCL2]
	,a.[Effective_Snapshot_Date]
	,a.[DEMENTIA_ESTIMATE_65_PLUS]
	,a.[DEMENTIA_REGISTER_65_PLUS]
	,a.[DEMENTIA_RATE_65_PLUS]
FROM(
SELECT
	[Org Type]
	,[Org Name]
	,[Org Code]
	,[ICB Name]
	,[Region Name]
--Calculate the pbar2 for dementia diagnosis rate first so that it can be used in the calculations for UCL2 and LCL2
--this is done for each organisation
	,SUM([DEMENTIA_REGISTER_65_PLUS])/SUM([DEMENTIA_ESTIMATE_65_PLUS]) AS [pbar2]
FROM [MHDInternal].[TEMP_DEM_DDRStep1]
GROUP BY [Org Type],[Org Name],[Org Code],[ICB Name],[Region Name]) AS b
--Join to TEMP_DEM_DDRStep1 so that the previously calculated dementia estimate, dementia register and DDR can be used alongside the calculated pbar2, UCL2 and LCL2
LEFT JOIN [MHDInternal].[TEMP_DEM_DDRStep1] a ON b.[Org Code] = a.[Org Code]
GROUP BY b.[Org Type],b.[Org Name],b.[Org Code], b.[ICB Name],b.[Region Name]
,[pbar2],[pbar2]+(3*SQRT([pbar2]*(1-[pbar2])/[DEMENTIA_ESTIMATE_65_PLUS])),[pbar2]-(3*SQRT([pbar2]*(1-[pbar2])/[DEMENTIA_ESTIMATE_65_PLUS]))
,a.[Effective_Snapshot_Date],a.[DEMENTIA_ESTIMATE_65_PLUS],a.[DEMENTIA_REGISTER_65_PLUS],a.[DEMENTIA_RATE_65_PLUS]
)_

--This final table (Dementia_Diagnosis_Rate_Dashboard_v2) is used in the dashboard and calculates the pbar, UCL, LCL for pre- and post-Covid (March 2020)
IF OBJECT_ID ('[MHDInternal].[DASHBOARD_DEM_DDR]') IS NOT NULL DROP TABLE [MHDInternal].[DASHBOARD_DEM_DDR]
SELECT *
INTO [MHDInternal].[DASHBOARD_DEM_DDR]
FROM(
-----------------------------------------------------------------------Pre-Covid ---------------------------------------------------------------
SELECT
	x.[Org Type]
	,x.[Org Name]
	,x.[Org Code]
	,x.[ICB Name]
	,x.[Region Name]
--pbar is calculated below so that it can be used in the calculations for UCL and LCL
	,x.[pbar]
--Calculations for UCL and LCL
	,[pbar]+(3*SQRT([pbar]*(1-[pbar])/[DEMENTIA_ESTIMATE_65_PLUS])) AS [UCL]
	,[pbar]-(3*SQRT([pbar]*(1-[pbar])/[DEMENTIA_ESTIMATE_65_PLUS])) AS [LCL]
	,y.[Effective_Snapshot_Date]
	,y.[DEMENTIA_ESTIMATE_65_PLUS]
	,y.[DEMENTIA_REGISTER_65_PLUS]
	,y.[DEMENTIA_RATE_65_PLUS]
	,y.[pbar2]
	,y.[UCL2]
	,y.[LCL2]
FROM(
SELECT
	[Org Type]
	,[Org Name]
	,[Org Code]
	,[ICB Name]
	,[Region Name]
--Calculate the pbar for dementia diagnosis rate first so that it can be used in the calculations for UCL and LCL
--this is done for each organisation
	,SUM([DEMENTIA_REGISTER_65_PLUS])/SUM([DEMENTIA_ESTIMATE_65_PLUS]) AS [pbar]
FROM [MHDInternal].[TEMP_DEM_DDRStep1]
--Filter the Effective Snapshot Date to calculate pbar for pre-covid
WHERE [Effective_Snapshot_Date]<'2020-03-01'
GROUP BY [Org Type],[Org Name],[Org Code],[ICB Name],[Region Name]) AS x
--Join to TEMP_DEM_DDRStep2 so that the previously calculated dementia estimate, dementia register,DDR, pbar2, UCL2 and LCL2 can be used alongside the calculated pbar, UCL and LCL
LEFT JOIN [MHDInternal].[TEMP_DEM_DDRStep2] y ON x.[Org Code] = y.[Org Code]
--Filter the Effective Snapshot Date to calculate UCL and LCL for pre-covid
WHERE [Effective_Snapshot_Date]<'2020-03-01'
GROUP BY x.[Org Type],x.[Org Name],x.[Org Code],x.[ICB Name],x.[Region Name]
,x.[pbar],[pbar]+(3*SQRT([pbar]*(1-[pbar])/[DEMENTIA_ESTIMATE_65_PLUS])),[pbar]-(3*SQRT([pbar]*(1-[pbar])/[DEMENTIA_ESTIMATE_65_PLUS]))
,y.[Effective_Snapshot_Date],y.[DEMENTIA_ESTIMATE_65_PLUS],y.[DEMENTIA_REGISTER_65_PLUS],y.[DEMENTIA_RATE_65_PLUS]
,y.[pbar2],y.[UCL2],y.[LCL2]

--Add this table to the next one for post-covid (will match column names and then just add the new rows for post-covid below)
UNION

-----------------------------------------------------------------------Post-Covid (March 2020) ---------------------------------------------------------------

SELECT
	x.[Org Type]
	,x.[Org Name]
	,x.[Org Code]
	,x.[ICB Name]
	,x.[Region Name]
--pbar is calculated below so that it can be used in the calculations for UCL and LCL
	,x.[pbar]
--Calculations for UCL and LCL
	,[pbar]+(3*SQRT([pbar]*(1-[pbar])/[DEMENTIA_ESTIMATE_65_PLUS])) AS [UCL]
	,[pbar]-(3*SQRT([pbar]*(1-[pbar])/[DEMENTIA_ESTIMATE_65_PLUS])) AS [LCL]
	,y.[Effective_Snapshot_Date]
	,y.[DEMENTIA_ESTIMATE_65_PLUS]
	,y.[DEMENTIA_REGISTER_65_PLUS]
	,y.[DEMENTIA_RATE_65_PLUS]
	,y.[pbar2]
	,y.[UCL2]
	,y.[LCL2]
FROM(
SELECT
	[Org Type]
	,[Org Name]
	,[Org Code]
	,[ICB Name]
	,[Region Name]
--Calculate the pbar for dementia diagnosis rate first so that it can be used in the calculations for UCL and LCL
--this is done for each organisation
	,SUM([DEMENTIA_REGISTER_65_PLUS])/SUM([DEMENTIA_ESTIMATE_65_PLUS]) AS [pbar]
FROM [MHDInternal].[TEMP_DEM_DDRStep1]
--Filter the Effective Snapshot Date to calculate pbar for post-covid
WHERE [Effective_Snapshot_Date]>'2020-03-01'
GROUP BY [Org Type],[Org Name],[Org Code],[ICB Name],[Region Name]) AS x
--Join to TEMP_DEM_DDRStep2 so that the previously calculated dementia estimate, dementia register,DDR, pbar2, UCL2 and LCL2 can be used alongside the calculated pbar, UCL and LCL
LEFT JOIN [MHDInternal].[TEMP_DEM_DDRStep2] y ON x.[Org Code] = y.[Org Code]
--Filter the Effective Snapshot Date to calculate UCL and LCL for post-covid
WHERE [Effective_Snapshot_Date]>'2020-03-01'
GROUP BY x.[Org Type], x.[Org Name],x.[Org Code],x.[ICB Name],x.[Region Name]
,x.[pbar],[pbar]+(3*SQRT([pbar]*(1-[pbar])/[DEMENTIA_ESTIMATE_65_PLUS])),[pbar]-(3*SQRT([pbar]*(1-[pbar])/[DEMENTIA_ESTIMATE_65_PLUS]))
,y.[Effective_Snapshot_Date],y.[DEMENTIA_ESTIMATE_65_PLUS],y.[DEMENTIA_REGISTER_65_PLUS],y.[DEMENTIA_RATE_65_PLUS]
,y.[pbar2],y.[UCL2],y.[LCL2]
)_

--Drop temporary tables created to produce the final output table
DROP TABLE [MHDInternal].[TEMP_SubICBtoRegion]
DROP TABLE [MHDInternal].[TEMP_DEM_DDRStep1]
DROP TABLE [MHDInternal].[TEMP_DEM_DDRStep2]
DROP TABLE [MHDInternal].[TEMP_DEM_DDR_Base]
