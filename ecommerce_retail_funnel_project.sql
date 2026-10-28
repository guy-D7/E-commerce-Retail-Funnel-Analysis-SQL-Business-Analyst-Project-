Drop Table If Exists campaigns;
Create Table campaigns
(
 campaign_id Varchar (10) Primary Key,
 campaign_name Varchar (25),
 channel	Varchar (15),
 objective Varchar (15),
 start_date Date,	
 end_date Date,	
 audience_type Varchar(20),	
 attribution_window_days INT
);

Drop Table If Exists customers;
Create Table customers
(
 customer_id Varchar (10) Primary Key,
 first_name Varchar (10),
 last_name Varchar (10),
 email Varchar (25),
 signup_date	Date,
 city Varchar (15),
 state Varchar (15),
 age_band Varchar (15),
 acquisition_source	Varchar (15),	
 loyalty_tier Varchar (10),	
 marketing_consent Boolean
);

CREATE TABLE products (
 product_id VARCHAR(20) PRIMARY KEY, product_name VARCHAR(255), category VARCHAR(100),
 subcategory VARCHAR(100), brand VARCHAR(100), list_price_inr NUMERIC(12,2),
 unit_cost_inr NUMERIC(12,2), launch_date DATE, is_active BOOLEAN);

CREATE TABLE sessions (
 session_id VARCHAR(20) PRIMARY KEY, customer_id VARCHAR(20) REFERENCES customers(customer_id),
 session_start TIMESTAMP, device_type VARCHAR(30), traffic_source VARCHAR(50),
 campaign_id VARCHAR(20) REFERENCES campaigns(campaign_id), landing_page VARCHAR(255),
 session_country VARCHAR(100), is_new_visitor BOOLEAN);
 
CREATE TABLE funnel_events (
 event_id VARCHAR(20) PRIMARY KEY, session_id VARCHAR(20) REFERENCES sessions(session_id),
 customer_id VARCHAR(20) REFERENCES customers(customer_id), event_timestamp TIMESTAMP,
 event_name VARCHAR(50), product_id VARCHAR(20) REFERENCES products(product_id),
 page_path VARCHAR(255), device_type VARCHAR(30), event_value_inr NUMERIC(12,2));
 
CREATE TABLE orders (
 order_id VARCHAR(20) PRIMARY KEY, customer_id VARCHAR(20) REFERENCES customers(customer_id),
 session_id VARCHAR(20) REFERENCES sessions(session_id), order_datetime TIMESTAMP,
 order_status VARCHAR(30), payment_status VARCHAR(30), subtotal_inr NUMERIC(12,2),
 discount_inr NUMERIC(12,2), shipping_fee_inr NUMERIC(12,2), tax_inr NUMERIC(12,2),
 order_total_inr NUMERIC(12,2), promo_code VARCHAR(50), fulfillment_type VARCHAR(50), delivery_days INTEGER);
 
CREATE TABLE order_items (
 order_item_id VARCHAR(20) PRIMARY KEY, order_id VARCHAR(20) REFERENCES orders(order_id),
 product_id VARCHAR(20) REFERENCES products(product_id), quantity INTEGER,
 unit_price_inr NUMERIC(12,2), item_discount_inr NUMERIC(12,2), line_total_inr NUMERIC(12,2));
 
CREATE TABLE payments (
 payment_id VARCHAR(20) PRIMARY KEY, order_id VARCHAR(20) REFERENCES orders(order_id),
 payment_method VARCHAR(50), payment_datetime TIMESTAMP, amount_inr NUMERIC(12,2),
 payment_status VARCHAR(30), gateway VARCHAR(50));
 
CREATE TABLE returns (
 return_id VARCHAR(20) PRIMARY KEY, order_id VARCHAR(20) REFERENCES orders(order_id),
 return_requested_date DATE, return_reason VARCHAR(100), return_status VARCHAR(30),
 refund_amount_inr NUMERIC(12,2), return_channel VARCHAR(50));

CREATE TABLE marketing_spend_daily (
 spend_date DATE, campaign_id VARCHAR(20) REFERENCES campaigns(campaign_id), impressions INTEGER,
 clicks INTEGER, ad_spend_inr NUMERIC(12,2), reported_conversions INTEGER, reported_revenue_inr NUMERIC(12,2),
 PRIMARY KEY(spend_date,campaign_id));
 
