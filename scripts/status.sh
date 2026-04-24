#!/bin/bash
# =============================================================================
# DNS Server - Status Check
# =============================================================================

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

echo ""
echo "============================================"
echo "   DNS Server Status"
echo "============================================"
echo ""

# Docker containers
echo "--- Containers ---"
if docker compose ps 2>/dev/null | grep -q "dns-server"; then
    echo -e "CoreDNS:          ${GREEN}Running${NC}"
else
    echo -e "CoreDNS:          ${RED}Stopped${NC}"
fi

if docker compose ps 2>/dev/null | grep -q "dns-blocklist-updater"; then
    echo -e "Blocklist Updater: ${GREEN}Running${NC}"
else
    echo -e "Blocklist Updater: ${RED}Stopped${NC}"
fi

# Ports
echo ""
echo "--- Ports ---"
for PORT in 53 853 443; do
    if ss -tlnp 2>/dev/null | grep -q ":$PORT "; then
        echo -e "Port $PORT:          ${GREEN}Listening${NC}"
    else
        echo -e "Port $PORT:          ${RED}Not listening${NC}"
    fi
done

# Certificates
echo ""
echo "--- TLS Certificate ---"
if [ -f certs/fullchain.pem ]; then
    EXPIRY=$(openssl x509 -enddate -noout -in certs/fullchain.pem 2>/dev/null | cut -d= -f2)
    echo -e "Certificate:      ${GREEN}Present${NC}"
    echo "Expires:          $EXPIRY"
else
    echo -e "Certificate:      ${RED}Not found${NC}"
fi

# Blocklist
echo ""
echo "--- Blocklist ---"
if [ -f blocklists/blocklist.hosts ]; then
    BLOCKED=$(grep -c "^0.0.0.0" blocklists/blocklist.hosts 2>/dev/null || echo 0)
    UPDATED=$(stat -c %y blocklists/blocklist.hosts 2>/dev/null | cut -d. -f1)
    echo -e "Blocklist:        ${GREEN}Active${NC}"
    echo "Domains blocked:  $BLOCKED"
    echo "Last updated:     $UPDATED"
else
    echo -e "Blocklist:        ${YELLOW}Not generated${NC}"
fi

# DNS Test
echo ""
echo "--- DNS Test ---"
if command -v dig &>/dev/null; then
    RESULT=$(dig @127.0.0.1 google.com +short +time=3 2>/dev/null)
    if [ -n "$RESULT" ]; then
        echo -e "DNS Resolution:   ${GREEN}Working${NC} (google.com -> $RESULT)"
    else
        echo -e "DNS Resolution:   ${RED}Failed${NC}"
    fi
else
    echo "dig not installed (apt install dnsutils)"
fi

echo ""
