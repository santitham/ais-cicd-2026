# Databricks notebook source
# MAGIC %md
# MAGIC # MLflow demo — churn prediction in 30 seconds
# MAGIC
# MAGIC A tiny scikit-learn classifier trained on a synthetic churn dataset, logged to MLflow.
# MAGIC
# MAGIC Used in Module 1 Lab B to demonstrate Databricks Repos + a real ML workload.
# MAGIC
# MAGIC **What you should see when this finishes:**
# MAGIC - A trained random forest model (~80% accuracy on synthetic data)
# MAGIC - An MLflow run logged to the workspace Experiments tab
# MAGIC - The model registered to the MLflow Model Registry (optional)

# COMMAND ----------

# MAGIC %pip install scikit-learn==1.5.0 mlflow==2.12.2 pandas==2.2.0
# MAGIC %restart_python

# COMMAND ----------

# MAGIC %md
# MAGIC ## 1. Generate a synthetic churn dataset
# MAGIC
# MAGIC In real life this would be a Delta table; here we build it in pandas so the notebook is self-contained.

# COMMAND ----------

import numpy as np
import pandas as pd
from sklearn.datasets import make_classification

X, y = make_classification(
    n_samples=2_000,
    n_features=8,
    n_informative=5,
    n_redundant=2,
    n_classes=2,
    weights=[0.7, 0.3],     # 30% churn rate
    random_state=42,
)
feature_cols = [
    "tenure_months", "monthly_spend", "support_tickets",
    "logins_last_30d", "feature_use_count", "is_paid_tier",
    "days_since_last_login", "nps_score",
]
df = pd.DataFrame(X, columns=feature_cols)
df["churned"] = y
display(df.head())

# COMMAND ----------

# MAGIC %md
# MAGIC ## 2. Train + log with MLflow

# COMMAND ----------

import mlflow
import mlflow.sklearn
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score, f1_score, roc_auc_score

X_train, X_test, y_train, y_test = train_test_split(
    df[feature_cols], df["churned"], test_size=0.2, random_state=42
)

# Enable autologging — MLflow records params, metrics, and the model for free.
mlflow.sklearn.autolog()

with mlflow.start_run(run_name="churn-demo-rf") as run:
    model = RandomForestClassifier(
        n_estimators=100,
        max_depth=6,
        random_state=42,
    )
    model.fit(X_train, y_train)

    preds = model.predict(X_test)
    proba = model.predict_proba(X_test)[:, 1]

    metrics = {
        "test_accuracy": accuracy_score(y_test, preds),
        "test_f1":       f1_score(y_test, preds),
        "test_auroc":    roc_auc_score(y_test, proba),
    }
    mlflow.log_metrics(metrics)

    print("Run id:", run.info.run_id)
    for k, v in metrics.items():
        print(f"  {k}: {v:.3f}")

# COMMAND ----------

# MAGIC %md
# MAGIC ## 3. Inspect the run
# MAGIC
# MAGIC Click the **Experiments** icon (the flask) in the left sidebar. You'll see the run you just created with the metrics, the model artifact, and the feature importances chart MLflow auto-generated.
# MAGIC
# MAGIC In Day 4 we'll deploy this exact pattern as a scheduled job through CI/CD.
