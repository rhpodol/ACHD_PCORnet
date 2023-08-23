/***********************************************************************************************************************/
/***********************************************************************************************************************/
/***                                                                                                                 ***/
/***     CHI-RON: Utilizing PCORnet to support transition from pediatric to adult centered care and reduce gaps in   ***/
/***              recommended care in patients with congenital heart disease.                                        ***/
/***        This file contains all the code needed to create analytical files that can be used for                   ***/
/***             subsequent analyses. Two analytical SAS datasets are generated:                                     ***/
/***                  one at the subject level (ACHD_subj_analytic) and                                              ***/
/***                  one at the encounter level (ACHD_encounter_analytic).                                          ***/
/***        Version 0.1                                                                                              ***/
/***        Last update: 08/18/2023                                                                                  ***/
/***        Last person updating: R. Podolsky                                                                        ***/
/***        Changes:                                                                                                 ***/
/***                                                                                                                 ***/
/***********************************************************************************************************************/
/***********************************************************************************************************************/

/* Set up */
/* Change the following macro variables to point to the location of the CDM data resulting from Query 1 (datdir), */
/* to the location of auxililary files (e.g., code lists and formats; datdictdir), and the directory where the    */
/* resulting files will be saved (outdatdir). */
%let datdir=L:\Translational-Bost-Lab\CTSICN Biostat Group\John A\PCORNet Rare Diseases\DataSets\Query1_full;
%let datdictdir=L:\Translational-Bost-Lab\CTSICN Biostat Group\John A\PCORNet Rare Diseases\DataDictionariesCodebook\CodelistsFormat;
%let outdatdir=L:\Translational-Bost-Lab\CTSICN Biostat Group\John A\PCORNet Rare Diseases\DataSets\Query1_full\ModifiedTables4Analysis;


/***********************************************************************************************************************/
/***********************************************************************************************************************/
/***********************************************************************************************************************/
/***********************************************************************************************************************/
/***                                                                                                                 ***/
/***                                DO NOT MODIFY BEYOND HERE                                                        ***/
/***                                                                                                                 ***/
/***********************************************************************************************************************/
/***********************************************************************************************************************/
/***********************************************************************************************************************/
/***********************************************************************************************************************/

libname dict_dir "&datdictdir";
libname q1_cddir "&datdir";
libname outdir "&outdatdir";

%include "&datdictdir\std_formats.sas";

/* Import Keith's ID crosswalk file */
data q1_pat_map;
  infile "&datdir\ACHD_Patient_Mapping.csv" delimiter = ','  firstobs=2;
  informat UNIQUE_PATID best32. ;
  informat PATID $35.;
  informat DMID $7. ;
  format UNIQUE_PATID best12. ;
  format PATID $32. ;
  format DMID $7. ;
  input UNIQUE_PATID PATID $ DMID  $;
  DATAMARTID=DMID;
  if DATAMARTID="ucsf" then DATAMARTID="C3UCSF";
Run;

/* Merge Q1 Tables with Keith's crosswalk file */
data finder;
 set q1_cddir.finder;
Run;

data recruitment_list;
 set q1_cddir.recruitment_list;
Run;

proc sort data=finder;
 by DATAMARTID PATID;
Run;

Proc Sort data=q1_pat_map;
 by DATAMARTID PATID;
Run;

data finder;
 merge finder q1_pat_map(drop=DMID);
 by DATAMARTID PATID;
Run;

/* Code Encounters for primary diagnosis */
filename chdfile "&datdictdir\chd_hierarchy.cpt";

proc cimport infile=chdfile library=work; run;

data chd_hierarchy(keep=code modifier codecat codetype icd_codes description primary_chd_diagnosis chd_complexity complexity_rank dx_rank);
  set chd_hierarchy(rename=(complexity=chd_complexity));
  if chd_complexity ^= ' ';
  length codecat codetype $2;
  code= strip(compress(code,'.,'));
  modifier=strip(compress(modifier,'.,'));
  type=left(type);
  codecat=substr(type,1,2);
  codetype=substr(type,3,2);
  primary_chd_diagnosis=strip(upcase(primary_chd_diagnosis)); 
  chd_complexity=strip(upcase(chd_complexity));
