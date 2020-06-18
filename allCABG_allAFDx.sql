-- get diagnosis labels for cases 
-- cases are defined as having af within 2 days after the surgery 
-- diagnosis includes diabetse, hypertension, af, copd, smoking 

-- get diagnosis labels for cases 
-- cases are defined as having af within 2 days after the surgery 
-- diagnosis includes diabetse, hypertension, af, copd, smoking 


USE NM_BI

IF OBJECT_ID('tempdb..#surgerie') IS NOT NULL BEGIN DROP TABLE #surgerie END;
 
SELECT DISTINCT

	prc.coded_procedure_key as surgical_case_key
	, p.ir_id
	, p.patient_key
	, prc.visit_key
	, prc.encounter_inpatient_key 
	, LOWER(REPLACE(REPLACE(REPLACE(pr.procedure_name,' ','_'),char(37),'percent'),char(39),'')) AS procedure_name
	, CAST(prc.coded_procedure_date_key AS DATETIME) AS surgery_start_datetime
	, prc.coded_procedure_date_key as surgery_start_date_key 
	, CAST(prc.coded_procedure_date_key AS DATETIME) AS surgery_end_datetime
	, prc.coded_procedure_date_key as surgery_end_date_key
	, ei.discharge_datetime 
	, p.birth_date
	, p.race_1
	, p.gender
	, p.athena_mrn
	, p.idx_mrn
	, p.lfh_mrn
	, p.nmff_mrn
	, p.nmh_mrn
	, p.west_mrn
	, p.death_date
	, ROW_NUMBER() over (order by p.ir_id) as the_counter 
INTO #surgerie
FROM NM_BI.fact.vw_coded_procedure prc 
--INNER JOIN dim.[procedure] prc
--	ON prc.procedure_key = sc.primary_procedure_key
	JOIN NM_BI.dim.vw_procedure pr 
		ON prc.procedure_key = pr.procedure_key 
INNER JOIN NM_BI.dim.vw_patient p
	ON p.patient_key = prc.patient_key
join NM_BI.fact.vw_encounter_inpatient ei 
	on ei.encounter_inpatient_key = prc.encounter_inpatient_key 
WHERE ei.encounter_inpatient_key != -2 
AND prc.coded_procedure_date_key IS NOT NULL
AND pr.code_type IN ('CPT', 'ICD9', 'ICD10')
AND pr.procedure_code IN ('33510', '33511', '33512', '33513', '33514', '33516', '33517', '33518', '33519', '33521', '33522', '33523', '33533', '33534', '33535', '33536'

                                         , '36.10', '36.11', '36.12', '36.13', '36.14', '36.15', '36.16', '36.17', '36.19'

                                         , '0210093', '0210098', '0210099', '021009C', '021009F', '021009W', '02100A3', '02100A8', '02100A9', '02100AC', '02100AF', '02100AW', '02100J3', '02100J8', '02100J9', '02100JC', '02100JF', '02100JW', '02100K3'
                                         , '02100K8', '02100K9', '02100KC', '02100KF', '02100KW', '02100Z3', '02100Z8', '02100Z9', '02100ZC', '02100ZF', '0210344', '02103D4', '0210444', '0210493', '0210498', '0210499', '021049C', '021049F', '021049W'
                                         , '02104A3', '02104A8', '02104A9', '02104AC', '02104AF', '02104AW', '02104D4', '02104J3', '02104J8', '02104J9', '02104JC', '02104JF', '02104JW', '02104K3', '02104K8', '02104K9', '02104KC', '02104KF', '02104KW'
                                         , '02104Z3', '02104Z8', '02104Z9', '02104ZC', '02104ZF', '0211093', '0211098', '0211099', '021109C', '021109F', '021109W', '02110A3', '02110A8', '02110A9', '02110AC', '02110AF', '02110AW', '02110J3', '02110J8'
                                         , '02110J9', '02110JC', '02110JF', '02110JW', '02110K3', '02110K8', '02110K9', '02110KC', '02110KF', '02110KW', '02110Z3', '02110Z8', '02110Z9', '02110ZC', '02110ZF', '0211344', '02113D4', '0211444', '0211493'
                                         , '0211498', '0211499', '021149C', '021149F', '021149W', '02114A3', '02114A8', '02114A9', '02114AC', '02114AF', '02114AW', '02114D4', '02114J3', '02114J8', '02114J9', '02114JC', '02114JF', '02114JW', '02114K3', '02114K8', '02114K9', '02114KC', '02114KF', '02114KW', '02114Z3', '02114Z8', '02114Z9', '02114ZC', '02114ZF', '0212093', '0212098', '0212099', '021209C', '021209F', '021209W', '02120A3', '02120A8', '02120A9', '02120AC', '02120AF', '02120AW', '02120J3', '02120J8', '02120J9', '02120JC', '02120JF', '02120JW', '02120K3', '02120K8', '02120K9', '02120KC', '02120KF', '02120KW', '02120Z3', '02120Z8', '02120Z9', '02120ZC', '02120ZF', '0212344', '02123D4', '0212444', '0212493', '0212498', '0212499', '021249C', '021249F', '021249W', '02124A3', '02124A8', '02124A9', '02124AC', '02124AF', '02124AW', '02124D4', '02124J3', '02124J8', '02124J9', '02124JC', '02124JF', '02124JW', '02124K3', '02124K8', '02124K9', '02124KC', '02124KF', '02124KW', '02124Z3', '02124Z8', '02124Z9', '02124ZC', '02124ZF', '0213093', '0213098', '0213099', '021309C', '021309F', '021309W', '02130A3', '02130A8', '02130A9', '02130AC', '02130AF', '02130AW', '02130J3', '02130J8', '02130J9', '02130JC', '02130JF', '02130JW', '02130K3', '02130K8', '02130K9', '02130KC', '02130KF', '02130KW', '02130Z3', '02130Z8', '02130Z9', '02130ZC', '02130ZF', '0213344', '02133D4', '0213444', '0213493', '0213498', '0213499', '021349C', '021349F', '021349W', '02134A3', '02134A8', '02134A9', '02134AC', '02134AF', '02134AW', '02134D4', '02134J3', '02134J8', '02134J9', '02134JC', '02134JF', '02134JW', '02134K3', '02134K8', '02134K9', '02134KC', '02134KF', '02134KW', '02134Z3', '02134Z8', '02134Z9', '02134ZC', '02134ZF'  
                                         
                      );
