-- the dx before surgery of all the patients that went throught CABG 

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
FROM fact.vw_coded_procedure prc 
--INNER JOIN dim.[procedure] prc
--	ON prc.procedure_key = sc.primary_procedure_key
	JOIN dim.vw_procedure pr 
		ON prc.procedure_key = pr.procedure_key 
INNER JOIN dim.vw_patient p
	ON p.patient_key = prc.patient_key

WHERE prc.coded_procedure_date_key IS NOT NULL
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

-- one person can have multiple surgries 
IF OBJECT_ID('tempdb..#surgeries') IS NOT NULL BEGIN DROP TABLE #surgeries END;
SELECT *
	INTO #surgeries 
FROM 
	(SELECT  * , row_number() over (partition by ir_id order by procedure_name ) as rk 
		FROM #surgerie
	)x 
where x.rk = 1


IF OBJECT_ID('tempdb..#hypertension') IS NOT NULL BEGIN DROP TABLE #hypertension END;
select s.ir_id,s.surgery_start_date_key, de.start_date_key, de.diagnosis_event_key, dti.diagnosis_code 
into #hypertension 
from #surgeries s  
left join dim.vw_patient p  
	on p.patient_key = s.patient_key
left join fact.vw_diagnosis_event de 
	on de.patient_key = p.patient_key 
left join  dim.vw_diagnosis_terminology dti 
	on de.diagnosis_key = dti.diagnosis_key 
JOIN [dim].[vw_diagnosis_event_profile] dp  
		ON dp.diagnosis_event_profile_key = de.diagnosis_event_profile_key
		AND dp.load_type in ( 'Encounter Diagnosis', 'Problem List', 'Billing Diagnosis','Encounter Diagnosis')
where ( dti.diagnosis_code_base between '401'and'405' or  dti.diagnosis_code_base between 'I10' and 'I16')
and s.surgery_start_date_key > de.start_date_key

--drop table #temp_hypertension 
IF OBJECT_ID('tempdb..#temp_hypertension') IS NOT NULL BEGIN DROP TABLE #temp_hypertension END;
select * , 'hypertension' as hypertension 
into #temp_hypertension 
from (
select *, row_number() over (partition by ir_id order by start_date_key asc) as rk 
from #hypertension 
)x where rk = 1 


------------------------------------copd ---------------------------------------
--------------------------------------copd --------------------------------------
IF OBJECT_ID('tempdb..#copd') IS NOT NULL BEGIN DROP TABLE #copd END;
IF OBJECT_ID('tempdb..#temp_copd') IS NOT NULL BEGIN DROP TABLE #temp_copd END;

select s.ir_id,s.surgery_start_date_key, de.start_date_key, de.diagnosis_event_key, dti.diagnosis_code 
into #copd  
from #surgeries s    
left join dim.vw_patient p  
	on p.patient_key = s.patient_key
left join fact.vw_diagnosis_event de 
	on de.patient_key = p.patient_key 
left join  dim.vw_diagnosis_terminology dti 
	on de.diagnosis_key = dti.diagnosis_key 
JOIN [dim].[vw_diagnosis_event_profile] dp  
		ON dp.diagnosis_event_profile_key = de.diagnosis_event_profile_key
		AND dp.load_type in ( 'Encounter Diagnosis', 'Problem List', 'Billing Diagnosis','Encounter Diagnosis')
where (diagnosis_code_base in ('J40','J41','J42','J43','J44','J47') and diagnosis_code_set = 'ICD-10-CM')
or (diagnosis_code in ('493.0','493.1','493.2','493.8','493.9', '491.0','491.1','491.2','491.8','491.9','492.0','506.4','494.0','496', '506') and diagnosis_code_set = 'ICD-9-CM')
and s.surgery_start_date_key > de.start_date_key

-- drop table #temp_copd 
select * , 'copd' as copd 
into #temp_copd 
from (
select *, row_number() over (partition by ir_id order by start_date_key asc) as rk 
from #copd  
)x where rk = 1 


------------------------diabetes ----------------------------------
----------------------------diabetes ---------------------------------
IF OBJECT_ID('tempdb..#diabetes') IS NOT NULL BEGIN DROP TABLE #diabetes END;
select s.ir_id,s.surgery_start_date_key, de.start_date_key, de.diagnosis_event_key, dti.diagnosis_code 
into #diabetes  
from #surgeries s  
left join dim.vw_patient p  
	on p.patient_key = s.patient_key
left join fact.vw_diagnosis_event de 
	on de.patient_key = p.patient_key 
left join  dim.vw_diagnosis_terminology dti 
	on de.diagnosis_key = dti.diagnosis_key 
JOIN [dim].[vw_diagnosis_event_profile] dp  
		ON dp.diagnosis_event_profile_key = de.diagnosis_event_profile_key
		AND dp.load_type in ( 'Encounter Diagnosis', 'Problem List', 'Billing Diagnosis','Encounter Diagnosis')
