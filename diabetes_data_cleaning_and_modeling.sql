SELECT 
    name AS database_name 
FROM sys.databases 
WHERE DB_ID(name) > 4; -- Filters out system databases
USE [MyDatabase];
GO

SELECT TOP 10 * 
FROM dbo.staging_diabetes;
-- ================================================
-- 1. Add a unique Patient Primary Key to staging
ALTER TABLE dbo.staging_diabetes 
ADD Patient_ID INT IDENTITY(1,1) PRIMARY KEY;
-- Change column data type in staging if it was created as INT
ALTER TABLE dbo.staging_diabetes
ALTER COLUMN bmi FLOAT;
GO
-- Converts '25.19' -> 25.19 -> 25
CAST(FLOOR(CAST(bmi AS FLOAT)) AS INT)
SELECT 
    Patient_ID,
    CAST(FLOOR(TRY_CAST(bmi AS FLOAT)) AS INT) AS bmi_integer,
    CAST(FLOOR(TRY_CAST(age AS FLOAT)) AS INT) AS age_integer
FROM dbo.staging_diabetes;
GO

-- 2. Convert invalid 0 measurements to NULL (adjust column names to match your schema)
UPDATE dbo.staging_diabetes
SET 
    blood_glucose_level = NULLIF(blood_glucose_level, 0),
    bmi = NULLIF(bmi, 0)
WHERE blood_glucose_level = 0 OR bmi = 0;
--==============================
SELECT 
    COLUMN_NAME, 
    DATA_TYPE, 
    IS_NULLABLE 
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_NAME = 'staging_diabetes';

--======================================
-- Check total row count
SELECT COUNT(*) AS Total_Rows 
FROM dbo.staging_diabetes;

-- Preview the first 10 rows
SELECT TOP 10 * 
FROM dbo.staging_diabetes;
--========================================
--run quality check to make sure table is deduplicated and every record has and id
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT patient_id) AS unique_patients
FROM dbo.staging_diabetes;
--================================================
--very number of diabetes and non diabetes in dataset
SELECT
    diabetes,
    COUNT(*) AS patients
FROM dbo.staging_diabetes
GROUP BY diabetes;
--==========================================
--verify number of htn and heart disease or heart disease w/o htn etc
SELECT
    hypertension,
    heart_disease,
    COUNT(*) AS patients
FROM dbo.staging_diabetes
GROUP BY hypertension, heart_disease;
--====================================
--check for duplicates
SELECT 
    gender, 
    age, 
    hypertension, 
    heart_disease, 
    smoking_history, 
    bmi, 
    HbA1c_level, 
    blood_glucose_level,
    COUNT(*) AS duplicate_count
FROM dbo.staging_diabetes
GROUP BY 
    gender, 
    age, 
    hypertension, 
    heart_disease, 
    smoking_history, 
    bmi, 
    HbA1c_level, 
    blood_glucose_level
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;
--======================================
--removing duplicates with CTE
WITH CTE_Duplicates AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY 
                gender, 
                age, 
                hypertension, 
                heart_disease, 
                smoking_history, 
                bmi, 
                HbA1c_level, 
                blood_glucose_level, 
                diabetes
            ORDER BY (SELECT NULL)
        ) AS RowNum
    FROM dbo.staging_diabetes
)
DELETE FROM CTE_Duplicates
WHERE RowNum > 1;
GO
--verify if duplicates are gone
SELECT COUNT(*) AS Cleaned_Row_Count 
FROM dbo.staging_diabetes;
GO
--=================================
--creating dim_patient
IF OBJECT_ID('dbo.Dim_Patient', 'U') IS NOT NULL DROP TABLE dbo.Dim_Patient;
GO

CREATE TABLE dbo.Dim_Patient (
    Patient_Key INT IDENTITY(1,1) PRIMARY KEY,
    Patient_ID INT,
    Gender VARCHAR(20),
    Age FLOAT,
    Age_Group VARCHAR(20)
);
GO

INSERT INTO dbo.Dim_Patient (Patient_ID, Gender, Age, Age_Group)
SELECT 
    Patient_ID,
    gender,
    age,
    CASE 
        WHEN age < 18 THEN 'Under 18'
        WHEN age BETWEEN 18 AND 35 THEN '18-35'
        WHEN age BETWEEN 36 AND 55 THEN '36-55'
        ELSE 'Over 55'
    END AS Age_Group
FROM dbo.staging_diabetes;
GO
--============================================
--create fact_diabetes_screening
IF OBJECT_ID('dbo.Fact_Diabetes_Screening', 'U') IS NOT NULL DROP TABLE dbo.Fact_Diabetes_Screening;
GO

CREATE TABLE dbo.Fact_Diabetes_Screening (
    Screening_ID INT IDENTITY(1,1) PRIMARY KEY,
    Patient_Key INT FOREIGN KEY REFERENCES dbo.Dim_Patient(Patient_Key),
    BMI FLOAT,
    Blood_Glucose_Level INT,
    HbA1c_Level FLOAT,
    Hypertension INT,
    Heart_Disease INT,
    Diabetes_Outcome INT
);
GO

INSERT INTO dbo.Fact_Diabetes_Screening (
    Patient_Key, 
    BMI, 
    Blood_Glucose_Level, 
    HbA1c_Level, 
    Hypertension, 
    Heart_Disease, 
    Diabetes_Outcome
)
SELECT 
    p.Patient_Key,
    s.bmi,
    s.blood_glucose_level,
    s.HbA1c_level,
    s.hypertension,
    s.heart_disease,
    s.diabetes
FROM dbo.staging_diabetes s
JOIN dbo.Dim_Patient p ON s.Patient_ID = p.Patient_ID;
GO
--verify fact table matched deduplicated row count of 96,146
SELECT COUNT(*) AS Fact_Table_Rows 
FROM dbo.Fact_Diabetes_Screening;--yes
--==================================================
--creating view table for power bi or tableau import
CREATE OR ALTER VIEW dbo.vw_Diabetes_Analysis AS
SELECT 
    p.Patient_ID,
    p.Gender,
    p.Age,
    p.Age_Group,
    f.BMI,
    f.Blood_Glucose_Level,
    f.HbA1c_Level,
    f.Hypertension,
    f.Heart_Disease,
    CASE WHEN f.Diabetes_Outcome = 1 THEN 'Diabetic' ELSE 'Non-Diabetic' END AS Diabetes_Status
FROM dbo.Fact_Diabetes_Screening f
JOIN dbo.Dim_Patient p ON f.Patient_Key = p.Patient_Key;
GO

-- Test the view
SELECT TOP 10 * FROM dbo.vw_Diabetes_Analysis;
GO
--===================================================================================


--============================================================================