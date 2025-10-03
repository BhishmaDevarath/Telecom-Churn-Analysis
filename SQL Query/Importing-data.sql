--Importing data from external CSV file
BULK INSERT Customers
FROM 'D:\Downloads\archive\WA_Fn-UseC_-Telco-Customer-Churn.csv' --paste your own file path
WITH (
    FIRSTROW = 2, -- skips header row
    FIELDTERMINATOR = ',', 
    ROWTERMINATOR = '\n',
    TABLOCK
);

--Displaying the table
SELECT * FROM Customers;