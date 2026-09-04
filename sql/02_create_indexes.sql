-- Indexes improve joins and query performance.

CREATE INDEX IF NOT EXISTS idx_orders_customer_id
    ON olist.orders (customer_id);

CREATE INDEX IF NOT EXISTS idx_orders_status
    ON olist.orders (order_status);

CREATE INDEX IF NOT EXISTS idx_orders_purchase_date
    ON olist.orders (order_purchase_timestamp);

CREATE INDEX IF NOT EXISTS idx_order_items_product_id
    ON olist.order_items (product_id);

CREATE INDEX IF NOT EXISTS idx_order_items_seller_id
    ON olist.order_items (seller_id);

CREATE INDEX IF NOT EXISTS idx_payments_order_id
    ON olist.order_payments (order_id);

CREATE INDEX IF NOT EXISTS idx_reviews_order_id
    ON olist.order_reviews (order_id);

CREATE INDEX IF NOT EXISTS idx_customers_state
    ON olist.customers (customer_state);
