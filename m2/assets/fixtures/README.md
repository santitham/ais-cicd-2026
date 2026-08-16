# Module 2 — fixture files

Every file the Module 2 slides and labs refer to as `fixtures/<name>.yml`.

These are also written by `../prep-ubuntu.sh`, which is the source of truth. If
you change a fixture here, change it there as well, or the Ubuntu server and the
course folder will drift apart.

| File | Used by | What it is |
|---|---|---|
| `pipeline.yml` | Challenge 1, Challenge 3, slide "yq on a valid file" | A correct, neutral pipeline configuration. The document students read and draw. |
| `skeleton.yml` | Challenge 4 | Five empty keys. The starting point for the authoring lab. |
| `scalars.yml` | Slide "The same lines under each indicator" | Literal, folded, stripped and plain multi-line scalars. |
| `runblock.yml` | Screenshot S18 | A `run:` block written twice, under `|` and under `>`. |
| `two-parsers.yml` | Screenshot S33 | Five lines that PyYAML and yq read differently. |
| `lint-valid.yml` | Reference | A correct GitHub Actions workflow. |
| `lint-tab.yml` | Screenshot S27 | A tab in the indentation. **Does not parse — this is intended.** |
| `lint-float.yml` | Screenshot S30 | `python-version: 3.10`, unquoted, so it resolves to 3.1. |
| `lint-norway.yml` | Slides on YAML 1.1 vs 1.2 | A step with `if: no`. |
| `lint-position.yml` | Slides on misplaced keys, screenshot S42 | `env:` indented one level too deep, inside `with:`. |
| `.yamllint.yml` | `validate.sh` | yamllint configuration used by the validation script. |
| `validate.sh` | Slides on checking each layer | Runs parse, style and schema checks in order. |

`lint-tab.yml` is the only file here that fails to parse, and it fails on purpose.
