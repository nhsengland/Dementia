/****** Script for producing a lookup for LSOA 2021 codes to MSOA 2021 codes to Sub-ICB Codes/Names to ICB COdes/Names to Region Name
		This table is used to enable aggregation of 2021 census population data, which is available at LSOA or MSOA levels, to Sub-ICB/ICB/Region levels******/

--The [NHSE_UKHF].[ODS].[vw_CCG_Names_And_Codes_England_SCD] contains ONS and ODS CCG codes which are needed in the joins for the final lookup table below
--This table produces an updated version of [NHSE_UKHF].[ODS].[vw_CCG_Names_And_Codes_England_SCD] with 2022 Sub-ICB codes found here (Sheet: Boundary changes >> Summary, Table: Other geography codes)
-- https://view.officeapps.live.com/op/view.aspx?src=https%3A%2F%2Fwww.england.nhs.uk%2Fwp-content%2Fuploads%2F2022%2F04%2Fx-integrated-care-board-boundary-changes-22-23.xlsx&wdOrigin=BROWSELINK
IF OBJECT_ID ('[NHSE_Sandbox_MentalHealth].[dbo].[Lookup_ONS_ODS_SubICB_Codes22]') IS NOT NULL DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].[Lookup_ONS_ODS_SubICB_Codes22]
SELECT DISTINCT 
	CCG_Code2 AS ONS_SubICB_Code
	,CCG_Code AS ODS_SubICB_Code
	,CASE WHEN CCG_Code2='E38000182' THEN 'E38000263' 
		WHEN CCG_Code2='E38000229' THEN 'E38000261'
		WHEN CCG_Code2='E38000250' THEN 'E38000259'
		WHEN CCG_Code2='E38000220' THEN 'E38000258'
		WHEN CCG_Code2='E38000026' THEN 'E38000260'
		WHEN CCG_Code2='E38000242' THEN 'E38000262'
		ELSE CCG_Code2 
		END AS ONS_SubICB_Code22
	,CASE WHEN CCG_Code2='E38000182' THEN '01Y' 
		WHEN CCG_Code2='E38000229' THEN '15M'
		WHEN CCG_Code2='E38000250' THEN 'D2P2L'
		WHEN CCG_Code2='E38000220' THEN '15E'
		WHEN CCG_Code2='E38000026' THEN '06H'
		WHEN CCG_Code2='E38000242' THEN '78H'
		ELSE CCG_Code 
		END AS ODS_SubICB_Code22
INTO [NHSE_Sandbox_MentalHealth].[dbo].[Lookup_ONS_ODS_SubICB_Codes22]
FROM [NHSE_UKHF].[ODS].[vw_CCG_Names_And_Codes_England_SCD] 

--This table produces the final lookup table for matching LSOA 2021 codes to MSOA 2021 codes to Sub-ICB Codes/Names to ICB COdes/Names to Region Name 
IF OBJECT_ID ('[NHSE_Sandbox_MentalHealth].[dbo].[Lookup_LSOA21_MSOA21_ICB]') IS NOT NULL DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].[Lookup_LSOA21_MSOA21_ICB]
SELECT DISTINCT
	b.[lsoa21]
	,b.[msoa21]
	,c.ONS_SubICB_Code22
	,c.ODS_SubICB_Code22
	,cc.Organisation_Code as SubICBCode
	,cc.Organisation_Name as SubICBName
	,cc.STP_Code as ICBCode
	,cc.STP_Name as ICBName
	,cc.Region_Code
	,cc.Region_Name
INTO [NHSE_Sandbox_MentalHealth].[dbo].[Lookup_LSOA21_MSOA21_ICB]
FROM [NHSE_Sandbox_MentalHealth].[dbo].[NSPL21_FEB_2023_UK] b
	--Table from: https://geoportal.statistics.gov.uk/datasets/ons::national-statistics-postcode-lookup-2021-census-february-2023/about
	--Contains LSOA 2021 codes matched to MSOA 2021 codes matched to ONS Sub-ICB codes
	LEFT JOIN [NHSE_Sandbox_MentalHealth].[dbo].[Lookup_ONS_ODS_SubICB_Codes22] c on c.ONS_SubICB_Code22=b.ccg
	--Joins on ONS CCG codes to get the 2022 ODS Sub-ICB codes so the [NHSE_Reference].[dbo].[tbl_Ref_ODS_Commissioner_Hierarchies] table can be joined to get Sub-ICB names etc
	LEFT JOIN [NHSE_Reference].[dbo].[tbl_Ref_ODS_Commissioner_Hierarchies] cc on cc.Organisation_Code= c.ODS_SubICB_Code22
	--Joins on 2022 ODS Sub-ICB codes to get the Sub-ICB names, ICB names and Region names
WHERE LSOA21 like 'E%' 
	--Filters LSOA 2021 codes for English codes




 