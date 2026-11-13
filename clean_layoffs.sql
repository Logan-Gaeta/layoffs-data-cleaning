-- Layoffs Data Cleaning | Source: layoffs.csv | DuckDB SQL
-- Raw: 2361 rows | After dedup: 2356 rows | Clean: 1995 rows

-- Data Cleaning Steps

-- 1. Remove Duplicates
-- 2. Standardize the Data
-- 3. Null values or blank values
-- 4. Remove any columns

-- Load raw data
CREATE TABLE layoffs_raw AS
SELECT * FROM read_csv('C:/path/to/your-folder/layoffs.csv', header = true);

-- Create staging table so raw data remains unmodified
CREATE TABLE layoffs_staging AS SELECT * FROM layoffs_raw;

-- Count number of recodrds to ensure no data loss 
SELECT COUNT(*) FROM layoffs_staging; --expecting 2361


-- Remove Duplicates
-- Find duplicate values using ROW_NUMBER
WITH duplicate_cte AS (
	SELECT *, 
	ROW_NUMBER() OVER(
		PARTITION BY company,
		location,
		industry, 
		total_laid_off, 
		percentage_laid_off, 
		date,
		stage,
		country,
		funds_raised_millions) AS row_num
	FROM layoffs_staging
)
SELECT * FROM duplicate_cte
WHERE row_num > 1;
-- Isolate one of the outputs to verify it is a duplicate
SELECT * FROM duplicate_cte WHERE company = 'Yahoo';
-- Create a new staging table with output from the cte where row_num = 1
CREATE TABLE layoffs_staging2 AS
SELECT company, location, industry, total_laid_off, percentage_laid_off,
       date, stage, country, funds_raised_millions
FROM (
  SELECT *,
         ROW_NUMBER() OVER (
           PARTITION BY company, location, industry, total_laid_off,
           percentage_laid_off, date, stage, country, funds_raised_millions
         ) AS row_num
  FROM layoffs_staging
)
WHERE row_num = 1;
-- New count is 2356

-- Standardize the Data
-- Remove any leading or trailing white space from company
UPDATE layoffs_staging2 SET company = TRIM(company);
-- Check industry for any opportunities to standardize
SELECT DISTINCT industry FROM layoffs_staging2 ORDER BY 1;
-- Discover three similar industries that can be standardized: Crypto, Crypto Currency, CryptoCurrency
-- Majority of dataset uses Crypto so will use that as standard
UPDATE layoffs_staging2 SET industry = 'Crypto' WHERE industry LIKE 'Crypto%';
-- Checked other columns and noticed country had one instance of United States.
UPDATE layoffs_staging2 SET country = TRIM(country, '.') WHERE country LIKE 'United States%';

-- Change Data Types
-- Date is stored as VARCHAR, change to Date
-- Convert NULLS from 'NULL' string to true NULL
UPDATE layoffs_staging2
SET date = NULL
WHERE TRIM(date) = 'NULL' OR TRIM(date) = '';
-- Convert from VARCHAR to DATE
ALTER TABLE layoffs_staging2
ALTER COLUMN date TYPE DATE
USING STRPTIME(TRIM(date), '%m/%d/%Y')::DATE;

-- total_laid_off is stored as VARCHAR, change to INTEGER
-- Handle blanks and 'NULL' in same step
ALTER TABLE layoffs_staging2
ALTER COLUMN total_laid_off TYPE INTEGER
USING NULLIF(NULLIF(TRIM(total_laid_off), ''), 'NULL')::INTEGER;

-- percentage_laid_off is stored as VARCHAR, change to DOUBLE
-- Handle blanks and 'NULL' in same step
ALTER TABLE layoffs_staging2
ALTER COLUMN percentage_laid_off TYPE DOUBLE
USING NULLIF(NULLIF(TRIM(percentage_laid_off), ''), 'NULL')::DOUBLE;

-- funds_raised_millions is stored as VARCHAR, change to INTEGER
-- Handle blanks and 'NULL' in same step
ALTER TABLE layoffs_staging2
ALTER COLUMN funds_raised_millions TYPE INTEGER
USING NULLIF(NULLIF(TRIM(funds_raised_millions), ''), 'NULL')::INTEGER;


-- Null vlaues or blank values
-- Set blank or 'NULL' text industry to NULL
UPDATE layoffs_staging2
SET industry = NULL
WHERE industry = '' OR industry = 'NULL';
-- Update Null industry if a company has industry populated in another row
UPDATE layoffs_staging2 t1
SET industry = t2.industry
FROM layoffs_staging2 t2
WHERE t1.company = t2.company
	AND t1.industry IS NULL
	AND t2.industry IS NOT NULL;

--Delete rows that do not have any data for total_laid_off and percentage_laid_off, bad data
DELETE FROM layoffs_staging2
WHERE total_laid_off IS NULL AND percentage_laid_off IS NULL;
-- 361 rows deleted, 1995 rows total

-- Remove any columns
-- Column row_num was removed in a previous step. If it was still present by this step, it can be safely removed now
ALTER TABLE layoffs_staging2 DROP COLUMN IF EXISTS row_num;


-- Move all data to a final layoffs_clean table
DROP TABLE IF EXISTS layoffs_clean;
CREATE TABLE layoffs_clean AS SELECT * FROM layoffs_staging2;
-- Count to verify
SELECT COUNT(*) FROM layoffs_clean;
-- 1995 rows returned

-- Drop intermediate tables after verifying clean
DROP TABLE IF EXISTS layoffs_staging;
DROP TABLE IF EXISTS layoffs_staging2;