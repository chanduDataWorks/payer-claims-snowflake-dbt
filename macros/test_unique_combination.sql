{#
    Generic model-level test: the combination of columns must be unique.
    (Same idea as dbt_utils.unique_combination_of_columns, without needing the package.)
#}
{% test unique_combination(model, columns) %}

select
    {{ columns | join(', ') }},
    count(*) as row_count
from {{ model }}
group by {{ columns | join(', ') }}
having count(*) > 1

{% endtest %}
