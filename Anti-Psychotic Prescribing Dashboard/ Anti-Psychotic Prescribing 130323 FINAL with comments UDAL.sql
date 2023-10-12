/****** Script looking at anti-psychotic prescribing within the dementia register - including calculations of pbar (mean), Upper Control Limit (UCL) and Lower Control Limit (LCL) for statistical process control chart  ******/

IF OBJECT_ID ('[MHDInternal].[TEMP_SubICBtoRegion]') IS NOT NULL DROP TABLE [MHDInternal].[TEMP_SubICBtoRegion]
--This table provides the latest Sub-ICB Codes (which currently are the same as 2021 CCG Codes) and provides the Sub-ICB Name, ICB and Region names and codes for that Sub-ICB code
--It contains 106 rows for the 106 Sub-ICBs
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
--[NHSE_Sandbox_MentalHealth].[dbo].[Dementia_AntiPsychoticData_SubICB] is the old data collection so contains data until September 2022
--To get the data at Sub-ICB level, the data is manually uploaded into the above tables from Table 5 in the Summary excel file from https://digital.nhs.uk/data-and-information/publications/statistical/recorded-dementia-diagnoses

--[NHSE_Sandbox_MentalHealth].[dbo].[Dementia_AntiPsychoticData_SubICB_Primary_Care_Collection] is the new data collection so contains data from October 2022
--To get the data at Sub-ICB level, the data is manually uploaded into the above tables from Table 5 in the Summary excel file from https://digital.nhs.uk/data-and-information/publications/statistical/primary-care-dementia-data

--This table combines the two data collections into one place
IF OBJECT_ID ('[MHDInternal].[TEMP_DEM_AntiPsychotic_Data]') IS NOT NULL DROP TABLE [MHDInternal].[TEMP_DEM_AntiPsychotic_Data]
SELECT * 
INTO [MHDInternal].[TEMP_DEM_AntiPsychotic_Data]
FROM [MHDInternal].[STAGING_DEM_AntiPsychotic_Data]

INSERT INTO [MHDInternal].[TEMP_DEM_AntiPsychotic_Data]
SELECT *
FROM [MHDInternal].[STAGING_DEM_AntiPsychotic_Data_Primary_Care_Collection]

------------------------------------------------------------------------------------
--This table recalculates the figures for without psychosis diagnosis, with psychosis diagnosis and dementia register based on CCG2021 codes and 2022 Sub-ICB names for Sub-ICBs, ICBs, Regions and Nationally
--It also calculates the proportions of the dementia register with abd without a psychosis diagnosis
IF OBJECT_ID ('[MHDInternal].[TEMP_DEM_AntiPsyStep1]') IS NOT NULL DROP TABLE [MHDInternal].[TEMP_DEM_AntiPsyStep1]

