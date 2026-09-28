FROM python:3.12-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends git \
    && rm -rf /var/lib/apt/lists/* \
    && pip install --no-cache-dir "dbt-core~=1.12.0" "dbt-snowflake~=1.12.0"

WORKDIR /usr/app/dbt
ENV DBT_PROFILES_DIR=/usr/app/dbt
ENTRYPOINT ["sh", "scripts/with_snowflake_env.sh", "dbt"]
CMD ["build"]
