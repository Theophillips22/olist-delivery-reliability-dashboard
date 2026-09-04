/* ============================================================
   06_key_findings.sql

   Purpose:
   Answer the main business questions for the Olist
   delivery reliability analysis.

   Main questions:
   1. How common are late deliveries?
   2. Are late deliveries associated with lower review scores?
   3. How much order value is associated with late deliveries?
   4. Which states have the worst delivery reliability?
   5. Which product categories are most affected?
   6. Is seller handling or carrier shipping associated with delays?
   7. How does delivery reliability change over time?
   8. What are the characteristics of late vs on-time orders?

   All analysis is based on the analytical views created
   in 05_delivery_analysis_view.sql.
   ============================================================ */


/* ============================================================
   1. OVERALL DELIVERY RELIABILITY

   Business question:
   What proportion of delivered orders were late?
   ============================================================ */

SELECT
    delivery_status,
    order_count,
    pct_of_orders,
    avg_delivery_days,
    avg_delivery_delay_days,
    avg_review_score,
    pct_negative_reviews,
    avg_order_value,
    total_order_value
FROM olist.vw_delivery_reliability_summary
ORDER BY
    CASE
        WHEN delivery_status = 'Late' THEN 1
        WHEN delivery_status = 'On Time' THEN 2
        ELSE 3
    END;


/* ============================================================
   2. LATE DELIVERY VS CUSTOMER SATISFACTION

   Business question:
   Are late deliveries associated with lower customer
   review scores?

   We compare:
   - Average review score
   - Negative review rate
   - Positive review rate
   ============================================================ */

SELECT
    delivery_status,
    COUNT(*) AS reviewed_orders,
    ROUND(AVG(review_score), 2) AS avg_review_score,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE review_score <= 2
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS pct_negative_reviews,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE review_score >= 4
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS pct_positive_reviews

FROM olist.vw_order_delivery_metrics

WHERE review_score IS NOT NULL

GROUP BY
    delivery_status

ORDER BY
    delivery_status;


/* ============================================================
   3. REVIEW SCORE DISTRIBUTION

   Business question:
   Does the distribution of review scores differ between
   late and on-time deliveries?

   This is more informative than looking only at averages.
   ============================================================ */

SELECT
    delivery_status,
    review_score,
    COUNT(*) AS order_count,

    ROUND(
        100.0 * COUNT(*)
        / SUM(COUNT(*)) OVER (
            PARTITION BY delivery_status
        ),
        2
    ) AS pct_of_status_orders

FROM olist.vw_order_delivery_metrics

WHERE review_score IS NOT NULL

GROUP BY
    delivery_status,
    review_score

ORDER BY
    delivery_status,
    review_score;


/* ============================================================
   4. LATE DELIVERY AND ORDER VALUE

   Business question:
   How much order value is associated with late deliveries?

   Important:
   In this project "order_value" represents:

       product price + freight value

   It is not accounting revenue or profit.
   ============================================================ */

SELECT
    delivery_status,

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
        100.0 * SUM(order_value)
        / SUM(SUM(order_value)) OVER (),
        2
    ) AS pct_of_total_order_value

FROM olist.vw_order_delivery_metrics

GROUP BY
    delivery_status

ORDER BY
    total_order_value DESC;


/* ============================================================
   5. ESTIMATED VS ACTUAL DELIVERY PERFORMANCE

   Business question:
   How much longer do late orders take compared with
   their estimated delivery time?
   ============================================================ */

SELECT
    delivery_status,

    COUNT(*) AS order_count,

    ROUND(
        AVG(estimated_delivery_days),
        2
    ) AS avg_estimated_delivery_days,

    ROUND(
        AVG(actual_delivery_days),
        2
    ) AS avg_actual_delivery_days,

    ROUND(
        AVG(delivery_delay_days),
        2
    ) AS avg_delivery_delay_days,

    ROUND(
        MAX(delivery_delay_days),
        2
    ) AS max_delivery_delay_days

FROM olist.vw_order_delivery_metrics

GROUP BY
    delivery_status

ORDER BY
    delivery_status;


/* ============================================================
   6. STATE DELIVERY PERFORMANCE

   Business question:
   Which customer states have the worst delivery reliability?

   We require at least 100 delivered orders so that very
   small states do not dominate the ranking.
   ============================================================ */

SELECT
    customer_state,
    order_count,
    ROUND(pct_late, 2) AS pct_late,
    ROUND(pct_on_time, 2) AS pct_on_time,
    ROUND(avg_delivery_days, 2) AS avg_delivery_days,
    ROUND(avg_delivery_delay_days, 2) AS avg_delivery_delay_days,
    ROUND(avg_review_score, 2) AS avg_review_score,
    ROUND(total_order_value, 2) AS total_order_value

FROM olist.vw_state_delivery_performance

WHERE order_count >= 100

ORDER BY
    pct_late DESC;


/* ============================================================
   7. BEST-PERFORMING STATES

   Business question:
   Which states have the strongest delivery reliability?

   Again, only states with at least 100 delivered orders
   are included.
   ============================================================ */

