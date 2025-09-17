#!/bin/bash

set -euo pipefail

echo "=== Ansible + Semaphore Kurulum Scripti (AlmaLinux 9) ==="

# 1. Kullanıcıdan değerleri al
read -p "MariaDB kullanıcı adını girin (default: semaphore): " SEMAPHORE_DB_USER
SEMAPHORE_DB_USER=${SEMAPHORE_DB_USER:-semaphore}

read -sp "MariaDB şifresini girin: " SEMAPHORE_DB_PASS
echo

read -p "Semaphore admin kullanıcı adını girin (default: admin): " SEMAPHORE_ADMIN_USER
SEMAPHORE_ADMIN_USER=${SEMAPHORE_ADMIN_USER:-admin}

read -p "Semaphore admin emailini girin: " SEMAPHORE_ADMIN_EMAIL

read -sp "Semaphore admin şifresini girin: " SEMAPHORE_ADMIN_PASS
echo

# 2. Gerekli paketler
echo "[*] Sistem paketleri yükleniyor..."
dnf install -y epel-release
dnf install -y wget curl git tar unzip openssl ansible mariadb-server

# 3. MariaDB başlat
echo "[*] MariaDB başlatılıyor..."
systemctl enable --now mariadb

# 4. Veritabanı ve kullanıcı
echo "[*] MariaDB ayarlanıyor..."
mysql -u root <<EOF
CREATE DATABASE IF NOT EXISTS semaphore CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE USER IF NOT EXISTS '$SEMAPHORE_DB_USER'@'localhost';
ALTER USER '$SEMAPHORE_DB_USER'@'localhost' IDENTIFIED BY '$SEMAPHORE_DB_PASS';
GRANT ALL PRIVILEGES ON semaphore.* TO '$SEMAPHORE_DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF

# 5. Semaphore indir & kur
echo "[*] Semaphore indiriliyor..."
VER=$(curl -s https://api.github.com/repos/semaphoreui/semaphore/releases/latest \
  | grep '"tag_name":' | head -1 | sed -E 's/.*"([^"]+)".*/\1/' | sed 's/^v//')

wget -q "https://github.com/semaphoreui/semaphore/releases/download/v${VER}/semaphore_${VER}_linux_amd64.rpm"
dnf install -y "semaphore_${VER}_linux_amd64.rpm"

# 6. Config dosyası
echo "[*] Config oluşturuluyor..."
mkdir -p /etc/semaphore
cat > /etc/semaphore/config.json <<EOL
{
    "mysql": {
        "host": "127.0.0.1:3306",
        "user": "$SEMAPHORE_DB_USER",
        "pass": "$SEMAPHORE_DB_PASS",
        "name": "semaphore"
    },
    "dialect": "mysql",
    "tmp_path": "/var/lib/semaphore",
    "web_host": "0.0.0.0",
    "web_port": 3000,
    "cookie_hash": "$(openssl rand -base64 32)",
    "cookie_encryption": "$(openssl rand -base64 32)",
    "access_key_encryption": "$(openssl rand -base64 32)"
}
EOL

# 7. Admin kullanıcı ekle
echo "[*] Admin kullanıcısı ekleniyor..."
/usr/bin/semaphore user add \
  --config /etc/semaphore/config.json \
  --login "$SEMAPHORE_ADMIN_USER" \
  --name "$SEMAPHORE_ADMIN_USER" \
  --email "$SEMAPHORE_ADMIN_EMAIL" \
  --password "$SEMAPHORE_ADMIN_PASS"

# 8. systemd servis dosyası oluştur
echo "[*] systemd servis dosyası ekleniyor..."
cat > /etc/systemd/system/semaphore.service <<EOF
[Unit]
Description=Semaphore Ansible UI
After=network.target mariadb.service

[Service]
ExecStart=/usr/bin/semaphore server --config /etc/semaphore/config.json
WorkingDirectory=/etc/semaphore
Restart=always
RestartSec=5
User=root

[Install]
WantedBy=multi-user.target
EOF

# 9. Servisi enable & başlat
systemctl daemon-reload
systemctl enable --now semaphore

echo "Kurulum tamamlandı!"
echo "Web arayüzü: http://<sunucu_ip>:3000"
echo "Admin kullanıcı: $SEMAPHORE_ADMIN_USER / $SEMAPHORE_ADMIN_PASS"
echo "Loglar: journalctl -u semaphore -f"
