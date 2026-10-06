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

SELECT
    -- DEMO_J: who (unweighted sample analysis — no survey weights)
    d."SEQN", -- respondent sequence number
    d."RIDAGEYR", -- age in years at screening
    d."RIAGENDR", -- gender
    d."RIDRETH3", -- race/Hispanic origin w/ NH Asian
    d."DMDEDUC2", -- education level - adults 20+
    d."INDFMPIR", -- ratio of family income to poverty
    -- DPQ_J: PHQ-9 items (score total / severity later in Python)
    p."DPQ010", -- have little interest in doing things
    p."DPQ020", -- feeling down, depressed, or hopeless
    p."DPQ030", -- trouble sleeping or sleeping too much
    p."DPQ040", -- feeling tired or having little energy
    p."DPQ050", -- poor appetite or overeating
    p."DPQ060", -- feeling bad about yourself
    p."DPQ070", -- trouble concentrating on things
    p."DPQ080", -- moving or speaking slowly or too fast
    p."DPQ090", -- thought you would be better off dead
    p."DPQ100", -- difficulty these problems have caused
    -- DLQ_J / HUQ_J / SLQ_J: adjacent psych / function / sleep metrics
    dl."DLQ040", -- serious difficulty concentrating
    dl."DLQ050", -- serious difficulty walking
    dl."DLQ060", -- difficulty dressing or bathing
    dl."DLQ080", -- difficulty doing errands alone
    hu."HUQ010", -- general health condition
    sl."SLD012", -- sleep hours - weekdays or workdays
    sl."SLD013", -- sleep hours - weekends
    sl."SLQ050", -- ever told doctor had trouble sleeping
    -- metabolic markers
    g."LBXGLU", -- fasting plasma glucose (mg/dL)
    i."LBXIN", -- fasting insulin (uU/mL)
    gh."LBXGH", -- glycohemoglobin HbA1c (%)
    tg."LBXTR", -- fasting triglyceride (mg/dL)
    tg."LBDLDL", -- LDL-C Friedewald (mg/dL)
    tc."LBXTC", -- total cholesterol (mg/dL)
    h."LBDHDD", -- direct HDL-C (mg/dL)
    bp_chem."LBXSGL", -- serum glucose, refrigerated (mg/dL, not fasting-specific)
    -- vascular / anthropometry
    bpx."BPXSY1", -- systolic BP 1st reading (mm Hg)
    bpx."BPXSY2", -- systolic BP 2nd reading (mm Hg)
    bpx."BPXSY3", -- systolic BP 3rd reading (mm Hg)
    bpx."BPXDI1", -- diastolic BP 1st reading (mm Hg)
    bpx."BPXDI2", -- diastolic BP 2nd reading (mm Hg)
    bpx."BPXDI3", -- diastolic BP 3rd reading (mm Hg)
    bpx."BPXPLS", -- 60 sec pulse (30 sec pulse * 2)
    b."BMXBMI", -- body mass index (kg/m**2)
    b."BMXWAIST", -- waist circumference (cm)
    -- hepatic
    bp_chem."LBXSATSI", -- ALT (U/L)
    bp_chem."LBXSGTSI", -- GGT (IU/L)
    -- inflammatory
    crp."LBXHSCRP", -- hs C-reactive protein (mg/L)
    -- renal / purine
    bp_chem."LBXSCR", -- creatinine, serum (mg/dL)
    bp_chem."LBXSBU", -- blood urea nitrogen (mg/dL)
    bp_chem."LBXSUA", -- uric acid (mg/dL)
    -- iron status
    fer."LBXFER", -- ferritin (ng/mL)
    irn."LBXIRN", -- iron, frozen serum (ug/dL)
    irn."LBDPCT", -- transferrin saturation (%)
    tfr."LBXTFR", -- transferrin receptor (mg/L)
    -- fasting context (for glucose/insulin/lipids interpretation; not a weight)
    fq."PHAFSTHR", -- total length of food fast, hours
    fq."PHAFSTMN", -- total length of food fast, minutes
    -- DBQ_J: diet behavior / habits
    db."DBQ700", -- how healthy is the diet
    db."DBD895", -- # of meals not home prepared
    db."DBD900", -- # of meals from fast food or pizza place
    db."DBD905", -- # of ready-to-eat foods in past 30 days
    db."DBD910", -- # of frozen meals/pizza in past 30 days
    -- FSQ_J: food security / access
    f."FSDHH", -- household food security category
    f."FSDAD", -- adult food security category
    f."FSD032A", -- HH worried run out of food
    f."FSD032B", -- HH food didn't last
    f."FSD032C", -- HH couldn't afford balanced meals
    -- DR1TOT_J: day-1 total intakes
    t1."DR1DRSTZ", -- dietary recall status
    t1."DR1TKCAL", -- energy (kcal)
    t1."DR1TPROT", -- protein (gm)
    t1."DR1TCARB", -- carbohydrate (gm)
    t1."DR1TTFAT", -- total fat (gm)
    t1."DR1TSFAT", -- total saturated fatty acids (gm)
    t1."DR1TMFAT", -- total monounsaturated fatty acids (gm)
    t1."DR1TPFAT", -- total polyunsaturated fatty acids (gm)
    t1."DR1TFIBE", -- dietary fiber (gm)
    t1."DR1TSUGR", -- total sugars (gm)
    t1."DR1TSODI", -- sodium (mg)
    -- DR2TOT_J: day-2 total intakes
    t2."DR2DRSTZ", -- dietary recall status
    t2."DR2TKCAL", -- energy (kcal)
    t2."DR2TPROT", -- protein (gm)
    t2."DR2TCARB", -- carbohydrate (gm)
    t2."DR2TTFAT", -- total fat (gm)
    t2."DR2TSFAT", -- total saturated fatty acids (gm)
    t2."DR2TMFAT", -- total monounsaturated fatty acids (gm)
    t2."DR2TPFAT", -- total polyunsaturated fatty acids (gm)
    t2."DR2TFIBE", -- dietary fiber (gm)
    t2."DR2TSUGR", -- total sugars (gm)
    t2."DR2TSODI", -- sodium (mg)
    -- PAQ_J: physical activity
    pa."PAQ605", -- vigorous work activity
    pa."PAQ620", -- moderate work activity
    pa."PAQ635", -- walk or bicycle
    pa."PAQ650", -- vigorous recreational activities
    pa."PAD660", -- minutes vigorous recreational activities
    pa."PAQ665", -- moderate recreational activities
    pa."PAD675", -- minutes moderate recreational activities
    pa."PAD680", -- minutes sedentary activity
    -- SMQ_J / COT_J: smoking
    s."SMQ020", -- smoked at least 100 cigarettes in life
    s."SMQ040", -- do you now smoke cigarettes
    s."SMD650", -- avg # cigarettes/day during past 30 days
    cot."LBXCOT", -- serum cotinine (ng/mL)
    -- ALQ_J: alcohol
    a."ALQ111", -- ever had a drink of any kind of alcohol
    a."ALQ121", -- past 12 mo how often have alcohol drink
    a."ALQ130", -- avg # alcohol drinks/day - past 12 mos
    a."ALQ151", -- ever have 4/5 or more drinks every day
    -- comorbidities: diabetes, BP/chol history, medical conditions
    di."DIQ010", -- doctor told you have diabetes
    di."DIQ160", -- ever told you have prediabetes
    bq."BPQ020", -- ever told you had high blood pressure
    bq."BPQ050A", -- now taking prescribed medicine for HBP
    bq."BPQ080", -- doctor told you - high cholesterol
    mc."MCQ160B", -- ever told had congestive heart failure
    mc."MCQ160C", -- ever told you had coronary heart disease
    mc."MCQ160E", -- ever told you had heart attack
    mc."MCQ160F", -- ever told you had a stroke
    mc."MCQ160L", -- ever told you had any liver condition
    mc."MCQ160O", -- ever told you had COPD
    mc."MCQ220", -- ever told you had cancer or malignancy
    mc."MCQ080" -- doctor ever said you were overweight
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