SELECT
    customer_state,
    order_count,
    ROUND(pct_on_time, 2) AS pct_on_time,
    ROUND(pct_late, 2) AS pct_late,
    ROUND(avg_delivery_days, 2) AS avg_delivery_days,
    ROUND(avg_review_score, 2) AS avg_review_score

FROM olist.vw_state_delivery_performance

WHERE order_count >= 100

ORDER BY
    pct_on_time DESC;


/* ============================================================
   8. PRODUCT CATEGORY PERFORMANCE

   Business question:
   Which product categories experience the highest proportion
   of late deliveries?
   ============================================================ */

SELECT
    product_category,
    order_count,

    ROUND(
        pct_late,
        2
    ) AS pct_late,

    ROUND(
        pct_on_time,
        2
    ) AS pct_on_time,

    ROUND(
        avg_delivery_days,
        2
    ) AS avg_delivery_days,

    ROUND(
        avg_review_score,
        2
    ) AS avg_review_score,

    ROUND(
        total_order_value,
        2
    ) AS total_order_value

FROM olist.vw_category_delivery_performance

WHERE order_count >= 100

ORDER BY
    pct_late DESC;


/* ============================================================
   9. CATEGORY VALUE AT RISK

   Business question:
   Which categories have the greatest amount of order value
   associated with late deliveries?

   This combines:
   - Delivery reliability
   - Commercial importance
   ============================================================ */

SELECT
    product_category,

    COUNT(*) AS category_order_count,

    ROUND(
        SUM(category_order_value),
        2
    ) AS total_order_value,

    ROUND(
        SUM(
            CASE
                WHEN delivery_status = 'Late'
                THEN category_order_value
                ELSE 0
            END
        ),
        2
    ) AS late_order_value,

    ROUND(
        100.0 *
        SUM(
            CASE
                WHEN delivery_status = 'Late'
                THEN category_order_value
                ELSE 0
            END
        )
        / NULLIF(SUM(category_order_value), 0),
        2
    ) AS pct_category_value_late

FROM olist.vw_category_delivery_performance

GROUP BY
    product_category

HAVING
    COUNT(*) >= 100

ORDER BY
    late_order_value DESC;


/* ============================================================
   10. SELLER HANDLING TIME

   Business question:
   Are longer seller handling times associated with late
   deliveries?

   We divide orders into handling-time bands.
   ============================================================ */

SELECT
    CASE
        WHEN seller_handling_days < 2
            THEN 'Under 2 days'

        WHEN seller_handling_days < 4
            THEN '2-3 days'

        WHEN seller_handling_days < 7
            THEN '4-6 days'

        ELSE '7+ days'
    END AS seller_handling_band,

    COUNT(*) AS order_count,

    ROUND(
        AVG(seller_handling_days),
        2
    ) AS avg_seller_handling_days,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE delivery_status = 'Late'
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS pct_late,

    ROUND(
        AVG(review_score),
        2
    ) AS avg_review_score

FROM olist.vw_order_delivery_metrics

GROUP BY
    seller_handling_band

ORDER BY
    MIN(seller_handling_days);


/* ============================================================
   11. CARRIER SHIPPING TIME

   Business question:
   Are longer carrier shipping times associated with late
   deliveries?
   ============================================================ */

SELECT
    CASE
        WHEN carrier_shipping_days < 2
            THEN 'Under 2 days'

        WHEN carrier_shipping_days < 5
            THEN '2-4 days'

        WHEN carrier_shipping_days < 8
            THEN '5-7 days'

        ELSE '8+ days'
    END AS carrier_shipping_band,

    COUNT(*) AS order_count,

    ROUND(
        AVG(carrier_shipping_days),
        2
    ) AS avg_carrier_shipping_days,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE delivery_status = 'Late'
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS pct_late,

    ROUND(
        AVG(review_score),
        2
    ) AS avg_review_score

FROM olist.vw_order_delivery_metrics

GROUP BY
    carrier_shipping_band

ORDER BY
    MIN(carrier_shipping_days);


/* ============================================================
   12. SELLER VS CARRIER CONTRIBUTION

   Business question:
   Is the delay more strongly associated with seller handling
   or carrier shipping time?

   We compare average seller handling and carrier shipping
   times between late and on-time orders.
   ============================================================ */

SELECT
    delivery_status,

    COUNT(*) AS order_count,

    ROUND(
        AVG(seller_handling_days),
        2
    ) AS avg_seller_handling_days,

    ROUND(
        AVG(carrier_shipping_days),
        2
    ) AS avg_carrier_shipping_days,

    ROUND(
        AVG(delivery_delay_days),
        2
    ) AS avg_delivery_delay_days

FROM olist.vw_order_delivery_metrics

GROUP BY
    delivery_status

ORDER BY
    delivery_status;


/* ============================================================
   13. MONTHLY DELIVERY RELIABILITY

   Business question:
   Has delivery reliability changed over time?
   ============================================================ */

