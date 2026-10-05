SELECT
    *
FROM
    "DEMO_J",
    "DPQ_J",
    "DBQ_J",
    "FSQ_J",
    "DR1TOT_J",
    "DR2TOT_J",
    "BMX_J",
    "SMQ_J"
WHERE "DEMO_J"."SEQN" = "DPQ_J"."SEQN"
    AND "DEMO_J"."SEQN" = "DBQ_J"."SEQN"
    AND "DEMO_J"."SEQN" = "FSQ_J"."SEQN"
    AND "DEMO_J"."SEQN" = "DR1TOT_J"."SEQN"
    AND "DEMO_J"."SEQN" = "DR2TOT_J"."SEQN"
    AND "DEMO_J"."SEQN" = "BMX_J"."SEQN"
    AND "DEMO_J"."SEQN" = "SMQ_J"."SEQN";