-- ============================================================
--  LEAD CONVERSION & SALES PIPELINE ANALYSIS
--  MySQL Script  |  Google Data Analytics Capstone Project
--  Author : Oluwabukunmi Akinmi
--  Date   : 2024
-- ============================================================

-- ============================================================
-- 1. DATA IMPORT
-- ============================================================
CREATE DATABASE sales_pipeline;
USE sales_pipeline;

CREATE TABLE sales_leads(
	Lead_id 		VARCHAR(10) 	NOT NULL PRIMARY KEY,
    Lead_Source 	VARCHAR(50) 	NOT NULL,
    Date_Created	DATE 			NOT NULL,
    First_Contact_Time DATE,			
    Response_Hours	DECIMAL(6,1),
    Response_Bucket	VARCHAR(30),
    Sales_Stage		VARCHAR(30)		NOT NULL,
    Converted		ENUM('Yes', 'No') NOT NULL,
    Deal_Value		DECIMAL(12,0)	,
    Month			VARCHAR(15),
    Month_Num		TINYINT
);

-- Table 2: One row per lead per stage (stage history)

CREATE TABLE lead_stage_history (
    History_ID    INT AUTO_INCREMENT  PRIMARY KEY,
    Lead_ID       VARCHAR(10)         NOT NULL,
    Stage         VARCHAR(30)         NOT NULL,
    Stage_Order   TINYINT             NOT NULL,   -- 1=Initial Contact, 5=Deal Closed
    Entry_Date    DATE                NOT NULL,
    FOREIGN KEY (Lead_ID) REFERENCES sales_leads(Lead_ID)
);


-- ============================================================
-- 2. DATA INTEGRITY VERIFICATION
-- ============================================================

-- Check for duplicate lead ids
SELECT 
	Lead_id,
    COUNT(*) AS duplicates
FROM sales_leads
GROUP BY Lead_id
HAVING COUNT(*) > 1;

-- Null Audit across key columns
SELECT 
	SUM(Lead_id IS NULL) AS null_lead_id,
    SUM(Lead_Source IS NULL) AS null_lead_source,
    SUM(Date_Created IS NULL) AS null_date_created,
    SUM(First_Contact_Time IS NULL) AS null_first_contact_time,
	SUM(Response_Hours IS NULL) AS null_response_hours,
	SUM(Sales_Stage IS NULL) AS null_sales_stage,
	SUM(Converted IS NULL) AS nullconverted,
	SUM(Deal_Value IS NULL) AS null_deal_value,
	SUM(Month IS NULL) AS null_month,
	SUM(Month_Num IS NULL) AS null_Month_Num
FROM sales_leads;

-- Verify consistent categorical values
SELECT DISTINCT Lead_Source  FROM sales_leads ORDER BY 1;
SELECT DISTINCT Sales_Stage  FROM sales_leads ORDER BY 1;
SELECT DISTINCT Converted    FROM sales_leads;
SELECT DISTINCT Response_Bucket FROM sales_leads ORDER BY 1;

-- Sanity check: Deal value should only be populated for converted leads
SELECT	
	Converted,
    COUNT(*) AS leads,
    SUM(Deal_Value > 0) AS has_deal_value
FROM sales_leads
GROUP BY Converted;
-- of 175 leads which were converted, only 167 deal value was recorded

-- Response time reasonableness — flag anything over 720 hrs (30 days)
SELECT 	
	Lead_id,
    Lead_Source,
    Response_Hours AS over_30_days_response
FROM sales_leads
WHERE Response_Hours > 720;

-- Date range check 
SELECT 
	MIN(Date_Created) AS earliest_lead,
    MAX(Date_Created) AS latest_lead
FROM sales_leads;


-- ============================================================
-- 3. EXPLORATORY DATA ANALYSIS (EDA)
-- ============================================================
-- Overall KPIs
SELECT
	COUNT(*) AS total_leads,
    SUM(Converted = 'Yes') AS total_converted,
    ROUND(SUM(Converted = 'Yes')/ COUNT(*) * 100, 1) AS conversion_rate_pct,
    ROUND(SUM(Deal_Value), 0) AS total_revenue,
    ROUND(AVG(Deal_Value), 0) AS avg_deal_value,
    ROUND(AVG(Response_Hours), 1) AS avg_response_hours
