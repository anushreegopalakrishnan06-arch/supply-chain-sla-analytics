-- ==============================================================================
-- Project: Supply Chain Analytics - Delivery SLA Breach & Customer Concession
-- File: 03_bottleneck_decomposition.sql
-- Description: Decomposes the fulfillment lifecycle into Seller Lag vs Carrier Transit 
--              Lag, and isolates geographic route bottlenecks.
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- Query 1: Lifecycle Stage Latency Breakdown (Seller vs Carrier)
-- ------------------------------------------------------------------------------
WITH stage_durations AS (
    SELECT 
        order_id,
        CASE 
            WHEN order_delivered_customer_date > order_estimated_delivery_date THEN 'Breached SLA' 
            ELSE 'On-Time' 
        END AS delivery_performance,
        -- Stage 1: Order Approval Duration (Purchase -> Approval)
        ROUND(EXTRACT(EPOCH FROM (order_approved_at - order_purchase_timestamp)) / 86400.0, 2) AS approval_lag_days,
        -- Stage 2: Seller Dispatch Duration (Approval -> Handover to Carrier)
        ROUND(EXTRACT(EPOCH FROM (order_delivered_carrier_date - order_approved_at)) / 86400.0, 2) AS seller_dispatch_lag_days,
        -- Stage 3: Carrier Transit Duration (Carrier Handover -> Doorstep Delivery)
        ROUND(EXTRACT(EPOCH FROM (order_delivered_customer_date - order_delivered_carrier_date)) / 86400.0, 2) AS carrier_transit_lag_days,
        -- Total End-to-End Duration
        ROUND(EXTRACT(EPOCH FROM (order_delivered_customer_date - order_purchase_timestamp)) / 86400.0, 2) AS total_delivery_days
    FROM fact_orders_fulfillment
    WHERE order_status = 'delivered'
      AND order_approved_at IS NOT NULL
      AND order_delivered_carrier_date IS NOT NULL
      AND order_delivered_customer_date IS NOT NULL
)
SELECT 
    delivery_performance,
    COUNT(order_id) AS order_count,
    ROUND(AVG(approval_lag_days), 2) AS avg_approval_lag_days,
    ROUND(AVG(seller_dispatch_lag_days), 2) AS avg_seller_dispatch_days,
    ROUND(AVG(carrier_transit_lag_days), 2) AS avg_carrier_transit_days,
    ROUND(AVG(total_delivery_days), 2) AS avg_total_delivery_days,
    -- Percentage of total delivery time consumed by Carrier Transit
    ROUND((AVG(carrier_transit_lag_days) / NULLIF(AVG(total_delivery_days), 0)) * 100, 1) AS carrier_transit_share_pct
FROM stage_durations
GROUP BY delivery_performance;


-- ------------------------------------------------------------------------------
-- Query 2: Origin State -> Destination State Route Bottlenecks
-- ------------------------------------------------------------------------------
WITH route_performance AS (
    SELECT 
        s.seller_state AS origin_state,
        c.customer_state AS dest_state,
        COUNT(DISTINCT o.order_id) AS total_shipments,
        SUM(CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 1 ELSE 0 END) AS late_shipments,
        ROUND(
            AVG(EXTRACT(EPOCH FROM (o.order_delivered_customer_date - o.order_delivered_carrier_date)) / 86400.0), 
            1
        ) AS avg_carrier_transit_days,
        ROUND(
            AVG(EXTRACT(EPOCH FROM (o.order_delivered_customer_date - o.order_purchase_timestamp)) / 86400.0), 
            1
        ) AS avg_total_delivery_days,
        ROUND(AVG(items.freight_value), 2) AS avg_freight_cost
    FROM fact_orders_fulfillment o
    JOIN fact_order_items items ON o.order_id = items.order_id
    JOIN dim_sellers s ON items.seller_id = s.seller_id
    JOIN dim_customers c ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
    GROUP BY s.seller_state, c.customer_state
    HAVING COUNT(DISTINCT o.order_id) >= 100 -- Focus on high-volume active trade lanes
)
SELECT 
    origin_state,
    dest_state,
    total_shipments,
    late_shipments,
    ROUND((late_shipments::NUMERIC / total_shipments) * 100, 2) AS route_breach_rate_pct,
    avg_carrier_transit_days,
    avg_total_delivery_days,
    avg_freight_cost,
    -- Rank routes by worst SLA breach rate using DENSE_RANK Window function
    DENSE_RANK() OVER (ORDER BY (late_shipments::NUMERIC / total_shipments) DESC) AS worst_route_rank
FROM route_performance
ORDER BY route_breach_rate_pct DESC
LIMIT 15;
