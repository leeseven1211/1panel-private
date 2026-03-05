#!/usr/bin/env bash
set -euo pipefail

# One-command installer for 1panel-private custom build.
# Usage:
#   curl -fsSL <URL>/quick-install.sh | GITHUB_TOKEN=xxx bash -s -- v2.0-custom.6
# or:
#   GITHUB_TOKEN=xxx bash quick-install.sh v2.0-custom.6

OWNER="leeseven1211"
REPO="1panel-private"
VERSION="${1:-v2.0-custom.6}"

if [ "$(id -u)" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

TOKEN_FILE="/root/.config/1panel-private/token"
mkdir -p "$(dirname "$TOKEN_FILE")"

# Token handling:
# - If GITHUB_TOKEN is set, use it.
# - Else, if token file exists, read it.
# - Else, prompt once (hidden input) and save to token file (0600).
if [ -z "${GITHUB_TOKEN:-}" ]; then
  if [ -f "$TOKEN_FILE" ]; then
    GITHUB_TOKEN="$(cat "$TOKEN_FILE" | tr -d '\n')"
  else
    echo "GITHUB_TOKEN not set. Please paste a GitHub token with read access to ${OWNER}/${REPO}."
    read -r -s -p "GitHub Token: " GITHUB_TOKEN
    echo
    if [ -z "$GITHUB_TOKEN" ]; then
      echo "Empty token. Abort."
      exit 1
    fi
    umask 077
    printf "%s" "$GITHUB_TOKEN" > "$TOKEN_FILE"
    chmod 600 "$TOKEN_FILE" || true
    echo "Token saved to $TOKEN_FILE (chmod 600). Next installs won't ask again."
  fi
fi

need_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1"; exit 1; }; }
need_cmd curl
need_cmd bash

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

INSTALLER_URL="https://github.com/${OWNER}/${REPO}/releases/download/${VERSION}/install-custom.sh"

echo "[1/2] download installer: ${INSTALLER_URL}"
# private release needs Authorization header
curl -fsSL \
  -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  -H "Accept: application/octet-stream" \
  "$INSTALLER_URL" -o "$TMP_DIR/install-custom.sh"
chmod +x "$TMP_DIR/install-custom.sh"

echo "[2/2] run installer (${VERSION})"
# Pass version through; installer will download the tarball and replace binaries.
GITHUB_TOKEN="$GITHUB_TOKEN" bash "$TMP_DIR/install-custom.sh" "$VERSION"

echo "All done. Use '1pctl user-info' to get panel address/user/password."
