/****** Script for Memory Assessment Services Dashboard for calculating the following: 
		open referrals, open referrals with no contact, open referrals with a care plan, new referrals, discharges, 
		wait times from referral to first contact, and wait times from referral to diagnosis ******/

-----------------------------------------------Step 1------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------Diagnosis Table--------------------------------------------------------
-- Creates a table for anyone with a primary (i.e. the diagnosis listed first) or secondary (i.e. the diagnosis listed second) diagnosis of dementia as defined by the codes in the Dementia guidance
--This means that people with only a secondary diagnosis of dementia will be picked up, as well as those with a primary diagnosis
--All diagnosis dates are included in this table as we are interested in the earliest (for wait times to diagnosis) and latest diagnoses (for everything else). 
--The next table ([NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_MAS_DIAG_Ranking]) ranks the diagnosis dates for use later in the script
 IF OBJECT_ID ('[NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_MAS_DIAG]') IS NOT NULL DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_MAS_DIAG]

SELECT DISTINCT 
	a.Der_Person_ID
	,a.UniqServReqID
	,a.CodedDiagTimestamp
	,CASE WHEN PrimDiag IS NOT NULL THEN a.PrimDiag
		ELSE SecDiag
		END AS [DiagnosisCode]
	,CASE WHEN PrimDiag IS NOT NULL THEN 'Primary'
		ELSE 'Secondary' 
		END AS Position
	,CASE WHEN PrimDiag IS NOT NULL THEN a.[Diagnosis Area] ELSE b.[Diagnosis Area]
	END AS [DiagnosisArea]
INTO [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_MAS_DIAG]
FROM
(
SELECT DISTINCT
	PrimDiag
	,Der_Person_ID
	,UniqServReqID
	,CodedDiagTimestamp
	,CASE WHEN PrimDiag IN ('F06.7','F067','386805003','28E0.','Xaagi') THEN 'MCI'
	ELSE 'Dementia' END AS 'Diagnosis Area'
FROM [NHSE_MHSDS].[dbo].[MHS604PrimDiag] p
WHERE
(p.[PrimDiag] IN

(--Dementia ICD10 codes Page 13 of Dementia Care Pathway Appendices
'F00.0','F00.1','F00.2','F00.9','F01.0','F01.1','F01.2','F01.3','F01.8','F01.9','F02.0','F02.1','F02.2','F02.3','F02.4','F02.8','F03','F05.1'
,'F000','F001','F002','F009','F010','F011','F012','F013','F018','F019','F020','F021','F022','F023','F024','F028','F051'

--This Dagger code is included as it is required in combination with F02.8 to identify Lewy body disease. 
--We are unable to filter MHSDS for those with both F02.8 AND G31.8 so have to filter for those with either F02.8 or G31.8
,'G318','G31.8'

--Dementia SNOMED codes Page 14 of Dementia Care Pathway Appendices
,'52448006','15662003','191449005','191457008','191461002','231438001','268612007','45864009','26929004','416780008','416975007','4169750 07','429998004','230285003'
,'56267009','230286002','230287006','230270009','230273006','90099008','230280008','86188000','13092008','21921000119103','429458009','442344002','792004'
,'713060000','425390006'
--Dementia SNOMED codes Page 15 of Dementia Care Pathway Appendices
,'713844000','191475009','80098002','312991009','135811000119107','13 5 8110 0 0119107','42769004','191519005','281004','191493005','111480006','1114 8 0 0 0 6'
,'32875003','59651006','278857002','230269008','79341000119107','12348006','421023003','713488003','191452002','65096006','31081000119101','191455000'
,'1089501000000102','10532003','191454001','230267005','230268000','230265002'
--Dementia SNOMED codes Page 16 of Dementia Care Pathway Appendices
,'230266001','191451009','1914510 09','22381000119105','230288001','191458003','191459006','191463004','191464005','191465006','191466007','279982005','6475002'
,'66108005'
	
--Dementia Read code v2 on Page 17 of Dementia Care Pathway Appendices
,'E00..%','E0 0..%','Eu01.%','Eu 01.%','Eu02.%','Eu 02.%','E012.%','Eu00.%','Eu 0 0.%','F110.%','A411.%','A 411.%','E02y1','E041.','E0 41.','Eu041','Eu 0 41'
,'F111.','F112.','F116.','F118.','F21y2','A410.','A 410.'
	
--Dementia CTV3 code on Page 17 of Dementia Care Pathway Appendices
--F110.%, Eu02.%,'E02y1' are in this list but are mentioned in the read code v2 list
,'XE1Xr%','X002w%','XE1Xs','Xa0sE'

--MCI codes
,'F06.7','F067' --ICD10 codes on Page 13 of Dementia Care Pathway Appendices
,'386805003' --SNOMED Code on Page 16 of Dementia Care Pathway Appendices
,'28E0.' --Read code v2 on Page 17 of Dementia Care Pathway Appendices
,'Xaagi' --CTV3 code on Page 17 of Dementia Care Pathway Appendices
)

OR p.PrimDiag LIKE 'F03%')
) AS a
LEFT JOIN  (
SELECT DISTINCT 
	SecDiag
	,Der_Person_ID
	,UniqServReqID --this column uniquely identifies the referral
	,CodedDiagTimestamp --The date, time and time zone for the PATIENT DIAGNOSIS.
	,CASE WHEN SecDiag IN ('F06.7','F067','386805003','28E0.','Xaagi') THEN 'MCI'
	ELSE 'Dementia' END AS 'Diagnosis Area'
FROM [NHSE_MHSDS].[dbo].[MHS605SecDiag] r
WHERE 
(r.[SecDiag] IN 

(--Dementia ICD10 codes Page 13 of Dementia Care Pathway Appendices
'F00.0','F00.1','F00.2','F00.9','F01.0','F01.1','F01.2','F01.3','F01.8','F01.9','F02.0','F02.1','F02.2','F02.3','F02.4','F02.8','F03','F05.1'
,'F000','F001','F002','F009','F010','F011','F012','F013','F018','F019','F020','F021','F022','F023','F024','F028','F051'

--This Dagger code is included as it is required in combination with F02.8 to identify Lewy body disease. 
--We are unable to filter MHSDS for those with both F02.8 AND G31.8 so have to filter for those with either F02.8 or G31.8
,'G318','G31.8'

--Dementia SNOMED codes Page 14 of Dementia Care Pathway Appendices
,'52448006','15662003','191449005','191457008','191461002','231438001','268612007','45864009','26929004','416780008','416975007','4169750 07','429998004','230285003'
,'56267009','230286002','230287006','230270009','230273006','90099008','230280008','86188000','13092008','21921000119103','429458009','442344002','792004'
,'713060000','425390006'
--Dementia SNOMED codes Page 15 of Dementia Care Pathway Appendices
,'713844000','191475009','80098002','312991009','135811000119107','13 5 8110 0 0119107','42769004','191519005','281004','191493005','111480006','1114 8 0 0 0 6'
,'32875003','59651006','278857002','230269008','79341000119107','12348006','421023003','713488003','191452002','65096006','31081000119101','191455000'
,'1089501000000102','10532003','191454001','230267005','230268000','230265002'
--Dementia SNOMED codes Page 16 of Dementia Care Pathway Appendices
,'230266001','191451009','1914510 09','22381000119105','230288001','191458003','191459006','191463004','191464005','191465006','191466007','279982005','6475002'
,'66108005'
	
--Dementia Read code v2 on Page 17 of Dementia Care Pathway Appendices
,'E00..%','E0 0..%','Eu01.%','Eu 01.%','Eu02.%','Eu 02.%','E012.%','Eu00.%','Eu 0 0.%','F110.%','A411.%','A 411.%','E02y1','E041.','E0 41.','Eu041','Eu 0 41'
,'F111.','F112.','F116.','F118.','F21y2','A410.','A 410.'
	
--Dementia CTV3 code on Page 17 of Dementia Care Pathway Appendices
--F110.%, Eu02.%,'E02y1' are in this list but are mentioned in the read code v2 list
,'XE1Xr%','X002w%','XE1Xs','Xa0sE'

--MCI codes
,'F06.7','F067' --ICD10 codes on Page 13 of Dementia Care Pathway Appendices
,'386805003' --SNOMED Code on Page 16 of Dementia Care Pathway Appendices
,'28E0.' --Read code v2 on Page 17 of Dementia Care Pathway Appendices
,'Xaagi' --CTV3 code on Page 17 of Dementia Care Pathway Appendices
)
OR r.[SecDiag] LIKE 'F03%')
) AS b
ON a.Der_Person_ID=b.Der_Person_ID AND a.UniqServReqID=b.UniqServReqID AND a.CodedDiagTimestamp=b.CodedDiagTimestamp
GO

