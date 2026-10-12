-- Short axis / legend titles for NHANES codes used in the psych–diet–physiology extract.
-- Source: data/raw/nhanes/2017-2018/_file_list.txt (wording lightly shortened for plots).
-- Usage:
--   labels = pd.read_sql(path.read_text(encoding="utf-8"), engine)
--   label_map = dict(zip(labels["code"], labels["short_label"]))

SELECT *
FROM (
    VALUES
        -- DEMO
        ('SEQN', 'Respondent sequence number'),
        ('RIDAGEYR', 'Age at screening (years)'),
        ('RIAGENDR', 'Gender'),
        ('RIDRETH3', 'Race/Hispanic origin'),
        ('DMDEDUC2', 'Education (adults 20+)'),
        ('INDFMPIR', 'Income-to-poverty ratio'),
        -- PHQ-9 (DPQ)
        ('DPQ010', 'Little interest in doing things'),
        ('DPQ020', 'Feeling down or hopeless'),
        ('DPQ030', 'Trouble sleeping'),
        ('DPQ040', 'Feeling tired / little energy'),
        ('DPQ050', 'Poor appetite or overeating'),
        ('DPQ060', 'Feeling bad about yourself'),
        ('DPQ070', 'Trouble concentrating'),
        ('DPQ080', 'Moving/speaking slowly or fast'),
        ('DPQ090', 'Thoughts of being better off dead'),
        ('DPQ100', 'Difficulty caused by problems'),
        -- Adjacent psych / function / sleep
        ('DLQ040', 'Serious difficulty concentrating'),
        ('DLQ050', 'Serious difficulty walking'),
        ('DLQ060', 'Difficulty dressing or bathing'),
        ('DLQ080', 'Difficulty doing errands alone'),
        ('HUQ010', 'General health condition'),
        ('SLD012', 'Sleep hours (weekdays)'),
        ('SLD013', 'Sleep hours (weekends)'),
        ('SLQ050', 'Ever told doctor: trouble sleeping'),
        -- Metabolic markers
        ('LBXGLU', 'Fasting glucose (mg/dL)'),
        ('LBXIN', 'Insulin (uU/mL)'),
        ('LBXGH', 'Glycohemoglobin / HbA1c (%)'),
        ('LBXTR', 'Triglyceride (mg/dL)'),
        ('LBDLDL', 'LDL cholesterol (mg/dL)'),
        ('LBXTC', 'Total cholesterol (mg/dL)'),
        ('LBDHDD', 'HDL cholesterol (mg/dL)'),
        ('LBXSGL', 'Serum glucose (mg/dL)'),
        -- Vascular / anthropometry (* = mean of readings in Python)
        ('BPXSY', 'Systolic BP (mm Hg)'),
        ('BPXDI', 'Diastolic BP (mm Hg)'),
        ('BPXSY1', 'Systolic BP 1st reading (mm Hg)'),
        ('BPXSY2', 'Systolic BP 2nd reading (mm Hg)'),
        ('BPXSY3', 'Systolic BP 3rd reading (mm Hg)'),
        ('BPXDI1', 'Diastolic BP 1st reading (mm Hg)'),
        ('BPXDI2', 'Diastolic BP 2nd reading (mm Hg)'),
        ('BPXDI3', 'Diastolic BP 3rd reading (mm Hg)'),
        ('BPXPLS', 'Pulse (60 sec)'),
        ('BMXBMI', 'BMI (kg/m²)'),
        ('BMXWAIST', 'Waist circumference (cm)'),
        -- Hepatic
        ('LBXSATSI', 'ALT (U/L)'),
        ('LBXSGTSI', 'GGT (IU/L)'),
        -- Inflammatory
        ('LBXHSCRP', 'hs-CRP (mg/L)'),
        -- Renal / purine
        ('LBXSCR', 'Serum creatinine (mg/dL)'),
        ('LBXSBU', 'Blood urea nitrogen (mg/dL)'),
        ('LBXSUA', 'Uric acid (mg/dL)'),
        -- Iron
        ('LBXFER', 'Ferritin (ng/mL)'),
        ('LBXIRN', 'Serum iron (ug/dL)'),
        ('LBDPCT', 'Transferrin saturation (%)'),
        ('LBXTFR', 'Transferrin receptor (mg/L)'),
        -- Fasting context
        ('PHAFSTHR', 'Food fast length (hours)'),
        ('PHAFSTMN', 'Food fast length (minutes)'),
        -- Diet behavior
        ('DBQ700', 'How healthy is the diet'),
        ('DBD895', 'Meals not home prepared'),
        ('DBD900', 'Meals from fast food/pizza'),
        ('DBD905', 'Ready-to-eat foods (30 days)'),
        ('DBD910', 'Frozen meals/pizza (30 days)'),
        -- Food security
        ('FSDHH', 'Household food security'),
        ('FSDAD', 'Adult food security'),
        ('FSD032A', 'HH worried food would run out'),
        ('FSD032B', 'HH food did not last'),
        ('FSD032C', 'HH could not afford balanced meals'),
        -- Diet recall day 1
        ('DR1DRSTZ', 'Day-1 dietary recall status'),
        ('DR1TKCAL', 'Day-1 energy (kcal)'),
        ('DR1TPROT', 'Day-1 protein (g)'),
        ('DR1TCARB', 'Day-1 carbohydrate (g)'),
        ('DR1TTFAT', 'Day-1 total fat (g)'),
        ('DR1TSFAT', 'Day-1 saturated fat (g)'),
        ('DR1TMFAT', 'Day-1 monounsaturated fat (g)'),
        ('DR1TPFAT', 'Day-1 polyunsaturated fat (g)'),
        ('DR1TFIBE', 'Day-1 dietary fiber (g)'),
        ('DR1TSUGR', 'Day-1 total sugars (g)'),
        ('DR1TSODI', 'Day-1 sodium (mg)'),
        -- Diet recall day 2
        ('DR2DRSTZ', 'Day-2 dietary recall status'),
        ('DR2TKCAL', 'Day-2 energy (kcal)'),
        ('DR2TPROT', 'Day-2 protein (g)'),
        ('DR2TCARB', 'Day-2 carbohydrate (g)'),
        ('DR2TTFAT', 'Day-2 total fat (g)'),
        ('DR2TSFAT', 'Day-2 saturated fat (g)'),
        ('DR2TMFAT', 'Day-2 monounsaturated fat (g)'),
        ('DR2TPFAT', 'Day-2 polyunsaturated fat (g)'),
        ('DR2TFIBE', 'Day-2 dietary fiber (g)'),
        ('DR2TSUGR', 'Day-2 total sugars (g)'),
        ('DR2TSODI', 'Day-2 sodium (mg)'),
        -- Physical activity
        ('PAQ605', 'Vigorous work activity'),
        ('PAQ620', 'Moderate work activity'),
        ('PAQ635', 'Walk or bicycle'),
        ('PAQ650', 'Vigorous recreational activity'),
        ('PAD660', 'Minutes vigorous recreation'),
        ('PAQ665', 'Moderate recreational activity'),
        ('PAD675', 'Minutes moderate recreation'),
        ('PAD680', 'Minutes sedentary activity'),
        -- Smoking
        ('SMQ020', 'Smoked ≥100 cigarettes in life'),
        ('SMQ040', 'Current cigarette smoking'),
        ('SMD650', 'Avg cigarettes/day (past 30 days)'),
        ('LBXCOT', 'Serum cotinine (ng/mL)'),
        -- Alcohol
        ('ALQ111', 'Ever drank alcohol'),
        ('ALQ121', 'Alcohol frequency (past 12 mo)'),
        ('ALQ130', 'Avg drinks/day (past 12 mo)'),
        ('ALQ151', 'Ever 4/5+ drinks every day'),
        -- Comorbidities
        ('DIQ010', 'Doctor told you: diabetes'),
        ('DIQ160', 'Ever told: prediabetes'),
        ('BPQ020', 'Ever told: high blood pressure'),
        ('BPQ050A', 'Now taking medicine for HBP'),
        ('BPQ080', 'Doctor told you: high cholesterol'),
        ('MCQ160B', 'Ever told: congestive heart failure'),
        ('MCQ160C', 'Ever told: coronary heart disease'),
        ('MCQ160D', 'Ever told: angina'),
        ('MCQ160E', 'Ever told: heart attack'),
        ('MCQ160F', 'Ever told: stroke'),
        ('MCQ160L', 'Ever told: liver condition'),
        ('MCQ160O', 'Ever told: COPD'),
        ('MCQ220', 'Ever told: cancer or malignancy'),
        ('MCQ080', 'Doctor ever said: overweight')
) AS var_labels(code, short_label);
