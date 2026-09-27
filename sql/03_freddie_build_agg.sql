-- ============================================================
-- Freddie Mac Single-Family Loan-Level Dataset
-- Release 47 layout (effective July 2026)
--
-- Requires 01_freddie_schema.sql (tables + cleaning views) and
-- loaded data. 
-- Does not depend on 02_freddie_views.sql, but it is recommended 
-- to run that first.
--
-- These are QUERIES, not object definitions. Section 3 creates a
-- materialized view; everything else is meant to be run, read,
-- and varied.
--
-- This is a BUILD script. It produces no output worth reading and
-- is safe to run unattended. Expect several minutes --- it scans
-- every performance row. Turn on \timing to see.
--
-- Checks, cuts and plots belong in notebooks/01_prepayment_curve.ipynb
-- (not yet written), where query output renders per cell.
-- ============================================================


-- ------------------------------------------------------------
-- WHAT THIS BUILDS
--
-- One row per combination of loan age and loan characteristics,
-- holding raw event COUNTS. Rates are not computed here --- see
-- the note at the bottom.
--
-- The unit of observation is a LOAN-MONTH. A loan alive at age 47
-- contributes one row to exposure at age 47.
--
-- The grain is deliberately finer than perhaps necessary.
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
--   orig_loan_term    a dimension, not a filter. 30-year loans are
--                     43% of the 2003 cohort and 15-year are 43%
--                     as well --- discarding half the data to avoid
--                     a maturity artifact is a poor trade. Keeping
--                     term as a dimension means the spike at age
--                     180 in the 15-year curve becomes something to
--                     point at deliberately rather than contamination
--                     to filter out.
--
--   fico_band         banded rather than raw, to keep cells from
--                     becoming too thin to estimate.
--
--   loan_purpose      P purchase, C cash-out refi, N no-cash-out refi
--
--   property_state    the expensive dimension --- it multiplies row
--                     count by ~50. Worth keeping while geography is
--                     an open question; drop it if it never gets used.
--
-- Deliberately absent: calendar period. Within a single vintage,
-- calendar date is determined by loan age, so period_ym would add
-- rows without adding information. It becomes meaningful only once
-- multiple vintages are loaded, at which point it belongs here.
-- ------------------------------------------------------------

DROP MATERIALIZED VIEW IF EXISTS prepay_by_age_segment;

CREATE MATERIALIZED VIEW prepay_by_age_segment AS
SELECT
    p.loan_age,
    substring(o.loan_id from 2 for 4)                            AS vintage,
    o.orig_loan_term,
    CASE
        WHEN o.classic_fico IS NULL  THEN 'unknown'
        WHEN o.classic_fico < 660    THEN '<660'
        WHEN o.classic_fico < 700    THEN '660-699'
        WHEN o.classic_fico < 740    THEN '700-739'
        WHEN o.classic_fico < 780    THEN '740-779'
        ELSE                              '780+'
    END                                                          AS fico_band,
    o.loan_purpose,
    o.property_state,

    count(*)                                                        AS exposure,
    count(*) FILTER (WHERE p.zero_balance_code = '01')              AS prepaid,
    count(*) FILTER (WHERE p.zero_balance_code IN ('02','03','09')) AS credit_event,
    count(*) FILTER (WHERE p.zero_balance_code IN ('15','16','96')) AS removed,
    sum(p.current_actual_upb)                                       AS exposure_upb

FROM perf p
JOIN orig_clean o USING (loan_id)
WHERE o.orig_loan_term IN (120, 180, 240, 360)   -- ~98% of the cohort
  AND p.loan_age BETWEEN 0 AND 360
GROUP BY 1, 2, 3, 4, 5, 6;


CREATE INDEX prepay_seg_age_idx ON prepay_by_age_segment (loan_age);

ANALYZE prepay_by_age_segment;


-- ------------------------------------------------------------
-- AFTER ANY NEW DATA LOAD
--
--     REFRESH MATERIALIZED VIEW prepay_by_age_segment;
--
-- Materialized means the results are stored on disk, unlike the
-- views in 01 and 02. Nothing updates automatically. Every cut
-- built on this table will silently report stale numbers until
-- it is refreshed.
-- ------------------------------------------------------------

-- ------------------------------------------------------------
-- WHY SMM & CPR ARE NOT CALCULATED HERE
--
-- Counts are the primitive, whereas rates are derived. Getting 
-- the rates now would mean repeating the same FILTER expression 
-- three times in the select list, since SQL cannot reference an 
-- output alias elsewhere in the same SELECT, and any change to the
-- definition of prepayment would then need making in three places.
--
-- Rates will be computed later in the notebook:
--
--     smm = prepaid / exposure
--     cpr = 1 - (1 - smm) ** 12
--
-- CPR compounds; it is not SMM x 12. A 1% monthly rate is 11.4%
-- annually.
--
-- One rule when aggregating up from this table: SMM must be
-- recomputed from SUMMED counts. It is a ratio, so averaging the
-- SMMs of subgroups gives the wrong answer unless the subgroups
-- happen to be the same size. Sum numerator and denominator
-- first, then divide. The error is silent.
-- ------------------------------------------------------------
