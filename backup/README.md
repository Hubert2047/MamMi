# MongoDB cloud backup

The backup worker starts with Docker Compose. After every confirmed closing, the backend creates an idempotent `BackupJob`; the worker creates a compressed `mongodump`, encrypts it with Restic, and stores it in an S3-compatible Cloudflare R2 bucket.

## Setup

1. Create a private R2 bucket and an API token restricted to that bucket.
2. Copy `.env.docker.example` to `.env`, set `BACKUP_ENABLED=true`, and set `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `RESTIC_REPOSITORY`, and a unique `RESTIC_PASSWORD`.
3. Start the stack:

   ```sh
   docker compose up -d
   ```

After the next confirmed closing, the worker claims its backup job. If the machine is off, the pending job remains in MongoDB and is processed when the stack starts again. Restic initializes the repository on its first successful run. Keep `RESTIC_PASSWORD` in a password manager: without it, the encrypted backup cannot be restored.

When `BACKUP_ENABLED=false` (the default), the worker remains idle and Docker Compose can run normally without cloud credentials.

## Retry behavior

The worker checks for jobs every 60 seconds. Failed uploads retry after 5 minutes, up to 5 attempts:

```env
BACKUP_POLL_INTERVAL_SECONDS=60
BACKUP_RETRY_DELAY_SECONDS=300
BACKUP_MAX_ATTEMPTS=5
```

The default retention policy is 7 daily, 4 weekly, and 6 monthly backups. Override `BACKUP_KEEP_DAILY`, `BACKUP_KEEP_WEEKLY`, or `BACKUP_KEEP_MONTHLY` in `.env` if needed. Backup failures never fail or roll back a closing.

## Restore drill

At least monthly, restore the newest archive into a separate test MongoDB instance. MongoDB supports restoring the generated archive with `mongorestore --gzip --archive <file>`.
