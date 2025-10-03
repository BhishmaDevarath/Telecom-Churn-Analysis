--FEW BASIC OPERATIONS BEFORE DATA CLEANING

--Churn Distribution
SELECT Churn, COUNT(*) AS Count,
       ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM Customers), 2) AS Percentage
FROM Customers
GROUP BY Churn;

--Basic stats on tenure and charges
SELECT 
    MIN(Tenure) AS MinTenure,
    MAX(Tenure) AS MaxTenure,
    AVG(Tenure) AS AvgTenure,
    MIN(MonthlyCharges) AS MinMonthlyCharges,
    MAX(MonthlyCharges) AS MaxMonthlyCharges,
    AVG(MonthlyCharges) AS AvgMonthlyCharges
FROM Customers;

--Churn by contract type
SELECT Contract,
       COUNT(*) AS Total,
       SUM(CASE WHEN Churn = 'Yes' THEN 1 ELSE 0 END) AS Churned,
       ROUND(100.0 * SUM(CASE WHEN Churn = 'Yes' THEN 1 ELSE 0 END) / COUNT(*), 2) AS ChurnRate
FROM Customers
GROUP BY Contract
ORDER BY ChurnRate DESC;

--Fix TotalCharges → convert blanks to NULL, then cast to DECIMAL
UPDATE Customers
SET TotalCharges = NULL
WHERE LTRIM(RTRIM(TotalCharges)) = '';

ALTER TABLE Customers
ALTER COLUMN TotalCharges DECIMAL(10,2);

/*Create derived features
Example: Average revenue per month*/
ALTER TABLE Customers ADD AvgRevenue DECIMAL(10,2);

UPDATE Customers
SET AvgRevenue = CASE 
    WHEN Tenure > 0 THEN TotalCharges / Tenure 
    ELSE NULL END;

--ACTUAL CLEANING

-- 0. Backup raw table
IF OBJECT_ID('dbo.Customers_Raw','U') IS NULL
BEGIN
    SELECT * INTO dbo.Customers_Raw FROM dbo.Customers;
    PRINT 'Customers_Raw created';
END
ELSE
BEGIN
    PRINT 'Customers_Raw already exists — backup skipped';
END

-- 1. Check column names & data types
SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'Customers'
ORDER BY ORDINAL_POSITION;

-- 2. Count total rows & distinct customers
SELECT COUNT(*) AS TotalRows, COUNT(DISTINCT CustomerID) AS DistinctCustomerIDs FROM dbo.Customers;

