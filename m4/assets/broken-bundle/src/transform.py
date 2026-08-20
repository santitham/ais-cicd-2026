dbutils.widgets.text("catalog", "")
dbutils.widgets.text("schema", "")
print("transform in", dbutils.widgets.get("catalog"))
