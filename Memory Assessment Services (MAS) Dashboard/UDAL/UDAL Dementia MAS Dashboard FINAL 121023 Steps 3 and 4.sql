--Please note this information is experimental and it is only intended for use for management purposes.

/****** Script for Memory Assessment Services Dashboard for calculating the following: 
		open referrals, open referrals with no contact, open referrals with a care plan, new referrals, discharges, 
		wait times from referral to first contact, and wait times from referral to diagnosis ******/

------------------------------------------------Step 3 and 4--------------------------------------------------------------


DECLARE @PeriodStart DATE
DECLARE @PeriodEnd DATE 
DECLARE @PeriodStart2 DATE

SET @PeriodStart2 = '2021-04-01' 

------For refreshing months each superstats this will always be -1 to get the latest refreshed month available
SET @PeriodStart = (SELECT DATEADD(MONTH,-1,MAX([ReportingPeriodStartDate])) FROM [MESH_MHSDS].[MHSDS_SubmissionFlags]) 
SET @PeriodEnd = (SELECT eomonth(DATEADD(MONTH,-1,MAX([ReportingPeriodEndDate]))) FROM [MESH_MHSDS].[MHSDS_SubmissionFlags])
SET DATEFIRST 1

PRINT @PeriodStart
PRINT @PeriodEnd
-----------------------------------------Base Table----------------------------------------------------
--This table produces a record level table for the refresh period defined above, as a basis for the aggregated counts done below ([MHDInternal].[DASHBOARD_DEM_MAS_Main_Metrics])
IF OBJECT_ID ('[MHDInternal].[TEMP_DEM_MAS_Base]') IS NOT NULL DROP TABLE [MHDInternal].[TEMP_DEM_MAS_Base]
SELECT DISTINCT
	CAST(DATENAME(m, sf.ReportingPeriodStartDate) + ' ' + CAST(DATEPART(yyyy, sf.ReportingPeriodStartDate) AS varchar)AS DATE) AS Month
	,c1.FirstContactDate
	,r.UniqServReqID
	,r.Der_Person_ID

	--Geography
    ,CASE WHEN ch.[Organisation_Code] IS NOT NULL THEN ch.[Organisation_Code] ELSE 'Other' END AS 'OrgIDComm'
	,CASE WHEN ch.[Organisation_Name] IS NOT NULL THEN ch.[Organisation_Name] ELSE 'Other' END AS 'Sub_ICB_Name'
	,CASE WHEN ch.[STP_Code] IS NOT NULL THEN ch.[STP_Code] ELSE 'Other' END AS 'ICB_Code'
	,CASE WHEN ch.[STP_Name] IS NOT NULL THEN ch.[STP_Name] ELSE 'Other' END AS 'ICB_Name'
	,CASE WHEN ch.[Region_Name] IS NOT NULL THEN ch.[Region_Name] ELSE 'Other' END AS'Comm_Region_Name'
	,CASE WHEN ch.[Region_Code] IS NOT NULL THEN ch.[Region_Code] ELSE 'Other' END AS 'Comm_Region_Code'
	,CASE WHEN ph.[Organisation_Code] IS NOT NULL THEN ph.[Organisation_Code] ELSE 'Other' END AS 'OrgIDProv'
	,CASE WHEN ph.[Organisation_Name] IS NOT NULL THEN ph.[Organisation_Name] ELSE 'Other' END AS 'Provider_Name'
	,CASE WHEN ph.[Region_Name] IS NOT NULL THEN ph.[Region_Name] ELSE 'Other' END AS 'Prov_Region_Name'

	,r.ReferralRequestReceivedDate
	,r.ServDischDate
	,r.UniqMonthID
	,m.EthnicCategory
	,m.Gender
	,r.AgeServReferRecDate AS AgeServReferRecDate
	,sf.ReportingPeriodStartDate
	,sf.ReportingPeriodEndDate
	,s.ServTeamTypeRefToMH	--team code
	,ISNULL(r1.Main_Description,'Missing/invalid') AS TeamType --Team name (e.g. Memory services/clinic)
	,r.PrimReasonReferralMH --primary reason for referral code
	,ISNULL(r2.Main_Description, 'Missing/invalid') AS PrimReason --primary reason for referral name (e.g. organic brain disorder)
	,CASE WHEN (c1.FirstContactDate IS NOT NULL AND c1.FirstContactDate >=ReferralRequestReceivedDate and c1.FirstContactDate<=sf.ReportingPeriodEndDate)
		THEN DATEDIFF(DD,ReferralRequestReceivedDate,c1.FirstContactDate) 
		ELSE NULL END 
		AS WaitRefContact	
	--Works out the difference between referral date and first contact date in days to calculate the wait time from referral to first contact. This is just for those with a contact date
	--and the first contact has to be after the referral date
	,CASE WHEN c1.FirstContactDate BETWEEN sf.ReportingPeriodStartDate and sf.ReportingPeriodEndDate THEN 1 
		ELSE 0 END 
		AS FirstContactDateMonthFlag
	--Creates a flag for use in tableau for wait time graph which only shows wait times for first contacts within the reporting period in question, rather than for all open referrals.
	,CASE WHEN r.ReferralRequestReceivedDate BETWEEN sf.ReportingPeriodStartDate AND sf.ReportingPeriodEndDate THEN 1 
		ELSE 0 END 
		AS NewRef	--New referrals are defined by the referral request date being between the start and end date of the period in question
	,CASE WHEN r.ServDischDate BETWEEN sf.ReportingPeriodStartDate AND sf.ReportingPeriodEndDate THEN 1 
		ELSE 0 END 
		AS DischRef	--Discharges are defined by the discharge date being between the start and end date of the period in question
	,CASE WHEN r.ServDischDate IS NULL OR r.ServDischDate > sf.ReportingPeriodEndDate THEN 1 
		ELSE 0 END 
		AS OpenRef
	--Open referrals are defined by the service discharge being null or being after the period end i.e. haven't been discharged before or during the period in question
	,CASE WHEN (r.ServDischDate IS NULL OR r.ServDischDate > sf.ReportingPeriodEndDate) AND (c1.FirstContactDate IS NULL OR c1.FirstContactDate > sf.ReportingPeriodEndDate) 
		THEN 1 
		ELSE 0 END 
		AS Refwaiting1stcontact
	--Open referrals waiting for contact are defined by an open referral (as defined above) and also having a null first contact date
	--or the first contact date is after the end of the period in question
	,CASE WHEN (r.ServDischDate IS NULL OR r.ServDischDate > sf.ReportingPeriodEndDate) AND (c.CarePlanCreatDate <= sf.ReportingPeriodEndDate) 
		THEN 1 ELSE 0 END 
		AS RefwithCarePlanCreated
	--Open referrals with a care plan are defined by an open referral (as defined above) and the care plan creation date being before the end of the period in question
	,e.CodedDiagTimestamp as EarliestDiagDate
	,e.[DiagnosisCode] as EarliestDementiaDiagnosisCode 
	,e.[DiagnosisArea] as EarliestDiagnosisArea
	,CASE WHEN (e.CodedDiagTimestamp IS NOT NULL AND CAST(e.CodedDiagTimestamp AS DATE) >=ReferralRequestReceivedDate AND CAST(e.CodedDiagTimestamp AS DATE)<=sf.ReportingPeriodEndDate)
		THEN DATEDIFF(DD,ReferralRequestReceivedDate,CAST(e.CodedDiagTimestamp AS DATE)) 
		ELSE NULL END 
		AS WaitRefDiag 
		--Works out the difference between referral date and earliest diagnosis date to calculate wait time from referral to earliest diagnosis. This is just for those with a diagnosis date,
		--the diagnosis date has to be after referral date, and the diagnosis date has to be before the reporting period end date
	,CASE WHEN CAST(e.CodedDiagTimestamp AS DATE) between sf.ReportingPeriodStartDate and sf.ReportingPeriodEndDate THEN 1 
		ELSE 0 END 
		AS EarliestDiagDateMonthFlag
	--Creates a flag for use in tableau for wait time graph which only shows wait times for diagnoses within the reporting period in question, rather than for all open referrals.
	,l.[DiagnosisCode] as LatestDementiaDiagnosisCode
	,l.[DiagnosisArea] as LatestDiagnosisArea
	--Latest diagnosis area is used to define the diagnosis area for all charts/tables except for the wait times to diagnosis (uses earliest diagnosis area to go with earliest diagnosis date)
	--This is to give the most up to date diagnosis area
	,CASE WHEN CAST(e.CodedDiagTimestamp AS DATE) >= ReferralRequestReceivedDate THEN 'Diagnosis After Referral' 
		WHEN CAST(e.CodedDiagTimestamp AS DATE)<ReferralRequestReceivedDate THEN 'Diagnosis Before Referral' 
		ELSE 'No Diagnosis' END 
		AS RefToEarliestDiagOrder
	--Defines if diagnosis is given before or after referral or if there is no diagnosis.
