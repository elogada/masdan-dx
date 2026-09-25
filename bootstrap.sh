#!/usr/bin/env bash
set -Eeuo pipefail

# Open WebUI bootstrapper:
# 1. Starts Open WebUI
# 2. Waits for the local API
# 3. Signs in using WEBUI_ADMIN_EMAIL / WEBUI_ADMIN_PASSWORD
# 4. Creates sendemail_tool_env.py as a Workspace Tool if it does not exist
#
# Assumes this script and sendemail_tool_env.py are copied into /app/bootstrap/
# by the Dockerfile (or adjust BOOTSTRAP_DIR below).

BASE_URL="${OPENWEBUI_BASE_URL:-http://127.0.0.1:${PORT:-8080}}"
BOOTSTRAP_DIR="${BOOTSTRAP_DIR:-/app/bootstrap}"
TOOL_FILE="${TOOL_FILE:-${BOOTSTRAP_DIR}/sendemail_tool_env.py}"
TOOL_ID="${TOOL_ID:-sendemail_tool_env}"
TOOL_NAME="${TOOL_NAME:-Send Email}"
MAX_WAIT_SECONDS="${MAX_WAIT_SECONDS:-180}"

log() {
    printf '[bootstrap] %s\n' "$*"
}

die() {
    printf '[bootstrap] ERROR: %s\n' "$*" >&2
    exit 1
}

require_env() {
    local name="$1"
    [ -n "${!name:-}" ] || die "Required environment variable '$name' is not set."
}

require_env WEBUI_ADMIN_EMAIL
require_env WEBUI_ADMIN_PASSWORD

[ -f "$TOOL_FILE" ] || die "Tool source not found: $TOOL_FILE"

# The official Open WebUI image currently provides this startup script.
START_SCRIPT="${OPENWEBUI_START_SCRIPT:-/app/backend/start.sh}"
[ -x "$START_SCRIPT" ] || die "Open WebUI start script is not executable: $START_SCRIPT"

log "Starting Open WebUI..."
"$START_SCRIPT" &
OWUI_PID=$!

cleanup_on_error() {
    local status=$?
    if [ "$status" -ne 0 ] && kill -0 "$OWUI_PID" 2>/dev/null; then
        log "Bootstrap failed; stopping Open WebUI."
        kill "$OWUI_PID" 2>/dev/null || true
    fi
    exit "$status"
}
trap cleanup_on_error ERR INT TERM

log "Waiting for Open WebUI at ${BASE_URL} ..."
elapsed=0
until curl -fsS "${BASE_URL}/health" >/dev/null 2>&1; do
    if ! kill -0 "$OWUI_PID" 2>/dev/null; then
        wait "$OWUI_PID" || true
        die "Open WebUI exited before becoming healthy."
    fi

    if [ "$elapsed" -ge "$MAX_WAIT_SECONDS" ]; then
        die "Timed out after ${MAX_WAIT_SECONDS}s waiting for Open WebUI."
    fi

    sleep 2
    elapsed=$((elapsed + 2))
done
log "Open WebUI is healthy."

# Build the login JSON with Python so credentials are JSON-escaped correctly.
AUTH_PAYLOAD="$(
    python - <<'PY'
import json
import os

print(json.dumps({
    "email": os.environ["WEBUI_ADMIN_EMAIL"],
    "password": os.environ["WEBUI_ADMIN_PASSWORD"],
}))
PY
)"

log "Authenticating bootstrap admin..."
AUTH_RESPONSE="$(
    curl -fsS \
        -X POST "${BASE_URL}/api/v1/auths/signin" \
        -H 'Content-Type: application/json' \
        --data-binary "$AUTH_PAYLOAD"
)"

# Never print AUTH_RESPONSE: it contains the JWT.
TOKEN="$(
    printf '%s' "$AUTH_RESPONSE" | python -c '
import json, sys
data = json.load(sys.stdin)
token = data.get("token")
if not token:
    raise SystemExit("signin response did not contain a token")
print(token)
'
)"

[ -n "$TOKEN" ] || die "Open WebUI signin returned no JWT."
log "Authenticated successfully."

# Idempotency: check whether the tool already exists.
# 200 => leave it alone for this first bootstrap version.
# 404 => create it.
# anything else => fail rather than guessing.
log "Checking for Workspace Tool '${TOOL_ID}'..."
HTTP_STATUS="$(
    curl -sS -o /tmp/bootstrap-tool-check.json -w '%{http_code}' \
        "${BASE_URL}/api/v1/tools/id/${TOOL_ID}" \
        -H "Authorization: Bearer ${TOKEN}"
)"

