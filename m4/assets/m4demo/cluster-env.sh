#!/usr/bin/env bash
# OPTIONAL. databricks.yml already pins cluster_id to Training_Cluster, so the
# bundle runs without this script. Use it to point the bundle at a DIFFERENT
# cluster without editing the file, or to re-read the id after Training_Cluster
# has been recreated.
#
# SOURCE it, do not run it — a subshell's exports do not survive:
#
#   source ./cluster-env.sh                    # re-reads Training_Cluster
#   source ./cluster-env.sh My_Other_Cluster
#
# It exports BUNDLE_VAR_cluster_id, which is source 4 of the five on slide S48 and
# therefore outranks the default in databricks.yml. Print what is in effect with:
#   databricks bundle validate -o json | jq -r .variables.cluster_id.value

_m4_cluster_name="${1:-Training_Cluster}"

if ! command -v jq >/dev/null 2>&1; then
  echo "cluster-env.sh: jq is required" >&2
  return 1 2>/dev/null || exit 1
fi

# clusters list -o json prints a BARE ARRAY, so it is indexed with .[] and not
# .clusters[]. This catches people every time.
_m4_json=$(databricks clusters list -o json 2>/dev/null) || {
  echo "cluster-env.sh: databricks clusters list failed — check your profile" >&2
  return 1 2>/dev/null || exit 1
}

_m4_id=$(printf '%s' "$_m4_json" \
  | jq -r --arg n "$_m4_cluster_name" '.[] | select(.cluster_name==$n) | .cluster_id' \
  | head -1)

if [ -z "${_m4_id:-}" ] || [ "$_m4_id" = null ]; then
  echo "cluster-env.sh: no cluster named '$_m4_cluster_name'. Available:" >&2
  printf '%s' "$_m4_json" | jq -r '.[] | "  \(.cluster_id)  \(.cluster_name)  [\(.state // "?")]"' >&2
  unset _m4_cluster_name _m4_json _m4_id
  return 1 2>/dev/null || exit 1
fi

export BUNDLE_VAR_cluster_id="$_m4_id"
_m4_state=$(printf '%s' "$_m4_json" \
  | jq -r --arg n "$_m4_cluster_name" '.[] | select(.cluster_name==$n) | .state' | head -1)

echo "BUNDLE_VAR_cluster_id=$BUNDLE_VAR_cluster_id   ($_m4_cluster_name, $_m4_state)"
if [ "$_m4_state" != RUNNING ]; then
  echo "note: the cluster is $_m4_state. The first task will start it, which takes a few minutes."
fi
unset _m4_cluster_name _m4_json _m4_id _m4_state
