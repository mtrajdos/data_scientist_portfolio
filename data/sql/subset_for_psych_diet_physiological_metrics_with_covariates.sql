-- Unweighted analysis extract for PHQ-9 vs cardiometabolic / inflammatory / renal /
-- iron markers, with diet, activity, smoking, alcohol, sleep, and comorbidity covariates.
-- PHQ-9 total / severity and forest-plot models are computed later in Python (not here).
-- No survey weights by design (sample-only framing).
--
-- Planned marker groups for stratified / colored forest plots:
--   metabolic:   LBXGLU, LBXIN, LBXGH, LBXTR, LBDLDL, LBXTC, LBDHDD
--   vascular:    BPXSY*, BPXDI* (mean in Python), BMXBMI, BMXWAIST
--   hepatic:     LBXSATSI (ALT), LBXSGTSI (GGT)
--   inflammatory: LBXHSCRP
--   renal:       LBXSCR, LBXSBU, LBXSUA
--   iron:        LBXFER, LBXIRN, LBDPCT, LBXTFR
--
-- Short plot labels (code -> short_label): see nhanes_var_labels.sql
--   labels = pd.read_sql((project_root / "data/sql/nhanes_var_labels.sql").read_text(encoding="utf-8"), engine)
--   label_map = dict(zip(labels["code"], labels["short_label"]))