FROM sales_leads;

-- Leads and revenue by source (quick overview)
SELECT 
	Lead_Source,
    COUNT(*) AS total_leads,
    SUM(converted = 'Yes') AS  converted,
    ROUND(SUM(converted = 'Yes')/COUNT(*) * 100, 1) AS conversion_rate_pct,
    ROUND(SUM(Deal_Value), 0) AS Revenue
FROM sales_leads
GROUP BY Lead_Source
ORDER BY conversion_rate_pct DESC;

-- Leads per pipeline stage
SELECT
    Sales_Stage AS Final_Stage,
    COUNT(*) AS lead_count,
    ROUND(COUNT(*) / (SELECT COUNT(*) FROM sales_leads) * 100, 1) AS pct_of_total
FROM sales_leads
GROUP BY Sales_Stage
ORDER BY FIELD(Sales_Stage,
    'Initial Contact','Qualified Lead','Sales Meeting','Proposal Sent','Deal Closed');
    

-- ============================================================
-- 4. BUSINESS QUESTION 1
--    Which lead sources generate the highest conversion rates?
-- ============================================================

-- Q1a. Full source performance breakdown

SELECT
	Lead_Source,
    COUNT(*) AS total_leads,
    SUM(Converted = 'Yes') AS converted,
    ROUND(SUM(converted = 'Yes')/COUNT(*) * 100, 1) AS conversion_rate_pct,
    ROUND(AVG(CASE WHEN Converted = 'Yes' THEN Deal_Value END), 0) AS avg_deal_value,
    ROUND(SUM(Deal_Value), 0) AS total_revenue,
    ROUND(AVG(Response_Hours), 1) AS avg_response_hours,
    ROUND(
		SUM(Deal_Value) / NULLIF((SELECT SUM(Deal_Value) FROM sales_leads), 0) * 100
		, 1) AS revenue_share_pct
FROM sales_leads
GROUP BY Lead_Source 
ORDER BY conversion_rate_pct DESC;

-- Q1b. Source performance vs company average (index)
--      An index > 100 means the source outperforms the average
WITH avg_cvr AS (
	SELECT
		SUM(Converted = 'Yes') / COUNT(*) AS company_avg
	FROM sales_leads)
SELECT
	s.Lead_Source,
    ROUND(SUM(s.converted = 'Yes') / COUNT(*) * 100, 1) AS conversion_rate_pct,
    ROUND(company_avg * 100, 1) AS company_avg_pct,
    ROUND(
		(SUM(s.converted = 'Yes') / COUNT(*)) / a.company_avg * 100
	, 0) AS performance_index
FROM sales_leads s
CROSS JOIN avg_cvr a 
GROUP BY s.Lead_Source, a.company_avg
ORDER BY performance_index DESC;

-- Q1c. Revenue efficiency: revenue generated per lead (not just per conversion)
SELECT
	Lead_Source,
    COUNT(*) AS total_lead,
    ROUND(SUM(Deal_Value), 0) AS total_revenue,
    ROUND(SUM(Deal_Value) / COUNT(*)) AS revenue_per_lead
FROM sales_leads
GROUP BY Lead_Source
ORDER BY revenue_per_lead DESC;


-- ============================================================
-- 5. BUSINESS QUESTION 2
--    How does response time affect conversion likelihood?
-- ============================================================
    
-- Q2a. Conversion rate by response time bucket
SELECT
	Response_Bucket,
    COUNT(*) AS total_leads,
    SUM(Converted = 'Yes') AS converted,
    ROUND(SUM(Converted = 'Yes') / COUNT(*) * 100, 1) AS conversion_rate_pct,
    ROUND(AVG(Response_Hours), 1) AS avg_response_hours
FROM sales_leads
GROUP BY Response_Bucket
ORDER BY conversion_rate_pct DESC;

-- Q2b. Fast vs slow responders — binary split at 1-hour threshold
SELECT
	CASE WHEN Response_Hours <= 1 THEN 'Within 1 Hour' ELSE 'After 1 Hour' END AS response_speed,
    COUNT(*) AS total_leads,
    SUM(Converted = 'Yes') AS converted,
    ROUND(SUM(Converted = 'Yes') / COUNT(*) * 100, 1) AS conversion_rate_pct
