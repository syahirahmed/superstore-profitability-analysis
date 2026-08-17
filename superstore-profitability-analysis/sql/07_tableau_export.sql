/* ============================================================
   07_tableau_export.sql
   Purpose : Produce the single source feeding the Tableau dashboard.
   ============================================================ */

/* ------------------------------------------------------------
   Why the full table rather than per-query extracts
   ------------------------------------------------------------
   An earlier iteration exported one CSV per analytical query and
   built one worksheet per CSV. Each chart rendered correctly in
   isolation, but no dashboard-level filter could act across them:
   a Region filter needs a region column present in every sheet's
   source, and the pre-aggregated extracts each carried only the
   dimensions their own GROUP BY required.

   Exporting the validated table once and letting Tableau perform
   the aggregation solves this. Every worksheet shares one source,
   so Region, Category, Segment and date filters apply everywhere,
   and the discount scatter can plot individual order marks instead
   of a handful of pre-aggregated points.

   The SQL in files 02-06 remains the analysis. This file only
   moves data to the presentation layer.
   ------------------------------------------------------------ */

SELECT
    row_id,
    order_id,
    order_date,
    ship_date,
    ship_date - order_date AS days_to_ship,
    ship_mode,
    customer_id,
    customer_name,
    segment,
    country,
    city,
    state,
    postal_code,
    region,
    product_id,
    category,
    sub_category,
    product_name,
    sales,
    quantity,
    discount,
    profit,
    CASE
        WHEN discount = 0    THEN '0%'
        WHEN discount <= 0.2 THEN '1-20%'
        WHEN discount <= 0.4 THEN '21-40%'
        ELSE '40%+'
    END AS discount_tier,
    CASE WHEN profit < 0 THEN 'Loss' ELSE 'Profit' END AS profit_flag
FROM orders
ORDER BY row_id;

/* ------------------------------------------------------------
   Export: run the above in TablePlus, then right-click the result
   grid and choose Export > CSV. Save as superstore_orders.csv.

   Two derived columns are included because they are awkward to
   recreate in Tableau Public and are used directly by the dashboard:
   discount_tier drives the tier comparison, profit_flag drives the
   loss highlighting.

   In Tableau, confirm on the Data Source tab that order_date and
   ship_date are typed as Date, that state and city carry a
   geographic role, and that sales, profit, discount and quantity
   are numeric before building any worksheet.
   ------------------------------------------------------------ */
