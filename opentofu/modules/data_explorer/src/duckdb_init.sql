-- DuckDB Initialization Script for Iceberg Tables
-- This script sets up GCS access and creates views for Iceberg tables

-- Install required extensions
INSTALL httpfs;
INSTALL iceberg;
LOAD httpfs;
LOAD iceberg;

-- Create GCS secret using environment variable placeholders
CREATE $SECRET_TYPE (TYPE GCS, KEY_ID '$HMAC_ACCESS_ID', SECRET '$HMAC_SECRET');

-- Create raw schema
CREATE SCHEMA IF NOT EXISTS raw;

-- Create views for Iceberg tables
-- Note: Iceberg tables store metadata files that DuckDB can read directly
CREATE OR REPLACE VIEW raw.expenses AS
SELECT * FROM iceberg_scan('gcs://$GCS_BUCKET_NAME/raw/expenses');

CREATE OR REPLACE VIEW raw.monthly_category_amounts AS
SELECT * FROM iceberg_scan('gcs://$GCS_BUCKET_NAME/raw/monthly_category_amounts');

CREATE OR REPLACE VIEW raw.rate AS
SELECT * FROM iceberg_scan('gcs://$GCS_BUCKET_NAME/raw/rate');
