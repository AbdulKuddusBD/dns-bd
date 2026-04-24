#!/bin/bash
# =============================================================================
# Blocklist Update Script
# =============================================================================
# Downloads and merges blocklists from multiple sources
# Generates a CoreDNS-compatible hosts file
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BLOCKLIST_DIR="$PROJECT_DIR/blocklists"
OUTPUT_FILE="$BLOCKLIST_DIR/blocklist.hosts"
TEMP_DIR=$(mktemp -d)
CONFIG_FILE="$PROJECT_DIR/config/sources.conf"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[BLOCKLIST]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[BLOCKLIST]${NC} $1"; }

# Cleanup temp dir on exit
cleanup() { rm -rf "$TEMP_DIR"; }
trap cleanup EXIT

# =============================================================================
# Blocklist Sources - Organized by Category
# =============================================================================

# --- ADS ---
ADS_SOURCES=(
    "https://adaway.org/hosts.txt"
    "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"
    "https://pgl.yoyo.org/adservers/serverlist.php?hostformat=hosts&showintro=0&mimetype=plaintext"
    "https://raw.githubusercontent.com/anudeepND/blacklist/master/adservers.txt"
    "https://v.firebog.net/hosts/AdguardDNS.txt"
    "https://v.firebog.net/hosts/Easylist.txt"
)

# --- ADULT / NSFW ---
ADULT_SOURCES=(
    "https://raw.githubusercontent.com/4skinSkywalker/Anti-Porn-HOSTS-File/master/HOSTS.txt"
    "https://raw.githubusercontent.com/Clefspeare13/pornhosts/master/0.0.0.0/hosts"
    "https://raw.githubusercontent.com/chadmayfield/my-pihole-blocklists/master/lists/pi_blocklist_porn_all.list"
    "https://raw.githubusercontent.com/chadmayfield/my-pihole-blocklists/master/lists/pi_blocklist_porn_top1m.list"
    "https://blocklistproject.github.io/Lists/porn.txt"
    "https://nsfw.oisd.nl/domainswild"
)

# --- MALWARE ---
MALWARE_SOURCES=(
    "https://urlhaus.abuse.ch/downloads/hostfile/"
    "https://v.firebog.net/hosts/RPiList-Malware.txt"
    "https://v.firebog.net/hosts/RPiList-Phishing.txt"
    "https://raw.githubusercontent.com/DandelionSprout/adfilt/master/Alternate%20versions%20Anti-Malware%20List/AntiMalwareHosts.txt"
    "https://raw.githubusercontent.com/FadeMind/hosts.extras/master/add.Risk/hosts"
    "https://blocklistproject.github.io/Lists/malware.txt"
    "https://blocklistproject.github.io/Lists/phishing.txt"
    "https://blocklistproject.github.io/Lists/ransomware.txt"
)

# --- TRACKING ---
TRACKING_SOURCES=(
    "https://v.firebog.net/hosts/Easyprivacy.txt"
    "https://raw.githubusercontent.com/crazy-max/WindowsSpyBlocker/master/data/hosts/spy.txt"
    "https://hostfiles.frogeye.fr/firstparty-trackers-hosts.txt"
    "https://raw.githubusercontent.com/FadeMind/hosts.extras/master/add.2o7Net/hosts"
    "https://blocklistproject.github.io/Lists/tracking.txt"
)

# --- GAMBLING ---
GAMBLING_SOURCES=(
    "https://blocklistproject.github.io/Lists/gambling.txt"
    "https://raw.githubusercontent.com/nickspaargaren/no-google/master/pihole-google.txt"
)

# --- SOCIAL MEDIA (optional) ---
SOCIAL_MEDIA_SOURCES=(
    "https://blocklistproject.github.io/Lists/facebook.txt"
    "https://blocklistproject.github.io/Lists/tiktok.txt"
)

# --- GAMING (optional) ---
GAMING_SOURCES=(
    "https://blocklistproject.github.io/Lists/gaming.txt"
)

# =============================================================================
# Functions
# =============================================================================

download_list() {
    local url="$1"
    local output="$2"
    
    if curl -sSL --max-time 30 --retry 2 "$url" -o "$output" 2>/dev/null; then
        return 0
    else
        log_warn "Failed to download: $url"
        return 1
    fi
}