FROM sales_leads
GROUP BY response_speed
ORDER BY conversion_rate_pct;

-- Q2c. Average response time for converted vs non-converted leads
SELECT
	Converted,
    ROUND(AVG(Response_Hours), 1) AS avg_response_hour,
    ROUND(MIN(Response_Hours), 1) AS min_response_hour,
    ROUND(MAX(Response_Hours), 1) AS max_response_hour
FROM sales_leads
GROUP BY converted;

-- Q2d. Response time breakdown by lead source
--      Helps identify which channels are being followed up slowest

SELECT
	Lead_Source,
    ROUND(AVG(Response_Hours), 1) AS avg_response_hours,
    ROUND(MIN(Response_Hours), 1) AS fastest_response,
    ROUND(MAX(Response_Hours), 1) AS slowest_response,
    SUM(Response_Hours <= 1) AS responded_within_1hr,
    ROUND(SUM(Response_Hours <= 1) / COUNT(*) * 100, 1) AS pct_within_1hr
FROM sales_leads
GROUP BY Lead_Source
ORDER BY avg_response_hours ASC;

-- ============================================================
-- 6. BUSINESS QUESTION 3
--    At which stage of the pipeline do most leads drop off?
-- ============================================================

-- Q3a. Leads that reached each pipeline stage 
SELECT
    Stage,
    Stage_Order,
    COUNT(DISTINCT Lead_ID) AS leads_reached
FROM lead_stage_history
GROUP BY Stage, Stage_Order
ORDER BY Stage_Order;
    
-- Q3b. Stage-to-stage drop-off using window functions
WITH stage_counts AS (
    SELECT
        Stage,
        Stage_Order,
        COUNT(DISTINCT Lead_ID) AS leads_reached
    FROM lead_stage_history
    GROUP BY Stage, Stage_Order
),
with_previous AS (
    SELECT
        Stage,
        Stage_Order,
        leads_reached,
        LAG(leads_reached) OVER (ORDER BY Stage_Order) AS prev_stage_leads
    FROM stage_counts
)
SELECT
    Stage,
    leads_reached,
    COALESCE(prev_stage_leads - leads_reached, 0)           AS leads_dropped,
    CASE
        WHEN prev_stage_leads IS NULL THEN NULL
        ELSE ROUND(
            (prev_stage_leads - leads_reached) / prev_stage_leads * 100
        , 1)
    END AS drop_off_rate_pct
FROM with_previous
ORDER BY Stage_Order;

-- Q3c. Drop-off breakdown by lead source
SELECT
    l.Lead_Source,
    COUNT(DISTINCT CASE WHEN h.Stage = 'Initial Contact' THEN l.Lead_ID END) AS initial_contact,
    COUNT(DISTINCT CASE WHEN h.Stage = 'Qualified Lead'  THEN l.Lead_ID END) AS qualified_lead,
    COUNT(DISTINCT CASE WHEN h.Stage = 'Sales Meeting'   THEN l.Lead_ID END) AS sales_meeting,
    COUNT(DISTINCT CASE WHEN h.Stage = 'Proposal Sent'   THEN l.Lead_ID END) AS proposal_sent,
    COUNT(DISTINCT CASE WHEN h.Stage = 'Deal Closed'     THEN l.Lead_ID END) AS deal_closed,
    COUNT(DISTINCT l.Lead_ID) AS total_leads
FROM sales_leads l
JOIN lead_stage_history h USING (Lead_ID)
GROUP BY l.Lead_Source
ORDER BY deal_closed DESC;

-- ============================================================
-- 7. BUSINESS QUESTION 4
--    How does lead volume change over time?
-- ============================================================

-- Q4a. Monthly lead volume, conversions, and revenue
SELECT
    Month_Num,
    Month AS month_label,
    COUNT(*) AS total_leads,
    SUM(Converted = 'Yes') AS conversions,
    ROUND(SUM(Converted = 'Yes') / COUNT(*) * 100, 1) AS conversion_rate_pct,
    ROUND(SUM(COALESCE(Deal_Value, 0)), 0) AS monthly_revenue,
    ROUND(AVG(Response_Hours), 1) AS avg_response_hours
