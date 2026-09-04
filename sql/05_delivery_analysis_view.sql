-- ============================================================
-- Project: Olist Delivery Reliability Dashboard
-- File: 05_delivery_analysis_view.sql
-- Database: PostgreSQL
-- ============================================================

-- ============================================================
-- PURPOSE
-- ============================================================

-- These analytical views sit between the raw Olist tables and
-- the Tableau dashboard.
--
-- The core business question is:
--
--   "How does delivery reliability affect customer satisfaction
--    and order value?"
--
-- The analytical layer creates consistent definitions for:
--
--   - delivery reliability
--   - delivery delay
--   - customer satisfaction
--   - order value
--   - seller handling time
--   - carrier shipping time
--
-- Tableau should connect to these views rather than repeatedly
-- joining the raw tables.


-- ============================================================
-- 1. Order-level delivery metrics
-- ============================================================

-- Grain:
-- One row per delivered order.
--
-- Only delivered orders with a customer delivery timestamp are
-- included because these are the orders for which actual delivery
-- performance can be measured.


CREATE OR REPLACE VIEW olist.vw_order_delivery_metrics AS

WITH order_value AS (

    SELECT

        order_id,

        SUM(price) AS item_value,

        SUM(freight_value) AS freight_value,

        SUM(price + freight_value) AS order_value,

        COUNT(*) AS item_count

    FROM olist.order_items

    GROUP BY order_id

),


order_review AS (

    -- The Olist dataset can contain multiple review records for
    -- an order. To avoid duplicating orders in the analytical
    -- layer, retain the most recent review response.

    SELECT DISTINCT ON (order_id)

        order_id,

        review_score

    FROM olist.order_reviews

    ORDER BY
        order_id,
        review_answer_timestamp DESC NULLS LAST

)


SELECT

    -- --------------------------------------------------------
    -- Order identification
    -- --------------------------------------------------------

    o.order_id,

    o.customer_id,

    c.customer_state,

    c.customer_city,


    -- --------------------------------------------------------
    -- Order dates
    -- --------------------------------------------------------

    o.order_status,

    o.order_purchase_timestamp,

    o.order_approved_at,

    o.order_delivered_carrier_date,

    o.order_delivered_customer_date,

    o.order_estimated_delivery_date,


    -- --------------------------------------------------------
    -- Delivery performance
    -- --------------------------------------------------------

    ROUND(
        EXTRACT(
            EPOCH FROM (
                o.order_delivered_customer_date
                - o.order_purchase_timestamp
            )
        ) / 86400.0,
        2
    ) AS actual_delivery_days,


    ROUND(
        EXTRACT(
            EPOCH FROM (
                o.order_estimated_delivery_date
                - o.order_purchase_timestamp
            )
        ) / 86400.0,
        2
    ) AS estimated_delivery_days,


    ROUND(
        EXTRACT(
            EPOCH FROM (
                o.order_delivered_customer_date
                - o.order_estimated_delivery_date
            )
        ) / 86400.0,
        2
    ) AS delivery_delay_days,


    CASE

        WHEN o.order_delivered_customer_date
             <= o.order_estimated_delivery_date

        THEN 'On Time'

        ELSE 'Late'

    END AS delivery_status,


    -- --------------------------------------------------------
    -- Delivery stages
    -- --------------------------------------------------------

    ROUND(
        EXTRACT(
            EPOCH FROM (
                o.order_delivered_carrier_date
                - o.order_approved_at
            )
        ) / 86400.0,
        2
    ) AS seller_handling_days,


    ROUND(
        EXTRACT(
            EPOCH FROM (
                o.order_delivered_customer_date
                - o.order_delivered_carrier_date
            )
        ) / 86400.0,
        2
    ) AS carrier_shipping_days,


    -- --------------------------------------------------------
    -- Order value
    -- --------------------------------------------------------

    ov.item_count,

    ov.item_value,

    ov.freight_value,

    ov.order_value,


    -- --------------------------------------------------------
    -- Customer satisfaction
    -- --------------------------------------------------------

    r.review_score,


    CASE

        WHEN r.review_score >= 4
            THEN 'Satisfied'

        WHEN r.review_score = 3
            THEN 'Neutral'

        WHEN r.review_score <= 2
            THEN 'Dissatisfied'

        ELSE NULL

    END AS satisfaction_bucket,


    -- --------------------------------------------------------
    -- Time dimensions
    -- --------------------------------------------------------

    DATE_TRUNC(
        'month',
        o.order_purchase_timestamp
    )::DATE AS order_month,


    EXTRACT(
        YEAR FROM o.order_purchase_timestamp
    )::INTEGER AS order_year

FROM olist.orders o

JOIN olist.customers c
    ON o.customer_id = c.customer_id

LEFT JOIN order_value ov
    ON o.order_id = ov.order_id

LEFT JOIN order_review r
    ON o.order_id = r.order_id

WHERE

    o.order_status = 'delivered'

    AND o.order_delivered_customer_date IS NOT NULL;


-- ============================================================
-- 2. On-time vs late summary
-- ============================================================

-- Headline analytical view for the project's core question.


CREATE OR REPLACE VIEW olist.vw_delivery_reliability_summary AS

