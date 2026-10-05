SELECT
    *
FROM
    "DPQ_J"
WHERE
    "DPQ010" = 'Nearly every day'
    AND "DPQ020" = 'Nearly every day'
    AND "DPQ030" = 'Nearly every day'
    AND "DPQ040" = 'Nearly every day'
    AND "DPQ050" = 'Nearly every day';

SELECT
    *
FROM
    codebook
WHERE
    form = 'DPQ_J';