


-- change SET @query_loop = N'SELECT DISTINCT
 
--	s.surgical_case_key
--	, s.west_mrn
--	, s.ir_id
	--, DATEDIFF(year,s.birth_date,s.surgery_start_datetime) AS age
--	, race_1
--	, gender
--	, s.procedure_name
--	, s.death_date
	--, s.surgery_start_datetime
	--, s.surgery_end_datetime
	--, sep.min_sepsis_datetime
	--, sep.max_sepsis_datetime
	--, DATEDIFF(MINUTE,s.surgery_start_datetime,s.surgery_end_datetime) AS surgery_length 
-- sep.min_sepsis_datetime does not exist in #sepsis temp table 
-- change s.surgery_start_datetime to the name existing in the #surgeries table 



USE NM_BI

IF OBJECT_ID('tempdb..#surgeries') IS NOT NULL BEGIN DROP TABLE #surgeries END;
 
SELECT DISTINCT

	sc.surgical_case_key
	, p.ir_id
	, sc.patient_key
	, sc.visit_key
	, LOWER(REPLACE(REPLACE(REPLACE(prc.procedure_name,' ','_'),char(37),'percent'),char(39),'')) AS procedure_name
	, CAST(sc.surgery_start_datetime AS DATETIME) AS surgery_start_datetime
	, sc.surgery_start_date_key
	, CAST(sc.surgery_end_datetime AS DATETIME) AS surgery_end_datetime
	, sc.surgery_end_date_key
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
INTO #surgeries
FROM fact.surgical_case sc
INNER JOIN dim.[procedure] prc
	ON prc.procedure_key = sc.primary_procedure_key
	AND sc.primary_procedure_key = 555536
	--Laparoscopic sigmoid colectomy, coloproctostomy, sigmoidoscopy, repair of bladder laceration
	--laparoscopic loop colostomy
INNER JOIN dim.vw_patient p
	ON p.patient_key = sc.patient_key

WHERE sc.surgery_start_datetime IS NOT NULL;



IF OBJECT_ID('tempdb..#sepsis') IS NOT NULL BEGIN DROP TABLE #sepsis END;

WITH sepsis_keys AS
(
SELECT DISTINCT diagnosis_key
FROM dim.diagnosis_terminology dt
WHERE ((dt.diagnosis_code_set = 'ICD-9-CM' AND dt.diagnosis_code IN ('995.92','785.52'))
OR (dt.diagnosis_code_set = 'ICD-10-CM' AND dt.diagnosis_code IN ('R65.20','R65.21'))
OR diagnosis_key = 773534)
)



--WITH sepsis_keys AS
--(
--SELECT DISTINCT diagnosis_key
--FROM dim.diagnosis_terminology dt
--WHERE ((dt.diagnosis_code_set = 'ICD-9-CM' AND dt.diagnosis_code IN ('427.31'))
--OR (dt.diagnosis_code_set = 'ICD-10-CM' AND dt.diagnosis_code IN ('I48.0'))
--)--OR diagnosis_key = 773534)
--)



SELECT DISTINCT
	s.ir_id
	, MIN(CASE WHEN de.start_datetime < s.surgery_end_datetime THEN de.start_datetime END) AS min_prior_sepsis_datetime
	, MAX(CASE WHEN de.start_datetime < s.surgery_end_datetime THEN de.start_datetime END) AS max_prior_sepsis_datetime
	, MIN(CASE WHEN de.start_datetime > s.surgery_end_datetime THEN de.start_datetime END) AS min_post_sepsis_datetime
	, MAX(CASE WHEN de.start_datetime > s.surgery_end_datetime THEN de.start_datetime END) AS max_post_sepsis_datetime
INTO #sepsis
FROM fact.diagnosis_event de
INNER JOIN sepsis_keys sk
	ON sk.diagnosis_key = de.diagnosis_key
INNER JOIN #surgeries s
	ON s.patient_key = de.patient_key
	AND DATEDIFF(y,s.surgery_end_datetime,de.start_datetime) < 30
WHERE start_datetime IS NOT NULL
GROUP BY s.ir_id;

IF OBJECT_ID('tempdb..#all_encounters') IS NOT NULL BEGIN DROP TABLE #all_encounters END;

CREATE TABLE #all_encounters (
surgical_case_key INT NOT NULL
, ir_id INT NULL
, encounter_key INT NOT NULL
, encounter_type VARCHAR(50) NOT NULL
, admission_diagnosis_bridge_key INT NULL
, discharge_diagnosis_bridge_key INT NULL
, encounter_start_datetime DATETIME NULL
, encounter_end_datetime DATETIME NULL
)

--------------------------------------------------------
--              inpatient encounters                  --
--------------------------------------------------------

INSERT #all_encounters

SELECT

s.surgical_case_key
, s.ir_id
, ei.encounter_inpatient_key
, 'inpatient'
, ei.present_on_admission_diagnosis_bridge_key
, ei.discharge_diagnosis_bridge_key
, ei.encounter_start_datetime
, ei.encounter_end_datetime

FROM #surgeries s
INNER JOIN dim.vw_patient p
	ON p.ir_id = s.ir_id
INNER JOIN fact.encounter_inpatient ei
	ON ei.patient_key = p.patient_key

--------------------------------------------------------
--              outpatient encounters                 --
--------------------------------------------------------

INSERT #all_encounters
SELECT

s.surgical_case_key
, s.ir_id
, eo.encounter_outpatient_key
, 'outpatient'
, NULL AS admission_diag
, eo.diagnosis_bridge_key AS discharge_diag -- is this at discharge or some other time?
, eo.encounter_start_datetime -- fishy
, eo.encounter_end_datetime -- fishy

FROM #surgeries s
INNER JOIN dim.vw_patient p
	ON p.ir_id = s.ir_id
INNER JOIN fact.encounter_outpatient eo
	ON eo.patient_key = p.patient_key

--------------------------------------------------------
--              emergency encounters                  --
--------------------------------------------------------

INSERT #all_encounters
SELECT

s.surgical_case_key
, s.ir_id
, ee.encounter_emergency_key
, 'emergency'
, NULL AS admission_diag
, ee.ed_diagnosis_bridge_key AS discharge_diag -- is this at discharge or some other time?
, ee.ed_arrival_datetime -- fishy
, ee.ed_departure_datetime -- fishy

FROM #surgeries s
INNER JOIN dim.vw_patient p
	ON p.ir_id = s.ir_id
INNER JOIN fact.encounter_emergency ee
	ON ee.patient_key = p.patient_key

--------------------------------------------------------
--                misfit encounters                   --
--------------------------------------------------------

INSERT #all_encounters
SELECT

s.surgical_case_key
, s.ir_id
, em.encounter_misfit_key
, 'misfit'
, NULL AS admission_diag
, NULL AS discharge_diag -- is this at discharge or some other time?
, em.encounter_start_datetime -- fishy
, em.encounter_end_datetime -- fishy

FROM #surgeries s
INNER JOIN dim.vw_patient p
	ON p.ir_id = s.ir_id
INNER JOIN fact.encounter_misfit em
	ON em.patient_key = p.patient_key

--SELECT * FROM #all_encounters
ORDER BY encounter_start_datetime

IF OBJECT_ID('tempdb..#mostrecent_diagnosis_bridge') IS NOT NULL BEGIN DROP TABLE #mostrecent_diagnosis_bridge END;

SELECT

	s.surgical_case_key
	, (SELECT TOP 1 admission_diagnosis_bridge_key
	FROM #all_encounters
	WHERE ir_id = s.ir_id
	AND encounter_start_datetime <= s.surgery_start_date_key
	AND admission_diagnosis_bridge_key > 0
	ORDER BY encounter_start_datetime DESC) AS mr_admission_diagnosis_bridge_key
	, (SELECT TOP 1 encounter_start_datetime
	FROM #all_encounters
	WHERE ir_id = s.ir_id
	AND encounter_start_datetime <= s.surgery_start_date_key
	AND admission_diagnosis_bridge_key > 0
	ORDER BY encounter_start_datetime DESC) AS mr_admission_datetime
	, (SELECT TOP 1 discharge_diagnosis_bridge_key
	FROM #all_encounters
	WHERE ir_id = s.ir_id
	AND encounter_end_datetime <= s.surgery_start_date_key
	AND discharge_diagnosis_bridge_key > 0
	ORDER BY encounter_start_datetime DESC) AS mr_discharge_diagnosis_bridge_key
	, (SELECT TOP 1 encounter_end_datetime
	FROM #all_encounters
	WHERE ir_id = s.ir_id
	AND encounter_end_datetime <= s.surgery_start_date_key
	AND discharge_diagnosis_bridge_key > 0
	ORDER BY encounter_start_datetime DESC) AS mr_discharge_datetime
INTO #mostrecent_diagnosis_bridge
FROM #surgeries s;

IF OBJECT_ID('tempdb..#most_recent_diagnoses') IS NOT NULL BEGIN DROP TABLE #most_recent_diagnoses END;

WITH most_recent_diagnoses AS
(
SELECT

	mrdb.surgical_case_key
	, CASE WHEN mrdb.mr_discharge_datetime > ISNULL(mrdb.mr_admission_datetime,'1900-01-01') THEN dtd.diagnosis_key ELSE dta.diagnosis_key END AS diagnosis_key
	, CASE WHEN mrdb.mr_discharge_datetime > ISNULL(mrdb.mr_admission_datetime,'1900-01-01') THEN mrdb.mr_discharge_datetime ELSE mrdb.mr_admission_datetime END AS diagnosis_datetime

FROM #mostrecent_diagnosis_bridge mrdb
LEFT OUTER JOIN dim.diagnosis_bridge dba
	ON dba.diagnosis_bridge_key = mrdb.mr_admission_diagnosis_bridge_key
LEFT OUTER JOIN dim.diagnosis_terminology dta
	ON dta.diagnosis_key = dba.diagnosis_key
LEFT OUTER JOIN dim.diagnosis_bridge dbd
	ON dbd.diagnosis_bridge_key = mrdb.mr_discharge_diagnosis_bridge_key
LEFT OUTER JOIN dim.diagnosis_terminology dtd
	ON dtd.diagnosis_key = dbd.diagnosis_key
)

