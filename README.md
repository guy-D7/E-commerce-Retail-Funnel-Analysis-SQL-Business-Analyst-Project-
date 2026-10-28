# E-commerce-Retail-Funnel-Analysis-SQL-Business-Analyst-Project-
A PostgreSQL business analysis of an Indian e-commerce retailer, covering traffic, conversion funnel, orders, payments, returns, marketing performance, and inventory. The project frames each analysis as a business problem, answers it with SQL, and ends with an action the business can take.

## Business Context

The retailer sells across multiple product categories to customers in several Indian cities. Leadership wants to grow revenue without proportionally growing ad spend, which means finding where the funnel leaks, which channels and customers are actually profitable, and which operational issues (payments, returns, stock) cost sales.

**Objectives**
1. Find and size funnel drop-off points
2. Identify the channels and customer segments that deliver real value
3. Reduce revenue leakage from failed payments, returns, and promotions
4. Prevent lost sales from stockouts

## Database Schema

Eleven relational tables (currency in INR):

| Table | Description |
|---|---|
| `customers` | Profile, city/state, age band, acquisition source, loyalty tier, marketing consent |
| `products` | Category, brand, list price, unit cost, launch date |
| `sessions` | Web sessions with device, traffic source, campaign, new/returning flag |
| `funnel_events` | Event stream per session (e.g. `view_product`, `add_to_cart`, `begin_checkout`, `purchase`) |
| `orders` | Status, payment status, subtotal, discount, shipping, tax, total, promo, delivery days |
| `order_items` | Line items with quantity, price, discount |
| `payments` | Method, gateway, status, amount |
| `returns` | Reason, status, refund amount, channel |
| `campaigns` | Channel, objective, audience, attribution window |
| `marketing_spend_daily` | Daily impressions, clicks, spend, reported conversions and revenue |
| `inventory_snapshots` | On-hand, reserved, reorder point, supplier lead time |

Foreign keys link sessions, events, orders, items, payments, and returns to customers, products, and campaigns. Indexes cover session start, event lookups, customer/order date, and order item product.

## Entity Relationship Diagram (ERD)

<img width="1227" height="982" alt="image" src="https://github.com/user-attachments/assets/63b66f43-1bd5-49a4-81db-829ef022d534" />


## Business Problems and Solutions

Each problem lists the question, the SQL approach, what to look for in the output, and the recommended action.

### Problem 1: Where does the funnel leak?
- **Question:** Of the shoppers who view products and add to cart, how many never reach checkout or purchase, and does it differ by device?
- **Queries:** Q12 (view to purchase by device), Q14 (cart abandonment by device), Q25 (purchase rate by new/returning visitor and device)
- **Approach:** Session-level funnel using `EXISTS` / `NOT EXISTS` on `funnel_events`, so each session is counted once per stage.
- **Look for:** The device and visitor type with the highest abandonment and lowest purchase rate.
- **Solution:** Prioritize checkout UX fixes on the weakest device, add cart-recovery reminders for consented customers, and use a different offer for new vs returning visitors.

### Problem 2: Which traffic and campaigns bring buyers, not just clicks?
- **Question:** Which sources and campaign objectives turn sessions into purchases, and how do paid channels compare on cost efficiency?
- **Queries:** Q5, Q6 (traffic mix), Q13 (purchase rate by source and objective), Q21 (CTR, CPC, ROAS by channel)
- **Approach:** Join sessions to campaigns for conversion by source and objective; aggregate daily spend for channel efficiency.
- **Look for:** Channels with high clicks but low purchase rate, and channels where reported ROAS is strong but session conversion is weak.
- **Solution:** Shift budget from high-traffic, low-conversion sources to those with higher purchase rate and ROAS. Validate platform-reported ROAS against Q13 before scaling spend.

