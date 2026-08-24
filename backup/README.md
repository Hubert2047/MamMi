# MongoDB cloud backup

The `backup` Compose profile creates a compressed `mongodump`, encrypts it with Restic, and stores it in an S3-compatible Cloudflare R2 bucket.

## Setup

1. Create a private R2 bucket and an API token restricted to that bucket.
2. Copy `.env.docker.example` to `.env` and set `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `RESTIC_REPOSITORY`, and a unique `RESTIC_PASSWORD`.
3. Run the first backup manually:

   ```sh
   docker compose --profile backup run --rm backup
   ```

Restic initializes the repository on its first successful run. Keep `RESTIC_PASSWORD` in a password manager: without it, the encrypted backup cannot be restored.

## Scheduling

Run it once per night from the Docker host, for example at 02:30:

```cron
30 2 * * * cd /path/to/MamMi && /usr/bin/docker compose --profile backup run --rm backup >> /var/log/mammi-backup.log 2>&1
```

The default retention policy is 7 daily, 4 weekly, and 6 monthly backups. Override `BACKUP_KEEP_DAILY`, `BACKUP_KEEP_WEEKLY`, or `BACKUP_KEEP_MONTHLY` in `.env` if needed.

## Restore drill

At least monthly, restore the newest archive into a separate test MongoDB instance. MongoDB supports restoring the generated archive with `mongorestore --gzip --archive <file>`.