run;

data card_codes1;
 set CHD_HIERARCHY;
 format CARD_DX_PX $18.;
 array ya {2} CODE MODIFIER;
 array clab {2} $ _TEMPORARY_ ("CODE" "MODIFIER");
 do yi=1 to 2;
    code_mod=clab{yi};
    CARD_DX_PX=ya{yi};
    CARD_CODE_YN=1;
	if codetype^="" & CARD_DX_PX^="" then output;
 end;
 keep code_mod codecat codetype CARD_DX_PX CARD_CODE_YN;
Run;

proc sort data=card_codes1 nodupkey;
 by codecat codetype CARD_DX_PX;
Run;

data chd_codelist;
 set chd_hierarchy;
 format CONCEPT_ID $23. CONCEPT_LABEL $46. CONCEPT_SUBGRP $22. CONCEPT_DESCRIPTION $159. DX $11. DX_TYPE $2. COMORBID_INDEX $15. DX_MODIFIER $7.;
 IF codecat="DX";
 CONCEPT_ID="DX_CHD";
 CONCEPT_LABEL="CHD";
 CONCEPT_SUBGRP=PRIMARY_CHD_DIAGNOSIS;
 CONCEPT_DESCRIPTION=DESCRIPTION;
 DX=CODE;
 DX_MODIFIER=MODIFIER;
 DX_TYPE=codetype;
 COMORBID_INDEX="Not Comorbidity";
 KEEP CONCEPT_ID CONCEPT_LABEL CONCEPT_SUBGRP CONCEPT_DESCRIPTION DX DX_TYPE DX_MODIFIER COMORBID_INDEX;
Run;

proc import datafile="&datdictdir\ACHD_CODELIST_MASTER.xlsx" out=codelist dbms=xlsx replace;
 sheet="COMORBIDITY";
Run;


/**  Creating ENC_TYPE2 so that ED visits are characterized as ED with no adjacent inpatient visit (IP) and ED with adjacent IP visit  **/
proc sql;
 create table ed_encounter as 
 select *,
        (discharge_date+2) as discharge_date_p2 label="discharge_date_p2"
 from q1_cddir.encounter
 where enc_type="ED";
Quit;

proc sql;
 create table ed_ip_adj_encounter as
 select A.*
 FROM ed_encounter A RIGHT JOIN q1_cddir.encounter B
 ON A.DATAMARTID=B.DATAMARTID & A.PATID=B.PATID 
 where B.ENC_TYPE="IP" and B.ADMIT_DATE between A.ADMIT_DATE and A.discharge_date_p2;
quit;

proc freq data=ed_encounter;
 table datamartid*discharge_disposition/missprint;
 table datamartid*discharge_status/missprint;
Run;

proc freq data=q1_cddir.encounter;
 table datamartid*enc_type;
Run;

/** Evaluating extent of coding for procedures and labs of interest **/

/* Importing and creating dataset that has codes of interest */
proc import datafile="&data_dict_dir\achd_codelist_master_071723.xlsx" out=achd_codelist0 dbms=xlsx replace;
 sheet="OTHER_code_metadata";
Run;

data achd_proc_codes;
 set achd_codelist0;
 if substr(CODETYPE,1,2)="PX";
 PX_TYPE=substr(CODETYPE,3);
 PX_CONCEPT_GROUP=CONCEPT_ID;
 PX_CONCEPT=CONCEPT_ID;
 IF CONCEPT_ID="PX_CT" then PX_CONCEPT="PX_CT_CARDIAC";
 IF CONCEPT_ID="PX_DEFIBRILLATOR" then PX_CONCEPT_GROUP="PX_HEART_STIM";
 IF CONCEPT_ID="PX_ECHO" then PX_CONCEPT="PX_ECHO_CARDIAC";
 IF CONCEPT_ID="PX_INTERVENTION" then PX_CONCEPT_GROUP="PX_CATH";
 IF CONCEPT_ID="PX_MRI" then PX_CONCEPT="PX_MRI_CARDIAC";
 IF CONCEPT_ID="PX_PACEMAKER" then PX_CONCEPT_GROUP="PX_HEART_STIM";
 IF CONCEPT_ID="PX_ULTRA" then PX_CONCEPT_GROUP="PX_ECHO";
