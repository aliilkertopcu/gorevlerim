#!/usr/bin/env bash
# One-time Linode server setup for Görevlerim
# Run as root (or with sudo) on a fresh Ubuntu 22.04/24.04 instance.
# Usage: sudo bash server-setup.sh YOUR_DOMAIN

set -e
DOMAIN="${1:?Usage: sudo bash server-setup.sh YOUR_DOMAIN}"

echo "=== 1. System update ==="
apt-get update && apt-get upgrade -y

echo "=== 2. Install Nginx & Certbot ==="
apt-get install -y nginx certbot python3-certbot-nginx

echo "=== 3. Create web root ==="
mkdir -p /var/www/gorevlerim
# Adjust the owner to your deploy user (default: ubuntu)
chown ubuntu:ubuntu /var/www/gorevlerim

echo "=== 4. Install Nginx site config ==="
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
sed "s/YOUR_DOMAIN/$DOMAIN/g" "$SCRIPT_DIR/nginx.conf" \
    > /etc/nginx/sites-available/gorevlerim
ln -sf /etc/nginx/sites-available/gorevlerim /etc/nginx/sites-enabled/gorevlerim
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl reload nginx

echo "=== 5. Obtain SSL certificate ==="
certbot --nginx -d "$DOMAIN" -d "www.$DOMAIN" --non-interactive --agree-tos -m "admin@$DOMAIN"

echo "=== 6. Enable Nginx on boot ==="
systemctl enable nginx

echo ""
echo "Done! Point your domain's A record to this server's IP, then push to main to deploy."
echo "Supabase: add https://$DOMAIN to Auth > URL Configuration > Redirect URLs."
