# Databricks Asset Bundles — quick reference

> One page. Print it. Stick it next to your monitor.

## Lifecycle

```bash
databricks bundle init <template>          # scaffold from a template
databricks bundle validate --target <t>    # syntax + schema check (no network)
databricks bundle summary --target <t>     # what would deploy?
databricks bundle deploy --target <t>      # apply the spec to the workspace
databricks bundle run <job-key> --target <t>     # trigger a deployed job
databricks bundle destroy --target <t>     # remove everything the bundle created
```

## Templates

| Template | When to use |
|---|---|
| `default-python` | Generic Python jobs, ETL pipelines, batch ML scoring |
| `default-sql` | dbt / SQL warehouse-only projects |
| `mlops-stacks` | ML training, model registry, scoring jobs together |

## Variables

```yaml
variables:
  notification_email:
    description: "Who gets paged"
    default: "oncall@example.com"
```

Reference with `${var.notification_email}` anywhere in the file.

Override priority (lowest → highest):

1. `default:` in the variable block
2. `targets.<name>.variables:` overrides
3. Environment variable `BUNDLE_VAR_notification_email=…`
4. CLI flag `--var notification_email=…`

## Built-in interpolations

| Token | Resolves to |
|---|---|
| `${bundle.name}` | The bundle's `name:` |
| `${bundle.target}` | Active target name (dev / staging / prod) |
| `${workspace.host}` | The active target's workspace URL |
| `${workspace.current_user.userName}` | The user / SP performing the deploy |
| `${workspace.file_path}` | Where bundle files are uploaded |

## Development mode behaviour

When `mode: development`:

- Schedules are paused.
- Resource display names are prefixed with `[username]`.
- Continuous pipelines are disabled.
- Bundle root is uploaded to a per-user folder.

When `mode: production`:

- Schedules run as configured.
- Names are clean.
- Deploys must come from a service principal, not a user (configurable).

## Common shapes

### Reference a notebook

```yaml
notebook_task:
  notebook_path: ../notebooks/clean_events
  base_parameters:
    run_date: "{{job.start_time.iso_date}}"
```

### Reference a Python file

```yaml
spark_python_task:
  python_file: ../src/clean_events.py
  parameters: ["--env", "dev"]
```

### Reference a Python wheel built from this bundle

```yaml
python_wheel_task:
  package_name: cicd_databricks
  entry_point: clean_events.main
```

## Things bundles do NOT manage

- The workspace itself (use Terraform).
- Account-level objects: users, groups, catalogs, account-level metastores.
- Secrets — bundles can reference scopes that already exist, but won't create the secret values themselves.

## Things bundles DO manage

- Jobs, pipelines (DLT), MLflow experiments, model serving endpoints, dashboards (lakeview), schemas, volumes.
- Files uploaded to the workspace.
- The deployment metadata (which version of the bundle is currently deployed).