Run;

proc sql;
 create table proc_select as
 select A.*,
        A.admit_date as ADMIT_MonthYr format=MMYYS. label="ADMIT_MonthYr",
        B.CONCEPT_ID,
		B.PX_CONCEPT,
		B.PX_CONCEPT_GROUP,
		B.CONCEPT_LBL,
		B.CODE_DESC
 from q1_cddir.procedures A LEFT JOIN achd_proc_codes B
 on A.PX_TYPE=B.PX_TYPE and A.PX=B.CODE;
Quit;

data proc_select;
 set proc_select;
 if PX_CONCEPT="" then PX_CONCEPT="Other";
 if PX_CONCEPT_GROUP="" then PX_CONCEPT_GROUP="Other";
Run;

/* Importing and creating dataset that has LOINC information for OBS_CLIN and LAB_RESULT_CM */
data WORK.ACHD_LOINCLIST0;
  infile 'L:\Translational-Bost-Lab\CTSICN Biostat Group\John A\PCORNet Rare Diseases\DataDictionariesCodebook\ACHD_LoincTableCore_051823_rp.csv' 
  delimiter = ',' MISSOVER DSD lrecl=32767 firstobs=2;
  informat LOINC_NUM $10.;
  informat COMPONENT $80.;
  informat PROPERTY $4.;
  informat TIME_ASPCT $2.;
  informat SYSTEM $8.;
  informat SCALE_TYP $6.;
  informat METHOD_TYP $57.;
  informat CLASS $24.;
  informat CLASSTYPE 2.;
  informat LONG_COMMON_NAME $254.;
  informat SHORTNAME $51.;
  informat EXTERNAL_COPYRIGHT_NOTICE $50.;
  informat STATUS $11.;
  informat VersionFirstReleased $6.;
  informat VersionLastChanged $6.;
  informat CONCEPT_TYPE $6.;
  informat CONCEPT $20.;
  informat CONCEPT_LBL $25.;
  informat AST 2.0;
  informat ALT 2.0 ;
  informat Iron 2.0 ;
  informat CBC 2.0 ;
  informat CATH 2.0 ;
  informat cardiac 2.0 ;
  informat CARDIAC_CATH 2.0 ;
  informat blood_pressure 2.0 ;
  informat percutaneous 2.0 ;
  informat blood_pressure__percutaneous 2.0 ;
  informat cardiovascular_stress_test 2.0 ;
  informat pacemaker 2.0 ;
  informat pulse_oximetry 2.0 ;
  format LOINC_NUM $7.;
  format COMPONENT $80.;
  format PROPERTY $4.;
  format TIME_ASPCT $2.;
  format SYSTEM $8.;
  format SCALE_TYP $6.;
  format METHOD_TYP $57.;
  format CLASS $24.;
  format CLASSTYPE 2.;
  format LONG_COMMON_NAME $254.;
  format SHORTNAME $51.;
  format EXTERNAL_COPYRIGHT_NOTICE $50.;
  format STATUS $11.;
  format VersionFirstReleased $6.;
  format VersionLastChanged $6.;
  format CONCEPT_TYPE $6.;
  format CONCEPT $20.;
  format CONCEPT_LBL $25.;
  format AST 2.0;
  format ALT 2.0 ;
  format Iron 2.0 ;
  format CBC 2.0 ;
  format CATH 2.0 ;
  format cardiac 2.0 ;
  format CARDIAC_CATH 2.0 ;
  format blood_pressure 2.0 ;
  format percutaneous 2.0 ;
  format blood_pressure__percutaneous 2.0 ;
  format cardiovascular_stress_test 2.0 ;
  format pacemaker 2.0 ;
  format pulse_oximetry 2.0 ;
  input LOINC_NUM  $ COMPONENT  $ PROPERTY  $ TIME_ASPCT  $ SYSTEM  $ SCALE_TYP  $ METHOD_TYP  $ CLASS  $ CLASSTYPE LONG_COMMON_NAME  $
        SHORTNAME  $ EXTERNAL_COPYRIGHT_NOTICE  $ STATUS  $ VersionFirstReleased  $ VersionLastChanged CONCEPT_TYPE  $ CONCEPT  $ CONCEPT_LBL $
        AST ALT Iron CBC CATH cardiac CARDIAC_CATH blood_pressure percutaneous blood_pressure__percutaneous cardiovascular_stress_test
        pacemaker pulse_oximetry;