--https://coder.aapc.com/cpt-codes-range/936/20 
-- https://edwardsprod.blob.core.windows.net/media/Default/about%20us/hvt-billing-guide-2018.pdf 
-- #surgerie: 11506
-- one person can have multiple surgries 
IF OBJECT_ID('tempdb..#surgeries') IS NOT NULL BEGIN DROP TABLE #surgeries END;
SELECT *
	INTO #surgeries 
FROM 
	(SELECT  * , row_number() over (partition by ir_id order by surgery_start_datetime ) as rk 
		FROM #surgerie
	)x 
where x.rk = 1
select * from #surgeries 
-- #surgeries: 6991



IF OBJECT_ID('tempdb..#sepsis1') IS NOT NULL BEGIN DROP TABLE #sepsis1 END;
IF OBJECT_ID('tempdb..#case_id') IS NOT NULL BEGIN DROP TABLE #case_id END;
IF OBJECT_ID('tempdb..#temp') IS NOT NULL BEGIN DROP TABLE #temp END;


-- get patients who has AF dx after surgery or on the day of surgery, before their discharge of the surgery encounter 
WITH sepsis_keys AS
(
SELECT DISTINCT diagnosis_key
FROM NM_BI.dim.vw_diagnosis_terminology dt 
WHERE (  
		(dt.diagnosis_code_set = 'ICD-9-CM' AND dt.diagnosis_code  ='427.31')  -- change to AF code here. 
		OR (dt.diagnosis_code_set = 'ICD-10-CM' AND dt.diagnosis_code_base ='I48')   -- change to AF code here
	  )
)

SELECT DISTINCT
	s.ir_id, de.start_datetime 
INTO #case_id 
FROM NM_BI.fact.vw_diagnosis_event de
INNER JOIN sepsis_keys sk
	ON sk.diagnosis_key = de.diagnosis_key 
INNER JOIN #surgeries s
	ON s.patient_key = de.patient_key
JOIN [dim].[vw_diagnosis_event_profile] dp  
		ON dp.diagnosis_event_profile_key = de.diagnosis_event_profile_key
		AND dp.load_type in ( 'Encounter Diagnosis', 'Problem List', 'Billing Diagnosis')
	WHERE start_datetime IS NOT NULL


--drop table #temp 
SELECT surgical_case_key, s.ir_id, patient_key, visit_key, surgery_start_datetime, start_datetime as AF_dxDate , discharge_datetime
--into #temp 
FROM #surgeries s
inner JOIN #case_id c
ON s.ir_id = c.ir_id  
--where start_datetime >= surgery_start_datetime 
--and start_datetime < discharge_datetime
order by ir_id, surgery_start_datetime 
