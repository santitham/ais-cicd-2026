"""etl/clean_events.py — starter module for Module 1 labs.

The function below is intentionally incomplete. Lab A asks you to fill in the
TODO so that null tenant_ids are dropped before any downstream logic runs.

Run locally with a tiny dummy DataFrame; we'll wire it up to Databricks in
later modules.
"""
from __future__ import annotations

from pyspark.sql import DataFrame


def clean_events(df: DataFrame) -> DataFrame:
    """Return a cleaned copy of the events DataFrame.

    Inputs: a Spark DataFrame with at least the columns
        tenant_id (string), event_ts (timestamp), event_type (string).

    Output: same schema, with invalid rows removed.
    """
    print("Cleaning events…")

    # TODO: drop rows where tenant_id is null
    # Hint: df.filter(df["tenant_id"].isNotNull())

    # de-duplicate exact-duplicate events (already implemented)
    df = df.dropDuplicates(["tenant_id", "event_ts", "event_type"])

    return df


if __name__ == "__main__":
    # Quick smoke test using a local Spark session.
    from pyspark.sql import SparkSession

    spark = SparkSession.builder.appName("clean_events_smoke").getOrCreate()
    rows = [
        ("t1", "2026-01-01 00:00:00", "view"),
        (None, "2026-01-01 00:00:01", "view"),     # should be dropped
        ("t2", "2026-01-01 00:00:02", "click"),
        ("t1", "2026-01-01 00:00:00", "view"),     # duplicate
    ]
    df = spark.createDataFrame(rows, ["tenant_id", "event_ts", "event_type"])
    clean_events(df).show()
