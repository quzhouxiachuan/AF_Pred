
USE NM_BI;

SET NOCOUNT ON;

IF OBJECT_ID('tempdb..#search_terms') IS NOT NULL BEGIN DROP TABLE #search_terms END;
IF OBJECT_ID('tempdb..#diagnosis_common_name') IS NOT NULL BEGIN DROP TABLE #diagnosis_common_name END; 

CREATE TABLE #search_terms (the_counter INT IDENTITY(0,1), common_name VARCHAR(100),search_terms VARCHAR(MAX));

INSERT #search_terms (common_name,search_terms)
SELECT 'betablocker','(dti.medication_name LIKE ''%acebutolol%'' OR dti.medication_name LIKE ''%Sectral%''

OR dti.medication_name like ''%acebutolol%''
OR dti.medication_name like ''%Sectral%''

OR dti.medication_name like ''%atenolol%''
OR dti.medication_name like ''%Tenormin%''

OR dti.medication_name like ''%betaxolol%''
OR dti.medication_name like ''%Kerlone%''

OR  dti.medication_name like ''%betaxolol%''
OR dti.medication_name like ''%Betoptic%S%''

OR dti.medication_name  like ''%bisoprolol%fumarate%''
OR dti.medication_name  like ''%Zebeta%''

OR dti.medication_name  like ''%carteolol%''
OR dti.medication_name  like ''%Cartrol%''--OR --discontinued 

OR dti.medication_name  like ''%carvedilol%''
OR dti.medication_name  like ''%Coreg%''

OR dti.medication_name  like ''%esmolol%''
OR dti.medication_name  like ''%Brevibloc%''

OR dti.medication_name  like ''%labetalol%''
OR dti.medication_name  like ''%Trandate%''--[Normodyne - discontinued]
OR dti.medication_name  like ''%metoprolol%''
OR dti.medication_name  like ''%Lopressor%''
OR dti.medication_name   like ''%Toprol%XL%''

OR dti.medication_name  like ''%nadolol%''
OR dti.medication_name  like ''%Corgard%''

OR dti.medication_name  like ''%nebivolol%''
OR dti.medication_name  like ''%Bystolic%''

OR dti.medication_name  like ''%penbutolol%''
OR dti.medication_name  like ''%Levatol%''
OR dti.medication_name  like ''%pindolol%''
OR dti.medication_name  like ''%Visken%''--discontinued

OR dti.medication_name  like ''%propranolol%''
OR dti.medication_name  like ''%Hemangeol''
OR  dti.medication_name  like ''%Inderal%LA%''
OR  dti.medication_name  like ''%Inderal%XL%''
OR  dti.medication_name  like ''%InnoPran%XL%''

OR dti.medication_name  like ''%sotalol%''
OR dti.medication_name  like ''%Betapace%''
OR dti.medication_name  like  ''%Sorine%''

OR dti.medication_name  like ''%timolol%''
OR dti.medication_name  like ''%Blocadren%''--OR discontinued) 

OR dti.medication_name  like ''%timolol%ophthalmic%solution%''
OR dti.medication_name  like ''%Timoptic%''
OR  dti.medication_name  like ''%Betimol%''
OR  dti.medication_name  like ''%Istalol%''
)'

UNION SELECT 'angiotensin-converting enzyme inhibitors', '( dti.medication_name  like ''%benazepril%''
OR dti.medication_name  like ''%Lotensin%''
OR dti.medication_name  like ''%captopril%''
OR dti.medication_name  like ''%Capoten%''-- discontinued brand) 
OR dti.medication_name  like ''%enalapril%''
OR dti.medication_name  like ''%Vasotec%''
OR  dti.medication_name  like ''%Epaned%''
OR  dti.medication_name  like ''%Lexxel%''-- discontinued brand]) 
--fosinopril (Monopril- Discontinued brand) 
OR dti.medication_name  like ''%lisinopril%''
OR dti.medication_name  like ''%Prinivil%''
OR  dti.medication_name  like ''%Zestril%''
OR  dti.medication_name  like ''%Qbrelis%''

--moexipril (Univasc- Discontinued brand) 
OR dti.medication_name  like ''%perindopril%''
OR dti.medication_name  like ''%Aceon%''
OR dti.medication_name  like ''%quinapril%''
OR dti.medication_name  like ''%Accupril%''
OR dti.medication_name  like ''%ramipril%''
OR dti.medication_name  like ''%Altace%''
OR dti.medication_name  like ''%trandolapril%''
OR dti.medication_name  like ''%Mavik%''

OR dti.generic_name  like ''%benazepril%''
OR dti.generic_name  like ''%Lotensin%''

OR dti.generic_name  like ''%captopril%''
OR dti.generic_name  like ''%Capoten%''-- discontinued brand) 

OR dti.generic_name  like ''%enalapril%''
OR dti.generic_name  like ''%Vasotec%''
OR  dti.generic_name  like ''%Epaned%''
OR  dti.generic_name  like ''%Lexxel%''-- discontinued brand]) 

