#!/usr/bin/env bash
set -euo pipefail

# One-command installer for 1panel-private custom build.
# Usage:
#   curl -fsSL <URL>/quick-install.sh | GITHUB_TOKEN=xxx bash -s -- v2.0-custom.6
# or:
#   GITHUB_TOKEN=xxx bash quick-install.sh v2.0-custom.6

OWNER="leeseven1211"
REPO="1panel-private"
VERSION="${1:-v2.0-custom.10}"

if [ "$(id -u)" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

# Repo is public: no token needed.
: "${GITHUB_TOKEN:=}"

need_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1"; exit 1; }; }
need_cmd curl
need_cmd bash

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

INSTALLER_URL="https://github.com/${OWNER}/${REPO}/releases/download/${VERSION}/install-custom.sh"

echo "[1/2] download installer: ${INSTALLER_URL}"
curl -fsSL "$INSTALLER_URL" -o "$TMP_DIR/install-custom.sh"
chmod +x "$TMP_DIR/install-custom.sh"

echo "[2/2] run installer (${VERSION})"
# Pass version through; installer will download the tarball and replace binaries.
bash "$TMP_DIR/install-custom.sh" "$VERSION"

echo "All done. Use '1pctl user-info' to get panel address/user/password."
