# Diabetes Healthcare Data Analysis & Dimensional Modeling

## Project Overview
This project processes and cleans a dataset of **96,146 patient records** to analyze key medical indicators for diabetes prevalence. Using T-SQL in SQL Server, raw staging data was deduplicated, cleaned, and transformed into a **Star Schema** optimized for downstream business intelligence and visualization (Power BI/Tableau).

---

## Architecture & Data Modeling
The data was restructured from a flat staging table into normalized dimension and fact tables:

* **`staging_diabetes`**: Raw data layer used for initial deduplication, data type conversions, and zero/null handling.
* **`Dim_Patient`**: Dimension table containing unique patient demographic profiles (Gender, Age, Age Group).
* **`Fact_Diabetes_Screening`**: Fact table storing quantitative health metrics (BMI, Blood Glucose Level, HbA1c Level, Hypertension, Heart Disease) linked via surrogate keys.
* **`vw_Diabetes_Analysis`**: Database view created for seamless import into reporting tools.

---

## Data Cleaning & Transformation Pipeline
The SQL script (`diabetes_data_cleaning_and_modeling.sql`) executes the following operations:

1. **Deduplication**: Applied a Common Table Expression (CTE) using `ROW_NUMBER() OVER(PARTITION BY ...)` to eliminate **3,854 duplicate records**.
2. **Type Casting & Handling Nulls**: Standardized numeric types (`FLOAT`, `INT`) and converted invalid zero-value measurements to `NULL`.
3. **Feature Engineering**: Categorized age metrics into logical cohorts (`Under 18`, `18-35`, `36-55`, `Over 55`).
4. **Target Distribution**: Analyzed class breakdown between diabetic and non-diabetic patient profiles.

---

## Key SQL Queries
```sql
-- CTE used to purge duplicate rows
WITH CTE_Duplicates AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY gender, age, hypertension, heart_disease, 
                         smoking_history, bmi, HbA1c_level, blood_glucose_level, diabetes
            ORDER BY (SELECT NULL)
        ) AS RowNum
    FROM dbo.staging_diabetes
)
DELETE FROM CTE_Duplicates WHERE RowNum > 1;
