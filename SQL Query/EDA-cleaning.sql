--EDA Cleaning

--Make a point-in-time copy so you can always restore
IF OBJECT_ID('dbo.Customers_Raw','U') IS NULL
BEGIN
    SELECT * INTO dbo.Customers_Raw FROM dbo.Customers;
    PRINT 'Customers_Raw created';
END
ELSE
    PRINT 'Customers_Raw already exists — backup skipped';

-- 1A: schema
SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH, IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'Customers'
ORDER BY ORDINAL_POSITION;

-- 1B: total rows and distinct ids
SELECT COUNT(*) AS TotalRows, COUNT(DISTINCT CustomerID) AS DistinctCustomerIDs
FROM dbo.Customers;

-- 1C: simple missing/blank check (all varchar columns checked as text)
SELECT
 SUM(CASE WHEN CustomerID IS NULL OR LTRIM(RTRIM(CAST(CustomerID AS VARCHAR(200)))) = '' THEN 1 ELSE 0 END) AS MissingCustomerID,
 SUM(CASE WHEN TRY_CONVERT(INT,Tenure) IS NULL THEN 1 ELSE 0 END) AS NonNumericTenure,
 SUM(CASE WHEN TRY_CONVERT(DECIMAL(10,2), MonthlyCharges) IS NULL THEN 1 ELSE 0 END) AS NonNumericMonthlyCharges,
 SUM(CASE WHEN TRY_CONVERT(DECIMAL(10,2), TotalCharges) IS NULL THEN 1 ELSE 0 END) AS NonNumericTotalCharges
FROM dbo.Customers;

DECLARE @sql NVARCHAR(MAX)=N'';
SELECT @sql += 'UPDATE dbo.Customers SET ' + QUOTENAME(COLUMN_NAME) + ' = LTRIM(RTRIM(' + QUOTENAME(COLUMN_NAME) + '));' + CHAR(13)
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME='Customers' AND DATA_TYPE IN ('varchar','nvarchar','char','nchar','text');

PRINT @sql; -- optional: inspect
EXEC sp_executesql @sql;

-- 3A: remove $ and commas (if any)
UPDATE dbo.Customers
SET TotalCharges = REPLACE(REPLACE(TotalCharges,'$',''),',','')
WHERE TotalCharges LIKE '%$%' OR TotalCharges LIKE '%,%';

-- 3B: make empty strings NULL
UPDATE dbo.Customers
SET TotalCharges = NULL
WHERE LTRIM(RTRIM(ISNULL(TotalCharges,''))) = '';

-- 3C: inspect any remaining non-convertible values
SELECT CustomerID, TotalCharges
FROM dbo.Customers
WHERE TotalCharges IS NOT NULL
  AND TRY_CONVERT(DECIMAL(10,2), TotalCharges) IS NULL;

-- If the select returns rows: fix manually (or set to NULL). Example to set to NULL:
-- UPDATE dbo.Customers SET TotalCharges = NULL WHERE CustomerID IN ('id1','id2',...);

-- 3D: convert column safely (allow NULL)
ALTER TABLE dbo.Customers
ALTER COLUMN TotalCharges DECIMAL(10,2) NULL;

-- 4A: MonthlyCharges cleaning if stored as text
UPDATE dbo.Customers
SET MonthlyCharges = REPLACE(REPLACE(MonthlyCharges,'$',''),',','')
WHERE MonthlyCharges LIKE '%$%' OR MonthlyCharges LIKE '%,%';

SELECT CustomerID, MonthlyCharges
FROM dbo.Customers
WHERE MonthlyCharges IS NOT NULL
  AND TRY_CONVERT(DECIMAL(10,2), MonthlyCharges) IS NULL;

-- 4B: convert MonthlyCharges
ALTER TABLE dbo.Customers
ALTER COLUMN MonthlyCharges DECIMAL(10,2) NULL;

