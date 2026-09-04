-- ============================================================
-- Freddie Mac Single-Family Loan-Level Dataset
-- Release 47 layout (effective July 2026)
--
-- Assuming 01_freddie_schema.sql has been run, and the steps 
-- described in that file for loading data have all been
-- followed, and that the tables orig and perf, as well as the
-- views orig_clean and perf_clean are all created and loaded. 
-- ============================================================

DROP VIEW IF EXISTS loan_outcome; -- in case new loan_outcome view desired

CREATE OR REPLACE VIEW loan_outcome AS
SELECT
    o.loan_id,
    o.orig_interest_rate,
    o.classic_fico,
    o.ltv,
    o.dti,
    o.property_state,
    o.loan_purpose,
    o.first_payment_date,
    t.zero_balance_code,
    t.zero_balance_eff_date,
    t.loan_age AS age_at_termination
FROM orig_clean o
LEFT JOIN (
    SELECT DISTINCT ON (loan_id)
           loan_id, zero_balance_code, zero_balance_eff_date, loan_age
    FROM perf
    WHERE zero_balance_code IS NOT NULL
    ORDER BY loan_id, period_ym DESC
) t USING (loan_id);


SELECT count(*) FROM loan_outcome;
SELECT count(*) FROM orig;
-- Verify the two numbers match

SELECT count(*) FILTER (WHERE zero_balance_code IS NULL) AS still_active,
       count(*) FILTER (WHERE zero_balance_code IS NOT NULL) AS terminated
FROM loan_outcome;
-- Verify that the number makes sense

SELECT count(*) AS orphans
FROM loan_outcome lo
WHERE lo.zero_balance_code IS NULL
  AND NOT EXISTS (SELECT 1 FROM perf p WHERE p.loan_id = lo.loan_id);
-- Verify that orphans=0, no NULL from left join