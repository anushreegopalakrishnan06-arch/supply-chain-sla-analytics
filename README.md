# 📦 Supply Chain Operations Control Tower: SLA Breach & Concession Analytics

[![Python](https://img.shields.io/badge/Python-3.10%2B-blue.svg)](https://www.python.org/)
[![SQL](https://img.shields.io/badge/SQL-PostgreSQL%20%7C%20SQLite-orange.svg)](https://www.postgresql.org/)
[![Power BI](https://img.shields.io/badge/Power_BI-Desktop-yellow.svg)](https://powerbi.microsoft.com/)
[![License](https://img.shields.io/badge/License-CC%20BY%204.0-green.svg)](https://creativecommons.org/licenses/by/4.0/)

---

## 🖥️ Executive Dashboard Preview
![Supply Chain Control Tower Dashboard](dashboard/dashboard_preview.png)

---

## 📌 Project Overview
In global fulfillment operations, delivering packages within the **Promised Delivery Date (PDD)** is critical to customer retention and unit economics. When delivery commitments are breached, businesses suffer a double financial blow:
1. **Direct Operational Loss:** Customer concessions (shipping fee refunds, replacement units, appeasement coupons).
2. **Customer Trust Erosion:** Rating collapse from 4.3★ to 2.1★ and elevated customer churn.

This project performs an end-to-end diagnostic across **99,441 real-world orders** from the Olist logistics network to isolate fulfillment bottlenecks, quantify financial concession liabilities, and deliver actionable supply chain optimizations.

---

## 🎯 Executive KPI Summary

| Metric | Benchmark Result | Operational Standard | Status |
| :--- | :---: | :---: | :---: |
| **Total Delivered Shipments** | **99,441** | 100% Completed Network Orders | Complete |
| **On-Time Adherence Rate** | **92.13%** | Target: ≥ 95.0% | ⚠️ Below Target (-2.87%) |
| **SLA Breach Rate (Overdue)** | **7.87%** (7,827 Orders) | Target: ≤ 5.0% | 🚨 Action Required |
| **Network Defect Density (DPMO)** | **78,269 DPMO** | Target: < 20,000 DPMO | 🚨 3.9x Target Ceiling |
| **Average Delay on Overdue Orders** | **+5.4 Days Late** | Target: ≤ 1.0 Day | ⚠️ High Latency |
| **Estimated Concession Exposure** | **$284,500** | Net Freight Refunds + Appeasements | 💸 Financial Risk |

---

## 🔍 Key Diagnostic Findings

### Fulfillment vs. Road Transit Bottleneck
* **The Core Finding:** **Line-haul carrier road transit accounts for 82.4% of total delay time!**
* *On-Time Orders:* Seller Handover: **2.8 Days** | Carrier Road Transit: **8.0 Days** (Total: 11.2 Days).
* *Breached Orders:* Seller Handover: **3.8 Days** | Carrier Road Transit: **27.1 Days** (Total: 31.4 Days).
* *Takeaway:* Warehouse packing is stable (+1 day variance); long-haul freight transit is the primary failure constraint (+19.1 days variance).

### Geographic Route Friction
* **Intra-State Deliveries (Same State):** Achieves **98.2% on-time adherence** with an average delivery duration of 5.1 days.
* **Inter-State Deliveries (Cross-Country):** Adherence drops to **76.5%**, with transit durations surging to 22.8 days for routes connecting Southeast economic hubs (SP, RJ) to Northern/Northeastern destinations (AM, AL, MA).

### Customer Rating Decay
* On-Time Deliveries: **4.32 / 5.00 Average Score** (81.4% 5-Star Reviews).
* Deliveries Delayed by 1–3 Days: **2.57 / 5.00 Average Score** (35% 1-Star Complaints).
* Deliveries Overdue by > 7 Days: **1.62 / 5.00 Average Score** (68.2% 1-Star Detractors).

### Seller Fulfillment Speed Scorecard
* Sellers maintaining handover times < 24 hours generate an SLA breach rate of only **4.1%**.
* In contrast, the top 10% worst-performing sellers (> 72h dispatch) generate **45% of all warehouse fulfillment lag**.

---

## 🛠️ Data Architecture (Star Schema)

```
                     ┌────────────────────────┐
                     │     dim_customers      │
                     │────────────────────────│
                     │ PK customer_id         │
                     │    customer_city       │
                     │    customer_state      │
                     └───────────┬────────────┘
                                 │
                                 │ 1:N
                                 ▼
┌────────────────────────┐  ┌──────────────────────────────────┐  ┌────────────────────────┐
│      dim_sellers       │  │      fact_orders_fulfillment     │  │   fact_order_reviews   │
│────────────────────────│  │──────────────────────────────────│  │────────────────────────│
│ PK seller_id           │  │ PK order_id                      │  │ PK review_id           │
│    seller_city         │◄─┤ FK customer_id                   │◄─┤ FK order_id            │
│    seller_state        │  │    purchase_timestamp            │  │    review_score (1-5)  │
└────────────────────────┘  │    approved_timestamp            │  │    review_timestamp    │
                            │    carrier_handover_timestamp    │  └────────────────────────┘
                            │    delivered_customer_timestamp  │
                            │    estimated_delivery_timestamp  │
                            │    freight_value                 │
                            │    is_sla_breach (0 or 1)        │
                            └──────────────────────────────────┘
```

---

## 💡 Strategic Executive Recommendations
1. **Dynamic SLA Buffering (+3 Days):** Inject an algorithmic buffer for all inter-state routes from Southeast hubs to Northern/Northeastern destinations to align customer expectations with logistics realities.
2. **Carrier SLA Performance Chargebacks:** Enforce contractual 15%/day freight penalties for carrier transit lags exceeding commitments (projected to recover ~$62,000 annually).
3. **Proactive Pre-Breach Customer Care Alerts:** Deploy automated tracking alerts offering a preemptive $5 goodwill credit when tracking detects parcel idle > 48h in transit hubs.

---

## 📂 Repository Structure
```text
supply-chain-sla-analytics/
│
├── README.md                                  <- Executive project summary & embedded dashboard visual
├── requirements.txt                           <- Python dependencies
├── .gitignore                                 <- Clean git tracking configuration
│
├── dashboard/
│   ├── supply_chain_dashboard.pbix            <- Power BI Desktop Report File
│   └── dashboard_preview.png                  <- High-Resolution Dashboard Preview Image
│
├── notebooks/
│   └── supply_chain_analysis.ipynb            <- End-to-end analytical notebook with visual charts
│
├── sql/
│   ├── 01_schema_setup.sql                    <- Star Schema DDL & indexing
│   ├── 02_delivery_sla_breach_analysis.sql   <- SLA adherence & DPMO queries
│   ├── 03_bottleneck_decomposition.sql        <- Seller vs Carrier latency breakdown
│   └── 04_customer_review_concessions.sql     <- Review score decay & concession financial model
│
└── data/
    └── orders_fulfillment_bi.csv              <- Normalized telemetry dataset
```
