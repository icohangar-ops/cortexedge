{% macro cortex_embeddings(text_col, model='snowflake-arctic-embed-m') %}

    SNOWFLAKE.CORTEX.EMBED_TEXT_768('{{ model }}', {{ text_col }})

{% endmacro %}
