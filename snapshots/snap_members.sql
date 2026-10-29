{#
    SCD Type 2 history of members.
    When a member changes plan, county or coverage end date, dbt closes the
    old row (dbt_valid_to) and inserts a new current row.
    Run with:  dbt snapshot
#}
{% snapshot snap_members %}

{{
    config(
        unique_key='member_id',
        strategy='check',
        check_cols=['plan_code', 'county', 'coverage_end_date']
    )
}}

select * from {{ ref('stg_members') }}

{% endsnapshot %}
