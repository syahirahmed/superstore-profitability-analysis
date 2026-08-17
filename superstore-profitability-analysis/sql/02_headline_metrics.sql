/* ============================================================
   02_headline_metrics.sql
   Purpose : Establish the top-line figures the rest of the
             analysis is measured against.
   ============================================================ */

/* ------------------------------------------------------------
   Overall performance, 2014-01-03 to 2017-12-30
   ------------------------------------------------------------
   Result:
     total_orders       5,009
     total_sales        $2,297,201
     total_profit       $286,398
     profit_margin_pct  12.47%

   A 12.5% blended margin looks healthy in aggregate. The purpose
   of everything that follows is to show that this average conceals
   two materially loss-making pockets.
   ------------------------------------------------------------ */

SELECT
    COUNT(DISTINCT order_id)                          AS total_orders,
    COUNT(*)                                          AS total_line_items,
    SUM(sales)                                        AS total_sales,
    SUM(profit)                                       AS total_profit,
    ROUND(SUM(profit) / SUM(sales) * 100, 2)          AS profit_margin_pct,
    ROUND(AVG(discount), 4)                           AS avg_discount
FROM orders;


/* ------------------------------------------------------------
   Performance by region
   ------------------------------------------------------------ */

SELECT
    region,
    SUM(sales)                                        AS total_sales,
    SUM(profit)                                       AS total_profit,
    ROUND(SUM(profit) / SUM(sales) * 100, 2)          AS profit_margin_pct,
    ROUND(AVG(discount), 4)                           AS avg_discount
FROM orders
GROUP BY region
ORDER BY total_profit DESC;


/* ------------------------------------------------------------
   Performance by customer segment
   ------------------------------------------------------------
   Included to test, and rule out, the hypothesis that one segment
   receives preferential discounting. Margins are comparable across
   Consumer, Corporate and Home Office, so segment is not the driver.
   ------------------------------------------------------------ */

SELECT
    segment,
    COUNT(DISTINCT order_id)                          AS total_orders,
    SUM(sales)                                        AS total_sales,
    SUM(profit)                                       AS total_profit,
    ROUND(SUM(profit) / SUM(sales) * 100, 2)          AS profit_margin_pct,
    ROUND(AVG(discount), 4)                           AS avg_discount
FROM orders
GROUP BY segment
ORDER BY total_profit DESC;
