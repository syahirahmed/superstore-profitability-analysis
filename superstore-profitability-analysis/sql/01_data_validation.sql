/* ============================================================
   01_data_validation.sql
   Purpose : Verify the load is complete and internally consistent
             before any analysis is trusted.
   ============================================================ */

/* ------------------------------------------------------------
   1. Row count and load integrity
   ------------------------------------------------------------
   The authoritative figure for this dataset is 9,994 rows.
   An initial import returned 10,006 rows: an earlier misaligned
   import had not been truncated before reloading, so 12 broken
   fragment rows persisted underneath the good data. Row count is
   therefore the first and cheapest integrity signal.
   ------------------------------------------------------------ */

SELECT COUNT(*) AS row_count FROM orders;   -- must be exactly 9994


/* ------------------------------------------------------------
   2. Uniqueness of the surrogate key
   ------------------------------------------------------------
   row_id is the source file line number and must never repeat.
   Any duplicate here means a partial or doubled import.
   ------------------------------------------------------------ */

SELECT row_id, COUNT(*) AS occurrences
FROM orders
GROUP BY row_id
HAVING COUNT(*) > 1
ORDER BY row_id;                            -- expect 0 rows

SELECT MIN(row_id) AS min_row_id,
       MAX(row_id) AS max_row_id
FROM orders;                                -- expect 1 .. 9994


/* ------------------------------------------------------------
   3. Column misalignment check
   ------------------------------------------------------------
   A quoting failure during import manifests as NULLs concentrated
   in the columns that were pushed past the end of the row, while
   text columns further left still appear populated. Checking the
   key columns catches this pattern directly.
   ------------------------------------------------------------ */

SELECT * FROM orders WHERE row_id IS NULL;  -- expect 0 rows


/* ------------------------------------------------------------
   4. Completeness across all analytical columns
   ------------------------------------------------------------ */

SELECT
    COUNT(*) FILTER (WHERE row_id        IS NULL) AS null_row_id,
    COUNT(*) FILTER (WHERE order_id      IS NULL) AS null_order_id,
    COUNT(*) FILTER (WHERE order_date    IS NULL) AS null_order_date,
    COUNT(*) FILTER (WHERE ship_date     IS NULL) AS null_ship_date,
    COUNT(*) FILTER (WHERE customer_id   IS NULL) AS null_customer_id,
    COUNT(*) FILTER (WHERE customer_name IS NULL) AS null_customer_name,
    COUNT(*) FILTER (WHERE region        IS NULL) AS null_region,
    COUNT(*) FILTER (WHERE state         IS NULL) AS null_state,
    COUNT(*) FILTER (WHERE category      IS NULL) AS null_category,
    COUNT(*) FILTER (WHERE sub_category  IS NULL) AS null_sub_category,
    COUNT(*) FILTER (WHERE sales         IS NULL) AS null_sales,
    COUNT(*) FILTER (WHERE quantity      IS NULL) AS null_quantity,
    COUNT(*) FILTER (WHERE discount      IS NULL) AS null_discount,
    COUNT(*) FILTER (WHERE profit        IS NULL) AS null_profit
FROM orders;                                -- expect all zeros


/* ------------------------------------------------------------
   5. Business-logic validity
   ------------------------------------------------------------ */

-- An order cannot ship before it is placed
SELECT * FROM orders WHERE ship_date < order_date;              -- expect 0 rows

-- Sales and quantity must be positive
SELECT * FROM orders WHERE sales <= 0;                          -- expect 0 rows
SELECT * FROM orders WHERE quantity <= 0;                        -- expect 0 rows

-- Discount is a proportion and must sit within [0, 1]
SELECT * FROM orders WHERE discount < 0 OR discount > 1;         -- expect 0 rows
SELECT DISTINCT discount FROM orders ORDER BY discount;

-- NOTE: profit is deliberately NOT constrained to be positive.
-- Negative profit is the signal this entire analysis is built on
-- and must not be treated as a data quality defect.


/* ------------------------------------------------------------
   6. Categorical consistency
   ------------------------------------------------------------
   Inconsistent casing or stray whitespace silently splits what
   should be a single group, quietly corrupting every GROUP BY
   downstream.
   ------------------------------------------------------------ */

SELECT DISTINCT segment      FROM orders ORDER BY segment;       -- expect 3
SELECT DISTINCT region       FROM orders ORDER BY region;        -- expect 4
SELECT DISTINCT category     FROM orders ORDER BY category;      -- expect 3
SELECT DISTINCT sub_category FROM orders ORDER BY sub_category;  -- expect 17
SELECT DISTINCT ship_mode    FROM orders ORDER BY ship_mode;     -- expect 4
SELECT DISTINCT state        FROM orders ORDER BY state;         -- expect 49

-- Leading/trailing whitespace in text keys
SELECT DISTINCT customer_name
FROM orders
WHERE customer_name <> TRIM(customer_name);                      -- expect 0 rows


/* ------------------------------------------------------------
   7. Apparent duplicates that are in fact legitimate
   ------------------------------------------------------------
   Grouping on (order_id, product_id, customer_id, order_date)
   returns 8 pairs. These are NOT duplicates: the same product
   appearing twice within one order is a valid pair of separate
   line items, distinguished by row_id and differing sales /
   quantity / discount values.

   Recorded here deliberately, because deleting them would have
   silently destroyed real transactions.
   ------------------------------------------------------------ */

