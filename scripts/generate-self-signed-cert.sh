#!/bin/bash
# =============================================================================
# Generate Self-Signed TLS Certificate (for testing only)
# =============================================================================
# Usage: bash scripts/generate-self-signed-cert.sh [domain]
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CERT_DIR="$PROJECT_DIR/certs"

# Load domain from .env or argument
if [ -f "$PROJECT_DIR/.env" ]; then
    source "$PROJECT_DIR/.env"
fi
DOMAIN="${1:-${DNS_DOMAIN:-dns.localhost}}"

mkdir -p "$CERT_DIR"

echo "[INFO] Generating self-signed certificate for: $DOMAIN"

openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout "$CERT_DIR/privkey.pem" \
    -out "$CERT_DIR/fullchain.pem" \
    -subj "/CN=$DOMAIN" \
    -addext "subjectAltName=DNS:$DOMAIN,DNS:*.$DOMAIN"

echo "[INFO] Certificate generated:"
echo "  - $CERT_DIR/fullchain.pem"
echo "  - $CERT_DIR/privkey.pem"
echo ""
echo "[WARN] This is a self-signed certificate for testing only."
echo "[WARN] For production, use Let's Encrypt via: sudo bash scripts/setup.sh"
