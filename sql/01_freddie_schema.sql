-- ============================================================
-- Freddie Mac Single-Family Loan-Level Dataset
-- Release 47 layout (effective July 2026)
--
-- Usage from psql:
--     \c freddie
--      *** Replace freddie with your database name
--     \i /path/to/freddie_schema.sql ***(This file)
--
-- Then load the data files (see LOADING section at the bottom).
-- ============================================================


-- ------------------------------------------------------------
-- 1. ORIGINATION DATA FILE  (orig_YYYYQn.txt, 31 fields)
--
-- Types follow the F"Data Type & Format" and "Max Length" 
-- columns from the "file_layout_july2026.txt" file. 
-- Flags are varchar(1) rather than char(1): bpchar blank-pads 
-- to a fixed width, which makes comparisons against a padded 
-- literal behave in ways that are easy to misread 
-- while learning.
-- ------------------------------------------------------------

DROP TABLE IF EXISTS orig CASCADE;
-- Delete previous version of table with same name if exist, 
-- and all the dependencies

CREATE TABLE orig (
    classic_fico              integer,        -- 300-850, 9999 = N/A
    first_payment_date        integer,        -- YYYYMM
    first_time_homebuyer      varchar(1),     -- Y / N / 9
    maturity_date             integer,        -- YYYYMM
    msa                       integer,        -- null = not in an MSA, or unknown
    mi_pct                    integer,        -- 1-55, 0 = no MI, 999 = N/A
    num_units                 integer,        -- 1-4, 99 = N/A
    occupancy_status          varchar(1),     -- P / I / S / 9
    cltv                      integer,        -- 999 = N/A
    dti                       integer,        -- 999 = N/A
    orig_upb                  bigint,         -- rounded to nearest $1,000
    ltv                       integer,        -- 999 = N/A
    orig_interest_rate        numeric(6,3),
    channel                   varchar(1),     -- R / B / C / T / 9
    ppm_indicator             varchar(1),     -- Y / N
    amortization_type         varchar(5),     -- FRM / ARM
    property_state            varchar(2),
    property_type             varchar(2),     -- CP / CO / PU / SF / MH / 99
    postal_code               varchar(3),     -- 3-digit prefix; 000 = unknown
    loan_id                   varchar(12),    -- PYYQnXXXXXXX
    loan_purpose              varchar(1),     -- P / C / N / R / 9
    orig_loan_term            integer,
    num_borrowers             integer,        -- 1-10, 99 = N/A
    seller_name               varchar(60),    -- or 'OTHER'
    super_conforming_flag     varchar(1),     -- Y / N
    pre_harp_loan_id          varchar(12),
    special_eligibility       varchar(1),     -- H / F / R / null
    harp_indicator            varchar(1),     -- Y / N
    property_valuation_method smallint,       -- 1 / 2 / 3 / 4, 7 = N/A
    interest_only_indicator   varchar(1),     -- Y / N
    vantage_score_4           integer         -- 300-850, 9999 = N/A
);
-- Above all follow Freddie's stated formats

-- ------------------------------------------------------------
-- 2. MONTHLY PERFORMANCE DATA FILE  (perf_YYYYQn.txt, 35 fields)
--
-- Three fields here require special attention, with all typed 
-- as text on purpose:
--
--   Field 4, delinquency status, is Alpha Numeric. It carries
--   '00'-'99' but also 'RA' (REO acquisition) and 'XX' (not
--   available). Typing it as an integer fails the load.
--
--   Field 15, net sales proceeds, is Alpha-Numeric with a max
--   length of 14. It has historically carried letter codes
--   alongside dollar amounts, so it cannot be numeric either.
--
--   Field 9, zero balance code, is kept as text to preserve the
--   leading zeros in '01', '02', '03', '09'.
-- ------------------------------------------------------------

DROP TABLE IF EXISTS perf CASCADE;

CREATE TABLE perf (
    loan_id                   varchar(12),
    period_ym                 integer,        -- YYYYMM
    current_actual_upb        numeric(14,2),
    delinquency_status        varchar(3),     -- '00'-'99', 'RA', 'XX'  <- text!
    loan_age                  integer,
    remaining_months          integer,
    defect_settlement_date    integer,        -- YYYYMM
    modification_flag         varchar(1),     -- P / Y / null
    zero_balance_code         varchar(2),     -- 01/02/03/09/15/16/96
    zero_balance_eff_date     integer,        -- YYYYMM
    current_interest_rate     numeric(8,3),
    non_interest_bearing_upb  numeric(14,2),
    ddlpi                     integer,        -- YYYYMM
    mi_recoveries             numeric(14,2),
    net_sales_proceeds        varchar(14),    -- <- text!
    non_mi_recoveries         numeric(14,2),
    total_expenses            numeric(14,2),
    legal_costs               numeric(14,2),
    maintenance_costs         numeric(14,2),
    taxes_and_insurance       numeric(14,2),
    misc_expenses             numeric(14,2),
    actual_loss               numeric(14,2),
    cumulative_mod_costs      numeric(14,2),
    interest_rate_step_ind    varchar(1),     -- Y / N / null
    payment_deferral_flag     varchar(1),     -- C / P / null
    eltv                      integer,        -- 1-998, 999 = N/A
    zero_balance_removal_upb  numeric(14,2),
    delinquent_accrued_int    numeric(14,2),
    delinquency_due_disaster  varchar(1),     -- Y / null
    borrower_assistance_plan  varchar(1),     -- F / R / T / null
    current_period_mod_costs  numeric(14,2),
    interest_bearing_upb      numeric(14,2),
    mi_cancellation_indicator varchar(1),     -- moved here from origination
    servicer_name             varchar(60),    -- moved here from origination
    bankruptcy_cramdown_costs numeric(14,2)
);