SELECT order_id, product_id, customer_id, order_date, COUNT(*) AS line_items
FROM orders
GROUP BY order_id, product_id, customer_id, order_date
HAVING COUNT(*) > 1
ORDER BY order_id;                          -- 8 rows, all legitimate

-- Confirm one such pair is genuinely two distinct line items
SELECT row_id, order_id, product_id, sales, quantity, discount, profit
FROM orders
WHERE order_id = 'CA-2016-140571'
  AND product_id = 'OFF-PA-10001954'
ORDER BY row_id;
SELECT 
	state, 
	SUM(sales) AS total_sales,
	SUM(profit) AS total_profit,	
	ROUND(SUM(profit) / SUM(sales) * 100, 2) AS profit_margin_pct
FROM orders
GROUP BY state
ORDER BY total_profit ASC;
SELECT 
    category,
    sub_category,
    SUM(sales) AS total_sales,
    SUM(profit) AS total_profit,
    ROUND(SUM(profit) / SUM(sales) * 100, 2) AS profit_margin_pct
FROM orders
GROUP BY category, sub_category
ORDER BY total_profit ASC;
SELECT 
    CASE 
        WHEN discount = 0 THEN '0%'
        WHEN discount <= 0.2 THEN '1-20%'
        WHEN discount <= 0.4 THEN '21-40%'
        ELSE '40%+'
    END AS discount_bucket,
    COUNT(*) AS num_orders,
    SUM(sales) AS total_sales,
    SUM(profit) AS total_profit,
    ROUND(AVG(profit), 2) AS avg_profit_per_order
FROM orders
GROUP BY discount_bucket
ORDER BY discount_bucket;
SELECT 
    category,
    sub_category,
    COUNT(*) AS num_high_discount_orders,
    SUM(profit) AS total_profit_impact,
    discount
FROM orders
WHERE discount > 0.2
GROUP BY category, sub_category,discount
ORDER BY total_profit_impact ASC;
SELECT 
    region,
    sub_category,
    SUM(profit) AS total_profit,
    RANK() OVER (PARTITION BY region ORDER BY SUM(profit) DESC) AS profit_rank
FROM orders
GROUP BY region, sub_category
ORDER BY region, profit_rank;
SELECT 
    DATE_TRUNC('month', order_date) AS month,
    SUM(sales) AS monthly_sales,
    SUM(SUM(sales)) OVER (ORDER BY DATE_TRUNC('month', order_date)) AS running_total_sales
FROM orders
GROUP BY DATE_TRUNC('month', order_date)
ORDER BY month;
WITH monthly AS (
    SELECT DATE_TRUNC('month', order_date) AS month, SUM(sales) AS total_sales
    FROM orders
    GROUP BY 1
)
SELECT 
    month,
    total_sales,
    LAG(total_sales) OVER (ORDER BY month) AS prev_month_sales,
    ROUND(
        (total_sales - LAG(total_sales) OVER (ORDER BY month)) 
        / LAG(total_sales) OVER (ORDER BY month) * 100, 2
    ) AS mom_growth_pct
FROM monthly
ORDER BY month;
WITH monthly_summary AS (
	SELECT
		DATE_TRUNC('month', order_date) AS month, 
		SUM(sales) AS total_sales,
		SUM(profit) AS total_profit
	FROM orders
	GROUP BY DATE_TRUNC('month', order_date)
),
monthly_with_margin AS (
	SELECT
		month,
		total_sales,
		total_profit,
		ROUND(total_profit/total_sales *100, 2) AS profit_margin_pct
	FROM monthly_summary
)

SELECT * from monthly_with_margin
ORDER BY month;
WITH customer_profit AS (
	SELECT
		customer_name,
		SUM(sales) AS total_sales,
		SUM(profit) AS total_profit,
		COUNT(DISTINCT order_id) AS num_orders
	FROM orders
	GROUP by customer_name
)
SELECT * FROM customer_profit
ORDER BY total_profit DESC
LIMIT 10;
WITH customer_metrics AS (
	SELECT
		customer_name,
		SUM(sales) AS total_sales,
		SUM(profit) AS total_profit,
		ROUND(SUM(profit) / NULLIF(SUM(sales),0) * 100,2) AS margin_pct
	FROM orders
	GROUP BY customer_name
),
top_decile AS (
	SELECT *,
		NTILE(10) OVER (ORDER BY total_sales DESC) AS sales_decile
		FROM customer_metrics
)
SELECT customer_name, total_sales, margin_pct
FROM top_decile
WHERE sales_decile = 1 AND margin_pct < 5
ORDER BY total_sales DESC;
SELECT 
	customer_name,
	segment,
	region,
	ROUND(AVG(discount),3) AS avg_discount_given,
	COUNT(*) AS num_orders,
	SUM(profit) as total_profit
FROM orders
WHERE customer_name IN (
'Sean Miller', 'Becky Martin','John Lee','Grant Thornton','Peter Fuller','Natalie Fritzler'	,'Sean Braxton','Zuschuss Carroll','Joseph Holt','Patrick O''Brill','Dean percer','Joel Eaton','Joseph Airdo','Victoria Wilson','Cassandra Brandow','Greg Maxwell'	
)
GROUP BY  customer_name, segment,region
ORDER BY total_profit ASC;