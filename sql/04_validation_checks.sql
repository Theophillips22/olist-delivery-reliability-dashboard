-- ============================================================
-- Project: Olist Delivery Reliability Dashboard
-- File: 04_validation_checks.sql
-- Database: PostgreSQL
-- ============================================================

-- Purpose:
-- Validate the imported Olist data before it is used for
-- delivery, satisfaction and order-value analysis.
--
-- Each validation produces:
--
--   check_name
--   issue_count
--   status
--
-- A clean dataset should produce PASS for all checks.
--
-- Any FAIL should be investigated before relying on the
-- analytical views.


-- ============================================================
-- 1. Data-quality validation summary
-- ============================================================

WITH validation_checks AS (

    -- --------------------------------------------------------
    -- Duplicate customers
    -- --------------------------------------------------------

    SELECT
        'Duplicate customer IDs' AS check_name,
        COUNT(*) AS issue_count
    FROM (
        SELECT customer_id
        FROM olist.customers
        GROUP BY customer_id
        HAVING COUNT(*) > 1
    ) duplicates


    UNION ALL


    -- --------------------------------------------------------
    -- Duplicate orders
    -- --------------------------------------------------------

    SELECT
        'Duplicate order IDs',
        COUNT(*)
    FROM (
        SELECT order_id
        FROM olist.orders
        GROUP BY order_id
        HAVING COUNT(*) > 1
    ) duplicates


    UNION ALL


    -- --------------------------------------------------------
    -- Duplicate products
    -- --------------------------------------------------------

    SELECT
        'Duplicate product IDs',
        COUNT(*)
    FROM (
        SELECT product_id
        FROM olist.products
        GROUP BY product_id
        HAVING COUNT(*) > 1
    ) duplicates


    UNION ALL


    -- --------------------------------------------------------
    -- Duplicate sellers
    -- --------------------------------------------------------

    SELECT
        'Duplicate seller IDs',
        COUNT(*)
    FROM (
        SELECT seller_id
        FROM olist.sellers
        GROUP BY seller_id
        HAVING COUNT(*) > 1
    ) duplicates


    UNION ALL


    -- --------------------------------------------------------
    -- Orders without customers
    -- --------------------------------------------------------

    SELECT
        'Orders without matching customers',
        COUNT(*)
    FROM olist.orders o
    LEFT JOIN olist.customers c
        ON o.customer_id = c.customer_id
    WHERE c.customer_id IS NULL


    UNION ALL


    -- --------------------------------------------------------
    -- Order items without orders
    -- --------------------------------------------------------

    SELECT
        'Order items without matching orders',
        COUNT(*)
    FROM olist.order_items oi
    LEFT JOIN olist.orders o
        ON oi.order_id = o.order_id
    WHERE o.order_id IS NULL


    UNION ALL


    -- --------------------------------------------------------
    -- Order items without products
    -- --------------------------------------------------------

    SELECT
        'Order items without matching products',
        COUNT(*)
    FROM olist.order_items oi
    LEFT JOIN olist.products p
        ON oi.product_id = p.product_id
    WHERE p.product_id IS NULL


    UNION ALL


    -- --------------------------------------------------------
    -- Order items without sellers
    -- --------------------------------------------------------

    SELECT
        'Order items without matching sellers',
        COUNT(*)
    FROM olist.order_items oi
    LEFT JOIN olist.sellers s
        ON oi.seller_id = s.seller_id
    WHERE s.seller_id IS NULL


    UNION ALL


    -- --------------------------------------------------------
    -- Payments without orders
    -- --------------------------------------------------------

    SELECT
        'Payments without matching orders',
        COUNT(*)
    FROM olist.order_payments op
    LEFT JOIN olist.orders o
        ON op.order_id = o.order_id
    WHERE o.order_id IS NULL


    UNION ALL


    -- --------------------------------------------------------
    -- Reviews without orders
    -- --------------------------------------------------------

    SELECT
        'Reviews without matching orders',
        COUNT(*)
    FROM olist.order_reviews r
    LEFT JOIN olist.orders o
        ON r.order_id = o.order_id
    WHERE o.order_id IS NULL


    UNION ALL


    -- --------------------------------------------------------
    -- Products without category translation
    -- --------------------------------------------------------

    SELECT
        'Products without category translation',
        COUNT(*)
    FROM (
        SELECT DISTINCT p.product_category_name
        FROM olist.products p
        LEFT JOIN olist.product_category_translation t
            ON p.product_category_name = t.product_category_name
        WHERE p.product_category_name IS NOT NULL
          AND t.product_category_name IS NULL
    ) unmatched_categories


    UNION ALL


    -- --------------------------------------------------------
    -- Orders missing purchase timestamp
    -- --------------------------------------------------------

    SELECT
        'Orders missing purchase timestamp',
        COUNT(*)
    FROM olist.orders
    WHERE order_purchase_timestamp IS NULL


    UNION ALL


    -- --------------------------------------------------------
    -- Delivered orders missing delivery date
    -- --------------------------------------------------------

    SELECT
        'Delivered orders missing customer delivery date',
        COUNT(*)
    FROM olist.orders
    WHERE order_status = 'delivered'
      AND order_delivered_customer_date IS NULL


    UNION ALL


    -- --------------------------------------------------------
    -- Order items missing price/freight
    -- --------------------------------------------------------

    SELECT
        'Order items missing price or freight',
        COUNT(*)
    FROM olist.order_items
    WHERE price IS NULL
       OR freight_value IS NULL


    UNION ALL


    -- --------------------------------------------------------
    -- Negative prices/freight
    -- --------------------------------------------------------

    SELECT
        'Order items with negative price/freight',
        COUNT(*)
    FROM olist.order_items
    WHERE price < 0
       OR freight_value < 0


    UNION ALL


    -- --------------------------------------------------------
    -- Invalid review scores
    -- --------------------------------------------------------

    SELECT
        'Invalid review scores',
        COUNT(*)
    FROM olist.order_reviews
    WHERE review_score IS NOT NULL
      AND review_score NOT BETWEEN 1 AND 5


    UNION ALL


    -- --------------------------------------------------------
    -- Delivered before purchase
    -- --------------------------------------------------------

    SELECT
        'Orders delivered before purchase',
        COUNT(*)
    FROM olist.orders
    WHERE order_delivered_customer_date IS NOT NULL
      AND order_delivered_customer_date < order_purchase_timestamp


    UNION ALL


    -- --------------------------------------------------------
    -- Carrier date after customer delivery date
    -- --------------------------------------------------------

    SELECT
        'Orders with carrier date after customer delivery',
        COUNT(*)
    FROM olist.orders
    WHERE order_delivered_carrier_date IS NOT NULL
      AND order_delivered_customer_date IS NOT NULL
      AND order_delivered_carrier_date > order_delivered_customer_date


    UNION ALL


    -- --------------------------------------------------------
    -- Reviews duplicated by order
    -- --------------------------------------------------------

    SELECT
        'Orders with multiple review records',
        COUNT(*)
    FROM (
        SELECT order_id
        FROM olist.order_reviews
        GROUP BY order_id
        HAVING COUNT(*) > 1
    ) duplicate_reviews
)


-- ============================================================
-- Final validation result
-- ============================================================

SELECT

    check_name,

    issue_count,

    CASE
        WHEN issue_count = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS status

FROM validation_checks

ORDER BY
    CASE
        WHEN issue_count = 0 THEN 1
        ELSE 0
    END,
    check_name;


-- ============================================================
-- 2. Order status breakdown
-- ============================================================

-- Shows how many orders fall into each status and what proportion
-- of the full dataset they represent.

SELECT

    order_status,

    COUNT(*) AS order_count,

    ROUND(
        100.0 * COUNT(*)
        / SUM(COUNT(*)) OVER (),
        2
    ) AS pct_of_orders

FROM olist.orders

GROUP BY order_status

ORDER BY order_count DESC;


-- ============================================================
-- 3. Loaded row counts
-- ============================================================

-- Confirms the final size of each raw table.

SELECT
    'customers' AS table_name,
    COUNT(*) AS loaded_rows
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