-- 4C: Tenure: ensure integer numeric
SELECT CustomerID, Tenure
FROM dbo.Customers
WHERE Tenure IS NOT NULL
  AND TRY_CONVERT(INT,Tenure) IS NULL;

ALTER TABLE dbo.Customers
ALTER COLUMN Tenure INT NULL;

-- columns that commonly need standardization
UPDATE dbo.Customers
SET
 Partners = CASE WHEN LOWER(LTRIM(RTRIM(ISNULL(Partners,'')))) IN ('yes','y','1','true') THEN 'Yes'
                WHEN LOWER(LTRIM(RTRIM(ISNULL(Partners,'')))) IN ('no','n','0','false','') THEN 'No'
                ELSE Partners END,
 Dependents = CASE WHEN LOWER(LTRIM(RTRIM(ISNULL(Dependents,'')))) IN ('yes','y','1','true') THEN 'Yes'
                   WHEN LOWER(LTRIM(RTRIM(ISNULL(Dependents,'')))) IN ('no','n','0','false','') THEN 'No'
                   ELSE Dependents END,
 PhoneService = CASE WHEN LOWER(LTRIM(RTRIM(ISNULL(PhoneService,'')))) IN ('yes','y','1','true') THEN 'Yes'
                     WHEN LOWER(LTRIM(RTRIM(ISNULL(PhoneService,'')))) IN ('no','n','0','false','') THEN 'No'
                     ELSE PhoneService END,
 PaperlessBilling = CASE WHEN LOWER(LTRIM(RTRIM(ISNULL(PaperlessBilling,'')))) IN ('yes','y','1','true') THEN 'Yes'
                         WHEN LOWER(LTRIM(RTRIM(ISNULL(PaperlessBilling,'')))) IN ('no','n','0','false','') THEN 'No'
                         ELSE PaperlessBilling END,
 Churn = CASE WHEN LOWER(LTRIM(RTRIM(ISNULL(Churn,'')))) IN ('yes','y','1','true') THEN 'Yes'
              WHEN LOWER(LTRIM(RTRIM(ISNULL(Churn,'')))) IN ('no','n','0','false','') THEN 'No'
              ELSE Churn END;

UPDATE dbo.Customers
SET OnlineSecurity = CASE WHEN LOWER(LTRIM(RTRIM(ISNULL(OnlineSecurity,'')))) IN ('yes','y','1') THEN 'Yes'
                          WHEN LOWER(LTRIM(RTRIM(ISNULL(OnlineSecurity,'')))) IN ('no','n','0') THEN 'No'
                          ELSE OnlineSecurity END;
-- repeat for other similar columns

-- 6A: add Churn_Flag if not exists
IF COL_LENGTH('dbo.Customers','Churn_Flag') IS NULL
    ALTER TABLE dbo.Customers ADD Churn_Flag TINYINT NULL;

UPDATE dbo.Customers
SET Churn_Flag = CASE WHEN Churn = 'Yes' THEN 1 ELSE 0 END;

-- 6B: add IsSenior BIT field
IF COL_LENGTH('dbo.Customers','IsSenior') IS NULL
    ALTER TABLE dbo.Customers ADD IsSenior BIT NULL;

UPDATE dbo.Customers
SET IsSenior = CASE WHEN TRY_CONVERT(INT,SeniorCitizen) = 1 THEN 1
                    WHEN LOWER(LTRIM(RTRIM(ISNULL(SeniorCitizen,'')))) IN ('yes','y','true') THEN 1
                    ELSE 0 END;

-- 7A: find duplicates
SELECT CustomerID, COUNT(*) AS cnt
FROM dbo.Customers
GROUP BY CustomerID
HAVING COUNT(*) > 1;

-- 7B: remove duplicates keeping the first row (no timestamp) — create new deduped table
;WITH cte AS (
  SELECT *, ROW_NUMBER() OVER(PARTITION BY CustomerID ORDER BY (SELECT NULL)) AS rn
  FROM dbo.Customers
)
SELECT * INTO dbo.Customers_deduped FROM cte WHERE rn = 1;

