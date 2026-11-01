-- ==============================================================================
-- Project: Supply Chain Analytics - Delivery SLA Breach & Concession Diagnostic
-- File: 04_seller_and_freight_segmentation.sql
-- Contains:
--   Analysis 5: Seller Fulfillment Speed & Tiering Scorecard
--   Analysis 6: Freight Cost & Weight Tier Sensitivity (NTILE Bucketing)
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- Analysis 5: Seller Fulfillment Speed & Tiering Scorecard
-- Segments sellers into performance tiers based on warehouse packing velocity.
-- ------------------------------------------------------------------------------
WITH seller_metrics AS (
    SELECT 
        items.seller_id,
        COUNT(DISTINCT o.order_id) AS total_orders_handled,
        ROUND(AVG(EXTRACT(EPOCH FROM (o.order_delivered_carrier_date - o.order_approved_at)) / 86400.0), 2) AS avg_seller_dispatch_days,
        ROUND(
            (SUM(CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 1 ELSE 0 END)::NUMERIC / COUNT(DISTINCT o.order_id)) * 100, 
            2
        ) AS seller_sla_breach_rate_pct
    FROM fact_orders_fulfillment o
    JOIN fact_order_items items ON o.order_id = items.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_carrier_date IS NOT NULL
      AND o.order_approved_at IS NOT NULL
    GROUP BY items.seller_id
    HAVING COUNT(DISTINCT o.order_id) >= 30 -- Statistically significant sellers
),
tiered_sellers AS (
    SELECT 
        seller_id,
        total_orders_handled,
        avg_seller_dispatch_days,
        seller_sla_breach_rate_pct,
        CASE 
            WHEN avg_seller_dispatch_days <= 1.0 THEN 'Tier 1: Gold (< 24h Handover)'
            WHEN avg_seller_dispatch_days <= 3.0 THEN 'Tier 2: Silver (24h - 72h Handover)'
            ELSE 'Tier 3: At-Risk (> 72h Handover)'
        END AS seller_tier
    FROM seller_metrics
)
SELECT 
    seller_tier,
    COUNT(seller_id) AS total_sellers,
    SUM(total_orders_handled) AS total_orders_fulfilled,
    ROUND(AVG(avg_seller_dispatch_days), 2) AS group_avg_dispatch_days,
    ROUND(AVG(seller_sla_breach_rate_pct), 2) AS group_avg_breach_rate_pct
FROM tiered_sellers
GROUP BY seller_tier
ORDER BY group_avg_dispatch_days ASC;


-- ------------------------------------------------------------------------------
-- Analysis 6: Freight Cost & Weight Tier Sensitivity (Quantile NTILE Bucketing)
-- Measures if bulky/heavy high-freight items experience line-haul bottlenecks.
-- ------------------------------------------------------------------------------
WITH order_freight_ranked AS (
    SELECT 
        o.order_id,
        o.order_delivered_customer_date,
        o.order_estimated_delivery_date,
        o.order_delivered_carrier_date,
        items.freight_value,
        -- Divide orders into 3 freight tiers using NTILE Window Function
        NTILE(3) OVER (ORDER BY items.freight_value ASC) AS freight_ntile
    FROM fact_orders_fulfillment o
    JOIN fact_order_items items ON o.order_id = items.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
)
SELECT 
    CASE 
        WHEN freight_ntile = 1 THEN 'Low Freight Tier (Bottom 33%)'
        WHEN freight_ntile = 2 THEN 'Medium Freight Tier (Middle 33%)'
        ELSE 'High Freight / Heavy Cargo Tier (Top 33%)'
    END AS freight_category,
    COUNT(order_id) AS total_shipments,
    ROUND(MIN(freight_value), 2) AS min_freight_usd,
    ROUND(MAX(freight_value), 2) AS max_freight_usd,
    ROUND(AVG(freight_value), 2) AS avg_freight_usd,
    ROUND(AVG(EXTRACT(EPOCH FROM (order_delivered_customer_date - order_delivered_carrier_date)) / 86400.0), 2) AS avg_carrier_transit_days,
    ROUND(
        (SUM(CASE WHEN order_delivered_customer_date > order_estimated_delivery_date THEN 1 ELSE 0 END)::NUMERIC / COUNT(order_id)) * 100, 
        2
    ) AS sla_breach_rate_pct
FROM order_freight_ranked
GROUP BY freight_ntile
ORDER BY freight_ntile ASC;