run;

data achd_loinclist0;
 set achd_loinclist0;
 if CONCEPT_TYPE ^= "";
Run;

proc sql;
 create table obs_clin_lc as
 select A.*,
        A.OBSCLIN_START_DATE  as OBSCLIN_DATE_MonthYr format=MMYYS. label="ADMIT_MonthYr",
		B.LOINC_NUM,
		B.SHORTNAME,
		B.CONCEPT_TYPE,
		B.CONCEPT
 from q1_cddir.OBS_CLIN A LEFT JOIN achd_loinclist0 B
 on A.OBSCLIN_CODE=B.LOINC_NUM
 where A.OBSCLIN_TYPE="LC";
Quit;

data obs_clin_lc;
 set obs_clin_lc;
 if CONCEPT="" then CONCEPT="OTHER";
Run;

proc sql;
 create table lab_result_lc as
 select A.*,
        A.LAB_ORDER_DATE  as LAB_ORDER_DATE_MonthYr format=MMYYS. label="ADMIT_MonthYr",
		B.LOINC_NUM,
		B.SHORTNAME,
		B.CONCEPT_TYPE,
		B.CONCEPT
 from q1_cddir.LAB_RESULT_CM A LEFT JOIN achd_loinclist0 B
 on A.LAB_LOINC=B.LOINC_NUM;
Quit;

data lab_result_lc;
 set lab_result_lc;
 if CONCEPT="" then CONCEPT="OTHER";
Run;


ods results off;
ods output OneWayFreqs=px_freq;
proc freq data=proc_select;
 by datamartid PX_CONCEPT;
 table PX;
Run;
ods results on;

proc sort data=proc_select;
 by datamartid PX_CONCEPT ADMIT_MonthYr;
Run;

proc sort data=obs_clin_lc;
 by datamartid CONCEPT OBSCLIN_DATE_MonthYr;
Run;

proc sort data=lab_result_lc;
 by datamartid CONCEPT LAB_ORDER_DATE_MonthYr;
Run;

ods results off;
ods output OneWayFreqs=px_concept_freq;
proc freq data=proc_select;
 by datamartid;
 table PX_CONCEPT;
Run;
ods results on;

proc sort data=px_concept_freq;
 by px_concept;
Run;

proc transpose data=px_concept_freq out=px_concept_freq_freq_t;
 by px_concept;
 var Frequency;
 ID DATAMARTID;
Run;

proc transpose data=px_concept_freq out=px_concept_freq_pct_t;
 by px_concept;
 var Percent;
 ID DATAMARTID;
Run;
 
ods results off;
ods output OneWayFreqs=px_concept_grp_freq;
proc freq data=proc_select;
 by datamartid;
 table PX_CONCEPT_GROUP;
Run;
ods results on;

data px_concept_grp_freq;
 set px_concept_grp_freq;
 if PX_CONCEPT_GROUP="PX_CATH"|PX_CONCEPT_GROUP="PX_HEART_STIM";
Run;

proc sort data=px_concept_grp_freq;
 by px_concept_group;
Run;

proc transpose data=px_concept_grp_freq out=px_concept_grp_freq_freq_t;
 by px_concept_group;
 var Frequency;
 ID DATAMARTID;
Run;

proc transpose data=px_concept_grp_freq out=px_concept_grp_freq_pct_t;
 by px_concept_group;
 var Percent;
 ID DATAMARTID;
Run;


proc sort data=obs_clin_lc;
 by datamartid;
Run;

ods results off;
ods output OneWayFreqs=obs_clin_px_freq;
proc freq data=obs_clin_lc;
 by datamartid;
 table CONCEPT;
Run;
ods results on;

