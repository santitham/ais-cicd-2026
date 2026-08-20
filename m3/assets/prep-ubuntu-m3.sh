#!/usr/bin/env bash
# Module 3 — environment preparation for Ubuntu
#
#   bash prep-ubuntu-m3.sh
#
# Installs and verifies everything Module 3 needs, then reports what it found.
# Safe to re-run. Only the apt step requires sudo.
#
# Run this before the module, not during it. Every check below corresponds to a
# failure that otherwise arrives in the middle of a lab.

set -uo pipefail

CLI_MIN="1.3.0"
say()  { printf '\n=== %s ===\n' "$1"; }
fail() { printf '  FAIL  %s\n' "$1"; FAILED=1; }
ok()   { printf '  ok    %s\n' "$1"; }
FAILED=0

# ---------------------------------------------------------------------------
say "Databricks CLI"
# The modern CLI is a single Go binary. The legacy databricks-cli Python
# package shares the command name and has no bundle subcommands at all.
if command -v databricks >/dev/null 2>&1; then
    ok "installed: $(databricks --version)"
else
    curl -fsSL https://raw.githubusercontent.com/databricks/setup-cli/main/install.sh | sh
    hash -r
    ok "installed: $(databricks --version)"
fi

# Version comparison: v1.3.0 is the release at which new bundles began using
# the direct deployment engine. Earlier versions accept bundle commands but
# write Terraform state, which changes what participants see in .databricks/.
have="$(databricks --version | sed 's/^Databricks CLI v//')"
lowest="$(printf '%s\n%s\n' "$CLI_MIN" "$have" | sort -V | head -1)"
if [ "$lowest" = "$CLI_MIN" ]; then
    ok "v${have} satisfies the v${CLI_MIN} minimum"
else
    fail "v${have} is older than v${CLI_MIN}; upgrade before the module"
fi

# ---------------------------------------------------------------------------
say "uv"
# The default-python template builds a wheel with `uv build --wheel`. Without
# uv, `bundle plan` and `bundle deploy` both fail at the build stage with
# exit status 127 and "uv: command not found".
if command -v uv >/dev/null 2>&1; then
    ok "installed: $(uv --version)"
else
    curl -LsSf https://astral.sh/uv/install.sh | sh
    # The installer writes to ~/.local/bin, which is not on PATH in the shell
    # that is already open. It appends the export to ~/.bashrc for later shells.
    export PATH="${HOME}/.local/bin:${PATH}"
    hash -r
    if command -v uv >/dev/null 2>&1; then
        ok "installed: $(uv --version)"
        printf '  note  add this to the shell you run databricks from:\n'
        printf '        export PATH="$HOME/.local/bin:$PATH"\n'
    else
        fail "uv installed but not on PATH; export PATH=\"\$HOME/.local/bin:\$PATH\""
    fi
fi

# The CLI runs the build through /usr/bin/bash -c, which inherits the
# environment of the databricks process. Confirm uv is visible the same way.
if bash -c 'command -v uv' >/dev/null 2>&1; then
    ok "uv is visible to the shell the CLI builds in"
else
    fail "uv is not on PATH for non-interactive bash; the build stage will fail"
fi

# ---------------------------------------------------------------------------
say "jq"
if command -v jq >/dev/null 2>&1; then
    ok "installed: $(jq --version)"
else
    sudo apt-get update -qq && sudo apt-get install -y -qq jq
    ok "installed: $(jq --version)"
fi

# ---------------------------------------------------------------------------
say "Authentication"
# bundle init is not an offline command: the template reads the metastore
# assignment to propose a default catalog and the SCIM endpoint for the user
# name. Both must succeed before a single file is written.
if databricks current-user me -o json >/tmp/m3-whoami.json 2>/tmp/m3-whoami.err; then
    ok "current user: $(jq -r .userName /tmp/m3-whoami.json)"
else
    fail "current-user me failed: $(grep -v '^Warn:' /tmp/m3-whoami.err | head -1)"
fi

# ---------------------------------------------------------------------------
say "Unity Catalog"
# The template's pipeline resource lives in a catalog. Participants need a
# catalog they can create schemas in; the CLI proposes the metastore's default.
if databricks catalogs list -o json >/tmp/m3-catalogs.json 2>/tmp/m3-catalogs.err; then
    # `catalogs list -o json` prints a bare array, not an object with a
    # "catalogs" key, so index it with .[] rather than .catalogs[].
    n="$(jq 'length' /tmp/m3-catalogs.json)"
    ok "${n} catalogs visible:"
    jq -r '.[] | "        " + .name' /tmp/m3-catalogs.json
    printf '  note  choose one of these when bundle init asks for a default catalog\n'
else
    fail "catalogs list failed: $(grep -v '^Warn:' /tmp/m3-catalogs.err | head -1)"
fi

# ---------------------------------------------------------------------------
say "Result"
if [ "$FAILED" -eq 0 ]; then
    printf '  Every check passed. You are ready for Lab A.\n\n'
else
    printf '  At least one check failed. Fix it before the module starts;\n'
    printf '  each failure above corresponds to a lab step that cannot proceed.\n\n'
    exit 1
fi