-------------------------Ranking of Diagnosis Table------------------------------------------------
--Ranks diagnoses to give the earliest diagnosis (for wait to diagnosis) and latest diagnosis (For everything else) for use later in the script
 IF OBJECT_ID ('[NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_MAS_DIAG_Ranking]') IS NOT NULL DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_MAS_DIAG_Ranking]
SELECT
	*
	,ROW_NUMBER() OVER(PARTITION BY [UniqServReqID],[Der_Person_ID] ORDER BY [CodedDiagTimestamp] ASC, DiagnosisArea DESC) AS RowIDEarliest	--There are instances of more than one primary diagnosis with the same timestamp. In this case Dementia is used over MCI.
	,ROW_NUMBER() OVER(PARTITION BY [UniqServReqID],[Der_Person_ID] ORDER BY [CodedDiagTimestamp] DESC, DiagnosisArea ASC) AS RowIDLatest	--There are instances of more than one primary diagnosis with the same timestamp. In this case Dementia is used over MCI.
INTO [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_MAS_DIAG_Ranking]
FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_MAS_DIAG]
GO
-----------------------------------------Contact Table-----------------------------------
--This table gets the first contact date from the MHS201CareContact table for use in calculating wait times from referral to first contact
IF OBJECT_ID ('[NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_MAS_Contact]') IS NOT NULL DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_MAS_Contact]
SELECT
	UniqServReqID
	,Der_Person_ID as Person_ID
	,MIN(CareContDate) AS FirstContactDate
INTO [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_MAS_Contact]
FROM [NHSE_MHSDS].[dbo].[MHS201CareContact] 

WHERE AttendOrDNACode IN ('5','6') AND ConsMechanismMH IN ('01', '02', '04', '11')
--Filtered for AttendOrDNACode of: "Attended on time or, if late, before the relevant care professional was ready to see the patient" 
--and "Arrived late, after the relevant care professional was ready to see the patient, but was seen"
--Filtered for consultation mechanism of: "Face to face", "Telephone", "Talk type for a person unable to speak", and "Video consultation"
GROUP BY UniqServReqID, Der_Person_ID
GO


