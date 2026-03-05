#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   bash install-custom.sh <version>
# Example:
#   GITHUB_TOKEN=ghp_xxx bash install-custom.sh v2.0-custom.1

OWNER="leeseven1211"
REPO="1panel-private"

# prevent "unbound variable" when running with `set -u`
: "${GITHUB_TOKEN:=}"
VERSION="${1:-latest}"
ASSET_NAME="1panel-custom-linux-amd64.tar.gz"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

need_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1"; exit 1; }; }
need_cmd curl
need_cmd tar
need_cmd systemctl

if [ "$(id -u)" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

# install official 1Panel if not installed
if ! command -v 1pctl >/dev/null 2>&1; then
  echo "[1/6] 1Panel not found, install official first..."
  # Use v2 installer channel by default for custom v2 builds
  curl -sSL https://resource.fit2cloud.com/1panel/package/v2/quick_start.sh -o "$TMP_DIR/quick_start.sh"

  if [ "${INTERACTIVE:-0}" = "1" ]; then
    echo "[info] INTERACTIVE=1: running official v2 installer in interactive mode"
    bash "$TMP_DIR/quick_start.sh"
  else
    # Non-interactive installer input to avoid hanging on prompts.
    # Prompts vary slightly by version, but generally include:
    # - language selection
    # - install dir (blank = /opt)
    # - docker install / mirror questions (answer n)
    # - port/entrance/user/password (use defaults)
    printf '1\n\n'"${PANEL_DOCKER_INSTALL:-n}"'\n\n\n\n\n\n' | bash "$TMP_DIR/quick_start.sh" || true

    # If install succeeded, 1pctl should exist now.
    if ! command -v 1pctl >/dev/null 2>&1; then
      echo "official v2 install did not produce 1pctl; please run installer manually (or INTERACTIVE=1) and rerun this script"
      exit 1
    fi
  fi
else
  echo "[1/6] 1Panel already installed"
fi

# If repo/release is private, set GITHUB_TOKEN with read access.
# When repo is public, token is optional.
CURL_AUTH_ARGS=()
API_AUTH_ARGS=()
if [ -n "${GITHUB_TOKEN:-}" ]; then
  CURL_AUTH_ARGS=( -H "Authorization: Bearer ${GITHUB_TOKEN}" -H "Accept: application/octet-stream" )
  API_AUTH_ARGS=( -H "Authorization: Bearer ${GITHUB_TOKEN}" -H "Accept: application/vnd.github+json" )
fi

if [ "$VERSION" = "latest" ]; then
  API_URL="https://api.github.com/repos/${OWNER}/${REPO}/releases/latest"
else
  API_URL="https://api.github.com/repos/${OWNER}/${REPO}/releases/tags/${VERSION}"
fi

echo "[2/6] resolve release asset..."
ASSET_URL=$(curl -fsSL "${API_AUTH_ARGS[@]}" "$API_URL" \
  | sed -n 's/.*"browser_download_url"[[:space:]]*:[[:space:]]*"\([^"]*'"$ASSET_NAME"'\)".*/\1/p' | head -n1)

if [ -z "$ASSET_URL" ]; then
  echo "Cannot find asset: $ASSET_NAME"
  exit 1
fi

echo "[3/6] download release asset"
curl -fL "${CURL_AUTH_ARGS[@]}" \
  "$ASSET_URL" -o "$TMP_DIR/$ASSET_NAME"

echo "[4/6] extract"
mkdir -p "$TMP_DIR/pkg"
tar xzf "$TMP_DIR/$ASSET_NAME" -C "$TMP_DIR/pkg"

CORE_NEW="$TMP_DIR/pkg/1panel-core"
AGENT_NEW="$TMP_DIR/pkg/1panel-agent"

[ -f "$CORE_NEW" ] || { echo "missing 1panel-core in package"; exit 1; }
[ -f "$AGENT_NEW" ] || { echo "missing 1panel-agent in package"; exit 1; }

# Resolve service ExecStart binary paths dynamically
resolve_exec_bin() {
  local svc="$1"
  local line
  line=$(systemctl cat "$svc" 2>/dev/null | grep -E '^ExecStart=' | head -n1 || true)
  [ -n "$line" ] || return 1
  line="${line#ExecStart=}"
  # strip leading '-'
  line="${line#-}"
  # first token is binary path
  echo "$line" | awk '{print $1}'
}

# Detect service names (v2 uses 1panel-core/1panel-agent)
CORE_SVC="1panel"
AGENT_SVC=""

# Prefer probing actual unit existence (more reliable than parsing list-unit-files)
if systemctl cat 1panel-core >/dev/null 2>&1; then
  CORE_SVC="1panel-core"
fi
if systemctl cat 1panel-agent >/dev/null 2>&1; then
  AGENT_SVC="1panel-agent"
fi

CORE_BIN="$(resolve_exec_bin "$CORE_SVC" || true)"
AGENT_BIN=""
if [ -n "$AGENT_SVC" ]; then
  AGENT_BIN="$(resolve_exec_bin "$AGENT_SVC" || true)"
fi

[ -n "$CORE_BIN" ] || CORE_BIN="$(command -v 1panel-core || command -v 1panel || true)"
[ -n "$AGENT_BIN" ] || AGENT_BIN="$(command -v 1panel-agent || true)"

[ -n "$CORE_BIN" ] || { echo "cannot resolve 1panel core binary path"; exit 1; }
[ -f "$CORE_BIN" ] || { echo "core binary not found: $CORE_BIN"; exit 1; }

echo "[5/6] replace binaries"
cp -a "$CORE_BIN" "${CORE_BIN}.bak.$(date +%Y%m%d%H%M%S)"
install -m 755 "$CORE_NEW" "$CORE_BIN"

if [ -n "$AGENT_BIN" ] && [ -f "$AGENT_BIN" ] && [ -n "$AGENT_SVC" ]; then
  cp -a "$AGENT_BIN" "${AGENT_BIN}.bak.$(date +%Y%m%d%H%M%S)"
  install -m 755 "$AGENT_NEW" "$AGENT_BIN"
  HAS_AGENT=1
else
  echo "[warn] 1panel-agent service/binary not found, skip agent replacement"
  HAS_AGENT=0
fi

echo "[6/6] restart services"
systemctl daemon-reload || true
systemctl restart "$CORE_SVC" || {
  echo "failed to restart $CORE_SVC";
  systemctl --no-pager -l status "$CORE_SVC" || true;
  exit 1;
}
if [ "$HAS_AGENT" -eq 1 ]; then
  systemctl restart "$AGENT_SVC" || true
fi
sleep 1
systemctl --no-pager --full status "$CORE_SVC" | head -n 20 || true
if [ "$HAS_AGENT" -eq 1 ]; then
  systemctl --no-pager --full status "$AGENT_SVC" | head -n 20 || true
fi

echo "Done. Custom build installed."