INTO [MHDInternal].[TEMP_DEM_MAS_Base]
FROM [MESH_MHSDS].[MHS101Referral] r 
		INNER JOIN [MESH_MHSDS].[MHS001MPI] m ON r.RecordNumber = m.RecordNumber
		LEFT JOIN [MESH_MHSDS].[MHS008CarePlanType] c ON r.RecordNumber = c.RecordNumber
		LEFT JOIN [MESH_MHSDS].[MHS102ServiceTypeReferredTo] s on r.UniqServReqID = s.UniqServReqID AND r.RecordNumber = s.RecordNumber  
		LEFT JOIN [MESH_MHSDS].[MHSDS_SubmissionFlags] sf ON r.NHSEUniqSubmissionID = sf.NHSEUniqSubmissionID AND sf.Der_IsLatest = 'Y'
------------------------------------------------------------------------------------------------------------------		
		----For April 2020 to March 2021 r.Der_Person_ID has to be joined on because it is different to Person_ID before April 2021:
		----LEFT JOIN [MHDInternal].[TEMP_DEM_MAS_Contact] c1 on c1.Person_ID=r.Der_Person_ID and c1.UniqServReqID=r.UniqServReqID
		--For April 2021 onwards r.Person_ID can be joined on as it is the same as Der_Person_ID:
		LEFT JOIN [MHDInternal].[TEMP_DEM_MAS_Contact] c1 on c1.Person_ID=r.Person_ID and c1.UniqServReqID=r.UniqServReqID
----------------------------------------------------------------------------------------------------------------------------------------

		LEFT JOIN [UKHD_Data_Dictionary].[Service_Or_Team_Type_For_Mental_Health_SCD_1] r1 ON s.ServTeamTypeRefToMH = r1.Main_Code_Text AND r1.Is_Latest = 1 
		LEFT JOIN [UKHD_Data_Dictionary].[Reason_For_Referral_To_Mental_Health_SCD_1] r2 ON r.PrimReasonReferralMH = r2.Main_Code_Text AND r2.Is_Latest = 1 
----------------------------------------------------------------------------------------------------------------------------
		--Four tables for getting the up-to-date Sub-ICB/ICB/Region/Provider names/codes:
		LEFT JOIN [Internal_Reference].[ComCodeChanges] cc ON r.OrgIDComm = cc.Org_Code COLLATE database_default
		LEFT JOIN [Reporting].[Ref_ODS_Commissioner_Hierarchies_ICB] ch ON COALESCE(cc.New_Code, r.OrgIDComm) = ch.Organisation_Code COLLATE database_default 
			AND ch.Effective_To IS NULL

		LEFT JOIN [Internal_Reference].[Provider_Successor] ps ON r.[OrgIDProv] = ps.Prov_original COLLATE database_default
		LEFT JOIN [Reporting].[Ref_ODS_Provider_Hierarchies_ICB] ph ON COALESCE(ps.Prov_Successor, r.[OrgIDProv]) = ph.Organisation_Code COLLATE database_default
			AND ph.Effective_To IS NULL
----------------------------------------------------------------------------------------------------------------------------
		LEFT JOIN [MHDInternal].[TEMP_DEM_MAS_DIAG_Ranking] e ON s.UniqServReqID = e.UniqServReqID AND s.Der_Person_ID = e.Der_Person_ID and e.RowIDEarliest=1
		LEFT JOIN [MHDInternal].[TEMP_DEM_MAS_DIAG_Ranking] l ON s.UniqServReqID = l.UniqServReqID AND s.Der_Person_ID = l.Der_Person_ID and l.RowIDLatest=1
WHERE 
sf.ReportingPeriodStartDate IS NOT NULL and sf.[ReportingPeriodStartDate] BETWEEN @PeriodStart2 AND @PeriodStart
GO


--------------------------------------------------------Wait Times Table---------------------------------------------------------
----Table used in tableau to produce boxplots of wait times and the graphs for the proportions of wait times:

DECLARE @RefreshVsFinal varchar='R' --This is no longer needed as we refresh all months every month

