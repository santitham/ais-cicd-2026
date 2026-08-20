# Databricks notebook source
dbutils.widgets.text("catalog", "")
dbutils.widgets.text("schema", "")
print("extract into", dbutils.widgets.get("catalog"), dbutils.widgets.get("schema"))
