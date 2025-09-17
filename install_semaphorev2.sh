#!/bin/bash

set -euo pipefail

echo "=== Ansible + Semaphore Kurulum Scripti ==="

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

# 2. Sistem paketlerini güncelle
echo "Sistem paketleri güncelleniyor..."
dnf update -y

# 3. wget yoksa yükle
if ! command -v wget &>/dev/null; then
    echo "wget bulunamadı, yükleniyor..."
    dnf install -y wget
fi

# 4. MariaDB kurulumu ve servisi başlat
echo "MariaDB kuruluyor..."
dnf install -y mariadb-server
systemctl enable --now mariadb

# 5. MariaDB güvenlik ve DB oluşturma
echo "MariaDB güvenlik ayarları ve Semaphore DB oluşturuluyor..."
mysql -u root <<EOF
CREATE DATABASE IF NOT EXISTS semaphore CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE USER IF NOT EXISTS '$SEMAPHORE_DB_USER'@'localhost' IDENTIFIED BY '$SEMAPHORE_DB_PASS';
GRANT ALL PRIVILEGES ON semaphore.* TO '$SEMAPHORE_DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF

# 6. Semaphore kurulumu
echo "Semaphore kuruluyor..."
VER=$(curl -s https://api.github.com/repos/semaphoreui/semaphore/releases/latest \
  | grep '"tag_name":' | head -1 | sed -E 's/.*"([^"]+)".*/\1/' | sed 's/^v//')

wget -q "https://github.com/semaphoreui/semaphore/releases/download/v${VER}/semaphore_${VER}_linux_amd64.rpm"
dnf install -y "semaphore_${VER}_linux_amd64.rpm"

# 7. Semaphore konfig dosyası oluştur
echo "Config dosyası oluşturuluyor..."
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

# 8. Admin kullanıcı oluşturma
echo "Admin kullanıcısı ekleniyor..."
/usr/bin/semaphore user add \
  --config /etc/semaphore/config.json \
  --login "$SEMAPHORE_ADMIN_USER" \
  --name "$SEMAPHORE_ADMIN_USER" \
  --email "$SEMAPHORE_ADMIN_EMAIL" \
  --password "$SEMAPHORE_ADMIN_PASS"

# 9. Semaphore server başlat
echo "Semaphore servisi başlatılıyor..."
nohup /usr/bin/semaphore server --config /etc/semaphore/config.json > /var/log/semaphore.log 2>&1 &

echo "Kurulum tamamlandı! Web arayüzüne http://<sunucu_ip>:3000 üzerinden erişebilirsiniz."