CREATE TABLE inventory_snapshots (
 inventory_snapshot_id VARCHAR(20) PRIMARY KEY, snapshot_date DATE,
 product_id VARCHAR(20) REFERENCES products(product_id), warehouse VARCHAR(100),
 on_hand_units INTEGER, reserved_units INTEGER, reorder_point_units INTEGER, supplier_lead_time_days INTEGER);

CREATE INDEX idx_sessions_start ON sessions(session_start);
CREATE INDEX idx_events_session_name ON funnel_events(session_id,event_name);
CREATE INDEX idx_orders_customer_date ON orders(customer_id,order_datetime);
CREATE INDEX idx_order_items_product ON order_items(product_id);



Select * From campaigns;
Select * From customers;
Select * From funnel_events;
Select * From inventory_snapshots;
Select * From marketing_spend_daily;
Select * From orders;
Select * From products;
Select * From payments;
Select * From returns;
Select * From sessions;

ALTER TABLE public.orders
ALTER COLUMN delivery_days TYPE NUMERIC
USING delivery_days::NUMERIC;

SELECT COUNT(*) AS total_orders
FROM public.orders;



-- Data Validation

SELECT 'customers' table_name,COUNT(*) rows FROM customers UNION ALL
SELECT 'products',COUNT(*) FROM products UNION ALL SELECT 'sessions',COUNT(*) FROM sessions UNION ALL
SELECT 'funnel_events',COUNT(*) FROM funnel_events UNION ALL SELECT 'orders',COUNT(*) FROM orders UNION ALL
SELECT 'order_items',COUNT(*) FROM order_items UNION ALL SELECT 'payments',COUNT(*) FROM payments UNION ALL
SELECT 'returns',COUNT(*) FROM returns UNION ALL SELECT 'campaigns',COUNT(*) FROM campaigns UNION ALL
SELECT 'marketing_spend_daily',COUNT(*) FROM marketing_spend_daily UNION ALL
SELECT 'inventory_snapshots',COUNT(*) FROM inventory_snapshots ORDER BY table_name;

-- Q1 Counts of core entities
SELECT 'customers' metric,COUNT(*) total FROM customers UNION ALL SELECT 'products',COUNT(*) FROM products
UNION ALL SELECT 'sessions',COUNT(*) FROM sessions UNION ALL SELECT 'orders',COUNT(*) FROM orders
UNION ALL SELECT 'returns',COUNT(*) FROM returns;

-- Q2 Ten most expensive products
SELECT product_id,product_name,category,list_price_inr FROM products ORDER BY list_price_inr DESC LIMIT 10;

-- Q3 Customers by state and city
SELECT state,city,COUNT(*) customer_count FROM customers GROUP BY state,city ORDER BY customer_count DESC;

-- Q4 Product count and average price by category
SELECT category,COUNT(*) product_count,ROUND(AVG(list_price_inr),2) avg_price_inr FROM products GROUP BY category;

-- Q5 Sessions by traffic source
SELECT traffic_source,COUNT(*) sessions FROM sessions GROUP BY traffic_source ORDER BY sessions DESC;

-- Q6 Sessions by device
SELECT device_type,COUNT(*) sessions FROM sessions GROUP BY device_type ORDER BY sessions DESC;

-- Q7 Orders by status
SELECT order_status,COUNT(*) orders FROM orders GROUP BY order_status ORDER BY orders DESC;

-- Q8 Monthly order value, cancelled orders excluded
SELECT
    DATE_TRUNC('month', order_datetime)::DATE AS "month",
    COUNT(*) AS total_orders,
    ROUND(SUM(order_total_inr), 2) AS booked_value_inr,
    ROUND(AVG(order_total_inr), 2) AS aov_inr
FROM public.orders
WHERE order_status <> 'cancelled'
GROUP BY DATE_TRUNC('month', order_datetime)::DATE
ORDER BY "month";

