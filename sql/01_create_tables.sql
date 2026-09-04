-- ============================================================
-- Project: Olist Delivery Reliability Dashboard
-- File: 01_create_tables.sql
-- Database: PostgreSQL
-- ============================================================

CREATE SCHEMA IF NOT EXISTS olist;

-- ------------------------------------------------------------
-- 1. Customers
-- One row per order-customer record.
-- customer_unique_id identifies repeat customers.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS olist.customers (
    customer_id                 VARCHAR(50) PRIMARY KEY,
    customer_unique_id          VARCHAR(50) NOT NULL,
    customer_zip_code_prefix    VARCHAR(5),
    customer_city               VARCHAR(100),
    customer_state              VARCHAR(2)
);

-- ------------------------------------------------------------
-- 2. Orders
-- One row per order. This is the main table for delivery analysis.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS olist.orders (
    order_id                        VARCHAR(50) PRIMARY KEY,
    customer_id                     VARCHAR(50) NOT NULL,
    order_status                    VARCHAR(30) NOT NULL,
    order_purchase_timestamp        TIMESTAMP,
    order_approved_at               TIMESTAMP,
    order_delivered_carrier_date    TIMESTAMP,
    order_delivered_customer_date   TIMESTAMP,
    order_estimated_delivery_date   TIMESTAMP
);

-- ------------------------------------------------------------
-- 3. Order items
-- One order can contain multiple items.
-- Revenue comes from price + freight_value.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS olist.order_items (
    order_id                VARCHAR(50) NOT NULL,
    order_item_id           INTEGER NOT NULL,
    product_id              VARCHAR(50) NOT NULL,
    seller_id               VARCHAR(50) NOT NULL,
    shipping_limit_date     TIMESTAMP,
    price                   NUMERIC(12, 2) NOT NULL,
    freight_value           NUMERIC(12, 2) NOT NULL,

    PRIMARY KEY (order_id, order_item_id)
);

-- ------------------------------------------------------------
-- 4. Payments
-- One order may have multiple payment records.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS olist.order_payments (
    order_id                VARCHAR(50) NOT NULL,
    payment_sequential      INTEGER NOT NULL,
    payment_type            VARCHAR(30),
    payment_installments    INTEGER,
    payment_value           NUMERIC(12, 2),

    PRIMARY KEY (order_id, payment_sequential)
);

-- ------------------------------------------------------------
-- 5. Reviews
-- Used to measure customer satisfaction.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS olist.order_reviews (
    review_id                   VARCHAR(50),
    order_id                    VARCHAR(50) NOT NULL,
    review_score                SMALLINT,
    review_comment_title        TEXT,
    review_comment_message      TEXT,
    review_creation_date        TIMESTAMP,
    review_answer_timestamp     TIMESTAMP,

    CONSTRAINT check_review_score
        CHECK (review_score BETWEEN 1 AND 5 OR review_score IS NULL)
);

-- ------------------------------------------------------------
-- 6. Products
-- Contains product category and physical product attributes.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS olist.products (
    product_id                      VARCHAR(50) PRIMARY KEY,
    product_category_name            VARCHAR(100),
    product_name_lenght              INTEGER,
    product_description_lenght       INTEGER,
    product_photos_qty               INTEGER,
    product_weight_g                 NUMERIC(12, 2),
    product_length_cm                NUMERIC(12, 2),
    product_height_cm                NUMERIC(12, 2),
    product_width_cm                 NUMERIC(12, 2)
);

-- ------------------------------------------------------------
-- 7. Sellers
-- Contains seller location information.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS olist.sellers (
    seller_id                    VARCHAR(50) PRIMARY KEY,
    seller_zip_code_prefix       VARCHAR(5),
    seller_city                  VARCHAR(100),
    seller_state                 VARCHAR(2)
);

-- ------------------------------------------------------------
-- 8. Product category translation
-- Converts Portuguese product categories to English.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS olist.product_category_translation (
    product_category_name             VARCHAR(100) PRIMARY KEY,
    product_category_name_english     VARCHAR(100)
);

-- ------------------------------------------------------------
-- 9. Geolocation
-- A ZIP prefix can appear many times, so no primary key is used.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS olist.geolocation (
    geolocation_zip_code_prefix    VARCHAR(5),
    geolocation_lat                DOUBLE PRECISION,
    geolocation_lng                DOUBLE PRECISION,
    geolocation_city               VARCHAR(100),
    geolocation_state              VARCHAR(2)
);