SELECT *
INTO [MHDInternal].[TEMP_DEM_AntiPsyStep1]
FROM(
-----------------------------------Sub-ICBs (recalculated based on 2021 CCG (now Sub-ICB) codes and 2022 Sub-ICB names)-----------------------------------------------------------------------------------------
SELECT
    z.[Month]
--CAST AS FLOAT used to remove the excess 0s
--Summing the 'without psychosis diagnosis', 'with psychosis diagnosis' and dementia register grouped by the month, the CCG2021 code, 2022 Sub-ICB name, ICB name, ICB code, Region name and Region code in order to recalculate these for any mergers/splits that have occurred
    ,SUM(CAST(z.[Without Psychosis Diagnosis] AS FLOAT)) AS [ANTI_PSY_NO_PSY_DIAG_ALL_AGES]
	,SUM(CAST(z.[With Psychosis Diagnosis] AS FLOAT)) AS [ANTI_PSY_PSY_DIAG_ALL_AGES]
	,SUM(CAST(z.[Dementia Register] AS FLOAT)) AS [DEM_REGISTER]
--Calculating the proportions of the dementia register grouped by the month, the CCG2021 code, 2022 Sub-ICB name, ICB name, ICB code, Region name and Region code
	,(SUM(z.[Without Psychosis Diagnosis])/SUM(z.[Dementia Register])) AS [Proportion_of_DEM_WITH_ANTI_PSY_AND_NO_PSY_DIAG]
	,(SUM(z.[With Psychosis Diagnosis])/SUM(z.[Dementia Register])) AS [Proportion_of_DEM_WITH_ANTI_PSY_AND_PSY_DIAG]
	,'Sub ICB' AS [Org Type]
	,b.[Sub ICB Code] AS [Org Code]
    ,b.[Sub ICB Name] AS [Org Name]
	,b.[ICB Code]
	,b.[ICB Name]
	,b.[Region Name]
	,b.[Region Code]
FROM [MHDInternal].[TEMP_DEM_AntiPsychotic_Data] z
--Joins to the CCG lookup table to match any old CCG codes with the latest CCG2021 codes
--The datatypes didn't match as the anti-psy data doesn't accept nulls and the lookup table does so collate database_default changes that to allow the join
LEFT JOIN [MHDInternal].[REFERENCE_CCG_2020_Lookup] a ON z.Code= a.IC_CCG COLLATE DATABASE_DEFAULT
--Joins to the TEMP_SubICBtoRegion table (from above) to get the latest (2022) Sub-ICB codes, Sub-ICB names and matches to ICB codes, ICB names and Region codes and Region names
LEFT JOIN [MHDInternal].[TEMP_SubICBtoRegion] b ON a.CCG21 = b.[Sub ICB Code]
--Filter for CCGs or Sub-ICBs - the data has all geography types in the column Type i.e. Region, STP, CCG and we only want CCG or Sub-ICB
WHERE [Type]='CCG' OR [Type]='SUB_ICB_LOC'
--This relates to the summing of 'without psychosis diagnosis', 'with psychosis diagnosis' and dementia register to recalculate these based on month, CCG21 code, 2022 Sub-ICB name, ICB name, ICB code, Region name and Region code
GROUP BY z.[Month], b.[Sub ICB Code], b.[Sub ICB Name], b.[ICB Code],b.[ICB Name],b.[Region Name],b.[Region Code]

UNION

-----------------------------------------------------ICBs (calculated based on 2021 CCG (now Sub-ICB) codes and 2022 Sub-ICB names)----------------------------------------------
SELECT
    z.[Month]
--CAST AS FLOAT used to remove the excess 0s
--Summing the 'without psychosis diagnosis', 'with psychosis diagnosis' and dementia register grouped by the month, ICB name, ICB code, Region name and Region code in order to recalculate these for any mergers/splits that have occurred
    ,SUM(CAST(z.[Without Psychosis Diagnosis] AS FLOAT)) AS [ANTI_PSY_NO_PSY_DIAG_ALL_AGES]
	,SUM(CAST(z.[With Psychosis Diagnosis] AS FLOAT)) AS [ANTI_PSY_PSY_DIAG_ALL_AGES]
	,SUM(CAST(z.[Dementia Register] AS FLOAT)) AS [DEM_REGISTER]
--Calculating the proportions of the dementia register grouped by the month, ICB name, ICB code, Region name and Region code
	,(SUM(z.[Without Psychosis Diagnosis])/SUM(z.[Dementia Register])) AS [Proportion_of_DEM_WITH_ANTI_PSY_AND_NO_PSY_DIAG]
	,(SUM(z.[With Psychosis Diagnosis])/SUM(z.[Dementia Register])) AS [Proportion_of_DEM_WITH_ANTI_PSY_AND_PSY_DIAG]
	,'ICB' AS [Org Type]
	,b.[ICB Code] AS [Org Code]
    ,b.[ICB Name] AS [Org Name]
	,b.[ICB Code]
	,b.[ICB Name]
	,b.[Region Name]
	,b.[Region Code]
FROM [MHDInternal].[TEMP_DEM_AntiPsychotic_Data] z
--Joins to the CCG lookup table to match any old CCG codes with the latest CCG2021 codes
--The datatypes didn't match as the anti-psy data doesn't accept nulls and the lookup table does so collate database_default changes that to allow the join
LEFT JOIN [MHDInternal].[REFERENCE_CCG_2020_Lookup] a ON z.Code= a.IC_CCG COLLATE DATABASE_DEFAULT
--Joins to the TEMP_SubICBtoRegion table (from above) to get the latest (2022) Sub-ICB codes, Sub-ICB names and matches to ICB codes, ICB names and Region codes and Region names
LEFT JOIN [MHDInternal].[TEMP_SubICBtoRegion] b ON a.CCG21 = b.[Sub ICB Code]
--Filter for CCGs or Sub-ICBs - the data has all geography types in the column Type i.e. Region, STP, CCG and we only want CCG or Sub-ICB in order to calculate the ICB values
WHERE [Type]='CCG' OR [Type]='SUB_ICB_LOC'
--This relates to the summing of 'without psychosis diagnosis', 'with psychosis diagnosis' and dementia register to recalculate these based on month, ICB name, ICB code, Region name and Region code
GROUP BY z.[Month], b.[ICB Code],b.[ICB Name],b.[Region Name],b.[Region Code]

UNION

-----------------------------------------------------------------Regions (calculated based on 2021 CCG (now Sub-ICB) codes and 2022 Sub-ICB names)----------------------------

SELECT
    z.[Month]
--CAST AS FLOAT used to remove the excess 0s
--Summing the 'without psychosis diagnosis', 'with psychosis diagnosis' and dementia register grouped by the month, Region name and Region code in order to recalculate these for any mergers/splits that have occurred
    ,SUM(CAST(z.[Without Psychosis Diagnosis] AS FLOAT)) AS [ANTI_PSY_NO_PSY_DIAG_ALL_AGES]
	,SUM(CAST(z.[With Psychosis Diagnosis] AS FLOAT)) AS [ANTI_PSY_PSY_DIAG_ALL_AGES]
	,SUM(CAST(z.[Dementia Register] AS FLOAT)) AS [DEM_REGISTER]
--Calculating the proportions of the dementia register grouped by the month, Region name and Region code
	,(SUM(z.[Without Psychosis Diagnosis])/SUM(z.[Dementia Register])) AS [Proportion_of_DEM_WITH_ANTI_PSY_AND_NO_PSY_DIAG]
	,(SUM(z.[With Psychosis Diagnosis])/SUM(z.[Dementia Register])) AS [Proportion_of_DEM_WITH_ANTI_PSY_AND_PSY_DIAG]
	,'Region' AS [Org Type]
	,b.[Region Code] AS [Org Code]
    ,b.[Region Name] AS [Org Name]
	,null AS [ICB Code]
	,null AS [ICB Name]
	,b.[Region Name]
	,b.[Region Code]
FROM [MHDInternal].[TEMP_DEM_AntiPsychotic_Data] z
--Joins to the CCG lookup table to match any old CCG codes with the latest CCG2021 codes
--The datatypes didn't match as the anti-psy data doesn't accept nulls and the lookup table does so collate database_default changes that to allow the join
LEFT JOIN [MHDInternal].[REFERENCE_CCG_2020_Lookup] a ON z.Code= a.IC_CCG COLLATE DATABASE_DEFAULT
--Joins to the TEMP_SubICBtoRegion table (from above) to get the latest (2022) Sub-ICB codes, Sub-ICB names and matches to ICB codes, ICB names and Region codes and Region names
LEFT JOIN [MHDInternal].[TEMP_SubICBtoRegion] b ON a.CCG21 = b.[Sub ICB Code]
--Filter for CCGs or Sub-ICBs - the data has all geography types in the column Type i.e. Region, STP, CCG and we only want CCG or Sub-ICB in order to calculate the Region values
WHERE [Type]='CCG' OR [Type]='SUB_ICB_LOC'
--This relates to the summing of 'without psychosis diagnosis', 'with psychosis diagnosis' and dementia register to recalculate these based on month, Region name and Region code
GROUP BY z.[Month], b.[Region Code], b.[Region Name] 

UNION
---------------------------------------------------------National (just filtered for what has been reported for England in the data as shouldn't be impacted by CCG mergers etc)---------------------------------------------------------

SELECT
    z.[Month]
--CAST AS FLOAT used to remove the excess 0s
--Summing the 'without psychosis diagnosis', 'with psychosis diagnosis' and dementia register grouped by the month
    ,SUM(CAST(z.[Without Psychosis Diagnosis] AS FLOAT)) AS [ANTI_PSY_NO_PSY_DIAG_ALL_AGES]
	,SUM(CAST(z.[With Psychosis Diagnosis] AS FLOAT)) AS [ANTI_PSY_PSY_DIAG_ALL_AGES]
	,SUM(CAST(z.[Dementia Register] AS FLOAT)) AS [DEM_REGISTER]
--Calculating the proportions of the dementia register grouped by the month
	,(SUM(z.[Without Psychosis Diagnosis])/SUM(z.[Dementia Register])) AS [Proportion_of_DEM_WITH_ANTI_PSY_AND_NO_PSY_DIAG]
	,(SUM(z.[With Psychosis Diagnosis])/SUM(z.[Dementia Register])) AS [Proportion_of_DEM_WITH_ANTI_PSY_AND_PSY_DIAG]
	,'National' AS [Org Type]
	,'England' AS [Org Code]
    ,'England' AS [Org Name]
	,null AS [ICB Code]
	,null AS [ICB Name]
	,null AS [Region Name]
	,null AS [Region Code]
FROM [MHDInternal].[TEMP_DEM_AntiPsychotic_Data] z
--Filter for National - the data has all geography types in the column Type i.e. Region, STP, CCG and we only want National
WHERE [Type]='National'
--This relates to the summing of 'without psychosis diagnosis', 'with psychosis diagnosis' and dementia register to recalculate these based on month
GROUP BY  [Month])_

--This is the final table used in the dashboard and calculates the pbar, upper control limit (UCL) and lower control limit (LCL) 
--for the proportion WITHOUT psychosis diagnosis out of the dementia register and for the proportion WITH psychosis diagnosis out of the dementia register
IF OBJECT_ID ('[MHDInternal].[DASHBOARD_DEM_AntiPsychotic]') IS NOT NULL DROP TABLE [MHDInternal].[DASHBOARD_DEM_AntiPsychotic]

SELECT *
INTO [MHDInternal].[DASHBOARD_DEM_AntiPsychotic]
FROM(

SELECT
	b.[Org Type]
	,b.[Org Name]
	,b.[Org Code]
	,b.[ICB Name]
	,b.[Region Name]
--pbar and pbar2 are calculated below so that they can be used in the calculations for UCL and LCL, and UCL2 and LCL2, respectively
	,b.[pbar]
	,b.[pbar2]
--Calculations for UCL and LCL for the proportion WITHOUT psychosis diagnosis out of the dementia register
	,[pbar]+(3*SQRT([pbar]*(1-[pbar])/(DEM_REGISTER))) AS [UCL]
	,[pbar]-(3*SQRT([pbar]*(1-[pbar])/(DEM_REGISTER))) AS [LCL]
--Calculations for UCL2 and LCL2 for the proportion WITH psychosis diagnosis out of the dementia register
	,[pbar2]+(3*SQRT([pbar2]*(1-[pbar2])/(DEM_REGISTER))) AS [UCL2]
	,[pbar2]-(3*SQRT([pbar2]*(1-[pbar2])/(DEM_REGISTER))) AS [LCL2]
	,CAST(a.[Month] AS Date) AS [Effective_Snapshot_Date]
	,a.[ANTI_PSY_NO_PSY_DIAG_ALL_AGES]
	,a.[ANTI_PSY_PSY_DIAG_ALL_AGES]
	,a.DEM_REGISTER
	,a.[Proportion_of_DEM_WITH_ANTI_PSY_AND_PSY_DIAG]
	,a.[Proportion_of_DEM_WITH_ANTI_PSY_AND_NO_PSY_DIAG]
FROM(
SELECT
	[Org Type]
	,[Org Name]
	,[Org Code]
	,[ICB Name]
	,[Region Name]
--Calculate the pbar for the proportion WITHOUT psychosis diagnosis out of the dementia register first so that it can be used in the calculations for UCL and LCL
--this is done for each organisation
	,SUM([ANTI_PSY_NO_PSY_DIAG_ALL_AGES])/(SUM(DEM_REGISTER)) AS [pbar]
--Calculate the pbar (labelled as pbar2) for the proportion WITH psychosis diagnosis out of the dementia register first so that it can be used in the calculations for UCL2 and LCL2
--this is done for each organisation
	,SUM([ANTI_PSY_PSY_DIAG_ALL_AGES])/(SUM(DEM_REGISTER)) AS [pbar2]
FROM [MHDInternal].[TEMP_DEM_AntiPsyStep1]
GROUP BY [Org Type],[Org Name],[Org Code],[ICB Name],[Region Name]
) AS b

--Join to TEMP_DEM_AntiPsyStep1 so that the previously calculated 'without psychosis diagnosis', 'with psychosis diagnosis', dementia register and proportions can be used alongside the calculated pbar, pbar2, UCL, UCL2, LCL and LCL2
LEFT JOIN [MHDInternal].[TEMP_DEM_AntiPsyStep1] a ON b.[Org Code] = a.[Org Code]

GROUP BY b.[Org Type], b.[Org Name], b.[Org Code], b.[ICB Name],b.[Region Name]
, b.[pbar], b.pbar2, CAST(a.[Month] AS Date),a.[ANTI_PSY_NO_PSY_DIAG_ALL_AGES]
, a.[ANTI_PSY_PSY_DIAG_ALL_AGES], a.DEM_REGISTER, a.[Proportion_of_DEM_WITH_ANTI_PSY_AND_PSY_DIAG]
, a.[Proportion_of_DEM_WITH_ANTI_PSY_AND_NO_PSY_DIAG]
)_

--Drop temporary tables created to produce the final output table
DROP TABLE [MHDInternal].[TEMP_SubICBtoRegion]
DROP TABLE [MHDInternal].[TEMP_DEM_AntiPsychotic_Data]
DROP TABLE [MHDInternal].[TEMP_DEM_AntiPsyStep1]
