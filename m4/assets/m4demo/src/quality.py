# Databricks notebook source

# COMMAND ----------

dbutils.widgets.text("catalog", "")   # noqa: F821
dbutils.widgets.text("schema", "")    # noqa: F821

catalog = dbutils.widgets.get("catalog")   # noqa: F821
schema = dbutils.widgets.get("schema")     # noqa: F821

# COMMAND ----------

# A sibling of `features`, not a descendant. When features fails, this one still
# succeeds, and that is the state pair Challenge 5 asks you to predict.
rows = [(i, f"order-{i}", (i % 7) * 1.5) for i in range(1, 501)]
df = spark.createDataFrame(rows, "id int, ref string, amount double")   # noqa: F821

nulls = df.filter("ref is null or amount is null").count()
negative = df.filter("amount < 0").count()
total = df.count()

print(f"checked {total} rows: {nulls} null, {negative} negative")

if nulls or negative:
    raise ValueError(f"quality gate failed: {nulls} null, {negative} negative")

# COMMAND ----------

dbutils.notebook.exit(f"checked={total} nulls=0 negative=0")   # noqa: F821
