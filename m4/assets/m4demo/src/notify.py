# Databricks notebook source

# COMMAND ----------

# This task declares run_if: ALL_DONE, so it runs whether or not the pipeline
# succeeded. It takes no parameters: a notification does not need to know the
# catalog, and giving it one would be a dependency it does not have.
print("pipeline finished")

# COMMAND ----------

dbutils.notebook.exit("notified")   # noqa: F821
