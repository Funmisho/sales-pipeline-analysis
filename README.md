# Sales Pipeline & Lead Conversion Analysis
### Google Data Analytics Professional Certificate — Capstone Project (2026)

**Author:** Oluwabukunmi Akinmi  
**Period:** January – December 2024  
**Tools:** Excel, MySQL, Tableau Public, Python (data generation)  
**Status:** Complete

**[View the Tableau Dashboard →](https://public.tableau.com/views/SalesPipelineAnalysisFY2024GoogleDACapstone/SalesPipelneDashboard?:language=en-US&:sid=&:redirect=auth&:display_count=n&:origin=viz_share_link)**

---

## Table of Contents
1. [Project Overview](#1-project-overview)
2. [Business Scenario](#2-business-scenario)
3. [Data Structure](#3-data-structure)
4. [Data Cleaning & Preparation](#4-data-cleaning--preparation)
5. [Analysis & Key Findings](#5-analysis--findings)
6. [Dashboard](#6-dashboard)
7. [Recommendations](#7-recommendations)
8. [Repository Structure](#8-repository-structure)
9. [How to Reproduce](#9-how-to-reproduce)

---

## 1. Project Overview

This project puts me in the role of a data analyst supporting the sales and marketing teams of a mid-size SaaS company. The company pulls leads from five marketing channels and hands them off to a sales team to convert. Leads were coming in at a healthy volume, but management had no real visibility into where those leads were dropping off, which channels were actually worth the spend, or whether how fast the sales team responded made any difference.

I set out to answer five questions using SQL and an interactive Tableau dashboard:

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
500 leads came in over FY 2024. Only 176 converted, a 35.2% conversion rate. Management couldn't say where or why leads were being lost, which channels were worth investing in, or whether the sales team's response speed had anything to do with it.

---

## 3. Data Structure

I used two relational tables, and that was a deliberate choice, not the starting point.

### Table 1: `sales_leads`
One row per lead, capturing lead-level facts.

| Column | Type | Description |
|--------|------|-------------|
| Lead_ID | VARCHAR(10) | Unique lead identifier (PK) |
| Lead_Source | VARCHAR(50) | Marketing channel that generated the lead |
| Date_Created | DATE | When the lead entered the system |
| First_Contact_Time | DATE | When sales first contacted the lead |
| Response_Hours | DECIMAL(6,1) | Hours between lead creation and first contact |
| Response_Bucket | VARCHAR(30) | Grouped response time (0–1 hr, 1–4 hrs, etc.) |
| Sales_Stage | VARCHAR(30) | Final stage reached by the lead |
| Converted | ENUM('Yes','No') | Whether the lead became a paying customer |
| Deal_Value | DECIMAL(12,0) | Revenue generated (NULL if not converted) |
| Month | VARCHAR(15) | Month label (e.g. "Jan 2024") |
| Month_Num | TINYINT | Month number for sorting |

### Table 2: `lead_stage_history`
One row per lead per stage reached. This is what makes accurate funnel and time-in-stage analysis possible.

| Column | Type | Description |
|--------|------|-------------|
| History_ID | INT | Auto-increment PK |
| Lead_ID | VARCHAR(10) | FK → sales_leads |
| Stage | VARCHAR(30) | Pipeline stage name |
| Stage_Order | TINYINT | Stage sequence (1 = Initial Contact, 5 = Deal Closed) |
| Entry_Date | DATE | Date the lead entered this stage |

### Why two tables?

I didn't start here. My first pass used a single `Sales_Stage` column that only recorded the final stage a lead reached, and it took running the funnel numbers to realize that was broken. A lead that closed a deal got stamped "Deal Closed," but it never showed up in the counts for "Proposal Sent" or "Sales Meeting" along the way. That produced a funnel that made no sense: Deal Closed (176) came out higher than Proposal Sent (45), which is impossible in a pipeline where deals have to pass through proposal before closing.

The fix was to rebuild the data model around a stage history table, one row per lead per stage, each with its own entry date. It's basically the same approach real CRMs like Salesforce and HubSpot use under the hood. Once that was in place, the funnel counts made sense, and I also got time-in-stage analysis as a bonus, since I could now see how long a lead sat at each stage before moving forward or falling out.

**Funnel counts after the fix, logically valid and decreasing at every stage:**
```
Initial Contact    500
Qualified Lead     382   (−118 dropped, 23.6%)
Sales Meeting      292   (− 90 dropped, 23.6%)
Proposal Sent      221   (− 71 dropped, 24.3%)
Deal Closed        176   (− 45 dropped, 20.4%)
```

---

## 4. Data Cleaning & Preparation

**Raw dataset issues I found:**
- Inconsistent casing in categorical columns (`social media`, `DEAL CLOSED`)
- Negative and zero Deal_Value entries for converted leads
- ~5% missing Response_Hours values
- ~5% missing First_Contact_Time values
- The Sales_Stage structural flaw described above

**How I handled them:**
- Standardized Lead_Source and Sales_Stage to title case
- Replaced zero/negative Deal_Values with NULL
- Imputed missing Response_Hours using the per-source median
- Derived missing First_Contact_Time from Date_Created + Response_Hours
- Added Response_Bucket as a derived categorical column
- Rebuilt the data model with the `lead_stage_history` table

**Validation checks run in MySQL:**
- Duplicate Lead_ID check (none found)
- NULL audit across all columns
- Referential integrity: every Lead_ID in the history table exists in the leads table
- Funnel integrity: stage counts confirmed to decrease monotonically
- Date sanity: Entry_Date confirmed to increase with Stage_Order for each lead

---

## 5. Analysis & Findings

### Referral converts at close to 4× the rate of Social Media

| Lead Source | Leads | Converted | Conv. Rate | Revenue | Rev / Lead |
|-------------|-------|-----------|------------|---------|------------|
| Referral | 60 | 42 | 70.0% | $278K | $4,634 |
| Website Form | 164 | 66 | 40.2% | $355K | $2,165 |
| Email Marketing | 85 | 27 | 31.8% | $186K | $2,188 |
| Paid Ads | 100 | 24 | 24.0% | $149K | $1,492 |
| Social Media | 91 | 17 | 18.7% | $93K | $1,022 |

Referral brings in the fewest leads of any channel, just 60, but produces the most revenue per lead by a wide margin. Paid Ads, meanwhile, brings in 100 leads and still only manages $1,492 per lead, less than a third of what Referral generates. Right now the company is spending for volume on the channel that converts worst, and barely investing in the one that converts best.

### Response speed changes conversion rate by roughly 4×

| Response Time | Leads | Conv. Rate |
|---------------|-------|------------|
| 0–1 hour | 82 | 54.9% |
| 1–4 hours | 167 | 39.5% |
| 4–24 hours | 221 | 27.6% |
| 24+ hours | 30 | 13.3% |

Leads contacted within the first hour convert more than 4× as often as leads left for over a day. The pattern holds steadily across every bucket, this isn't one outlier pulling the average, every added hour of delay costs conversion rate. It also lines up with what's already well documented in sales research on response time, so it's not a surprising finding, but it's a costly one if the team isn't acting on it.

### Drop-off is spread evenly across the funnel, not concentrated at one stage

```
Initial Contact (500) → Qualified Lead (382):   −23.6%
Qualified Lead  (382) → Sales Meeting   (292):  −23.6%
Sales Meeting   (292) → Proposal Sent   (221):  −24.3%
Proposal Sent   (221) → Deal Closed     (176):  −20.4%
```

Each stage loses roughly the same 23–24% of remaining leads. If one stage were badly broken, I'd expect to see a sharp cliff somewhere in this list, but there isn't one. That points to something systemic rather than a single fixable bottleneck, either the top of the funnel is letting in leads that were never a good fit, or nurturing is weak across the board rather than at one specific point.

### Lead volume holds steady, but conversion dips mid-year

Monthly lead volume stays in a fairly tight band, 30 to 50 leads, peaking in March and dipping to its lowest in June. Conversion rate follows a similar dip through June and July. Could be seasonal buying patterns, could be reduced sales capacity over the summer, worth digging into with a full year or two of data before drawing a firm conclusion.

### Fast response alone doesn't guarantee conversion

I ran a query (Q5c) to pull leads that were contacted within the first hour but still didn't convert. These show up across every lead source, and they cluster at the Qualified Lead and Sales Meeting stages. So the team is responding fast, that part's working, but a chunk of those fast-contacted leads are still falling out mid-funnel. That points to a discovery and qualification problem rather than a response-time problem for this subset.

---

## 6. Dashboard

**[View on Tableau Public →](https://public.tableau.com/views/SalesPipelineAnalysisFY2024GoogleDACapstone/SalesPipelneDashboard?:language=en-US&:sid=&:redirect=auth&:display_count=n&:origin=viz_share_link)**

Six panels:

| Panel | Chart Type | Business Question |
|-------|------------|-------------------|
| KPI Cards | Big number | Overall performance at a glance |
| Conversion Rate by Lead Source | Diverging horizontal bar | Q1 — Which sources perform best? |
| Monthly Lead Volume & Conversions | Dual-line chart | Q4 — How does volume change over time? |
| Sales Pipeline — Leads at Each Stage | Funnel bar chart | Q3 — Where do leads drop off? |
| How Response Speed Affects Conversion | Diverging colour bar | Q2 — Does response time matter? |
| Revenue vs Lead Volume by Source | Dual-axis bar + dot | Q1/Q5 — Revenue efficiency by source |
| Source Performance Table | Crosstab | Q5 — Full source comparison |

Each chart connects to one of six MySQL views (`vw_source_performance`, `vw_monthly_trend`, `vw_pipeline_funnel`, `vw_pipeline_dropoff`, `vw_response_time`, `vw_full_data`), so the analysis logic lives in SQL and the visualization logic lives in Tableau, kept separate on purpose.

![Sales Pipeline Dashboard](dashboard/SalesPipelne%20Dashboard.png)

---

## 7. Recommendations

Three things I'd prioritize based on this analysis:

**1. Build a formal referral program**  
Referral converts at 70% and generates the most revenue per lead of any channel, yet it's the lowest-volume source at only 60 leads. A structured incentive, discounts or commissions for existing customers who refer someone, could grow Referral volume without a proportional jump in acquisition cost.

**2. Put a 1-hour first-contact SLA in place**  
Leads contacted within an hour convert at 54.9%, versus 13.3% for leads contacted after 24 hours. An internal SLA requiring first contact within 60 minutes, backed by an automated alert to the sales team, is a low-cost change with a clear, measurable upside.

**3. Shift some Paid Ads budget toward Website Form optimization**  
Paid Ads brings in 100 leads at a 24% conversion rate and $1,492 revenue per lead. Website Form brings in 164 leads at 40.2% and $2,165 per lead. Moving some Paid Ads spend into improving the Website Form conversion path, better landing pages, faster form flow, stronger calls to action, should lift both volume and quality.

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
└── dashboard/
    └── dashboard image
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
[https://public.tableau.com/views/SalesPipelineAnalysisFY2024GoogleDACapstone/SalesPipelneDashboard?:language=en-US&:sid=&:redirect=auth&:display_count=n&:origin=viz_share_link]

---

*This project was completed as part of the Google Data Analytics Professional Certificate. The dataset is fully synthetic and was generated specifically for this analysis.*