### Problem 3: Which customers are worth acquiring and keeping?
- **Question:** Which acquisition sources bring higher-value customers, and how many customers come back?
- **Queries:** Q15 (AOV, orders per buyer, repeat rate), Q16 (acquisition source performance), Q26 (signup-month cohort repeat rate), Q11 (marketing consent)
- **Approach:** Customer-level order counts with valid-order filters, cohort grouping by signup month, and consent rate for reachable audience.
- **Look for:** Sources with higher AOV, cohorts with weak repeat rate, and how much of the base can actually be messaged.
- **Solution:** Fund acquisition sources with the best AOV and repeat behavior, launch a post-first-purchase lifecycle campaign for weak cohorts, and run a consent-capture push to grow the reachable audience.

### Problem 4: Are promotions growing the business or just giving away margin?
- **Question:** Do promo orders have a higher order value, and how deep are the discounts?
- **Queries:** Q17 (promo vs no promo), Q18 (category sales and margin)
- **Approach:** Compare average order value and weighted discount percent across promo groups; estimate margin from product unit cost.
- **Look for:** Promo orders with similar AOV to non-promo orders (discount without lift) and low-margin categories receiving heavy discounts.
- **Solution:** Cap discount depth, restrict promos to categories with healthy margin, and use minimum-basket thresholds so promos raise AOV.

### Problem 5: Where is revenue lost to payments, returns, and delivery?
- **Question:** Which payment methods fail most, why do customers return products, and does slow delivery relate to returns?
- **Queries:** Q9 (failure rate by method), Q24 (paid rate by method), Q19 (returns and refunds by category and reason), Q20 (delivery days by outcome), Q7 (order status mix)
- **Approach:** Rate calculations with `FILTER`, return joins to order items and products, and median delivery time using `PERCENTILE_CONT`.
- **Look for:** Payment methods with the lowest paid rate, categories and reasons driving the most refund value, and longer delivery times among returned or failed orders.
- **Solution:** Reorder or fix weak payment methods with the gateway, fix product content or quality for the top return reasons, and tighten delivery SLAs with the slowest fulfillment types.

### Problem 6: What drives revenue, and where are the growth pockets?
- **Question:** How is revenue trending, which products and categories lead, and which cities order often but spend little?
- **Queries:** Q8 (monthly orders, value, AOV), Q10 (top products by units), Q2, Q4 (catalog price view), Q3 (customer geography), Q22 (high-order, low-AOV cities)
- **Approach:** Monthly trend with `DATE_TRUNC`, product and category rankings, and a CTE benchmark comparing each city to the overall average.
- **Look for:** Seasonality, best sellers that should never stock out, and cities where frequent buyers have a low basket size.
- **Solution:** Plan inventory and campaigns around peak months, set free-shipping or bundle thresholds in low-AOV cities, and promote best sellers with strong margin.

### Problem 7: Which products risk stockouts?
- **Question:** Which products are at or below their reorder point, and which are most urgent given supplier lead time?
- **Queries:** Q23
- **Approach:** Latest snapshot per warehouse, available units as on-hand minus reserved, ranked by lowest availability and longest lead time.
- **Look for:** Best sellers (cross-check with Q10) that are low on stock with long lead times.
- **Solution:** Raise purchase orders first for items that are both fast-selling and slow to resupply.

## Key Business Queries

The core SQL behind each business problem (formatted for readability; full list in the `.sql` file).

### Problem 1: Funnel leakage