data obs_clin_px_freq;
 set obs_clin_px_freq;
 if CONCEPT="PX_PULSE_OX";
Run;

proc sort data=obs_clin_px_freq;
 by concept;
Run;

proc transpose data=obs_clin_px_freq out=obs_clin_px_freq_freq_t;
 by concept;
 var Frequency;
 ID DATAMARTID;
Run;

proc transpose data=obs_clin_px_freq out=obs_clin_px_freq_pct_t;
 by concept;
 var Percent;
 ID DATAMARTID;
Run;


proc sort data=lab_result_lc;
 by datamartid;
Run;

ods results off;
ods output OneWayFreqs=lab_result_lab_freq;
proc freq data=lab_result_lc;
 by datamartid;
 table CONCEPT;
Run;
ods results on;

proc sort data=lab_result_lab_freq;
 by concept;
Run;

proc transpose data=lab_result_lab_freq out=lab_result_lab_freq_freq_t;
 by concept;
 var Frequency;
 ID DATAMARTID;
Run;

proc transpose data=lab_result_lab_freq out=lab_result_lab_freq_pct_t;
 by concept;
 var Percent;
 ID DATAMARTID;
Run;

data px_concept_freq_freq_t;
 set px_concept_freq_freq_t;
 CONCEPT=PX_CONCEPT;
 STAT="FREQ";
 drop PX_CONCEPT _NAME_;
Run;

data px_concept_freq_pct_t;
 set px_concept_freq_pct_t;
 CONCEPT=PX_CONCEPT;
 STAT="PCT";
 drop PX_CONCEPT _NAME_;
Run;

data px_concept_grp_freq_freq_t;
 set px_concept_grp_freq_freq_t;
 CONCEPT=PX_CONCEPT_GROUP;
 STAT="FREQ";
 drop PX_CONCEPT_GROUP _NAME_;
Run;

data px_concept_grp_freq_pct_t;
 set px_concept_grp_freq_pct_t;
 CONCEPT=PX_CONCEPT_GROUP;
 STAT="PCT";
 drop PX_CONCEPT_GROUP _NAME_;
Run;

data obs_clin_px_freq_freq_t;
 set obs_clin_px_freq_freq_t;
 STAT="FREQ";
 drop _NAME_;
Run;

data obs_clin_px_freq_pct_t;
 set obs_clin_px_freq_pct_t;
 STAT="PCT";
 drop _NAME_;
Run;

data lab_result_lab_freq_freq_t;
 set lab_result_lab_freq_freq_t;
 STAT="FREQ";
 drop _NAME_;
Run;

data lab_result_lab_freq_pct_t;
 set lab_result_lab_freq_pct_t;
 STAT="PCT";
 drop _NAME_;
Run;

data px_lab_freq;
 set px_concept_freq_freq_t px_concept_freq_pct_t px_concept_grp_freq_freq_t px_concept_grp_freq_pct_t
     obs_clin_px_freq_freq_t obs_clin_px_freq_pct_t lab_result_lab_freq_freq_t lab_result_lab_freq_pct_t;
Run;


proc sort data=proc_select out=px_patids nodupkey;
 by datamartid patid;
Run; 

ods results off;
ods output OneWayFreqs=px_patid_freq;
proc freq data=px_patids;
 table datamartid;
Run;
ods results on;

proc sort data=proc_select out=proc_select_dedup nodupkey;
 by datamartid patid PX_CONCEPT;
Run;

ods results off;
ods output OneWayFreqs=px_concept_dd_freq;
proc freq data=proc_select_dedup;
 by datamartid;
 table PX_CONCEPT;
Run;
ods results on;

proc sql;
 create table px_concept_dd_freq2 as
 select A.*,
        B.Frequency as N_patids
 from px_concept_dd_freq A LEFT JOIN px_patid_freq B
 on A.DATAMARTID=B.DATAMARTID;
Quit;
        
data px_concept_dd_freq2;
 set px_concept_dd_freq2;
 Percent=Frequency/N_patids;
Run;

proc sort data=px_concept_dd_freq2;
 by px_concept;
Run;

proc transpose data=px_concept_dd_freq2 out=px_concept_dd_freq_freq_t;
 by px_concept;
 var Frequency;
 ID DATAMARTID;
