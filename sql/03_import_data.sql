-- ============================================================
-- Project: Olist Delivery Reliability Dashboard
-- File: 03_import_data.sql
-- Database: PostgreSQL
-- ============================================================

-- Purpose:
-- Load the raw Olist CSV files into the PostgreSQL tables
-- created by 01_create_tables.sql.
--
-- IMPORTANT:
-- This script uses PostgreSQL's \copy command.
-- \copy is a psql client command and reads files from the
-- computer running psql.
--
-- Therefore, the CSV files must be accessible from the current
-- working directory when this script is executed.
--
-- Example:
--
--   psql -U theophillips -d olist_delivery -f 03_import_data.sql
--
-- If the CSV files are stored in another folder, either:
--
--   1. Run psql from that folder, or
--   2. Update the file paths below.
--
-- Raw CSV files should NOT be committed to GitHub.
-- The repository should contain the SQL required to reproduce
-- the import rather than the raw dataset.


-- ============================================================
-- 1. Clear existing data
-- ============================================================

-- This makes the script safe to re-run.
--
-- All tables are cleared before importing the source data again.
-- This prevents duplicate records when the import script is
-- executed multiple times.

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


-- ============================================================
-- 2. Import sellers
-- ============================================================

\copy olist.sellers FROM 'olist_sellers_dataset.csv' WITH ( FORMAT csv, HEADER true, ENCODING 'UTF8' );


-- ============================================================
-- 3. Import product category translations
-- ============================================================

\copy olist.product_category_translation FROM 'product_category_name_translation.csv' WITH ( FORMAT csv, HEADER true, ENCODING 'UTF8' );


-- ============================================================
-- 4. Import customers
-- ============================================================

\copy olist.customers FROM 'olist_customers_dataset.csv' WITH ( FORMAT csv, HEADER true, ENCODING 'UTF8' );


-- ============================================================
-- 5. Import products
-- ============================================================

\copy olist.products FROM 'olist_products_dataset.csv' WITH ( FORMAT csv, HEADER true, ENCODING 'UTF8' );


-- ============================================================
-- 6. Import orders
-- ============================================================

\copy olist.orders FROM 'olist_orders_dataset.csv' WITH ( FORMAT csv, HEADER true, ENCODING 'UTF8' );


-- ============================================================
-- 7. Import order items
-- ============================================================

\copy olist.order_items FROM 'olist_order_items_dataset.csv' WITH ( FORMAT csv, HEADER true, ENCODING 'UTF8' );


-- ============================================================
-- 8. Import order payments
-- ============================================================

\copy olist.order_payments FROM 'olist_order_payments_dataset.csv' WITH ( FORMAT csv, HEADER true, ENCODING 'UTF8' );


-- ============================================================
-- 9. Import order reviews
-- ============================================================

\copy olist.order_reviews FROM 'olist_order_reviews_dataset.csv' WITH ( FORMAT csv, HEADER true, ENCODING 'UTF8' );


-- ============================================================
-- 10. Import geolocation
-- ============================================================

\copy olist.geolocation FROM 'olist_geolocation_dataset.csv' WITH ( FORMAT csv, HEADER true, ENCODING 'UTF8' );


-- ============================================================
-- 11. Row-count sanity check
-- ============================================================

-- These counts confirm that the expected source records have
-- been loaded into PostgreSQL.

SELECT
    'customers' AS table_name,
    COUNT(*) AS row_count
FROM olist.customers

UNION ALL

SELECT
    'geolocation',
    COUNT(*)
FROM olist.geolocation

UNION ALL

SELECT
    'order_items',
    COUNT(*)
FROM olist.order_items

UNION ALL

SELECT
    'order_payments',
    COUNT(*)
FROM olist.order_payments

UNION ALL

SELECT
    'order_reviews',
    COUNT(*)
FROM olist.order_reviews

UNION ALL

SELECT
    'orders',
    COUNT(*)
FROM olist.orders

UNION ALL

SELECT
    'product_category_translation',
    COUNT(*)
FROM olist.product_category_translation

UNION ALL

SELECT
    'products',
    COUNT(*)
FROM olist.products

UNION ALL

SELECT
    'sellers',
    COUNT(*)
FROM olist.sellers

ORDER BY table_name;
