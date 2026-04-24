#!/bin/bash
# =============================================================================
# DNS Server - Uninstall Script
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

echo "[INFO] Stopping DNS server..."
docker compose down 2>/dev/null || true

echo "[INFO] Re-enabling systemd-resolved..."
systemctl enable systemd-resolved 2>/dev/null || true
systemctl start systemd-resolved 2>/dev/null || true

echo "[INFO] Cleaning up..."
rm -rf certs certbot-webroot
rm -f blocklists/blocklist.hosts

echo "[INFO] DNS server uninstalled."
echo "[INFO] Your .env and custom blocklist files are preserved."