FROM sales_leads
GROUP BY Month_Num, Month
ORDER BY Month_Num;

-- Q4b. Quarterly rollup
SELECT
    CONCAT('Q', CEIL(Month_Num / 3)) AS quarter,
    COUNT(*) AS total_leads,
    SUM(Converted = 'Yes') AS conversions,
    ROUND(SUM(Converted = 'Yes') / COUNT(*) * 100, 1) AS conversion_rate_pct,
    ROUND(SUM(COALESCE(Deal_Value, 0)), 0) AS quarterly_revenue
FROM sales_leads
GROUP BY quarter
ORDER BY quarter;

-- Q4c. Month-over-month lead growth
WITH monthly AS (
    SELECT Month_Num, Month, COUNT(*) AS leads
    FROM sales_leads
    GROUP BY Month_Num, Month
)
SELECT
    Month_Num, Month, leads,
    LAG(leads) OVER (ORDER BY Month_Num) AS prev_month_leads,
    leads - LAG(leads) OVER (ORDER BY Month_Num) AS mom_change,
    ROUND(
        (leads - LAG(leads) OVER (ORDER BY Month_Num))
        / LAG(leads) OVER (ORDER BY Month_Num) * 100
    , 1) AS mom_growth_pct
FROM monthly
ORDER BY Month_Num;

-- Q4d. Lead source mix by month
SELECT
    Month_Num, Month, Lead_Source, COUNT(*) AS leads
FROM sales_leads
GROUP BY Month_Num, Month, Lead_Source
ORDER BY Month_Num, leads DESC;

-- ============================================================
-- 8. BUSINESS QUESTION 5
--    What actions can improve sales efficiency & conversion?
-- ============================================================

-- Q5a. Best-performing segment: source × response speed
SELECT
    Lead_Source,
    CASE WHEN Response_Hours <= 1 THEN 'Fast (≤1hr)' ELSE 'Slow (>1hr)' END AS response_speed,
    COUNT(*) AS leads,
    SUM(Converted = 'Yes') AS converted,
    ROUND(SUM(Converted = 'Yes') / COUNT(*) * 100, 1) AS conversion_rate_pct,
    ROUND(AVG(CASE WHEN Converted = 'Yes' THEN Deal_Value END), 0) AS avg_deal_value
FROM sales_leads
GROUP BY Lead_Source, response_speed
ORDER BY conversion_rate_pct DESC;

-- Q5b. High-value deals (top 25%) — where do they originate?
WITH deal_quartile AS (
    SELECT *, NTILE(4) OVER (ORDER BY Deal_Value) AS value_quartile
    FROM sales_leads
    WHERE Deal_Value IS NOT NULL
)
SELECT
    Lead_Source,
    COUNT(*) AS high_value_deals,
    ROUND(AVG(Deal_Value), 0) AS avg_deal_value,
    ROUND(SUM(Deal_Value), 0) AS total_revenue
FROM deal_quartile
WHERE value_quartile = 4
GROUP BY Lead_Source
ORDER BY total_revenue DESC;

-- Q5c. Fast-response leads that still did NOT convert (qualification problem)
SELECT
    Lead_Source,
    Sales_Stage AS furthest_stage,
    COUNT(*) AS leads,
    ROUND(AVG(Response_Hours), 1) AS avg_response_hours
FROM sales_leads
WHERE Converted = 'No' AND Response_Hours <= 1
GROUP BY Lead_Source, Sales_Stage
ORDER BY leads DESC;

-- Q5d. Overall efficiency score per source
SELECT
    Lead_Source,
    ROUND(SUM(Converted = 'Yes') / COUNT(*) * 100, 1) AS conversion_rate_pct,
    ROUND(AVG(Response_Hours), 1) AS avg_response_hours,
    ROUND(AVG(CASE WHEN Converted = 'Yes' THEN Deal_Value END), 0) AS avg_deal_value,
    ROUND(SUM(COALESCE(Deal_Value, 0)) / COUNT(*), 0) AS revenue_per_lead
FROM sales_leads
GROUP BY Lead_Source
ORDER BY revenue_per_lead DESC;

-- ============================================================
-- 9. VIEWS  
-- ============================================================

