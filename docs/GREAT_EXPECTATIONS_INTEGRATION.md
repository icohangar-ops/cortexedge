# Great Expectations Data Quality Validation for CortexEdge

## Overview

[Great Expectations](https://greatexpectations.io/) (12K+ GitHub stars) is a Python-based data quality framework that validates, profiles, and documents data. It lets you define "expectations" about your data — like assertions on columns, rows, or entire tables — and surfaces quality issues before they propagate through downstream models.

This integration adds expectation suites to CortexEdge's financial NLP pipeline, covering the raw source tables that feed staging, intermediate, and mart models. Caught early, data quality problems never reach Cortex AI sentiment scoring or composite signal calculations.

---

## Why Great Expectations for CortexEdge?

CortexEdge depends on three raw data sources — earnings calls, SEC filings, and stock prices. Quality issues at the source (null transcripts, invalid tickers, bad prices) cascade through sentiment analysis, risk classification, and composite research signals. Great Expectations validates data **before** dbt runs, so downstream models always operate on clean input.

| GX Feature | CortexEdge Use Case |
|------------|---------------------|
| **Expectation Suites** | Declarative validation rules for each raw source table |
| **Snowflake Data Docs** | Browse validation results inside Snowflake or as a static site |
| **Checkpoint Runner** | Automated validation after `dbt seed` or raw data ingestion |
| **Data Docs** | Auto-generated HTML docs describing expected data shape |
| **Custom Expectations** | Validate sentiment score bounds, filing type enums, date ranges |
| **Integration with dbt** | Run expectations as a gate between ingestion and dbt models |

---

## Installation

### 1. Install Great Expectations

```bash
pip install great_expectations snowflake-connector-python
```

### 2. Initialize GX in the project root

```bash
cd cortexedge
great_expectations init
```

This creates `great_expectations/` with a base configuration.

### 3. Configure the Snowflake datasource

Edit `great_expectations/great_expectations.yml`:

```yaml
datasources:
  snowflake_cortex:
    class_name: Datasource
    execution_engine:
      class_name: SnowflakeExecutionEngine
      connection_string: "snowflake://{user}:{password}@{account}/{database}/{schema}?warehouse={warehouse}&role={role}"
      # Alternatively, use env vars:
      # connection_string: "${SNOWFLAKE_CONN_STRING}"
    data_connectors:
      default_runtime_data_connector:
        class_name: RuntimeDataConnector
        batch_identifiers:
          - default_identifier_name
      default_inferred_data_connector:
        class_name: InferredAssetSqlDataConnector
        name: whole_table
```

### 4. Set up the GX context

```python
# great_expectations/great_expectations.yml handles most config.
# For programmatic use:
import great_expectations as gx

context = gx.get_context()
```

---

## Expectation Suites

### 1. Earnings Calls (`earnings_calls`)

Validates raw earnings call transcript data in `CORTEX_RESEARCH.RAW.EARNINGS_CALLS`.

```json
{
  "expectation_suite_name": "earnings_calls_suite",
  "expectations": [
    {
      "expectation_type": "expect_column_values_to_not_be_null",
      "kwargs": { "column": "transcript_text" }
    },
    {
      "expectation_type": "expect_column_values_to_not_be_null",
      "kwargs": { "column": "ticker" }
    },
    {
      "expectation_type": "expect_column_values_to_not_be_null",
      "kwargs": { "column": "call_date" }
    },
    {
      "expectation_type": "expect_column_values_to_match_regex",
      "kwargs": {
        "column": "ticker",
        "regex": "^[A-Z]{1,5}$"
      }
    },
    {
      "expectation_type": "expect_column_values_to_be_between",
      "kwargs": {
        "column": "confidence_score",
        "min_value": 0.0,
        "max_value": 1.0
      }
    },
    {
      "expectation_type": "expect_column_value_lengths_to_be_between",
      "kwargs": {
        "column": "transcript_text",
        "min_value": 50,
        "max_value": 500000
      }
    },
    {
      "expectation_type": "expect_column_values_to_be_in_set",
      "kwargs": {
        "column": "call_type",
        "value_set": ["earnings", "conference", "investor_day", "guidance"]
      }
    },
    {
      "expectation_type": "expect_table_row_count_to_be_between",
      "kwargs": {
        "min_value": 10,
        "max_value": 100000
      }
    }
  ]
}
```

**Key validations:**
- `transcript_text` must never be null (Cortex AI requires text input)
- `ticker` must be non-null and match a 1-5 uppercase letter pattern
- `confidence_score` must be between 0 and 1
- `transcript_text` must be between 50 and 500K characters (matches dbt staging filter)
- `call_type` must be one of the known values

### 2. SEC Filings (`sec_filings`)

Validates raw SEC filing data in `CORTEX_RESEARCH.RAW.SEC_FILINGS`.

```json
{
  "expectation_suite_name": "sec_filings_suite",
  "expectations": [
    {
      "expectation_type": "expect_column_values_to_not_be_null",
      "kwargs": { "column": "filing_id" }
    },
    {
      "expectation_type": "expect_column_values_to_not_be_null",
      "kwargs": { "column": "section_text" }
    },
    {
      "expectation_type": "expect_column_values_to_not_be_null",
      "kwargs": { "column": "filing_type" }
    },
    {
      "expectation_type": "expect_column_values_to_be_in_set",
      "kwargs": {
        "column": "filing_type",
        "value_set": ["10-K", "10-Q", "8-K", "DEF 14A", "S-1", "10-K/A", "10-Q/A"]
      }
    },
    {
      "expectation_type": "expect_column_values_to_match_regex",
      "kwargs": {
        "column": "ticker",
        "regex": "^[A-Z]{1,5}$"
      }
    },
    {
      "expectation_type": "expect_column_value_lengths_to_be_between",
      "kwargs": {
        "column": "section_text",
        "min_value": 100,
        "max_value": 1000000
      }
    },
    {
      "expectation_type": "expect_column_values_to_be_unique",
      "kwargs": { "column": "filing_id" }
    },
    {
      "expectation_type": "expect_column_values_to_not_be_null",
      "kwargs": { "column": "filing_date" }
    },
    {
      "expectation_type": "expect_column_values_to_be_between",
      "kwargs": {
        "column": "pages_count",
        "min_value": 1,
        "max_value": 1000
      }
    },
    {
      "expectation_type": "expect_table_row_count_to_be_between",
      "kwargs": {
        "min_value": 5,
        "max_value": 200000
      }
    }
  ]
}
```

**Key validations:**
- `filing_type` must be one of the standard SEC form types
- `section_text` must be non-null and at least 100 characters (no empty extractions)
- `filing_id` must be unique (no duplicate processing)
- `pages_count` must be within a reasonable range

### 3. Stock Prices (`stock_prices`)

Validates raw stock price data in `CORTEX_RESEARCH.RAW.STOCK_PRICES`.

```json
{
  "expectation_suite_name": "stock_prices_suite",
  "expectations": [
    {
      "expectation_type": "expect_column_values_to_not_be_null",
      "kwargs": { "column": "close_price" }
    },
    {
      "expectation_type": "expect_column_values_to_be_between",
      "kwargs": {
        "column": "close_price",
        "min_value": 0.01,
        "max_value": 100000
      }
    },
    {
      "expectation_type": "expect_column_values_to_be_between",
      "kwargs": {
        "column": "open_price",
        "min_value": 0.01,
        "max_value": 100000
      }
    },
    {
      "expectation_type": "expect_column_values_to_be_between",
      "kwargs": {
        "column": "high_price",
        "min_value": 0.01,
        "max_value": 100000
      }
    },
    {
      "expectation_type": "expect_column_values_to_be_between",
      "kwargs": {
        "column": "low_price",
        "min_value": 0.01,
        "max_value": 100000
      }
    },
    {
      "expectation_type": "expect_column_values_to_not_be_null",
      "kwargs": { "column": "price_date" }
    },
    {
      "expectation_type": "expect_column_values_to_be_unique",
      "kwargs": {
        "column": "price_id"
      }
    },
    {
      "expectation_type": "expect_column_values_to_match_regex",
      "kwargs": {
        "column": "ticker",
        "regex": "^[A-Z]{1,5}$"
      }
    },
    {
      "expectation_type": "expect_column_values_to_not_be_null",
      "kwargs": { "column": "volume" }
    },
    {
      "expectation_type": "expect_column_values_to_be_between",
      "kwargs": {
        "column": "volume",
        "min_value": 0,
        "max_value": 10000000000
      }
    },
    {
      "expectation_type": "expect_column_values_to_be_between",
      "kwargs": {
        "column": "price_date",
        "min_value": "2020-01-01",
        "max_value": "2030-12-31"
      }
    },
    {
      "expectation_type": "expect_table_row_count_to_be_between",
      "kwargs": {
        "min_value": 100,
        "max_value": 5000000
      }
    }
  ]
}
```

**Key validations:**
- All price columns (`close_price`, `open_price`, `high_price`, `low_price`) must be positive
- `price_date` must be within a valid range (2020-2030)
- `volume` must be non-negative
- `price_id` must be unique
- `ticker` must match the standard 1-5 uppercase letter pattern

---

## Snowflake Integration

### Connecting GX to Snowflake

GX connects to Snowflake the same way dbt does — via connection strings or environment variables.

**Option A: Connection string in config**

```yaml
# great_expectations/great_expectations.yml
datasources:
  snowflake_cortex:
    class_name: Datasource
    execution_engine:
      class_name: SnowflakeExecutionEngine
      connection_string: "snowflake://${SNOWFLAKE_USER}:${SNOWFLAKE_PASSWORD}@${SNOWFLAKE_ACCOUNT}/CORTEX_RESEARCH/RAW?warehouse=CORTEX_WH&role=CORTEX_RESEARCH_ROLE"
```

**Option B: SQLAlchemy URL**

```yaml
execution_engine:
  class_name: SnowflakeExecutionEngine
  connection_string: "snowflake://user:password@account-id/CORTEX_RESEARCH/RAW?warehouse=CORTEX_WH"
```

### Validating Snowflake Data

```python
import great_expectations as gx

context = gx.get_context()

# Connect to Snowflake
datasource = context.sources.add_or_update_snowflake(
    name="snowflake_cortex",
    connection_string="snowflake://user:password@account/CORTEX_RESEARCH/RAW?warehouse=CORTEX_WH",
)

# Create a batch request for the earnings_calls table
batch_request = datasource.get_batch_request(
    table_name="earnings_calls",
)

# Add the expectation suite
context.add_or_update_expectation_suite(expectation_suite_name="earnings_calls_suite")

# Run validation
validator = context.get_validator(
    batch_request=batch_request,
    expectation_suite_name="earnings_calls_suite",
)
result = validator.validate()

print(f"Success: {result.success}")
print(f"Evaluated: {result.statistics['evaluated_expectations']}")
print(f"Successful: {result.statistics['successful_expectations']}")
print(f"Unsuccessful: {result.statistics['unsuccessful_expectations']}")
```

---

## Running Expectations After dbt Run

### Option 1: dbt Test Hook

Add a post-run script that executes GX validation:

```bash
#!/bin/bash
# scripts/validate_after_dbt.sh

set -e

echo "Running dbt models..."
dbt run

echo "Running Great Expectations validation..."
python scripts/run_gx_validation.py

echo "Pipeline complete."
```

### Option 2: Python Validation Script

Create `scripts/run_gx_validation.py`:

```python
"""Run Great Expectations validation after dbt run."""
import sys
import great_expectations as gx
from great_expectations.core import ExpectationSuite

context = gx.get_context()

SUITES = {
    "CORTEX_RESEARCH.RAW.EARNINGS_CALLS": "earnings_calls_suite",
    "CORTEX_RESEARCH.RAW.SEC_FILINGS": "sec_filings_suite",
    "CORTEX_RESEARCH.RAW.STOCK_PRICES": "stock_prices_suite",
}

all_passed = True

for table, suite_name in SUITES.items():
    print(f"\nValidating {table} ({suite_name})...")

    datasource = context.sources.add_or_update_snowflake(
        name="snowflake_cortex",
        connection_string="snowflake://user:password@account/CORTEX_RESEARCH/RAW?warehouse=CORTEX_WH",
    )

    batch_request = datasource.get_batch_request(table_name=table)

    validator = context.get_validator(
        batch_request=batch_request,
        expectation_suite_name=suite_name,
    )

    result = validator.validate()

    status = "PASSED" if result.success else "FAILED"
    print(f"  {status}: {result.statistics['successful_expectations']}/{result.statistics['evaluated_expectations']} expectations passed")

    if not result.success:
        all_passed = False
        for res in result.results:
            if not res.success:
                print(f"  FAILED: {res.expectation_config.expectation_type} on {res.expectation_config.kwargs.get('column', 'table')}")

if not all_passed:
    print("\nData quality validation FAILED. Check results above.")
    sys.exit(1)

print("\nAll expectations passed.")
```

### Option 3: Scheduled Checkpoint

```bash
# Run GX validation as a scheduled task (e.g., via cron or Snowflake Task)
python scripts/run_gx_validation.py

# Or run as a dbt test
great_expectations checkpoint run after_dbt_run
```

---

## Generating Data Docs

Great Expectations auto-generates HTML documentation describing your data and validation results.

```bash
# Build Data Docs
great_expectations docs build

# Serve locally
great_expectations docs build --open
```

Data Docs include:
- **Expectation Suites**: What each table is expected to contain
- **Validation Results**: Pass/fail history for each suite
- **Data Profiling**: Statistical profiles of each column
- **Suite/Edit**: Interactive editor for adding/modifying expectations

---

## Integration with the CortexEdge Pipeline

```
Raw Data (SEC, Earnings, Prices)
    ↓
Great Expectations validation (expectation suites)
    ↓ (must pass)
dbt source freshness check
    ↓
Staging Models (stg_earnings_calls, stg_sec_filings, stg_stock_prices)
    ↓
Intermediate Models (int_earnings_sentiment, int_filing_classifications, int_price_metrics)
    ↓
Mart Models (mart_research_signals, mart_earnings_summary, mart_filing_dashboard)
    ↓
Dynamic Tables (auto-refresh)
```

### Pipeline Integration Pattern

```yaml
# In your CI/CD pipeline or Snowflake Task
steps:
  - name: Validate raw data
    run: python scripts/run_gx_validation.py
    description: "Run GX expectation suites before dbt models"

  - name: Run dbt
    run: dbt run
    description: "Transform validated raw data into staging → marts"

  - name: Generate docs
    run: dbt docs generate
    description: "Document the pipeline"
```

---

## GX vs Elementary: Complementary Tools

| Aspect | Great Expectations | Elementary |
|--------|--------------------|------------|
| **Focus** | Data validation (assertions on data) | Data observability (monitoring, anomaly detection) |
| **When to run** | Before dbt run (pre-ingestion gate) | After dbt run (post-transformation monitoring) |
| **Checks** | Exact rules (column must be non-null, values in set) | Statistical anomalies (volume spike, schema drift) |
| **Use case** | Catch bad raw data before it enters the pipeline | Detect issues that emerge over time |
| **Output** | Pass/fail per expectation | Dashboard + alerts |

Use both: GX as a quality gate before dbt, Elementary for ongoing monitoring after dbt.

---

## References

- [Great Expectations Documentation](https://docs.greatexpectations.io/)
- [GX Snowflake Integration](https://docs.greatexpectations.io/docs/reference/integrations/datasource-framework/snowflake)
- [dbt + GX Integration](https://docs.greatexpectations.io/docs/reference/integrations/dbt)
- [CortexEdge Elementary Integration](./ELEMENTARY_INTEGRATION.md)
