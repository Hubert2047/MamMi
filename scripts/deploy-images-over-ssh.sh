#!/usr/bin/env bash
set -euo pipefail

# Edit these defaults for the usual production machine. CLI options override them.
REMOTE_HOST="100.78.69.25"
REMOTE_USER="hp"
SSH_PORT="22"
TAG="${MAMMI_IMAGE_TAG:-local}"
PREFIX="${MAMMI_IMAGE_PREFIX:-mammi}"
ENV_FILE=".env"
SERVICES="all"
SKIP_BUILD=0

usage() {
  cat <<'EOF'
Usage: deploy-images-over-ssh.sh [options]

Options:
  --host HOST             Production host IP or hostname
  --user USER             SSH user
  --port PORT             SSH port (default: 22)
  --tag TAG               Image tag (default: local)
  --prefix PREFIX         Image prefix (default: mammi)
  --env-file FILE         Build env file relative to project root (default: .env)
  --services LIST         all, or comma-separated: backend,frontend,order-web,backup
  --skip-build            Transfer existing local images without building
  -h, --help              Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host) REMOTE_HOST="$2"; shift 2 ;;
    --user) REMOTE_USER="$2"; shift 2 ;;
    --port) SSH_PORT="$2"; shift 2 ;;
    --tag) TAG="$2"; shift 2 ;;
    --prefix) PREFIX="$2"; shift 2 ;;
    --env-file) ENV_FILE="$2"; shift 2 ;;
    --services) SERVICES="$2"; shift 2 ;;
    --skip-build) SKIP_BUILD=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_PATH="$PROJECT_ROOT/$ENV_FILE"

dotenv_value() {
  local name="$1"
  local value="${!name-}"
  if [[ -n "$value" ]]; then
    printf '%s' "$value"
    return
  fi
  [[ -f "$ENV_PATH" ]] || return 0
  awk -v key="$name" 'index($0, key "=") == 1 { value=substr($0, length(key)+2); gsub(/^"|"$/, "", value); print value; exit }' "$ENV_PATH"
}

require_dotenv_value() {
  local name="$1"
  local value
  value="$(dotenv_value "$name")"
  [[ -n "$value" ]] || { echo "Set $name in $ENV_FILE or the current environment." >&2; exit 1; }
  printf '%s' "$value"
}

if [[ "$SERVICES" == "all" ]]; then
  SELECTED_SERVICES=(backend frontend order-web backup)
else
  IFS=',' read -r -a SELECTED_SERVICES <<< "$SERVICES"
fi

for service in "${SELECTED_SERVICES[@]}"; do
  case "$service" in
    backend|frontend|order-web|backup) ;;
    *) echo "Invalid service: $service" >&2; exit 2 ;;
  esac
done

if [[ "$SKIP_BUILD" -eq 0 ]]; then
  if [[ " ${SELECTED_SERVICES[*]} " == *" backend "* ]]; then
    docker build --tag "$PREFIX/backend:$TAG" "$PROJECT_ROOT/be"
  fi
  if [[ " ${SELECTED_SERVICES[*]} " == *" frontend "* ]]; then
    PRIVATE_HOST="$(require_dotenv_value MAMMI_PRIVATE_HOST)"
    ORDER_WEB_URL="$(require_dotenv_value NEXT_PUBLIC_ORDER_WEB_URL)"
    docker build \
      --build-arg "NEXT_PUBLIC_API_BASE_URL=http://${PRIVATE_HOST}:8080" \
      --build-arg "NEXT_PUBLIC_ORDER_WEB_URL=$ORDER_WEB_URL" \
      --tag "$PREFIX/frontend:$TAG" \
      "$PROJECT_ROOT/fe"
  fi
  if [[ " ${SELECTED_SERVICES[*]} " == *" order-web "* ]]; then
    TURNSTILE_SITE_KEY="$(require_dotenv_value NEXT_PUBLIC_TURNSTILE_SITE_KEY)"
    docker build \
      --build-arg "NEXT_PUBLIC_TURNSTILE_SITE_KEY=$TURNSTILE_SITE_KEY" \
      --tag "$PREFIX/order-web:$TAG" \
      "$PROJECT_ROOT/order-web"
  fi
  if [[ " ${SELECTED_SERVICES[*]} " == *" backup "* ]]; then
    docker build --tag "$PREFIX/backup:$TAG" "$PROJECT_ROOT/backup"
  fi
fi

IMAGES=()
for service in "${SELECTED_SERVICES[@]}"; do
  image="$PREFIX/$service:$TAG"
  docker image inspect "$image" >/dev/null
  IMAGES+=("$image")
done

REMOTE="$REMOTE_USER@$REMOTE_HOST"
echo "Streaming ${#IMAGES[@]} image(s) (${SELECTED_SERVICES[*]}) to $REMOTE ..."
docker save "${IMAGES[@]}" | ssh -p "$SSH_PORT" "$REMOTE" docker load
echo "Images loaded on $REMOTE."