INSERT INTO [MHDInternal].[DASHBOARD_DEM_MAS_Wait_Times]
SELECT 
	*
	--For use in tableau to filter the waits reference to diagnosis box plots for just those with a diagnosis
	,CAST(CASE WHEN EarliestDementiaDiagnosisCode IS NOT NULL THEN 1 ELSE 0 END AS varchar) AS DementiaDiagnosis
	--Groups waits into the categories of less than 6 weeks (<=42 days), between 6 and 18 weeks (43 to 126 days) and over 18 weeks (>126 days) for both first contact and diagnosis waits
	--Diagnosis waits use the earliest diagnosis date
    ,CASE WHEN [WaitRefContact]<=42 and [UniqServReqID] is not null THEN 1 ELSE 0 END AS ContactUnder6weeksNumber
	,CASE WHEN [WaitRefContact]>42 AND [WaitRefContact]<=126 and [UniqServReqID] is not null THEN 1 ELSE 0 END AS Contact6to18weeksNumber
	,CASE WHEN [WaitRefContact]>126 and [UniqServReqID] is not null THEN 1 ELSE 0 END AS ContactOver18weeksNumber
	,CASE WHEN [WaitRefContact] IS NOT NULL and [UniqServReqID] is not null THEN 1 ELSE 0 END AS TotalReferralsWithContact

	,CASE WHEN [WaitRefDiag]<=42 and [UniqServReqID] is not null THEN 1 ELSE 0 END AS DiagUnder6weeksNumber
	,CASE WHEN [WaitRefDiag]>42 AND [WaitRefDiag]<=126 and [UniqServReqID] is not null THEN 1 ELSE 0 END AS Diag6to18weeksNumber
	,CASE WHEN [WaitRefDiag]>126 and [UniqServReqID] is not null THEN 1 ELSE 0 END AS DiagOver18weeksNumber
    ,CASE WHEN [WaitRefDiag] IS NOT NULL and [UniqServReqID] is not null THEN 1 ELSE 0 END AS TotalReferralsWithDiag
	,@RefreshVsFinal AS [DataSubmissionType]
	,GETDATE() AS SnapshotDate
FROM [MHDInternal].[TEMP_DEM_MAS_Base]
WHERE [Teamtype]='Memory Services/Clinic/Drop in service' AND [PrimReason]='Organic brain disorder'
GO


DECLARE @RefreshVsFinal varchar='R' --This is no longer needed as we refresh all months every month
----------------------------------------------------------------Main Metrics Table----------------------------------------------------------------------------------------------------
----This table aggregates the main metrics (open referrals, open referrals waiting 1st contact, open referrals with care plan, new referrals, discharges) 
----at different geography levels (Provider, Sub-ICB, ICB, National) for different categories (total, age, gender, ethnicity) and for those with and without a diagnosis of Dementia/MCI

----------------------------------------------------------------------------Provider---------------------------------------------------------------------------------
--Total
INSERT INTO [MHDInternal].[DASHBOARD_DEM_MAS_Main_Metrics]
	SELECT 
		Month
		,cast(OrgIDProv AS varchar(50)) AS OrgCode
		,Provider_Name AS OrgName
		,Prov_Region_Name AS Region 
		,'Provider' AS Orgtype
		,Teamtype
		,PrimReason
		,cast('Total' as varchar(50)) AS 'Category'
		,cast('Total' as varchar(50)) AS 'Variable'
		,LatestDementiaDiagnosisCode AS [Dementia Diagnosis Code]
		,LatestDiagnosisArea
		--the latest diagnosis area is used to provide the most up to date data
		,CASE WHEN [LatestDementiaDiagnosisCode] IS NOT NULL THEN 1 ELSE 0 END AS DementiaDiagnosis 
		--defines if diagnosed or not (the latest diagnosis code is used to provide the most up to date data)
		,SUM(NewRef) AS NewReferrals
		,SUM(OpenRef) AS OpenReferrals
		,SUM(DischRef) AS Discharges
		,SUM(Refwaiting1stcontact) AS OpenWaitingFirstCont
		,SUM(RefwithCarePlanCreated) AS OpenRefwithCarePlanCreated
		,@RefreshVsFinal AS DataSubmissionType
		,GETDATE() AS SnapshotDate --getdate tells us the date the query was run - so we can keep track of it

FROM [MHDInternal].[TEMP_DEM_MAS_Base]	
GROUP BY 
	Month
	,OrgIDProv
	,Provider_Name
	,Prov_Region_Name
	,Teamtype
	,PrimReason
	,LatestDementiaDiagnosisCode
	,LatestDiagnosisArea
	,CASE WHEN LatestDementiaDiagnosisCode IS NOT NULL THEN 1 ELSE 0 END
	-------------------------------------
--Age Group

INSERT INTO [MHDInternal].[DASHBOARD_DEM_MAS_Main_Metrics]
SELECT
	Month
	,OrgIDProv AS OrgCode
	,Provider_Name AS OrgName
	,Prov_Region_Name AS Region
	,'Provider' AS Orgtype
	,Teamtype
	,PrimReason
	,'Age Group' AS 'Category'
	,CASE WHEN AgeServReferRecDate < 65 THEN 'Under65'
		WHEN AgeServReferRecDate BETWEEN 65 AND 74 THEN '65to74'
		WHEN AgeServReferRecDate BETWEEN 75 AND 84 THEN '75to84'
		WHEN AgeServReferRecDate >= 85 THEN '85+' 
		ELSE 'Unknown/Not Stated' 
	END AS 'Variable'
	,LatestDementiaDiagnosisCode AS [Dementia Diagnosis Code]
	,LatestDiagnosisArea
	--the latest diagnosis area is used to provide the most up to date data
	,CASE WHEN [LatestDementiaDiagnosisCode] IS NOT NULL THEN 1 ELSE 0 END AS DementiaDiagnosis
	--defines if diagnosed or not (the latest diagnosis code is used to provide the most up to date data)
	,SUM(NewRef) AS NewReferrals
	,SUM(OpenRef) AS OpenReferrals
	,SUM(DischRef) AS Discharges
	,SUM(Refwaiting1stcontact) AS OpenWaitingFirstCont
	,SUM(RefwithCarePlanCreated) AS OpenRefwithCarePlanCreated
	,@RefreshVsFinal AS DataSubmissionType
	,GETDATE() AS SnapshotDate --getdate tells us the date the query was run - so we can keep track of it
