{% macro test_number_range(model, column_name, min_value) %}
    
    select *
    from {{ model }}
    where {{ column_name }} < {{ min_value }}
{% endmacro %}


