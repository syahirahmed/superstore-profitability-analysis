/* ============================================================
   06_customer_analysis.sql
   Purpose : CTEs. Move the discount finding from product level to
             customer level and test whether it still holds.
   ============================================================ */

/* ------------------------------------------------------------
   Top 10 customers by profit
   ------------------------------------------------------------ */

WITH customer_profit AS (
    SELECT
        customer_name,
        COUNT(DISTINCT order_id)                  AS num_orders,
        SUM(sales)                                AS total_sales,
        SUM(profit)                               AS total_profit,
        ROUND(AVG(discount), 4)                   AS avg_discount
    FROM orders
    GROUP BY customer_name
)
SELECT *
FROM customer_profit
ORDER BY total_profit DESC
LIMIT 10;


/* ------------------------------------------------------------
   High revenue, thin margin
   ------------------------------------------------------------
   NTILE(10) splits customers into ten equally sized buckets by
   sales rank, so decile 1 is the top 10% by revenue. Combined with
   a margin filter this isolates the most commercially dangerous
   accounts: large, visible, and barely profitable.
   ------------------------------------------------------------ */

WITH customer_metrics AS (
    SELECT
        customer_name,
        SUM(sales)                                            AS total_sales,
        SUM(profit)                                           AS total_profit,
        ROUND(SUM(profit) / NULLIF(SUM(sales), 0) * 100, 2)   AS margin_pct,
        ROUND(AVG(discount), 4)                               AS avg_discount
    FROM orders
    GROUP BY customer_name
),
ranked AS (
    SELECT
        *,
        NTILE(10) OVER (ORDER BY total_sales DESC) AS sales_decile
    FROM customer_metrics
)
SELECT
    customer_name,
    total_sales,
    total_profit,
    margin_pct,
    avg_discount
FROM ranked
WHERE sales_decile = 1
  AND margin_pct < 5
ORDER BY total_sales DESC;


/* ------------------------------------------------------------
   Discount profile of the flagged accounts
   ------------------------------------------------------------
   Average discount for these accounts runs roughly 25-50%, against
   a dataset-wide average near 16%. The same threshold effect found
   at product level reappears at customer level.

   Grouping by region as well as customer is deliberate. Region is a
   property of the order, not of the customer, so a customer who buys
   into more than one region legitimately returns more than one row.
   That is what exposes the finding below.
   ------------------------------------------------------------ */

WITH flagged AS (
    SELECT customer_name
    FROM (
        SELECT
            customer_name,
            SUM(sales)                                          AS total_sales,
            ROUND(SUM(profit) / NULLIF(SUM(sales), 0) * 100, 2)  AS margin_pct,
            NTILE(10) OVER (ORDER BY SUM(sales) DESC)            AS sales_decile
        FROM orders
        GROUP BY customer_name
    ) m
    WHERE sales_decile = 1 AND margin_pct < 5
)
SELECT
    o.customer_name,
    o.segment,
    o.region,
    ROUND(AVG(o.discount), 3) AS avg_discount_given,
    COUNT(*)                  AS num_orders,
    SUM(o.sales)              AS total_sales,
    SUM(o.profit)             AS total_profit
FROM orders o
JOIN flagged f USING (customer_name)
GROUP BY o.customer_name, o.segment, o.region
ORDER BY total_profit ASC;


/* ------------------------------------------------------------
   The same customer, profitable in one region and not another
   ------------------------------------------------------------
   Sean Braxton is the clearest case:

     region    avg_discount   profit
     East          0.413      -$1,478
     Central       0.400        -$762
     South         0.000         +$78
     West          0.000         +$80

   Identical customer, identical commercial relationship. The only
   variable that moves is the discount applied, and profit follows
   it exactly. This is the strongest available evidence that discount
   rate is the causal driver rather than customer quality, product
   mix, or segment.
   ------------------------------------------------------------ */

SELECT
    customer_name,
    region,
    ROUND(AVG(discount), 3) AS avg_discount,
    COUNT(*)                AS num_orders,
    SUM(sales)              AS total_sales,
    SUM(profit)             AS total_profit
FROM orders
WHERE customer_name = 'Sean Braxton'
GROUP BY customer_name, region
ORDER BY total_profit;

-- Order-level detail behind the same customer
SELECT
    order_id,
    order_date,
    region,
    sub_category,
    discount,
    sales,
    profit
FROM orders
WHERE customer_name = 'Sean Braxton'
ORDER BY region, order_date;


/* ------------------------------------------------------------
   Customers appearing in more than one region
   ------------------------------------------------------------
   Confirms the pattern above is general and not specific to one
   account, and documents why customer-level aggregates can mask
   region-specific losses.
   ------------------------------------------------------------ */

SELECT
    customer_name,
    COUNT(DISTINCT region) AS regions_active_in,
    SUM(profit)            AS total_profit
FROM orders
GROUP BY customer_name
HAVING COUNT(DISTINCT region) > 1
ORDER BY total_profit ASC
LIMIT 20;