FROM [MHDInternal].[TEMP_DEM_MAS_Base]		
GROUP BY 
	Month
	,OrgIDProv
	,Provider_Name
	,Prov_Region_Name
	,Teamtype
	,PrimReason
	,CASE WHEN AgeServReferRecDate < 65 THEN 'Under65'
		WHEN AgeServReferRecDate BETWEEN 65 AND 74 THEN '65to74'
		WHEN AgeServReferRecDate BETWEEN 75 AND 84 THEN '75to84'
		WHEN AgeServReferRecDate >= 85 THEN '85+' 
		ELSE 'Unknown/Not Stated' END
	,LatestDementiaDiagnosisCode
	,LatestDiagnosisArea
	,CASE WHEN [LatestDementiaDiagnosisCode] IS NOT NULL THEN 1 ELSE 0 END
	

--Gender
INSERT INTO [MHDInternal].[DASHBOARD_DEM_MAS_Main_Metrics]
SELECT 
	Month
	,OrgIDProv AS OrgCode
	,Provider_Name AS OrgName
	,Prov_Region_Name AS Region
	,'Provider' AS Orgtype 
	,[Teamtype]
	,PrimReason
	,'Gender' AS 'Category'
	,CASE WHEN Gender = '1' THEN 'Males'
		WHEN Gender = '2' THEN 'Females'
		ELSE 'Other/Not Stated/Not Known' 
	END AS 'Variable'
	,LatestDementiaDiagnosisCode AS [Dementia Diagnosis Code]
	,LatestDiagnosisArea
	--the latest diagnosis area is used to provide the most up to date data
	,CASE WHEN [LatestDementiaDiagnosisCode] IS NOT NULL THEN 1 ELSE 0 END AS DementiaDiagnosis 
	--defines if diagnosed or not (the latest diagnosis code is used to provide the most up to date data)
	,SUM(NewRef) AS NewReferrals
	,SUM(OpenRef) AS OpenReferrals
	,SUM(DischRef) AS Discharges
	,SUM(Refwaiting1stcontact) AS OpenWaitingFirstCont
	,SUM(RefwithCarePlanCreated) AS OpenRefwithCarePlanCreated
	,@RefreshVsFinal AS DataSubmissionType
	,GETDATE() AS SnapshotDate --getdate tells us the date the query was run - so we can keep track of it
FROM [MHDInternal].[TEMP_DEM_MAS_Base]	
GROUP BY 
	Month
	,OrgIDProv
	,Provider_Name
	,Prov_Region_Name
	,Teamtype
	,PrimReason
	,CASE WHEN Gender = '1' THEN 'Males'
		WHEN Gender = '2' THEN 'Females'
		ELSE 'Other/Not Stated/Not Known' END
	,LatestDementiaDiagnosisCode
	,LatestDiagnosisArea
	,CASE WHEN [LatestDementiaDiagnosisCode] IS NOT NULL THEN 1 ELSE 0 END
	

--Ethnicity
INSERT INTO [MHDInternal].[DASHBOARD_DEM_MAS_Main_Metrics]
SELECT 
	Month
	,OrgIDProv AS OrgCode
	,Provider_Name AS OrgName
	,Prov_Region_Name AS Region
	,'Provider' AS Orgtype
	,Teamtype
	,PrimReason
	,'Ethnicity' AS 'Category'
	,CASE WHEN EthnicCategory IN ('A','B','C') THEN 'White'
		WHEN EthnicCategory IN ('D','E','F','G') THEN 'Mixed'
		WHEN EthnicCategory IN ('H','J','K','L') THEN 'Asian'
		WHEN EthnicCategory IN ('M','N','P') THEN 'Black'
		WHEN EthnicCategory IN ('R','S') THEN 'Other'
		ELSE 'Not Stated/Not Known' 
	END AS 'Variable'
	,LatestDementiaDiagnosisCode AS [Dementia Diagnosis Code]
	,LatestDiagnosisArea
	--the latest diagnosis area is used to provide the most up to date data
	,CASE WHEN [LatestDementiaDiagnosisCode] IS NOT NULL THEN 1 ELSE 0 END AS DementiaDiagnosis 
	--defines if diagnosed or not (the latest diagnosis code is used to provide the most up to date data)
	,SUM(NewRef) AS NewReferrals
	,SUM(OpenRef) AS OpenReferrals
	,SUM(DischRef) AS Discharges
	,SUM(Refwaiting1stcontact) AS OpenWaitingFirstCont
	,SUM(RefwithCarePlanCreated) AS OpenRefwithCarePlanCreated
	,@RefreshVsFinal AS DataSubmissionType
	,GETDATE() AS SnapshotDate --getdate tells us the date the query was run - so we can keep track of it
FROM [MHDInternal].[TEMP_DEM_MAS_Base]
GROUP BY 
	Month
	,OrgIDProv
	,[Provider_Name]
	,Prov_Region_Name
	,Teamtype
	,PrimReason
	,CASE WHEN EthnicCategory IN ('A','B','C') THEN 'White'
		WHEN EthnicCategory IN ('D','E','F','G') THEN 'Mixed'
		WHEN EthnicCategory IN ('H','J','K','L') THEN 'Asian'
		WHEN EthnicCategory IN ('M','N','P') THEN 'Black'
		WHEN EthnicCategory IN ('R','S') THEN 'Other'
		ELSE 'Not Stated/Not Known' END
	,[LatestDementiaDiagnosisCode]
	,[LatestDiagnosisArea]
	,CASE WHEN [LatestDementiaDiagnosisCode] IS NOT NULL THEN 1 ELSE 0 END 
	

------------------------------------------------------Sub-ICB------------------------------------------------------
--Total
INSERT INTO [MHDInternal].[DASHBOARD_DEM_MAS_Main_Metrics]
SELECT 
	Month 
	,[OrgIDComm] AS OrgCode
	,[Sub_ICB_Name] AS OrgName
	,Comm_Region_Name AS Region
	,'Sub-ICB' AS Orgtype
	,[Teamtype]
	,PrimReason
	,'Total' AS 'Category'
	,'Total' AS 'Variable'
	,LatestDementiaDiagnosisCode AS [Dementia Diagnosis Code]
	,LatestDiagnosisArea
	--the latest diagnosis area is used to provide the most up to date data
	,CASE WHEN [LatestDementiaDiagnosisCode] IS NOT NULL THEN 1 ELSE 0 END AS DementiaDiagnosis
	--defines if diagnosed or not (the latest diagnosis code is used to provide the most up to date data)
	,SUM(NewRef) AS NewReferrals
	,SUM(OpenRef) AS OpenReferrals
	,SUM(DischRef) AS Discharges
	,SUM(Refwaiting1stcontact) AS OpenWaitingFirstCont
	,SUM(RefwithCarePlanCreated) AS OpenRefwithCarePlanCreated
	,@RefreshVsFinal AS DataSubmissionType
	,GETDATE() AS SnapshotDate --getdate tells us the date the query was run - so we can keep track of it