**Q14: Cart abandonment before checkout by device**
```sql
SELECT s.device_type,
  COUNT(*) FILTER (WHERE EXISTS (SELECT 1 FROM funnel_events e
        WHERE e.session_id = s.session_id AND e.event_name = 'add_to_cart')) AS cart_sessions,
  COUNT(*) FILTER (WHERE EXISTS (SELECT 1 FROM funnel_events e
        WHERE e.session_id = s.session_id AND e.event_name = 'add_to_cart')
      AND NOT EXISTS (SELECT 1 FROM funnel_events e
        WHERE e.session_id = s.session_id AND e.event_name = 'begin_checkout')) AS abandoned,
  ROUND(100.0 * COUNT(*) FILTER (WHERE EXISTS (SELECT 1 FROM funnel_events e
        WHERE e.session_id = s.session_id AND e.event_name = 'add_to_cart')
      AND NOT EXISTS (SELECT 1 FROM funnel_events e
        WHERE e.session_id = s.session_id AND e.event_name = 'begin_checkout'))
    / NULLIF(COUNT(*) FILTER (WHERE EXISTS (SELECT 1 FROM funnel_events e
        WHERE e.session_id = s.session_id AND e.event_name = 'add_to_cart')), 0), 2) AS abandonment_pct
FROM sessions s
GROUP BY s.device_type;
```
*Business use:* shows which device loses the most shoppers after add-to-cart, so checkout fixes and recovery reminders go where they matter.

**Q25: Purchase rate by new/returning visitor and device**
```sql
SELECT is_new_visitor, device_type, COUNT(*) AS sessions,
  COUNT(*) FILTER (WHERE EXISTS (SELECT 1 FROM funnel_events e
        WHERE e.session_id = s.session_id AND e.event_name = 'purchase')) AS purchase_sessions,
  ROUND(100.0 * COUNT(*) FILTER (WHERE EXISTS (SELECT 1 FROM funnel_events e
        WHERE e.session_id = s.session_id AND e.event_name = 'purchase'))
    / NULLIF(COUNT(*), 0), 2) AS purchase_rate_pct
FROM sessions s
GROUP BY is_new_visitor, device_type
ORDER BY purchase_rate_pct DESC;
```
*Business use:* separates acquisition problems (new visitors) from retention opportunities (returning visitors).

### Problem 2: Channel effectiveness

**Q13: Purchase rate by traffic source and campaign objective**
```sql
SELECT s.traffic_source, COALESCE(c.objective, 'Unassigned') AS objective,
  COUNT(DISTINCT s.session_id) AS sessions,
  COUNT(DISTINCT s.session_id) FILTER (WHERE EXISTS (SELECT 1 FROM funnel_events e
        WHERE e.session_id = s.session_id AND e.event_name = 'purchase')) AS purchase_sessions,
  ROUND(100.0 * COUNT(DISTINCT s.session_id) FILTER (WHERE EXISTS (SELECT 1 FROM funnel_events e
        WHERE e.session_id = s.session_id AND e.event_name = 'purchase'))
    / NULLIF(COUNT(DISTINCT s.session_id), 0), 2) AS purchase_rate_pct
FROM sessions s
LEFT JOIN campaigns c USING (campaign_id)
GROUP BY 1, 2
ORDER BY purchase_rate_pct DESC;
```
*Business use:* ranks sources by actual purchases rather than traffic volume.

**Q21: CTR, CPC, conversion rate and ROAS by channel**
```sql
SELECT c.channel,
  SUM(m.impressions) AS impressions, SUM(m.clicks) AS clicks,
  ROUND(SUM(m.ad_spend_inr), 2) AS spend_inr,
  ROUND(100.0 * SUM(m.clicks) / NULLIF(SUM(m.impressions), 0), 2) AS ctr_pct,
  ROUND(SUM(m.ad_spend_inr) / NULLIF(SUM(m.clicks), 0), 2) AS cpc_inr,
  ROUND(SUM(m.reported_revenue_inr) / NULLIF(SUM(m.ad_spend_inr), 0), 2) AS reported_roas
FROM marketing_spend_daily m
JOIN campaigns c USING (campaign_id)
GROUP BY c.channel
ORDER BY reported_roas DESC;
```
*Business use:* guides budget reallocation across channels.

### Problem 3: Customer value and retention

