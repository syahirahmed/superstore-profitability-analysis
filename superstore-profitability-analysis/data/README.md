# Data

The raw dataset is not committed to this repository. Download it and place it here as `Superstore.csv`.

## Source

Superstore Sales, 9,994 rows covering 2014-01-03 to 2017-12-30. Retail transactions for a fictional US office supplies retailer, one row per order line item.

- Kaggle: https://www.kaggle.com/datasets/vivek468/superstore-dataset-final
- Structurally identical to Tableau's official sample dataset, so the 21 columns match every published tutorial for this data.

## Loading

```bash
createdb superstore_db
psql superstore_db -f ../sql/00_schema_setup.sql
```

Then load the CSV from a `psql` prompt:

```sql
\copy orders FROM '/absolute/path/to/Superstore.csv' \
    WITH (FORMAT csv, HEADER true, DELIMITER ',', QUOTE '"', ENCODING 'WIN1252');
```

## Two issues worth knowing before you load

**Encoding.** The file ships in Windows-1252, not UTF-8. Check with `file -I Superstore.csv` and convert if needed:

```bash
iconv -f WINDOWS-1252 -t UTF-8 Superstore.csv > Superstore_utf8.csv
```

**Embedded commas.** `product_name` contains quoted values with commas inside them, for example `"Xerox 1954, Recycled Paper, 8.5 x 11"`. Any importer that splits naively on commas will misalign every subsequent column, producing NULLs and an inflated row count. The `QUOTE '"'` argument above handles this.

Validate with `../sql/01_data_validation.sql` after loading. The row count must be exactly 9,994.