-- optional: verify counts
SELECT (SELECT COUNT(*) FROM dbo.Customers) AS old_count,
       (SELECT COUNT(*) FROM dbo.Customers_deduped) AS deduped_count;

-- if happy, replace Customers (or create Customers_Clean)
-- prefer creating Customers_Clean to keep raw until final:
SELECT * INTO dbo.Customers_Clean FROM dbo.Customers_deduped;

-- 8A: add AvgRevenue
IF COL_LENGTH('dbo.Customers_Clean','AvgRevenue') IS NULL
    ALTER TABLE dbo.Customers_Clean ADD AvgRevenue DECIMAL(10,2) NULL;

UPDATE dbo.Customers_Clean
SET AvgRevenue = CASE WHEN Tenure > 0 THEN ROUND(TotalCharges / NULLIF(Tenure,0), 2) ELSE MonthlyCharges END;

-- 8B: Tenure group
IF COL_LENGTH('dbo.Customers_Clean','TenureGroup') IS NULL
    ALTER TABLE dbo.Customers_Clean ADD TenureGroup VARCHAR(20) NULL;

UPDATE dbo.Customers_Clean
SET TenureGroup = CASE
    WHEN Tenure BETWEEN 0 AND 12 THEN '0-12'
    WHEN Tenure BETWEEN 13 AND 24 THEN '13-24'
    WHEN Tenure BETWEEN 25 AND 48 THEN '25-48'
    WHEN Tenure >= 49 THEN '49+' ELSE 'Unknown' END;

WITH stats AS (
  SELECT
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY MonthlyCharges) OVER () AS Q1,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY MonthlyCharges) OVER () AS Q3
  FROM dbo.Customers_Clean
)
SELECT DISTINCT Q1, Q3 FROM stats;

WITH s AS (
  SELECT
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY MonthlyCharges) OVER () AS Q1,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY MonthlyCharges) OVER () AS Q3
  FROM dbo.Customers_Clean
)
SELECT c.*
FROM dbo.Customers_Clean c
CROSS JOIN (SELECT DISTINCT Q1, Q3 FROM s) q
WHERE c.MonthlyCharges > (q.Q3 + 1.5*(q.Q3 - q.Q1))
   OR c.MonthlyCharges < (q.Q1 - 1.5*(q.Q3 - q.Q1));

-- 10A: churn distribution
SELECT Churn, COUNT(*) AS Count, ROUND(100.0*COUNT(*)/(SELECT COUNT(*) FROM dbo.Customers_Clean),2) AS Pct
FROM dbo.Customers_Clean
GROUP BY Churn;

-- 10B: check numeric nulls
SELECT
 SUM(CASE WHEN MonthlyCharges IS NULL THEN 1 ELSE 0 END) AS NullMonthlyCharges,
 SUM(CASE WHEN TotalCharges IS NULL THEN 1 ELSE 0 END) AS NullTotalCharges,
 SUM(CASE WHEN Tenure IS NULL THEN 1 ELSE 0 END) AS NullTenure
FROM dbo.Customers_Clean;

--Create a stable object for reports
CREATE OR ALTER VIEW dbo.vCustomers_Final AS
SELECT *
FROM dbo.Customers_Clean;  -- or select subset/renames

--OR you can use the physical table
IF OBJECT_ID('dbo.Customers_Final','U') IS NOT NULL DROP TABLE dbo.Customers_Final;

SELECT
  CustomerID, Gender, IsSenior, Partners, Dependents, Tenure, TenureGroup,
  PhoneService, MultipleLines, InternetService, OnlineSecurity, OnlineBackup,
  DeviceProtection, TechSupport, StreamingTV, StreamingMovies,
  Contracts, PaperlessBilling, PaymentMethod, MonthlyCharges, TotalCharges,
  AvgRevenue, Churn, Churn_Flag
INTO dbo.Customers_Final
FROM dbo.Customers_Clean;