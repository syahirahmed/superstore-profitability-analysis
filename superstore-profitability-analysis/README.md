# Superstore Profitability Analysis

Analysis of 9,994 retail transactions (2014–2017) identifying why a business with a healthy 12.5% blended margin is losing $135,000 to a single controllable practice: discounting above 20%.

**Tools:** PostgreSQL 16 · TablePlus · Tableau Public
**Dashboard:** [live on Tableau Public](#) · **Analysis:** [`/sql`](./sql)

---

## Business problem

Revenue is growing and overall margin looks acceptable, but profit is not keeping pace. Leadership needs to know which product lines and commercial practices are eroding margin, whether the cause is the products themselves or how they are being sold, and what specifically should change.

The question this analysis answers: **where is profit being destroyed, and is it something we control?**

---

## Key findings

### 1. A 20% discount is a cliff edge, not a slope

Profitability does not decline gradually as discounts deepen. It inverts at a threshold.

| Discount tier | Orders | Sales | Profit | Avg profit/order |
|---|---:|---:|---:|---:|
| 0% | 4,798 | $1,087,908 | **+$320,988** | +$66.90 |
| 1–20% | 3,803 | $846,522 | **+$100,786** | +$26.50 |
| 21–40% | 460 | $234,138 | **−$35,818** | −$77.86 |
| 40%+ | 933 | $128,632 | **−$99,559** | −$106.71 |

Every tier at or below 20% is profitable. Every tier above it loses money. Orders above 20% discount are just **13.9% of volume but destroy $135,376** — equivalent to 47% of the company's entire reported profit.

### 2. Almost every "unprofitable product" is actually a discounting artifact

Three sub-categories show negative margin on aggregate, which invites the conclusion that they are bad products. Decomposing them by discount depth shows otherwise:

| Sub-category | Profit ≤20% discount | Profit >20% discount | Overall |
|---|---:|---:|---:|
| Binders | +$68,732 | −$38,511 | +$30,222 |
| Machines | +$32,940 | −$29,555 | +$3,385 |
| Tables | **+$12,973** | −$30,698 | **−$17,726** |
| Bookcases | **+$7,625** | −$11,098 | **−$3,473** |

Tables carries the worst headline margin in the business at −8.56%, yet it is *profitable* when sold at 20% discount or less. Its aggregate loss comes from an unusually high share of deeply discounted volume, not from the product's economics. Machines is the starkest case: it earns $32,940 below the threshold and gives back $29,555 above it — nearly all of it.

**This matters commercially.** Discontinuing Tables, the obvious read from the headline number, would remove a line that generates $13,000 in profit when sold at sane prices.

### 3. One genuine structural exception: Supplies

Supplies loses $1,189 at −2.55% margin and has **no orders above 20% discount at all**, meaning the loss occurs entirely at normal pricing. It is the only sub-category whose economics fail on their own merits — and at $1,189 it is immaterial next to the $135,376 lost to discounting.

### 4. The same customer is profitable or loss-making depending only on discount

Filtering for top-decile-revenue customers with sub-5% margin surfaces accounts receiving 25–50% average discounts against a company-wide average near 16%. Sean Braxton is the clearest illustration:

| Region | Avg discount | Profit |
|---|---:|---:|
| East | 41.3% | −$1,478 |
| Central | 40.0% | −$762 |
| South | 0.0% | +$78 |
| West | 0.0% | +$80 |

Same customer, same commercial relationship, four different outcomes tracking discount rate exactly. This rules out customer quality as the driver and confirms the discount itself is causal.

### 5. Not a segment or seasonality problem

Consumer, Corporate and Home Office show comparable margins, ruling out preferential discounting by segment. Monthly margin is broadly stable across all four years, with a recurring Q4 peak that resets each January — normal holiday seasonality, not a deteriorating trend. The losses are a persistent structural condition, not a recent decline.

---

## Recommendations

1. **Require approval for any discount above 20%.** This single control addresses $135,376 of losses across 13.9% of order volume. The threshold is empirically derived, not arbitrary.
2. **Do not discontinue Tables or Bookcases.** Both are profitable at normal pricing. Cap their discount exposure instead — Tables has the highest deep-discount share in the business, which is the actual defect.
3. **Audit Binders and Machines discount approvals specifically.** These two lines account for $68,066 of high-discount losses between them despite being profitable products.
4. **Review Supplies pricing and cost independently.** It is the only line that fails without discounting, and needs a costing review rather than a discount control.

---

## Approach

| Stage | File | What it does |
|---|---|---|
| Setup | [`00_schema_setup.sql`](./sql/00_schema_setup.sql) | Table definition and CSV load |
| Validation | [`01_data_validation.sql`](./sql/01_data_validation.sql) | Row count, key uniqueness, nulls, business-logic and categorical checks |
| Baseline | [`02_headline_metrics.sql`](./sql/02_headline_metrics.sql) | Top-line totals, region and segment breakdowns |
| Product | [`03_category_profitability.sql`](./sql/03_category_profitability.sql) | Category and sub-category margin, loss concentration |
| Root cause | [`04_discount_analysis.sql`](./sql/04_discount_analysis.sql) | Discount tiers, threshold isolation, recoverable profit |
| Trends | [`05_regional_and_trend_analysis.sql`](./sql/05_regional_and_trend_analysis.sql) | Window functions: regional ranking, running totals, MoM growth, moving average, seasonality |
| Customers | [`06_customer_analysis.sql`](./sql/06_customer_analysis.sql) | CTEs and `NTILE` decile segmentation, customer-level confirmation |
| Handoff | [`07_tableau_export.sql`](./sql/07_tableau_export.sql) | Single validated export feeding the dashboard |

SQL techniques used: aggregations, `CASE` tiering and conditional aggregation, window functions (`RANK`, `LAG`, `NTILE`, framed `AVG`, running `SUM`), single and chained CTEs, correlated subqueries, and date handling with `DATE_TRUNC` and `EXTRACT`.

---

## Data

Superstore Sales — 9,994 rows, 2014-01-03 to 2017-12-30, one row per order line item. [Kaggle source](https://www.kaggle.com/datasets/vivek468/superstore-dataset-final); structurally identical to Tableau's official sample dataset. Raw file is not committed — see [`data/README.md`](./data/README.md).

### Data quality work

Validation is in [`01_data_validation.sql`](./sql/01_data_validation.sql). Three issues were found and resolved:

**Encoding.** The source file ships in Windows-1252, not UTF-8, and failed import on special characters in customer and product names.

**Embedded commas breaking column alignment.** `product_name` contains quoted values with internal commas (`"Xerox 1954, Recycled Paper, 8.5 x 11"`). A naive comma-split import misaligned every row after the first such value, producing NULLs in columns pushed past the row end while columns further left still appeared populated. Resolved by importing with an explicit `QUOTE '"'` argument.

**Row count as an integrity signal.** An initial load returned 10,006 rows against an expected 9,994. The cause was reloading without truncating first, leaving 12 fragment rows from the earlier broken import underneath the good data. Row count is the cheapest available check that a load is clean.

**One finding deliberately not "cleaned":** grouping on `(order_id, product_id, customer_id, order_date)` returns 8 apparent duplicate pairs. These are legitimate — the same product ordered twice within one order as two separate line items, distinguished by `row_id` and differing sales, quantity and discount values. Deleting them would have destroyed real transactions. Negative `profit` was likewise left untouched, as it is the signal the analysis is built on.

---

## Dashboard

Four linked views on a single shared data source, filterable by region, category, segment and date range:

- **Profit by state** — choropleth, diverging red/green scale centred at zero
- **Profit by sub-category** — sorted bar chart surfacing loss-making lines
- **Monthly sales and profit** — dual-axis trend showing seasonality and margin stability
- **Discount vs profit** — order-level scatter with trend line, the visual proof of the 20% threshold

An earlier iteration built each worksheet from its own pre-aggregated query export. Every chart rendered correctly in isolation, but no dashboard-level filter could act across them, because a `region` filter requires a region column present in every sheet's source and each extract carried only the dimensions its own `GROUP BY` needed. Rebuilt against one validated export with aggregation performed in Tableau, which also allowed the scatter to plot individual order marks rather than a handful of aggregated points.

---

## Reproducing

```bash
createdb superstore_db
psql superstore_db -f sql/00_schema_setup.sql
# load the CSV via \copy — see data/README.md
psql superstore_db -f sql/01_data_validation.sql
```

Then run `02` through `06` in order. `07_tableau_export.sql` produces the dashboard source.

---

## Repository

```
superstore-profitability-analysis/
├── README.md
├── data/
│   └── README.md              # source, load instructions, known issues
├── sql/
│   ├── 00_schema_setup.sql
│   ├── 01_data_validation.sql
│   ├── 02_headline_metrics.sql
│   ├── 03_category_profitability.sql
│   ├── 04_discount_analysis.sql
│   ├── 05_regional_and_trend_analysis.sql
│   ├── 06_customer_analysis.sql
│   └── 07_tableau_export.sql
└── dashboard/
    └── dashboard.png          # screenshot; live version on Tableau Public
```
