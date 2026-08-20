# Databricks notebook source

# The header line above is what makes this a notebook rather than a Python
# file. Without it, bundle validate refuses the task:
#   Error: expected a notebook for "...notebook_path" but got a file

# COMMAND ----------

dbutils.widgets.text("catalog", "")   # noqa: F821
dbutils.widgets.text("schema", "")    # noqa: F821

catalog = dbutils.widgets.get("catalog")   # noqa: F821
schema = dbutils.widgets.get("schema")     # noqa: F821

# COMMAND ----------

# Genuine Spark work, so the job cluster is actually exercised, but nothing is
# written: this bundle never touches Unity Catalog, so it cannot fail on a
# missing grant. The catalog and schema are carried through and reported so the
# difference between targets is visible in the run output.
rows = [(i, f"order-{i}", (i % 7) * 1.5) for i in range(1, 501)]
raw = spark.createDataFrame(rows, "id int, ref string, amount double")   # noqa: F821
landed = raw.count()

print(f"landed {landed} rows, destined for {catalog}.{schema}")

# COMMAND ----------

# print() output does not reach the API for a notebook task. A notebook has to
# exit with a value for `databricks bundle run` and the Jobs API to report one.
dbutils.notebook.exit(f"landed={landed} target={catalog}.{schema}")   # noqa: F821