where (diagnosis_name  like  '%diabetes%mellitus%'
or (diagnosis_code_base = '250' and diagnosis_code_set = 'ICD-9-CM'
or (diagnosis_code IN (
			'44054006'
			,'197763012'
			,'474213016'
			,'200951011'
			,'78158011'
			,'48EB2F20-59A4-4676-A1C0-40880362224F'
			,'359642000'
			,'81531005'
			) AND diagnosis_code_set = 'SNOMED')
OR (
		diagnosis_code_base IN (
			 'E08'
			 ,'E09'
			 ,'E10'
			 ,'E11'
			 ,'E13')
		AND diagnosis_code_set = 'ICD-10-CM'
		)))
and s.surgery_start_date_key > de.start_date_key



IF OBJECT_ID('tempdb..#temp_diabetes') IS NOT NULL BEGIN DROP TABLE #temp_diabetes END;
select * , 'diabetes' as diabetes 
into #temp_diabetes 
from (
select *, row_number() over (partition by ir_id order by start_date_key asc) as rk 
from #diabetes 
)x where rk = 1 

-----------------------------------af----------------------------
----------------------------------af---------------------------
IF OBJECT_ID('tempdb..#AF') IS NOT NULL BEGIN DROP TABLE #AF END;
IF OBJECT_ID('tempdb..#temp_AF') IS NOT NULL BEGIN DROP TABLE #temp_AF END;
select distinct diagnosis_code_set from  dim.vw_diagnosis_terminology  
select s.ir_id,s.surgery_start_date_key, de.start_date_key, de.diagnosis_event_key, dti.diagnosis_code 
into #AF   
from #surgeries s  
left join dim.vw_patient p   
	on p.patient_key = s.patient_key
left join fact.vw_diagnosis_event de 
	on de.patient_key = p.patient_key 
left join  dim.vw_diagnosis_terminology dti 
	on de.diagnosis_key = dti.diagnosis_key 
JOIN [dim].[vw_diagnosis_event_profile] dp  
		ON dp.diagnosis_event_profile_key = de.diagnosis_event_profile_key
		AND dp.load_type in ( 'Encounter Diagnosis', 'Problem List', 'Billing Diagnosis','Encounter Diagnosis')
where diagnosis_code  in ( '427.31', 'I48','427.31' )
and s.surgery_start_date_key > de.start_date_key

-- drop table #temp_AF 
select * , 'prior_af' as prior_af
into #temp_AF 
from (
select *, row_number() over (partition by ir_id order by start_date_key asc) as rk 
from #AF 
)x where rk = 1 
select * from #temp_AF where ir_id = '9792'




--------------------------------------------smoking ---------------------------
--------------------------------------------smoking ------------------------------ 
IF OBJECT_ID('tempdb..#smoking') IS NOT NULL BEGIN DROP TABLE #smoking END;
IF OBJECT_ID('tempdb..#temp_smok') IS NOT NULL BEGIN DROP TABLE #temp_smok END;
select s.ir_id,s.surgery_start_date_key, de.start_date_key, de.diagnosis_event_key, dti.diagnosis_code 
into #smoking   
from #surgeries s  
left join dim.vw_patient p  
	on p.patient_key = s.patient_key
left join fact.vw_diagnosis_event de 
	on de.patient_key = p.patient_key 
left join  dim.vw_diagnosis_terminology dti 
	on de.diagnosis_key = dti.diagnosis_key 
JOIN [dim].[vw_diagnosis_event_profile] dp  
		ON dp.diagnosis_event_profile_key = de.diagnosis_event_profile_key
		AND dp.load_type in ( 'Encounter Diagnosis', 'Problem List', 'Billing Diagnosis','Encounter Diagnosis')
where (
diagnosis_name like '%smok%' or diagnosis_name like '%cig%'
or dti.diagnosis_code in ('305.1','V15.82', 'Z87.891') 
or dti.diagnosis_code like 'F17.2%'
and s.surgery_start_date_key > de.start_date_key)

--drop table #temp_smok 
select * , 'smoking' as smoking 
into #temp_smok  
from (
select *, row_number() over (partition by ir_id order by start_date_key asc) as rk 
from #smoking  
)x where rk = 1 



--------------------------------------Myocardial Infarction--------------------------------
--------------------------------------Myocardial Infarction--------------------------------
IF OBJECT_ID('tempdb..#myo') IS NOT NULL BEGIN DROP TABLE #myo END;
IF OBJECT_ID('tempdb..#temp_myo') IS NOT NULL BEGIN DROP TABLE #temp_myo END;
select s.ir_id,s.surgery_start_date_key, de.start_date_key, de.diagnosis_event_key, dti.diagnosis_code 
into #myo    
from #surgeries s    
left join dim.vw_patient p  
	on p.patient_key = s.patient_key
left join fact.vw_diagnosis_event de 
	on de.patient_key = p.patient_key 
left join  dim.vw_diagnosis_terminology dti 
	on de.diagnosis_key = dti.diagnosis_key 
JOIN [dim].[vw_diagnosis_event_profile] dp  
		ON dp.diagnosis_event_profile_key = de.diagnosis_event_profile_key
		AND dp.load_type in ( 'Encounter Diagnosis', 'Problem List', 'Billing Diagnosis','Encounter Diagnosis')

