# Sales Pipeline & Lead Conversion Analysis
### Google Data Analytics Professional Certificate — Capstone Project (2026)

**Author:** Oluwabukunmi Akinmi  
**Period:** January – December 2024  
**Tools:** · Excel MySQL · Tableau Public · Python (data generation)  
**Status:** ✅ Complete

📊 **[View the Tableau Dashboard→](https://public.tableau.com/views/SalesPipelineAnalysisFY2024GoogleDACapstone/SalesPipelneDashboard?:language=en-US&:sid=&:redirect=auth&:display_count=n&:origin=viz_share_link)**

---

## Table of Contents
1. [Project Overview](#1-project-overview)
2. [Business Scenario](#2-business-scenario)
3. [Data Structure](#3-data-structure)
4. [Data Cleaning & Preparation](#4-data-cleaning--preparation)
5. [Analysis & Key Findings](#5-analysis--key-findings)
6. [Dashboard](#6-dashboard)
7. [Recommendations](#7-recommendations)
8. [Repository Structure](#8-repository-structure)
9. [How to Reproduce](#9-how-to-reproduce)

---

## 1. Project Overview

This project simulates the role of a data analyst supporting the sales and marketing teams of a mid-size SaaS company. The company generates leads from five marketing channels and passes them to a sales team for conversion. Despite generating a healthy volume of leads, management has no clear visibility into where leads drop off, which channels perform best, or how response time affects conversion.

The goal was to move the company from *having data* to *having insight* — answering five core business questions using SQL analysis and an interactive Tableau dashboard.

**Business questions answered:**
1. Which lead sources generate the highest conversion rates?
2. How does response time affect conversion likelihood?
3. At which pipeline stage do most leads drop off?
4. How does lead volume change over time?
5. What actions can improve sales efficiency and revenue?

---

## 2. Business Scenario

**Company type:** Digital product / SaaS (simulated)  
**Lead sources:** Website Form, Social Media, Email Marketing, Paid Ads, Referral  
**Sales pipeline:**
```
Lead Generated → Initial Contact → Qualified Lead → Sales Meeting → Proposal Sent → Deal Closed
```

**The problem:**  
499 leads generated in FY 2024. Only 175 converted (35.2% conversion rate). Management could not identify where or why leads were being lost, which channels were worth investing in, or whether the sales team's response speed was affecting outcomes.

---

## 3. Data Structure

The project uses two relational tables — a deliberate design choice that enables accurate funnel analysis.

### Table 1: `sales_leads`
One row per lead. Captures lead-level facts.

| Column | Type | Description |
|--------|------|-------------|
| Lead_ID | VARCHAR(10) | Unique lead identifier (PK) |
| Lead_Source | VARCHAR(50) | Marketing channel that generated the lead |
| Date_Created | DATE | When the lead entered the system |
| First_Contact_Time | DATE | When sales first contacted the lead |
| Response_Hours | DECIMAL(6,1) | Hours between lead creation and first contact |
| Response_Bucket | VARCHAR(30) | Grouped response time (0–1 hr, 1–4 hrs, etc.) |
| Sales_Stage | VARCHAR(30) | **Final stage reached** by the lead |
| Converted | ENUM('Yes','No') | Whether the lead became a paying customer |
| Deal_Value | DECIMAL(12,0) | Revenue generated (NULL if not converted) |
| Month | VARCHAR(15) | Month label (e.g. "Jan 2024") |
| Month_Num | TINYINT | Month number for sorting |

### Table 2: `lead_stage_history`
One row per lead per stage reached. Enables accurate funnel and time-in-stage analysis.

| Column | Type | Description |
|--------|------|-------------|
| History_ID | INT | Auto-increment PK |
| Lead_ID | VARCHAR(10) | FK → sales_leads |
| Stage | VARCHAR(30) | Pipeline stage name |
| Stage_Order | TINYINT | Stage sequence (1 = Initial Contact, 5 = Deal Closed) |
| Entry_Date | DATE | Date the lead entered this stage |

### Why two tables?

Early in the project I identified a critical flaw in the initial data model: using a single `Sales_Stage` column (representing only the *final* stage reached) made it impossible to do accurate funnel drop-off analysis. For example, a lead that closed a deal would be stamped "Deal Closed" — but it would never appear in counts for "Proposal Sent" or "Sales Meeting", producing an impossible funnel where Deal Closed (176) exceeded Proposal Sent (45).

The fix was rebuilding the data model with a proper stage history table — the same structure used by real CRM tools like Salesforce and HubSpot. Every lead now has one row per stage it passed through, each with an `Entry_Date`. This unlocks not just correct funnel counts, but also time-in-stage analysis (how many days does a lead spend at each stage before moving forward or dropping off).

**Funnel counts after the fix — logically valid and monotonically decreasing:**
```
Initial Contact    500
Qualified Lead     382   (−118 dropped, 23.6%)
Sales Meeting      292   (− 90 dropped, 23.6%)
Proposal Sent      221   (− 71 dropped, 24.3%)
Deal Closed        176   (− 45 dropped, 20.4%)
```

---

## 4. Data Cleaning & Preparation

**Raw dataset issues identified:**
- Inconsistent casing in categorical columns (`social media`, `DEAL CLOSED`)
- Negative and zero Deal_Value entries for converted leads
- ~5% missing Response_Hours values
- ~5% missing First_Contact_Time values
- Structural flaw: Sales_Stage as final-stage-only field (see Section 3)

**Cleaning steps applied:**
- Standardised Lead_Source and Sales_Stage to title case
- Replaced zero/negative Deal_Values with NULL
- Imputed missing Response_Hours using per-source median
- Derived missing First_Contact_Time from Date_Created + Response_Hours
- Added Response_Bucket as a derived categorical column
- Rebuilt data model with `lead_stage_history` table

**Validation checks run in MySQL:**
- Duplicate Lead_ID check (0 found)
- NULL audit across all columns
- Referential integrity: all Lead_IDs in history table exist in leads table
- Funnel integrity: stage counts confirmed monotonically decreasing
- Date sanity: Entry_Date confirmed to increase with Stage_Order per lead

---

## 5. Analysis & Key Findings

### Finding 1 — Referral converts at 3.7× the rate of Social Media

| Lead Source | Leads | Converted | Conv. Rate | Revenue | Rev / Lead |
|-------------|-------|-----------|------------|---------|------------|
| Referral | 60 | 42 | **70.0%** | $278K | **$4,634** |
| Website Form | 164 | 66 | 40.2% | $355K | $2,165 |
| Email Marketing | 85 | 27 | 31.8% | $186K | $2,188 |
| Paid Ads | 100 | 24 | 24.0% | $149K | $1,492 |
| Social Media | 91 | 17 | **18.7%** | $93K | $1,022 |

**Key insight:** Referral generates the highest revenue per lead ($4,634) despite being the lowest-volume channel (60 leads). Paid Ads drives 100 leads but produces only $1,492 revenue per lead — less than one third of Referral's efficiency. The company is over-investing in volume and under-investing in quality.

---

### Finding 2 — Response speed has a 4× impact on conversion rate

| Response Time | Leads | Conv. Rate |
|---------------|-------|------------|
| 0–1 hour | 82 | **54.9%** |
| 1–4 hours | 167 | 39.5% |
| 4–24 hours | 221 | 27.6% |
| 24+ hours | 30 | **13.3%** |

**Key insight:** Leads contacted within 1 hour convert at 54.9% — more than 4× the rate of leads contacted after 24 hours (13.3%). The relationship is consistent and monotonic: every hour of delay costs conversion rate. This is not a data artefact; it reflects well-documented sales research on lead response time.

---

### Finding 3 — Drop-off is consistent across all pipeline stages, not concentrated at one point

Each stage transition loses approximately 23–24% of remaining leads:

```
Initial Contact (500) → Qualified Lead (382):   −23.6%
Qualified Lead  (382) → Sales Meeting   (292):  −23.6%
Sales Meeting   (292) → Proposal Sent   (221):  −24.3%
Proposal Sent   (221) → Deal Closed     (176):  −20.4%
```

**Key insight:** There is no single catastrophic drop-off point. Loss is evenly distributed, which suggests a systemic process problem rather than a stage-specific issue. This pattern indicates either poor lead qualification at the top (allowing low-fit leads in) or insufficient nurturing at every stage.

---

### Finding 4 — Lead volume is stable but conversion rate dips mid-year

Monthly lead volume stays between 30–50 leads throughout the year with a peak in March (50 leads) and a dip in June (30 leads). The conversion rate tracks similarly, dipping to its lowest in June–July. This mid-year slump may reflect seasonal buyer behaviour or reduced sales team capacity during summer.

---

### Finding 5 — Fast-response leads that still don't convert point to a qualification problem

SQL query Q5c identified leads that were contacted within 1 hour but still did not convert. These leads exist across all sources and cluster at the Qualified Lead and Sales Meeting stages — suggesting that while the team responds quickly, the quality of discovery and qualification conversations needs improvement.

---

## 6. Dashboard

📊 **[View on Tableau Public →](https://public.tableau.com/views/SalesPipelineAnalysisFY2024GoogleDACapstone/SalesPipelneDashboard?:language=en-US&:sid=&:redirect=auth&:display_count=n&:origin=viz_share_link)**

The dashboard contains 6 panels:

| Panel | Chart Type | Business Question |
|-------|------------|-------------------|
| KPI Cards | Big number | Overall performance at a glance |
| Conversion Rate by Lead Source | Diverging horizontal bar | Q1 — Which sources perform best? |
| Monthly Lead Volume & Conversions | Dual-line chart | Q4 — How does volume change over time? |
| Sales Pipeline — Leads at Each Stage | Funnel bar chart | Q3 — Where do leads drop off? |
| How Response Speed Affects Conversion | Diverging colour bar | Q2 — Does response time matter? |
| Revenue vs Lead Volume by Source | Dual-axis bar + dot | Q1/Q5 — Revenue efficiency by source |
| Source Performance Table | Crosstab | Q5 — Full source comparison |

Each Tableau chart connects to one of six MySQL views (`vw_source_performance`, `vw_monthly_trend`, `vw_pipeline_funnel`, `vw_pipeline_dropoff`, `vw_response_time`, `vw_full_data`) — keeping the analysis logic in SQL and the visualisation logic in Tableau.

---

## 7. Recommendations

Based on the analysis, three actions would have the highest impact on revenue:

**1. Build a formal referral programme**  
Referral is the highest-converting channel (70%) with the highest revenue per lead ($4,634). Yet it produces only 60 leads — the lowest volume of any channel. A structured incentive programme (e.g. discounts or commissions for existing customers who refer new leads) could double Referral volume without proportionally increasing acquisition costs.

**2. Implement a 1-hour first-contact SLA**  
The data shows a clear, consistent relationship between response speed and conversion rate. Leads contacted within 1 hour convert at 54.9% vs 13.3% for those contacted after 24 hours. An internal SLA mandating first contact within 60 minutes of lead creation — backed by automated alerts to the sales team — is a low-cost, high-impact process change.

**3. Redirect Paid Ads budget to Website Form optimisation**  
Paid Ads produces 100 leads at a 24% conversion rate and $1,492 revenue per lead. Website Form produces 164 leads at a 40.2% conversion rate and $2,165 revenue per lead. Reallocating a portion of Paid Ads spend toward Website Form conversion rate optimisation (better landing pages, faster form flows, stronger CTAs) would likely improve both volume and quality.

---

## 8. Repository Structure

```
sales-pipeline-analysis/
│
├── README.md                          ← This file (case study)
│
├── data/
│   ├── sales_leads_raw.csv            ← Original dataset with intentional errors
│   ├── sales_leads_cleaned.csv        ← Cleaned, validated lead-level data
│   └── sales_leads_stage_history.csv  ← Stage history table (1,571 rows)
│
├── sql/
│   └── sales_pipeline.sql             ← Full MySQL script:
│                                          0. Database & table setup
│                                          1. Data import
│                                          2. Validation & cleaning checks
│                                          3. Exploratory data analysis
│                                          4. BQ1 — Lead source analysis
│                                          5. BQ2 — Response time analysis
│                                          6. BQ3 — Pipeline drop-off (uses stage history)
│                                          7. BQ4 — Monthly trends
│                                          8. BQ5 — Sales efficiency
│                                          9. Views for Tableau connection
│
└── docs/
    └── Tableau_Dashboard_Build_Guide.docx  ← Step-by-step Tableau guide
```

---

## 9. How to Reproduce

**Requirements:** MySQL 8.0+, Tableau Public (free)

**Step 1 — Set up the database**
```sql
-- Run sections 0–1 of sql/sales_pipeline.sql
-- Update the file paths in LOAD DATA to point to your local /data/ folder
```

**Step 2 — Load the data**
```sql
-- Option A: LOAD DATA LOCAL INFILE (fastest)
SET GLOBAL local_infile = 1;
-- then run the LOAD DATA blocks in section 1

-- Option B: MySQL Workbench Table Import Wizard
-- Right-click sales_leads table → Table Data Import Wizard → select sales_leads_cleaned.csv
-- Repeat for lead_stage_history table using sales_leads_stage_history.csv
```

**Step 3 — Run the analysis**
```sql
-- Run sections 2–8 to reproduce all validation checks and business question queries
-- Run section 9 to create the six Tableau-ready views
```

**Step 4 — Connect Tableau**
```
Tableau Public → Connect → MySQL
Server: localhost | Port: 3306 | Database: sales_pipeline
→ Connect to each vw_* view for the relevant chart
```

**Step 5 — View the dashboard**  
📊 [YOUR_TABLEAU_URL_HERE]

---

*This project was completed as part of the Google Data Analytics Professional Certificate. The dataset is fully synthetic and was generated specifically for this analysis.*
