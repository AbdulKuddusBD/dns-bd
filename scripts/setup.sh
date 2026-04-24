#!/bin/bash
# =============================================================================
# DNS Server - Initial Setup Script
# =============================================================================
# Usage: sudo bash scripts/setup.sh
# =============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()    { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }
log_step()    { echo -e "${BLUE}[STEP]${NC} $1"; }

echo ""
echo "============================================"
echo "   DNS Server Setup (KahfGuard-style)"
echo "============================================"
echo ""

# Check root
if [ "$EUID" -ne 0 ]; then
    log_error "Please run as root: sudo bash scripts/setup.sh"
    exit 1
fi

# --- Step 1: Check dependencies ---
log_step "1/7 - Checking dependencies..."

if ! command -v docker &>/dev/null; then
    log_info "Installing Docker..."
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker
    log_info "Docker installed successfully"
else
    log_info "Docker already installed: $(docker --version)"
fi

if ! command -v docker-compose &>/dev/null && ! docker compose version &>/dev/null; then
    log_info "Installing Docker Compose..."
    apt-get update && apt-get install -y docker-compose-plugin
    log_info "Docker Compose installed"
else
    log_info "Docker Compose already installed"
fi

# --- Step 2: Get configuration ---
log_step "2/7 - Configuration..."

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

if [ ! -f .env ]; then
    cp .env.example .env
    log_warn ".env file created from .env.example"
    log_warn "Please edit .env with your domain and email before continuing"
    echo ""
    read -p "Enter your DNS domain (e.g., dns.yourdomain.com): " DNS_DOMAIN
    read -p "Enter your email for Let's Encrypt: " LETSENCRYPT_EMAIL
    read -p "Enter blocklist categories (ads,adult,malware,tracking): " BLOCKLIST_CATEGORIES

    DNS_DOMAIN="${DNS_DOMAIN:-dns.example.com}"
    LETSENCRYPT_EMAIL="${LETSENCRYPT_EMAIL:-admin@example.com}"
    BLOCKLIST_CATEGORIES="${BLOCKLIST_CATEGORIES:-ads,adult,malware,tracking}"

    sed -i "s|DNS_DOMAIN=.*|DNS_DOMAIN=$DNS_DOMAIN|" .env
    sed -i "s|LETSENCRYPT_EMAIL=.*|LETSENCRYPT_EMAIL=$LETSENCRYPT_EMAIL|" .env
    sed -i "s|BLOCKLIST_CATEGORIES=.*|BLOCKLIST_CATEGORIES=$BLOCKLIST_CATEGORIES|" .env
else
    log_info ".env file already exists"
fi

source .env

# --- Step 3: Create directories ---
log_step "3/7 - Creating directories..."
mkdir -p certs blocklists certbot-webroot
touch certs/.gitkeep

# --- Step 4: Stop conflicting services ---
log_step "4/7 - Checking for port conflicts..."

if systemctl is-active --quiet systemd-resolved 2>/dev/null; then
    log_warn "Disabling systemd-resolved (conflicts with port 53)..."
    systemctl stop systemd-resolved
    systemctl disable systemd-resolved
    # Set a fallback DNS
    echo "nameserver 8.8.8.8" > /etc/resolv.conf
    echo "nameserver 8.8.4.4" >> /etc/resolv.conf
    log_info "systemd-resolved disabled"
fi

# --- Step 5: Generate TLS certificates ---
log_step "5/7 - Setting up TLS certificates..."

if [ ! -f certs/fullchain.pem ]; then
    log_info "Generating TLS certificate with Let's Encrypt..."
    log_info "Domain: $DNS_DOMAIN"

    # Use standalone mode for initial certificate
    docker run --rm \
        -p 80:80 \
        -v "$(pwd)/certs:/etc/letsencrypt" \
        -v "$(pwd)/certbot-webroot:/var/www/certbot" \
        certbot/certbot certonly \
        --standalone \
        --non-interactive \
        --agree-tos \
        --email "$LETSENCRYPT_EMAIL" \
        -d "$DNS_DOMAIN"

    # Copy certs to expected location
    if [ -d "certs/live/$DNS_DOMAIN" ]; then
        cp "certs/live/$DNS_DOMAIN/fullchain.pem" certs/fullchain.pem
        cp "certs/live/$DNS_DOMAIN/privkey.pem" certs/privkey.pem
        log_info "TLS certificate generated successfully"
    else
        log_error "Certificate generation failed. Check your domain DNS settings."
        log_warn "Make sure $DNS_DOMAIN points to this server's IP address."
        log_warn "You can generate a self-signed cert for testing:"
        log_warn "  bash scripts/generate-self-signed-cert.sh"
        exit 1
    fi
else
    log_info "TLS certificates already exist"
fi

# --- Step 6: Download blocklists ---
log_step "6/7 - Downloading blocklists..."
bash scripts/update-blocklists.sh

# --- Step 7: Start services ---
log_step "7/7 - Starting DNS server..."

docker compose up -d

echo ""
echo "============================================"
echo "   DNS Server is running!"
echo "============================================"
echo ""
log_info "Domain:       $DNS_DOMAIN"
log_info "DNS (UDP/TCP): Port 53"
log_info "DoT (TLS):     Port 853"
log_info "DoH (HTTPS):   Port 443"
echo ""
log_info "Android Private DNS: $DNS_DOMAIN"
log_info "iOS DNS Profile:     Use a .mobileconfig profile"
echo ""
log_info "To check logs:   docker compose logs -f coredns"
log_info "To update lists: bash scripts/update-blocklists.sh"
log_info "To stop:         docker compose down"
echo ""
