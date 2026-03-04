# Custom one-click install (private fork)

## 1) Build release package
In GitHub Actions, run workflow: `release-custom`.
Input a version tag, for example:

- `v2.0-custom.1`

Workflow will build and upload:

- `1panel-custom-linux-amd64.tar.gz`
- `install-custom.sh`

## 2) Install on target server (one-line)

```bash
curl -fsSL -H "Authorization: Bearer <GITHUB_TOKEN>" \
  https://raw.githubusercontent.com/leeseven1211/1panel-private/main/deploy/install-custom.sh \
  -o /tmp/install-custom.sh && sudo bash /tmp/install-custom.sh v2.0-custom.1
```

Or:

```bash
export GITHUB_TOKEN=<GITHUB_TOKEN>
curl -fsSL https://raw.githubusercontent.com/leeseven1211/1panel-private/main/deploy/install-custom.sh -o /tmp/install-custom.sh
sudo -E bash /tmp/install-custom.sh v2.0-custom.1
```

## Notes

- `GITHUB_TOKEN` must have access to private repo release assets (`repo` scope is enough).
- If 1Panel is not installed, script installs official 1Panel first, then replaces core/agent binaries with your custom build.
- Script auto-detects binary paths from systemd service (`1panel`, `1panel-agent`).
