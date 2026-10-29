-- =====================================================================
-- One-time Snowflake setup for the payer_claims dbt project.
-- Run in a Snowsight worksheet as ACCOUNTADMIN (a free trial works).
-- =====================================================================

use role accountadmin;

-- 1. Warehouse: smallest size, suspends after 60s idle to save credits
create warehouse if not exists transform_wh
    warehouse_size = 'XSMALL'
    auto_suspend = 60
    auto_resume = true
    initially_suspended = true
    comment = 'dbt transformations for payer_claims';

-- 2. Cost guardrail: stop the warehouse if it burns more than 5 credits a month
create resource monitor if not exists transform_monitor
    with credit_quota = 5
    frequency = monthly
    start_timestamp = immediately
    triggers on 80 percent do notify
             on 100 percent do suspend;

alter warehouse transform_wh set resource_monitor = transform_monitor;

-- 3. Database. dbt creates the schemas (DEV_RAW, DEV_STAGING, DEV_MARTS ...)
create database if not exists payer_claims;

-- 4. Role-based access: dbt runs as TRANSFORMER, Power BI reads as REPORTER
create role if not exists transformer;
create role if not exists reporter;

grant usage on warehouse transform_wh to role transformer;
grant usage on warehouse transform_wh to role reporter;

grant usage, create schema on database payer_claims to role transformer;
grant usage on database payer_claims to role reporter;

-- reporter can read every current and future table/view in the database
grant usage on future schemas in database payer_claims to role reporter;
grant select on future tables in database payer_claims to role reporter;
grant select on future views  in database payer_claims to role reporter;

-- 5. Give both roles to the user running this script
set my_user = current_user();
grant role transformer to user identifier($my_user);
grant role reporter    to user identifier($my_user);

-- role hierarchy: SYSADMIN can manage what TRANSFORMER builds
grant role transformer to role sysadmin;
grant role reporter    to role sysadmin;

-- 6. Quick check
show grants to role transformer;