Run;

proc transpose data=px_concept_dd_freq2 out=px_concept_dd_freq_pct_t;
 by px_concept;
 var Percent;
 ID DATAMARTID;
Run;

 
ods results off;
ods output OneWayFreqs=px_concept_grp_dd_freq;
proc freq data=proc_select_dedup;
 by datamartid;
 table PX_CONCEPT_GROUP;
Run;
ods results on;

proc sql;
 create table px_concept_grp_dd_freq2 as
 select A.*,
        B.Frequency as N_patids
 from px_concept_grp_dd_freq A LEFT JOIN px_patid_freq B
 on A.DATAMARTID=B.DATAMARTID
 where A.PX_CONCEPT_GROUP="PX_CATH"|A.PX_CONCEPT_GROUP="PX_HEART_STIM";
Quit;

data px_concept_grp_dd_freq2;
 set px_concept_grp_dd_freq2;
 Percent=Frequency/N_patids;
Run;

proc sort data=px_concept_grp_dd_freq2;
 by px_concept_group;
Run;

proc transpose data=px_concept_grp_dd_freq2 out=px_concept_grp_dd_freq_freq_t;
 by px_concept_group;
 var Frequency;
 ID DATAMARTID;
Run;

proc transpose data=px_concept_grp_dd_freq2 out=px_concept_grp_dd_freq_pct_t;
 by px_concept_group;
 var Percent;
 ID DATAMARTID;
Run;


proc sort data=obs_clin_lc out=obs_clin_patids nodupkey;
 by datamartid patid;
Run; 

ods results off;
ods output OneWayFreqs=obs_clin_patid_freq;
proc freq data=obs_clin_patids;
 table datamartid;
Run;
ods results on;

proc sort data=obs_clin_lc out=obs_clin_lc_dedup nodupkey;
 by datamartid patid CONCEPT;
Run;

ods results off;
ods output OneWayFreqs=obs_clin_dd_px_freq;
proc freq data=obs_clin_lc_dedup;
 by datamartid;
 table CONCEPT;
Run;
ods results on;

proc sql;
 create table obs_clin_dd_px_freq2 as
 select A.*,
        B.Frequency as N_patids
 from obs_clin_dd_px_freq A LEFT JOIN obs_clin_patid_freq B
 on A.DATAMARTID=B.DATAMARTID
 where CONCEPT="PX_PULSE_OX";
Quit;

data obs_clin_dd_px_freq2;
 set obs_clin_dd_px_freq2;
 Percent=Frequency/N_patids;
Run;

proc sort data=obs_clin_dd_px_freq2;
 by concept;
Run;

proc transpose data=obs_clin_dd_px_freq2 out=obs_clin_dd_px_freq_freq_t;
 by concept;
 var Frequency;
 ID DATAMARTID;
Run;

proc transpose data=obs_clin_dd_px_freq2 out=obs_clin_dd_px_freq_pct_t;
 by concept;
 var Percent;
 ID DATAMARTID;
Run;


proc sort data=lab_result_lc out=lab_result_patids nodupkey;
 by datamartid patid;
Run; 

ods results off;
ods output OneWayFreqs=lab_result_patid_freq;
proc freq data=lab_result_patids;
 table datamartid;
Run;
ods results on;

proc sort data=lab_result_lc out=lab_result_lc_dedup nodupkey;
 by datamartid patid concept;
Run;

ods results off;
ods output OneWayFreqs=lab_result_dd_lab_freq;
proc freq data=lab_result_lc_dedup;
 by datamartid;
 table CONCEPT;
Run;
ods results on;

proc sql;
 create table lab_result_dd_lab_freq2 as
 select A.*,
        B.Frequency as N_patids
 from lab_result_dd_lab_freq A LEFT JOIN lab_result_patid_freq B 
 on A.DATAMARTID=B.DATAMARTID;
Quit;

data lab_result_dd_lab_freq2;
 set lab_result_dd_lab_freq2;
 Percent=Frequency/N_patids;
Run;

proc sort data=lab_result_dd_lab_freq2;
 by concept;
Run;