SELECT

	mrd.surgical_case_key
	, mrd.diagnosis_key
	, dt.diagnosis_code_base
	, dt.diagnosis_code_set
	, dt.diagnosis_code
	, LOWER(REPLACE(REPLACE(REPLACE(dt.diagnosis_name,' ','_'),char(37),'percent'),char(39),'')) AS diagnosis_name
	, mrd.diagnosis_datetime
INTO #most_recent_diagnoses
FROM most_recent_diagnoses mrd
INNER JOIN dim.diagnosis_terminology dt
	ON dt.diagnosis_key = mrd.diagnosis_key

--SELECT * FROM #mostrecent_diagnoses

IF OBJECT_ID('tempdb..#transfusions') IS NOT NULL BEGIN DROP TABLE #transfusions END;

SELECT procedure_key
INTO #transfusions
FROM dim.vw_procedure
WHERE procedure_name LIKE '%trans%'
and procedure_category = 'NURSING TREATMENT ORDERABLES - BLOOD ADMIN'

IF OBJECT_ID('tempdb..#measurements') IS NOT NULL BEGIN DROP TABLE #measurements END;

SELECT

	surg.surgical_case_key
	, LOWER(REPLACE(REPLACE(REPLACE(vt.vital_type_name,' ','_'),char(37),'percent'),char(39),'')) AS measurement_name
	, CASE WHEN v.recorded_datetime > DATEADD(day,-45,surg.surgery_end_datetime) AND v.recorded_datetime < surg.surgery_start_datetime THEN 1 ELSE 0 END AS pre_op
	, CASE WHEN v.recorded_datetime > surg.surgery_start_datetime AND v.recorded_datetime < surg.surgery_end_datetime THEN 1 ELSE 0 END AS inter_op
	, CASE WHEN v.recorded_datetime > surg.surgery_end_datetime AND v.recorded_datetime < ISNULL(sep.min_post_sepsis_datetime,DATEADD(day,30,surg.surgery_end_datetime)) THEN 1 ELSE 0 END AS post_op
	, MIN(vital_value_number) AS [min]
	, MAX(vital_value_number) AS [max]
	, AVG(vital_value_number) AS [avg]
	, STDEV(vital_value_number) AS [stdev]
	, COUNT(v.vital_key) AS [count]
	, COUNT(DISTINCT v.vital_key) AS [countd]

INTO #measurements
FROM #surgeries surg
INNER JOIN dim.vw_patient p
	ON p.ir_id = surg.ir_id
LEFT OUTER JOIN fact.vital v
	ON v.patient_key = p.patient_key
LEFT OUTER JOIN dim.vital_type vt
	ON vt.vital_type_key = v.vital_type_key
LEFT OUTER JOIN #sepsis sep
	ON sep.ir_id = surg.ir_id

WHERE (vt.vital_type_name <> 'height' OR vt.unit_of_measurement_category <> 'CENTIMETER')
AND (v.recorded_datetime > DATEADD(day,-2,surg.surgery_end_datetime) AND v.recorded_datetime < DATEADD(day,2,surg.surgery_end_datetime))

GROUP BY 
	surg.surgical_case_key
	, LOWER(REPLACE(REPLACE(REPLACE(vt.vital_type_name,' ','_'),char(37),'percent'),char(39),''))
	, CASE WHEN v.recorded_datetime > DATEADD(day,-45,surg.surgery_end_datetime) AND v.recorded_datetime < surg.surgery_start_datetime THEN 1 ELSE 0 END
	, CASE WHEN v.recorded_datetime > surg.surgery_start_datetime AND v.recorded_datetime < surg.surgery_end_datetime THEN 1 ELSE 0 END
	, CASE WHEN v.recorded_datetime > surg.surgery_end_datetime AND v.recorded_datetime < ISNULL(sep.min_post_sepsis_datetime,DATEADD(day,30,surg.surgery_end_datetime)) THEN 1 ELSE 0 END

INSERT #measurements
SELECT

	surg.surgical_case_key
	, LOWER(REPLACE(REPLACE(REPLACE(ISNULL(c.name,p.procedure_name),' ','_'),char(37),'percent'),char(39),''))
	, CASE WHEN ISNULL(por.result_datetime,po.order_datetime) < surg.surgery_start_datetime THEN 1 ELSE 0 END AS pre_op
	, CASE WHEN ISNULL(por.result_datetime,po.order_datetime) > surg.surgery_start_datetime AND ISNULL(por.result_datetime,po.order_datetime) < surg.surgery_end_datetime THEN 1 ELSE 0 END AS inter_op
	, CASE WHEN ISNULL(por.result_datetime,po.order_datetime) > surg.surgery_end_datetime AND ISNULL(por.result_datetime,po.order_datetime) < DATEADD(day,2,surg.surgery_end_datetime) THEN 1 ELSE 0 END AS post_op
	, MIN(por.value_numeric) AS [min]
	, MAX(por.value_numeric) AS [max]
	, AVG(por.value_numeric) AS [avg]
	, STDEV(por.value_numeric) AS [stdev]
	, COUNT(ISNULL(por.procedure_order_result_key,po.procedure_order_key)) AS [count]
	, COUNT(DISTINCT ISNULL(por.procedure_order_result_key,po.procedure_order_key)) AS [countd]

FROM #surgeries surg
LEFT OUTER JOIN fact.procedure_order po
	ON po.visit_key = surg.visit_key
LEFT OUTER JOIN dim.[procedure] p
	ON p.procedure_key = po.procedure_key
LEFT OUTER JOIN fact.procedure_order_result por
	ON por.procedure_order_key = po.procedure_order_key
LEFT OUTER JOIN dim.component c
	ON c.component_key = por.component_key

