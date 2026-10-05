SELECT
    -- DEMO_J: who (unweighted sample analysis — no survey weights)
    d."SEQN", -- respondent sequence number
    d."RIDAGEYR", -- age in years at screening
    d."RIAGENDR", -- gender
    d."RIDRETH3", -- race/Hispanic origin w/ NH Asian
    -- DPQ_J: PHQ-9 items (score later in Python/R)
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
    -- DBQ_J: diet behavior / habits (adult-relevant)
    db."DBQ700", -- how healthy is the diet
    db."DBD895", -- # of meals not home prepared
    db."DBD900", -- # of meals from fast food or pizza place
    db."DBD905", -- # of ready-to-eat foods in past 30 days
    db."DBD910", -- # of frozen meals/pizza in past 30 days
    db."DBQ930", -- main meal planner/preparer
    db."DBQ940", -- main food shopper
    -- FSQ_J: food security / access
    f."FSDHH", -- household food security category
    f."FSDAD", -- adult food security category
    f."FSD032A", -- HH worried run out of food
    f."FSD032B", -- HH food didn't last
    f."FSD032C", -- HH couldn't afford balanced meals
    f."FSD041", -- HH adults cut size or skip meals
    f."FSD061", -- HH eat less than should
    f."FSD071", -- HH hungry, but didn't eat
    f."FSQ012", -- HH FS benefit: receive in last 12 months
    f."FSD230", -- HH FS benefit: currently receive
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
    -- covariates
    b."BMXBMI", -- body mass index (kg/m**2)
    s."SMQ020" -- smoked at least 100 cigarettes in life
FROM
    "DEMO_J" AS d
    INNER JOIN "DPQ_J" AS p ON d."SEQN" = p."SEQN"
    LEFT JOIN "DBQ_J" AS db ON d."SEQN" = db."SEQN"
    LEFT JOIN "FSQ_J" AS f ON d."SEQN" = f."SEQN"
    LEFT JOIN "DR1TOT_J" AS t1 ON d."SEQN" = t1."SEQN"
    LEFT JOIN "DR2TOT_J" AS t2 ON d."SEQN" = t2."SEQN"
    LEFT JOIN "BMX_J" AS b ON d."SEQN" = b."SEQN"
    LEFT JOIN "SMQ_J" AS s ON d."SEQN" = s."SEQN"
WHERE
    d."RIDAGEYR" >= 18 -- PHQ-9 public file is adult-oriented
    AND (
        t1."DR1DRSTZ" = 1
        OR t1."DR1DRSTZ" IS NULL
    );

-- reliable day-1 recall, or no diet row yet