**Q15: AOV, orders per buyer, repeat buyer rate**
```sql
WITH co AS (
  SELECT customer_id, COUNT(*) AS n
  FROM orders
  WHERE order_status <> 'cancelled' AND payment_status IN ('paid', 'refunded')
  GROUP BY customer_id
)
SELECT
  (SELECT ROUND(AVG(order_total_inr), 2) FROM orders
    WHERE order_status <> 'cancelled' AND payment_status IN ('paid', 'refunded')) AS aov_inr,
  ROUND(AVG(n), 2) AS orders_per_buyer,
  COUNT(*) FILTER (WHERE n >= 2) AS repeat_buyers,
  COUNT(*) AS buyers,
  ROUND(100.0 * COUNT(*) FILTER (WHERE n >= 2) / NULLIF(COUNT(*), 0), 2) AS repeat_buyer_pct
FROM co;
```
*Business use:* sets baseline AOV and repeat rate targets for loyalty and upsell programs.

**Q26: Signup-month cohort repeat rate**
```sql
WITH x AS (
  SELECT c.customer_id, DATE_TRUNC('month', c.signup_date)::date AS signup_month, c.signup_date,
    COUNT(o.order_id) FILTER (WHERE o.order_status <> 'cancelled'
      AND o.payment_status IN ('paid', 'refunded')) AS valid_orders
  FROM customers c
  LEFT JOIN orders o USING (customer_id)
  GROUP BY c.customer_id, c.signup_date
)
SELECT signup_month, COUNT(*) AS customers,
  COUNT(*) FILTER (WHERE valid_orders >= 2) AS repeat_customers,
  ROUND(100.0 * COUNT(*) FILTER (WHERE valid_orders >= 2) / NULLIF(COUNT(*), 0), 2) AS observed_repeat_pct
FROM x
WHERE signup_date <= CURRENT_DATE - INTERVAL '30 days'
GROUP BY signup_month
ORDER BY signup_month;
```
*Business use:* reveals which signup cohorts need lifecycle campaigns.

### Problem 4: Promotions and margin

**Q17: Promo vs no promo**
```sql
SELECT CASE WHEN NULLIF(BTRIM(promo_code), '') IS NULL THEN 'No promo' ELSE 'Promo' END AS promo_group,
  COUNT(*) AS orders,
  ROUND(AVG(order_total_inr), 2) AS avg_order_inr,
  ROUND(AVG(discount_inr), 2) AS avg_discount_inr,
  ROUND(100.0 * SUM(discount_inr) / NULLIF(SUM(subtotal_inr), 0), 2) AS weighted_discount_pct
FROM orders
WHERE order_status <> 'cancelled'
GROUP BY 1;
```
*Business use:* tests whether promos lift order value enough to justify the discount.

**Q18: Category sales, units and estimated margin**
```sql
SELECT p.category, SUM(oi.quantity) AS units,
  ROUND(SUM(oi.line_total_inr), 2) AS item_sales_inr,
  ROUND(SUM(oi.line_total_inr - p.unit_cost_inr * oi.quantity), 2) AS estimated_margin_inr,
  ROUND(100.0 * SUM(oi.line_total_inr - p.unit_cost_inr * oi.quantity)
    / NULLIF(SUM(oi.line_total_inr), 0), 2) AS margin_pct
FROM order_items oi
JOIN products p USING (product_id)
JOIN orders o USING (order_id)
WHERE o.order_status <> 'cancelled' AND o.payment_status IN ('paid', 'refunded')
GROUP BY p.category
ORDER BY item_sales_inr DESC;
```
*Business use:* identifies which categories deserve promotion and which are too thin to discount.

### Problem 5: Revenue leakage

**Q9: Payment failure rate by method**
```sql
SELECT payment_method, COUNT(*) AS records,
  COUNT(*) FILTER (WHERE payment_status = 'failed') AS failed,
  ROUND(100.0 * COUNT(*) FILTER (WHERE payment_status = 'failed')
    / NULLIF(COUNT(*), 0), 2) AS failure_pct
FROM payments
GROUP BY payment_method
ORDER BY records DESC;
```
*Business use:* pinpoints payment methods or gateways that cost sales.