WHERE por.value_numeric IS NOT NULL
OR p.procedure_key IN (SELECT procedure_key FROM #transfusions)


GROUP BY
	surg.surgical_case_key
	, LOWER(REPLACE(REPLACE(REPLACE(ISNULL(c.name,p.procedure_name),' ','_'),char(37),'percent'),char(39),''))
	, CASE WHEN ISNULL(por.result_datetime,po.order_datetime) < surg.surgery_start_datetime THEN 1 ELSE 0 END
	, CASE WHEN ISNULL(por.result_datetime,po.order_datetime) > surg.surgery_start_datetime AND ISNULL(por.result_datetime,po.order_datetime) < surg.surgery_end_datetime THEN 1 ELSE 0 END
	, CASE WHEN ISNULL(por.result_datetime,po.order_datetime) > surg.surgery_end_datetime AND ISNULL(por.result_datetime,po.order_datetime) < DATEADD(day,2,surg.surgery_end_datetime) THEN 1 ELSE 0 END

ORDER BY surg.surgical_case_key

--SELECT * FROM #measurements
--SELECT * FROM #surgeries
--SELECT * FROM #sepsis
--SELECT * FROM #mostrecent_diagnoses


--SELECT DISTINCT
 
--	s.surgical_case_key
--	, s.ir_id
--	, DATEDIFF(year,s.birth_date,s.surgery_start_datetime) AS age
--	, race_1
--	, gender
--	, s.procedure_name
--	, DATEDIFF(MINUTE,s.surgery_start_datetime,s.surgery_end_datetime) AS surgery_length
--	, MAX(CASE WHEN measurement_name = 'weight' THEN [max] WHEN measurement_name = 'weight/scale' THEN [max]/16 END) AS weight
--	, MAX(CASE WHEN measurement_name = 'height' THEN [max] END) AS height
--	--, MAX(CASE WHEN measurement_name = 'bmi_calculated' THEN [max] END) AS bmi
--	, MAX(CASE WHEN measurement_name = 'r_bmi' THEN [max] END) AS r_bmi
--	--lord, forgive me for that which i have wrought
--	, MAX(CASE WHEN pre_op = 1 AND measurement_name =  'transfuse_platelet_pheresis' THEN [countd] END) AS pre_op_transfuse_platelet_pheresis_tx
--	, MAX(CASE WHEN inter_op = 1 AND measurement_name =  'transfuse_platelet_pheresis' THEN [countd] END) AS inter_op_transfuse_platelet_pheresis_tx
--	, MAX(CASE WHEN post_op = 1 AND measurement_name =  'transfuse_platelet_pheresis' THEN [countd] END) AS post_op_transfuse_platelet_pheresis_tx
--	, MAX(CASE WHEN pre_op = 1 AND measurement_name =  'transfuse_rbc' THEN [countd] END) AS pre_op_transfuse_rbc_tx
--	, MAX(CASE WHEN inter_op = 1 AND measurement_name =  'transfuse_rbc' THEN [countd] END) AS inter_op_transfuse_rbc_tx
--	, MAX(CASE WHEN post_op = 1 AND measurement_name =  'transfuse_rbc' THEN [countd] END) AS post_op_transfuse_rbc_tx
--	, MAX(CASE WHEN pre_op = 1 AND measurement_name =  'transfuse_fresh_frozen_plasma' THEN [countd] END) AS pre_op_transfuse_fresh_frozen_plasma_tx
--	, MAX(CASE WHEN inter_op = 1 AND measurement_name =  'transfuse_fresh_frozen_plasma' THEN [countd] END) AS inter_op_transfuse_fresh_frozen_plasma_tx
--	, MAX(CASE WHEN post_op = 1 AND measurement_name =  'transfuse_fresh_frozen_plasma' THEN [countd] END) AS post_op_transfuse_fresh_frozen_plasma_tx
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'respiration' THEN [min] END) AS [pre_op_respiration_min]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'respiration' THEN [max] END) AS [pre_op_respiration_max]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'respiration' THEN [avg] END) AS [pre_op_respiration_avg]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'respiration' THEN [stdev] END) AS [pre_op_respiration_stdev]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'respiration' THEN [count] END) AS [pre_op_respiration_count]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'respiration' THEN [countd] END) AS [pre_op_respiration_countd]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'respiration' THEN [min] END) AS [inter_op_respiration_min]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'respiration' THEN [max] END) AS [inter_op_respiration_max]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'respiration' THEN [avg] END) AS [inter_op_respiration_avg]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'respiration' THEN [stdev] END) AS [inter_op_respiration_stdev]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'respiration' THEN [count] END) AS [inter_op_respiration_count]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'respiration' THEN [countd] END) AS [inter_op_respiration_countd]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'respiration' THEN [min] END) AS [post_op_respiration_min]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'respiration' THEN [max] END) AS [post_op_respiration_max]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'respiration' THEN [avg] END) AS [post_op_respiration_avg]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'respiration' THEN [stdev] END) AS [post_op_respiration_stdev]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'respiration' THEN [count] END) AS [post_op_respiration_count]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'respiration' THEN [countd] END) AS [post_op_respiration_countd]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'percent_of_saturation' THEN [min] END) AS [pre_op_percent_of_saturation_min]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'percent_of_saturation' THEN [max] END) AS [pre_op_percent_of_saturation_max]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'percent_of_saturation' THEN [avg] END) AS [pre_op_percent_of_saturation_avg]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'percent_of_saturation' THEN [stdev] END) AS [pre_op_percent_of_saturation_stdev]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'percent_of_saturation' THEN [count] END) AS [pre_op_percent_of_saturation_count]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'percent_of_saturation' THEN [countd] END) AS [pre_op_percent_of_saturation_countd]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'percent_of_saturation' THEN [min] END) AS [inter_op_percent_of_saturation_min]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'percent_of_saturation' THEN [max] END) AS [inter_op_percent_of_saturation_max]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'percent_of_saturation' THEN [avg] END) AS [inter_op_percent_of_saturation_avg]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'percent_of_saturation' THEN [stdev] END) AS [inter_op_percent_of_saturation_stdev]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'percent_of_saturation' THEN [count] END) AS [inter_op_percent_of_saturation_count]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'percent_of_saturation' THEN [countd] END) AS [inter_op_percent_of_saturation_countd]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'percent_of_saturation' THEN [min] END) AS [post_op_percent_of_saturation_min]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'percent_of_saturation' THEN [max] END) AS [post_op_percent_of_saturation_max]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'percent_of_saturation' THEN [avg] END) AS [post_op_percent_of_saturation_avg]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'percent_of_saturation' THEN [stdev] END) AS [post_op_percent_of_saturation_stdev]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'percent_of_saturation' THEN [count] END) AS [post_op_percent_of_saturation_count]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'percent_of_saturation' THEN [countd] END) AS [post_op_percent_of_saturation_countd]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'pulse' THEN [min] END) AS [pre_op_pulse_min]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'pulse' THEN [max] END) AS [pre_op_pulse_max]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'pulse' THEN [avg] END) AS [pre_op_pulse_avg]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'pulse' THEN [stdev] END) AS [pre_op_pulse_stdev]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'pulse' THEN [count] END) AS [pre_op_pulse_count]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'pulse' THEN [countd] END) AS [pre_op_pulse_countd]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'pulse' THEN [min] END) AS [inter_op_pulse_min]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'pulse' THEN [max] END) AS [inter_op_pulse_max]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'pulse' THEN [avg] END) AS [inter_op_pulse_avg]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'pulse' THEN [stdev] END) AS [inter_op_pulse_stdev]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'pulse' THEN [count] END) AS [inter_op_pulse_count]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'pulse' THEN [countd] END) AS [inter_op_pulse_countd]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'pulse' THEN [min] END) AS [post_op_pulse_min]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'pulse' THEN [max] END) AS [post_op_pulse_max]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'pulse' THEN [avg] END) AS [post_op_pulse_avg]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'pulse' THEN [stdev] END) AS [post_op_pulse_stdev]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'pulse' THEN [count] END) AS [post_op_pulse_count]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'pulse' THEN [countd] END) AS [post_op_pulse_countd]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'diastolic' THEN [min] END) AS [pre_op_diastolic_min]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'diastolic' THEN [max] END) AS [pre_op_diastolic_max]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'diastolic' THEN [avg] END) AS [pre_op_diastolic_avg]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'diastolic' THEN [stdev] END) AS [pre_op_diastolic_stdev]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'diastolic' THEN [count] END) AS [pre_op_diastolic_count]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'diastolic' THEN [countd] END) AS [pre_op_diastolic_countd]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'diastolic' THEN [min] END) AS [inter_op_diastolic_min]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'diastolic' THEN [max] END) AS [inter_op_diastolic_max]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'diastolic' THEN [avg] END) AS [inter_op_diastolic_avg]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'diastolic' THEN [stdev] END) AS [inter_op_diastolic_stdev]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'diastolic' THEN [count] END) AS [inter_op_diastolic_count]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'diastolic' THEN [countd] END) AS [inter_op_diastolic_countd]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'diastolic' THEN [min] END) AS [post_op_diastolic_min]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'diastolic' THEN [max] END) AS [post_op_diastolic_max]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'diastolic' THEN [avg] END) AS [post_op_diastolic_avg]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'diastolic' THEN [stdev] END) AS [post_op_diastolic_stdev]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'diastolic' THEN [count] END) AS [post_op_diastolic_count]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'diastolic' THEN [countd] END) AS [post_op_diastolic_countd]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'systolic' THEN [min] END) AS [pre_op_systolic_min]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'systolic' THEN [max] END) AS [pre_op_systolic_max]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'systolic' THEN [avg] END) AS [pre_op_systolic_avg]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'systolic' THEN [stdev] END) AS [pre_op_systolic_stdev]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'systolic' THEN [count] END) AS [pre_op_systolic_count]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'systolic' THEN [countd] END) AS [pre_op_systolic_countd]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'systolic' THEN [min] END) AS [inter_op_systolic_min]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'systolic' THEN [max] END) AS [inter_op_systolic_max]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'systolic' THEN [avg] END) AS [inter_op_systolic_avg]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'systolic' THEN [stdev] END) AS [inter_op_systolic_stdev]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'systolic' THEN [count] END) AS [inter_op_systolic_count]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'systolic' THEN [countd] END) AS [inter_op_systolic_countd]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'systolic' THEN [min] END) AS [post_op_systolic_min]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'systolic' THEN [max] END) AS [post_op_systolic_max]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'systolic' THEN [avg] END) AS [post_op_systolic_avg]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'systolic' THEN [stdev] END) AS [post_op_systolic_stdev]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'systolic' THEN [count] END) AS [post_op_systolic_count]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'systolic' THEN [countd] END) AS [post_op_systolic_countd]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'temperature_in_f' THEN [min] END) AS [pre_op_temperature_in_f_min]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'temperature_in_f' THEN [max] END) AS [pre_op_temperature_in_f_max]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'temperature_in_f' THEN [avg] END) AS [pre_op_temperature_in_f_avg]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'temperature_in_f' THEN [stdev] END) AS [pre_op_temperature_in_f_stdev]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'temperature_in_f' THEN [count] END) AS [pre_op_temperature_in_f_count]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'temperature_in_f' THEN [countd] END) AS [pre_op_temperature_in_f_countd]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'temperature_in_f' THEN [min] END) AS [inter_op_temperature_in_f_min]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'temperature_in_f' THEN [max] END) AS [inter_op_temperature_in_f_max]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'temperature_in_f' THEN [avg] END) AS [inter_op_temperature_in_f_avg]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'temperature_in_f' THEN [stdev] END) AS [inter_op_temperature_in_f_stdev]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'temperature_in_f' THEN [count] END) AS [inter_op_temperature_in_f_count]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'temperature_in_f' THEN [countd] END) AS [inter_op_temperature_in_f_countd]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'temperature_in_f' THEN [min] END) AS [post_op_temperature_in_f_min]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'temperature_in_f' THEN [max] END) AS [post_op_temperature_in_f_max]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'temperature_in_f' THEN [avg] END) AS [post_op_temperature_in_f_avg]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'temperature_in_f' THEN [stdev] END) AS [post_op_temperature_in_f_stdev]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'temperature_in_f' THEN [count] END) AS [post_op_temperature_in_f_count]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'temperature_in_f' THEN [countd] END) AS [post_op_temperature_in_f_countd]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'glucose_whole_blood_-_blood_gas' THEN [min] END) AS [pre_op_glucose_whole_blood_-_blood_gas_min]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'glucose_whole_blood_-_blood_gas' THEN [max] END) AS [pre_op_glucose_whole_blood_-_blood_gas_max]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'glucose_whole_blood_-_blood_gas' THEN [avg] END) AS [pre_op_glucose_whole_blood_-_blood_gas_avg]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'glucose_whole_blood_-_blood_gas' THEN [stdev] END) AS [pre_op_glucose_whole_blood_-_blood_gas_stdev]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'glucose_whole_blood_-_blood_gas' THEN [count] END) AS [pre_op_glucose_whole_blood_-_blood_gas_count]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'glucose_whole_blood_-_blood_gas' THEN [countd] END) AS [pre_op_glucose_whole_blood_-_blood_gas_countd]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'glucose_whole_blood_-_blood_gas' THEN [min] END) AS [inter_op_glucose_whole_blood_-_blood_gas_min]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'glucose_whole_blood_-_blood_gas' THEN [max] END) AS [inter_op_glucose_whole_blood_-_blood_gas_max]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'glucose_whole_blood_-_blood_gas' THEN [avg] END) AS [inter_op_glucose_whole_blood_-_blood_gas_avg]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'glucose_whole_blood_-_blood_gas' THEN [stdev] END) AS [inter_op_glucose_whole_blood_-_blood_gas_stdev]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'glucose_whole_blood_-_blood_gas' THEN [count] END) AS [inter_op_glucose_whole_blood_-_blood_gas_count]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'glucose_whole_blood_-_blood_gas' THEN [countd] END) AS [inter_op_glucose_whole_blood_-_blood_gas_countd]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'glucose_whole_blood_-_blood_gas' THEN [min] END) AS [post_op_glucose_whole_blood_-_blood_gas_min]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'glucose_whole_blood_-_blood_gas' THEN [max] END) AS [post_op_glucose_whole_blood_-_blood_gas_max]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'glucose_whole_blood_-_blood_gas' THEN [avg] END) AS [post_op_glucose_whole_blood_-_blood_gas_avg]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'glucose_whole_blood_-_blood_gas' THEN [stdev] END) AS [post_op_glucose_whole_blood_-_blood_gas_stdev]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'glucose_whole_blood_-_blood_gas' THEN [count] END) AS [post_op_glucose_whole_blood_-_blood_gas_count]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'glucose_whole_blood_-_blood_gas' THEN [countd] END) AS [post_op_glucose_whole_blood_-_blood_gas_countd]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'white_cell_count' THEN [min] END) AS [pre_op_white_cell_count_min]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'white_cell_count' THEN [max] END) AS [pre_op_white_cell_count_max]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'white_cell_count' THEN [avg] END) AS [pre_op_white_cell_count_avg]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'white_cell_count' THEN [stdev] END) AS [pre_op_white_cell_count_stdev]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'white_cell_count' THEN [count] END) AS [pre_op_white_cell_count_count]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'white_cell_count' THEN [countd] END) AS [pre_op_white_cell_count_countd]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'white_cell_count' THEN [min] END) AS [inter_op_white_cell_count_min]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'white_cell_count' THEN [max] END) AS [inter_op_white_cell_count_max]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'white_cell_count' THEN [avg] END) AS [inter_op_white_cell_count_avg]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'white_cell_count' THEN [stdev] END) AS [inter_op_white_cell_count_stdev]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'white_cell_count' THEN [count] END) AS [inter_op_white_cell_count_count]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'white_cell_count' THEN [countd] END) AS [inter_op_white_cell_count_countd]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'white_cell_count' THEN [min] END) AS [post_op_white_cell_count_min]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'white_cell_count' THEN [max] END) AS [post_op_white_cell_count_max]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'white_cell_count' THEN [avg] END) AS [post_op_white_cell_count_avg]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'white_cell_count' THEN [stdev] END) AS [post_op_white_cell_count_stdev]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'white_cell_count' THEN [count] END) AS [post_op_white_cell_count_count]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'white_cell_count' THEN [countd] END) AS [post_op_white_cell_count_countd]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'hemoglobin' THEN [min] END) AS [pre_op_hemoglobin_min]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'hemoglobin' THEN [max] END) AS [pre_op_hemoglobin_max]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'hemoglobin' THEN [avg] END) AS [pre_op_hemoglobin_avg]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'hemoglobin' THEN [stdev] END) AS [pre_op_hemoglobin_stdev]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'hemoglobin' THEN [count] END) AS [pre_op_hemoglobin_count]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'hemoglobin' THEN [countd] END) AS [pre_op_hemoglobin_countd]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'hemoglobin' THEN [min] END) AS [inter_op_hemoglobin_min]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'hemoglobin' THEN [max] END) AS [inter_op_hemoglobin_max]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'hemoglobin' THEN [avg] END) AS [inter_op_hemoglobin_avg]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'hemoglobin' THEN [stdev] END) AS [inter_op_hemoglobin_stdev]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'hemoglobin' THEN [count] END) AS [inter_op_hemoglobin_count]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'hemoglobin' THEN [countd] END) AS [inter_op_hemoglobin_countd]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'hemoglobin' THEN [min] END) AS [post_op_hemoglobin_min]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'hemoglobin' THEN [max] END) AS [post_op_hemoglobin_max]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'hemoglobin' THEN [avg] END) AS [post_op_hemoglobin_avg]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'hemoglobin' THEN [stdev] END) AS [post_op_hemoglobin_stdev]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'hemoglobin' THEN [count] END) AS [post_op_hemoglobin_count]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'hemoglobin' THEN [countd] END) AS [post_op_hemoglobin_countd]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'platelet_count' THEN [min] END) AS [pre_op_platelet_count_min]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'platelet_count' THEN [max] END) AS [pre_op_platelet_count_max]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'platelet_count' THEN [avg] END) AS [pre_op_platelet_count_avg]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'platelet_count' THEN [stdev] END) AS [pre_op_platelet_count_stdev]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'platelet_count' THEN [count] END) AS [pre_op_platelet_count_count]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'platelet_count' THEN [countd] END) AS [pre_op_platelet_count_countd]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'platelet_count' THEN [min] END) AS [inter_op_platelet_count_min]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'platelet_count' THEN [max] END) AS [inter_op_platelet_count_max]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'platelet_count' THEN [avg] END) AS [inter_op_platelet_count_avg]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'platelet_count' THEN [stdev] END) AS [inter_op_platelet_count_stdev]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'platelet_count' THEN [count] END) AS [inter_op_platelet_count_count]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'platelet_count' THEN [countd] END) AS [inter_op_platelet_count_countd]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'platelet_count' THEN [min] END) AS [post_op_platelet_count_min]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'platelet_count' THEN [max] END) AS [post_op_platelet_count_max]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'platelet_count' THEN [avg] END) AS [post_op_platelet_count_avg]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'platelet_count' THEN [stdev] END) AS [post_op_platelet_count_stdev]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'platelet_count' THEN [count] END) AS [post_op_platelet_count_count]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'platelet_count' THEN [countd] END) AS [post_op_platelet_count_countd]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'sodium' THEN [min] END) AS [pre_op_sodium_min]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'sodium' THEN [max] END) AS [pre_op_sodium_max]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'sodium' THEN [avg] END) AS [pre_op_sodium_avg]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'sodium' THEN [stdev] END) AS [pre_op_sodium_stdev]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'sodium' THEN [count] END) AS [pre_op_sodium_count]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'sodium' THEN [countd] END) AS [pre_op_sodium_countd]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'sodium' THEN [min] END) AS [inter_op_sodium_min]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'sodium' THEN [max] END) AS [inter_op_sodium_max]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'sodium' THEN [avg] END) AS [inter_op_sodium_avg]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'sodium' THEN [stdev] END) AS [inter_op_sodium_stdev]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'sodium' THEN [count] END) AS [inter_op_sodium_count]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'sodium' THEN [countd] END) AS [inter_op_sodium_countd]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'sodium' THEN [min] END) AS [post_op_sodium_min]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'sodium' THEN [max] END) AS [post_op_sodium_max]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'sodium' THEN [avg] END) AS [post_op_sodium_avg]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'sodium' THEN [stdev] END) AS [post_op_sodium_stdev]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'sodium' THEN [count] END) AS [post_op_sodium_count]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'sodium' THEN [countd] END) AS [post_op_sodium_countd]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'potassium' THEN [min] END) AS [pre_op_potassium_min]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'potassium' THEN [max] END) AS [pre_op_potassium_max]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'potassium' THEN [avg] END) AS [pre_op_potassium_avg]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'potassium' THEN [stdev] END) AS [pre_op_potassium_stdev]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'potassium' THEN [count] END) AS [pre_op_potassium_count]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'potassium' THEN [countd] END) AS [pre_op_potassium_countd]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'potassium' THEN [min] END) AS [inter_op_potassium_min]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'potassium' THEN [max] END) AS [inter_op_potassium_max]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'potassium' THEN [avg] END) AS [inter_op_potassium_avg]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'potassium' THEN [stdev] END) AS [inter_op_potassium_stdev]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'potassium' THEN [count] END) AS [inter_op_potassium_count]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'potassium' THEN [countd] END) AS [inter_op_potassium_countd]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'potassium' THEN [min] END) AS [post_op_potassium_min]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'potassium' THEN [max] END) AS [post_op_potassium_max]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'potassium' THEN [avg] END) AS [post_op_potassium_avg]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'potassium' THEN [stdev] END) AS [post_op_potassium_stdev]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'potassium' THEN [count] END) AS [post_op_potassium_count]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'potassium' THEN [countd] END) AS [post_op_potassium_countd]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'chloride' THEN [min] END) AS [pre_op_chloride_min]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'chloride' THEN [max] END) AS [pre_op_chloride_max]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'chloride' THEN [avg] END) AS [pre_op_chloride_avg]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'chloride' THEN [stdev] END) AS [pre_op_chloride_stdev]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'chloride' THEN [count] END) AS [pre_op_chloride_count]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'chloride' THEN [countd] END) AS [pre_op_chloride_countd]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'chloride' THEN [min] END) AS [inter_op_chloride_min]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'chloride' THEN [max] END) AS [inter_op_chloride_max]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'chloride' THEN [avg] END) AS [inter_op_chloride_avg]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'chloride' THEN [stdev] END) AS [inter_op_chloride_stdev]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'chloride' THEN [count] END) AS [inter_op_chloride_count]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'chloride' THEN [countd] END) AS [inter_op_chloride_countd]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'chloride' THEN [min] END) AS [post_op_chloride_min]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'chloride' THEN [max] END) AS [post_op_chloride_max]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'chloride' THEN [avg] END) AS [post_op_chloride_avg]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'chloride' THEN [stdev] END) AS [post_op_chloride_stdev]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'chloride' THEN [count] END) AS [post_op_chloride_count]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'chloride' THEN [countd] END) AS [post_op_chloride_countd]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'blood_urea_nitrogen' THEN [min] END) AS [pre_op_blood_urea_nitrogen_min]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'blood_urea_nitrogen' THEN [max] END) AS [pre_op_blood_urea_nitrogen_max]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'blood_urea_nitrogen' THEN [avg] END) AS [pre_op_blood_urea_nitrogen_avg]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'blood_urea_nitrogen' THEN [stdev] END) AS [pre_op_blood_urea_nitrogen_stdev]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'blood_urea_nitrogen' THEN [count] END) AS [pre_op_blood_urea_nitrogen_count]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'blood_urea_nitrogen' THEN [countd] END) AS [pre_op_blood_urea_nitrogen_countd]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'blood_urea_nitrogen' THEN [min] END) AS [inter_op_blood_urea_nitrogen_min]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'blood_urea_nitrogen' THEN [max] END) AS [inter_op_blood_urea_nitrogen_max]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'blood_urea_nitrogen' THEN [avg] END) AS [inter_op_blood_urea_nitrogen_avg]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'blood_urea_nitrogen' THEN [stdev] END) AS [inter_op_blood_urea_nitrogen_stdev]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'blood_urea_nitrogen' THEN [count] END) AS [inter_op_blood_urea_nitrogen_count]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'blood_urea_nitrogen' THEN [countd] END) AS [inter_op_blood_urea_nitrogen_countd]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'blood_urea_nitrogen' THEN [min] END) AS [post_op_blood_urea_nitrogen_min]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'blood_urea_nitrogen' THEN [max] END) AS [post_op_blood_urea_nitrogen_max]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'blood_urea_nitrogen' THEN [avg] END) AS [post_op_blood_urea_nitrogen_avg]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'blood_urea_nitrogen' THEN [stdev] END) AS [post_op_blood_urea_nitrogen_stdev]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'blood_urea_nitrogen' THEN [count] END) AS [post_op_blood_urea_nitrogen_count]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'blood_urea_nitrogen' THEN [countd] END) AS [post_op_blood_urea_nitrogen_countd]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'creatinine' THEN [min] END) AS [pre_op_creatinine_min]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'creatinine' THEN [max] END) AS [pre_op_creatinine_max]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'creatinine' THEN [avg] END) AS [pre_op_creatinine_avg]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'creatinine' THEN [stdev] END) AS [pre_op_creatinine_stdev]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'creatinine' THEN [count] END) AS [pre_op_creatinine_count]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'creatinine' THEN [countd] END) AS [pre_op_creatinine_countd]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'creatinine' THEN [min] END) AS [inter_op_creatinine_min]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'creatinine' THEN [max] END) AS [inter_op_creatinine_max]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'creatinine' THEN [avg] END) AS [inter_op_creatinine_avg]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'creatinine' THEN [stdev] END) AS [inter_op_creatinine_stdev]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'creatinine' THEN [count] END) AS [inter_op_creatinine_count]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'creatinine' THEN [countd] END) AS [inter_op_creatinine_countd]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'creatinine' THEN [min] END) AS [post_op_creatinine_min]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'creatinine' THEN [max] END) AS [post_op_creatinine_max]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'creatinine' THEN [avg] END) AS [post_op_creatinine_avg]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'creatinine' THEN [stdev] END) AS [post_op_creatinine_stdev]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'creatinine' THEN [count] END) AS [post_op_creatinine_count]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'creatinine' THEN [countd] END) AS [post_op_creatinine_countd]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'phosphorus' THEN [min] END) AS [pre_op_phosphorus_min]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'phosphorus' THEN [max] END) AS [pre_op_phosphorus_max]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'phosphorus' THEN [avg] END) AS [pre_op_phosphorus_avg]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'phosphorus' THEN [stdev] END) AS [pre_op_phosphorus_stdev]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'phosphorus' THEN [count] END) AS [pre_op_phosphorus_count]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'phosphorus' THEN [countd] END) AS [pre_op_phosphorus_countd]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'phosphorus' THEN [min] END) AS [inter_op_phosphorus_min]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'phosphorus' THEN [max] END) AS [inter_op_phosphorus_max]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'phosphorus' THEN [avg] END) AS [inter_op_phosphorus_avg]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'phosphorus' THEN [stdev] END) AS [inter_op_phosphorus_stdev]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'phosphorus' THEN [count] END) AS [inter_op_phosphorus_count]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'phosphorus' THEN [countd] END) AS [inter_op_phosphorus_countd]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'phosphorus' THEN [min] END) AS [post_op_phosphorus_min]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'phosphorus' THEN [max] END) AS [post_op_phosphorus_max]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'phosphorus' THEN [avg] END) AS [post_op_phosphorus_avg]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'phosphorus' THEN [stdev] END) AS [post_op_phosphorus_stdev]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'phosphorus' THEN [count] END) AS [post_op_phosphorus_count]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'phosphorus' THEN [countd] END) AS [post_op_phosphorus_countd]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'magnesium' THEN [min] END) AS [pre_op_magnesium_min]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'magnesium' THEN [max] END) AS [pre_op_magnesium_max]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'magnesium' THEN [avg] END) AS [pre_op_magnesium_avg]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'magnesium' THEN [stdev] END) AS [pre_op_magnesium_stdev]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'magnesium' THEN [count] END) AS [pre_op_magnesium_count]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'magnesium' THEN [countd] END) AS [pre_op_magnesium_countd]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'magnesium' THEN [min] END) AS [inter_op_magnesium_min]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'magnesium' THEN [max] END) AS [inter_op_magnesium_max]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'magnesium' THEN [avg] END) AS [inter_op_magnesium_avg]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'magnesium' THEN [stdev] END) AS [inter_op_magnesium_stdev]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'magnesium' THEN [count] END) AS [inter_op_magnesium_count]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'magnesium' THEN [countd] END) AS [inter_op_magnesium_countd]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'magnesium' THEN [min] END) AS [post_op_magnesium_min]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'magnesium' THEN [max] END) AS [post_op_magnesium_max]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'magnesium' THEN [avg] END) AS [post_op_magnesium_avg]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'magnesium' THEN [stdev] END) AS [post_op_magnesium_stdev]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'magnesium' THEN [count] END) AS [post_op_magnesium_count]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'magnesium' THEN [countd] END) AS [post_op_magnesium_countd]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'calcium' THEN [min] END) AS [pre_op_calcium_min]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'calcium' THEN [max] END) AS [pre_op_calcium_max]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'calcium' THEN [avg] END) AS [pre_op_calcium_avg]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'calcium' THEN [stdev] END) AS [pre_op_calcium_stdev]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'calcium' THEN [count] END) AS [pre_op_calcium_count]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'calcium' THEN [countd] END) AS [pre_op_calcium_countd]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'calcium' THEN [min] END) AS [inter_op_calcium_min]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'calcium' THEN [max] END) AS [inter_op_calcium_max]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'calcium' THEN [avg] END) AS [inter_op_calcium_avg]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'calcium' THEN [stdev] END) AS [inter_op_calcium_stdev]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'calcium' THEN [count] END) AS [inter_op_calcium_count]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'calcium' THEN [countd] END) AS [inter_op_calcium_countd]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'calcium' THEN [min] END) AS [post_op_calcium_min]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'calcium' THEN [max] END) AS [post_op_calcium_max]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'calcium' THEN [avg] END) AS [post_op_calcium_avg]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'calcium' THEN [stdev] END) AS [post_op_calcium_stdev]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'calcium' THEN [count] END) AS [post_op_calcium_count]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'calcium' THEN [countd] END) AS [post_op_calcium_countd]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'albumin' THEN [min] END) AS [pre_op_albumin_min]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'albumin' THEN [max] END) AS [pre_op_albumin_max]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'albumin' THEN [avg] END) AS [pre_op_albumin_avg]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'albumin' THEN [stdev] END) AS [pre_op_albumin_stdev]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'albumin' THEN [count] END) AS [pre_op_albumin_count]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'albumin' THEN [countd] END) AS [pre_op_albumin_countd]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'albumin' THEN [min] END) AS [inter_op_albumin_min]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'albumin' THEN [max] END) AS [inter_op_albumin_max]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'albumin' THEN [avg] END) AS [inter_op_albumin_avg]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'albumin' THEN [stdev] END) AS [inter_op_albumin_stdev]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'albumin' THEN [count] END) AS [inter_op_albumin_count]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'albumin' THEN [countd] END) AS [inter_op_albumin_countd]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'albumin' THEN [min] END) AS [post_op_albumin_min]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'albumin' THEN [max] END) AS [post_op_albumin_max]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'albumin' THEN [avg] END) AS [post_op_albumin_avg]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'albumin' THEN [stdev] END) AS [post_op_albumin_stdev]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'albumin' THEN [count] END) AS [post_op_albumin_count]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'albumin' THEN [countd] END) AS [post_op_albumin_countd]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'bilirubin_-_total' THEN [min] END) AS [pre_op_bilirubin_-_total_min]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'bilirubin_-_total' THEN [max] END) AS [pre_op_bilirubin_-_total_max]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'bilirubin_-_total' THEN [avg] END) AS [pre_op_bilirubin_-_total_avg]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'bilirubin_-_total' THEN [stdev] END) AS [pre_op_bilirubin_-_total_stdev]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'bilirubin_-_total' THEN [count] END) AS [pre_op_bilirubin_-_total_count]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'bilirubin_-_total' THEN [countd] END) AS [pre_op_bilirubin_-_total_countd]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'bilirubin_-_total' THEN [min] END) AS [inter_op_bilirubin_-_total_min]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'bilirubin_-_total' THEN [max] END) AS [inter_op_bilirubin_-_total_max]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'bilirubin_-_total' THEN [avg] END) AS [inter_op_bilirubin_-_total_avg]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'bilirubin_-_total' THEN [stdev] END) AS [inter_op_bilirubin_-_total_stdev]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'bilirubin_-_total' THEN [count] END) AS [inter_op_bilirubin_-_total_count]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'bilirubin_-_total' THEN [countd] END) AS [inter_op_bilirubin_-_total_countd]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'bilirubin_-_total' THEN [min] END) AS [post_op_bilirubin_-_total_min]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'bilirubin_-_total' THEN [max] END) AS [post_op_bilirubin_-_total_max]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'bilirubin_-_total' THEN [avg] END) AS [post_op_bilirubin_-_total_avg]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'bilirubin_-_total' THEN [stdev] END) AS [post_op_bilirubin_-_total_stdev]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'bilirubin_-_total' THEN [count] END) AS [post_op_bilirubin_-_total_count]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'bilirubin_-_total' THEN [countd] END) AS [post_op_bilirubin_-_total_countd]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'alkaline_phosphatase' THEN [min] END) AS [pre_op_alkaline_phosphatase_min]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'alkaline_phosphatase' THEN [max] END) AS [pre_op_alkaline_phosphatase_max]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'alkaline_phosphatase' THEN [avg] END) AS [pre_op_alkaline_phosphatase_avg]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'alkaline_phosphatase' THEN [stdev] END) AS [pre_op_alkaline_phosphatase_stdev]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'alkaline_phosphatase' THEN [count] END) AS [pre_op_alkaline_phosphatase_count]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'alkaline_phosphatase' THEN [countd] END) AS [pre_op_alkaline_phosphatase_countd]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'alkaline_phosphatase' THEN [min] END) AS [inter_op_alkaline_phosphatase_min]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'alkaline_phosphatase' THEN [max] END) AS [inter_op_alkaline_phosphatase_max]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'alkaline_phosphatase' THEN [avg] END) AS [inter_op_alkaline_phosphatase_avg]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'alkaline_phosphatase' THEN [stdev] END) AS [inter_op_alkaline_phosphatase_stdev]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'alkaline_phosphatase' THEN [count] END) AS [inter_op_alkaline_phosphatase_count]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'alkaline_phosphatase' THEN [countd] END) AS [inter_op_alkaline_phosphatase_countd]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'alkaline_phosphatase' THEN [min] END) AS [post_op_alkaline_phosphatase_min]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'alkaline_phosphatase' THEN [max] END) AS [post_op_alkaline_phosphatase_max]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'alkaline_phosphatase' THEN [avg] END) AS [post_op_alkaline_phosphatase_avg]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'alkaline_phosphatase' THEN [stdev] END) AS [post_op_alkaline_phosphatase_stdev]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'alkaline_phosphatase' THEN [count] END) AS [post_op_alkaline_phosphatase_count]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'alkaline_phosphatase' THEN [countd] END) AS [post_op_alkaline_phosphatase_countd]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'inr_(inr2)' THEN [min] END) AS [pre_op_inr_(inr2)_min]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'inr_(inr2)' THEN [max] END) AS [pre_op_inr_(inr2)_max]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'inr_(inr2)' THEN [avg] END) AS [pre_op_inr_(inr2)_avg]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'inr_(inr2)' THEN [stdev] END) AS [pre_op_inr_(inr2)_stdev]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'inr_(inr2)' THEN [count] END) AS [pre_op_inr_(inr2)_count]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'inr_(inr2)' THEN [countd] END) AS [pre_op_inr_(inr2)_countd]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'inr_(inr2)' THEN [min] END) AS [inter_op_inr_(inr2)_min]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'inr_(inr2)' THEN [max] END) AS [inter_op_inr_(inr2)_max]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'inr_(inr2)' THEN [avg] END) AS [inter_op_inr_(inr2)_avg]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'inr_(inr2)' THEN [stdev] END) AS [inter_op_inr_(inr2)_stdev]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'inr_(inr2)' THEN [count] END) AS [inter_op_inr_(inr2)_count]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'inr_(inr2)' THEN [countd] END) AS [inter_op_inr_(inr2)_countd]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'inr_(inr2)' THEN [min] END) AS [post_op_inr_(inr2)_min]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'inr_(inr2)' THEN [max] END) AS [post_op_inr_(inr2)_max]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'inr_(inr2)' THEN [avg] END) AS [post_op_inr_(inr2)_avg]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'inr_(inr2)' THEN [stdev] END) AS [post_op_inr_(inr2)_stdev]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'inr_(inr2)' THEN [count] END) AS [post_op_inr_(inr2)_count]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'inr_(inr2)' THEN [countd] END) AS [post_op_inr_(inr2)_countd]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'glucose_level' THEN [min] END) AS [pre_op_glucose_level_min]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'glucose_level' THEN [max] END) AS [pre_op_glucose_level_max]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'glucose_level' THEN [avg] END) AS [pre_op_glucose_level_avg]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'glucose_level' THEN [stdev] END) AS [pre_op_glucose_level_stdev]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'glucose_level' THEN [count] END) AS [pre_op_glucose_level_count]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'glucose_level' THEN [countd] END) AS [pre_op_glucose_level_countd]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'glucose_level' THEN [min] END) AS [inter_op_glucose_level_min]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'glucose_level' THEN [max] END) AS [inter_op_glucose_level_max]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'glucose_level' THEN [avg] END) AS [inter_op_glucose_level_avg]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'glucose_level' THEN [stdev] END) AS [inter_op_glucose_level_stdev]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'glucose_level' THEN [count] END) AS [inter_op_glucose_level_count]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'glucose_level' THEN [countd] END) AS [inter_op_glucose_level_countd]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'glucose_level' THEN [min] END) AS [post_op_glucose_level_min]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'glucose_level' THEN [max] END) AS [post_op_glucose_level_max]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'glucose_level' THEN [avg] END) AS [post_op_glucose_level_avg]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'glucose_level' THEN [stdev] END) AS [post_op_glucose_level_stdev]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'glucose_level' THEN [count] END) AS [post_op_glucose_level_count]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'glucose_level' THEN [countd] END) AS [post_op_glucose_level_countd]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'bedside_glucose' THEN [min] END) AS [pre_op_bedside_glucose_min]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'bedside_glucose' THEN [max] END) AS [pre_op_bedside_glucose_max]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'bedside_glucose' THEN [avg] END) AS [pre_op_bedside_glucose_avg]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'bedside_glucose' THEN [stdev] END) AS [pre_op_bedside_glucose_stdev]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'bedside_glucose' THEN [count] END) AS [pre_op_bedside_glucose_count]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'bedside_glucose' THEN [countd] END) AS [pre_op_bedside_glucose_countd]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'bedside_glucose' THEN [min] END) AS [inter_op_bedside_glucose_min]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'bedside_glucose' THEN [max] END) AS [inter_op_bedside_glucose_max]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'bedside_glucose' THEN [avg] END) AS [inter_op_bedside_glucose_avg]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'bedside_glucose' THEN [stdev] END) AS [inter_op_bedside_glucose_stdev]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'bedside_glucose' THEN [count] END) AS [inter_op_bedside_glucose_count]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'bedside_glucose' THEN [countd] END) AS [inter_op_bedside_glucose_countd]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'bedside_glucose' THEN [min] END) AS [post_op_bedside_glucose_min]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'bedside_glucose' THEN [max] END) AS [post_op_bedside_glucose_max]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'bedside_glucose' THEN [avg] END) AS [post_op_bedside_glucose_avg]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'bedside_glucose' THEN [stdev] END) AS [post_op_bedside_glucose_stdev]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'bedside_glucose' THEN [count] END) AS [post_op_bedside_glucose_count]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'bedside_glucose' THEN [countd] END) AS [post_op_bedside_glucose_countd]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'lactic_acid_-_blood_gas' THEN [min] END) AS [pre_op_lactic_acid_-_blood_gas_min]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'lactic_acid_-_blood_gas' THEN [max] END) AS [pre_op_lactic_acid_-_blood_gas_max]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'lactic_acid_-_blood_gas' THEN [avg] END) AS [pre_op_lactic_acid_-_blood_gas_avg]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'lactic_acid_-_blood_gas' THEN [stdev] END) AS [pre_op_lactic_acid_-_blood_gas_stdev]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'lactic_acid_-_blood_gas' THEN [count] END) AS [pre_op_lactic_acid_-_blood_gas_count]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'lactic_acid_-_blood_gas' THEN [countd] END) AS [pre_op_lactic_acid_-_blood_gas_countd]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'lactic_acid_-_blood_gas' THEN [min] END) AS [inter_op_lactic_acid_-_blood_gas_min]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'lactic_acid_-_blood_gas' THEN [max] END) AS [inter_op_lactic_acid_-_blood_gas_max]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'lactic_acid_-_blood_gas' THEN [avg] END) AS [inter_op_lactic_acid_-_blood_gas_avg]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'lactic_acid_-_blood_gas' THEN [stdev] END) AS [inter_op_lactic_acid_-_blood_gas_stdev]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'lactic_acid_-_blood_gas' THEN [count] END) AS [inter_op_lactic_acid_-_blood_gas_count]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'lactic_acid_-_blood_gas' THEN [countd] END) AS [inter_op_lactic_acid_-_blood_gas_countd]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'lactic_acid_-_blood_gas' THEN [min] END) AS [post_op_lactic_acid_-_blood_gas_min]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'lactic_acid_-_blood_gas' THEN [max] END) AS [post_op_lactic_acid_-_blood_gas_max]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'lactic_acid_-_blood_gas' THEN [avg] END) AS [post_op_lactic_acid_-_blood_gas_avg]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'lactic_acid_-_blood_gas' THEN [stdev] END) AS [post_op_lactic_acid_-_blood_gas_stdev]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'lactic_acid_-_blood_gas' THEN [count] END) AS [post_op_lactic_acid_-_blood_gas_count]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'lactic_acid_-_blood_gas' THEN [countd] END) AS [post_op_lactic_acid_-_blood_gas_countd]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'pain_assessment' THEN [min] END) AS [pre_op_pain_assessment_min]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'pain_assessment' THEN [max] END) AS [pre_op_pain_assessment_max]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'pain_assessment' THEN [avg] END) AS [pre_op_pain_assessment_avg]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'pain_assessment' THEN [stdev] END) AS [pre_op_pain_assessment_stdev]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'pain_assessment' THEN [count] END) AS [pre_op_pain_assessment_count]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'pain_assessment' THEN [countd] END) AS [pre_op_pain_assessment_countd]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'pain_assessment' THEN [min] END) AS [inter_op_pain_assessment_min]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'pain_assessment' THEN [max] END) AS [inter_op_pain_assessment_max]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'pain_assessment' THEN [avg] END) AS [inter_op_pain_assessment_avg]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'pain_assessment' THEN [stdev] END) AS [inter_op_pain_assessment_stdev]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'pain_assessment' THEN [count] END) AS [inter_op_pain_assessment_count]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'pain_assessment' THEN [countd] END) AS [inter_op_pain_assessment_countd]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'pain_assessment' THEN [min] END) AS [post_op_pain_assessment_min]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'pain_assessment' THEN [max] END) AS [post_op_pain_assessment_max]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'pain_assessment' THEN [avg] END) AS [post_op_pain_assessment_avg]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'pain_assessment' THEN [stdev] END) AS [post_op_pain_assessment_stdev]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'pain_assessment' THEN [count] END) AS [post_op_pain_assessment_count]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'pain_assessment' THEN [countd] END) AS [post_op_pain_assessment_countd]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'pain_assessment,_iview_icu_q_12_hours' THEN [min] END) AS [pre_op_pain_assessment,_iview_icu_q_12_hours_min]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'pain_assessment,_iview_icu_q_12_hours' THEN [max] END) AS [pre_op_pain_assessment,_iview_icu_q_12_hours_max]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'pain_assessment,_iview_icu_q_12_hours' THEN [avg] END) AS [pre_op_pain_assessment,_iview_icu_q_12_hours_avg]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'pain_assessment,_iview_icu_q_12_hours' THEN [stdev] END) AS [pre_op_pain_assessment,_iview_icu_q_12_hours_stdev]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'pain_assessment,_iview_icu_q_12_hours' THEN [count] END) AS [pre_op_pain_assessment,_iview_icu_q_12_hours_count]
--	--, MAX(CASE WHEN pre_op = 1 AND measurement_name = 'pain_assessment,_iview_icu_q_12_hours' THEN [countd] END) AS [pre_op_pain_assessment,_iview_icu_q_12_hours_countd]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'pain_assessment,_iview_icu_q_12_hours' THEN [min] END) AS [inter_op_pain_assessment,_iview_icu_q_12_hours_min]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'pain_assessment,_iview_icu_q_12_hours' THEN [max] END) AS [inter_op_pain_assessment,_iview_icu_q_12_hours_max]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'pain_assessment,_iview_icu_q_12_hours' THEN [avg] END) AS [inter_op_pain_assessment,_iview_icu_q_12_hours_avg]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'pain_assessment,_iview_icu_q_12_hours' THEN [stdev] END) AS [inter_op_pain_assessment,_iview_icu_q_12_hours_stdev]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'pain_assessment,_iview_icu_q_12_hours' THEN [count] END) AS [inter_op_pain_assessment,_iview_icu_q_12_hours_count]
--	--, MAX(CASE WHEN inter_op = 1 AND measurement_name = 'pain_assessment,_iview_icu_q_12_hours' THEN [countd] END) AS [inter_op_pain_assessment,_iview_icu_q_12_hours_countd]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'pain_assessment,_iview_icu_q_12_hours' THEN [min] END) AS [post_op_pain_assessment,_iview_icu_q_12_hours_min]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'pain_assessment,_iview_icu_q_12_hours' THEN [max] END) AS [post_op_pain_assessment,_iview_icu_q_12_hours_max]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'pain_assessment,_iview_icu_q_12_hours' THEN [avg] END) AS [post_op_pain_assessment,_iview_icu_q_12_hours_avg]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'pain_assessment,_iview_icu_q_12_hours' THEN [stdev] END) AS [post_op_pain_assessment,_iview_icu_q_12_hours_stdev]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'pain_assessment,_iview_icu_q_12_hours' THEN [count] END) AS [post_op_pain_assessment,_iview_icu_q_12_hours_count]
--	--, MAX(CASE WHEN post_op = 1 AND measurement_name = 'pain_assessment,_iview_icu_q_12_hours' THEN [countd] END) AS [post_op_pain_assessment,_iview_icu_q_12_hours_countd]


