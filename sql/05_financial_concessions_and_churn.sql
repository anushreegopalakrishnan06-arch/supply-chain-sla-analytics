-- ==============================================================================
-- Project: Supply Chain Analytics - Delivery SLA Breach & Concession Diagnostic
-- File: 05_financial_concessions_and_churn.sql
-- Contains:
--   Analysis 7: Monthly Seasonality & Trailing 3-Month Rolling Average
--   Analysis 9: Customer Review Decay & 1-Star Detractor Influx
--   Analysis 10: Financial Concession Liability Exposure Model
--   Analysis 11: First-Order Delivery Delay vs Long-Term Customer Churn
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- Analysis 7: Monthly Seasonality & Trailing 3-Month Rolling Average Trend
-- Tracks delivery performance degradation during holiday peak volume surges.
-- ------------------------------------------------------------------------------
WITH monthly_aggregates AS (
    SELECT 
        TO_CHAR(order_purchase_timestamp, 'YYYY-MM') AS order_month,
        COUNT(order_id) AS total_monthly_orders,
        SUM(CASE WHEN order_delivered_customer_date > order_estimated_delivery_date THEN 1 ELSE 0 END) AS monthly_breached_orders
    FROM fact_orders_fulfillment
    WHERE order_status = 'delivered'
      AND order_delivered_customer_date IS NOT NULL
    GROUP BY TO_CHAR(order_purchase_timestamp, 'YYYY-MM')
)
SELECT 
    order_month,
    total_monthly_orders,
    monthly_breached_orders,
    ROUND((monthly_breached_orders::NUMERIC / total_monthly_orders) * 100, 2) AS monthly_breach_rate_pct,
    -- 3-Month Trailing Moving Average using Window Frame
    ROUND(
        AVG((monthly_breached_orders::NUMERIC / total_monthly_orders) * 100) 
        OVER (ORDER BY order_month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW),
        2
    ) AS rolling_3mo_avg_breach_rate_pct
FROM monthly_aggregates
ORDER BY order_month ASC;


-- ------------------------------------------------------------------------------
-- Analysis 9: Customer Review Decay & 1-Star Detractor Influx
-- Models customer rating collapse across delay severity tiers.
-- ------------------------------------------------------------------------------
WITH delay_severity AS (
    SELECT 
        o.order_id,
        r.review_score,
        ROUND(EXTRACT(EPOCH FROM (o.order_delivered_customer_date - o.order_estimated_delivery_date)) / 86400.0, 1) AS delay_days,
        CASE 
            WHEN o.order_delivered_customer_date <= o.order_estimated_delivery_date THEN '01. On-Time / Ahead of Schedule'
            WHEN EXTRACT(EPOCH FROM (o.order_delivered_customer_date - o.order_estimated_delivery_date)) / 86400.0 BETWEEN 0.01 AND 3.0 THEN '02. Minor Delay (1-3 Days Late)'
            WHEN EXTRACT(EPOCH FROM (o.order_delivered_customer_date - o.order_estimated_delivery_date)) / 86400.0 BETWEEN 3.01 AND 7.0 THEN '03. Moderate Delay (4-7 Days Late)'
            ELSE '04. Severe Delay (> 7 Days Late)'
        END AS delay_tier
    FROM fact_orders_fulfillment o
    JOIN fact_order_reviews r ON o.order_id = r.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
)
SELECT 
    delay_tier,
    COUNT(order_id) AS total_reviews_received,
    ROUND(AVG(review_score), 2) AS avg_review_score,
    -- 1-Star Detractor %
    SUM(CASE WHEN review_score = 1 THEN 1 ELSE 0 END) AS count_1_star,
    ROUND((SUM(CASE WHEN review_score = 1 THEN 1 ELSE 0 END)::NUMERIC / COUNT(order_id)) * 100, 2) AS pct_1_star_complaints,
    -- 5-Star Promoter %
    SUM(CASE WHEN review_score = 5 THEN 1 ELSE 0 END) AS count_5_star,
    ROUND((SUM(CASE WHEN review_score = 5 THEN 1 ELSE 0 END)::NUMERIC / COUNT(order_id)) * 100, 2) AS pct_5_star_promoters