**Q19: Returns and refunds by category and reason**
```sql
SELECT p.category, r.return_reason,
  COUNT(DISTINCT r.return_id) AS returns,
  ROUND(SUM(r.refund_amount_inr), 2) AS refunds_inr
FROM returns r
JOIN order_items oi USING (order_id)
JOIN products p USING (product_id)
GROUP BY p.category, r.return_reason
ORDER BY returns DESC;
```
*Business use:* directs product, content, and supplier fixes to the biggest return drivers.

**Q20: Delivery days by order outcome and return status**
```sql
SELECT o.order_status,
  CASE WHEN r.order_id IS NULL THEN 'No return' ELSE 'Has return' END AS return_group,
  COUNT(*) AS orders,
  ROUND(AVG(o.delivery_days), 2) AS avg_delivery_days,
  PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.delivery_days) AS median_delivery_days
FROM orders o
LEFT JOIN (SELECT DISTINCT order_id FROM returns) r USING (order_id)
WHERE o.delivery_days IS NOT NULL
GROUP BY 1, 2;
```
*Business use:* tests whether slow delivery is linked to returns and poor outcomes.

### Problem 6: Growth pockets

**Q8: Monthly order value (cancelled excluded)**
```sql
SELECT DATE_TRUNC('month', order_datetime)::DATE AS month,
  COUNT(*) AS total_orders,
  ROUND(SUM(order_total_inr), 2) AS booked_value_inr,
  ROUND(AVG(order_total_inr), 2) AS aov_inr
FROM orders
WHERE order_status <> 'cancelled'
GROUP BY 1
ORDER BY 1;
```
*Business use:* reveals trend and seasonality for planning inventory and campaigns.

**Q22: Cities with above-average orders but below-average AOV**
```sql
WITH cm AS (
  SELECT c.city,
    COUNT(o.order_id) FILTER (WHERE o.order_status <> 'cancelled') AS orders,
    AVG(o.order_total_inr) FILTER (WHERE o.order_status <> 'cancelled') AS aov
  FROM customers c
  LEFT JOIN orders o USING (customer_id)
  GROUP BY c.city
),
b AS (SELECT AVG(orders) AS avg_orders, AVG(aov) AS avg_aov FROM cm)
SELECT cm.city, cm.orders, ROUND(cm.aov, 2) AS aov_inr
FROM cm CROSS JOIN b
WHERE cm.orders > b.avg_orders AND cm.aov < b.avg_aov
ORDER BY cm.orders DESC;
```
*Business use:* finds cities where frequent buyers have small baskets, ideal for bundles and free-shipping thresholds.

### Problem 7: Stock risk

**Q23: Latest stock at or below reorder point**
```sql
WITH l AS (SELECT MAX(snapshot_date) AS d FROM inventory_snapshots)
SELECT i.snapshot_date, i.warehouse, p.product_id, p.product_name,
  i.on_hand_units, i.reserved_units,
  i.on_hand_units - i.reserved_units AS available_units,
  i.reorder_point_units, i.supplier_lead_time_days
FROM inventory_snapshots i
JOIN l ON i.snapshot_date = l.d
JOIN products p USING (product_id)
WHERE i.on_hand_units - i.reserved_units <= i.reorder_point_units
ORDER BY available_units, i.supplier_lead_time_days DESC;
```
*Business use:* produces a replenishment priority list, weighted by supplier lead time.

## Query Index