--	, s.surgery_start_datetime
--	, sep.start_datetime as sepsis_start_datetime
--	, s.athena_mrn
--	, s.idx_mrn
--	, s.lfh_mrn
--	, s.nmff_mrn
--	, s.nmh_mrn
--	, s.west_mrn

--FROM #surgeries s
--LEFT OUTER JOIN #measurements m
--	ON s.surgical_case_key = m.surgical_case_key
--LEFT OUTER JOIN #sepsis sep
--	ON sep.ir_id = s.ir_id

--GROUP BY

--	s.surgical_case_key
--	, s.ir_id
--	, s.surgery_start_datetime
--	, sep.start_datetime
--	, s.athena_mrn
--	, s.idx_mrn
--	, s.lfh_mrn
--	, s.nmff_mrn
--	, s.nmh_mrn
--	, s.west_mrn
--	, DATEDIFF(year,s.birth_date,s.surgery_start_datetime)
--	, race_1
--	, gender
--	, DATEDIFF(MINUTE,s.surgery_start_datetime,s.surgery_end_datetime)
	
--	, s.procedure_name
--ORDER BY s.surgical_case_key

---------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------
-- diagnoses_load script
------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------

USE NM_BI;

SET NOCOUNT ON;

IF OBJECT_ID('tempdb..#search_terms') IS NOT NULL BEGIN DROP TABLE #search_terms END;
CREATE TABLE #search_terms (the_counter INT IDENTITY(0,1), common_name VARCHAR(100),search_terms VARCHAR(MAX));