--fosinopril (Monopril- Discontinued brand) 

OR dti.generic_name  like ''%lisinopril%''
OR dti.generic_name  like ''%Prinivil%''
OR  dti.generic_name  like ''%Zestril%''
OR  dti.generic_name  like ''%Qbrelis%''

--moexipril (Univasc- Discontinued brand) 

OR dti.generic_name  like ''%perindopril%''
OR dti.generic_name  like ''%Aceon%''

OR dti.generic_name  like ''%quinapril%''
OR dti.generic_name  like ''%Accupril%''

OR dti.generic_name  like ''%ramipril%''
OR dti.generic_name  like ''%Altace%''

OR dti.generic_name  like ''%trandolapril%''
OR dti.generic_name  like ''%Mavik%''


)'

UNION SELECT 'angiotensin II receptor  blockers ', '(



 dti.generic_name  like ''%azilsartan%''
OR dti.generic_name  like ''%Edarbi%''

OR dti.generic_name  like ''%candesartan%''
OR dti.generic_name  like ''%Atacand%''

OR dti.generic_name  like ''%eprosartan%''
OR dti.generic_name  like ''%Teveten%''

OR dti.generic_name  like ''%irbesartan%''
OR dti.generic_name  like ''%Avapro%''

OR dti.generic_name  like ''%telmisartan%''
OR dti.generic_name  like ''%Micardis%''
OR dti.generic_name  like ''%valsartan%''
OR dti.generic_name  like ''%Diovan%''
OR  dti.generic_name  like ''%Prexxartan%''
OR dti.generic_name  like ''%losartan%''
OR dti.generic_name  like ''%Cozaar%''

OR dti.generic_name  like ''%olmesartan%''
OR dti.generic_name  like ''%Benicar%''
OR dti.generic_name  like ''%entresto%''
OR dti.generic_name  like ''%sacubitril%valsartan%''

OR dti.generic_name  like ''%byvalson%''
OR dti.generic_name  like ''%nebivolol%valsartan%''



)'

UNION SELECT 'statin','(dti.medication_name LIKE ''%atorvastatin%''
OR dti.medication_name  like ''%Lipitor%''
OR dti.medication_name  like  ''%fluvastatin%''
OR dti.medication_name  like ''%Lescol%''
OR  dti.medication_name  like ''%Lescol%XL%''
OR  dti.medication_name  like ''%lovastatin%''
OR dti.medication_name  like ''%Mevacor%''
OR dti.medication_name  like  ''%Altoprev%''
OR  dti.medication_name  like ''%pravastatin%''
OR dti.medication_name  like ''%Pravachol%''
OR  dti.medication_name  like ''%rosuvastatin%''
OR dti.medication_name  like ''%Crestor%''
OR dti.medication_name  like  ''%simvastatin%''
OR dti.medication_name  like ''%Zocor%''
OR dti.medication_name  like ''%pitavastatin%''
OR dti.medication_name  like ''%Livalo%''

OR dti.generic_name  like ''%atorvastatin%''
OR dti.generic_name  like ''%Lipitor%''
OR dti.generic_name  like  ''%fluvastatin%''
OR dti.generic_name  like ''%Lescol%''
OR  dti.generic_name  like ''%Lescol%XL%''
OR  dti.generic_name  like ''%lovastatin%''
OR dti.generic_name  like ''%Mevacor%''
OR dti.generic_name  like  ''%Altoprev%''
OR  dti.generic_name  like ''%pravastatin%''
OR dti.generic_name  like ''%Pravachol%''
OR  dti.generic_name  like ''%rosuvastatin%''
OR dti.generic_name  like ''%Crestor%''
OR dti.generic_name  like  ''%simvastatin%''
OR dti.generic_name  like ''%Zocor%''
OR dti.generic_name  like ''%pitavastatin%''
OR dti.generic_name  like ''%Livalo%''
)'


UNION SELECT 'Aspirin', '(
dti.generic_name  like ''%AcetylSalicylic%Acid%''
OR dti.generic_name  like ''%Aspirin%''
OR dti.generic_name  like  ''%Ascriptin%''
OR dti.generic_name  like  ''%Aspergum%''
OR  dti.generic_name  like ''%Aspirtab%''
OR  dti.generic_name  like ''%Bayer%''
OR  dti.generic_name  like ''%Easprin%''
OR dti.generic_name  like  ''%Ecotrin%''
OR dti.generic_name  like ''%Ecpirin%''
OR dti.generic_name  like  ''%Entercote%''
OR  dti.generic_name  like ''%Genacote%''
OR  dti.generic_name  like ''%Halfprin%''
OR dti.generic_name  like  ''%Ninoprin%''
OR  dti.generic_name  like ''%Norwich%Aspirin%''
OR dti.generic_name  like ''%Ascriptin%''-- Maximum Strength  
--Ascriptin Regular Strength  

