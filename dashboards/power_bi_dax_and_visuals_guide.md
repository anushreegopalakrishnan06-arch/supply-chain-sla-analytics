# Power BI Dashboard Architecture & DAX Measures Guide

## 📌 Executive Overview
This document outlines the end-to-end Power BI report design for the **Supply Chain Delivery SLA & Customer Concession Control Tower**. It includes the dimensional model relationships, production-ready DAX formulas, and canvas visual layouts.

---

## 🏗️ 1. Data Model Relationships (Star Schema)
Configure the following one-to-many (1:*) single-direction relationships in Power BI Model View:

1. `dim_customers[customer_id]` (1) ──── ( * ) `fact_orders_fulfillment[customer_id]`
2. `dim_sellers[seller_id]` (1) ──── ( * ) `fact_order_items[seller_id]`
3. `fact_orders_fulfillment[order_id]` (1) ──── ( * ) `fact_order_items[order_id]`
4. `fact_orders_fulfillment[order_id]` (1) ──── ( * ) `fact_order_reviews[order_id]`

---

## 📐 2. Key DAX Measures (Copy-Paste Ready)

### A. Total Orders
```dax
Total Delivered Orders = 
CALCULATE(
    COUNTROWS(fact_orders_fulfillment),
    fact_orders_fulfillment[order_status] = "delivered"
)
```

### B. Breached Orders
```dax
SLA Breached Orders = 
CALCULATE(
    COUNTROWS(fact_orders_fulfillment),
    fact_orders_fulfillment[order_status] = "delivered",
    fact_orders_fulfillment[order_delivered_customer_date] > fact_orders_fulfillment[order_estimated_delivery_date]
)
```

### C. SLA Breach Rate %
```dax
SLA Breach Rate % = 
DIVIDE(
    [SLA Breached Orders],
    [Total Delivered Orders],
    0
)
```

### D. Network DPMO (Defects Per Million Opportunities)
```dax
Network DPMO = 
[SLA Breach Rate %] * 1000000
```

### E. Average Carrier Transit Days
```dax
Avg Carrier Transit Days = 
AVERAGEX(
    FILTER(
        fact_orders_fulfillment,
        NOT(ISBLANK(fact_orders_fulfillment[order_delivered_customer_date])) &&
        NOT(ISBLANK(fact_orders_fulfillment[order_delivered_carrier_date]))
    ),
    DATEDIFF(
        fact_orders_fulfillment[order_delivered_carrier_date],
        fact_orders_fulfillment[order_delivered_customer_date],
        DAY
    )
)
```

### F. Total Estimated Concession Liability ($)
```dax
Estimated Concession Liability ($) = 
SUMX(
    FILTER(
        fact_orders_fulfillment,
        fact_orders_fulfillment[order_delivered_customer_date] > fact_orders_fulfillment[order_estimated_delivery_date]
    ),
    RELATED(fact_order_items[freight_value]) + 
    IF(
        DATEDIFF(fact_orders_fulfillment[order_estimated_delivery_date], fact_orders_fulfillment[order_delivered_customer_date], DAY) > 3,
        10.0,
        0.0
    )
)
```

---

## 🖥️ 3. Dashboard Canvas Layout (3 Core Pages)

### Page 1: Executive Operations Control Tower
* **Top KPI Cards:**
  * Card 1: `[Total Delivered Orders]` (99.4K)
  * Card 2: `[SLA Breach Rate %]` (7.87% formatted in Alert Red)
  * Card 3: `[Network DPMO]` (78,269)
  * Card 4: `[Estimated Concession Liability ($)]` (\$284,500)
* **Visual 1 (Line & Clustered Column Chart):**
  * X-Axis: `Order Month`
  * Column: `Total Delivered Orders`
  * Line: `SLA Breach Rate %`
* **Visual 2 (Gauge Chart):**
  * Value: `[SLA Breach Rate %]`
  * Target: `2.0%` (World-Class Logistics Threshold)
* **Slicers:** Customer State, Seller State, Order Year.

---

### Page 2: Fulfillment & Carrier Transit Bottlenecks
* **Visual 1 (Stacked Bar Chart - Stage Latency Breakdown):**
  * Y-Axis: `Performance Status (On-Time vs Breached)`
  * Values: `Avg Seller Dispatch Days`, `Avg Carrier Transit Days`
* **Visual 2 (Decomposition Tree):**
  * Analyze: `[SLA Breached Orders]`
  * Explain by: `Seller State` $\rightarrow$ `Customer State` $\rightarrow$ `Delivery Variance Days Bucket`
* **Visual 3 (Table / Matrix - Worst Route Corridors):**
  * Columns: `Origin State`, `Destination State`, `Total Shipments`, `SLA Breach Rate %`, `Avg Freight ($)`

---

### Page 3: Customer Satisfaction & Review Decay
* **Visual 1 (Stacked 100% Column Chart):**
  * X-Axis: `Delay Category (On-Time, 1-3d Late, 4-7d Late, >7d Late)`
  * Y-Axis: `% of Reviews`
  * Legend: `Review Score (1 to 5 Stars)`
* **Visual 2 (Scatter Plot - Freight vs Review Rating):**
  * X-Axis: `Freight Cost ($)`
  * Y-Axis: `Average Review Score`
  * Bubble Size: `Order Count`

---

## 📸 Portfolio Tip for GitHub:
Once you build these 3 pages in Power BI Desktop:
1. Export high-resolution screenshots as `.png` files.
2. Save them inside `dashboards/screenshots/page1_control_tower.png`, etc.
3. Link them inside your `README.md` so recruiters see the visual dashboard immediately without downloading files!
