/* ============================================================
   00_schema_setup.sql
   Purpose : Create the target table and load the raw Superstore CSV
   Database: PostgreSQL 16
   Run     : psql superstore_db -f sql/00_schema_setup.sql
   ============================================================ */

-- Superstore is a single denormalised transaction table: one row per
-- order line item (not one row per order). row_id is the source file's
-- line counter and is the only guaranteed-unique column.

DROP TABLE IF EXISTS orders;

CREATE TABLE orders (
    row_id        INT,
    order_id      VARCHAR(20),
    order_date    DATE,
    ship_date     DATE,
    ship_mode     VARCHAR(50),
    customer_id   VARCHAR(20),
    customer_name VARCHAR(100),
    segment       VARCHAR(50),
    country       VARCHAR(50),
    city          VARCHAR(50),
    state         VARCHAR(50),
    postal_code   VARCHAR(10),
    region        VARCHAR(20),
    product_id    VARCHAR(20),
    category      VARCHAR(50),
    sub_category  VARCHAR(50),
    product_name  VARCHAR(200),
    sales         NUMERIC(10,2),
    quantity      INT,
    discount      NUMERIC(4,2),
    profit        NUMERIC(10,2)
);


/* ------------------------------------------------------------
   LOAD
   ------------------------------------------------------------
   The source CSV ships in Windows-1252 encoding, not UTF-8, and
   product_name contains embedded commas inside quoted fields
   (e.g. "Xerox 1954, Recycled Paper, 8.5 x 11").

   A naive comma-split importer misaligns every row after the first
   quoted comma, which silently produces NULLs and inflates the row
   count. \copy with an explicit QUOTE character parses correctly.

   Run this from the psql prompt (\copy is a psql meta-command and
   will not execute inside a GUI SQL editor):
   ------------------------------------------------------------ */

-- \copy orders FROM '/absolute/path/to/Superstore.csv' \
--     WITH (FORMAT csv, HEADER true, DELIMITER ',', QUOTE '"', ENCODING 'WIN1252');

-- If the encoding is unknown, check it first from a shell:
--     file -I Superstore.csv
-- and convert to UTF-8 if preferred:
--     iconv -f WINDOWS-1252 -t UTF-8 Superstore.csv > Superstore_utf8.csv


-- Expected state after a clean load
SELECT COUNT(*) AS row_count FROM orders;              -- expect 9994
SELECT MIN(order_date), MAX(order_date) FROM orders;   -- expect 2014-01-03 .. 2017-12-30
