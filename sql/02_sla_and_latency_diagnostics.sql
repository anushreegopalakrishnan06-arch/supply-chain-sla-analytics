-- ==============================================================================
-- Project: Supply Chain Analytics - Delivery SLA Breach & Concession Diagnostic
-- File: 02_sla_and_latency_diagnostics.sql
-- Contains:
--   Analysis 1: Network SLA Compliance & Defect Density (DPMO)
--   Analysis 2: Multi-Stage Fulfillment Latency Decomposition
--   Analysis 8: Day-of-Week & Weekend Dispatch Efficiency
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- Analysis 1: Network SLA Compliance & Defect Density (DPMO)
-- Evaluates Promised Delivery Date (PDD) vs Actual Delivery Date across network.
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
        -- SLA Breach Flag (1 = Breached/Late, 0 = On-Time/Early)
        CASE 
            WHEN order_delivered_customer_date > order_estimated_delivery_date THEN 1 
            ELSE 0 
        END AS is_sla_breached,
        ROUND(EXTRACT(EPOCH FROM (order_delivered_customer_date - order_estimated_delivery_date)) / 86400.0, 2) AS variance_days
    FROM fact_orders_fulfillment
    WHERE order_status = 'delivered'
      AND order_delivered_customer_date IS NOT NULL
      AND order_estimated_delivery_date IS NOT NULL
)
SELECT 
    COUNT(order_id) AS total_delivered_orders,
    SUM(CASE WHEN is_sla_breached = 0 THEN 1 ELSE 0 END) AS on_time_orders,
    SUM(is_sla_breached) AS breached_orders,
    ROUND((SUM(is_sla_breached)::NUMERIC / COUNT(order_id)) * 100, 2) AS sla_breach_rate_pct,
    ROUND((1 - (SUM(is_sla_breached)::NUMERIC / COUNT(order_id))) * 100, 2) AS on_time_adherence_pct,
    -- Network DPMO (Defects Per Million Opportunities)
    ROUND((SUM(is_sla_breached)::NUMERIC / COUNT(order_id)) * 1000000, 0) AS network_dpmo,
    ROUND(AVG(actual_delivery_days), 2) AS avg_delivery_days,
    ROUND(AVG(CASE WHEN is_sla_breached = 1 THEN variance_days END), 2) AS avg_days_overdue
FROM delivery_metrics;


-- ------------------------------------------------------------------------------
-- Analysis 2: Multi-Stage Fulfillment Latency Decomposition
-- Isolates Approval Lag, Seller Warehouse Dispatch Lag, and Carrier Road Transit Lag.
-- ------------------------------------------------------------------------------
WITH stage_durations AS (
    SELECT 
        order_id,
        CASE 
            WHEN order_delivered_customer_date > order_estimated_delivery_date THEN 'SLA Breached' 
            ELSE 'On-Time' 
        END AS performance_status,
        -- Stage 1: Payment to Order Approval
        ROUND(EXTRACT(EPOCH FROM (order_approved_at - order_purchase_timestamp)) / 86400.0, 2) AS approval_lag_days,
        -- Stage 2: Seller Warehouse Dispatch (Packing & Courier Handover)
        ROUND(EXTRACT(EPOCH FROM (order_delivered_carrier_date - order_approved_at)) / 86400.0, 2) AS seller_dispatch_days,
        -- Stage 3: Carrier Line-Haul Transit (Courier Road Transport to Doorstep)
        ROUND(EXTRACT(EPOCH FROM (order_delivered_customer_date - order_delivered_carrier_date)) / 86400.0, 2) AS carrier_transit_days,
        -- Total End-to-End Delivery Duration
        ROUND(EXTRACT(EPOCH FROM (order_delivered_customer_date - order_purchase_timestamp)) / 86400.0, 2) AS total_delivery_days
    FROM fact_orders_fulfillment
    WHERE order_status = 'delivered'
      AND order_approved_at IS NOT NULL
      AND order_delivered_carrier_date IS NOT NULL
      AND order_delivered_customer_date IS NOT NULL
)
SELECT 
    performance_status,
    COUNT(order_id) AS order_count,
    ROUND(AVG(approval_lag_days), 2) AS avg_approval_lag,
    ROUND(AVG(seller_dispatch_days), 2) AS avg_seller_dispatch,
    ROUND(AVG(carrier_transit_days), 2) AS avg_carrier_transit,
    ROUND(AVG(total_delivery_days), 2) AS avg_total_delivery,
    -- Carrier Share of Total Latency (%)
    ROUND((AVG(carrier_transit_days) / NULLIF(AVG(total_delivery_days), 0)) * 100, 1) AS carrier_transit_share_pct
FROM stage_durations
GROUP BY performance_status;


-- ------------------------------------------------------------------------------
-- Analysis 8: Day-of-Week & Weekend Dispatch Efficiency
-- Measures if weekend orders suffer warehouse dispatch bottlenecks compared to weekdays.
-- ------------------------------------------------------------------------------
SELECT 
    TO_CHAR(order_purchase_timestamp, 'Day') AS purchase_day_of_week,
    EXTRACT(ISODOW FROM order_purchase_timestamp) AS day_number,
    COUNT(order_id) AS total_orders,
    ROUND(AVG(EXTRACT(EPOCH FROM (order_delivered_carrier_date - order_approved_at)) / 86400.0), 2) AS avg_seller_dispatch_days,
    ROUND(
        (SUM(CASE WHEN order_delivered_customer_date > order_estimated_delivery_date THEN 1 ELSE 0 END)::NUMERIC / COUNT(order_id)) * 100, 
        2
    ) AS sla_breach_rate_pct
FROM fact_orders_fulfillment
WHERE order_status = 'delivered'
  AND order_delivered_carrier_date IS NOT NULL
GROUP BY TO_CHAR(order_purchase_timestamp, 'Day'), EXTRACT(ISODOW FROM order_purchase_timestamp)
ORDER BY day_number ASC;
