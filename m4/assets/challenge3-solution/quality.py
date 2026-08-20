# Databricks notebook source
dbutils.widgets.text("catalog", "")
dbutils.widgets.text("schema", "")
print("quality in", dbutils.widgets.get("catalog"), dbutils.widgets.get("schema"))
