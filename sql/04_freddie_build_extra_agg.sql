-- ============================================================
-- Freddie Mac Single-Family Loan-Level Dataset
-- Release 47 layout (effective July 2026)
--
-- Requires 01_freddie_schema.sql (tables + cleaning views) and
-- loaded data. 
-- Does not depend on 02_freddie_views.sql, nor 03_freddie_build_agg.sql 
-- to run that first.
--
-- This is a BUILD script. It produces no output worth reading and
-- is safe to run unattended. Expect several minutes --- it scans
-- every performance row. Turn on \timing to see.
--
-- Checks, cuts and plots belong in notebooks/01_prepayment_curve.ipynb
-- ============================================================


-- ------------------------------------------------------------
-- WHAT THIS BUILDS
--
-- One row per combination of loan age and loan characteristics,
-- holding raw event COUNTS. Rates are not computed here. 
-- **ONLY 30 year loans are considered here.**
--
-- The unit of observation is a LOAN-MONTH. A loan alive at age 47
-- contributes one row to exposure at age 47.
--
-- The grain here is deliberately finer than perhaps necessary.
-- Counts are additive over disjoint groups, so any coarser cut is
-- a GROUP BY over this table and runs in milliseconds. This file
-- runs the expensive scan once.
--
--
-- EVENT CLASSIFICATION
--
--   prepaid       '01'              paid off: refinance, home sale,
--                                   or reaching scheduled maturity
--   credit_event  '02','03','09'    third party sale, short sale,
--                                   REO disposition
--   removed       '15','16','96'    sold out of the dataset or
--                                   removed for a defect --- NOT a
--                                   borrower event
--
-- Removals are censoring, not outcomes. The loan-month formulation
-- handles them correctly without adjustment: the loan contributes
-- exposure up to its removal and then disappears, exactly like a
-- loan still alive at the data cutoff. They are counted separately
-- only so the size of that attrition is visible.
--
--
-- DIMENSIONS
--
--   vintage           origination quarter, from the loan id.
--                     Present so that loading additional vintages
--                     later does not silently pool them together.
--
--   fico_band         banded rather than raw, to keep cells from
--                     becoming too thin to estimate.
--
--   ltv_band          loan to value ratio, banded according to 
--                     preliminary analysis of LTV counts done in
--                     notebooks/01_prepayment_curve.ipynb
--
--   upb_band          original unpaid principle balance, banded
--                     according to percentiles (10th, 25th, 50th,
--                     75th, and 90th)
--
--   property_state    Worth keeping while geography is an open
--                     question; drop it if it never gets used.
--
-- Deliberately absent: calendar period. Within a single vintage,
-- calendar date is determined by loan age, so period_ym would add
-- rows without adding information. It becomes meaningful only once
-- multiple vintages are loaded, at which point it belongs here.
-- ------------------------------------------------------------


DROP MATERIALIZED VIEW IF EXISTS prepay_by_age_finer_segments;

CREATE MATERIALIZED VIEW prepay_by_age_finer_segments AS
SELECT
    p.loan_age,
    substring(o.loan_id from 2 for 4)                            AS vintage,
    CASE
        WHEN o.classic_fico IS NULL  THEN 'unknown'
        WHEN o.classic_fico < 660    THEN '<660'
        WHEN o.classic_fico < 700    THEN '660-699'
        WHEN o.classic_fico < 740    THEN '700-739'
        WHEN o.classic_fico < 780    THEN '740-779'
        ELSE                              '780+'
    END                                                          AS fico_band,
    CASE
        WHEN o.ltv IS NULL THEN 'unknown'
        WHEN o.ltv <= 60   THEN '<=60'
        WHEN o.ltv <= 70   THEN '61-70'
        WHEN o.ltv <= 75   THEN '71-75'
        WHEN o.ltv <= 80   THEN '76-80'
        WHEN o.ltv <= 90   THEN '81-90'
        ELSE                    '90+'
    END                                                          AS ltv_band,
    CASE
        WHEN o.orig_upb <= 75000   THEN '<=75k'
        WHEN o.orig_upb <= 104000   THEN '75-104k'
        WHEN o.orig_upb <= 150000   THEN '104-150k'
        WHEN o.orig_upb <= 210000   THEN '150-210k'
        WHEN o.orig_upb <= 273000   THEN '210-273k'
        ELSE                    '>273k' -- Above values for upb based on percentiles (10, 25, 50, 75, 90)
    END                                                          AS upb_band,
    o.property_state,

    count(*)                                                        AS exposure,
    count(*) FILTER (WHERE p.zero_balance_code = '01')              AS prepaid,
    count(*) FILTER (WHERE p.zero_balance_code IN ('02','03','09')) AS credit_event,
    count(*) FILTER (WHERE p.zero_balance_code IN ('15','16','96')) AS removed,
    sum(p.current_actual_upb)                                       AS exposure_upb

FROM perf p
JOIN orig_clean o USING (loan_id)
WHERE o.orig_loan_term = 360   -- Looking here only at the longer term, 30 yr loans
  AND p.loan_age BETWEEN 0 AND 360
GROUP BY 1, 2, 3, 4, 5, 6;


CREATE INDEX prepay_seg_age_finer_idx ON prepay_by_age_finer_segments (loan_age);

ANALYZE prepay_by_age_finer_segments;