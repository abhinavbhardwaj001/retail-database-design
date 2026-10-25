-- Decision-support queries Q1-Q8 (PostgreSQL)

-- Q1 | Monthly revenue trend | Tracks orders, revenue and average order value (AOV) per month so management can see growth and seasonality.
SELECT DATE_TRUNC('month', o.order_date)::date AS month,
       COUNT(*)                                AS orders,
       SUM(o.total_amount)                     AS revenue,
       ROUND(AVG(o.total_amount), 2)           AS avg_order_value
FROM   orders o
WHERE  o.status NOT IN ('CANCELLED', 'RETURNED')
GROUP  BY 1
ORDER  BY 1;

-- Q2 | Top 10 products by revenue and gross profit | Shows which products drive sales and margin; supports ranging and promotion decisions.
SELECT p.sku,
       p.product_name,
       SUM(oi.quantity)                                              AS units_sold,
       SUM(oi.quantity * oi.unit_price - oi.discount_amount)         AS revenue,
       SUM(oi.quantity * (oi.unit_price - p.cost_price)
           - oi.discount_amount)                                     AS gross_profit
FROM   order_items oi
JOIN   orders   o ON o.order_id   = oi.order_id
JOIN   products p ON p.product_id = oi.product_id
WHERE  o.status NOT IN ('CANCELLED', 'RETURNED')
GROUP  BY p.product_id, p.sku, p.product_name
ORDER  BY revenue DESC
LIMIT  10;

-- Q3 | Low-stock replenishment report | Lists every product/warehouse pair at or below its reorder level so buyers know what to order and how much.
SELECT w.warehouse_name,
       p.sku,
       p.product_name,
       i.quantity_on_hand,
       i.reorder_level,
       i.reorder_quantity
FROM   inventory  i
JOIN   products   p ON p.product_id   = i.product_id
JOIN   warehouses w ON w.warehouse_id = i.warehouse_id
WHERE  i.quantity_on_hand <= i.reorder_level
  AND  p.is_active
ORDER  BY i.quantity_on_hand - i.reorder_level, w.warehouse_name;

-- Q4 | Customer lifetime value and segmentation | Ranks customers by lifetime spend, splits them into quartiles and shows recency, for CRM campaigns.
WITH cust AS (
    SELECT c.customer_id,
           c.first_name || ' ' || c.last_name AS customer_name,
           COUNT(o.order_id)                  AS orders,
           SUM(o.total_amount)                AS lifetime_value,
           MAX(o.order_date)                  AS last_order
    FROM   customers c
    JOIN   orders    o ON o.customer_id = c.customer_id
    WHERE  o.status NOT IN ('CANCELLED', 'RETURNED')
    GROUP  BY c.customer_id, c.first_name, c.last_name
)
SELECT customer_id,
       customer_name,
       orders,
       lifetime_value,
       NTILE(4) OVER (ORDER BY lifetime_value DESC) AS value_quartile,
       CURRENT_DATE - last_order::date              AS days_since_last_order
FROM   cust
ORDER  BY lifetime_value DESC;

-- Q5 | Supplier performance scorecard | Compares suppliers on delivery speed, on-time rate and fill rate to guide vendor negotiations.
WITH po_stats AS (
    SELECT po.po_id,
           po.supplier_id,
           po.received_date - po.po_date                       AS days_to_receive,
           (po.received_date <= po.expected_date)::int         AS on_time,
           SUM(poi.quantity_ordered)                           AS ordered,
           SUM(poi.quantity_received)                          AS received
    FROM   purchase_orders      po
    JOIN   purchase_order_items poi ON poi.po_id = po.po_id
    WHERE  po.po_status IN ('RECEIVED', 'PARTIAL')
    GROUP  BY po.po_id, po.supplier_id, po.received_date, po.po_date, po.expected_date
)
SELECT s.supplier_name,
       COUNT(*)                                          AS purchase_orders,
       ROUND(AVG(ps.days_to_receive), 1)                 AS avg_days_to_receive,
       ROUND(100.0 * AVG(ps.on_time), 1)                 AS on_time_pct,
       ROUND(100.0 * SUM(ps.received) / NULLIF(SUM(ps.ordered), 0), 1) AS fill_rate_pct
FROM   po_stats ps
JOIN   suppliers s ON s.supplier_id = ps.supplier_id
GROUP  BY s.supplier_id, s.supplier_name
ORDER  BY on_time_pct DESC;

-- Q6 | Category revenue share | Shows each category's contribution to total sales using a window function.
SELECT c.category_name,
       SUM(oi.quantity * oi.unit_price - oi.discount_amount) AS revenue,
       ROUND(100.0 * SUM(oi.quantity * oi.unit_price - oi.discount_amount)
             / SUM(SUM(oi.quantity * oi.unit_price - oi.discount_amount)) OVER (), 2) AS pct_of_total
FROM   order_items oi
JOIN   orders     o ON o.order_id    = oi.order_id
JOIN   products   p ON p.product_id  = oi.product_id
JOIN   categories c ON c.category_id = p.category_id
WHERE  o.status NOT IN ('CANCELLED', 'RETURNED')
GROUP  BY c.category_id, c.category_name
ORDER  BY revenue DESC;

-- Q7 | Repeat-customer rate | Measures loyalty: the share of buying customers who ordered more than once.
SELECT ROUND(100.0 * COUNT(*) FILTER (WHERE order_count > 1) / COUNT(*), 1) AS repeat_customer_pct
FROM  (SELECT customer_id, COUNT(*) AS order_count
       FROM   orders
       WHERE  status NOT IN ('CANCELLED', 'RETURNED')
       GROUP  BY customer_id) t;

-- Q8 | Stock reconciliation check | Data-quality query: compares the stored stock level with the sum of the audit ledger and flags drift.
SELECT i.warehouse_id,
       i.product_id,
       i.quantity_on_hand,
       COALESCE(SUM(t.quantity_change), 0) AS ledger_balance
FROM   inventory i
LEFT   JOIN inventory_transactions t
       ON  t.warehouse_id = i.warehouse_id
       AND t.product_id   = i.product_id
GROUP  BY i.warehouse_id, i.product_id, i.quantity_on_hand
HAVING i.quantity_on_hand <> COALESCE(SUM(t.quantity_change), 0);