| # | Analysis | Problem |
|---|---|---|
| Validation | Row counts for all tables | Data quality |
| Q1 | Core entity counts | Baseline |
| Q2 | Top 10 most expensive products | 6 |
| Q3 | Customers by state and city | 6 |
| Q4 | Product count and average price by category | 6 |
| Q5 | Sessions by traffic source | 2 |
| Q6 | Sessions by device | 2 |
| Q7 | Orders by status | 5 |
| Q8 | Monthly orders, booked value, AOV | 6 |
| Q9 | Payment failure rate by method | 5 |
| Q10 | Top 10 products by units ordered | 6, 7 |
| Q11 | Marketing consent rate | 3 |
| Q12 | Product view to purchase by device | 1 |
| Q13 | Purchase rate by traffic source and campaign objective | 2 |
| Q14 | Cart abandonment before checkout by device | 1 |
| Q15 | AOV, orders per buyer, repeat buyer rate | 3 |
| Q16 | Customers, orders, AOV by acquisition source | 3 |
| Q17 | Promo vs no-promo orders | 4 |
| Q18 | Category sales, units, estimated margin | 4, 6 |
| Q19 | Returns and refunds by category and reason | 5 |
| Q20 | Delivery days by order outcome and return status | 5 |
| Q21 | CTR, CPC, conversion rate, ROAS by channel | 2 |
| Q22 | Cities with above-average orders but below-average AOV | 6 |
| Q23 | Latest stock at or below reorder point | 7 |
| Q24 | Payment paid rate by method | 5 |
| Q25 | Purchase rate by new/returning visitor and device | 1 |
| Q26 | Signup-month cohort repeat rate | 3 |

## Priority Recommendations

| Priority | Action | Based on |
|---|---|---|
| High | Fix checkout friction and add cart recovery on the weakest device | Q12, Q14, Q25 |
| High | Reallocate ad budget to channels with the best purchase rate and ROAS | Q13, Q21 |
| High | Resolve weakest payment method failures | Q9, Q24 |
| Medium | Cap promo depth and limit promos to healthy-margin categories | Q17, Q18 |
| Medium | Address top return reasons in the worst categories | Q19, Q20 |
| Medium | Build lifecycle campaigns for low-repeat cohorts | Q15, Q26 |
| Ongoing | Replenish fast-selling, long-lead-time products first | Q10, Q23 |

## Skills Demonstrated

- **Business analysis**: problem framing, KPI definition, funnel and cohort thinking, actionable recommendations
- **Schema design**: DDL, primary and foreign keys, indexes, type changes
- **SQL**: joins, CTEs, subqueries with `EXISTS` / `NOT EXISTS`, `FILTER`, `NULLIF`, `PERCENTILE_CONT`, `DATE_TRUNC`
- **Data validation**: row-count reconciliation across tables

## Metric Definitions

- **Valid order**: `order_status <> 'cancelled'`; revenue metrics also require `payment_status IN ('paid','refunded')`
- **AOV**: average `order_total_inr` of valid orders
- **Repeat buyer**: customer with 2 or more valid orders
- **Cart abandonment**: sessions with `add_to_cart` but no `begin_checkout`, divided by sessions with `add_to_cart`
- **Estimated margin**: `line_total_inr - unit_cost_inr * quantity`
- **ROAS**: reported revenue / ad spend (platform-reported)
- **Available stock**: `on_hand_units - reserved_units`

## Notes and Caveats

- Q19 joins returns to order items, so multi-category orders can appear under more than one category.
- Q26 is an observed multiple-order proxy for repeat rate, not a strict 30-day repeat metric.
- ROAS uses platform-reported figures, which may overstate true attribution.
- Funnel queries count distinct sessions containing an event, regardless of event order.
- Q8 and Q22 filter on `order_status` only, while other revenue queries also require paid or refunded status.

## How to Run

1. Create a PostgreSQL database (v12+).
2. Run the DDL section of `ecommerce_retail_funnel_project.sql` to create tables and indexes.
3. Load your CSV data into each table (e.g. `\copy` in psql or pgAdmin import).
4. Run the validation query to confirm row counts.
5. Execute Q1 to Q26 individually.

## Tools

PostgreSQL, pgAdmin / psql

## Author

Doyen Deb, Bengaluru, India
