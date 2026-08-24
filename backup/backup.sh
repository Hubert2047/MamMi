#!/bin/sh
set -eu

required_vars='MONGO_HOST MONGO_DATABASE MONGO_USERNAME MONGO_PASSWORD RESTIC_REPOSITORY RESTIC_PASSWORD AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY'
for var_name in $required_vars; do
    eval "var_value=\${$var_name:-}"
    if [ -z "$var_value" ]; then
        echo "$var_name must be configured" >&2
        exit 1
    fi
done

umask 077
backup_dir=$(mktemp -d)
dump_file="$backup_dir/mammi-$(date -u +%Y%m%dT%H%M%SZ).archive.gz"
cleanup() {
    rm -rf "$backup_dir"
}
trap cleanup EXIT INT TERM

mongodump \
    --host "$MONGO_HOST" \
    --port 27017 \
    --username "$MONGO_USERNAME" \
    --password "$MONGO_PASSWORD" \
    --authenticationDatabase admin \
    --db "$MONGO_DATABASE" \
    --archive="$dump_file" \
    --gzip

if ! restic cat config >/dev/null 2>&1; then
    restic init
fi

restic backup --tag mammi --tag mongodb "$dump_file"
restic forget --tag mammi --keep-daily "${BACKUP_KEEP_DAILY:-7}" --keep-weekly "${BACKUP_KEEP_WEEKLY:-4}" --keep-monthly "${BACKUP_KEEP_MONTHLY:-6}" --prune
