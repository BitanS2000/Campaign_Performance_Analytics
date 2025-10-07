-- Create the base transactions table

CREATE TABLE transactions (
	transaction_id TEXT PRIMARY KEY,
	customer_id TEXT,
	product_id TEXT,
	transaction_date DATE,
	units_sold INTEGER,
	discount_applied NUMERIC(5,2),
	revenue NUMERIC(10,2),
	clicks INTEGER,
	impressions INTEGER,
	conversion_rate NUMERIC(5,2),
	category TEXT,
	region TEXT,
	ad_ctr NUMERIC(6,4),
	ad_cpc NUMERIC(5,2),
	ad_spend NUMERIC(10,2)
);

-- Data Quality Check 1: Missing transaction dates

SELECT COUNT(*) FROM transactions WHERE transaction_id IS NULL;

-- Data Quality Check 2: Negative revenue or ad spend

SELECT * FROM transactions WHERE revenue < 0 OR ad_spend < 0;

-- Data Quality Check 3: Duplicate transaction IDs

SELECT transaction_id, COUNT(*) 
FROM transactions 
GROUP BY transaction_id 
HAVING COUNT(*) > 1;

-- Ad Spend Efficiency by Region and Category

SELECT 
    region,
    category,
    ROUND(SUM(revenue - ad_spend) / NULLIF(SUM(ad_spend), 0), 2) AS roi,
    ROUND(SUM(revenue), 2) AS total_revenue,
    ROUND(SUM(ad_spend), 2) AS total_ad_spend,
    COUNT(*) AS transactions
FROM transactions
GROUP BY region, category
ORDER BY roi DESC;

-- Funnel Metrics by Region and Category

SELECT
  region,
  category,
  CASE 
    WHEN discount_applied < 0.05 THEN '0–5%'
    WHEN discount_applied < 0.10 THEN '5–10%'
    WHEN discount_applied < 0.15 THEN '10–15%'
    WHEN discount_applied < 0.20 THEN '15–20%'
    WHEN discount_applied < 0.25 THEN '20–25%'
    WHEN discount_applied < 0.30 THEN '25–30%'
    ELSE '30%+'
  END AS discount_bucket,
  SUM(impressions) AS total_impressions,
  SUM(clicks) AS total_clicks,
  SUM(units_sold) AS total_units_sold,
  SUM(revenue) AS total_revenue,
  ROUND(SUM(clicks)::NUMERIC / NULLIF(SUM(impressions), 0), 4) AS click_through_rate,
  ROUND(SUM(units_sold)::NUMERIC / NULLIF(SUM(clicks), 0), 4) AS conversion_rate
FROM transactions
GROUP BY region, category, discount_bucket;

-- Discount vs. Revenue Correlation

SELECT 
    ROUND(CORR(discount_applied, revenue)::NUMERIC, 4) AS discount_revenue_correlation
FROM transactions
WHERE discount_applied IS NOT NULL AND revenue IS NOT NULL;

-- Revenue by Discount Bucket

SELECT
  region,
  category,
  CASE 
    WHEN discount_applied < 0.05 THEN '0–5%'
    WHEN discount_applied < 0.10 THEN '5–10%'
    WHEN discount_applied < 0.15 THEN '10–15%'
    WHEN discount_applied < 0.20 THEN '15–20%'
    WHEN discount_applied < 0.25 THEN '20–25%'
    WHEN discount_applied < 0.30 THEN '25–30%'
    ELSE '30%+'
  END AS discount_bucket,
  ROUND(AVG(revenue), 2) AS avg_revenue,
  COUNT(*) AS transactions
FROM transactions
WHERE discount_applied IS NOT NULL AND revenue IS NOT NULL
GROUP BY region, category, discount_bucket
ORDER BY region, category, discount_bucket;

-- Channel-Level Ad Efficiency

SELECT 
    region,
    category,
    ROUND(SUM(ad_spend), 2) AS total_ad_spend,
    ROUND(SUM(revenue), 2) AS total_revenue,
    ROUND(SUM(clicks), 2) AS total_clicks,
    ROUND(SUM(revenue) / NULLIF(SUM(ad_spend), 0), 2) AS revenue_per_pound,
    ROUND(SUM(clicks) / NULLIF(SUM(ad_spend), 0), 2) AS clicks_per_pound,
    ROUND(AVG(ad_ctr), 4) AS avg_ad_ctr,
    ROUND(AVG(ad_cpc), 2) AS avg_ad_cpc
FROM transactions
GROUP BY region, category
ORDER BY revenue_per_pound ASC;

-- Customer Segmentation using RFM Scoring

WITH customer_metrics AS (
  SELECT 
    t.customer_id,
    t.region,
    MAX(t.transaction_date) AS last_purchase,
    COUNT(*) AS frequency,
    SUM(t.revenue) AS total_spent
  FROM transactions t
  GROUP BY t.customer_id, t.region
),
rfm_ranked AS (
  SELECT 
    customer_id,
    region,
    DENSE_RANK() OVER (ORDER BY last_purchase DESC) AS recency_rank,
    DENSE_RANK() OVER (ORDER BY frequency DESC) AS frequency_rank,
    DENSE_RANK() OVER (ORDER BY total_spent DESC) AS monetary_rank
  FROM customer_metrics
)
SELECT *,
       recency_rank + frequency_rank + monetary_rank AS rfm_score
FROM rfm_ranked
ORDER BY rfm_score ASC
LIMIT 100;


-- Weekly ROI Trends by Region

SELECT 
  DATE_TRUNC('week', transaction_date) AS week_start,
  region,
  ROUND(SUM(revenue - ad_spend) / NULLIF(SUM(ad_spend), 0), 2) AS roi,
  ROUND(SUM(revenue), 2) AS total_revenue,
  ROUND(SUM(ad_spend), 2) AS total_ad_spend
FROM transactions
GROUP BY week_start, region
ORDER BY week_start, region;