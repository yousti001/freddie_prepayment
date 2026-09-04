# Freddie Mac Single-Family Loan Dataset Data Structure Notes

Release 47 layout (effective July 2026). Standard Dataset.

---

## The two files

Freddie Mac publishes each vintage quarter as two pipe-delimited text
files with no header row.

### `orig_YYYYQn.txt` -> table `orig` (31 fields)

**One row per loan.** A snapshot of the loan on the day it was made, stays
constant and is never changed for each given loan.

Contains: credit scores, original UPB, interest rate, LTV/CLTV/DTI,
loan term, property state and type, occupancy, channel, seller name,
loan purpose.

### `orig_YYYYQn.txt` -> table `perf` (31 fields)

**One row per loan per month** starting with the first payment until the loan 
terminates, is a time series.

Contains: current balance, loan age, remaining months, delinquency
status, current interest rate, and (on the final row only) how the
loan ended and any associated losses.

### The relationship

    orig                    perf
    ─────────────           ─────────────────────────────
    F03Q10000001    ──┬──   F03Q10000001 | 200305 | ...
                      ├──   F03Q10000001 | 200306 | ...
                      ├──   F03Q10000001 | 200307 | ...
                      └──   F03Q10000001 | 200308 | ...  ← final row

One-to-many, joined on `loan_id`. A loan that lived five years has
1 row in `orig` and 60 in `perf`.

(Hence why `perf` is roughly 100x larger than `orig`, and why
aggregation should be performed in SQL rather than pandas for anything 
that touches or looks at `perf`.)

---

## Loan ID's

Format `PYYQnXXXXXXX`, e.g. `F03Q10000001`:

| Position | Meaning                        | Example |
|----------|--------------------------------|---------|
| 1        | Product: F = fixed, A = ARM    | `F`     |
| 2-3      | Origination year               | `03`    |
| 4-5      | Origination quarter            | `Q1`    |
| 6-12     | Randomly assigned digits       | `0000001` |

The vintage (Year, Quater) is embedded, so all quarters can live in one table 
with no key collisions:

```sql
SELECT substring(loan_id from 2 for 4) AS vintage, count(*)
FROM orig GROUP BY vintage ORDER BY vintage;
```

---

## How loans end, i.e. the `zero_balance_code`

A significant interest for this analysis. **NULL for every month
a loan is alive**; populated only on the final row.

| Code | Meaning                                    | Category      |
|------|--------------------------------------------|---------------|
| `01` | Prepaid or matured (voluntary payoff)      | Prepayment    |
| `02` | Third party sale                           | Credit event  |
| `03` | Short sale or charge off                   | Credit loss   |
| `09` | REO disposition (foreclosure completed)    | Credit loss   |
| `15` | Whole loan sale                            | Left dataset  |
| `16` | Reperforming loan securitization           | Left dataset  |
| `96` | Underwriting/servicing defect              | Removed       |

**Caution on `01`:** it covers both refinancing/home sale *and*
reaching scheduled maturity, which are *not* the same events. Especially since
Freddie's data includes 15- and 20-year loans, which from 2003 matured
in 2018 and 2023 respectively. Will need to use `orig_loan_term` and 
`loan_age` to separate genuine prepayment from maturity before confirming that
the `01` of interest is "prepayment."

---

## Two kinds of NULL

After creating the `loan_outcome` view, it is a good idea to make a sanity
check on the data, comparing the number of NULL values within
`loan_outcome.zero_balance_code` against those in `perf.zero_balance_code`

**NULL in `loan_outcome.zero_balance_code`** - manufactured by the
`LEFT JOIN` used to create `loan_outcome`, in cases where the 
subquery found no terminal row for this loan, so Postgres fills the
right-side columns with NULL to keep the result rectangular.

**NULL in `perf.zero_balance_code`** - real data from the file. The
field is empty in the source because the loan was alive that month
and there was nothing to report. The `NULL ''` clause in `\copy`
converts empty fields to true NULLs on load.

These align in the healthy case: a loan with no terminal row is a
loan still performing. That alignment breaks if a loan exists in
`orig` but has no rows in `perf` at all — a load error that wears
the same disguise. Hence the orphan check:

```sql
SELECT count(*) AS orig_without_perf
FROM loan_outcome lo
WHERE lo.zero_balance_code IS NULL
  AND NOT EXISTS (SELECT 1 FROM perf p WHERE p.loan_id = lo.loan_id);
```

Zero means every NULL is a genuinely active loan.

---

## Sentinel values

Freddie encodes "unknown" as out-of-range numbers rather than blanks.
Postgres cannot tell these apart from real values, so `avg()` over a
raw column silently returns nonsense.

| Field                      | Sentinel | Valid range |
|----------------------------|----------|-------------|
| Classic FICO               | `9999`   | 300-850     |
| VantageScore 4.0           | `9999`   | 300-850     |
| DTI                        | `999`    | 1-65        |
| LTV / CLTV                 | `999`    | 1-998       |
| MI %                       | `999`    | 1-55 (`0` = no MI) |
| Number of units            | `99`     | 1-4         |
| Number of borrowers        | `99`     | 1-10        |
| Property valuation method  | `7`      | 1-4         |
| ELTV (performance file)    | `999`    | 1-998       |
| Various single-char flags  | `9`      | -           |

**NOTE ON `mi_pct` (MI %)** `0` here means that the loan has no mortgage
insurance, and only `999` means the amount is unknown. It is thus only valid
to convert `999` to NULL, while the `0` is kept for later analysis. 

The raw tables keep sentinels as-is; the `_clean` views convert them
with `nullif()`. This keeps the load faithful and the cleaning rules
revisable without a reload.

---

## Fields that look numeric but are not

Both will fail a load if typed as integers, and both are typed as
text in `01_schema.sql` for that reason.

- **`perf.delinquency_status`** - `'00'`-`'99'`, plus `'RA'`, `'XX'`
- **`perf.net_sales_proceeds`** - dollar amounts, plus letter codes

`perf_clean` parses each into a numeric column with a regex guard,
keeping the raw column alongside it so nothing is lost.

---

## Release 47 notable changes 

Some July 2026 revision changes worth keep on mind, especially when written
against older layouts and in ways that may not raise errors.

- **origination fields moved** Servicer Name and MI Cancellation
  Indicator moved from `orig` (now 31 fields) to `perf` (now 35 fields).
- **VantageScore 4.0 added** at origination position 31. Expect
  `9999` for essentially all 2003-vintage loans.
- **Sign convention flipped** on the loss fields. Recoveries and gains
  are now negative; expenses and losses positive. Actual Loss is
  positive, with gains negative.
- **Postal code** is now a 3-digit prefix (`435`), not `###00`
  (`43500`). Import as text instead of integer, since leading zeros
  matters for Massachusetts and New Jersey.
- **Number of borrowers** is now `1`, not `01`.
- **Super Conforming and HARP indicators** now use `N` where the old
  layout used a space.
- **Delinquency status** is now two digits (`00`, `01`) rather than
  one, and is Alpha-Numeric as it carries `RA` (REO acquisition) and
  `XX` (not available) alongside the numbers.

---

## Licensing

Freddie Mac permits free use for non-commercial, academic, and
research purposes, but requires a licensing agreement for commercial
redistribution. **The raw data files must not be committed to a
public repository.**

Aggregate and derived results (prepayment curves, rates by FICO band,
summary tables) are fine to commit. However, row-level output is not, 
even filtered or as a subset.
