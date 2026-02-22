#!/usr/bin/env bash
# ============================================================
# aitopcu.com/tasks — tek seferlik sunucu ayarları
# Mevcut Ghost ve diğer servisler KORUNUR.
# Kullanım: bash server-setup.sh
# ============================================================

set -e

DEPLOY_USER="${SUDO_USER:-$(whoami)}"
WEB_ROOT="/var/www/gorevlerim"
NGINX_SITE="/etc/nginx/sites-available/aitopcu.com"   # mevcut site config'in yolu

echo "=== 1. Web klasörü oluştur ==="
mkdir -p "$WEB_ROOT"
chown "$DEPLOY_USER":"$DEPLOY_USER" "$WEB_ROOT"
echo "Klasör hazır: $WEB_ROOT"

echo ""
echo "=== 2. Nginx location bloğunu mevcut config'e ekle ==="
echo ""
echo "Aşağıdaki bloğu $NGINX_SITE dosyasındaki"
echo "mevcut 'server { ... }' bloğunun İÇİNE ekle:"
echo ""
cat << 'NGINX_SNIPPET'
    # /tasks → /tasks/ yönlendirmesi
    location = /tasks {
        return 301 /tasks/;
    }

    # Flutter SPA
    location /tasks/ {
        alias /var/www/gorevlerim/;
        index index.html;
        try_files $uri $uri/ /tasks/index.html;
    }

    # Statik dosyalar için cache
    location ~* ^/tasks/.+\.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot|wasm)$ {
        alias /var/www/gorevlerim/;
        rewrite ^/tasks/(.*)$ /$1 break;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
NGINX_SNIPPET

echo ""
echo "Bloğu ekledikten sonra:"
echo "  sudo nginx -t && sudo systemctl reload nginx"
echo ""
echo "Supabase'de aitopcu.com/tasks URL'sini Redirect URL'lere ekle:"
echo "  Auth → URL Configuration → Redirect URLs → https://aitopcu.com/tasks/**"
echo ""
echo "Kurulum tamamlandı. GitHub'dan push geldiğinde otomatik deploy başlar."
