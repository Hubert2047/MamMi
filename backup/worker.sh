#!/bin/sh
set -u

if [ "${BACKUP_ENABLED:-false}" != 'true' ]; then
    echo 'Cloud backup is disabled. Set BACKUP_ENABLED=true after configuring R2 and Restic credentials.'
    while true; do sleep 3600; done
fi

required_vars='MONGO_HOST MONGO_DATABASE MONGO_USERNAME MONGO_PASSWORD RESTIC_REPOSITORY RESTIC_PASSWORD AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY'
for var_name in $required_vars; do
    eval "var_value=\${$var_name:-}"
    if [ -z "$var_value" ]; then
        echo "$var_name must be configured" >&2
        exit 1
    fi
done

poll_interval="${BACKUP_POLL_INTERVAL_SECONDS:-60}"
retry_delay="${BACKUP_RETRY_DELAY_SECONDS:-300}"
max_attempts="${BACKUP_MAX_ATTEMPTS:-5}"
lease_ms=$((2 * 60 * 60 * 1000))

mongo_eval() {
    mongosh --quiet \
        --host "$MONGO_HOST" \
        --port 27017 \
        --username "$MONGO_USERNAME" \
        --password "$MONGO_PASSWORD" \
        --authenticationDatabase admin \
        "$MONGO_DATABASE" \
        --eval "$1"
}

claim_job() {
    mongo_eval "
const now = new Date();
const job = db.backupjobs.findOneAndUpdate(
  { \$or: [
    { status: 'pending' },
    { status: 'failed', attempts: { \$lt: $max_attempts }, nextAttemptAt: { \$lte: now } },
    { status: 'running', leaseExpiresAt: { \$lte: now } }
  ] },
  { \$set: { status: 'running', startedAt: now, leaseExpiresAt: new Date(now.getTime() + $lease_ms) }, \$inc: { attempts: 1 } },
  { sort: { createdAt: 1 }, returnDocument: 'after' },
);
if (job) print(job._id.toString());
" | tail -n 1
}

mark_succeeded() {
    mongo_eval "db.backupjobs.updateOne({ _id: ObjectId('$1'), status: 'running' }, { \$set: { status: 'succeeded', completedAt: new Date() }, \$unset: { leaseExpiresAt: 1, lastError: 1, nextAttemptAt: 1 } });" >/dev/null
}

mark_failed() {
    mongo_eval "db.backupjobs.updateOne({ _id: ObjectId('$1'), status: 'running' }, { \$set: { status: 'failed', lastError: 'Backup command failed; inspect backup container logs', nextAttemptAt: new Date(Date.now() + ($retry_delay * 1000)) }, \$unset: { leaseExpiresAt: 1 } });" >/dev/null
}

while true; do
    job_id=$(claim_job || true)
    if [ -z "$job_id" ]; then
        sleep "$poll_interval"
        continue
    fi

    echo "Processing backup job $job_id"
    if /usr/local/bin/mammi-backup; then
        mark_succeeded "$job_id"
        echo "Backup job $job_id completed"
    else
        mark_failed "$job_id"
        echo "Backup job $job_id failed; it will retry" >&2
    fi
done
