-- ==============================================================================
-- Project: Supply Chain Analytics - Delivery SLA Breach & Customer Concession
-- File: 04_customer_review_concessions.sql
-- Description: Quantifies customer satisfaction collapse (Review Decay) and models
--              financial loss from freight refunds and appeasement concessions.
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- Query 1: Delivery Delay vs Customer Review Score Decay
-- ------------------------------------------------------------------------------
WITH order_delay_buckets AS (
    SELECT 
        o.order_id,
        r.review_score,
        ROUND(EXTRACT(EPOCH FROM (o.order_delivered_customer_date - o.order_estimated_delivery_date)) / 86400.0, 1) AS delay_days,
        CASE 
            WHEN o.order_delivered_customer_date <= o.order_estimated_delivery_date THEN '01. On-Time / Early'
            WHEN EXTRACT(EPOCH FROM (o.order_delivered_customer_date - o.order_estimated_delivery_date)) / 86400.0 BETWEEN 0.01 AND 3.0 THEN '02. Minor Delay (1-3 Days)'
            WHEN EXTRACT(EPOCH FROM (o.order_delivered_customer_date - o.order_estimated_delivery_date)) / 86400.0 BETWEEN 3.01 AND 7.0 THEN '03. Moderate Delay (4-7 Days)'
            ELSE '04. Severe Delay (> 7 Days Late)'
        END AS delay_severity_bucket
    FROM fact_orders_fulfillment o
    JOIN fact_order_reviews r ON o.order_id = r.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_estimated_delivery_date IS NOT NULL
)
SELECT 
    delay_severity_bucket,
    COUNT(order_id) AS total_reviewed_orders,
    ROUND(AVG(review_score), 2) AS avg_review_score,
    -- 1-Star Review Rate (Customer Detractor Indicator)
    SUM(CASE WHEN review_score = 1 THEN 1 ELSE 0 END) AS count_1_star_reviews,
    ROUND((SUM(CASE WHEN review_score = 1 THEN 1 ELSE 0 END)::NUMERIC / COUNT(order_id)) * 100, 2) AS pct_1_star_reviews,
    -- 5-Star Review Rate (Customer Promoter Indicator)
    SUM(CASE WHEN review_score = 5 THEN 1 ELSE 0 END) AS count_5_star_reviews,
    ROUND((SUM(CASE WHEN review_score = 5 THEN 1 ELSE 0 END)::NUMERIC / COUNT(order_id)) * 100, 2) AS pct_5_star_reviews
FROM order_delay_buckets
GROUP BY delay_severity_bucket
ORDER BY delay_severity_bucket ASC;


-- ------------------------------------------------------------------------------
-- Query 2: Financial Concession & Revenue Leakage Model
-- ------------------------------------------------------------------------------
-- Business Scenario: Company policy guarantees full shipping fee refund on breached 
-- SLA + $10 goodwill appeasement credit for severely delayed deliveries (> 3 days).
WITH order_freight_summary AS (
    SELECT 
        o.order_id,
        o.order_delivered_customer_date,
        o.order_estimated_delivery_date,
        SUM(items.freight_value) AS total_freight_paid,
        SUM(items.price) AS total_order_merchandise_value,
        CASE 
            WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 1 
            ELSE 0 
        END AS is_breached,
        ROUND(EXTRACT(EPOCH FROM (o.order_delivered_customer_date - o.order_estimated_delivery_date)) / 86400.0, 1) AS days_late
    FROM fact_orders_fulfillment o
    JOIN fact_order_items items ON o.order_id = items.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
    GROUP BY o.order_id, o.order_delivered_customer_date, o.order_estimated_delivery_date
)
SELECT 
    COUNT(order_id) AS total_network_orders,
    SUM(is_breached) AS total_breached_orders,
    -- Total Revenue Processed
    ROUND(SUM(total_order_merchandise_value), 2) AS total_gmov_usd,
    ROUND(SUM(total_freight_paid), 2) AS total_freight_collected_usd,
    
    -- FINANCIAL EXPOSURE FROM SLA BREACHES:
    -- 1. At-risk Freight Revenue on Breached Orders
    ROUND(SUM(CASE WHEN is_breached = 1 THEN total_freight_paid ELSE 0 END), 2) AS at_risk_freight_loss_usd,
    
    -- 2. Concession Policy: Full freight refund + $10 appeasement on orders > 3 days late
    ROUND(
        SUM(CASE 
            WHEN is_breached = 1 AND days_late > 3.0 THEN total_freight_paid + 10.00
            WHEN is_breached = 1 THEN total_freight_paid
            ELSE 0 
        END), 
        2
    ) AS total_estimated_concession_liability_usd,
    
    -- Concession Cost per Breached Order
    ROUND(
        SUM(CASE 
            WHEN is_breached = 1 AND days_late > 3.0 THEN total_freight_paid + 10.00
            WHEN is_breached = 1 THEN total_freight_paid
            ELSE 0 
        END) / NULLIF(SUM(is_breached), 0),
        2
    ) AS avg_concession_cost_per_breached_order_usd
FROM order_freight_summary;
