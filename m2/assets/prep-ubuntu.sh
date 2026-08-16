#!/usr/bin/env bash
# Module 2 — screenshot preparation for Ubuntu
#
#   bash prep-ubuntu.sh
#
# Installs the tools the Module 2 captures need and writes every fixture file
# used by capture-screenshots.md. Safe to re-run. Installs require sudo.
#
# No Git anywhere: actionlint is invoked on explicit file paths, which works
# outside a repository.

set -euo pipefail

DEMO_DIR="${HOME}/m2-demo"
ACTIONLINT_VERSION="1.7.7"

say() { printf '\n=== %s ===\n' "$1"; }

# ---------------------------------------------------------------------------
say "yq"
# Do NOT use `apt install yq`. Ubuntu's package of that name is a Python
# wrapper around jq with incompatible syntax; it reports version 0.0.0 and
# none of the commands in this module work. Install the Go binary.
if command -v yq >/dev/null 2>&1 && yq --version 2>&1 | grep -q mikefarah; then
    echo "already installed: $(yq --version)"
else
    sudo wget -qO /usr/local/bin/yq \
        https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
    sudo chmod +x /usr/local/bin/yq
    hash -r
    echo "installed: $(yq --version)"
fi

# ---------------------------------------------------------------------------
say "actionlint"
if command -v actionlint >/dev/null 2>&1; then
    echo "already installed: $(actionlint --version | head -1)"
else
    tmp="$(mktemp -d)"
    wget -qO "${tmp}/actionlint.tgz" \
        "https://github.com/rhysd/actionlint/releases/download/v${ACTIONLINT_VERSION}/actionlint_${ACTIONLINT_VERSION}_linux_amd64.tar.gz"
    tar xzf "${tmp}/actionlint.tgz" -C "${tmp}" actionlint
    sudo install -m 0755 "${tmp}/actionlint" /usr/local/bin/actionlint
    rm -rf "${tmp}"
    hash -r
    echo "installed: $(actionlint --version | head -1)"
fi

# ---------------------------------------------------------------------------
say "jq, PyYAML, yamllint"
sudo apt-get update -qq
sudo apt-get install -y -qq jq python3-yaml yamllint
echo "jq       : $(jq --version)"
echo "PyYAML   : $(python3 -c 'import yaml; print(yaml.__version__)')"
echo "yamllint : $(yamllint --version)"

# ---------------------------------------------------------------------------
say "Databricks CLI"
if command -v databricks >/dev/null 2>&1; then
    echo "already installed: $(databricks --version)"
else
    curl -fsSL https://raw.githubusercontent.com/databricks/setup-cli/main/install.sh | sudo sh
    hash -r
    echo "installed: $(databricks --version)"
fi

# ---------------------------------------------------------------------------
say "fixtures in ${DEMO_DIR}"
rm -rf "${DEMO_DIR}"
mkdir -p "${DEMO_DIR}/fixtures"
cd "${DEMO_DIR}"

# --- the correct file -------------------------------------------------------
cat > fixtures/lint-valid.yml <<'EOF'
name: lint

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - name: Check out code
        uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.11"

      - name: Install flake8
        run: pip install flake8

      - name: Run flake8
        run: flake8 etl/ --max-line-length=100
EOF

# --- class 1: a tab in the indentation (printf, so the tab survives) --------
{
    printf 'name: lint\n\n'
    printf 'on:\n  push:\n    branches: [main]\n\n'
    printf 'jobs:\n  lint:\n'
    printf '\truns-on: ubuntu-latest\n'
    printf '    steps:\n      - name: Check out code\n        uses: actions/checkout@v4\n'
} > fixtures/lint-tab.yml

# --- class 2: unquoted version resolves to a float --------------------------
sed 's/python-version: "3.11"/python-version: 3.10/' \
    fixtures/lint-valid.yml > fixtures/lint-float.yml

# --- class 3: the Norway problem --------------------------------------------
cp fixtures/lint-valid.yml fixtures/lint-norway.yml
cat >> fixtures/lint-norway.yml <<'EOF'

      - name: Check (no, really)
        if: no
        run: echo "this never runs"
EOF

# --- class 3b: the five-line file for the two-parser comparison (S33) -------
cat > fixtures/two-parsers.yml <<'EOF'
on:
  push:
    branches: [main]
python-version: 3.10
enabled: no
country: NO
EOF

# --- class 4: env indented one level too deep -------------------------------
cat > fixtures/lint-position.yml <<'EOF'
name: lint

on:
  push:
    branches: [main]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.11"
          env:
            TOKEN: abc
EOF

# --- block scalars (S17, S18) -----------------------------------------------
cat > fixtures/scalars.yml <<'EOF'
literal: |
  line one
  line two
folded: >
  line one
  line two
literal_strip: |-
  line one
  line two
plain_multiline: line one
  line two
quoted: "has: a colon"
EOF

cat > fixtures/runblock.yml <<'EOF'
steps:
  - name: literal
    run: |
      pip install flake8
      flake8 etl/ --max-line-length=100

  - name: folded
    run: >
      pip install flake8
      flake8 etl/ --max-line-length=100
EOF

# --- the document used for reading practice and Challenges 1 and 3 ---------
cat > fixtures/pipeline.yml <<'EOF'
pipeline:
  name: customer_features
  enabled: true
  owners:
    - data-science
    - data-engineering
  settings:
    retries: 3
    timeout_minutes: 20
tasks:
  - name: prepare_data
    notebook: notebooks/prepare
    retries: 2
  - name: train_model
    notebook: notebooks/train
    retries: 1
EOF

# --- the starting point for Challenge 4 (authoring) ------------------------
cat > fixtures/skeleton.yml <<'EOF'
project:
  name:
  owner:
environments:
tasks:
EOF

# --- yamllint configuration -------------------------------------------------
cat > .yamllint.yml <<'EOF'
extends: default
rules:
  line-length: disable
  document-start: disable
  truthy:
    check-keys: false
EOF

# --- the validation script (S43, S44) ---------------------------------------
cat > validate.sh <<'SH'
#!/usr/bin/env bash
# validate.sh — run levels 1 to 3 against one YAML file, stopping at the first
# failure so the output names the level that rejected it.
set -u
f="${1:?usage: ./validate.sh <file.yml>}"

printf '\n[1] parse            : '
if yq . "$f" >/dev/null 2>&1; then echo "ok"
else echo "FAILED"; yq . "$f"; exit 1; fi

printf '[2] style and truthy : '
if yamllint -s -c .yamllint.yml "$f" >/dev/null 2>&1; then echo "ok"
else echo "FAILED"; yamllint -c .yamllint.yml "$f"; exit 1; fi

printf '[3] workflow schema  : '
if actionlint "$f" >/dev/null 2>&1; then echo "ok"
else echo "FAILED"; actionlint "$f"; exit 1; fi

echo "all three levels passed: $f"
SH
chmod +x validate.sh

say "done"
echo "Fixtures : ${DEMO_DIR}/fixtures"
echo "Script   : ${DEMO_DIR}/validate.sh"
echo
echo "Next: cd ${DEMO_DIR} and follow capture-screenshots.md."
