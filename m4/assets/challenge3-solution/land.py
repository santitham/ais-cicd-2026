# Databricks notebook source
dbutils.widgets.text("catalog", "")
dbutils.widgets.text("schema", "")
print("land in", dbutils.widgets.get("catalog"), dbutils.widgets.get("schema"))