INSERT #search_terms (common_name,search_terms)
SELECT 'Smoking','(diagnosis_name LIKE ''%smok%'' OR diagnosis_name LIKE ''%cig%'')'
UNION SELECT 'Diabetes','(diagnosis_name LIKE ''%diabetes mellitus%'')'
UNION SELECT 'Alcohol use','(diagnosis_code_base = ''F10'')'
UNION SELECT 'Chronic obstructive pulmonary disease (COPD)','(diagnosis_code_base IN (''J40'',''J41'',''J42'',''J43'',''J44'',''J47''))'
UNION SELECT 'Ascites','(diagnosis_code_base = ''R18'')'
UNION SELECT 'Cirrhosis','(diagnosis_code_base IN (''K70'',''K71'',''K74''))'
UNION SELECT 'Congestive heart failure','(diagnosis_name LIKE ''%congestive heart%'')'
UNION SELECT 'Coronary artery disease','(diagnosis_code_base IN (''I20'',''I21'',''I22'',''I23'',''I24'',''I25''))'
UNION SELECT 'Hypertension','(diagnosis_code_base IN (''I10'',''I11'',''I12'',''I13'',''I15''))'
UNION SELECT 'Peripheral vascular disease','(diagnosis_code = ''I73.9'')'
UNION SELECT 'Renal failure','(diagnosis_code_base IN (''N17'',''N18'',''N19''))'
UNION SELECT 'Stroke','(diagnosis_code_base IN (''I61'',''I62'',''I63'',''I64''))'