-- 3. Missing / blank values for each column (casts to varchar for a safe blank-check)
SELECT
    SUM(CASE WHEN CustomerID IS NULL OR LTRIM(RTRIM(CAST(CustomerID AS VARCHAR(200)))) = '' THEN 1 ELSE 0 END) AS MissingCustomerID,
    SUM(CASE WHEN Gender IS NULL OR LTRIM(RTRIM(CAST(Gender AS VARCHAR(200)))) = '' THEN 1 ELSE 0 END) AS MissingGender,
    SUM(CASE WHEN SeniorCitizen IS NULL OR LTRIM(RTRIM(CAST(SeniorCitizen AS VARCHAR(200)))) = '' THEN 1 ELSE 0 END) AS MissingSeniorCitizen,
    SUM(CASE WHEN Partners IS NULL OR LTRIM(RTRIM(CAST(Partners AS VARCHAR(200)))) = '' THEN 1 ELSE 0 END) AS MissingPartner,
    SUM(CASE WHEN Dependents IS NULL OR LTRIM(RTRIM(CAST(Dependents AS VARCHAR(200)))) = '' THEN 1 ELSE 0 END) AS MissingDependents,
    SUM(CASE WHEN Tenure IS NULL THEN 1 ELSE 0 END) AS MissingTenure,
    SUM(CASE WHEN PhoneService IS NULL OR LTRIM(RTRIM(CAST(PhoneService AS VARCHAR(200)))) = '' THEN 1 ELSE 0 END) AS MissingPhoneService,
    SUM(CASE WHEN MultipleLines IS NULL OR LTRIM(RTRIM(CAST(MultipleLines AS VARCHAR(200)))) = '' THEN 1 ELSE 0 END) AS MissingMultipleLines,
    SUM(CASE WHEN InternetService IS NULL OR LTRIM(RTRIM(CAST(InternetService AS VARCHAR(200)))) = '' THEN 1 ELSE 0 END) AS MissingInternetService,
    SUM(CASE WHEN OnlineSecurity IS NULL OR LTRIM(RTRIM(CAST(OnlineSecurity AS VARCHAR(200)))) = '' THEN 1 ELSE 0 END) AS MissingOnlineSecurity,
    SUM(CASE WHEN OnlineBackup IS NULL OR LTRIM(RTRIM(CAST(OnlineBackup AS VARCHAR(200)))) = '' THEN 1 ELSE 0 END) AS MissingOnlineBackup,
    SUM(CASE WHEN DeviceProtection IS NULL OR LTRIM(RTRIM(CAST(DeviceProtection AS VARCHAR(200)))) = '' THEN 1 ELSE 0 END) AS MissingDeviceProtection,
    SUM(CASE WHEN TechSupport IS NULL OR LTRIM(RTRIM(CAST(TechSupport AS VARCHAR(200)))) = '' THEN 1 ELSE 0 END) AS MissingTechSupport,
    SUM(CASE WHEN StreamingTV IS NULL OR LTRIM(RTRIM(CAST(StreamingTV AS VARCHAR(200)))) = '' THEN 1 ELSE 0 END) AS MissingStreamingTV,
    SUM(CASE WHEN StreamingMovies IS NULL OR LTRIM(RTRIM(CAST(StreamingMovies AS VARCHAR(200)))) = '' THEN 1 ELSE 0 END) AS MissingStreamingMovies,
    SUM(CASE WHEN Contracts IS NULL OR LTRIM(RTRIM(CAST(Contracts AS VARCHAR(200)))) = '' THEN 1 ELSE 0 END) AS MissingContract,
    SUM(CASE WHEN PaperlessBilling IS NULL OR LTRIM(RTRIM(CAST(PaperlessBilling AS VARCHAR(200)))) = '' THEN 1 ELSE 0 END) AS MissingPaperlessBilling,
    SUM(CASE WHEN PaymentMethod IS NULL OR LTRIM(RTRIM(CAST(PaymentMethod AS VARCHAR(200)))) = '' THEN 1 ELSE 0 END) AS MissingPaymentMethod,
    SUM(CASE WHEN MonthlyCharges IS NULL OR LTRIM(RTRIM(CAST(MonthlyCharges AS VARCHAR(200)))) = '' THEN 1 ELSE 0 END) AS MissingMonthlyCharges,
    SUM(CASE WHEN TotalCharges IS NULL OR LTRIM(RTRIM(CAST(TotalCharges AS VARCHAR(200)))) = '' THEN 1 ELSE 0 END) AS MissingTotalCharges,
    SUM(CASE WHEN Churn IS NULL OR LTRIM(RTRIM(CAST(Churn AS VARCHAR(200)))) = '' THEN 1 ELSE 0 END) AS MissingChurn
FROM dbo.Customers;

-- 2. Trim whitespace on all character columns (dynamic)
DECLARE @sql NVARCHAR(MAX) = N'';
SELECT @sql = @sql + N'UPDATE dbo.Customers SET ' + QUOTENAME(COLUMN_NAME) + N' = LTRIM(RTRIM(' + QUOTENAME(COLUMN_NAME) + N'));' + CHAR(13)
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME='Customers' AND DATA_TYPE IN ('varchar','nvarchar','char','nchar','text');

PRINT @sql;  -- optional: inspect the generated updates
EXEC sp_executesql @sql;

-- 3A. Remove common characters that break numeric conversion (dollar signs, commas)
UPDATE dbo.Customers
SET TotalCharges = REPLACE(REPLACE(TotalCharges, '$', ''), ',', '')
WHERE TotalCharges LIKE '%$%' OR TotalCharges LIKE '%,%';

-- 3B. Turn empty/whitespace-only cells into NULL
UPDATE dbo.Customers
SET TotalCharges = NULL
WHERE LTRIM(RTRIM(ISNULL(TotalCharges, ''))) = '';

-- 3C. See rows that are still non-convertible (non-null but not numeric)
SELECT CustomerID, TotalCharges
FROM dbo.Customers
WHERE TotalCharges IS NOT NULL
  AND TRY_CONVERT(DECIMAL(10,2), TotalCharges) IS NULL;

-- If the above SELECT returns rows, inspect them and decide how to fix (replace, set NULL, correct manually).
-- 3D. If none or after you fix them, convert column type:
ALTER TABLE dbo.Customers
ALTER COLUMN TotalCharges DECIMAL(10,2);

-- 4A. Check if MonthlyCharges needs cleaning
SELECT DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME='Customers'
  AND COLUMN_NAME='MonthlyCharges';