OR dti.generic_name  like ''%Aspercin%''
OR dti.generic_name  like ''%Aspir%low%''
OR dti.generic_name  like ''%Aspirin%Adult%Low%Strength%''
OR dti.generic_name  like ''%Aspirin%EC%Low%Strength%''
OR dti.generic_name  like ''%Aspirtab%''
OR dti.generic_name  like ''%Bayer%Aspirin%Extra%Strength%''
OR dti.generic_name  like ''%Bayer%Aspirin%Regimen%Adult%Low%Strength%''
--Bayer Aspirin Regimen Children  
OR dti.generic_name  like ''%Bayer%Aspirin%Regimen%Regular%Strength%''
OR dti.generic_name  like ''%Bayer%Genuine%Aspirin%''
OR dti.generic_name  like ''%Bayer%Plus%Extra%Strength%''
OR dti.generic_name  like ''%Bayer%Women%Low%Dose%Aspirin%''
OR dti.generic_name  like ''%Buffasal%''
OR dti.generic_name  like ''%Bufferin%Extra%Strength%''
OR dti.generic_name  like ''%Bufferin%''
OR dti.generic_name  like ''%Buffinol%''

OR dti.generic_name  like ''%Durlaza%''

OR dti.generic_name  like ''%Ecotrin%Arthritis%Strength%''

OR dti.generic_name  like ''%Ecotrin%Low%Strength%''

OR dti.generic_name  like ''%Ecotrin%''

OR dti.generic_name  like ''%Halfprin%''

OR dti.generic_name  like ''%St%Joseph%Adult%Aspirin%''
OR dti.generic_name  like ''%Tri-Buffered%Aspirin%'')'

UNION SELECT 'cyclooxygenase-2 inhibitors', '(
 dti.medication_name  like ''%Celecoxib%''
OR dti.medication_name  like ''%Celebrex%''

OR dti.medication_name  like ''%Rofecoxib%''
OR dti.medication_name  like ''%Vioxx%''-- (withdrawn from the market) 

OR dti.medication_name  like ''%valdecoxib%''
OR dti.medication_name  like ''%Bextra%''-- (withdrawn from the market)
)'

--UNION SELECT 'Alcohol use','(diagnosis_code_base = ''F10'')'
--UNION SELECT 'Chronic obstructive pulmonary disease (COPD)','(diagnosis_code_base IN (''J40'',''J41'',''J42'',''J43'',''J44'',''J47''))'
--UNION SELECT 'Ascites','(diagnosis_code_base = ''R18'')'
--UNION SELECT 'Cirrhosis','(diagnosis_code_base IN (''K70'',''K71'',''K74''))'
--UNION SELECT 'Congestive heart failure','(diagnosis_name LIKE ''%congestive heart%'')'
--UNION SELECT 'Coronary artery disease','(diagnosis_code_base IN (''I20'',''I21'',''I22'',''I23'',''I24'',''I25''))'
--UNION SELECT 'Hypertension','(diagnosis_code_base IN (''I10'',''I11'',''I12'',''I13'',''I15''))'
--UNION SELECT 'Peripheral vascular disease','(diagnosis_code = ''I73.9'')'
--UNION SELECT 'Renal failure','(diagnosis_code_base IN (''N17'',''N18'',''N19''))'
--UNION SELECT 'Stroke','(diagnosis_code_base IN (''I61'',''I62'',''I63'',''I64''))'



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
			, dti.medication_key
			,dti.medication_name
			,dti.generic_name 
			,de.order_placed_datetime 
			, de.order_end_date_key
			, p.patient_key
		

		FROM [NM_BI].[dim].vw_medication dti
		INNER JOIN [NM_BI].[fact].vw_medication_order de
			ON dti.medication_key = de.medication_key
		JOIN [NM_BI].dim.vw_medication_order_profile mop 
			ON mop.medication_order_profile_key=de.medication_order_profile_key 
		JOIN [NM_BI].dim.vw_patient_current p 
			ON p.patient_key= de.patient_key  
		WHERE ' + @the_search_terms + '
		
		AND de.medication_key>0 
		AND mop.order_status IN (''Completed'',''Verified'',''Sent'')
		UNION ALL '

	SET @full_diagnosis_search = @full_diagnosis_search + @diagnosis_search;
	SET @i = @i + 1;

END;

SET @full_diagnosis_search = LEFT(@full_diagnosis_search,LEN(@full_diagnosis_search)-10);

IF OBJECT_ID('tempdb..#diagnosis_common_name') IS NOT NULL BEGIN DROP TABLE #diagnosis_common_name END;
CREATE TABLE #diagnosis_common_name ( common_name VARCHAR(max), diagnosis_key VARCHAR(max), medication_name VARCHAR(max) , generic_name VARCHAR(max), order_end_datekey VARCHAR(max), order_placed_dt VARCHAR(max),patient_key VARCHAR(max)
)

INSERT INTO #diagnosis_common_name
EXECUTE sp_executesql @full_diagnosis_search;
 
 
SELECT * FROM #diagnosis_common_name 
 
