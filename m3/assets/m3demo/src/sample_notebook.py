# Databricks notebook source

# This file is a notebook because of the header line above. Without it the
# workspace imports it as a plain Python file and the task fails to start.

# COMMAND ----------

print("hello from the deployed copy")

# COMMAND ----------

# print() output does not reach the API for a notebook task. A notebook must
# exit with a value for `databricks bundle run` and the jobs API to report one.
dbutils.notebook.exit("ok")  # noqa: F821
