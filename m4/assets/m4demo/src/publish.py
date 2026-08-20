# Databricks notebook source

# COMMAND ----------

dbutils.widgets.text("catalog", "")   # noqa: F821
dbutils.widgets.text("schema", "")    # noqa: F821

catalog = dbutils.widgets.get("catalog")   # noqa: F821
schema = dbutils.widgets.get("schema")     # noqa: F821

# COMMAND ----------

# The fan-in. This task declares one depends_on block with two entries, so it
# waits for both features and quality. If either fails, this task is reported
# UPSTREAM_FAILED and never runs.
#
# Nothing is written. In a real pipeline this is where the write would be, and
# it is the reason a retry on this task would need the write to be idempotent.
target = f"{catalog}.{schema}.sales_daily"
print(f"would publish to {target}")

# COMMAND ----------

dbutils.notebook.exit(f"published={target}")   # noqa: F821