-- Q9 Payment failure rate by method
SELECT payment_method,COUNT(*) records,COUNT(*) FILTER(WHERE payment_status='failed') failed,
 ROUND(100.0*COUNT(*) FILTER(WHERE payment_status='failed')/NULLIF(COUNT(*),0),2) failure_pct
FROM payments GROUP BY payment_method ORDER BY records DESC;

-- Q10 Ten products with most units ordered, excluding cancelled orders
SELECT p.product_id,p.product_name,p.category,SUM(oi.quantity) units
FROM order_items oi JOIN products p USING(product_id) JOIN orders o USING(order_id)
WHERE o.order_status<>'cancelled' GROUP BY 1,2,3 ORDER BY units DESC LIMIT 10;

-- Q11 Marketing consent rate
SELECT COUNT(*) customers,COUNT(*) FILTER(WHERE marketing_consent) consented,
 ROUND(100.0*COUNT(*) FILTER(WHERE marketing_consent)/NULLIF(COUNT(*),0),2) consent_pct FROM customers;

-- Q12 Product-view to purchase event conversion by device
SELECT s.device_type,
 COUNT(DISTINCT s.session_id) FILTER(WHERE EXISTS(SELECT 1 FROM funnel_events e WHERE e.session_id=s.session_id AND e.event_name='view_product')) product_views,
 COUNT(DISTINCT s.session_id) FILTER(WHERE EXISTS(SELECT 1 FROM funnel_events e WHERE e.session_id=s.session_id AND e.event_name='view_product')
 AND EXISTS(SELECT 1 FROM funnel_events e WHERE e.session_id=s.session_id AND e.event_name='purchase')) converted,
 ROUND(100.0*COUNT(DISTINCT s.session_id) FILTER(WHERE EXISTS(SELECT 1 FROM funnel_events e WHERE e.session_id=s.session_id AND e.event_name='view_product')
 AND EXISTS(SELECT 1 FROM funnel_events e WHERE e.session_id=s.session_id AND e.event_name='purchase'))
 /NULLIF(COUNT(DISTINCT s.session_id) FILTER(WHERE EXISTS(SELECT 1 FROM funnel_events e WHERE e.session_id=s.session_id AND e.event_name='view_product')),0),2) conversion_pct
FROM sessions s GROUP BY s.device_type ORDER BY conversion_pct;

-- Q13 Funnel by source and campaign objective
SELECT s.traffic_source,COALESCE(c.objective,'Unassigned') objective,COUNT(DISTINCT s.session_id) sessions,
 COUNT(DISTINCT s.session_id) FILTER(WHERE EXISTS(SELECT 1 FROM funnel_events e WHERE e.session_id=s.session_id AND e.event_name='purchase')) purchase_sessions,
 ROUND(100.0*COUNT(DISTINCT s.session_id) FILTER(WHERE EXISTS(SELECT 1 FROM funnel_events e WHERE e.session_id=s.session_id AND e.event_name='purchase'))/NULLIF(COUNT(DISTINCT s.session_id),0),2) purchase_rate_pct
FROM sessions s LEFT JOIN campaigns c USING(campaign_id) GROUP BY 1,2 ORDER BY purchase_rate_pct DESC;

-- Q14 Cart abandonment before checkout by device
SELECT s.device_type,
 COUNT(DISTINCT s.session_id) FILTER(WHERE EXISTS(SELECT 1 FROM funnel_events e WHERE e.session_id=s.session_id AND e.event_name='add_to_cart')) cart_sessions,
 COUNT(DISTINCT s.session_id) FILTER(WHERE EXISTS(SELECT 1 FROM funnel_events e WHERE e.session_id=s.session_id AND e.event_name='add_to_cart')
 AND NOT EXISTS(SELECT 1 FROM funnel_events e WHERE e.session_id=s.session_id AND e.event_name='begin_checkout')) abandoned,
 ROUND(100.0*COUNT(DISTINCT s.session_id) FILTER(WHERE EXISTS(SELECT 1 FROM funnel_events e WHERE e.session_id=s.session_id AND e.event_name='add_to_cart')
 AND NOT EXISTS(SELECT 1 FROM funnel_events e WHERE e.session_id=s.session_id AND e.event_name='begin_checkout'))
 /NULLIF(COUNT(DISTINCT s.session_id) FILTER(WHERE EXISTS(SELECT 1 FROM funnel_events e WHERE e.session_id=s.session_id AND e.event_name='add_to_cart')),0),2) abandonment_pct
