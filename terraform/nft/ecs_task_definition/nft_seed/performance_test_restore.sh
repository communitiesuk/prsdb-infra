set -eu
set -o pipefail

stage=initialization
workspace=
failure_logged=false

log() {
  printf '%s %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$1"
}

fail() {
  failure_logged=true
  log "PRECHECK FAILED: $stage"
  exit 1
}

cleanup() {
  status=$?
  trap - EXIT
  if [ "$status" -ne 0 ] && [ "$failure_logged" != true ]; then
    log "PRECHECK FAILED: $stage"
  fi
  if [ -n "$workspace" ] && [ -d "$workspace" ]; then
    if ! rm -rf -- "$workspace"; then
      log "Temporary archive cleanup failed"
      status=1
    fi
  fi
  exit "$status"
}

trap cleanup EXIT
trap 'exit 1' HUP INT TERM

stage=tools
log "Installing restore tools"
timeout 180 apk add --no-cache aws-cli jq >/tmp/nft-restore-tool-install.log 2>&1 || fail
aws --version 2>/dev/null
psql --version
pg_restore --version
test "$(pg_restore --version | awk '{print $3}' | cut -d. -f1)" = 16 || fail

stage=identity
test "$AWS_REGION" = eu-west-2 || fail
test "$EXPECTED_AWS_ACCOUNT" = 448120078528 || fail
test "$NFT_DUMP_BUCKET" = prsdb-seed-data-nft || fail
test "$NFT_DUMP_KEY" = seed-data.dump || fail
test "$NFT_DUMP_VERSION" != "" || fail
test "$NFT_RESTORE_TASK_FAMILY" != "" || fail
test "${ECS_CONTAINER_METADATA_URI_V4:-}" != "" || fail
case "$ECS_CONTAINER_METADATA_URI_V4" in
  http://169.254.170.2/v4/*) ;;
  *) fail ;;
esac
aws sts get-caller-identity --query Account --output text >/tmp/nft-restore-account 2>/tmp/nft-restore-aws-error || fail
test "$(cat /tmp/nft-restore-account)" = "$EXPECTED_AWS_ACCOUNT" || fail
wget -q -T 10 -O /tmp/nft-restore-task.json "$ECS_CONTAINER_METADATA_URI_V4/task" 2>/dev/null || fail
jq -e --arg family "$NFT_RESTORE_TASK_FAMILY" --arg account "$EXPECTED_AWS_ACCOUNT" --arg cluster "$NFT_APP_CLUSTER" '
  .Cluster == ("arn:aws:ecs:eu-west-2:" + $account + ":cluster/" + $cluster) and
  (.TaskARN | startswith("arn:aws:ecs:eu-west-2:" + $account + ":task/" + $cluster + "/")) and
  .Family == $family and
  .LaunchType == "FARGATE"
' /tmp/nft-restore-task.json >/dev/null || fail
log "NFT account and Fargate task identity verified"

stage=dump-metadata
workspace="$(mktemp -d /tmp/nft-restore.XXXXXX)"
archive="$workspace/seed-data.dump"
aws s3api head-object --bucket "$NFT_DUMP_BUCKET" --key "$NFT_DUMP_KEY" \
  --version-id "$NFT_DUMP_VERSION" --expected-bucket-owner "$EXPECTED_AWS_ACCOUNT" \
  >"$workspace/metadata.json" 2>/tmp/nft-restore-aws-error || fail
jq -e --arg version "$NFT_DUMP_VERSION" --argjson size "$NFT_DUMP_BYTES" \
  '.VersionId == $version and .ContentLength == $size' "$workspace/metadata.json" >/dev/null || fail
available_kb="$(df -Pk "$workspace" | awk 'END {print $4}')"
test "$available_kb" -ge 2097152 || fail
log "Pinned dump version and size verified; at least 2 GiB free disk"

stage=download
started="$(date +%s)"
log "Dump download started"
aws s3api get-object --bucket "$NFT_DUMP_BUCKET" --key "$NFT_DUMP_KEY" \
  --version-id "$NFT_DUMP_VERSION" --expected-bucket-owner "$EXPECTED_AWS_ACCOUNT" "$archive" \
  >"$workspace/download.json" 2>/tmp/nft-restore-aws-error || fail
download_seconds=$(( $(date +%s) - started ))
test "$(stat -c %s "$archive")" = "$NFT_DUMP_BYTES" || fail
test "$(sha256sum "$archive" | awk '{print $1}')" = "$NFT_DUMP_SHA256" || fail
pg_restore --list "$archive" >/dev/null 2>/tmp/nft-restore-postgres-error || fail
log "Dump download/checksum/archive verified: $NFT_DUMP_BYTES bytes; download ${download_seconds}s"

stage=database-readonly
test "$PGDATABASE" = prsdb || fail
test "$PGPORT" = 5432 || fail
test "$PGHOST" = "$EXPECTED_PGHOST" || fail
case "$PGHOST" in
  *.eu-west-2.rds.amazonaws.com) ;;
  *) fail ;;