SELECT

    delivery_status,

    COUNT(*) AS order_count,


    ROUND(
        100.0 * COUNT(*)
        / SUM(COUNT(*)) OVER (),
        2
    ) AS pct_of_orders,


    ROUND(
        AVG(review_score),
        2
    ) AS avg_review_score,


    ROUND(
        100.0
        * COUNT(*) FILTER (
            WHERE review_score <= 2
        )
        / NULLIF(COUNT(review_score), 0),
        2
    ) AS pct_negative_reviews,


    ROUND(
        100.0
        * COUNT(*) FILTER (
            WHERE review_score >= 4
        )
        / NULLIF(COUNT(review_score), 0),
        2
    ) AS pct_positive_reviews,


    ROUND(
        AVG(order_value),
        2
    ) AS avg_order_value,


    ROUND(
        SUM(order_value),
        2
    ) AS total_order_value,


    ROUND(
        AVG(delivery_delay_days),
        2
    ) AS avg_delivery_delay_days,


    ROUND(
        AVG(actual_delivery_days),
        2
    ) AS avg_delivery_days

FROM olist.vw_order_delivery_metrics

GROUP BY delivery_status

ORDER BY delivery_status;


-- ============================================================
-- 3. Monthly sales and reliability performance
-- ============================================================

CREATE OR REPLACE VIEW olist.vw_monthly_sales_performance AS

SELECT

    order_month,

    COUNT(*) AS order_count,


    ROUND(
        SUM(order_value),
        2
    ) AS total_order_value,


    ROUND(
        AVG(order_value),
        2
    ) AS avg_order_value,


    ROUND(
        AVG(review_score),
        2
    ) AS avg_review_score,


    ROUND(
        100.0
        * COUNT(*) FILTER (
            WHERE delivery_status = 'On Time'
        )
        / COUNT(*),
        2
    ) AS pct_on_time,


    ROUND(
        100.0
        * COUNT(*) FILTER (
            WHERE delivery_status = 'Late'
        )
        / COUNT(*),
        2
    ) AS pct_late,


    ROUND(
        AVG(actual_delivery_days),
        2
    ) AS avg_delivery_days,


    ROUND(
        AVG(delivery_delay_days),
        2
    ) AS avg_delivery_delay_days

FROM olist.vw_order_delivery_metrics

GROUP BY order_month

ORDER BY order_month;


-- ============================================================
-- 4. Delivery performance by customer state
-- ============================================================

CREATE OR REPLACE VIEW olist.vw_state_delivery_performance AS

SELECT

    customer_state,

    COUNT(*) AS order_count,


    ROUND(
        SUM(order_value),
        2
    ) AS total_order_value,


    ROUND(
        AVG(order_value),
        2
    ) AS avg_order_value,


    ROUND(
        AVG(review_score),
        2
    ) AS avg_review_score,


    ROUND(
        AVG(actual_delivery_days),
        2
    ) AS avg_delivery_days,


    ROUND(
        AVG(delivery_delay_days),
        2
    ) AS avg_delivery_delay_days,


    ROUND(
        100.0
        * COUNT(*) FILTER (
            WHERE delivery_status = 'On Time'
        )
        / COUNT(*),
        2
    ) AS pct_on_time,


    ROUND(
        100.0
        * COUNT(*) FILTER (
            WHERE delivery_status = 'Late'
        )
        / COUNT(*),
        2
    ) AS pct_late

FROM olist.vw_order_delivery_metrics

GROUP BY customer_state

ORDER BY pct_late DESC;


-- ============================================================
-- 5. Delivery performance by product category
-- ============================================================

-- Category analysis is performed at an order/category level.
--
-- This prevents an order's review score from being counted
-- multiple times simply because the order contains multiple
-- items from the same category.


CREATE OR REPLACE VIEW olist.vw_category_delivery_performance AS

WITH category_order_metrics AS (

    SELECT

        oi.order_id,

        COALESCE(
            t.product_category_name_english,
            p.product_category_name,
            'unknown'
        ) AS product_category,


        -- Item-level order value associated with the category.
        SUM(
            oi.price + oi.freight_value
        ) AS category_order_value,


        MAX(m.review_score) AS review_score,

        MAX(m.actual_delivery_days)
            AS actual_delivery_days,

        MAX(m.delivery_status)
            AS delivery_status

    FROM olist.order_items oi

    JOIN olist.vw_order_delivery_metrics m
        ON oi.order_id = m.order_id

    LEFT JOIN olist.products p
        ON oi.product_id = p.product_id

    LEFT JOIN olist.product_category_translation t
        ON p.product_category_name =
           t.product_category_name

    GROUP BY

        oi.order_id,

        COALESCE(
            t.product_category_name_english,
            p.product_category_name,
            'unknown'
        )

)


SELECT

    product_category,


    COUNT(*) AS order_count,


    ROUND(
        SUM(category_order_value),
        2
    ) AS total_order_value,


    ROUND(
        AVG(category_order_value),
        2
    ) AS avg_category_order_value,


    ROUND(
        AVG(review_score),
        2
    ) AS avg_review_score,


    ROUND(
        AVG(actual_delivery_days),
        2
    ) AS avg_delivery_days,


    ROUND(
        100.0
        * COUNT(*) FILTER (
            WHERE delivery_status = 'On Time'
        )
        / COUNT(*),
        2
    ) AS pct_on_time,


    ROUND(
        100.0
        * COUNT(*) FILTER (
            WHERE delivery_status = 'Late'
        )
        / COUNT(*),
        2
    ) AS pct_late

FROM category_order_metrics

GROUP BY product_category

ORDER BY pct_late DESC;
