FROM mongo:8.0

RUN apt-get update \
    && apt-get install --no-install-recommends --yes restic ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY backup.sh /usr/local/bin/mammi-backup
COPY worker.sh /usr/local/bin/mammi-backup-worker
RUN chmod 0755 /usr/local/bin/mammi-backup /usr/local/bin/mammi-backup-worker

ENTRYPOINT ["/usr/local/bin/mammi-backup-worker"]
