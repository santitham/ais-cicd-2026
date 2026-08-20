# cicd-databricks-<yourname>

Companion repo for the *From Notebook to Production* course.

## Layout

```
.
├── etl/                # ETL pipelines, the focus of Day 1–2 labs
├── ml/                 # ML training and scoring jobs (added in Day 4)
├── tests/              # pytest unit + integration tests (added in Day 4)
├── databricks.yml      # Asset Bundle config (added in Day 2)
└── .github/workflows/  # CI/CD pipelines (added in Day 3)
```

## Running locally

```bash
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
pytest -q
```

## Running on Databricks

The asset bundle in `databricks.yml` knows how to deploy this repo to a Databricks workspace. The first invocation looks like:

```bash
databricks bundle validate
databricks bundle deploy --target dev
databricks bundle run clean_events --target dev
```
