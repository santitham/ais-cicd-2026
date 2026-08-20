#!/usr/bin/env bash
# Module 4 pre-flight. Run this before Challenge 1.
#
# Module 4 uses the default-minimal template, which declares no artifacts, so uv is
# NOT required this afternoon even though Module 3 needed it. Seven checks, each
# corresponding to a lab step that cannot proceed without it.
#
# Check 6 is the one that matters most and is easiest to miss: a credential that
# cannot CREATE clusters deploys the whole module successfully and then fails at the
# first run. See assets/m4demo/SHARED-CLUSTER.md.
set -u
PASS=0; FAIL=0
ok()   { printf '  [ ok ] %s\n' "$1"; PASS=$((PASS+1)); }
bad()  { printf '  [FAIL] %s\n' "$1"; FAIL=$((FAIL+1)); }
note() { printf '         %s\n' "$1"; }

echo "=== Module 4 pre-flight ==="

# 1 -- CLI version
if command -v databricks >/dev/null 2>&1; then
  V=$(databricks --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
  MAJ=${V%%.*}; REST=${V#*.}; MIN=${REST%%.*}
  if [ "${MAJ:-0}" -gt 1 ] || { [ "${MAJ:-0}" -eq 1 ] && [ "${MIN:-0}" -ge 3 ]; }; then
    ok "Databricks CLI v$V"
  else
    bad "Databricks CLI is v$V; this course needs v1.3.0 or later"
    note "bundle plan does not exist before v1.2, and earlier versions write Terraform state"
  fi
else
  bad "databricks is not on PATH"
fi

# 2 -- authentication
if databricks current-user me -o json >/tmp/m4_me.json 2>/dev/null; then
  ok "authenticated as $(python3 -c 'import json;print(json.load(open("/tmp/m4_me.json"))["userName"])' 2>/dev/null)"
else
  bad "databricks current-user me failed"
  note "re-run the Module 2 profile setup; every command this afternoon needs it"
fi

# 3 -- a writable Unity Catalog catalog
if databricks catalogs list -o json >/tmp/m4_cat.json 2>/dev/null; then
  N=$(python3 -c 'import json;print(len(json.load(open("/tmp/m4_cat.json"))))' 2>/dev/null || echo 0)
  if [ "${N:-0}" -gt 0 ]; then
    ok "$N catalog(s) visible: $(python3 -c 'import json;print(", ".join(c["name"] for c in json.load(open("/tmp/m4_cat.json"))[:5]))' 2>/dev/null)"
  else
    bad "no catalogs visible to this credential"
    note "bundle init asks for one, and every task writes into it"
  fi
else
  bad "databricks catalogs list failed"
fi

# 4 -- jq, used to read resolved configuration in every challenge
if command -v jq >/dev/null 2>&1; then
  ok "jq $(jq --version 2>/dev/null)"
else
  bad "jq is not installed"
  note "sudo apt-get install -y jq   # used in Challenges 1, 3, 4, 5 and 6"
fi

# 5 -- the runtime and node type this course's cluster specs name
if [ -f /tmp/m4_me.json ]; then
  if databricks clusters spark-versions -o json 2>/dev/null | grep -q '16\.4\.x-scala2\.12'; then
    ok "runtime 16.4.x-scala2.12 is offered by this workspace"
  else
    bad "16.4.x-scala2.12 is not in this workspace's runtime list"
    note "run: databricks clusters spark-versions | grep LTS   and use a listed LTS key instead"
  fi
  if databricks clusters list-node-types -o json 2>/dev/null | grep -q 'Standard_D3_v2'; then
    ok "node type Standard_D3_v2 is available"
  else
    bad "Standard_D3_v2 is not available in this workspace's region"
    note "run: databricks clusters list-node-types -o json | jq -r '.node_types[].node_type_id' | grep Standard_D"
    note "and substitute a listed type everywhere the slides say Standard_D3_v2"
  fi
fi

# 6 -- compute: can this credential CREATE clusters, or must it borrow one?
#      This is the check that decides whether the module runs as written.
#      A credential without cluster-create fails at RUN time, not at deploy, with
#      PERMISSION_DENIED while preparing the cluster — after everything else has
#      already succeeded, which makes it an expensive thing to discover in class.
CAN_CREATE=unknown
if [ -f /tmp/m4_me.json ]; then
  ENT=$(python3 - <<'PYCHK' 2>/dev/null
import json
d = json.load(open("/tmp/m4_me.json"))
ents = [e.get("value") for e in (d.get("entitlements") or [])]
print("yes" if "allow-cluster-create" in ents else ("no" if ents else "unknown"))
PYCHK
)
  if [ "${ENT:-unknown}" = yes ]; then
    CAN_CREATE=yes
    ok "this credential may create clusters (allow-cluster-create)"
  elif [ "${ENT:-unknown}" = unknown ]; then
    CAN_CREATE=unknown
    ok "cluster-create entitlement not reported by this workspace's SCIM response"
    note "cannot be determined without trying. Test ONCE before class:"
    note "  cd assets/m4demo && databricks bundle deploy -t dev && databricks bundle run ingest -t dev"
    note "if the run fails with PERMISSION_DENIED, use assets/m4demo/SHARED-CLUSTER.md"
  else
    if databricks cluster-policies list -o json 2>/dev/null | grep -q policy_id; then
      CAN_CREATE=policy
      ok "no unrestricted cluster-create, but cluster policies are visible"
      note "job clusters may work within a policy. Test with a real run before class:"
      note "  databricks bundle deploy -t dev && databricks bundle run ingest -t dev"
    else
      CAN_CREATE=no
      bad "this credential may NOT create clusters"
      note "every job_cluster in the slides will fail at RUN time with:"
      note "  PERMISSION_DENIED: You are not authorized to create clusters"
      note "Use the shared-cluster variant: assets/m4demo/SHARED-CLUSTER.md"
    fi
  fi
fi

# 7 -- an existing cluster to borrow, needed by the shared-cluster variant
if databricks clusters list -o json > /tmp/m4_cl.json 2>/dev/null; then
  NCL=$(python3 -c 'import json;print(len(json.load(open("/tmp/m4_cl.json"))))' 2>/dev/null || echo 0)
  if [ "${NCL:-0}" -gt 0 ]; then
    ok "$NCL existing cluster(s) available to borrow"
    python3 - <<'PYCL' 2>/dev/null
import json
for c in json.load(open("/tmp/m4_cl.json"))[:6]:
    print("           %-24s %s" % (c.get("cluster_id",""), c.get("cluster_name","")))
PYCL
    if [ "$CAN_CREATE" = no ]; then
      note "export the id you will use, then no command needs a flag:"
      note "  export BUNDLE_VAR_cluster_id=\$(databricks clusters list -o json \\"
      note "    | jq -r '.[] | select(.cluster_name==\"Training_Cluster\") | .cluster_id')"
    fi
  elif [ "$CAN_CREATE" = no ]; then
    bad "no cluster-create permission AND no existing cluster to borrow"
    note "the module cannot run any task on this workspace. Ask the administrator for"
    note "either a cluster policy granting CAN_USE, or CAN_ATTACH_TO on a shared cluster."
  fi
fi

echo
echo "=== Result ==="
if [ "$FAIL" -eq 0 ]; then
  echo "  Every check passed. You are ready for Challenge 1."
else
  echo "  $FAIL check(s) failed and $PASS passed. Fix the failures before Challenge 1;"
  echo "  the first two are blocking and the rest cost you lab time."
fi
exit 0