case "$HTTP_STATUS" in
    200)
        log "Tool '${TOOL_ID}' already exists; skipping creation."
        ;;
    404)
        log "Creating Workspace Tool '${TOOL_ID}'..."

        # ToolForm currently requires:
        #   id, name, content, meta, access_grants
        # The Python source is embedded as JSON safely here.
        TOOL_PAYLOAD="$(
            TOOL_FILE="$TOOL_FILE" TOOL_ID="$TOOL_ID" TOOL_NAME="$TOOL_NAME" python - <<'PY'
import json
import os
from pathlib import Path

source = Path(os.environ["TOOL_FILE"]).read_text(encoding="utf-8")

print(json.dumps({
    "id": os.environ["TOOL_ID"],
    "name": os.environ["TOOL_NAME"],
    "content": source,
    "meta": {
        "description": "SMTP email tool provisioned automatically at container startup."
    },
    "access_grants": []
}))
PY
        )"

        CREATE_RESPONSE_FILE="/tmp/bootstrap-tool-create.json"
        CREATE_STATUS="$(
            curl -sS -o "$CREATE_RESPONSE_FILE" -w '%{http_code}' \
                -X POST "${BASE_URL}/api/v1/tools/create" \
                -H "Authorization: Bearer ${TOKEN}" \
                -H 'Content-Type: application/json' \
                --data-binary "$TOOL_PAYLOAD"
        )"

        case "$CREATE_STATUS" in
            200|201)
                log "Tool '${TOOL_ID}' created successfully."
                ;;
            *)
                printf '[bootstrap] Tool creation response:\n' >&2
                cat "$CREATE_RESPONSE_FILE" >&2 || true
                printf '\n' >&2
                die "Tool creation failed with HTTP ${CREATE_STATUS}."
                ;;
        esac
        ;;
    *)
        printf '[bootstrap] Tool lookup response:\n' >&2
        cat /tmp/bootstrap-tool-check.json >&2 || true
        printf '\n' >&2
        die "Tool lookup failed with HTTP ${HTTP_STATUS}."
        ;;
esac

###############################################################################
# Dani / MASDAN-DX model profile
###############################################################################

MODEL_FILE="${MODEL_FILE:-${BOOTSTRAP_DIR}/dani-masdan-dx.json}"
[ -f "$MODEL_FILE" ] || die "Model JSON not found: $MODEL_FILE"

log "Preparing model import from $(basename "$MODEL_FILE")..."

# Open WebUI /api/v1/models/import expects {"models":[...]}.
# Accept an export array, an already-wrapped object, or one model object.
MODEL_PAYLOAD="$(
    MODEL_FILE="$MODEL_FILE" python - <<'PY'
import json
import os
from pathlib import Path

path = Path(os.environ["MODEL_FILE"])
data = json.loads(path.read_text(encoding="utf-8"))

if isinstance(data, list):
    models = data
elif isinstance(data, dict) and isinstance(data.get("models"), list):
    models = data["models"]
elif isinstance(data, dict):
    models = [data]
else:
    raise SystemExit("Unsupported model JSON shape.")

if not models:
    raise SystemExit("Model JSON contains no models.")

print(json.dumps({"models": models}))
PY
)"

log "Importing/upserting Dani/MASDAN-DX model profile..."
MODEL_RESPONSE_FILE="/tmp/bootstrap-model-import.json"
MODEL_STATUS="$(
    curl -sS -o "$MODEL_RESPONSE_FILE" -w '%{http_code}' \
        -X POST "${BASE_URL}/api/v1/models/import" \
        -H "Authorization: Bearer ${TOKEN}" \
        -H 'Content-Type: application/json' \
        --data-binary "$MODEL_PAYLOAD"
)"

case "$MODEL_STATUS" in
    200|201)
        log "Dani/MASDAN-DX model profile imported successfully."
        ;;
    *)
        printf '[bootstrap] Model import response:\n' >&2
        cat "$MODEL_RESPONSE_FILE" >&2 || true
        printf '\n' >&2
        die "Model import failed with HTTP ${MODEL_STATUS}."
        ;;
esac

# Remove temporary files and drop shell variables containing auth material.
rm -f /tmp/bootstrap-tool-check.json \
      /tmp/bootstrap-tool-create.json \
      /tmp/bootstrap-model-import.json
unset AUTH_PAYLOAD AUTH_RESPONSE TOKEN TOOL_PAYLOAD MODEL_PAYLOAD 2>/dev/null || true

log "Bootstrap complete. Handing lifecycle back to Open WebUI."
trap - ERR INT TERM
wait "$OWUI_PID"