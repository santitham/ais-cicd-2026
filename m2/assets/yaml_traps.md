# YAML traps — a cheatsheet

> The four common ways a YAML file is "valid" but silently wrong.

## Trap 1 — Tabs instead of spaces

YAML rejects tab characters in indentation. Most editors render tabs identically to spaces, so the eye misses it.

```yaml
jobs:
  lint:
	runs-on: ubuntu-latest   # ← this line starts with a tab
```

**Detection:** `yq .` reports `found character that cannot start any token`.

**Prevention:** in your editor, set tab→4 spaces; show whitespace characters.

---

## Trap 2 — Implicit string vs. number

```yaml
python-version: 3.10     # parsed as the float 3.1
python-version: "3.10"   # parsed as the string "3.10"   ✓
```

Versions, IDs, and account numbers should always be quoted.

**Detection:** `yq '.python-version | type'` returns `!!float`.

---

## Trap 3 — The Norway problem

YAML 1.1 (which GitHub Actions and many tools still use) interprets a long list of words as booleans, not strings:

| Written | Parsed |
|---|---|
| `yes` / `Yes` / `YES` | `true` |
| `no` / `No` / `NO` | `false` |
| `on` / `On` / `ON` | `true` |
| `off` / `Off` / `OFF` | `false` |

So `country: no` becomes `country: false`. Always quote two-letter codes and human-readable yes/no values:

```yaml
country: "NO"
enabled: "yes"      # if you mean the string
enabled: true       # if you mean the boolean
```

**Detection:** if a field unexpectedly disappears or becomes a boolean, suspect this first.

---

## Trap 4 — Off-by-one indentation

Sibling keys at the same level must have the same indentation:

```yaml
with:
  python-version: "3.11"
   cache: pip                  # ← one extra space — now a child of "python-version"
```

This parses without error. The `setup-python` action just sees `python-version` as a mapping rather than a string and fails at runtime.

**Detection:** `yq .` and look at the parsed structure, not the file. Or use the **YAML** extension in VS Code with schema validation.

---

## Quick reference: validate before you commit

```bash
# generic YAML validation
yq . path/to/file.yml

# pretty-print parsed structure
yq -o json . path/to/file.yml | jq

# Databricks Asset Bundle validation (schema-aware)
databricks bundle validate

# GitHub Actions workflow validation (locally, via act)
act -l                              # list workflows the way GHA sees them
```
