# Databricks notebook source

# COMMAND ----------

dbutils.widgets.text("catalog", "")   # noqa: F821
dbutils.widgets.text("schema", "")    # noqa: F821

catalog = dbutils.widgets.get("catalog")   # noqa: F821
schema = dbutils.widgets.get("schema")     # noqa: F821

# COMMAND ----------

# This task and `quality` both depend only on `land`, so they start together.
# They run on separate job clusters, which is what turns that into real
# parallelism rather than two tasks queued on one cluster.
from pyspark.sql import functions as F

rows = [(i, f"order-{i}", (i % 7) * 1.5) for i in range(1, 501)]
df = spark.createDataFrame(rows, "id int, ref string, amount double")   # noqa: F821

features = (
    df.withColumn("amount_band", F.when(F.col("amount") > 6.0, "high").otherwise("low"))
      .groupBy("amount_band")
      .agg(F.count("*").alias("n"), F.round(F.avg("amount"), 2).alias("avg_amount"))
)
features.show()

built = features.count()
print(f"built {built} feature bands for {catalog}.{schema}")

# COMMAND ----------

dbutils.notebook.exit(f"bands={built} target={catalog}.{schema}")   # noqa: F821
