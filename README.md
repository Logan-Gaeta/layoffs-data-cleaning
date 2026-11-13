# Layoffs Data Cleaning in SQL

Cleaning a global layoffs dataset using SQL. The goal was to take messy, real-world CSV data and prepare it for analysis.

## Dataset

- File: `layoffs.csv`
- Rows: 2,361
- Columns: company, location, industry, total_laid_off, percentage_laid_off, date, stage, country, funds_raised_millions
- Period: 2020-2023

## Tools Used

- DuckDB - local analytical database, file-based, no server required
- DBeaver Community - SQL editor and database client
- SQL - all cleaning logic in `clean_layoffs.sql`

## Files in This Repo

- `layoffs.csv` - raw data, untouched
- `clean_layoffs.sql` - full cleaning script, run top to bottom
- `layoffs_clean.csv` - cleaned output, exported from DuckDB
- `README.md` - this file

`layoffs.db` is not committed. It is a local DuckDB file generated when you run the script. See `.gitignore`.

## How to Reproduce

1. Clone this repo
2. Open DBeaver and create a new DuckDB connection
3. Point the connection to a new file called `layoffs.db` in this project folder
4. Update the file path in Step 1 of `clean_layoffs.sql` to your local path
5. Open `clean_layoffs.sql` in DBeaver and run it top to bottom
6. Verify the counts in the Results section below

## Cleaning Steps

1. **Load and stage**
   - Loaded `layoffs.csv` into `layoffs_raw` using `read_csv`
   - Created `layoffs_staging` as a working copy, raw data was never edited

2. **Remove duplicates**
   - Used `ROW_NUMBER()` partitioned by all columns to find exact duplicates
   - Created `layoffs_staging2` with only `row_num = 1`

3. **Standardize text**
   - `TRIM(company)` to remove leading and trailing whitespace
   - Standardized industry to `Crypto` where it appeared as `Crypto Currency`, `CryptoCurrency`, etc.
   - Removed trailing period from `United States.`

4. **Fix data types**
   - `date`: VARCHAR to DATE using `STRPTIME(date, '%m/%d/%Y')`
   - `total_laid_off`: VARCHAR to INTEGER
   - `percentage_laid_off`: VARCHAR to DOUBLE
   - `funds_raised_millions`: VARCHAR to INTEGER
   - Empty strings `''` and literal `'NULL'` strings were converted to real NULLs before casting, otherwise the cast fails

5. **Fill missing industry values**
   - Used a self-join on `company` to fill NULL industry values from another row for the same company

6. **Remove unusable rows**
   - Deleted rows where both `total_laid_off` and `percentage_laid_off` are NULL, as they contain no layoff information

7. **Create final table**
   - Created `layoffs_clean` from the cleaned staging table
   - Dropped the intermediate staging tables, keeping only `layoffs_raw` and `layoffs_clean`

## Results

| Stage | Rows | Change |
| --- | --- | --- |
| Raw | 2,361 | - |
| After removing duplicates | 2,356 | -5 duplicates |
| Clean | 1,995 | -361 rows with no layoff numbers |

Final checks:
- 0 rows in `layoffs_clean` where both `total_laid_off` and `percentage_laid_off` are NULL
- 1 row where `industry` is still NULL
- `date` is now a DATE type, range 2020-2023

## Notes

- **Bally's Interactive:** This is the 1 row where `industry` is still NULL. It has no other row for the same company to copy industry from, so it was left as NULL rather than guessed.