proc transpose data=lab_result_dd_lab_freq2 out=lab_result_dd_lab_freq_freq_t;
 by concept;
 var Frequency;
 ID DATAMARTID;
Run;

proc transpose data=lab_result_dd_lab_freq2 out=lab_result_dd_lab_freq_pct_t;
 by concept;
 var Percent;
 ID DATAMARTID;
Run;

data px_concept_dd_freq_freq_t;
 set px_concept_dd_freq_freq_t;
 CONCEPT=PX_CONCEPT;
 STAT="FREQ";
 drop PX_CONCEPT _NAME_;
Run;

data px_concept_dd_freq_pct_t;
 set px_concept_dd_freq_pct_t;
 CONCEPT=PX_CONCEPT;
 STAT="PCT";
 drop PX_CONCEPT _NAME_;
Run;

data px_concept_grp_dd_freq_freq_t;
 set px_concept_grp_dd_freq_freq_t;
 CONCEPT=PX_CONCEPT_GROUP;
 STAT="FREQ";
 drop PX_CONCEPT_GROUP _NAME_;
Run;

data px_concept_grp_dd_freq_pct_t;
 set px_concept_grp_dd_freq_pct_t;
 CONCEPT=PX_CONCEPT_GROUP;
 STAT="PCT";
 drop PX_CONCEPT_GROUP _NAME_;
Run;

data obs_clin_dd_px_freq_freq_t;
 set obs_clin_dd_px_freq_freq_t;
 STAT="FREQ";
 drop _NAME_;
Run;

data obs_clin_dd_px_freq_pct_t;
 set obs_clin_dd_px_freq_pct_t;
 STAT="PCT";
 drop _NAME_;
Run;

data lab_result_dd_lab_freq_freq_t;
 set lab_result_dd_lab_freq_freq_t;
 STAT="FREQ";
 drop _NAME_;
Run;

data lab_result_dd_lab_freq_pct_t;
 set lab_result_dd_lab_freq_pct_t;
 STAT="PCT";
 drop _NAME_;
Run;

data px_lab_dd_freq;
 set px_concept_dd_freq_freq_t px_concept_dd_freq_pct_t px_concept_grp_dd_freq_freq_t px_concept_grp_dd_freq_pct_t
     obs_clin_dd_px_freq_freq_t obs_clin_dd_px_freq_pct_t lab_result_dd_lab_freq_freq_t lab_result_dd_lab_freq_pct_t;
Run;

/** Evaluating Percent Missing for Vitals for each Encounter **/

data tvital;
 set q1_cddir.vital;
 array a1 {5} ht wt diastolic systolic original_bmi;
 array a2 {5} ht_miss wt_miss diastolic_miss systolic_miss original_bmi_miss;
 do i=1 to 5;
    if a1{i}=. then a2{i}=0;
	if a1{i}^=. then a2{i}=1;
 end;
Run;

proc sort data=tvital;
 by datamartid encounterid;
Run;

proc means noprint data=tvital;
 by datamartid encounterid;
 var ht_miss wt_miss diastolic_miss systolic_miss original_bmi_miss;
 output out=tvital2 max=ht_miss wt_miss diastolic_miss systolic_miss original_bmi_miss;
Run;

proc freq data=tvital2;
 table datamartid*ht_miss;
 table datamartid*wt_miss;
 table datamartid*diastolic_miss;
 table datamartid*systolic_miss;
 table datamartid*original_bmi_miss;
Run;

/** Creating primary diagnosis for each subject **/
data diagnosis;
 set q1_cddir.diagnosis;
 DX_comp=compress(DX,".");
Run;

proc sql;
 create table prim_diagnosis as 
 select A.*,
        month(A.admit_date) as ADMIT_MONTH,
		year(A.admit_date) as ADMIT_YEAR,
		A.admit_date as ADMIT_MonthYr format=MMYYS.,
		B.CONCEPT_ID,
		B.CONCEPT_SUBGRP
 FROM diagnosis A LEFT JOIN codelist B on
      A.DX_TYPE=B.DX_TYPE AND A.DX_comp=B.DX
 WHERE PDX="P" & CONCEPT_ID ^= "";
Quit;

