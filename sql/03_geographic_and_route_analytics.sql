-- ==============================================================================
-- Project: Supply Chain Analytics - Delivery SLA Breach & Concession Diagnostic
-- File: 03_geographic_and_route_analytics.sql
-- Contains:
--   Analysis 3: Geographic Trade Lane Corridor Ranking (Worst Route Matrix)
--   Analysis 4: Intra-State vs Inter-State Route Disparity
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- Analysis 3: Geographic Trade Lane Corridor Ranking (Worst Routes with DENSE_RANK)
-- Ranks Origin State -> Destination State routes by worst SLA breach frequency.
-- ------------------------------------------------------------------------------
WITH route_summary AS (
    SELECT 
        s.seller_state AS origin_state,
        c.customer_state AS destination_state,
        COUNT(DISTINCT o.order_id) AS total_shipments,
        SUM(CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 1 ELSE 0 END) AS overdue_shipments,
        ROUND(AVG(EXTRACT(EPOCH FROM (o.order_delivered_customer_date - o.order_delivered_carrier_date)) / 86400.0), 1) AS avg_carrier_transit_days,
        ROUND(AVG(EXTRACT(EPOCH FROM (o.order_delivered_customer_date - o.order_purchase_timestamp)) / 86400.0), 1) AS avg_total_delivery_days,
        ROUND(AVG(items.freight_value), 2) AS avg_freight_paid
    FROM fact_orders_fulfillment o
    JOIN fact_order_items items ON o.order_id = items.order_id
    JOIN dim_sellers s ON items.seller_id = s.seller_id
    JOIN dim_customers c ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
    GROUP BY s.seller_state, c.customer_state
    HAVING COUNT(DISTINCT o.order_id) >= 100 -- Filter for active commercial corridors
)
SELECT 
    origin_state,
    destination_state,
    total_shipments,
    overdue_shipments,
    ROUND((overdue_shipments::NUMERIC / total_shipments) * 100, 2) AS route_breach_rate_pct,
    avg_carrier_transit_days,
    avg_total_delivery_days,
    avg_freight_paid,
    -- Rank routes by highest failure rate using DENSE_RANK Window function
    DENSE_RANK() OVER (ORDER BY (overdue_shipments::NUMERIC / total_shipments) DESC) AS worst_route_rank
FROM route_summary
ORDER BY worst_route_rank ASC
LIMIT 15;


-- ------------------------------------------------------------------------------
-- Analysis 4: Intra-State vs Inter-State Route Disparity
-- Quantifies the performance collapse when packages cross state borders.
-- ------------------------------------------------------------------------------
SELECT 
    CASE 
        WHEN s.seller_state = c.customer_state THEN 'Intra-State (Same State)' 
        ELSE 'Inter-State (Cross-Country)' 
    END AS trade_lane_type,
    COUNT(DISTINCT o.order_id) AS total_orders,
    SUM(CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 1 ELSE 0 END) AS breached_orders,
    ROUND(
        (SUM(CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 1 ELSE 0 END)::NUMERIC / COUNT(DISTINCT o.order_id)) * 100, 
        2
    ) AS sla_breach_rate_pct,
    ROUND(AVG(EXTRACT(EPOCH FROM (o.order_delivered_customer_date - o.order_delivered_carrier_date)) / 86400.0), 2) AS avg_carrier_transit_days,
    ROUND(AVG(items.freight_value), 2) AS avg_freight_cost
FROM fact_orders_fulfillment o
JOIN fact_order_items items ON o.order_id = items.order_id
JOIN dim_sellers s ON items.seller_id = s.seller_id
JOIN dim_customers c ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
GROUP BY CASE WHEN s.seller_state = c.customer_state THEN 'Intra-State (Same State)' ELSE 'Inter-State (Cross-Country)' END;