FROM sessions s GROUP BY s.device_type;

-- Q15 AOV, orders per buyer, repeat buyer rate
WITH co AS (SELECT customer_id,COUNT(*) n FROM orders WHERE order_status<>'cancelled' AND payment_status IN('paid','refunded') GROUP BY customer_id)
SELECT (SELECT ROUND(AVG(order_total_inr),2) FROM orders WHERE order_status<>'cancelled' AND payment_status IN('paid','refunded')) aov_inr,
 ROUND(AVG(n),2) orders_per_buyer,COUNT(*) FILTER(WHERE n>=2) repeat_buyers,COUNT(*) buyers,
 ROUND(100.0*COUNT(*) FILTER(WHERE n>=2)/NULLIF(COUNT(*),0),2) repeat_buyer_pct FROM co;
 
-- Q16 Customer acquisition source, customers, orders, AOV
SELECT c.acquisition_source,COUNT(DISTINCT c.customer_id) customers,COUNT(o.order_id) orders,
 ROUND(AVG(o.order_total_inr) FILTER(WHERE o.order_status<>'cancelled' AND o.payment_status IN('paid','refunded')),2) aov_inr
FROM customers c LEFT JOIN orders o USING(customer_id) GROUP BY c.acquisition_source ORDER BY aov_inr DESC NULLS LAST;

-- Q17 Promo vs no promo
SELECT CASE WHEN NULLIF(BTRIM(promo_code),'') IS NULL THEN 'No promo' ELSE 'Promo' END promo_group,
 COUNT(*) orders,ROUND(AVG(order_total_inr),2) avg_order_inr,ROUND(AVG(discount_inr),2) avg_discount_inr,
 ROUND(100.0*SUM(discount_inr)/NULLIF(SUM(subtotal_inr),0),2) weighted_discount_pct
FROM orders WHERE order_status<>'cancelled' GROUP BY 1;

-- Q18 Category sales, units and estimated product margin
SELECT p.category,SUM(oi.quantity) units,ROUND(SUM(oi.line_total_inr),2) item_sales_inr,
 ROUND(SUM(oi.line_total_inr-p.unit_cost_inr*oi.quantity),2) estimated_margin_inr,
 ROUND(100.0*SUM(oi.line_total_inr-p.unit_cost_inr*oi.quantity)/NULLIF(SUM(oi.line_total_inr),0),2) margin_pct
FROM order_items oi JOIN products p USING(product_id) JOIN orders o USING(order_id)
WHERE o.order_status<>'cancelled' AND o.payment_status IN('paid','refunded') GROUP BY p.category ORDER BY item_sales_inr DESC;

-- Q19 Returns/refunds by category and reason (multi-category order may appear in multiple categories)
SELECT p.category,r.return_reason,COUNT(DISTINCT r.return_id) returns,ROUND(SUM(r.refund_amount_inr),2) refunds_inr
FROM returns r JOIN order_items oi USING(order_id) JOIN products p USING(product_id)
GROUP BY p.category,r.return_reason ORDER BY returns DESC;

-- Q20 Median/average delivery days by outcome and whether return record exists
SELECT o.order_status,CASE WHEN r.order_id IS NULL THEN 'No return' ELSE 'Has return' END return_group,
 COUNT(*) orders,ROUND(AVG(o.delivery_days),2) avg_delivery_days,
 PERCENTILE_CONT(.5) WITHIN GROUP(ORDER BY o.delivery_days) median_delivery_days
FROM orders o LEFT JOIN (SELECT DISTINCT order_id FROM returns) r USING(order_id)
WHERE o.delivery_days IS NOT NULL GROUP BY 1,2;

