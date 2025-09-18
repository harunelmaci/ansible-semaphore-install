#!/bin/bash
# Ubuntu 22.04/24.04 üzerinde Ansible + MariaDB + Semaphore kurulumu (otomatik latest version)

set -e

echo "=== Ansible + Semaphore Kurulum Scripti (Ubuntu) ==="

# --------------- Prompt ile kullanıcıdan bilgileri al ----------------
read -sp "MariaDB root şifresi (yeni ayarlanacak): " MYSQL_ROOT_PASS
echo

read -p "Semaphore DB adı (default: semaphore): " SEMAPHORE_DB
SEMAPHORE_DB=${SEMAPHORE_DB:-semaphore}

read -p "Semaphore DB kullanıcısı (default: semaphore): " SEMAPHORE_DB_USER
SEMAPHORE_DB_USER=${SEMAPHORE_DB_USER:-semaphore}

read -sp "Semaphore DB şifresi: " SEMAPHORE_DB_PASS
echo

read -p "Semaphore admin kullanıcı adı (default: admin): " SEMAPHORE_ADMIN_USER
SEMAPHORE_ADMIN_USER=${SEMAPHORE_ADMIN_USER:-admin}

read -p "Semaphore admin email: " SEMAPHORE_ADMIN_EMAIL

read -sp "Semaphore admin şifresi: " SEMAPHORE_ADMIN_PASS
echo
# --------------------------------------------------------------------

SEMAPHORE_INSTALL_DIR="/usr/bin"
SEMAPHORE_CONFIG="/etc/semaphore/config.json"
SEMAPHORE_TMP="/var/lib/semaphore"
SEMAPHORE_PORT=3000

echo "### Sistem güncelleniyor..."
apt update -y && apt upgrade -y
apt install -y wget curl git gnupg lsb-release software-properties-common

echo "### Ansible kuruluyor..."
apt install -y ansible

echo "### MariaDB kuruluyor..."
apt install -y mariadb-server
systemctl enable --now mariadb

echo "### MariaDB root güvenliği..."
mysql -u root <<EOF || true
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${MYSQL_ROOT_PASS}';
DELETE FROM mysql.user WHERE User='';
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%';
FLUSH PRIVILEGES;
EOF

echo "### Semaphore için veritabanı ve kullanıcı oluşturuluyor..."
mysql -u root -p"${MYSQL_ROOT_PASS}" <<EOF
CREATE DATABASE IF NOT EXISTS ${SEMAPHORE_DB} CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE USER IF NOT EXISTS '${SEMAPHORE_DB_USER}'@'localhost' IDENTIFIED BY '${SEMAPHORE_DB_PASS}';
GRANT ALL PRIVILEGES ON ${SEMAPHORE_DB}.* TO '${SEMAPHORE_DB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF

echo "### Son Semaphore versiyonu alınıyor..."
SEMAPHORE_VERSION=$(curl -s https://api.github.com/repos/semaphoreui/semaphore/releases/latest \
  | grep '"tag_name":' | head -1 | sed -E 's/.*"([^"]+)".*/\1/' | sed 's/^v//')
echo "[*] Yüklenecek versiyon: $SEMAPHORE_VERSION"

echo "### Semaphore indiriliyor..."
wget -q "https://github.com/semaphoreui/semaphore/releases/download/v${SEMAPHORE_VERSION}/semaphore_${SEMAPHORE_VERSION}_linux_amd64.deb" -O "/tmp/semaphore.deb"
apt install -y /tmp/semaphore.deb

echo "### Konfigürasyon klasörü ve tmp path hazırlanıyor..."
mkdir -p $(dirname ${SEMAPHORE_CONFIG})
mkdir -p ${SEMAPHORE_TMP}

echo "### Semaphore config dosyası oluşturuluyor..."
tee ${SEMAPHORE_CONFIG} > /dev/null <<EOF
{
    "mysql": {
        "host": "127.0.0.1:3306",
        "user": "${SEMAPHORE_DB_USER}",
        "pass": "${SEMAPHORE_DB_PASS}",
        "name": "${SEMAPHORE_DB}"
    },
    "dialect": "mysql",
    "tmp_path": "${SEMAPHORE_TMP}",
    "web_addr": "0.0.0.0:${SEMAPHORE_PORT}",
    "cookie_hash": "$(openssl rand -base64 32)",
    "cookie_encryption": "$(openssl rand -base64 32)",
    "access_key_encryption": "$(openssl rand -base64 32)"
}
EOF

echo "### Semaphore veritabanı migrasyonları çalıştırılıyor..."
/usr/bin/semaphore migrate --config ${SEMAPHORE_CONFIG}

echo "### Admin kullanıcı oluşturuluyor..."
/usr/bin/semaphore users add \
  --login ${SEMAPHORE_ADMIN_USER} \
  --email ${SEMAPHORE_ADMIN_EMAIL} \
  --name ${SEMAPHORE_ADMIN_USER} \
  --password "${SEMAPHORE_ADMIN_PASS}" \
  --admin \
  --config ${SEMAPHORE_CONFIG} || true

echo "### Systemd servisi oluşturuluyor..."
tee /etc/systemd/system/semaphore.service > /dev/null <<EOF
[Unit]
Description=Semaphore Ansible Web UI
After=network.target mariadb.service
Requires=mariadb.service

[Service]
Type=simple
User=root
ExecStart=/usr/bin/semaphore server --config ${SEMAPHORE_CONFIG}
Restart=always

[Install]
WantedBy=multi-user.target
EOF

echo "### Servis başlatılıyor..."
systemctl daemon-reload
systemctl enable semaphore
systemctl start semaphore

echo "### Kurulum tamamlandı!"
echo "Web arayüzü: http://<SUNUCU_IP>:${SEMAPHORE_PORT}"
echo "Admin kullanıcı: ${SEMAPHORE_ADMIN_USER} / ${SEMAPHORE_ADMIN_PASS}"