SELECT
    order_month,

    order_count,

    ROUND(
        total_order_value,
        2
    ) AS total_order_value,

    ROUND(
        avg_order_value,
        2
    ) AS avg_order_value,

    ROUND(
        avg_review_score,
        2
    ) AS avg_review_score,

    ROUND(
        pct_on_time,
        2
    ) AS pct_on_time,

    ROUND(
        pct_late,
        2
    ) AS pct_late,

    ROUND(
        avg_delivery_days,
        2
    ) AS avg_delivery_days,

    ROUND(
        avg_delivery_delay_days,
        2
    ) AS avg_delivery_delay_days

FROM olist.vw_monthly_sales_performance

ORDER BY
    order_month;


/* ============================================================
   14. YEARLY DELIVERY PERFORMANCE

   Business question:
   Does overall delivery performance differ by year?
   ============================================================ */

SELECT
    order_year,

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
        100.0 * COUNT(*) FILTER (
            WHERE delivery_status = 'On Time'
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS pct_on_time,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE delivery_status = 'Late'
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS pct_late,

    ROUND(
        AVG(delivery_delay_days),
        2
    ) AS avg_delivery_delay_days

FROM olist.vw_order_delivery_metrics

GROUP BY
    order_year

ORDER BY
    order_year;


/* ============================================================
   15. DELIVERY DELAY BANDS

   Business question:
   How severe are late deliveries?

   This separates slightly late orders from severely delayed
   orders.
   ============================================================ */

SELECT
    CASE
        WHEN delivery_delay_days <= 0
            THEN 'On Time'

        WHEN delivery_delay_days <= 2
            THEN '1-2 days late'

        WHEN delivery_delay_days <= 7
            THEN '3-7 days late'

        WHEN delivery_delay_days <= 14
            THEN '8-14 days late'

        ELSE '15+ days late'
    END AS delay_band,

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
        AVG(order_value),
        2
    ) AS avg_order_value,

    ROUND(
        SUM(order_value),
        2
    ) AS total_order_value

FROM olist.vw_order_delivery_metrics

GROUP BY
    delay_band

ORDER BY
    CASE delay_band
        WHEN 'On Time' THEN 1
        WHEN '1-2 days late' THEN 2
        WHEN '3-7 days late' THEN 3
        WHEN '8-14 days late' THEN 4
        WHEN '15+ days late' THEN 5
    END;


/* ============================================================
   16. SEVERELY DELAYED ORDERS

   Business question:
   What proportion of order value is associated with orders
   that were more than 7 days late?
   ============================================================ */

SELECT

    COUNT(*) FILTER (
        WHERE delivery_delay_days > 7
    ) AS severely_delayed_orders,

    COUNT(*) AS total_orders,

    ROUND(
        100.0 *
        COUNT(*) FILTER (
            WHERE delivery_delay_days > 7
        )
        / NULLIF(COUNT(*), 0),
        2
    ) AS pct_severely_delayed_orders,

    ROUND(
        SUM(order_value) FILTER (
            WHERE delivery_delay_days > 7
        ),
        2
    ) AS severely_delayed_order_value,

    ROUND(
        SUM(order_value),
        2
    ) AS total_order_value,

    ROUND(
        100.0 *
        SUM(order_value) FILTER (
            WHERE delivery_delay_days > 7
        )
        / NULLIF(SUM(order_value), 0),
        2
    ) AS pct_order_value_severely_delayed

FROM olist.vw_order_delivery_metrics;


/* ============================================================
   17. HIGH-VALUE LATE ORDERS

   Business question:
   Are expensive orders more likely to be late?

   Orders are divided into quartiles based on order value.
   ============================================================ */

WITH value_bands AS (

    SELECT
        *,
        NTILE(4) OVER (
            ORDER BY order_value
        ) AS value_quartile

    FROM olist.vw_order_delivery_metrics

)

SELECT
    value_quartile,

    COUNT(*) AS order_count,

    ROUND(
        AVG(order_value),
        2
    ) AS avg_order_value,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE delivery_status = 'Late'
        )
        / NULLIF(COUNT(*), 0),
        2
    ) AS pct_late,

    ROUND(
        AVG(review_score),
        2
    ) AS avg_review_score

FROM value_bands

GROUP BY
    value_quartile

ORDER BY
    value_quartile;


/* ============================================================
   18. FINAL EXECUTIVE SUMMARY

   This produces a compact set of headline metrics that can
   eventually be used for the Tableau dashboard.
   ============================================================ */

SELECT

    COUNT(*) AS total_delivered_orders,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE delivery_status = 'Late'
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS pct_late,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE delivery_status = 'On Time'
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS pct_on_time,

    ROUND(
        AVG(review_score),
        2
    ) AS overall_avg_review_score,

    ROUND(
        AVG(delivery_delay_days) FILTER (
            WHERE delivery_status = 'Late'
        ),
        2
    ) AS avg_delay_among_late_orders,

    ROUND(
        SUM(order_value),
        2
    ) AS total_order_value,

    ROUND(
        SUM(order_value) FILTER (
            WHERE delivery_status = 'Late'
        ),
        2
    ) AS late_order_value,

    ROUND(
        100.0 *
        SUM(order_value) FILTER (
            WHERE delivery_status = 'Late'
        )
        / NULLIF(SUM(order_value), 0),
        2
    ) AS pct_order_value_late

FROM olist.vw_order_delivery_metrics;