FROM [MHDInternal].[TEMP_DEM_MAS_Base]  				
GROUP BY 
	Month
	,[OrgIDComm]
	,[Sub_ICB_Name]
	,[Comm_Region_Name]
	,Teamtype
	,PrimReason
	,LatestDementiaDiagnosisCode
	,LatestDiagnosisArea
	,CASE WHEN [LatestDementiaDiagnosisCode] IS NOT NULL THEN 1 ELSE 0 END
	
--Age Group
INSERT INTO [MHDInternal].[DASHBOARD_DEM_MAS_Main_Metrics]
SELECT 
	Month
	,[OrgIDComm] AS OrgCode
	,[Sub_ICB_Name] AS OrgName
	,[Comm_Region_Name] AS Region
	,'Sub-ICB' AS Orgtype
	,[Teamtype] 
	,PrimReason
	,'Age Group' AS 'Category'
	,CASE WHEN AgeServReferRecDate < 65 THEN 'Under65'
		WHEN AgeServReferRecDate BETWEEN 65 AND 74 THEN '65to74'
		WHEN AgeServReferRecDate BETWEEN 75 AND 84 THEN '75to84'
		WHEN AgeServReferRecDate >= 85 THEN '85+' 
		ELSE 'Unknown/Not Stated' 
	END AS 'Variable'
	,LatestDementiaDiagnosisCode AS [Dementia Diagnosis Code]
	,LatestDiagnosisArea
	--the latest diagnosis area is used to provide the most up to date data
	,CASE WHEN [LatestDementiaDiagnosisCode] IS NOT NULL THEN 1 ELSE 0 END AS DementiaDiagnosis
	--defines if diagnosed or not (the latest diagnosis code is used to provide the most up to date data)
	,SUM(NewRef) AS NewReferrals
	,SUM(OpenRef) AS OpenReferrals
	,SUM(DischRef) AS Discharges
	,SUM(Refwaiting1stcontact) AS OpenWaitingFirstCont
	,SUM(RefwithCarePlanCreated) AS OpenRefwithCarePlanCreated
	,@RefreshVsFinal AS DataSubmissionType
	,GETDATE() AS SnapshotDate --getdate tells us the date the query was run - so we can keep track of it
FROM [MHDInternal].[TEMP_DEM_MAS_Base]  					
GROUP BY 
	Month
	,[OrgIDComm]
	,[Sub_ICB_Name]
	,[Comm_Region_Name]
	,Teamtype
	,PrimReason
	,CASE WHEN AgeServReferRecDate < 65 THEN 'Under65'
		WHEN AgeServReferRecDate BETWEEN 65 AND 74 THEN '65to74'
		WHEN AgeServReferRecDate BETWEEN 75 AND 84 THEN '75to84'
		WHEN AgeServReferRecDate >= 85 THEN '85+' 
		ELSE 'Unknown/Not Stated' END
	,LatestDementiaDiagnosisCode
	,LatestDiagnosisArea
	,CASE WHEN [LatestDementiaDiagnosisCode] IS NOT NULL THEN 1 ELSE 0 END

-- Gender
INSERT INTO [MHDInternal].[DASHBOARD_DEM_MAS_Main_Metrics]
SELECT 
	Month
	,[OrgIDComm] AS OrgCode
	,[Sub_ICB_Name] AS OrgName
	,Comm_Region_Name AS Region
	,'Sub-ICB' AS Orgtype 
	,Teamtype 
	,PrimReason
	,'Gender' AS 'Category'
	,CASE WHEN Gender = '1' THEN 'Males'
		WHEN Gender = '2' THEN 'Females'
		ELSE 'Other/Not Stated/Not Known' 
	END AS 'Variable'
	,LatestDementiaDiagnosisCode AS [Dementia Diagnosis Code]
	,LatestDiagnosisArea
	--the latest diagnosis area is used to provide the most up to date data
	,CASE WHEN [LatestDementiaDiagnosisCode] IS NOT NULL THEN 1 ELSE 0 END AS DementiaDiagnosis
	--defines if diagnosed or not (the latest diagnosis code is used to provide the most up to date data)
	,SUM(NewRef) AS NewReferrals
	,SUM(OpenRef) AS OpenReferrals
	,SUM(DischRef) AS Discharges
	,SUM(Refwaiting1stcontact) AS OpenWaitingFirstCont
	,SUM(RefwithCarePlanCreated) AS OpenRefwithCarePlanCreated
	,@RefreshVsFinal AS DataSubmissionType
	,GETDATE() AS SnapshotDate --getdate tells us the date the query was run - so we can keep track of it
FROM [MHDInternal].[TEMP_DEM_MAS_Base]  				
GROUP BY 
	Month
	,[OrgIDComm]
	,[Sub_ICB_Name]
	,Comm_Region_Name
	,Teamtype
	,PrimReason
	,CASE WHEN Gender = '1' THEN 'Males'
		WHEN Gender = '2' THEN 'Females'
		ELSE 'Other/Not Stated/Not Known' END
	,LatestDementiaDiagnosisCode
	,LatestDiagnosisArea
	,CASE WHEN [LatestDementiaDiagnosisCode] IS NOT NULL THEN 1 ELSE 0 END

--Ethnicity
INSERT INTO [MHDInternal].[DASHBOARD_DEM_MAS_Main_Metrics]
SELECT 
	Month
	,[OrgIDComm] AS OrgCode
	,[Sub_ICB_Name] AS OrgName
	,Comm_Region_Name AS Region
	,'Sub-ICB' AS Orgtype
	,Teamtype
	,PrimReason
	,'Ethnicity' AS 'Category'
	,CASE WHEN EthnicCategory IN ('A','B','C') THEN 'White'
		WHEN EthnicCategory IN ('D','E','F','G') THEN 'Mixed'
		WHEN EthnicCategory IN ('H','J','K','L') THEN 'Asian'
		WHEN EthnicCategory IN ('M','N','P') THEN 'Black'
		WHEN EthnicCategory IN ('R','S') THEN 'Other'
		ELSE 'Not Stated/Not Known' 
	END AS 'Variable'
	,LatestDementiaDiagnosisCode AS [Dementia Diagnosis Code]
	,LatestDiagnosisArea
	--the latest diagnosis area is used to provide the most up to date data
	,CASE WHEN [LatestDementiaDiagnosisCode] IS NOT NULL THEN 1 ELSE 0 END AS DementiaDiagnosis
	--defines if diagnosed or not (the latest diagnosis code is used to provide the most up to date data)
	,SUM(NewRef) AS NewReferrals
	,SUM(OpenRef) AS OpenReferrals
	,SUM(DischRef) AS Discharges
	,SUM(Refwaiting1stcontact) AS OpenWaitingFirstCont
	,SUM(RefwithCarePlanCreated) AS OpenRefwithCarePlanCreated
	,@RefreshVsFinal AS DataSubmissionType
	,GETDATE() AS SnapshotDate --getdate tells us the date the query was run - so we can keep track of it
