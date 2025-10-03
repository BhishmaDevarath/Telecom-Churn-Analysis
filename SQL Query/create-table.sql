--Creating the database
CREATE DATABASE TelecomChurnDB;

--Shifting workspace to the desired databse
USE TelecomChurnDB;
GO

--Creating the table
CREATE TABLE Customers (
    customerID VARCHAR(50) PRIMARY KEY,
    gender VARCHAR(50),
    SeniorCitizen BIT,
    Partners VARCHAR(50),
    Dependents VARCHAR(50),
    tenure INT,
    PhoneService VARCHAR(50),
    MultipleLines VARCHAR(50),
    InternetService VARCHAR(50),
    OnlineSecurity VARCHAR(50),
    OnlineBackup VARCHAR(50),
    DeviceProtection VARCHAR(50),
    TechSupport VARCHAR(50),
    StreamingTV VARCHAR(50),
    StreamingMovies VARCHAR(50),
    Contracts VARCHAR(50),
    PaperlessBilling VARCHAR(50),
    PaymentMethod VARCHAR(50),
    MonthlyCharges DECIMAL(10,2),
    TotalCharges DECIMAL(10,2),
    Churn VARCHAR(50)
);