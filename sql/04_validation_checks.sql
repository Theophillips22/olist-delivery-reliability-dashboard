-- ============================================================
-- Project: Olist Delivery Reliability Dashboard
-- File: 04_validation_checks.sql
-- Database: PostgreSQL
-- ============================================================
-- Data quality checks to run after 03_import_data.sql.
-- Each query should return 0 rows / 0 count if the data is clean.
-- Anything returned here is worth noting in the README as a
-- known data quality issue, since it affects how the delivery
-- and revenue metrics in 05_delivery_analysis_view.sql should
-- be interpreted.
-- ============================================================

-- ------------------------------------------------------------
-- 1. Duplicate primary keys
-- (should not be possible given the PK constraints, but useful
-- to run once before constraints are trusted, e.g. after a
-- schema change)
-- ------------------------------------------------------------
SELECT customer_id, COUNT(*)
FROM olist.customers
GROUP BY customer_id
HAVING COUNT(*) > 1;

SELECT order_id, COUNT(*)
FROM olist.orders
GROUP BY order_id
HAVING COUNT(*) > 1;

SELECT product_id, COUNT(*)
FROM olist.products
GROUP BY product_id
HAVING COUNT(*) > 1;

SELECT seller_id, COUNT(*)
FROM olist.sellers
GROUP BY seller_id
HAVING COUNT(*) > 1;

-- ------------------------------------------------------------
-- 2. Orphaned records
-- No FK constraints were declared on purpose (Olist's raw
-- export has a small number of orphaned rows), so check for
-- them explicitly instead.
-- ------------------------------------------------------------
-- Orders with no matching customer
SELECT o.order_id
FROM olist.orders o
LEFT JOIN olist.customers c ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;

-- Order items with no matching order
SELECT oi.order_id
FROM olist.order_items oi
LEFT JOIN olist.orders o ON oi.order_id = o.order_id
WHERE o.order_id IS NULL;

-- Order items with no matching product
SELECT oi.product_id
FROM olist.order_items oi
LEFT JOIN olist.products p ON oi.product_id = p.product_id
WHERE p.product_id IS NULL;

-- Order items with no matching seller
SELECT oi.seller_id
FROM olist.order_items oi
LEFT JOIN olist.sellers s ON oi.seller_id = s.seller_id
WHERE s.seller_id IS NULL;

-- Payments with no matching order
SELECT op.order_id
FROM olist.order_payments op
LEFT JOIN olist.orders o ON op.order_id = o.order_id
WHERE o.order_id IS NULL;

-- Reviews with no matching order
SELECT rv.order_id
FROM olist.order_reviews rv
LEFT JOIN olist.orders o ON rv.order_id = o.order_id
WHERE o.order_id IS NULL;

-- Products with a category not present in the translation table
SELECT DISTINCT p.product_category_name
FROM olist.products p
LEFT JOIN olist.product_category_translation t
    ON p.product_category_name = t.product_category_name
WHERE p.product_category_name IS NOT NULL
  AND t.product_category_name IS NULL;

-- ------------------------------------------------------------
-- 3. Null / missing critical fields
-- ------------------------------------------------------------
SELECT COUNT(*) AS orders_missing_status
FROM olist.orders
WHERE order_status IS NULL;

SELECT COUNT(*) AS orders_missing_purchase_ts
FROM olist.orders
WHERE order_purchase_timestamp IS NULL;

SELECT COUNT(*) AS delivered_orders_missing_delivery_date
FROM olist.orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NULL;

SELECT COUNT(*) AS items_missing_price_or_freight
FROM olist.order_items
WHERE price IS NULL OR freight_value IS NULL;

-- ------------------------------------------------------------
-- 4. Business-logic / date-order sanity checks
-- ------------------------------------------------------------
-- Delivered before it was purchased (should never happen)
SELECT order_id, order_purchase_timestamp, order_delivered_customer_date
FROM olist.orders
WHERE order_delivered_customer_date IS NOT NULL
  AND order_delivered_customer_date < order_purchase_timestamp;

-- Delivered to the carrier after it reached the customer
SELECT order_id, order_delivered_carrier_date, order_delivered_customer_date
FROM olist.orders
WHERE order_delivered_carrier_date IS NOT NULL
  AND order_delivered_customer_date IS NOT NULL
  AND order_delivered_carrier_date > order_delivered_customer_date;

-- Negative prices or freight values
SELECT order_id, order_item_id, price, freight_value
FROM olist.order_items
WHERE price < 0 OR freight_value < 0;

-- Review scores outside the expected 1-5 range
-- (belt-and-braces check; the CHECK constraint should prevent this)
SELECT review_id, review_score
FROM olist.order_reviews
WHERE review_score IS NOT NULL
  AND review_score NOT BETWEEN 1 AND 5;

-- Duplicate reviews for the same order
SELECT order_id, COUNT(*) AS review_count
FROM olist.order_reviews
GROUP BY order_id
HAVING COUNT(*) > 1;

-- ------------------------------------------------------------
-- 5. Order status breakdown
-- Confirms what proportion of orders are usable for delivery
-- analysis (only 'delivered' orders have a full timestamp trail).
-- ------------------------------------------------------------
SELECT
    order_status,
    COUNT(*) AS order_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_orders
FROM olist.orders
GROUP BY order_status
ORDER BY order_count DESC;

-- ------------------------------------------------------------
-- 6. Row count reconciliation against source CSVs
-- Fill in the expected counts from the raw files and compare.
-- ------------------------------------------------------------
SELECT 'customers' AS table_name, COUNT(*) AS loaded_rows FROM olist.customers
UNION ALL
SELECT 'orders', COUNT(*) FROM olist.orders
UNION ALL
SELECT 'order_items', COUNT(*) FROM olist.order_items
UNION ALL
SELECT 'order_payments', COUNT(*) FROM olist.order_payments
UNION ALL
SELECT 'order_reviews', COUNT(*) FROM olist.order_reviews
UNION ALL
SELECT 'products', COUNT(*) FROM olist.products
UNION ALL
SELECT 'sellers', COUNT(*) FROM olist.sellers
UNION ALL
SELECT 'geolocation', COUNT(*) FROM olist.geolocation
ORDER BY table_name;