where (
	diagnosis_code in ('I21.4', 'I25.10', 'I25.110', 'I25.119', 'I25.5', 'I25.82', 'SNOMED.401314000')
	or diagnosis_code_base in ('410', '412'))
and s.surgery_start_date_key > de.start_date_key

-- drop table #temp_myo 
select * , 'myo' as myo
into #temp_myo
from (
select *, row_number() over (partition by ir_id order by start_date_key asc) as rk 
from #myo 
)x where rk = 1 

--------------------------------------Heart Failure--------------------------------
--------------------------------------Heart Failure--------------------------------
IF OBJECT_ID('tempdb..#hf') IS NOT NULL BEGIN DROP TABLE #hf END;
IF OBJECT_ID('tempdb..#temp_hf') IS NOT NULL BEGIN DROP TABLE #temp_hf END;
select s.ir_id,s.surgery_start_date_key, de.start_date_key, de.diagnosis_event_key, dti.diagnosis_code 
into #hf   
from #surgeries s    
left join dim.vw_patient p  
	on p.patient_key = s.patient_key
left join fact.vw_diagnosis_event de 
	on de.patient_key = p.patient_key 
left join  dim.vw_diagnosis_terminology dti 
	on de.diagnosis_key = dti.diagnosis_key 
JOIN [dim].[vw_diagnosis_event_profile] dp  
		ON dp.diagnosis_event_profile_key = de.diagnosis_event_profile_key
		AND dp.load_type in ( 'Encounter Diagnosis', 'Problem List', 'Billing Diagnosis','Encounter Diagnosis')
where diagnosis_code in ('398.91', '402.01', '402.11', '402.91'
, '404.01', '404.03', '404.11', '404.13', '404.91', '404.93', '425', '428.0'
, '428.1', '428.20', '428.21', '428.22', '428.23', '428.30', '428.31'
,'428.32','428.33','428.40', '428.41', '428.42', '428.43'
, '428.9', 'I50.9', 'SNOMED.42343007')
and s.surgery_start_date_key > de.start_date_key

-- drop table #temp_hf
select * , 'hf' as hf
into #temp_hf
from (
select *, row_number() over (partition by ir_id order by start_date_key asc) as rk 
from #hf
)x where rk = 1 


--------------------------------------Mitral Valve Disorder--------------------------------
IF OBJECT_ID('tempdb..#mv') IS NOT NULL BEGIN DROP TABLE #mv END;
IF OBJECT_ID('tempdb..#temp_mv') IS NOT NULL BEGIN DROP TABLE #temp_mv END;
select s.ir_id,s.surgery_start_date_key, de.start_date_key, de.diagnosis_event_key, dti.diagnosis_code 
into #mv   
from #surgeries s    
left join dim.vw_patient p  
	on p.patient_key = s.patient_key  
left join fact.vw_diagnosis_event de 
	on de.patient_key = p.patient_key 
left join  dim.vw_diagnosis_terminology dti 
	on de.diagnosis_key = dti.diagnosis_key 
JOIN [dim].[vw_diagnosis_event_profile] dp  
		ON dp.diagnosis_event_profile_key = de.diagnosis_event_profile_key
		AND dp.load_type in ( 'Encounter Diagnosis', 'Problem List', 'Billing Diagnosis','Encounter Diagnosis')
where diagnosis_code in ('I34.0', 'X424.0')
and s.surgery_start_date_key > de.start_date_key

-- drop table #temp_mv
select * , 'mv' as mv
into #temp_mv
from (
select *, row_number() over (partition by ir_id order by start_date_key asc) as rk 
from #mv
)x where rk = 1 






select s.ir_id
,  DATEDIFF(year,s.birth_date,s.surgery_start_datetime) AS age 
,  s.race_1 
, s.gender 
,case when smoking is null then 0 else 1 end as smoking 
, case when copd is null then 0 else 1 end  as copd  
, case when  prior_af IS null then 0 else 1 end  as prior_af 
, case when hypertension IS null then 0 else 1   end as hypertension 
, case when  diabetes IS null then 0 else 1  end as diabetes 
, case when mv IS NULL then 0 else 1  end as mitralValve
, case when hf IS NULL then 0 else 1  end as hf
, case when myo IS NULL then 0 else 1  end as myo
--into #temp 
from #surgeries s
left join #temp_hypertension hyper 
	on hyper.ir_id = s.ir_id 
left join #temp_AF af 
	on af.ir_id = s.ir_id
left join #temp_copd copd  
	on copd.ir_id = s.ir_id 
left join #temp_smok smok  
	on smok.ir_id = s.ir_id
left join #temp_diabetes d 
	on d.ir_id = s.ir_id
LEFT join #temp_mv mv 
on mv.ir_id = s.ir_id 
LEFT join #temp_hf hf 
on s.ir_id = hf.ir_id 
LEFT join #temp_myo myo 
on myo.ir_id = s.ir_id  
--where s.ir_id = '9792'	


