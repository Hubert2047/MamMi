FROM mongo:8.0

RUN apt-get update \
    && apt-get install --no-install-recommends --yes restic ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY backup.sh /usr/local/bin/mammi-backup
RUN chmod 0755 /usr/local/bin/mammi-backup

ENTRYPOINT ["/usr/local/bin/mammi-backup"]
