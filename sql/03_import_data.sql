-- ============================================================
-- Project: Olist Delivery Reliability Dashboard
-- File: 03_import_data.sql
-- Database: PostgreSQL
-- ============================================================
-- Loads the raw Olist CSV exports into the tables created in
-- 01_create_tables.sql.
--
-- NOTES
-- - Run this with psql (the \copy meta-command is a psql client
--   command, not standard SQL, and it reads files from YOUR
--   local machine rather than the server, so it works without
--   extra server-side file permissions).
-- - Update the file paths below to wherever you saved the
--   Kaggle "Brazilian E-Commerce" CSVs.
-- - Load order does not matter here because no FOREIGN KEY
--   constraints were defined in 01_create_tables.sql, but the
--   order below still follows the schema for readability.
-- - product_category_name_translation.csv is saved with a
--   UTF-8 BOM by Excel/Kaggle. If the first row loads with a
--   stray character in the header, re-save the file as
--   "UTF-8 (no BOM)" before importing, or strip it with:
--   sed -i '1s/^\xEF\xBB\xBF//' product_category_name_translation.csv
-- ============================================================

-- Clear existing data if re-running this script (safe because
-- there are no FK constraints linking these tables together).
TRUNCATE TABLE
    olist.geolocation,
    olist.order_reviews,
    olist.order_payments,
    olist.order_items,
    olist.orders,
    olist.products,
    olist.product_category_translation,
    olist.customers,
    olist.sellers
RESTART IDENTITY;

-- ------------------------------------------------------------
-- 1. Sellers
-- ------------------------------------------------------------
\copy olist.sellers FROM 'olist_sellers_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

-- ------------------------------------------------------------
-- 2. Product category translation
-- ------------------------------------------------------------
\copy olist.product_category_translation FROM 'product_category_name_translation.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

-- ------------------------------------------------------------
-- 3. Customers
-- ------------------------------------------------------------
\copy olist.customers FROM 'olist_customers_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

-- ------------------------------------------------------------
-- 4. Products
-- ------------------------------------------------------------
\copy olist.products FROM 'olist_products_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

-- ------------------------------------------------------------
-- 5. Orders
-- ------------------------------------------------------------
\copy olist.orders FROM 'olist_orders_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

-- ------------------------------------------------------------
-- 6. Order items
-- ------------------------------------------------------------
\copy olist.order_items FROM 'olist_order_items_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

-- ------------------------------------------------------------
-- 7. Order payments
-- ------------------------------------------------------------
\copy olist.order_payments FROM 'olist_order_payments_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

-- ------------------------------------------------------------
-- 8. Order reviews
-- ------------------------------------------------------------
\copy olist.order_reviews FROM 'olist_order_reviews_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

-- ------------------------------------------------------------
-- 9. Geolocation
-- ------------------------------------------------------------
\copy olist.geolocation FROM 'olist_geolocation_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

-- ------------------------------------------------------------
-- Quick sanity check: row counts per table
-- ------------------------------------------------------------
SELECT 'sellers' AS table_name, COUNT(*) AS row_count FROM olist.sellers
UNION ALL
SELECT 'product_category_translation', COUNT(*) FROM olist.product_category_translation
UNION ALL
SELECT 'customers', COUNT(*) FROM olist.customers
UNION ALL
SELECT 'products', COUNT(*) FROM olist.products
UNION ALL
SELECT 'orders', COUNT(*) FROM olist.orders
UNION ALL
SELECT 'order_items', COUNT(*) FROM olist.order_items
UNION ALL
SELECT 'order_payments', COUNT(*) FROM olist.order_payments
UNION ALL
SELECT 'order_reviews', COUNT(*) FROM olist.order_reviews
UNION ALL
SELECT 'geolocation', COUNT(*) FROM olist.geolocation
ORDER BY table_name;

