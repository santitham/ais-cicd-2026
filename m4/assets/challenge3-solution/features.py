# Databricks notebook source
dbutils.widgets.text("catalog", "")
dbutils.widgets.text("schema", "")
print("features in", dbutils.widgets.get("catalog"), dbutils.widgets.get("schema"))
