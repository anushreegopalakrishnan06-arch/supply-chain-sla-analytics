-- ==============================================================================
-- Project: Supply Chain Analytics - Delivery SLA Breach & Customer Concession
-- File: 02_delivery_sla_breach_analysis.sql
-- Description: Measures network-wide SLA compliance, defect rates (DPMO), and 
--              seasonal delivery variance.
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- Query 1: Network-Wide Delivery SLA Adherence & DPMO
-- ------------------------------------------------------------------------------
WITH delivery_metrics AS (
    SELECT 
        order_id,
        order_status,
        order_purchase_timestamp,
        order_delivered_customer_date,
        order_estimated_delivery_date,
        -- Exact delivery duration vs estimated duration in days
        ROUND(EXTRACT(EPOCH FROM (order_delivered_customer_date - order_purchase_timestamp)) / 86400.0, 2) AS actual_delivery_days,
        ROUND(EXTRACT(EPOCH FROM (order_estimated_delivery_date - order_purchase_timestamp)) / 86400.0, 2) AS estimated_delivery_days,
        -- SLA Breach Flag (1 if actual delivery exceeded estimated delivery date)
        CASE 
            WHEN order_delivered_customer_date > order_estimated_delivery_date THEN 1 
            ELSE 0 
        END AS is_sla_breached,
        -- Variance: Positive = Delayed, Negative = Early
        ROUND(EXTRACT(EPOCH FROM (order_delivered_customer_date - order_estimated_delivery_date)) / 86400.0, 2) AS delivery_variance_days
    FROM fact_orders_fulfillment
    WHERE order_status = 'delivered'
      AND order_delivered_customer_date IS NOT NULL
      AND order_estimated_delivery_date IS NOT NULL
)
SELECT 
    COUNT(order_id) AS total_delivered_orders,
    SUM(CASE WHEN is_sla_breached = 0 THEN 1 ELSE 0 END) AS on_time_orders,
    SUM(is_sla_breached) AS breached_orders,
    -- SLA Breach Percentage
    ROUND((SUM(is_sla_breached)::NUMERIC / COUNT(order_id)) * 100, 2) AS sla_breach_rate_pct,
    -- On-Time Adherence Percentage
    ROUND((1 - (SUM(is_sla_breached)::NUMERIC / COUNT(order_id))) * 100, 2) AS on_time_adherence_pct,
    -- Defects Per Million Opportunities (DPMO - Amazon Operational Standard)
    ROUND((SUM(is_sla_breached)::NUMERIC / COUNT(order_id)) * 1000000, 0) AS network_dpmo,
    -- Latency Benchmarks
    ROUND(AVG(actual_delivery_days), 2) AS avg_actual_delivery_days,
    ROUND(AVG(CASE WHEN is_sla_breached = 0 THEN actual_delivery_days END), 2) AS avg_days_when_ontime,
    ROUND(AVG(CASE WHEN is_sla_breached = 1 THEN actual_delivery_days END), 2) AS avg_days_when_breached,
    ROUND(AVG(CASE WHEN is_sla_breached = 1 THEN delivery_variance_days END), 2) AS avg_days_overdue
FROM delivery_metrics;


-- ------------------------------------------------------------------------------
-- Query 2: Monthly SLA Breach Trend & Peak Seasonality
-- ------------------------------------------------------------------------------
SELECT 
    TO_CHAR(order_purchase_timestamp, 'YYYY-MM') AS order_month,
    COUNT(order_id) AS monthly_orders,
    SUM(CASE WHEN order_delivered_customer_date > order_estimated_delivery_date THEN 1 ELSE 0 END) AS late_orders,
    ROUND(
        (SUM(CASE WHEN order_delivered_customer_date > order_estimated_delivery_date THEN 1 ELSE 0 END)::NUMERIC / COUNT(order_id)) * 100, 
        2
    ) AS monthly_breach_rate_pct,
    -- Trailing 3-Month Moving Average of Breach Rate using Window Function
    ROUND(
        AVG((SUM(CASE WHEN order_delivered_customer_date > order_estimated_delivery_date THEN 1 ELSE 0 END)::NUMERIC / COUNT(order_id)) * 100) 
        OVER (ORDER BY TO_CHAR(order_purchase_timestamp, 'YYYY-MM') ROWS BETWEEN 2 PRECEDING AND CURRENT ROW),
        2
    ) AS rolling_3mo_avg_breach_rate
FROM fact_orders_fulfillment
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
GROUP BY TO_CHAR(order_purchase_timestamp, 'YYYY-MM')
ORDER BY order_month ASC;