SELECT
    -- DEMO_J: who (unweighted sample analysis — no survey weights)
    d."SEQN", -- Respondent sequence number
    d."RIDAGEYR", -- Age at screening (years)
    d."RIAGENDR", -- Gender
    d."RIDRETH3", -- Race/Hispanic origin
    d."DMDEDUC2", -- Education (adults 20+)
    d."INDFMPIR", -- Income-to-poverty ratio
    -- DPQ_J: PHQ-9 items (score total / severity later in Python)
    p."DPQ010", -- Little interest in doing things
    p."DPQ020", -- Feeling down or hopeless
    p."DPQ030", -- Trouble sleeping
    p."DPQ040", -- Feeling tired / little energy
    p."DPQ050", -- Poor appetite or overeating
    p."DPQ060", -- Feeling bad about yourself
    p."DPQ070", -- Trouble concentrating
    p."DPQ080", -- Moving/speaking slowly or fast
    p."DPQ090", -- Thoughts of being better off dead
    p."DPQ100", -- Difficulty caused by problems
    -- DLQ_J / HUQ_J / SLQ_J: adjacent psych / function / sleep metrics
    dl."DLQ040", -- Serious difficulty concentrating
    dl."DLQ050", -- Serious difficulty walking
    dl."DLQ060", -- Difficulty dressing or bathing
    dl."DLQ080", -- Difficulty doing errands alone
    hu."HUQ010", -- General health condition
    sl."SLD012", -- Sleep hours (weekdays)
    sl."SLD013", -- Sleep hours (weekends)
    sl."SLQ050", -- Ever told doctor: trouble sleeping
    -- metabolic markers
    g."LBXGLU", -- Fasting glucose (mg/dL)
    i."LBXIN", -- Insulin (uU/mL)
    gh."LBXGH", -- Glycohemoglobin / HbA1c (percent)
    tg."LBXTR", -- Triglyceride (mg/dL)
    tg."LBDLDL", -- LDL cholesterol (mg/dL)
    tc."LBXTC", -- Total cholesterol (mg/dL)
    h."LBDHDD", -- HDL cholesterol (mg/dL)
    bp_chem."LBXSGL", -- Serum glucose (mg/dL)
    -- vascular / anthropometry
    bpx."BPXSY1", -- Systolic BP 1st reading (mm Hg)
    bpx."BPXSY2", -- Systolic BP 2nd reading (mm Hg)
    bpx."BPXSY3", -- Systolic BP 3rd reading (mm Hg)
    bpx."BPXSY4", -- Systolic BP 4th reading (mm Hg)
    bpx."BPXDI1", -- Diastolic BP 1st reading (mm Hg)
    bpx."BPXDI2", -- Diastolic BP 2nd reading (mm Hg)
    bpx."BPXDI3", -- Diastolic BP 3rd reading (mm Hg)
    bpx."BPXDI4", -- Diastolic BP 4th reading (mm Hg)
    bpx."BPXPLS", -- Pulse (60 sec)
    b."BMXBMI", -- BMI (kg/m²)
    b."BMXWAIST", -- Waist circumference (cm)
    -- hepatic
    bp_chem."LBXSATSI", -- ALT (U/L)
    bp_chem."LBXSGTSI", -- GGT (IU/L)
    -- inflammatory
    crp."LBXHSCRP", -- hs-CRP (mg/L)
    -- renal / purine
    bp_chem."LBXSCR", -- Serum creatinine (mg/dL)
    bp_chem."LBXSBU", -- Blood urea nitrogen (mg/dL)
    bp_chem."LBXSUA", -- Uric acid (mg/dL)
    -- iron status
    fer."LBXFER", -- Ferritin (ng/mL)
    irn."LBXIRN", -- Serum iron (ug/dL)
    irn."LBDPCT", -- Transferrin saturation (percent)
    tfr."LBXTFR", -- Transferrin receptor (mg/L)
    -- fasting context (for glucose/insulin/lipids interpretation; not a weight)
    fq."PHAFSTHR", -- Food fast length (hours)
    fq."PHAFSTMN", -- Food fast length (minutes)
    -- DBQ_J: diet behavior / habits
    db."DBQ700", -- How healthy is the diet
    db."DBD895", -- Meals not home prepared
    db."DBD900", -- Meals from fast food/pizza
    db."DBD905", -- Ready-to-eat foods (30 days)
    db."DBD910", -- Frozen meals/pizza (30 days)
    -- FSQ_J: food security / access
    f."FSDHH", -- Household food security
    f."FSDAD", -- Adult food security
    f."FSD032A", -- HH worried food would run out
    f."FSD032B", -- HH food did not last
    f."FSD032C", -- HH could not afford balanced meals
    -- DR1TOT_J: day-1 total intakes
    t1."DR1DRSTZ", -- Day-1 dietary recall status
    t1."DR1TKCAL", -- Day-1 energy (kcal)
    t1."DR1TPROT", -- Day-1 protein (g)
    t1."DR1TCARB", -- Day-1 carbohydrate (g)
    t1."DR1TTFAT", -- Day-1 total fat (g)
    t1."DR1TSFAT", -- Day-1 saturated fat (g)
    t1."DR1TMFAT", -- Day-1 monounsaturated fat (g)
    t1."DR1TPFAT", -- Day-1 polyunsaturated fat (g)
    t1."DR1TFIBE", -- Day-1 dietary fiber (g)
    t1."DR1TSUGR", -- Day-1 total sugars (g)
    t1."DR1TSODI", -- Day-1 sodium (mg)
    -- DR2TOT_J: day-2 total intakes
    t2."DR2DRSTZ", -- Day-2 dietary recall status
    t2."DR2TKCAL", -- Day-2 energy (kcal)
    t2."DR2TPROT", -- Day-2 protein (g)
    t2."DR2TCARB", -- Day-2 carbohydrate (g)
    t2."DR2TTFAT", -- Day-2 total fat (g)
    t2."DR2TSFAT", -- Day-2 saturated fat (g)
    t2."DR2TMFAT", -- Day-2 monounsaturated fat (g)
    t2."DR2TPFAT", -- Day-2 polyunsaturated fat (g)
    t2."DR2TFIBE", -- Day-2 dietary fiber (g)
    t2."DR2TSUGR", -- Day-2 total sugars (g)
    t2."DR2TSODI", -- Day-2 sodium (mg)
    -- PAQ_J: physical activity
    pa."PAQ605", -- Vigorous work activity
    pa."PAQ620", -- Moderate work activity
    pa."PAQ635", -- Walk or bicycle
    pa."PAQ650", -- Vigorous recreational activity
    pa."PAD660", -- Minutes vigorous recreation
    pa."PAQ665", -- Moderate recreational activity
    pa."PAD675", -- Minutes moderate recreation
    pa."PAD680", -- Minutes sedentary activity
    -- SMQ_J / COT_J: smoking
    s."SMQ020", -- Smoked ≥100 cigarettes in life
    s."SMQ040", -- Current cigarette smoking
    s."SMD650", -- Avg cigarettes/day (past 30 days)
    cot."LBXCOT", -- Serum cotinine (ng/mL)
    -- ALQ_J: alcohol
    a."ALQ111", -- Ever drank alcohol
    a."ALQ121", -- Alcohol frequency (past 12 mo)
    a."ALQ130", -- Avg drinks/day (past 12 mo)
    a."ALQ151", -- Ever 4/5+ drinks every day
    -- comorbidities: diabetes, BP/chol history, medical conditions
    di."DIQ010", -- Doctor told you: diabetes
    di."DIQ160", -- Ever told: prediabetes
    bq."BPQ020", -- Ever told: high blood pressure
    bq."BPQ050A", -- Now taking medicine for HBP
    bq."BPQ080", -- Doctor told you: high cholesterol
    mc."MCQ160B", -- Ever told: congestive heart failure
    mc."MCQ160C", -- Ever told: coronary heart disease
    mc."MCQ160D", -- Ever told: angina
    mc."MCQ160E", -- Ever told: heart attack
    mc."MCQ160F", -- Ever told: stroke
    mc."MCQ160L", -- Ever told: liver condition
    mc."MCQ160O", -- Ever told: COPD
    mc."MCQ220", -- Ever told: cancer or malignancy
    mc."MCQ080" -- Doctor ever said: overweight