-- 4B. If MonthlyCharges is varchar, clean $/commas and convert
UPDATE dbo.Customers
SET MonthlyCharges = REPLACE(REPLACE(MonthlyCharges, '$', ''), ',', '')
WHERE MonthlyCharges LIKE '%$%' OR MonthlyCharges LIKE '%,%';

SELECT CustomerID, MonthlyCharges
FROM dbo.Customers
WHERE TRY_CONVERT(DECIMAL(10,2), MonthlyCharges) IS NULL
  AND LTRIM(RTRIM(ISNULL(MonthlyCharges, ''))) <> '';

-- After verifying, run:
ALTER TABLE dbo.Customers
ALTER COLUMN MonthlyCharges DECIMAL(10,2);

-- 5A. Standardize common Yes/No columns
UPDATE dbo.Customers
SET Partners = CASE WHEN LOWER(LTRIM(RTRIM(ISNULL(Partners,'')))) IN ('yes','y','1','true') THEN 'Yes'
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

-- 6A. Add IsSenior if not exists
IF COL_LENGTH('dbo.Customers','IsSenior') IS NULL
BEGIN
    ALTER TABLE dbo.Customers ADD IsSenior BIT NULL;
END

-- 6B. Populate it from existing SeniorCitizen values (handles '1','0','Yes','No', etc.)
UPDATE dbo.Customers
SET IsSenior = CASE 
    WHEN TRY_CONVERT(INT, SeniorCitizen) = 1 THEN 1
    WHEN LOWER(LTRIM(RTRIM(ISNULL(SeniorCitizen,'')))) IN ('yes','y','true') THEN 1
    ELSE 0 END;

-- Optional: if you want IsSenior NOT NULL
ALTER TABLE dbo.Customers ALTER COLUMN IsSenior BIT NOT NULL;

-- 7A. Duplicates check
SELECT CustomerID, COUNT(*) AS cnt
FROM dbo.Customers
GROUP BY CustomerID
HAVING COUNT(*) > 1;

-- 7B. If duplicates exist, inspect them (example)
SELECT * FROM dbo.Customers WHERE CustomerID IN (
    SELECT CustomerID FROM dbo.Customers GROUP BY CustomerID HAVING COUNT(*) > 1
) ORDER BY CustomerID;

-- 8A. Add columns (if not exist)
IF COL_LENGTH('dbo.Customers','AvgRevenue') IS NULL
    ALTER TABLE dbo.Customers ADD AvgRevenue DECIMAL(10,2) NULL;

IF COL_LENGTH('dbo.Customers','TenureGroup') IS NULL
    ALTER TABLE dbo.Customers ADD TenureGroup VARCHAR(20) NULL;

-- 8B. Fill them
UPDATE dbo.Customers
SET AvgRevenue = CASE WHEN Tenure > 0 THEN ROUND(TotalCharges / NULLIF(Tenure,0), 2) ELSE NULL END,
    TenureGroup = CASE 
         WHEN Tenure BETWEEN 0 AND 12 THEN '0-12'
         WHEN Tenure BETWEEN 13 AND 24 THEN '13-24'
         WHEN Tenure BETWEEN 25 AND 48 THEN '25-48'
         ELSE '49+' END;

-- 9A. compute quartiles (MonthlyCharges)
WITH stats AS (
  SELECT
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY MonthlyCharges) OVER () AS Q1,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY MonthlyCharges) OVER () AS Q3
  FROM dbo.Customers
)
SELECT DISTINCT Q1, Q3 FROM stats;

-- 9B. list outliers > Q3 + 1.5*IQR
WITH s AS (
  SELECT
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY MonthlyCharges) OVER () AS Q1,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY MonthlyCharges) OVER () AS Q3
  FROM dbo.Customers
)
SELECT c.*
FROM dbo.Customers c
CROSS JOIN (SELECT DISTINCT Q1, Q3 FROM s) q
WHERE c.MonthlyCharges > (q.Q3 + 1.5 * (q.Q3 - q.Q1))
   OR c.MonthlyCharges < (q.Q1 - 1.5 * (q.Q3 - q.Q1));

-- 10. Create or replace Customers_Clean (simple copy; you can select only the columns/formats you want)
IF OBJECT_ID('dbo.Customers_Clean','U') IS NOT NULL
    DROP TABLE dbo.Customers_Clean;

SELECT *
INTO dbo.Customers_Clean
FROM dbo.Customers;

-- (Alternatively, create a view instead of a physical copy)
-- CREATE OR ALTER VIEW dbo.vCustomers_Clean AS SELECT ... FROM dbo.Customers;