CREATE OR REPLACE VIEW vw_source_performance AS
SELECT
    Lead_Source,
    COUNT(*)  AS total_leads,
    SUM(Converted = 'Yes') AS converted_leads,
    ROUND(SUM(Converted = 'Yes') / COUNT(*) * 100, 1) AS conversion_rate_pct,
    ROUND(AVG(CASE WHEN Converted = 'Yes' THEN Deal_Value END), 0) AS avg_deal_value,
    ROUND(SUM(COALESCE(Deal_Value, 0)), 0) AS total_revenue,
    ROUND(AVG(Response_Hours), 1) AS avg_response_hours
FROM sales_leads
GROUP BY Lead_Source;

CREATE OR REPLACE VIEW vw_monthly_trend AS
SELECT
    Month_Num,
    Month  AS month_label,
    COUNT(*) AS total_leads,
    SUM(Converted = 'Yes') AS conversions,
    ROUND(SUM(Converted = 'Yes') / COUNT(*) * 100, 1) AS conversion_rate_pct,
    ROUND(SUM(COALESCE(Deal_Value, 0)), 0) AS monthly_revenue
FROM sales_leads
GROUP BY Month_Num, Month;


CREATE OR REPLACE VIEW vw_pipeline_funnel AS
SELECT
    Stage,
    Stage_Order,
    COUNT(DISTINCT Lead_ID) AS leads_reached
FROM lead_stage_history
GROUP BY Stage, Stage_Order;

CREATE OR REPLACE VIEW vw_pipeline_dropoff AS
WITH stage_counts AS (
    SELECT Stage, Stage_Order, COUNT(DISTINCT Lead_ID) AS leads_reached
    FROM lead_stage_history
    GROUP BY Stage, Stage_Order
),
with_previous AS (
    SELECT Stage, Stage_Order, leads_reached,
           LAG(leads_reached) OVER (ORDER BY Stage_Order) AS prev_stage_leads
    FROM stage_counts
)
SELECT
    Stage, Stage_Order, leads_reached,
    COALESCE(prev_stage_leads - leads_reached, 0) AS leads_dropped,
    CASE
        WHEN prev_stage_leads IS NULL THEN 0
        ELSE ROUND((prev_stage_leads - leads_reached) / prev_stage_leads * 100, 1)
    END AS drop_off_rate_pct
FROM with_previous
ORDER BY Stage_Order;

CREATE OR REPLACE VIEW vw_response_time AS
SELECT
    Response_Bucket,
    FIELD(Response_Bucket, '0–1 hr','1–4 hrs','4–24 hrs','24+ hrs') AS bucket_order,
    COUNT(*) AS total_leads,
    SUM(Converted = 'Yes') AS converted,
    ROUND(SUM(Converted = 'Yes') / COUNT(*) * 100, 1) AS conversion_rate_pct
FROM sales_leads
GROUP BY Response_Bucket;

CREATE OR REPLACE VIEW vw_full_data AS
SELECT
    l.Lead_ID, l.Lead_Source, l.Date_Created, l.First_Contact_Time,
    l.Response_Hours, l.Response_Bucket, l.Sales_Stage,
    l.Converted,
    CASE WHEN l.Converted = 'Yes' THEN 1 ELSE 0 END AS converted_flag,
    l.Deal_Value, l.Month, l.Month_Num,
    CONCAT('Q', CEIL(l.Month_Num / 3)) AS quarter,
    CASE WHEN l.Response_Hours <= 1 THEN 'Fast (≤1hr)'
         ELSE 'Slow (>1hr)' END AS response_speed,
    h_start.Entry_Date AS pipeline_start_date,
    h_close.Entry_Date AS close_date,
    DATEDIFF(h_close.Entry_Date, h_start.Entry_Date) AS days_to_close
FROM sales_leads l
LEFT JOIN lead_stage_history h_start
    ON l.Lead_ID = h_start.Lead_ID AND h_start.Stage = 'Initial Contact'
LEFT JOIN lead_stage_history h_close
    ON l.Lead_ID = h_close.Lead_ID AND h_close.Stage = 'Deal Closed';

-- ============================================================
-- END OF SCRIPT
-- ============================================================





		

    

    
    


    
    
    
