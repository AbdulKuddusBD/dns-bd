# DNS Server - প্রাইভেট DNS কন্টেন্ট ফিল্টারিং সহ

নিজস্ব **DNS over TLS (DoT)** এবং **DNS over HTTPS (DoH)** সার্ভার। বিজ্ঞাপন, প্রাপ্তবয়স্ক কন্টেন্ট, ম্যালওয়্যার ইত্যাদি ব্লক করে। [AdGuard DNS](https://adguard-dns.io/) এবং [KahfGuard](https://kahfguard.com/) এর মতো কাজ করে।

## বৈশিষ্ট্য

- **প্রাইভেট DNS (DoT)** - Android এর Private DNS সেটিংসে কাজ করে
- **DNS over HTTPS (DoH)** - ব্রাউজার এবং অন্যান্য DoH ক্লায়েন্টে কাজ করে
- **কন্টেন্ট ফিল্টারিং** - বিজ্ঞাপন, প্রাপ্তবয়স্ক কন্টেন্ট, ম্যালওয়্যার, ট্র্যাকিং ব্লক করে
- **৫ লক্ষ+ ডোমেইন ব্লক** - বিশ্বস্ত কমিউনিটি ব্লকলিস্ট থেকে সংগ্রহিত
- **স্বয়ংক্রিয় আপডেট** - প্রতি ৬ ঘণ্টায় ব্লকলিস্ট রিফ্রেশ
- **কাস্টম ব্লকলিস্ট** - নিজের ডোমেইন ব্লক করুন
- **Let's Encrypt TLS** - স্বয়ংক্রিয় HTTPS সার্টিফিকেট
- **Docker-ভিত্তিক** - এক কমান্ডে ডিপ্লয়
- **হালকা** - কম রিসোর্সের VPS তেও চলে (৫১২MB RAM যথেষ্ট)

## দ্রুত শুরু

### প্রয়োজনীয়তা

- একটি VPS (Ubuntu 20.04+ সুপারিশকৃত) পাবলিক IP সহ
- একটি ডোমেইন নাম যা আপনার VPS এ পয়েন্ট করা (যেমন: `dns.yourdomain.com`)
- ফায়ারওয়ালে পোর্ট 53, 80, 443, 853 খোলা

### ধাপ ১: রিপোজিটরি ক্লোন করুন

```bash
git clone https://github.com/YOUR_USERNAME/dns-server.git
cd dns-server
```

### ধাপ ২: DNS রেকর্ড সেট করুন

আপনার ডোমেইনকে VPS এর IP তে পয়েন্ট করুন:

```
dns.yourdomain.com  →  A record  →  আপনার_VPS_IP
```

### ধাপ ৩: সেটআপ স্ক্রিপ্ট চালান

```bash
sudo bash scripts/setup.sh
```

স্ক্রিপ্ট যা করবে:
1. Docker ইনস্টল করবে (না থাকলে)
2. আপনার ডোমেইন এবং ইমেইল জিজ্ঞেস করবে
3. Let's Encrypt TLS সার্টিফিকেট তৈরি করবে
4. ব্লকলিস্ট ডাউনলোড এবং কম্পাইল করবে
5. DNS সার্ভার শুরু করবে

### ধাপ ৪: DNS ব্যবহার করুন

**Android (প্রাইভেট DNS):**
1. Settings → Network & Internet → Private DNS
2. "Private DNS provider hostname" সিলেক্ট করুন
3. লিখুন: `dns.yourdomain.com`
4. Save করুন

**iPhone/iOS:**
- DNS প্রোফাইল জেনারেটর ব্যবহার করুন
- DNS over TLS সার্ভার হিসেবে `dns.yourdomain.com` দিন

## ব্যবস্থাপনা

### স্ট্যাটাস দেখুন
```bash
bash scripts/status.sh
```

### লগ দেখুন
```bash
docker compose logs -f coredns
```

### ব্লকলিস্ট ম্যানুয়ালি আপডেট
```bash
bash scripts/update-blocklists.sh
```

### কাস্টম ডোমেইন ব্লক করুন
```bash
# কাস্টম ব্লকলিস্ট এডিট করুন
nano blocklists/custom-block.txt

# তারপর আপডেট করুন
bash scripts/update-blocklists.sh
```

### সার্ভার বন্ধ করুন
```bash
docker compose down
```

### সার্ভার আনইনস্টল
```bash
sudo bash scripts/uninstall.sh
```

## ব্লকলিস্ট ক্যাটাগরি

| ক্যাটাগরি | বিবরণ |
|-----------|-------|
| `ads` | বিজ্ঞাপন, অ্যাড নেটওয়ার্ক |
| `adult` | প্রাপ্তবয়স্ক/NSFW কন্টেন্ট |
| `malware` | ম্যালওয়্যার, ফিশিং, র‍্যানসমওয়্যার |
| `tracking` | ট্র্যাকার, অ্যানালিটিক্স |
| `gambling` | জুয়া সাইট |
| `social-media` | Facebook, TikTok (ঐচ্ছিক) |
| `gaming` | গেমিং প্ল্যাটফর্ম (ঐচ্ছিক) |

## ফায়ারওয়াল সেটআপ

```bash
# UFW (Ubuntu)
sudo ufw allow 53/tcp
sudo ufw allow 53/udp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 853/tcp
```

## পরীক্ষা

```bash
# DNS রেজল্যুশন পরীক্ষা
dig @YOUR_VPS_IP google.com

# ব্লকিং পরীক্ষা - 0.0.0.0 রিটার্ন করলে ব্লক হচ্ছে
dig @YOUR_VPS_IP doubleclick.net
```

## সমস্যা সমাধান

### পোর্ট 53 ব্যবহারে আছে
```bash
sudo systemctl stop systemd-resolved
sudo systemctl disable systemd-resolved
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf
```

### সার্টিফিকেট সমস্যা
```bash
# টেস্টিং এর জন্য self-signed cert তৈরি করুন
bash scripts/generate-self-signed-cert.sh
```

## লাইসেন্স

MIT License
