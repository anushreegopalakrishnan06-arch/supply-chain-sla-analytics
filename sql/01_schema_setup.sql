-- ==============================================================================
-- Project: Supply Chain Analytics - Delivery SLA Breach & Customer Concession
-- File: 01_schema_setup.sql
-- Description: DDL to establish the Star Schema analytical warehouse tables.
-- ==============================================================================

-- 1. Dimension Table: Customers
CREATE TABLE IF NOT EXISTS dim_customers (
    customer_id VARCHAR(50) PRIMARY KEY,
    customer_unique_id VARCHAR(50),
    customer_zip_code_prefix INT,
    customer_city VARCHAR(100),
    customer_state VARCHAR(10)
);

-- 2. Dimension Table: Sellers
CREATE TABLE IF NOT EXISTS dim_sellers (
    seller_id VARCHAR(50) PRIMARY KEY,
    seller_zip_code_prefix INT,
    seller_city VARCHAR(100),
    seller_state VARCHAR(10)
);

-- 3. Fact Table: Orders Fulfillment
CREATE TABLE IF NOT EXISTS fact_orders_fulfillment (
    order_id VARCHAR(50) PRIMARY KEY,
    customer_id VARCHAR(50) NOT NULL,
    order_status VARCHAR(30) NOT NULL,
    order_purchase_timestamp TIMESTAMP NOT NULL,
    order_approved_at TIMESTAMP,
    order_delivered_carrier_date TIMESTAMP,
    order_delivered_customer_date TIMESTAMP,
    order_estimated_delivery_date TIMESTAMP NOT NULL,
    -- Analytical Derived Columns
    delivery_days NUMERIC,
    estimated_days NUMERIC,
    delay_days NUMERIC,
    is_sla_breach INT DEFAULT 0,
    CONSTRAINT fk_customer FOREIGN KEY (customer_id) REFERENCES dim_customers(customer_id)
);

-- 4. Fact Table: Order Items & Freight
CREATE TABLE IF NOT EXISTS fact_order_items (
    order_id VARCHAR(50) NOT NULL,
    order_item_id INT NOT NULL,
    product_id VARCHAR(50) NOT NULL,
    seller_id VARCHAR(50) NOT NULL,
    shipping_limit_date TIMESTAMP,
    price NUMERIC(10, 2) NOT NULL,
    freight_value NUMERIC(10, 2) NOT NULL,
    PRIMARY KEY (order_id, order_item_id),
    CONSTRAINT fk_order FOREIGN KEY (order_id) REFERENCES fact_orders_fulfillment(order_id),
    CONSTRAINT fk_seller FOREIGN KEY (seller_id) REFERENCES dim_sellers(seller_id)
);

-- 5. Fact Table: Customer Reviews
CREATE TABLE IF NOT EXISTS fact_order_reviews (
    review_id VARCHAR(50) PRIMARY KEY,
    order_id VARCHAR(50) NOT NULL,
    review_score INT NOT NULL,
    review_creation_date TIMESTAMP NOT NULL,
    review_answer_timestamp TIMESTAMP,
    CONSTRAINT fk_order_review FOREIGN KEY (order_id) REFERENCES fact_orders_fulfillment(order_id)
);

-- Analytical Indexing for High-Performance Queries
CREATE INDEX IF NOT EXISTS idx_orders_customer ON fact_orders_fulfillment(customer_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON fact_orders_fulfillment(order_status);
CREATE INDEX IF NOT EXISTS idx_orders_delivered_date ON fact_orders_fulfillment(order_delivered_customer_date);
CREATE INDEX IF NOT EXISTS idx_orders_estimated_date ON fact_orders_fulfillment(order_estimated_delivery_date);
CREATE INDEX IF NOT EXISTS idx_reviews_score ON fact_order_reviews(review_score);
