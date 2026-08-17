/* ============================================================
   03_category_profitability.sql
   Purpose : Locate loss-making product lines. Sorted ascending so
             the worst performers surface first.
   ============================================================ */

/* ------------------------------------------------------------
   Category level
   ------------------------------------------------------------ */

SELECT
    category,
    SUM(sales)                                AS total_sales,
    SUM(profit)                               AS total_profit,
    ROUND(SUM(profit) / SUM(sales) * 100, 2)  AS profit_margin_pct
FROM orders
GROUP BY category
ORDER BY total_profit ASC;


/* ------------------------------------------------------------
   Sub-category level: the operative grain
   ------------------------------------------------------------
   Three sub-categories lose money on aggregate:

     Tables      $206,966 sales   -$17,726 profit   -8.56% margin
     Bookcases   $114,880 sales    -$3,473 profit   -3.02% margin
     Supplies     $46,674 sales    -$1,189 profit   -2.55% margin

   These aggregate figures are misleading on their own and should
   not be read as three unprofitable product lines. Decomposing them
   by discount depth in 04_discount_analysis.sql shows that Tables
   and Bookcases are both profitable at or below 20% discount
   (+$12,973 and +$7,625 respectively) and are dragged negative
   only by their unusually high share of deeply discounted orders.

   Supplies is the exception and the only genuinely structural case:
   it has no orders above 20% discount at all, so its loss occurs
   entirely at normal pricing.

   Note Machines: $189,239 sales at +1.79% margin. Profitable overall
   but only barely, which becomes significant in 04_discount_analysis.
   ------------------------------------------------------------ */

SELECT
    category,
    sub_category,
    SUM(sales)                                AS total_sales,
    SUM(profit)                               AS total_profit,
    ROUND(SUM(profit) / SUM(sales) * 100, 2)  AS profit_margin_pct,
    ROUND(AVG(discount), 4)                   AS avg_discount,
    COUNT(*)                                  AS line_items
FROM orders
GROUP BY category, sub_category
ORDER BY total_profit ASC;


/* ------------------------------------------------------------
   Loss concentration
   ------------------------------------------------------------
   How much profit is destroyed by loss-making line items, and how
   much would be recovered if they simply broke even.
   ------------------------------------------------------------ */

SELECT
    COUNT(*)                                                    AS loss_making_line_items,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM orders), 2)   AS pct_of_all_line_items,
    SUM(profit)                                                 AS total_loss,
    ROUND(AVG(discount), 4)                                     AS avg_discount_on_losses
FROM orders
WHERE profit < 0;


/* ------------------------------------------------------------
   Sub-categories that are profitable overall yet still contain
   loss-making orders: hidden risk inside apparently healthy lines.
   ------------------------------------------------------------ */

WITH subcat_totals AS (
    SELECT sub_category, SUM(profit) AS total_profit
    FROM orders
    GROUP BY sub_category
),
subcat_losses AS (
    SELECT
        sub_category,
        COUNT(*)    AS loss_orders,
        SUM(profit) AS loss_amount
    FROM orders
    WHERE profit < 0
    GROUP BY sub_category
)
SELECT
    t.sub_category,
    t.total_profit,
    l.loss_orders,
    l.loss_amount,
    ROUND(ABS(l.loss_amount) / t.total_profit * 100, 1) AS loss_as_pct_of_profit
FROM subcat_totals t
JOIN subcat_losses l USING (sub_category)
WHERE t.total_profit > 0
ORDER BY loss_as_pct_of_profit DESC;