-- Q21 Marketing CTR, CPC, conversion rate and ROAS by channel
SELECT c.channel,SUM(m.impressions) impressions,SUM(m.clicks) clicks,ROUND(SUM(m.ad_spend_inr),2) spend_inr,
 SUM(m.reported_conversions) reported_conversions,ROUND(100.0*SUM(m.clicks)/NULLIF(SUM(m.impressions),0),2) ctr_pct,
 ROUND(SUM(m.ad_spend_inr)/NULLIF(SUM(m.clicks),0),2) cpc_inr,
 ROUND(100.0*SUM(m.reported_conversions)/NULLIF(SUM(m.clicks),0),2) reported_conversion_pct,
 ROUND(SUM(m.reported_revenue_inr)/NULLIF(SUM(m.ad_spend_inr),0),2) reported_roas
FROM marketing_spend_daily m JOIN campaigns c USING(campaign_id) GROUP BY c.channel ORDER BY reported_roas DESC;

-- Q22 Cities above average order count but below average city AOV
WITH cm AS (SELECT c.city,COUNT(o.order_id) FILTER(WHERE o.order_status<>'cancelled') orders,
 AVG(o.order_total_inr) FILTER(WHERE o.order_status<>'cancelled') aov
 FROM customers c LEFT JOIN orders o USING(customer_id) GROUP BY c.city),
 b AS(SELECT AVG(orders) avg_orders,AVG(aov) avg_aov FROM cm)
SELECT cm.city,cm.orders,ROUND(cm.aov,2) aov_inr FROM cm CROSS JOIN b WHERE cm.orders>b.avg_orders AND cm.aov<b.avg_aov ORDER BY cm.orders DESC;

-- Q23 Latest stock at/below reorder point
WITH l AS(SELECT MAX(snapshot_date) d FROM inventory_snapshots)
SELECT i.snapshot_date,i.warehouse,p.product_id,p.product_name,i.on_hand_units,i.reserved_units,
 i.on_hand_units-i.reserved_units available_units,i.reorder_point_units,i.supplier_lead_time_days
FROM inventory_snapshots i JOIN l ON i.snapshot_date=l.d JOIN products p USING(product_id)
WHERE i.on_hand_units-i.reserved_units<=i.reorder_point_units ORDER BY available_units,i.supplier_lead_time_days DESC;

-- Q24 Payment paid rate by method
SELECT payment_method,COUNT(*) payment_records,COUNT(*) FILTER(WHERE payment_status='paid') paid,
 ROUND(100.0*COUNT(*) FILTER(WHERE payment_status='paid')/NULLIF(COUNT(*),0),2) paid_rate_pct,
 COUNT(*) FILTER(WHERE payment_status='failed') failed FROM payments GROUP BY payment_method ORDER BY paid_rate_pct DESC;

-- Q25 Event purchase rate by new/returning visitor and device
SELECT is_new_visitor,device_type,COUNT(*) sessions,
 COUNT(*) FILTER(WHERE EXISTS(SELECT 1 FROM funnel_events e WHERE e.session_id=s.session_id AND e.event_name='purchase')) purchase_event_sessions,
 ROUND(100.0*COUNT(*) FILTER(WHERE EXISTS(SELECT 1 FROM funnel_events e WHERE e.session_id=s.session_id AND e.event_name='purchase'))/NULLIF(COUNT(*),0),2) purchase_rate_pct
FROM sessions s GROUP BY is_new_visitor,device_type ORDER BY purchase_rate_pct DESC;

-- Q26 Signup-month cohort repeat rate (observed multiple-order proxy, not a strict 30-day repeat metric)
WITH x AS(SELECT c.customer_id,DATE_TRUNC('month',c.signup_date)::date signup_month,c.signup_date,
 COUNT(o.order_id) FILTER(WHERE o.order_status<>'cancelled' AND o.payment_status IN('paid','refunded')) valid_orders
 FROM customers c LEFT JOIN orders o USING(customer_id) GROUP BY c.customer_id,c.signup_date)
SELECT signup_month,COUNT(*) customers,COUNT(*) FILTER(WHERE valid_orders>=2) repeat_customers,
 ROUND(100.0*COUNT(*) FILTER(WHERE valid_orders>=2)/NULLIF(COUNT(*),0),2) observed_repeat_pct
FROM x WHERE signup_date<=CURRENT_DATE-INTERVAL '30 days' GROUP BY signup_month ORDER BY signup_month;

