FROM [MHDInternal].[TEMP_DEM_MAS_Base]  				
GROUP BY 
	Month
	,[OrgIDComm]
	,[Sub_ICB_Name]
	,Comm_Region_Name
	,Teamtype 
	,PrimReason
	,CASE WHEN EthnicCategory IN ('A','B','C') THEN 'White'
		WHEN EthnicCategory IN ('D','E','F','G') THEN 'Mixed'
		WHEN EthnicCategory IN ('H','J','K','L') THEN 'Asian'
		WHEN EthnicCategory IN ('M','N','P') THEN 'Black'
		WHEN EthnicCategory IN ('R','S') THEN 'Other'
		ELSE 'Not Stated/Not Known' END
	,LatestDementiaDiagnosisCode
	,LatestDiagnosisArea
	,CASE WHEN [LatestDementiaDiagnosisCode] IS NOT NULL THEN 1 ELSE 0 END
	
--------------------------------------------------------------------National-----------------------------------------------------------------------------------
--Total
INSERT INTO [MHDInternal].[DASHBOARD_DEM_MAS_Main_Metrics]
SELECT 
	Month
	,'England' AS OrgCode
	,'England' AS OrgName
	,'All Regions' AS Region
	,'National' AS Orgtype
	,Teamtype
	,PrimReason
	,'Total' AS 'Category'
	,'Total' AS 'Variable'
	,LatestDementiaDiagnosisCode AS [Dementia Diagnosis Code]
	,LatestDiagnosisArea
	--the latest diagnosis area is used to provide the most up to date data
	,CASE WHEN [LatestDementiaDiagnosisCode] IS NOT NULL THEN 1 ELSE 0 END AS DementiaDiagnosis
	--defines if diagnosed or not (the latest diagnosis code is used to provide the most up to date data)
	,SUM(NewRef) AS NewReferrals
	,SUM(OpenRef) AS OpenReferrals
	,SUM(DischRef) AS Discharges
	,SUM(Refwaiting1stcontact) AS OpenWaitingFirstCont
	,SUM(RefwithCarePlanCreated) AS OpenRefwithCarePlanCreated
	,@RefreshVsFinal AS DataSubmissionType
	,GETDATE() AS SnapshotDate --getdate tells us the date the query was run - so we can keep track of it
FROM [MHDInternal].[TEMP_DEM_MAS_Base]  
GROUP BY 
	Month
	,Teamtype
	,PrimReason
	,LatestDementiaDiagnosisCode
	,LatestDiagnosisArea
	,CASE WHEN [LatestDementiaDiagnosisCode] IS NOT NULL THEN 1 ELSE 0 END
		
--Age Group
INSERT INTO [MHDInternal].[DASHBOARD_DEM_MAS_Main_Metrics]
SELECT
	Month 
	,'England' AS OrgCode
	,'England' AS OrgName
	,'All Regions' AS Region
	,'National' AS Orgtype
	,Teamtype
	,PrimReason
	,'Age Group' AS 'Category'
	,CASE WHEN AgeServReferRecDate < 65 THEN 'Under65'
		WHEN AgeServReferRecDate BETWEEN 65 AND 74 THEN '65to74'
		WHEN AgeServReferRecDate BETWEEN 75 AND 84 THEN '75to84'
		WHEN AgeServReferRecDate >= 85 THEN '85+' 
		ELSE 'Unknown/Not Stated' 
	END AS 'Variable'
	,LatestDementiaDiagnosisCode AS [Dementia Diagnosis Code]
	,LatestDiagnosisArea
	--the latest diagnosis area is used to provide the most up to date data
	,CASE WHEN [LatestDementiaDiagnosisCode] IS NOT NULL THEN 1 ELSE 0 END AS DementiaDiagnosis
	--defines if diagnosed or not (the latest diagnosis code is used to provide the most up to date data)
	,SUM(NewRef) AS NewReferrals
	,SUM(OpenRef) AS OpenReferrals
	,SUM(DischRef) AS Discharges
	,SUM(Refwaiting1stcontact) AS OpenWaitingFirstCont
	,SUM(RefwithCarePlanCreated) AS OpenRefwithCarePlanCreated
	,@RefreshVsFinal AS DataSubmissionType
	,GETDATE() AS SnapshotDate --getdate tells us the date the query was run - so we can keep track of it
FROM [MHDInternal].[TEMP_DEM_MAS_Base]  
GROUP BY 
	Month
	,Teamtype
	,PrimReason
	,CASE WHEN AgeServReferRecDate < 65 THEN 'Under65'
		WHEN AgeServReferRecDate BETWEEN 65 AND 74 THEN '65to74'
		WHEN AgeServReferRecDate BETWEEN 75 AND 84 THEN '75to84'
		WHEN AgeServReferRecDate >= 85 THEN '85+' 
		ELSE 'Unknown/Not Stated' END
	,LatestDementiaDiagnosisCode
	,LatestDiagnosisArea
	,CASE WHEN [LatestDementiaDiagnosisCode] IS NOT NULL THEN 1 ELSE 0 END

--Gender
INSERT INTO [MHDInternal].[DASHBOARD_DEM_MAS_Main_Metrics]
SELECT 
	Month 
	,'England' AS OrgCode
	,'England' AS OrgName
	,'All Regions' AS Region
	,'National' AS Orgtype
	,Teamtype 
	,PrimReason
	,'Gender' AS 'Category'
	,CASE WHEN Gender = '1' THEN 'Males'
		WHEN Gender = '2' THEN 'Females'
		ELSE 'Other/Not Stated/Not Known' END AS 'Variable'
	,LatestDementiaDiagnosisCode AS [Dementia Diagnosis Code]
	,LatestDiagnosisArea
	--the latest diagnosis area is used to provide the most up to date data
	,CASE WHEN [LatestDementiaDiagnosisCode] IS NOT NULL THEN 1 ELSE 0 END AS DementiaDiagnosis
	--defines if diagnosed or not (the latest diagnosis code is used to provide the most up to date data)
	,SUM(NewRef) AS NewReferrals
	,SUM(OpenRef) AS OpenReferrals
	,SUM(DischRef) AS Discharges
	,SUM(Refwaiting1stcontact) AS OpenWaitingFirstCont
	,SUM(RefwithCarePlanCreated) AS OpenRefwithCarePlanCreated
	,@RefreshVsFinal AS DataSubmissionType
	,GETDATE() AS SnapshotDate --getdate tells us the date the query was run - so we can keep track of it
