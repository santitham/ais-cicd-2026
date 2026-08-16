# ============================================================================
# Module 2 — full job lifecycle from the terminal
# ============================================================================

# ---- 0. settings -----------------------------------------------------------
PROFILE=dev
WS="/Users/santitham.pro@kmutt.ac.th"          # no trailing slash
CLUSTER_NAME="Training_Cluster"

# ---- 1. verify the profile -------------------------------------------------
databricks current-user me --profile $PROFILE | jq -r .userName

# ---- 2. the notebook to run ------------------------------------------------
cat > hello_world.py <<'EOF'
import sys, datetime

msg = (f"Hello, world! at {datetime.datetime.now(datetime.timezone.utc).isoformat()} "
       f"| Python {sys.version.split()[0]}")
print(msg)
dbutils.notebook.exit(msg)      # required, or the API returns nothing
EOF

# ---- 3. upload it ----------------------------------------------------------
databricks workspace import \
  --file hello_world.py \
  --format SOURCE --language PYTHON \
  --overwrite \
  --profile $PROFILE \
  "$WS/hello_world"

databricks workspace list "$WS" --profile $PROFILE | grep hello_world

# ---- 4. find the cluster ---------------------------------------------------
CLUSTER_ID=$(databricks clusters list --profile $PROFILE -o json \
  | jq -r ".[] | select(.cluster_name==\"$CLUSTER_NAME\") | .cluster_id")
echo "cluster: $CLUSTER_ID"

# ---- 5. create the job -----------------------------------------------------
JOB_ID=$(databricks jobs create --profile $PROFILE -o json --json "{
  \"name\": \"hello-world-santitham\",
  \"tasks\": [{
    \"task_key\": \"say-hello\",
    \"existing_cluster_id\": \"$CLUSTER_ID\",
    \"notebook_task\": { \"notebook_path\": \"$WS/hello_world\" }
  }]
}" | jq -r .job_id)
echo "job: $JOB_ID"

# ---- 6. run it, without blocking ------------------------------------------
RUN_ID=$(databricks jobs run-now "$JOB_ID" --no-wait --profile $PROFILE -o json \
         | jq -r .run_id)
echo "run: $RUN_ID"

# ---- 7. poll ---------------------------------------------------------------
databricks jobs get-run "$RUN_ID" --profile $PROFILE -o json | jq .state

while true; do
  STATE=$(databricks jobs get-run "$RUN_ID" --profile $PROFILE -o json \
          | jq -r .state.life_cycle_state)
  echo "$STATE"
  [ "$STATE" = "TERMINATED" ] && break
  sleep 10
done

# ---- 8. the result — this line is Module 8's smoke test --------------------
databricks jobs get-run "$RUN_ID" --profile $PROFILE -o json \
  | jq -r '.state.result_state'

# ---- 9. the output ---------------------------------------------------------
TASK_RUN_ID=$(databricks jobs get-run "$RUN_ID" --profile $PROFILE -o json \
              | jq -r '.tasks[0].run_id')

databricks jobs get-run-output "$TASK_RUN_ID" --profile $PROFILE -o json \
  | jq -r '.notebook_output.result'

# ---- 10. where to look when it fails --------------------------------------
databricks jobs get-run "$RUN_ID" --profile $PROFILE -o json | jq -r '.run_page_url'

# ---- 11. how long it waited vs worked -------------------------------------
databricks jobs get-run "$RUN_ID" --profile $PROFILE -o json \
  | jq -r '"setup: \(.setup_duration/1000)s   execution: \(.execution_duration/1000)s"'
