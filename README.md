# freddie_prepayment
Simple analysis of home loan payment records and prepayment records

Prepayment and termination analysis of 2003 vintage from Freddie Mac's Single-Family
Loan dataset, using PostgreSQL for data management and Python for modeling.

## Data
Data for this mini-project are downloaded from Freddie Mac via the following:
https://www.freddiemac.com/research/datasets/sf-loanlevel-dataset
Details on data used to build the analysis:/
Standard Dataset, Release 47 (July 2026 layout), vintage 2003Q1-Q2/
** Later expansion might be added for more data, though personal storage is limited **

The raw data used is not included in this repository to comply with Freddie Mac's terms 
(non-commercial, research use permited, but license required for redistribution). Please
download the necessary files in 'data/raw/'. 

Field definitions, termination codes, and sentinel value handling are documented in [DATA_NOTES.md](DATA_NOTES.md).

## Setup

## Repository Layout
```bash
freddie_prepayment/
├── DATA_NOTES.md
├── README.md
├── analysis
├── data
│   ├── file_headers_july_2026
│   │   ├── origination_data_file_header.txt
│   │   └── performance_data_file_header.txt
│   ├── raw
│   │   └── historical_data_2003
│   │       ├── historical_data_2003Q1
│   │       │   ├── orig_2003Q1.txt
│   │       │   └── perf_2003Q1.txt
│   │       ├── historical_data_2003Q2
│   │       │   ├── orig_2003Q2.txt
│   │       │   └── perf_2003Q2.txt
│   │       ├── historical_data_2003Q3
│   │       │   ├── orig_2003Q3.txt
│   │       │   └── perf_2003Q3.txt
│   │       └── historical_data_2003Q4
│   │           ├── orig_2003Q4.txt
│   │           └── perf_2003Q4.txt
│   └── release-47-sample-files
│       └── Sample Files
│           ├── origination_sample_file.txt
│           ├── performance_sample_file.txt
│           └── scp46436
├── disclosure-changes-summary.pdf
├── file_layout_july_2026.xlsx
├── general_user_guide_july_2026.pdf
├── outputs
└── sql
    ├── 01_freddie_schema.sql
    └── 02_freddie_views.sql
```