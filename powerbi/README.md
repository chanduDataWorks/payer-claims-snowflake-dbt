# Power BI layer

Connect Power BI Desktop to Snowflake and build a 2-page report on the marts.

## 1. Connect

1. **Get Data → Snowflake**
2. Server: `<your_account>.snowflakecomputing.com`, Warehouse: `TRANSFORM_WH`
3. Sign in, choose role `REPORTER` if prompted
4. Select from `PAYER_CLAIMS.DEV_MARTS`: `FCT_CLAIMS`, `DIM_MEMBER`, `DIM_PROVIDER`, `MART_PLAN_MONTHLY_SUMMARY`
5. Choose **Import** (fine for this data size; use DirectQuery for very large tables)

## 2. Model (star schema)

| From (many) | To (one) | Column | Direction |
| --- | --- | --- | --- |
| FCT_CLAIMS | DIM_MEMBER | MEMBER_ID | Single |
| FCT_CLAIMS | DIM_PROVIDER | PROVIDER_NPI | Single |

Add a date table (Modeling → New table):

```DAX
Date =
ADDCOLUMNS (
    CALENDAR ( DATE ( 2024, 1, 1 ), DATE ( 2025, 12, 31 ) ),
    "Year", YEAR ( [Date] ),
    "Month", FORMAT ( [Date], "MMM yyyy" ),
    "MonthSort", YEAR ( [Date] ) * 100 + MONTH ( [Date] )
)
```

Mark it as a date table, then relate `Date[Date]` → `FCT_CLAIMS[SERVICE_DATE]` and `Date[Date]` → `MART_PLAN_MONTHLY_SUMMARY[MONTH_START]`, so the date slicers filter both. Sort `Month` by `MonthSort`.

## 3. Measures

Put these in a dedicated `_Measures` table.

```DAX
Total Paid = SUM ( FCT_CLAIMS[PAID_AMOUNT] )

Total Billed = SUM ( FCT_CLAIMS[BILLED_AMOUNT] )

Total Allowed = SUM ( FCT_CLAIMS[ALLOWED_AMOUNT] )

Claim Count = COUNTROWS ( FCT_CLAIMS )

Denied Claims =
CALCULATE ( [Claim Count], FCT_CLAIMS[CLAIM_STATUS] = "DENIED" )

Denial Rate = DIVIDE ( [Denied Claims], [Claim Count] )

Discount % = DIVIDE ( [Total Billed] - [Total Allowed], [Total Billed] )

Avg Days to Pay = AVERAGE ( FCT_CLAIMS[DAYS_RECEIVED_TO_PAID] )

Member Months = SUM ( MART_PLAN_MONTHLY_SUMMARY[MEMBER_MONTHS] )

Paid PMPM =
DIVIDE ( SUM ( MART_PLAN_MONTHLY_SUMMARY[TOTAL_PAID] ), [Member Months] )

Total Paid PY =
CALCULATE ( [Total Paid], SAMEPERIODLASTYEAR ( 'Date'[Date] ) )

Paid YoY % = DIVIDE ( [Total Paid] - [Total Paid PY], [Total Paid PY] )

In-Network Paid % =
DIVIDE (
    CALCULATE ( [Total Paid], DIM_PROVIDER[IS_IN_NETWORK] = TRUE () ),
    [Total Paid]
)
```

## 4. Report pages

**Page 1: Executive summary**
- KPI cards: Total Paid, Claim Count, Denial Rate, Paid PMPM, Avg Days to Pay
- Line chart: Total Paid by Month, with Paid YoY % as a tooltip
- Clustered bar: Paid PMPM by Plan Code
- Slicers: Plan Type, Year

**Page 2: Denials and providers**
- Bar: Denied Claims by Denial Reason
- Matrix: Specialty × Plan Type showing Total Paid and Denial Rate
- Table: top 10 providers by Total Paid, with In-Network flag

Save screenshots of both pages into `/images` in the repo for your README and Upwork portfolio.