DECLARE @i INT = 0;

DECLARE @full_diagnosis_search NVARCHAR(MAX) = 'SET NOCOUNT ON;
DECLARE @date_limiter DATE = ''2017-01-01'' ';
DECLARE @diagnosis_search NVARCHAR(MAX);
DECLARE @the_common_name VARCHAR(100);
DECLARE @the_search_terms VARCHAR(MAX);

WHILE @i < (SELECT COUNT(*) FROM #search_terms)
BEGIN
	SET @the_common_name = (SELECT common_name FROM #search_terms WHERE the_counter = @i)
	SET @the_search_terms = (SELECT search_terms FROM #search_terms WHERE the_counter = @i)
	SET @diagnosis_search = N'
		SELECT DISTINCT
			''' + @the_common_name + ''' AS common_name
			, dti.diagnosis_key

		FROM dim.diagnosis_terminology dti
		INNER JOIN fact.diagnosis_event de
			ON dti.diagnosis_key = de.diagnosis_key
		WHERE ' + @the_search_terms + '
		AND de.start_date_key > @date_limiter
		UNION ALL '

	SET @full_diagnosis_search = @full_diagnosis_search + @diagnosis_search;
	SET @i = @i + 1;

END;

SET @full_diagnosis_search = LEFT(@full_diagnosis_search,LEN(@full_diagnosis_search)-10);

IF OBJECT_ID('tempdb..#diagnosis_common_name') IS NOT NULL BEGIN DROP TABLE #diagnosis_common_name END;
CREATE TABLE #diagnosis_common_name ( common_name VARCHAR(max), diagnosis_key VARCHAR(max) )

INSERT INTO #diagnosis_common_name
EXECUTE sp_executesql @full_diagnosis_search;

SELECT * FROM #diagnosis_common_name

-------------------------------------------------------------------------------------------------------------------
--load analysis table.sql 
-----------------------------------------------------------------------------------------------------------------
--USE Sepsis

-------------Preparations-------------

-------------Deciding the measurements/labs to include-------------
--USE Sepsis

-------------Preparations-------------

-------------Deciding the measurements/labs to include-------------

IF OBJECT_ID('tempdb..#all_measurements') IS NOT NULL BEGIN DROP TABLE #all_measurements END;

SELECT TOP 20
	IDENTITY(INT,0,1) AS the_counter
	, measurement_name
	, COUNT(*) AS num
INTO #all_measurements
FROM #measurements
GROUP BY measurement_name
ORDER BY COUNT(*) DESC

-------------Deciding the diagnoses to include-------------

IF OBJECT_ID('tempdb..#all_diagnoses') IS NOT NULL BEGIN DROP TABLE #all_diagnoses END;
CREATE TABLE #all_diagnoses (the_counter INT IDENTITY(0,1),diagnosis_name VARCHAR(200),num INT)
INSERT #all_diagnoses (diagnosis_name)
SELECT DISTINCT common_name
FROM #diagnosis_common_name

--SELECT * FROM #all_diagnoses 

INSERT #all_diagnoses (diagnosis_name,num)
SELECT TOP 50
	mrd.diagnosis_code AS diagnosis_name
	, COUNT(DISTINCT mrd.surgical_case_key) as num

FROM #most_recent_diagnoses mrd
LEFT OUTER JOIN #diagnosis_common_name dcn
	ON dcn.diagnosis_key = mrd.diagnosis_key
WHERE dcn.common_name IS NULL
GROUP BY mrd.diagnosis_code
ORDER BY COUNT(DISTINCT mrd.surgical_case_key) DESC

--DECLARE @i INT = 0
SET @i = 0 
DECLARE @all_measurement_selects VARCHAR(MAX)
SET @all_measurement_selects = ''

-------------Make the select statements for measurements/labs-------------


WHILE @i < (SELECT COUNT(*) FROM #all_measurements)
BEGIN

	DECLARE @measurement_selects VARCHAR(MAX)
	DECLARE @measurement_name VARCHAR(200)

	SET @measurement_name = (SELECT measurement_name FROM #all_measurements WHERE the_counter = @i)
	SET @measurement_selects = ', MAX(CASE WHEN pre_op = 1 AND measurement_name = ''' + @measurement_name + ''' THEN [min] END) AS [pre_op_' + @measurement_name + '_min]
		, MAX(CASE WHEN pre_op = 1 AND measurement_name = ''' + @measurement_name + ''' THEN [max] END) AS [pre_op_' + @measurement_name + '_max]
		, MAX(CASE WHEN pre_op = 1 AND measurement_name = ''' + @measurement_name + ''' THEN [avg] END) AS [pre_op_' + @measurement_name + '_avg]
		, MAX(CASE WHEN pre_op = 1 AND measurement_name = ''' + @measurement_name + ''' THEN [stdev] END) AS [pre_op_' + @measurement_name + '_stdev]
		, MAX(CASE WHEN pre_op = 1 AND measurement_name = ''' + @measurement_name + ''' THEN [countd] END) AS [pre_op_' + @measurement_name + '_countd]
		, MAX(CASE WHEN inter_op = 1 AND measurement_name = ''' + @measurement_name + ''' THEN [min] END) AS [inter_op_' + @measurement_name + '_min]
		, MAX(CASE WHEN inter_op = 1 AND measurement_name = ''' + @measurement_name + ''' THEN [max] END) AS [inter_op_' + @measurement_name + '_max]
		, MAX(CASE WHEN inter_op = 1 AND measurement_name = ''' + @measurement_name + ''' THEN [avg] END) AS [inter_op_' + @measurement_name + '_avg]
		, MAX(CASE WHEN inter_op = 1 AND measurement_name = ''' + @measurement_name + ''' THEN [stdev] END) AS [inter_op_' + @measurement_name + '_stdev]
		, MAX(CASE WHEN inter_op = 1 AND measurement_name = ''' + @measurement_name + ''' THEN [countd] END) AS [inter_op_' + @measurement_name + '_countd]
		, MAX(CASE WHEN post_op = 1 AND measurement_name = ''' + @measurement_name + ''' THEN [min] END) AS [post_op_' + @measurement_name + '_min]
		, MAX(CASE WHEN post_op = 1 AND measurement_name = ''' + @measurement_name + ''' THEN [max] END) AS [post_op_' + @measurement_name + '_max]
		, MAX(CASE WHEN post_op = 1 AND measurement_name = ''' + @measurement_name + ''' THEN [avg] END) AS [post_op_' + @measurement_name + '_avg]
		, MAX(CASE WHEN post_op = 1 AND measurement_name = ''' + @measurement_name + ''' THEN [stdev] END) AS [post_op_' + @measurement_name + '_stdev]
		, MAX(CASE WHEN post_op = 1 AND measurement_name = ''' + @measurement_name + ''' THEN [countd] END) AS [post_op_' + @measurement_name + '_countd]'

	SET @all_measurement_selects = @all_measurement_selects + @measurement_selects

	SET @i = @i + 1

END;

SELECT * FROM #all_diagnoses 

-------------Making the select statements for diagnoses-------------

SET @i = 0
DECLARE @all_diagnosis_selects VARCHAR(MAX)
SET @all_diagnosis_selects = ''

WHILE @i < (SELECT COUNT(*) FROM #all_diagnoses)
BEGIN

	DECLARE @diagnosis_select VARCHAR(MAX)
	DECLARE @diagnosis_name VARCHAR(200)

	SET @diagnosis_name = (SELECT diagnosis_name FROM #all_diagnoses WHERE the_counter = @i)
	--used to be ', MAX(CASE WHEN ISNULL(dcn.common_name,''zz_'' + mrd.diagnosis_code) = ''' + @diagnosis_name + ''' THEN 1 ELSE 0 END) AS [' + @diagnosis_name + ']'
	SET @diagnosis_select = ', MAX(CASE WHEN ISNULL(dcn.common_name,mrd.diagnosis_code) = ''' + @diagnosis_name + ''' THEN 1 ELSE 0 END) AS [' + @diagnosis_name + ']'

	SET @all_diagnosis_selects = @all_diagnosis_selects + @diagnosis_select

	SET @i = @i + 1

END;

DECLARE @query_loop NVARCHAR(MAX)

-------------Looping through query so we can get status updates-------------
select top 10 * FROM #surgeries 


DECLARE @surgery_count INT
DECLARE @per_group INT = 500
SET @surgery_count = (SELECT MAX(the_counter) FROM #surgeries)
PRINT(@surgery_count)
SET @i = 0
DECLARE @max_i INT = CAST(@surgery_count/@per_group AS INT)

WHILE @i <= @max_i
BEGIN
SET @query_loop = N'SELECT DISTINCT
 
	s.surgical_case_key
	, s.west_mrn
	, s.ir_id
	, DATEDIFF(year,s.birth_date,s.surgery_start_datetime) AS age
	, race_1
	, gender
	, s.procedure_name
	, s.death_date
	, s.surgery_start_datetime 
	, s.surgery_end_datetime 
	--, sep.min_sepsis_datetime
	--, sep.max_sepsis_datetime
	, DATEDIFF(MINUTE,s.surgery_start_date_key,s.surgery_end_date_key) AS surgery_length
	, MAX(CASE WHEN pre_op = 1 AND measurement_name =  ''transfuse_platelet_pheresis'' THEN [countd] END) AS pre_op_transfuse_platelet_pheresis_tx
	, MAX(CASE WHEN inter_op = 1 AND measurement_name =  ''transfuse_platelet_pheresis'' THEN [countd] END) AS inter_op_transfuse_platelet_pheresis_tx
	, MAX(CASE WHEN post_op = 1 AND measurement_name =  ''transfuse_platelet_pheresis'' THEN [countd] END) AS post_op_transfuse_platelet_pheresis_tx
	, MAX(CASE WHEN pre_op = 1 AND measurement_name =  ''transfuse_rbc'' THEN [countd] END) AS pre_op_transfuse_rbc_tx
	, MAX(CASE WHEN inter_op = 1 AND measurement_name =  ''transfuse_rbc'' THEN [countd] END) AS inter_op_transfuse_rbc_tx
	, MAX(CASE WHEN post_op = 1 AND measurement_name =  ''transfuse_rbc'' THEN [countd] END) AS post_op_transfuse_rbc_tx
	, MAX(CASE WHEN pre_op = 1 AND measurement_name =  ''transfuse_fresh_frozen_plasma'' THEN [countd] END) AS pre_op_transfuse_fresh_frozen_plasma_tx
	, MAX(CASE WHEN inter_op = 1 AND measurement_name =  ''transfuse_fresh_frozen_plasma'' THEN [countd] END) AS inter_op_transfuse_fresh_frozen_plasma_tx
	, MAX(CASE WHEN post_op = 1 AND measurement_name =  ''transfuse_fresh_frozen_plasma'' THEN [countd] END) AS post_op_transfuse_fresh_frozen_plasma_tx' + 
	@all_measurement_selects +
	@all_diagnosis_selects + '

FROM #surgeries s
LEFT OUTER JOIN #measurements m
	ON s.surgical_case_key = m.surgical_case_key
LEFT OUTER JOIN #sepsis sep
	ON sep.ir_id = s.ir_id
LEFT OUTER JOIN #most_recent_diagnoses mrd
	ON mrd.surgical_case_key = s.surgical_case_key
LEFT OUTER JOIN #diagnosis_common_name dcn
	ON dcn.diagnosis_key = mrd.diagnosis_key

WHERE s.the_counter >= '+CAST(@i*@per_group AS VARCHAR(10))+'
AND s.the_counter < '+CAST((@i+1)*@per_group AS VARCHAR(10))+'

GROUP BY

	s.surgical_case_key
	, s.west_mrn
	, s.ir_id
	, s.surgery_start_date_key 
	--, sep.start_datetime
	--, CASE WHEN sep.start_datetime < s.surgery_start_datetime OR sep.start_datetime > DATEADD(day,30,s.surgery_end_datetime) THEN 1 ELSE 0 END
	, s.athena_mrn
	, s.idx_mrn
	, s.lfh_mrn
	, s.nmff_mrn
	, s.nmh_mrn
	, s.west_mrn
	, s.surgery_start_datetime
	, s.surgery_end_datetime
	, DATEDIFF(year,s.birth_date,s.surgery_start_datetime)
	, race_1
	, gender
	, DATEDIFF(MINUTE,s.surgery_start_date_key,s.surgery_end_date_key)
	, s.procedure_name
	, s.death_date
ORDER BY s.surgical_case_key';

PRINT 'Running query ' + CAST(@i AS VARCHAR(5)) + ' of ' + CAST(@max_i AS VARCHAR(5));

EXECUTE sp_executesql @query_loop;

SET @i = @i + 1

END;