esac
test "$PGSSLMODE" = require || fail
test "${PGPASSWORD:-}" != "" || fail
log "Private PostgreSQL TLS read-only connection check started"
result="$(psql --no-psqlrc --set ON_ERROR_STOP=1 --tuples-only --no-align --quiet --command "
BEGIN READ ONLY;
SELECT
  current_database() = 'prsdb'
  AND current_setting('server_version_num')::integer / 10000 = 16
  AND inet_server_addr() << inet '10.1.0.0/16'
  AND current_setting('transaction_read_only') = 'on'
  AND EXISTS (SELECT 1 FROM pg_stat_ssl WHERE pid = pg_backend_pid() AND ssl)
  AND EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'public');
ROLLBACK;
" 2>/tmp/nft-restore-postgres-error)" || fail
test "$result" = t || fail
log "PostgreSQL16 private TLS connection and explicit read-only transaction verified"
log "PRECHECK PASSED; no schema or application data changes performed"

stage=writer-guard-services
log "Rechecking stopped app and scheduled writers before destructive restore"
aws ecs describe-services --cluster "$NFT_APP_CLUSTER" \
  --services "$NFT_APP_SERVICE" "$NFT_SIMULATOR_SERVICE" "$NFT_ASYNC_WORKER_SERVICE" \
  >"$workspace/services.json" 2>/tmp/nft-restore-aws-error || fail
jq -e --arg app "$NFT_APP_SERVICE" --arg simulator "$NFT_SIMULATOR_SERVICE" --arg worker "$NFT_ASYNC_WORKER_SERVICE" '
  (.failures | length == 0) and (.services | length == 3) and
  all(.services[]; .desiredCount == 0 and .runningCount == 0 and .pendingCount == 0) and
  ([.services[].serviceName] | index($app) != null and index($simulator) != null and index($worker) != null)
' "$workspace/services.json" >/dev/null || fail
log "App and simulator zero-writer service checks passed; async worker also stopped"

stage=writer-guard-scheduled-tasks
aws ecs list-tasks --cluster "$NFT_SCHEDULED_CLUSTER" \
  >"$workspace/scheduled-tasks.json" 2>/tmp/nft-restore-aws-error || fail
jq -e '.taskArns | length == 0' "$workspace/scheduled-tasks.json" >/dev/null || fail
log "No scheduled writer tasks found"

stage=writer-guard-database-sessions
sessions="$(psql --no-psqlrc --set ON_ERROR_STOP=1 --tuples-only --no-align --quiet \
  --command "SELECT count(*) FROM pg_stat_activity WHERE datname=current_database() AND pid<>pg_backend_pid() AND backend_type='client backend' AND usename<>'rdsadmin';" \
  2>/tmp/nft-restore-postgres-error)" || fail
case "$sessions" in
  ''|*[!0-9]*) fail ;;
esac
log "Other PostgreSQL client sessions: $sessions"
test "$sessions" = 0 || fail

stage=restore
export PGOPTIONS='-c default_transaction_read_only=off -c lock_timeout=15000'
started="$(date +%s)"
log "DESTRUCTIVE RESTORE STARTED; pinned archive; four workers"
psql --no-psqlrc --set ON_ERROR_STOP=1 --quiet \
  --command 'DROP SCHEMA public CASCADE; CREATE SCHEMA public AUTHORIZATION CURRENT_USER;' \
  >/tmp/nft-restore-schema-output 2>/tmp/nft-restore-postgres-error || fail
pg_restore --jobs=4 --exit-on-error --no-owner --no-acl --dbname=prsdb "$archive" \
  >/tmp/nft-restore-output 2>/tmp/nft-restore-postgres-error &
restore_pid=$!
while kill -0 "$restore_pid" 2>/dev/null; do
  sleep 30
  log "Restore heartbeat: $(( $(date +%s) - started ))s elapsed"
done
wait "$restore_pid" || fail
log "RESTORE COMPLETED: $(( $(date +%s) - started ))s"

stage=restored-schema-check
export PGOPTIONS='-c default_transaction_read_only=on -c statement_timeout=60000'
schema_ok="$(psql --no-psqlrc --set ON_ERROR_STOP=1 --tuples-only --no-align --quiet \
  --command "SELECT
    (SELECT count(*) FROM pg_constraint WHERE conrelid='public.address'::regclass AND contype IN ('p','u','f')) >= 3
    AND (SELECT count(*) FROM pg_constraint WHERE conrelid='public.local_council'::regclass AND contype IN ('p','u')) >= 2
    AND to_regclass('public.address_postcode_idx') IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM flyway_schema_history WHERE NOT success);" \
  2>/tmp/nft-restore-postgres-error)" || fail
test "$schema_ok" = t || fail
log "RESTORE TASK PASSED; restored constraints/index and migration history success verified; exact-SHA migration/count checks still required"
