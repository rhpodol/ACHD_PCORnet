
/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *                                                                      
* Program Name:  std_formats.sas                          
*         Date:  01/22/2022                                               
* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
* Purpose:  The purpose of the program is to store output templates 
*           and formats of variables.
* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */;

ODS PATH RESET;                              
ODS PATH (PREPEND) SASHELP.TMPLMST(READ) WORK.Templat(UPDATE);  
ODS NOPROCTITLE;

PROC TEMPLATE;  
    DEFINE STYLE std_xlsx;
       parent=styles.excel;
       class body / background= white; END;
RUN;

PROC FORMAT;

	value $sex
       "A" = "Ambiguous"
       "F" = "Female"
       "M" = "Male"
	   "NI", "UN", "OT", " " = "Missing"
        ;

     value $race
       "01" = "American Indian or Alaska Native"
       "02" = "Asian"
       "03" = "Black or African American"
       "04" = "Native Hawaiian or Other Pacific Islander"
       "05" = "White"
       "06" = "Multiple Race"
	   "07", "NI", "UN", "OT", " " = "Missing"
       ;
      
     value $hispanic
        "Y" = 1
        "N"  = 2
        "R", "NI", "UN", "OT"  = 3
        ;
        
      value $rpt_hispanic
        "1" = "Yes"
        "2" = "No"
        "3" = "Missing"
        ;
        
     value $chd_pdiagnosis
       "ANOMALIES OF AORTA" = "Anomalies of Aorta"
       "ANOMALIES OF AV"    = "Anomalies of AV"
       "ANOMALIES OF PA/PV" = "Anomalies of PA/PV"
       "ANOMALIES OF TV"    = "Anomalies of TV" 
       "ANOMALIES OF VEINS" = "Anomalies of veins" 
       "ANOMALOUS CORONARY ARTERY" = "Anomalous coronary Artery"
       "COA"     = "COA" 
       "EISENMENGER" = "Eisenmenger"
       "ENDOCARDIAL" = "Endocardial"
       "HLHS" = "HLHS" 
       "OTHER ANOMALIES" = "Other anomalies"
       "PDA"  = "PDA"
       "SUBAORTIC STENOSIS" = "Subaortic stenosis" 
       "TOF"  = "TOF"
       "TRANSPOSITION" = "Transposition"
       "TRUNCUS" = "Truncus"  
       "UNIVENTRICLE" = "Univentricle"
       "VSD"  = "VSD"
       "UNASSIGNED" = "Unassigned"
       ;
       
    value $complexity 
      "COMPLEX-TOF"   = 1
      "COMPLEX-OTHERS" = 2
      "MODERATE"      =	3
      "SIMPLE WITH MODIFIERS" =	4
      "OTHERS"        = 5
      "SIMPLE" =	6
      "UNASSIGNED" = 7
      ;
      
     value $complexity_lbl 
      "Complex - TOF"   = 1
      "Complex - Others" = 2
      "Moderate"      =	3
      "Simple with modifiers" =	4
      "Others"        = 5
      "Simple" =	6
      "Unassigned" = 7
      ;
      
    value $cstatus 
      "IN CARE"       = "In Care"
      "OUT OF CARE"   = "Out of Care"
      "NA"            = "NA"
      ; 
     
    value $gaps_in_care 
      "YES" = 1
      "NO"  = 2
      "NA"  = 3
      ;
      
     value $rpt_gaps_in_care
      '1' = "Yes"
      '2'  = "No"
      '3'  = "NA"
      ;
      
     value age_category
       18-29 = "18-29"
       30-39 = "30-39"
       40-49 = "40-49"
       50-59 = "50-59"
       60-High = "60+"
       ;
    
RUN;



