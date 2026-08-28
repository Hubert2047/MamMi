# Transfer production images over SSH

Run the Bash script from Ubuntu, WSL2, or Git Bash on the development computer. It builds the selected MamMi images and streams them directly into Docker on the production computer. No source code, `.env`, or intermediate `.tar` file is transferred.

The production computer needs:

- Docker Desktop with the Docker CLI available to the SSH account.
- An OpenSSH server accepting the account used below.
- The SSH account allowed to run `docker load`.

Build and transfer all images:

Edit the defaults at the top of `scripts/deploy-images-over-ssh.sh` when you want to keep a fixed target:

```powershell
REMOTE_HOST="192.168.16.50"
REMOTE_USER="mammi-deploy"
SSH_PORT="22"
```

Then run on Ubuntu, WSL2, or Git Bash:

```powershell
./scripts/deploy-images-over-ssh.sh --tag 1.0
```

The same values can be overridden for one run:

```powershell
./scripts/deploy-images-over-ssh.sh --host 192.168.16.50 --user mammi-deploy --port 2222 --tag 1.0
```

By default the script sends all four images:

```text
mammi/backend:1.0
mammi/frontend:1.0
mammi/order-web:1.0
mammi/backup:1.0
```

After loading, copy only the Compose file to the production computer and run Compose there with the production env file that already exists on that machine:

```powershell
docker compose --env-file C:\ProgramData\MamMi\secrets\.env.production `
  -f C:\ProgramData\MamMi\docker-compose.production.yml up -d
```

If the images were already built locally, skip rebuilding:

```powershell
./scripts/deploy-images-over-ssh.sh \
  --host 192.168.16.50 \
  --user mammi-deploy \
  --tag 1.0 \
  --skip-build
```

Build and transfer only selected services:

```powershell
./scripts/deploy-images-over-ssh.sh --services backend,frontend --tag 1.1
```

Valid values are `all`, `backend`, `frontend`, `order-web`, and `backup`. When a service is selected, only its required build-time values are read from `.env`.

The `.ps1` script remains available for native PowerShell, but `.sh` is the cross-platform entry point. The script does not transfer `.env`; keep secrets on the production computer and update them separately.
