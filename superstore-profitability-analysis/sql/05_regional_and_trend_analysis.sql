/* ============================================================
   05_regional_and_trend_analysis.sql
   Purpose : Window functions. Rank performance within regions and
             measure how sales, profit and margin move over time.
   ============================================================ */

/* ------------------------------------------------------------
   Sub-category profit ranked within each region
   ------------------------------------------------------------
   PARTITION BY region restarts the ranking at each region, so this
   answers "worst performer in the West" rather than "worst overall".
   Used to test whether Tables underperforms everywhere or only in
   specific regions.
   ------------------------------------------------------------ */

SELECT
    region,
    sub_category,
    SUM(profit)                                                        AS total_profit,
    RANK() OVER (PARTITION BY region ORDER BY SUM(profit) DESC)        AS profit_rank_in_region
FROM orders
GROUP BY region, sub_category
ORDER BY region, profit_rank_in_region;


/* ------------------------------------------------------------
   Bottom 3 sub-categories per region
   ------------------------------------------------------------
   A window function cannot be filtered in the same query level it
   is computed in, because window functions are evaluated after
   WHERE. Wrapping in a subquery and filtering on the outside is the
   standard pattern.
   ------------------------------------------------------------ */

SELECT *
FROM (
    SELECT
        region,
        sub_category,
        SUM(profit)                                                 AS total_profit,
        RANK() OVER (PARTITION BY region ORDER BY SUM(profit) ASC)  AS worst_rank
    FROM orders
    GROUP BY region, sub_category
) ranked
WHERE worst_rank <= 3
ORDER BY region, worst_rank;


/* ------------------------------------------------------------
   Top 5 customers by profit within each region
   ------------------------------------------------------------ */

SELECT *
FROM (
    SELECT
        region,
        customer_name,
        SUM(profit)                                                  AS total_profit,
        RANK() OVER (PARTITION BY region ORDER BY SUM(profit) DESC)   AS rank_in_region
    FROM orders
    GROUP BY region, customer_name
) ranked
WHERE rank_in_region <= 5
ORDER BY region, rank_in_region;


/* ------------------------------------------------------------
   Monthly sales with running total
   ------------------------------------------------------------
   Aggregate first in a CTE, then window over the clean result.

   Writing SUM(SUM(sales)) OVER (ORDER BY DATE_TRUNC('month', order_date))
   directly against the base table fails in PostgreSQL, because
   order_date is no longer individually addressable inside the OVER
   clause once GROUP BY has been applied. Pre-aggregating avoids the
   problem and reads better.
   ------------------------------------------------------------ */

WITH monthly_sales AS (
    SELECT
        DATE_TRUNC('month', order_date) AS month,
        SUM(sales)                      AS monthly_sales
    FROM orders
    GROUP BY DATE_TRUNC('month', order_date)
)
SELECT
    month,
    monthly_sales,
    SUM(monthly_sales) OVER (ORDER BY month) AS running_total_sales
FROM monthly_sales
ORDER BY month;


/* ------------------------------------------------------------
   Month-over-month growth
   ------------------------------------------------------------
   LAG pulls the previous row's value onto the current row, which
   makes period-over-period arithmetic possible without a self-join.
   The first row is NULL by definition: there is no prior month.

   Observed pattern: a pronounced Q4 peak each year that resets in
   January, consistent with holiday seasonality rather than
   underlying growth or decline.
   ------------------------------------------------------------ */

WITH monthly AS (
    SELECT
        DATE_TRUNC('month', order_date) AS month,
        SUM(sales)                      AS total_sales
    FROM orders
    GROUP BY 1
)
SELECT
    month,
    total_sales,
    LAG(total_sales) OVER (ORDER BY month) AS prev_month_sales,
    ROUND(
        (total_sales - LAG(total_sales) OVER (ORDER BY month))
        / NULLIF(LAG(total_sales) OVER (ORDER BY month), 0) * 100
    , 2)                                   AS mom_growth_pct
FROM monthly
ORDER BY month;


/* ------------------------------------------------------------
   Three-month moving average
   ------------------------------------------------------------
   Smooths the seasonal spikes to expose the underlying trend.
   ------------------------------------------------------------ */

WITH monthly AS (
    SELECT
        DATE_TRUNC('month', order_date) AS month,
        SUM(sales)                      AS total_sales
    FROM orders
    GROUP BY 1
)
SELECT
    month,
    total_sales,
    ROUND(AVG(total_sales) OVER (
        ORDER BY month
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ), 2) AS three_month_moving_avg
FROM monthly
ORDER BY month;


/* ------------------------------------------------------------
   Recurring seasonality
   ------------------------------------------------------------
   EXTRACT(MONTH ...) collapses the same calendar month across all
   years, which tests whether the Q4 peak recurs annually or was
   driven by one exceptional year. DATE_TRUNC would keep the years
   separate and could not answer this.
   ------------------------------------------------------------ */

SELECT
    EXTRACT(MONTH FROM order_date)            AS month_num,
    TRIM(TO_CHAR(order_date, 'Month'))        AS month_name,
    SUM(sales)                                AS total_sales,
    SUM(profit)                               AS total_profit,
    ROUND(SUM(profit) / SUM(sales) * 100, 2)  AS profit_margin_pct
FROM orders
GROUP BY 1, 2
ORDER BY total_sales DESC;


/* ------------------------------------------------------------
   Monthly margin stability
   ------------------------------------------------------------
   Margin holds broadly steady month to month, so the losses
   identified elsewhere are a persistent structural condition
   rather than a deteriorating trend.
   ------------------------------------------------------------ */

WITH monthly_summary AS (
    SELECT
        DATE_TRUNC('month', order_date) AS month,
        SUM(sales)                      AS monthly_sales,
        SUM(profit)                     AS monthly_profit
    FROM orders
    GROUP BY DATE_TRUNC('month', order_date)
)
SELECT
    month,
    monthly_sales,
    monthly_profit,
    ROUND(monthly_profit / monthly_sales * 100, 2) AS profit_margin_pct
FROM monthly_summary
ORDER BY month;


/* ------------------------------------------------------------
   Fulfilment speed by ship mode and by year
   ------------------------------------------------------------ */

SELECT
    ship_mode,
    ROUND(AVG(ship_date - order_date), 2) AS avg_days_to_ship,
    COUNT(*)                              AS line_items
FROM orders
GROUP BY ship_mode
ORDER BY avg_days_to_ship;

SELECT
    EXTRACT(YEAR FROM order_date)         AS order_year,
    ROUND(AVG(ship_date - order_date), 2) AS avg_days_to_ship
FROM orders
GROUP BY 1
ORDER BY 1;
