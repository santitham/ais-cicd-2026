# Databricks notebook source
dbutils.widgets.text("catalog", "")
dbutils.widgets.text("schema", "")
print("landing raw sales into", dbutils.widgets.get("catalog"), dbutils.widgets.get("schema"))