process_hosts_file() {
    local input="$1"
    # Extract domain names from various formats:
    # - 0.0.0.0 domain.com
    # - 127.0.0.1 domain.com
    # - domain.com (plain domain list)
    # Remove comments, empty lines, localhost entries
    grep -vE '^\s*#|^\s*$|localhost|broadcasthost|local$|^!|^\[' "$input" 2>/dev/null | \
        sed -E 's/^(0\.0\.0\.0|127\.0\.0\.1)\s+//; s/\s*#.*$//; s/\r//g; s/^\|\|//; s/\^$//; s/^\*\.//;' | \
        grep -E '^[a-zA-Z0-9]([a-zA-Z0-9-]*\.)+[a-zA-Z]{2,}$' | \
        tr '[:upper:]' '[:lower:]' | \
        sort -u
}

# =============================================================================
# Main
# =============================================================================

# Load categories from .env if available
if [ -f "$PROJECT_DIR/.env" ]; then
    source "$PROJECT_DIR/.env"
fi

CATEGORIES="${BLOCKLIST_CATEGORIES:-ads,adult,malware,tracking}"

log_info "Starting blocklist update..."
log_info "Categories: $CATEGORIES"

COUNTER=0
ALL_DOMAINS="$TEMP_DIR/all_domains.txt"
touch "$ALL_DOMAINS"

# Download and process each category
for CATEGORY in $(echo "$CATEGORIES" | tr ',' ' '); do
    log_info "Processing category: $CATEGORY"

    case "$CATEGORY" in
        ads)        SOURCES=("${ADS_SOURCES[@]}") ;;
        adult)      SOURCES=("${ADULT_SOURCES[@]}") ;;
        malware)    SOURCES=("${MALWARE_SOURCES[@]}") ;;
        tracking)   SOURCES=("${TRACKING_SOURCES[@]}") ;;
        gambling)   SOURCES=("${GAMBLING_SOURCES[@]}") ;;
        social-media) SOURCES=("${SOCIAL_MEDIA_SOURCES[@]}") ;;
        gaming)     SOURCES=("${GAMING_SOURCES[@]}") ;;
        *)
            log_warn "Unknown category: $CATEGORY (skipping)"
            continue
            ;;
    esac

    for URL in "${SOURCES[@]}"; do
        COUNTER=$((COUNTER + 1))
        TEMP_FILE="$TEMP_DIR/list_${COUNTER}.txt"

        if download_list "$URL" "$TEMP_FILE"; then
            process_hosts_file "$TEMP_FILE" >> "$ALL_DOMAINS"
        fi
    done
done

# Add custom blocklist if exists
CUSTOM_FILE="$BLOCKLIST_DIR/custom-block.txt"
if [ -f "$CUSTOM_FILE" ]; then
    log_info "Adding custom blocklist..."
    grep -vE '^\s*#|^\s*$' "$CUSTOM_FILE" 2>/dev/null | \
        tr '[:upper:]' '[:lower:]' >> "$ALL_DOMAINS"
fi

# Deduplicate and generate hosts file
log_info "Generating hosts file..."

TOTAL_BEFORE=$(wc -l < "$ALL_DOMAINS")
sort -u "$ALL_DOMAINS" > "$TEMP_DIR/unique_domains.txt"
TOTAL_AFTER=$(wc -l < "$TEMP_DIR/unique_domains.txt")

# Generate CoreDNS-compatible hosts file
{
    echo "# ============================================================================="
    echo "# DNS Blocklist - Auto-generated by update-blocklists.sh"
    echo "# Generated: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    echo "# Categories: $CATEGORIES"
    echo "# Total domains blocked: $TOTAL_AFTER (deduplicated from $TOTAL_BEFORE)"
    echo "# ============================================================================="
    echo ""
    while IFS= read -r domain; do
        echo "0.0.0.0 $domain"
    done < "$TEMP_DIR/unique_domains.txt"
} > "$OUTPUT_FILE"

log_info "Blocklist updated successfully!"
log_info "  Total sources processed: $COUNTER"
log_info "  Domains before dedup: $TOTAL_BEFORE"
log_info "  Domains after dedup: $TOTAL_AFTER"
log_info "  Output: $OUTPUT_FILE"

# Reload CoreDNS if running
if docker ps --format '{{.Names}}' 2>/dev/null | grep -q 'dns-server'; then
    log_info "Sending reload signal to CoreDNS..."
    docker kill --signal=SIGUSR1 dns-server 2>/dev/null || true
fi

log_info "Done!"
