# 📊 Telecom Churn Analysis

## 📖 Project Overview
Customer churn is one of the biggest challenges in the telecom industry. Retaining customers is more cost-effective than acquiring new ones, and understanding **why customers leave** can directly improve business strategies.  

In this project, we analyze telecom customer data to uncover **patterns behind churn** using **SQL** for data cleaning and analysis, and **Power BI** for building an interactive dashboard.

---

## 🛠️ Tools & Technologies
- **SQL Server (T-SQL)** → Data import, cleaning, transformation, exploratory analysis  
- **Power BI** → Interactive dashboard & data visualization  
- **VS Code** → SQL & script management  
- **GitHub** → Project hosting and version control  

---

## 🔎 Project Workflow
1. **Data Import**
   - Loaded raw dataset (`Telco-Customer-Churn.csv`) into SQL Server.  
   - Created tables and handled type mismatches during import.  

2. **Data Cleaning (SQL)**
   - Converted `MonthlyCharges` and `TotalCharges` to numeric values.  
   - Standardized Yes/No columns.  
   - Removed duplicates based on `CustomerID`.  
   - Handled missing/null values.  

3. **Feature Engineering (SQL)**
   - Created `Churn_Flag` (Yes → 1, No → 0).  
   - Calculated `AvgChargesPerMonth = TotalCharges / Tenure`.  
   - Grouped tenure into buckets (0–12, 13–24, 25–48, 49+).  

4. **Exploratory Analysis (SQL)**
   - Calculated churn % across contracts, payment methods, tenure groups, etc.  
   - Identified high-risk segments (month-to-month, electronic check).  

5. **Visualization (Power BI)**
   - Built interactive dashboard with KPIs and slicers.  
   - Added insights on churn distribution, revenue impact, and customer demographics.  

---

## 📊 Dashboard Preview
![Telecom Churn Dashboard](./PowerBI%20Dashboard/TelecomChurnDashboard.jpeg)

---

## 💡 Key Insights
- 📌 **Churn Rate:** ~27% customers churned.  
- 📌 **Contracts:** Month-to-month customers are **5x more likely** to churn compared to yearly contracts.  
- 📌 **Payment Method:** Electronic check users have the **highest churn**.  
- 📌 **Tenure:** Customers with low tenure (<12 months) are more likely to leave.  
- 📌 **Revenue Impact:** Churned customers contribute significantly less to long-term revenue.  

---

## 🚀 Future Improvements
- Add predictive modeling using Python (Logistic Regression, Random Forest).  
- Build real-time dashboard with Power BI Service.  
- Customer segmentation for targeted retention strategies.  

---

## 📌 Author
👤 **Aman Kumar Singh**  
📧 amankrsingh1831@gmail.com  
🔗 www.linkedin.com/in/aman-kumar-singh-3a3305387  

---
