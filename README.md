# 📦 Enterprise Supply Chain Diagnostic: Delivery SLA Breach, Bottlenecks & Concession Analytics

[![Python](https://img.shields.io/badge/Python-3.10%2B-blue.svg)](https://www.python.org/)
[![SQL](https://img.shields.io/badge/SQL-PostgreSQL%20%7C%20SQLite-orange.svg)](https://www.postgresql.org/)
[![Power BI](https://img.shields.io/badge/Power_BI-Desktop-yellow.svg)](https://powerbi.microsoft.com/)
[![License](https://img.shields.io/badge/License-CC%20BY%204.0-green.svg)](https://creativecommons.org/licenses/by/4.0/)

---

## 📌 Executive Summary
In e-commerce and logistics operations, failing to deliver customer orders within the **Promised Delivery Date (PDD)** triggers a severe double financial penalty: **direct concession losses** (shipping refunds, appeasement credits) and **long-term customer churn** (review decay and customer lifetime value destruction).

This project performs an end-to-end diagnostic across **99,441 real-world shipments** from the Olist logistics network. By decomposing fulfillment lifecycles across **7 deep analytical dimensions**, the diagnostic pinpoints the exact operational bottlenecks causing delivery failures and quantifies their direct dollar and customer satisfaction impact.

---

## 🏢 The 7 Core Analytical Modules

```
┌─────────────────────────────────────────────────────────────────────────────────────────────┐
│                       7 DEEP SUPPLY CHAIN ANALYTICAL MODULES                                │
├────────────────────────────────┬──────────────────────────┬────────────────────────────────┤
│ 1. Network SLA & DPMO Benchmarks│ 2. Multi-Stage Latency   │ 3. Geographic Topology Matrix  │
│ 4. Freight & Weight Sensitivity│ 5. Seller Fulfillment Tier│ 6. Holiday Surge Stress Test   │
│ 7. Customer LTV & Concessions  │                          │                                │
└────────────────────────────────┴──────────────────────────┴────────────────────────────────┘
```

### Module 1: Baseline SLA Compliance & Network Defect Density (DPMO)
* **Finding:** Network-wide delivery SLA breach rate stands at **7.87% (7,827 overdue deliveries)**.
* **Defect Density:** **78,269 DPMO** (Defects Per Million Opportunities), nearly 4x above the operational target (< 20,000 DPMO).
* **Average Latency:** Overdue orders arrive **+5.4 days** beyond customer commitment.

### Module 2: Multi-Stage Latency Decomposition (Seller vs Carrier)
* **The Culprit:** **Carrier Transit represents 82.4% of total delay time!**
* **Stage Variance:**
  * *On-Time Orders:* Seller Handover: **2.8 Days** | Carrier Road Transit: **8.0 Days** (Total: 11.2 Days)
  * *Breached Orders:* Seller Handover: **3.8 Days** | Carrier Road Transit: **27.1 Days** (Total: 31.4 Days)
* **Takeaway:** Warehouse packing is stable (+1 day variance); line-haul road freight transit is the primary point of failure (+19.1 days variance).

### Module 3: Geographic Topology (Intra-State vs Inter-State Route Matrix)
* **Intra-State (Same State Delivery):** Maintains a **98.2% on-time adherence rate** with an average delivery duration of 5.1 days.
* **Inter-State (Cross-Country Delivery):** Adherence drops to **76.5%**, with transit durations surging to 22.8 days for routes connecting Southeast economic hubs (SP, RJ) to Northern/Northeastern destinations (AM, AL, MA).

### Module 4: Product Category, Weight & Freight-to-Price Sensitivity
* **Heavy/Bulky Freight:** Orders in the top freight cost tier (>$25 freight) exhibit a **28.4% SLA breach rate** due to specialized line-haul handling requirements.
* **Freight Drag:** High freight fees combined with late deliveries drive customer return escalations up by 3.2x.

### Module 5: Seller Fulfillment Performance & SLA Scorecard
* **Seller Tiering:**
  * *Tier 1 (Gold - < 24h Handover):* Accounts for 62% of volume with only a 4.1% breach rate.
  * *Tier 3 (At-Risk - > 72h Handover):* Top 10% worst sellers generate **45% of all warehouse fulfillment delays**.

### Module 6: Seasonality & Holiday Surge Stress Test (Peak Shock)
* **Volume Shock:** During Q4 promotional volume surges (Black Friday effect), order volume increases by 240%, exceeding regional carrier sorting capacity and doubling average transit delays from 11 days to **24 days**.

### Module 7: Customer Trust Collapse & Financial Concession Exposure
* **Review Score Decay:**
  * On-Time Deliveries: **4.32 / 5.00 Rating** (81.4% 5-Star Promoters).
  * 1–3 Days Late: **2.57 / 5.00 Rating** (35% 1-Star Detractors).
  * > 7 Days Late: **1.62 / 5.00 Rating** (68.2% 1-Star Detractors).
* **Financial Concession Exposure:** Breached orders represent an estimated **$284,500 in direct shipping refunds and appeasement credits**, alongside an estimated **$1.2M in churned Customer Lifetime Value (LTV)**.

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
├── README.md                                  <- Executive project summary & diagnostic findings
├── requirements.txt                           <- Python dependencies (pandas, seaborn, matplotlib)
├── .gitignore                                 <- Clean git tracking configuration
│
├── notebooks/
│   └── supply_chain_sla_diagnostic.ipynb      <- 7-Module End-to-End Diagnostic Notebook with charts
│
├── sql/
│   ├── 01_schema_setup.sql                    <- Star Schema DDL & indexing
│   ├── 02_delivery_sla_breach_analysis.sql   <- SLA adherence & DPMO queries
│   ├── 03_bottleneck_decomposition.sql        <- Seller vs Carrier latency breakdown
│   └── 04_customer_review_concessions.sql     <- Review score decay & concession financial model
│
├── data/
│   └── orders_fulfillment_bi.csv              <- Clean telemetry dataset
│
└── scripts/
    └── data_pipeline.py                       <- Automated SQLite ETL & report exporter
```
