-- DuckDB Initialization Script
-- This script sets up GCS access and creates views for parquet files
-- Variables will be substituted by envsubst or Python string formatting

-- Install and load httpfs extension
INSTALL httpfs;
LOAD httpfs;

-- Create GCS secret using environment variable placeholders
-- For envsubst (CLI): uses $VARIABLE syntax
-- For Python: can be replaced with {VARIABLE} or use this as template
CREATE SECRET (TYPE GCS, KEY_ID '$HMAC_ACCESS_ID', SECRET '$HMAC_SECRET');

-- Create raw schema
CREATE SCHEMA IF NOT EXISTS raw;

-- Create views using bucket name placeholder
CREATE OR REPLACE VIEW raw.expenses AS 
SELECT * FROM read_parquet('gcs://$GCS_BUCKET_NAME/raw/expenses/data.parquet');

CREATE OR REPLACE VIEW raw.monthly_category_amounts AS 
SELECT * FROM read_parquet('gcs://$GCS_BUCKET_NAME/raw/monthly_category_amounts/data.parquet');

CREATE OR REPLACE VIEW raw.rate AS 
SELECT * FROM read_parquet('gcs://$GCS_BUCKET_NAME/raw/rate/data.parquet');