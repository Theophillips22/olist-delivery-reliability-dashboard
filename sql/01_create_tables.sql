-- ============================================================
-- Project: Olist Delivery Reliability Dashboard
-- File: 01_create_tables.sql
-- Database: PostgreSQL
-- ============================================================

-- Create a dedicated schema so that the Olist tables are kept
-- separate from PostgreSQL's default public schema.
CREATE SCHEMA IF NOT EXISTS olist;


-- ============================================================
-- 1. Customers
-- ============================================================

-- One row per customer-order relationship in the source data.
-- customer_id is unique to an order/customer record.
-- customer_unique_id identifies the underlying customer and can
-- therefore be used to identify repeat customers.

CREATE TABLE IF NOT EXISTS olist.customers (

    customer_id VARCHAR(50) PRIMARY KEY,

    customer_unique_id VARCHAR(50) NOT NULL,

    customer_zip_code_prefix VARCHAR(5),

    customer_city VARCHAR(100),

    customer_state VARCHAR(2)

);


-- ============================================================
-- 2. Orders
-- ============================================================

-- One row per order.
-- This is the main table used for delivery reliability analysis.

CREATE TABLE IF NOT EXISTS olist.orders (

    order_id VARCHAR(50) PRIMARY KEY,

    customer_id VARCHAR(50) NOT NULL,

    order_status VARCHAR(30) NOT NULL,

    order_purchase_timestamp TIMESTAMP,

    order_approved_at TIMESTAMP,

    order_delivered_carrier_date TIMESTAMP,

    order_delivered_customer_date TIMESTAMP,

    order_estimated_delivery_date TIMESTAMP

);


-- ============================================================
-- 3. Order items
-- ============================================================

-- One row per product within an order.
-- A single order can therefore contain multiple rows.

-- price represents the item price.
-- freight_value represents the freight charge associated with
-- the item.

-- The composite primary key ensures that an order cannot contain
-- the same order_item_id more than once.

CREATE TABLE IF NOT EXISTS olist.order_items (

    order_id VARCHAR(50) NOT NULL,

    order_item_id INTEGER NOT NULL,

    product_id VARCHAR(50) NOT NULL,

    seller_id VARCHAR(50) NOT NULL,

    shipping_limit_date TIMESTAMP,

    price NUMERIC(12, 2) NOT NULL,

    freight_value NUMERIC(12, 2) NOT NULL,

    PRIMARY KEY (order_id, order_item_id)

);


-- ============================================================
-- 4. Payments
-- ============================================================

-- One order may contain multiple payment records.
-- payment_sequential identifies the individual payment record
-- within an order.

CREATE TABLE IF NOT EXISTS olist.order_payments (

    order_id VARCHAR(50) NOT NULL,

    payment_sequential INTEGER NOT NULL,

    payment_type VARCHAR(30),

    payment_installments INTEGER,

    payment_value NUMERIC(12, 2),

    PRIMARY KEY (order_id, payment_sequential)

);


-- ============================================================
-- 5. Reviews
-- ============================================================

-- Reviews are used as the main measure of customer satisfaction.

-- The raw Olist data can contain multiple review records for an
-- order, so review_id is intentionally not used as the primary key.

CREATE TABLE IF NOT EXISTS olist.order_reviews (

    review_id VARCHAR(50),

    order_id VARCHAR(50) NOT NULL,

    review_score SMALLINT,

    review_comment_title TEXT,

    review_comment_message TEXT,

    review_creation_date TIMESTAMP,

    review_answer_timestamp TIMESTAMP,

    CONSTRAINT check_review_score
        CHECK (review_score BETWEEN 1 AND 5 OR review_score IS NULL)

);


-- ============================================================
-- 6. Products
-- ============================================================

-- Contains product category and physical product attributes.

CREATE TABLE IF NOT EXISTS olist.products (

    product_id VARCHAR(50) PRIMARY KEY,

    product_category_name VARCHAR(100),

    product_name_lenght INTEGER,

    product_description_lenght INTEGER,

    product_photos_qty INTEGER,

    product_weight_g NUMERIC(12, 2),

    product_length_cm NUMERIC(12, 2),

    product_height_cm NUMERIC(12, 2),

    product_width_cm NUMERIC(12, 2)

);


-- ============================================================
-- 7. Sellers
-- ============================================================

-- Contains seller location information.

CREATE TABLE IF NOT EXISTS olist.sellers (

    seller_id VARCHAR(50) PRIMARY KEY,

    seller_zip_code_prefix VARCHAR(5),

    seller_city VARCHAR(100),

    seller_state VARCHAR(2)

);


-- ============================================================
-- 8. Product category translation
-- ============================================================

-- Maps the original Portuguese product category names to
-- English category names.

CREATE TABLE IF NOT EXISTS olist.product_category_translation (

    product_category_name VARCHAR(100) PRIMARY KEY,

    product_category_name_english VARCHAR(100)

);


-- ============================================================
-- 9. Geolocation
-- ============================================================

-- A ZIP-code prefix can appear multiple times because the source
-- dataset contains multiple geographic observations per prefix.
-- Therefore, no primary key is defined on this table.

CREATE TABLE IF NOT EXISTS olist.geolocation (

    geolocation_zip_code_prefix VARCHAR(5),

    geolocation_lat DOUBLE PRECISION,

    geolocation_lng DOUBLE PRECISION,

    geolocation_city VARCHAR(100),

    geolocation_state VARCHAR(2)

);


-- ============================================================
-- DESIGN NOTE
-- ============================================================

-- Foreign key constraints are intentionally not defined in this
-- raw ingestion layer.
--
-- This preserves the source dataset as supplied and allows
-- referential integrity to be assessed explicitly in
-- 04_validation_checks.sql.
--
-- The analytical views in 05_delivery_analysis_view.sql only use
-- records that satisfy the relevant joins and business rules.
--
-- This approach separates:
--
--   1. Raw data ingestion
--   2. Data-quality validation
--   3. Analytical modelling
--
-- which makes the workflow easier to audit and reproduce.