FROM [MHDInternal].[TEMP_DEM_MAS_Base]  
GROUP BY
	Month
	,Teamtype
	,PrimReason
	,CASE WHEN Gender = '1' THEN 'Males'
		WHEN Gender = '2' THEN 'Females'
		ELSE 'Other/Not Stated/Not Known' END
	,LatestDementiaDiagnosisCode
	,LatestDiagnosisArea
	,CASE WHEN [LatestDementiaDiagnosisCode] IS NOT NULL THEN 1 ELSE 0 END

--Ethnicity
INSERT INTO [MHDInternal].[DASHBOARD_DEM_MAS_Main_Metrics]
SELECT 
	Month
	,'England' AS OrgCode
	,'England' AS OrgName
	,'All Regions' AS Region
	,'National' AS Orgtype
	,Teamtype 
	,PrimReason
	,'Ethnicity' AS 'Category'
	,CASE WHEN EthnicCategory IN ('A','B','C') THEN 'White'
		WHEN EthnicCategory IN ('D','E','F','G') THEN 'Mixed'
		WHEN EthnicCategory IN ('H','J','K','L') THEN 'Asian'
		WHEN EthnicCategory IN ('M','N','P') THEN 'Black'
		WHEN EthnicCategory IN ('R','S') THEN 'Other'
		ELSE 'Not Stated/Not Known' 
	END AS 'Variable'
	,LatestDementiaDiagnosisCode AS [Dementia Diagnosis Code]
	,LatestDiagnosisArea
	--the latest diagnosis area is used to provide the most up to date data
	,CASE WHEN [LatestDementiaDiagnosisCode] IS NOT NULL THEN 1 ELSE 0 END AS DementiaDiagnosis 
	--defines if diagnosed or not (the latest diagnosis code is used to provide the most up to date data)
	,SUM(NewRef) AS NewReferrals
	,SUM(OpenRef) AS OpenReferrals
	,SUM(DischRef) AS Discharges
	,SUM(Refwaiting1stcontact) AS OpenWaitingFirstCont
	,SUM(RefwithCarePlanCreated) AS OpenRefwithCarePlanCreated
	,@RefreshVsFinal AS DataSubmissionType
	,GETDATE() AS SnapshotDate --getdate tells us the date the query was run - so we can keep track of it
FROM [MHDInternal].[TEMP_DEM_MAS_Base]  
GROUP BY 
	Month
	,Teamtype
	,PrimReason
	,CASE WHEN EthnicCategory IN ('A','B','C') THEN 'White'
		WHEN EthnicCategory IN ('D','E','F','G') THEN 'Mixed'
		WHEN EthnicCategory IN ('H','J','K','L') THEN 'Asian'
		WHEN EthnicCategory IN ('M','N','P') THEN 'Black'
		WHEN EthnicCategory IN ('R','S') THEN 'Other'
		ELSE 'Not Stated/Not Known' END
	,LatestDementiaDiagnosisCode
	,LatestDiagnosisArea
	,CASE WHEN [LatestDementiaDiagnosisCode] IS NOT NULL THEN 1 ELSE 0 END
--------------------------------------------------------------------------ICB-------------------------------------------------------------
--Total
INSERT INTO [MHDInternal].[DASHBOARD_DEM_MAS_Main_Metrics]
SELECT 
	Month 
	,ICB_Code AS OrgCode
	,ICB_Name AS OrgName
	,Comm_Region_Name AS Region
	,'ICB' AS Orgtype
	,Teamtype
	,PrimReason
	,'Total' AS 'Category'
	,'Total' AS 'Variable'
	,LatestDementiaDiagnosisCode AS [Dementia Diagnosis Code]
	,LatestDiagnosisArea
	--the latest diagnosis area is used to provide the most up to date data
	,CASE WHEN [LatestDementiaDiagnosisCode] IS NOT NULL THEN 1 ELSE 0 END AS DementiaDiagnosis 
	--defines if diagnosed or not (the latest diagnosis code is used to provide the most up to date data)
	,SUM(NewRef) AS NewReferrals
	,SUM(OpenRef) AS OpenReferrals
	,SUM(DischRef) AS Discharges
	,SUM(Refwaiting1stcontact) AS OpenWaitingFirstCont
	,SUM(RefwithCarePlanCreated) AS OpenRefwithCarePlanCreated
	,@RefreshVsFinal AS DataSubmissionType
	,GETDATE() AS SnapshotDate --getdate tells us the date the query was run - so we can keep track of it
FROM [MHDInternal].[TEMP_DEM_MAS_Base]  			
GROUP BY 
	Month
	,ICB_Code
	,ICB_Name
	,Comm_Region_Name
	,Teamtype
	,PrimReason
	,LatestDementiaDiagnosisCode
	,LatestDiagnosisArea
	,CASE WHEN [LatestDementiaDiagnosisCode] IS NOT NULL THEN 1 ELSE 0 END

--Age Group
INSERT INTO [MHDInternal].[DASHBOARD_DEM_MAS_Main_Metrics]
SELECT 
	Month
	,ICB_Code AS OrgCode
	,ICB_Name AS OrgName
	,Comm_Region_Name AS Region
	,'ICB' AS Orgtype
	,Teamtype 
	,PrimReason
	,'Age Group' AS 'Category'
	,CASE WHEN AgeServReferRecDate < 65 THEN 'Under65'
		WHEN AgeServReferRecDate BETWEEN 65 AND 74 THEN '65to74'
		WHEN AgeServReferRecDate BETWEEN 75 AND 84 THEN '75to84'
		WHEN AgeServReferRecDate >= 85 THEN '85+' 
		ELSE 'Unknown/Not Stated' 
	END AS 'Variable'
	,LatestDementiaDiagnosisCode AS [Dementia Diagnosis Code]
	,LatestDiagnosisArea
	--the latest diagnosis area is used to provide the most up to date data
	,CASE WHEN [LatestDementiaDiagnosisCode] IS NOT NULL THEN 1 ELSE 0 END AS DementiaDiagnosis 
	--defines if diagnosed or not (the latest diagnosis code is used to provide the most up to date data)
	,SUM(NewRef) AS NewReferrals
	,SUM(OpenRef) AS OpenReferrals
	,SUM(DischRef) AS Discharges
	,SUM(Refwaiting1stcontact) AS OpenWaitingFirstCont
	,SUM(RefwithCarePlanCreated) AS OpenRefwithCarePlanCreated
	,@RefreshVsFinal AS DataSubmissionType
	,GETDATE() AS SnapshotDate --getdate tells us the date the query was run - so we can keep track of it
