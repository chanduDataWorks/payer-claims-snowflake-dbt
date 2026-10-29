{#
    Schema naming:
      - prod target  -> use the custom schema as-is      (RAW, STAGING, MARTS)
      - any other    -> prefix with the target schema     (DEV_STAGING, DEV_MARTS)
    This keeps each developer's objects separate from production.
#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- set default_schema = target.schema -%}
    {%- if custom_schema_name is none -%}
        {{ default_schema }}
    {%- elif target.name == 'prod' -%}
        {{ custom_schema_name | trim }}
    {%- else -%}
        {{ default_schema }}_{{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
