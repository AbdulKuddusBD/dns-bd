# DNS Server - Private DNS with Content Filtering

A self-hosted **DNS over TLS (DoT)** and **DNS over HTTPS (DoH)** server with built-in content filtering. Works with Android's Private DNS, iOS, and all major platforms. Similar to [AdGuard DNS](https://adguard-dns.io/) and [KahfGuard](https://kahfguard.com/).

[বাংলা ডকুমেন্টেশন](README_BN.md)

## Features

- **Private DNS (DoT)** - Works with Android's built-in Private DNS setting
- **DNS over HTTPS (DoH)** - Works with browsers and other DoH clients
- **Content Filtering** - Blocks ads, adult content, malware, tracking, and more
- **500,000+ blocked domains** - Curated from trusted community blocklists
- **Auto-updating blocklists** - Refreshes every 6 hours automatically
- **Custom blocklist** - Add your own domains to block
- **Let's Encrypt TLS** - Automatic HTTPS certificate management
- **Docker-based** - One-command deployment
- **Lightweight** - Runs on minimal VPS (512MB RAM is enough)

## Architecture

```
[Phone/Device]
     |
     | DNS over TLS (Port 853)
     | DNS over HTTPS (Port 443)
     |
[Your VPS - CoreDNS]
     |
     |--- [Blocklist Filter] --- Block? --> Return 0.0.0.0
     |
     |--- [Forward to Upstream] --> Google DNS / Cloudflare
     |
[Response back to device]
```

## Blocklist Categories

| Category | Description | Domains |
|----------|-------------|---------|
| `ads` | Advertisements, ad networks | ~200K |
| `adult` | Adult/NSFW content | ~300K |
| `malware` | Malware, phishing, ransomware | ~50K |
| `tracking` | Trackers, analytics, telemetry | ~80K |
| `gambling` | Gambling sites | ~10K |
| `social-media` | Facebook, TikTok (optional) | ~5K |
| `gaming` | Gaming platforms (optional) | ~3K |

## Quick Start

### Prerequisites

- A VPS (Ubuntu 20.04+ recommended) with a public IP
- A domain name pointing to your VPS (e.g., `dns.yourdomain.com`)
- Ports 53, 80, 443, 853 open in your firewall

### 1. Clone the repository

```bash
git clone https://github.com/AbdulKuddusBD/dns-bd.git
cd dns-server
```

### 2. Configure DNS records

Point your domain to your VPS IP address:

```
dns.yourdomain.com  →  A record  →  YOUR_VPS_IP
```

### 3. Run the setup script

```bash
sudo bash scripts/setup.sh
```

The script will:
1. Install Docker (if not present)
2. Ask for your domain and email
3. Generate Let's Encrypt TLS certificates
4. Download and compile blocklists
5. Start the DNS server

### 4. Use your DNS server

**Android (Private DNS):**
1. Settings → Network & Internet → Private DNS
2. Select "Private DNS provider hostname"
3. Enter: `dns.yourdomain.com`
4. Save

**iOS:**
- Use a DNS profile generator or Apple Configurator
- Set DNS over TLS server to `dns.yourdomain.com`

**Windows:**
- Settings → Network → DNS → DNS over HTTPS
- Enter: `https://dns.yourdomain.com/dns-query`

**Linux:**
```bash
# Using systemd-resolved
sudo systemd-resolve --set-dns=YOUR_VPS_IP --set-dnsovertls=yes --interface=eth0
```

## Management

### Check status
```bash
bash scripts/status.sh
```

### View logs
```bash
docker compose logs -f coredns
```

### Update blocklists manually
```bash
bash scripts/update-blocklists.sh
```

### Add custom blocked domains
```bash
# Edit the custom blocklist
nano blocklists/custom-block.txt

# Then update
bash scripts/update-blocklists.sh
```

### Restart the server
```bash
docker compose restart coredns
```

### Stop the server
```bash
docker compose down
```

### Renew TLS certificate
```bash
sudo bash scripts/renew-cert.sh
```

## Configuration

### Environment Variables (`.env`)

| Variable | Description | Default |
|----------|-------------|---------|
| `DNS_DOMAIN` | Your DNS server domain | `dns.example.com` |
| `LETSENCRYPT_EMAIL` | Email for Let's Encrypt | `admin@example.com` |
| `UPSTREAM_DNS` | Upstream DNS servers | `8.8.8.8,8.8.4.4` |
| `BLOCKLIST_CATEGORIES` | Enabled categories | `ads,adult,malware,tracking` |

### Changing blocked categories

Edit `.env`:
```bash
# Block everything
BLOCKLIST_CATEGORIES=ads,adult,malware,tracking,gambling

# Minimal blocking (ads + malware only)
BLOCKLIST_CATEGORIES=ads,malware
```

Then update:
```bash
bash scripts/update-blocklists.sh
docker compose restart coredns
```

## Firewall Setup

```bash
# UFW (Ubuntu)
sudo ufw allow 53/tcp
sudo ufw allow 53/udp
sudo ufw allow 80/tcp    # For Let's Encrypt
sudo ufw allow 443/tcp   # DoH
sudo ufw allow 853/tcp   # DoT (Private DNS)

# iptables
sudo iptables -A INPUT -p tcp --dport 53 -j ACCEPT
sudo iptables -A INPUT -p udp --dport 53 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 853 -j ACCEPT
```

## Auto-renewal (Cron)

Set up automatic certificate renewal:
```bash
# Add to crontab
sudo crontab -e

# Renew certificate every Monday at 3 AM
0 3 * * 1 cd /path/to/dns-server && sudo bash scripts/renew-cert.sh >> /var/log/dns-cert-renew.log 2>&1

# Update blocklists every 6 hours (already handled by Docker, but as backup)
0 */6 * * * cd /path/to/dns-server && bash scripts/update-blocklists.sh >> /var/log/dns-blocklist.log 2>&1
```

## Testing

### Test DNS resolution
```bash
# Standard DNS
dig @YOUR_VPS_IP google.com

# DNS over TLS
kdig @YOUR_VPS_IP +tls google.com

# Check if blocking works
dig @YOUR_VPS_IP doubleclick.net
# Should return 0.0.0.0
```

### Test from Android
1. Set Private DNS to your domain
2. Visit [https://adguard.com/test.html](https://adguard.com/test.html)
3. It should show that ads are being blocked

## Troubleshooting

### Port 53 already in use
```bash
# Check what's using port 53
sudo lsof -i :53

# Disable systemd-resolved
sudo systemctl stop systemd-resolved
sudo systemctl disable systemd-resolved
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf
```

### Certificate issues
```bash
# Generate self-signed cert for testing
bash scripts/generate-self-signed-cert.sh

# Check certificate expiry
openssl x509 -enddate -noout -in certs/fullchain.pem
```

### CoreDNS not starting
```bash
# Check logs
docker compose logs coredns

# Validate Corefile
docker run --rm -v $(pwd)/Corefile:/etc/coredns/Corefile coredns/coredns:1.11.1 -validate
```

## Uninstall

```bash
sudo bash scripts/uninstall.sh
```

## License

MIT License - Feel free to use and modify.
