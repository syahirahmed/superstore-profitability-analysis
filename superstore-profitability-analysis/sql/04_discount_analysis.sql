/* ============================================================
   04_discount_analysis.sql
   Purpose : Test whether discount depth predicts profitability.
             This is the central finding of the project.
   ============================================================ */

/* ------------------------------------------------------------
   Discount tiers
   ------------------------------------------------------------
   Result:

     tier      orders   total_sales    total_profit   avg_profit
     0%         4,798   $1,087,908      $320,988        $66.90
     1-20%      3,803     $846,522      $100,786        $26.50
     21-40%       460     $234,138      -$35,818       -$77.86
     40%+         933     $128,632      -$99,559      -$106.71

   The 20% threshold is a sign flip, not a gradual decline.
   Every tier at or below 20% is profitable; every tier above it
   loses money on average.

   Profitable tiers contribute  +$421,774
   Loss-making tiers contribute -$135,376
   Loss-making tiers are 1,393 line items, 13.9% of volume.
   ------------------------------------------------------------ */

SELECT
    CASE
        WHEN discount = 0    THEN '0%'
        WHEN discount <= 0.2 THEN '1-20%'
        WHEN discount <= 0.4 THEN '21-40%'
        ELSE '40%+'
    END                                       AS discount_tier,
    COUNT(*)                                  AS num_orders,
    SUM(sales)                                AS total_sales,
    SUM(profit)                               AS total_profit,
    ROUND(AVG(profit), 2)                     AS avg_profit_per_order,
    ROUND(SUM(profit) / SUM(sales) * 100, 2)  AS profit_margin_pct
FROM orders
GROUP BY discount_tier
ORDER BY discount_tier;


/* ------------------------------------------------------------
   Discount level detail
   ------------------------------------------------------------
   Finer resolution to locate the break-even point precisely rather
   than relying on the bucket boundaries chosen above.
   ------------------------------------------------------------ */

SELECT
    discount,
    COUNT(*)                                  AS num_orders,
    SUM(sales)                                AS total_sales,
    SUM(profit)                               AS total_profit,
    ROUND(AVG(profit), 2)                     AS avg_profit_per_order,
    ROUND(SUM(profit) / SUM(sales) * 100, 2)  AS profit_margin_pct
FROM orders
GROUP BY discount
ORDER BY discount;


/* ------------------------------------------------------------
   Where the high-discount damage concentrates
   ------------------------------------------------------------
   Result (discount > 20%):

     Binders     613 orders   -$38,511
     Tables      176 orders   -$30,698
     Machines     53 orders   -$29,555
     Bookcases    70 orders   -$11,098
     Appliances   67 orders    -$8,630
     Chairs      158 orders    -$6,737
     Phones      109 orders    -$6,386
     Furnishings 138 orders    -$5,945
     Copiers       9 orders    +$2,183

   Read against 03_category_profitability.sql, the important result
   is that this single mechanism explains almost every loss in the
   dataset. Subtracting the figures above from each sub-category's
   overall profit isolates performance at or below 20% discount:

     sub_category   <=20%       >20%        overall
     Binders      +$68,732    -$38,511    +$30,222
     Machines     +$32,940    -$29,555     +$3,385
     Tables       +$12,973    -$30,698    -$17,726
     Bookcases     +$7,625    -$11,098     -$3,473

   Every one of these lines is profitable below the threshold and
   loss-making above it. Tables and Bookcases only appear to be
   failing products because a large share of their volume is sold at
   deep discount; Machines returns nearly all of the profit it earns
   below the threshold once it crosses it.

   Supplies is the single genuine exception. It appears nowhere in
   the query above, meaning it has no orders above 20% discount, so
   its -$1,189 loss is incurred entirely at normal pricing. It is
   the only sub-category whose economics fail on their own merits,
   and it is immaterial in size.

   Conclusion: discount depth, not product mix, is the operative
   variable. This is a controllable policy failure rather than a
   demand or costing problem.
   ------------------------------------------------------------ */

SELECT
    category,
    sub_category,
    COUNT(*)                                  AS num_high_discount_orders,
    SUM(sales)                                AS total_sales,
    SUM(profit)                               AS total_profit_impact,
    ROUND(AVG(discount), 4)                   AS avg_discount
FROM orders
WHERE discount > 0.2
GROUP BY category, sub_category
ORDER BY total_profit_impact ASC;


/* ------------------------------------------------------------
   Same sub-category, above vs below the 20% threshold
   ------------------------------------------------------------
   Directly contrasts each line's behaviour either side of the
   threshold. Binders and Machines flip from healthy to heavily
   loss-making; Tables is negative on both sides.
   ------------------------------------------------------------ */

SELECT
    sub_category,
    SUM(CASE WHEN discount <= 0.2 THEN profit ELSE 0 END) AS profit_at_or_below_20pct,
    SUM(CASE WHEN discount >  0.2 THEN profit ELSE 0 END) AS profit_above_20pct,
    COUNT(*) FILTER (WHERE discount <= 0.2)               AS orders_at_or_below_20pct,
    COUNT(*) FILTER (WHERE discount >  0.2)               AS orders_above_20pct
FROM orders
GROUP BY sub_category
ORDER BY profit_above_20pct ASC;


/* ------------------------------------------------------------
   Recoverable profit
   ------------------------------------------------------------
   Quantifies the recommendation: if no order were discounted above
   20%, how much loss disappears from the books.
   ------------------------------------------------------------ */

SELECT
    SUM(profit)                                              AS loss_above_20pct_discount,
    COUNT(*)                                                 AS orders_affected,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM orders), 2) AS pct_of_order_volume,
    (SELECT SUM(profit) FROM orders)                         AS current_total_profit,
    (SELECT SUM(profit) FROM orders) - SUM(profit)           AS profit_if_losses_eliminated
FROM orders
WHERE discount > 0.2;