-- ------------------------------------------------------------
-- 3. CLEANED VIEWS
--
-- The raw tables keep the sentinel values.
-- Create views to convert them to NULL and turn YYYYMM integers
-- into dates, so aggregates behave.
--
-- NOTE: sign convention changes in Release 47: 
--      -- recoveries and gains are now negative, 
--      -- expenses and losses positive, and
--      -- actual loss is positive with gains negative. 
-- Anything written against the old files has the opposite sign.
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW orig_clean AS
SELECT
    loan_id,
    nullif(classic_fico, 9999)                     AS classic_fico,
    nullif(vantage_score_4, 9999)                  AS vantage_score_4,
    to_date(first_payment_date::text, 'YYYYMM')    AS first_payment_date,
    to_date(maturity_date::text, 'YYYYMM')         AS maturity_date,
    msa,
    nullif(mi_pct, 999)                            AS mi_pct,
    nullif(num_units, 99)                          AS num_units,
    nullif(occupancy_status, '9')                  AS occupancy_status,
    nullif(cltv, 999)                              AS cltv,
    nullif(dti, 999)                               AS dti,
    orig_upb,
    nullif(ltv, 999)                               AS ltv,
    orig_interest_rate,
    nullif(channel, '9')                           AS channel,
    ppm_indicator,
    amortization_type,
    property_state,
    nullif(property_type, '99')                    AS property_type,
    nullif(postal_code, '000')                     AS postal_code,
    nullif(loan_purpose, '9')                      AS loan_purpose,
    orig_loan_term,
    nullif(num_borrowers, 99)                      AS num_borrowers,
    seller_name,
    super_conforming_flag,
    pre_harp_loan_id,
    special_eligibility,
    harp_indicator,
    nullif(property_valuation_method, 7)           AS property_valuation_method,
    interest_only_indicator,
    nullif(first_time_homebuyer, '9')              AS first_time_homebuyer
FROM orig;


CREATE OR REPLACE VIEW perf_clean AS
SELECT
    loan_id,
    to_date(period_ym::text, 'YYYYMM')                AS period_date,
    current_actual_upb,
    -- months delinquent as a number; RA and XX become NULL
    CASE WHEN delinquency_status ~ '^[0-9]+$'
         THEN delinquency_status::integer END      AS months_delinquent,
    delinquency_status,                            -- keep the raw code too
    loan_age,
    remaining_months,
    modification_flag,
    zero_balance_code,
    to_date(zero_balance_eff_date::text, 'YYYYMM') AS zero_balance_eff_date,
    current_interest_rate,
    to_date(ddlpi::text, 'YYYYMM')                 AS ddlpi,
    -- dollar amount where the field is numeric; letter codes become NULL
    CASE WHEN net_sales_proceeds ~ '^-?[0-9]+(\.[0-9]+)?$'
         THEN net_sales_proceeds::numeric END      AS net_sales_proceeds_amt,
    net_sales_proceeds,                            -- keep the raw value too
    mi_recoveries,
    non_mi_recoveries,
    total_expenses,
    actual_loss,
    nullif(eltv, 999)                              AS eltv,
    payment_deferral_flag,
    delinquency_due_disaster,
    borrower_assistance_plan,
    mi_cancellation_indicator,
    servicer_name
FROM perf;


-- ------------------------------------------------------------
-- 4. LOADING  (run these in psql, NOT as part of \i)
--
-- \copy is a psql client command, not SQL. Each must be on a
-- single line with no trailing semicolon. Forward slashes work
-- in Windows paths.
--
--   FORMAT csv      avoids the backslash escaping that text
--                   format applies inside seller/servicer names
--   QUOTE E'\b'     disables quote handling; the files use none
--   NULL ''         turns empty fields into real NULLs
--
-- \copy orig FROM 'C:/data/orig_2003Q1.txt' WITH (FORMAT csv, DELIMITER '|', QUOTE E'\b', NULL '')
-- \copy perf FROM 'C:/data/perf_2003Q1.txt' WITH (FORMAT csv, DELIMITER '|', QUOTE E'\b', NULL '')
--
-- Add keys and indexes AFTER loading. Doing it in this order
-- keeps a load error and a uniqueness error distinguishable,
-- and bulk loading into an unindexed table is much faster.
--
--   ALTER TABLE orig ADD PRIMARY KEY (loan_id);
--   ALTER TABLE perf ADD PRIMARY KEY (loan_id, period_ym);
--   ***CREATE INDEX perf_loan_idx ON perf (loan_id);
--   ANALYZE orig;
--   ANALYZE perf;
-- ------------------------------------------------------------