FROM [MHDInternal].[TEMP_DEM_MAS_Base]  				
GROUP BY 
	Month
	,ICB_Code
	,ICB_Name
	,Comm_Region_Name
	,Teamtype 
	,PrimReason
	,CASE WHEN AgeServReferRecDate < 65 THEN 'Under65'
		WHEN AgeServReferRecDate BETWEEN 65 AND 74 THEN '65to74'
		WHEN AgeServReferRecDate BETWEEN 75 AND 84 THEN '75to84'
		WHEN AgeServReferRecDate >= 85 THEN '85+' 
		ELSE 'Unknown/Not Stated' END
	,LatestDementiaDiagnosisCode
	,LatestDiagnosisArea
	,CASE WHEN [LatestDementiaDiagnosisCode] IS NOT NULL THEN 1 ELSE 0 END

--Gender 
INSERT INTO [MHDInternal].[DASHBOARD_DEM_MAS_Main_Metrics]
SELECT 
	Month
	,ICB_Code AS OrgCode
	,ICB_Name AS OrgName
	,Comm_Region_Name AS Region
	,'ICB' AS Orgtype 
	,Teamtype
	,PrimReason
	,'Gender' AS 'Category'
	,CASE WHEN Gender = '1' THEN 'Males'
		WHEN Gender = '2' THEN 'Females'
		ELSE 'Other/Not Stated/Not Known' 
	END AS 'Variable'
	,LatestDementiaDiagnosisCode AS [Dementia Diagnosis Code]
	,LatestDiagnosisArea
	--the latest diagnosis area is used to provide the most up to date data
	,CASE WHEN [LatestDementiaDiagnosisCode] IS NOT NULL THEN 1 ELSE 0 END AS DementiaDiagnosis 
	--defines if diagnosed or not (the latest diagnosis code is used to provide the most up to date data)
	,SUM(NewRef) AS NewReferrals
	,SUM(OpenRef) AS OpenReferrals
	,SUM(DischRef) AS Discharges
	,SUM(Refwaiting1stcontact) AS OpenWaitingFirstCont
	,SUM(RefwithCarePlanCreated) AS OpenRefwithCarePlanCreated
	,@RefreshVsFinal AS DataSubmissionType
	,GETDATE() AS SnapshotDate --getdate tells us the date the query was run - so we can keep track of it
FROM [MHDInternal].[TEMP_DEM_MAS_Base]  				
GROUP BY 
	Month
	,ICB_Code
	,ICB_Name
	,Comm_Region_Name
	,Teamtype
	,PrimReason
	,CASE WHEN Gender = '1' THEN 'Males'
		WHEN Gender = '2' THEN 'Females'
		ELSE 'Other/Not Stated/Not Known' END
	,LatestDementiaDiagnosisCode
	,LatestDiagnosisArea
	,CASE WHEN [LatestDementiaDiagnosisCode] IS NOT NULL THEN 1 ELSE 0 END

--Ethnicity
INSERT INTO [MHDInternal].[DASHBOARD_DEM_MAS_Main_Metrics]
SELECT
	Month 
	,ICB_Code AS OrgCode
	,ICB_Name AS OrgName
	,Comm_Region_Name AS Region
	,'ICB' AS Orgtype
	,Teamtype
	,PrimReason
	,'Ethnicity' AS 'Category'
	,CASE WHEN EthnicCategory IN ('A','B','C') THEN 'White'
		WHEN EthnicCategory IN ('D','E','F','G') THEN 'Mixed'
		WHEN EthnicCategory IN ('H','J','K','L') THEN 'Asian'
		WHEN EthnicCategory IN ('M','N','P') THEN 'Black'
		WHEN EthnicCategory IN ('R','S') THEN 'Other'
		ELSE 'Not Stated/Not Known' 
	END AS 'Variable'
	,LatestDementiaDiagnosisCode AS [Dementia Diagnosis Code]
	,LatestDiagnosisArea
	--the latest diagnosis area is used to provide the most up to date data
	,CASE WHEN [LatestDementiaDiagnosisCode] IS NOT NULL THEN 1 ELSE 0 END AS DementiaDiagnosis 
	--defines if diagnosed or not (the latest diagnosis code is used to provide the most up to date data)
	,SUM(NewRef) AS NewReferrals
	,SUM(OpenRef) AS OpenReferrals
	,SUM(DischRef) AS Discharges
	,SUM(Refwaiting1stcontact) AS OpenWaitingFirstCont
	,SUM(RefwithCarePlanCreated) AS OpenRefwithCarePlanCreated
	,@RefreshVsFinal AS DataSubmissionType
	,GETDATE() AS SnapshotDate --getdate tells us the date the query was run - so we can keep track of it	
FROM [MHDInternal].[TEMP_DEM_MAS_Base]  					
GROUP BY 
	Month
	,ICB_Code
	,ICB_Name
	,Comm_Region_Name
	,Teamtype
	,PrimReason
	,CASE WHEN EthnicCategory IN ('A','B','C') THEN 'White'
		WHEN EthnicCategory IN ('D','E','F','G') THEN 'Mixed'
		WHEN EthnicCategory IN ('H','J','K','L') THEN 'Asian'
		WHEN EthnicCategory IN ('M','N','P') THEN 'Black'
		WHEN EthnicCategory IN ('R','S') THEN 'Other'
		ELSE 'Not Stated/Not Known' END
	,LatestDementiaDiagnosisCode
	,LatestDiagnosisArea
	,CASE WHEN [LatestDementiaDiagnosisCode] IS NOT NULL THEN 1 ELSE 0 END
-------------------------------------------------End of Step 3----------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------Step 4------------------------------------------------------------------------------------

--Drops temporary tables used in the query
--DROP TABLE [MHDInternal].[TEMP_DEM_MAS_DIAG]
--DROP TABLE [MHDInternal].[TEMP_DEM_MAS_DIAG_Ranking]
--DROP TABLE [MHDInternal].[TEMP_DEM_MAS_Contact]
--DROP TABLE [MHDInternal].[TEMP_DEM_MAS_Base]



---------------------------------------------End of Step 4--------------------------------------------------------------------------
---------------------------------------------------------End of Script--------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------

