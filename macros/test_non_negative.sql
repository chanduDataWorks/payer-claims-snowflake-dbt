{#
    Generic test: fails for any row where the column is negative.
    Usage in YAML:
        - name: paid_amount
          data_tests:
            - non_negative
#}
{% test non_negative(model, column_name) %}

select {{ column_name }}
from {{ model }}
where {{ column_name }} < 0

{% endtest %}
