-- ============================================================
-- Project: Olist Delivery Reliability Dashboard
-- File: 02_create_indexes.sql
-- Database: PostgreSQL
-- ============================================================

-- Indexes are added to columns frequently used for:
--   - joins
--   - filtering
--   - grouping
--   - delivery analysis
--
-- IF NOT EXISTS makes this script safe to re-run.


-- ============================================================
-- Orders
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_orders_customer_id
ON olist.orders (customer_id);

CREATE INDEX IF NOT EXISTS idx_orders_status
ON olist.orders (order_status);

CREATE INDEX IF NOT EXISTS idx_orders_purchase_date
ON olist.orders (order_purchase_timestamp);

CREATE INDEX IF NOT EXISTS idx_orders_estimated_delivery_date
ON olist.orders (order_estimated_delivery_date);

CREATE INDEX IF NOT EXISTS idx_orders_delivered_customer_date
ON olist.orders (order_delivered_customer_date);

CREATE INDEX IF NOT EXISTS idx_orders_delivered_carrier_date
ON olist.orders (order_delivered_carrier_date);


-- ============================================================
-- Order items
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_order_items_product_id
ON olist.order_items (product_id);

CREATE INDEX IF NOT EXISTS idx_order_items_seller_id
ON olist.order_items (seller_id);


-- ============================================================
-- Payments
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_payments_order_id
ON olist.order_payments (order_id);


-- ============================================================
-- Reviews
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_reviews_order_id
ON olist.order_reviews (order_id);


-- ============================================================
-- Customers
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_customers_state
ON olist.customers (customer_state);


-- ============================================================
-- Products
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_products_category
ON olist.products (product_category_name);
