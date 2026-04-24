#!/bin/bash
# =============================================================================
# Renew Let's Encrypt TLS Certificate
# =============================================================================
# Usage: sudo bash scripts/renew-cert.sh
# Add to crontab: 0 3 * * 1 cd /path/to/dns-server && sudo bash scripts/renew-cert.sh
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

if [ -f .env ]; then
    source .env
fi

DOMAIN="${DNS_DOMAIN:-dns.example.com}"

echo "[INFO] Renewing certificate for: $DOMAIN"

# Stop CoreDNS temporarily to free port 443
docker compose stop coredns 2>/dev/null || true

# Renew certificate
docker run --rm \
    -p 80:80 \
    -v "$(pwd)/certs:/etc/letsencrypt" \
    certbot/certbot renew --standalone --quiet

# Copy renewed certs
if [ -d "certs/live/$DOMAIN" ]; then
    cp "certs/live/$DOMAIN/fullchain.pem" certs/fullchain.pem
    cp "certs/live/$DOMAIN/privkey.pem" certs/privkey.pem
    echo "[INFO] Certificate renewed successfully"
fi

# Restart CoreDNS
docker compose up -d coredns
echo "[INFO] CoreDNS restarted with new certificate"