FROM
    "DEMO_J" AS d
    INNER JOIN "DPQ_J" AS p ON d."SEQN" = p."SEQN"
    LEFT JOIN "DLQ_J" AS dl ON d."SEQN" = dl."SEQN"
    LEFT JOIN "HUQ_J" AS hu ON d."SEQN" = hu."SEQN"
    LEFT JOIN "SLQ_J" AS sl ON d."SEQN" = sl."SEQN"
    LEFT JOIN "GLU_J" AS g ON d."SEQN" = g."SEQN"
    LEFT JOIN "INS_J" AS i ON d."SEQN" = i."SEQN"
    LEFT JOIN "GHB_J" AS gh ON d."SEQN" = gh."SEQN"
    LEFT JOIN "TRIGLY_J" AS tg ON d."SEQN" = tg."SEQN"
    LEFT JOIN "TCHOL_J" AS tc ON d."SEQN" = tc."SEQN"
    LEFT JOIN "HDL_J" AS h ON d."SEQN" = h."SEQN"
    LEFT JOIN "BIOPRO_J" AS bp_chem ON d."SEQN" = bp_chem."SEQN"
    LEFT JOIN "BPX_J" AS bpx ON d."SEQN" = bpx."SEQN"
    LEFT JOIN "BMX_J" AS b ON d."SEQN" = b."SEQN"
    LEFT JOIN "HSCRP_J" AS crp ON d."SEQN" = crp."SEQN"
    LEFT JOIN "FERTIN_J" AS fer ON d."SEQN" = fer."SEQN"
    LEFT JOIN "FETIB_J" AS irn ON d."SEQN" = irn."SEQN"
    LEFT JOIN "TFR_J" AS tfr ON d."SEQN" = tfr."SEQN"
    LEFT JOIN "FASTQX_J" AS fq ON d."SEQN" = fq."SEQN"
    LEFT JOIN "DBQ_J" AS db ON d."SEQN" = db."SEQN"
    LEFT JOIN "FSQ_J" AS f ON d."SEQN" = f."SEQN"
    LEFT JOIN "DR1TOT_J" AS t1 ON d."SEQN" = t1."SEQN"
    LEFT JOIN "DR2TOT_J" AS t2 ON d."SEQN" = t2."SEQN"
    LEFT JOIN "PAQ_J" AS pa ON d."SEQN" = pa."SEQN"
    LEFT JOIN "SMQ_J" AS s ON d."SEQN" = s."SEQN"
    LEFT JOIN "COT_J" AS cot ON d."SEQN" = cot."SEQN"
    LEFT JOIN "ALQ_J" AS a ON d."SEQN" = a."SEQN"
    LEFT JOIN "DIQ_J" AS di ON d."SEQN" = di."SEQN"
    LEFT JOIN "BPQ_J" AS bq ON d."SEQN" = bq."SEQN"
    LEFT JOIN "MCQ_J" AS mc ON d."SEQN" = mc."SEQN"
WHERE
    d."RIDAGEYR" >= 18 -- PHQ-9 public file is adult-oriented
    AND (
        t1."DR1DRSTZ" = 1 -- reliable day-1 recall
        OR t1."DR1DRSTZ" IS NULL -- or no diet row yet
    );
