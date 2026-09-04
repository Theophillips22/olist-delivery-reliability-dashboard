-- Project: Olist Delivery Reliability Dashboard
-- File: 05_delivery_analysis_view.sql
-- Database: PostgreSQL
-- ============================================================
-- Analytical views built on top of the raw tables. These are
-- the objects Tableau connects to directly.
--
-- Core question: how does delivery reliability affect customer
-- satisfaction and revenue?
--
-- Contents:
--   1. olist.vw_order_delivery_metrics   - one row per delivered order
--                                           (grain for most Tableau sheets)
--   2. olist.vw_delivery_reliability_summary
--                                         - on-time vs late comparison
--   3. olist.vw_monthly_sales_performance
--                                         - month-by-month sales dashboard
--   4. olist.vw_state_delivery_performance
--                                         - geographic breakdown
--   5. olist.vw_category_delivery_performance
--                                         - product category breakdown
-- ============================================================

-- ------------------------------------------------------------
-- 1. Order-level delivery metrics
-- Grain: one row per order. Restricted to 'delivered' orders,
-- since only they have a complete timestamp trail
-- (order_delivered_customer_date) to measure against.
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW olist.vw_order_delivery_metrics AS
WITH order_revenue AS (
    SELECT
        order_id,
        SUM(price)          AS items_revenue,
        SUM(freight_value)  AS freight_revenue,
        SUM(price + freight_value) AS total_revenue,
        COUNT(*)            AS item_count
    FROM olist.order_items
    GROUP BY order_id
),
order_review AS (
    -- an order should have one review, but take the most recent
    -- if a duplicate slipped through
    SELECT DISTINCT ON (order_id)
        order_id,
        review_score
    FROM olist.order_reviews
    ORDER BY order_id, review_answer_timestamp DESC NULLS LAST
)
SELECT
    o.order_id,
    o.customer_id,
    c.customer_state,
    c.customer_city,
    o.order_status,
    o.order_purchase_timestamp,
    o.order_approved_at,
    o.order_delivered_carrier_date,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,

    -- delivery performance
    EXTRACT(DAY FROM (o.order_delivered_customer_date - o.order_purchase_timestamp))
        AS actual_delivery_days,
    EXTRACT(DAY FROM (o.order_estimated_delivery_date - o.order_purchase_timestamp))
        AS estimated_delivery_days,
    EXTRACT(DAY FROM (o.order_delivered_customer_date - o.order_estimated_delivery_date))
        AS delivery_delay_days,   -- positive = late, negative/zero = on time or early
    CASE
        WHEN o.order_delivered_customer_date <= o.order_estimated_delivery_date
            THEN 'On Time'
        ELSE 'Late'
    END AS delivery_status,
    EXTRACT(DAY FROM (o.order_delivered_carrier_date - o.order_approved_at))
        AS seller_handling_days,
    EXTRACT(DAY FROM (o.order_delivered_customer_date - o.order_delivered_carrier_date))
        AS carrier_shipping_days,

    -- revenue
    orv.item_count,
    orv.items_revenue,
    orv.freight_revenue,
    orv.total_revenue,

    -- satisfaction
    orr.review_score,
    CASE
        WHEN orr.review_score >= 4 THEN 'Satisfied'
        WHEN orr.review_score = 3 THEN 'Neutral'
        WHEN orr.review_score <= 2 THEN 'Dissatisfied'
        ELSE NULL
    END AS satisfaction_bucket,

    DATE_TRUNC('month', o.order_purchase_timestamp)::DATE AS order_month
FROM olist.orders o
JOIN olist.customers c ON o.customer_id = c.customer_id
LEFT JOIN order_revenue orv ON o.order_id = orv.order_id
LEFT JOIN order_review orr ON o.order_id = orr.order_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL;


-- ------------------------------------------------------------
-- 2. On-time vs late: satisfaction & revenue comparison
-- The headline view for the core research question.
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW olist.vw_delivery_reliability_summary AS
SELECT
    delivery_status,
    COUNT(*)                                   AS order_count,
    ROUND(AVG(review_score), 2)                AS avg_review_score,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE review_score <= 2)
        / NULLIF(COUNT(review_score), 0), 2
    )                                           AS pct_negative_reviews,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE review_score >= 4)
        / NULLIF(COUNT(review_score), 0), 2
    )                                           AS pct_positive_reviews,
    ROUND(AVG(total_revenue), 2)                AS avg_order_revenue,
    ROUND(SUM(total_revenue), 2)                AS total_revenue,
    ROUND(AVG(delivery_delay_days), 2)          AS avg_delay_days
FROM olist.vw_order_delivery_metrics
GROUP BY delivery_status;


-- ------------------------------------------------------------
-- 3. Monthly sales performance
-- Backbone of the general sales dashboard (revenue, order
-- volume, and reliability trended over time).
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW olist.vw_monthly_sales_performance AS
SELECT
    order_month,
    COUNT(*)                                    AS order_count,
    ROUND(SUM(total_revenue), 2)                AS total_revenue,
    ROUND(AVG(total_revenue), 2)                AS avg_order_value,
    ROUND(AVG(review_score), 2)                 AS avg_review_score,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE delivery_status = 'On Time')
        / COUNT(*), 2
    )                                            AS pct_on_time,
    ROUND(AVG(actual_delivery_days), 2)         AS avg_delivery_days
FROM olist.vw_order_delivery_metrics
GROUP BY order_month
ORDER BY order_month;


-- ------------------------------------------------------------
-- 4. Delivery performance by customer state
-- For a map/geo view in the dashboard.
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW olist.vw_state_delivery_performance AS
SELECT
    customer_state,
    COUNT(*)                                    AS order_count,
    ROUND(SUM(total_revenue), 2)                AS total_revenue,
    ROUND(AVG(total_revenue), 2)                AS avg_order_value,
    ROUND(AVG(review_score), 2)                 AS avg_review_score,
    ROUND(AVG(actual_delivery_days), 2)         AS avg_delivery_days,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE delivery_status = 'On Time')
        / COUNT(*), 2
    )                                            AS pct_on_time
FROM olist.vw_order_delivery_metrics
GROUP BY customer_state
ORDER BY total_revenue DESC;


-- ------------------------------------------------------------
-- 5. Delivery performance by product category
-- For a "which categories are hurt most by late delivery" view.
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW olist.vw_category_delivery_performance AS
SELECT
    COALESCE(t.product_category_name_english, p.product_category_name, 'unknown')
        AS product_category,
    COUNT(DISTINCT oi.order_id)                 AS order_count,
    ROUND(SUM(oi.price + oi.freight_value), 2)  AS total_revenue,
    ROUND(AVG(m.review_score), 2)               AS avg_review_score,
    ROUND(AVG(m.actual_delivery_days), 2)       AS avg_delivery_days,
    ROUND(
        100.0 * COUNT(DISTINCT oi.order_id) FILTER (WHERE m.delivery_status = 'On Time')
        / COUNT(DISTINCT oi.order_id), 2
    )                                            AS pct_on_time
FROM olist.order_items oi
JOIN olist.vw_order_delivery_metrics m ON oi.order_id = m.order_id
LEFT JOIN olist.products p ON oi.product_id = p.product_id
LEFT JOIN olist.product_category_translation t
    ON p.product_category_name = t.product_category_name
GROUP BY COALESCE(t.product_category_name_english, p.product_category_name, 'unknown')
ORDER BY total_revenue DESC;