FROM delay_severity
GROUP BY delay_tier
ORDER BY delay_tier ASC;


-- ------------------------------------------------------------------------------
-- Analysis 10: Financial Concession Liability Exposure Model
-- Quantifies net freight refund exposure + goodwill compensation liability.
-- ------------------------------------------------------------------------------
WITH order_financials AS (
    SELECT 
        o.order_id,
        o.order_delivered_customer_date,
        o.order_estimated_delivery_date,
        SUM(items.freight_value) AS order_freight_paid,
        SUM(items.price) AS order_item_value,
        CASE 
            WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 1 
            ELSE 0 
        END AS is_breached,
        ROUND(EXTRACT(EPOCH FROM (o.order_delivered_customer_date - o.order_estimated_delivery_date)) / 86400.0, 1) AS days_overdue
    FROM fact_orders_fulfillment o
    JOIN fact_order_items items ON o.order_id = items.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
    GROUP BY o.order_id, o.order_delivered_customer_date, o.order_estimated_delivery_date
)
SELECT 
    COUNT(order_id) AS total_orders,
    SUM(is_breached) AS total_breached_orders,
    ROUND(SUM(order_item_value), 2) AS gross_merchandise_volume_usd,
    ROUND(SUM(order_freight_paid), 2) AS total_freight_collected_usd,
    -- 1. Direct At-Risk Shipping Refund Loss
    ROUND(SUM(CASE WHEN is_breached = 1 THEN order_freight_paid ELSE 0 END), 2) AS direct_freight_refund_loss_usd,
    -- 2. Concession Policy: Full shipping refund + $10 appeasement on severe delays (> 3d late)
    ROUND(
        SUM(CASE 
            WHEN is_breached = 1 AND days_overdue > 3.0 THEN order_freight_paid + 10.00
            WHEN is_breached = 1 THEN order_freight_paid
            ELSE 0 
        END), 
        2
    ) AS total_estimated_concession_liability_usd
FROM order_financials;


-- ------------------------------------------------------------------------------
-- Analysis 11: First-Order Delivery Delay vs Long-Term Customer Churn
-- Measures whether experiencing a late delivery on first purchase destroys repeat purchase probability.
-- ------------------------------------------------------------------------------
WITH customer_order_history AS (
    SELECT 
        c.customer_unique_id,
        o.order_id,
        o.order_purchase_timestamp,
        CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 1 ELSE 0 END AS was_breached,
        -- Identify sequence of orders per customer using ROW_NUMBER
        ROW_NUMBER() OVER (PARTITION BY c.customer_unique_id ORDER BY o.order_purchase_timestamp ASC) AS order_sequence_number
    FROM fact_orders_fulfillment o
    JOIN dim_customers c ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
),
first_order_experience AS (
    SELECT 
        customer_unique_id,
        was_breached AS first_order_was_late
    FROM customer_order_history
    WHERE order_sequence_number = 1
),
repeat_orders AS (
    SELECT 
        customer_unique_id,
        COUNT(order_id) AS total_lifetime_orders,
        CASE WHEN COUNT(order_id) > 1 THEN 1 ELSE 0 END AS is_repeat_customer
    FROM customer_order_history
    GROUP BY customer_unique_id
)
SELECT 
    CASE 
        WHEN f.first_order_was_late = 1 THEN 'First Order Delayed (Breached SLA)' 
        ELSE 'First Order Delivered On-Time' 
    END AS initial_customer_experience,
    COUNT(f.customer_unique_id) AS total_customers,
    SUM(r.is_repeat_customer) AS repeat_customers_retained,
    ROUND((SUM(r.is_repeat_customer)::NUMERIC / COUNT(f.customer_unique_id)) * 100, 2) AS repeat_purchase_rate_pct
FROM first_order_experience f
JOIN repeat_orders r ON f.customer_unique_id = r.customer_unique_id
GROUP BY f.first_order_was_late;
