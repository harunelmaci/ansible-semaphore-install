#!/bin/bash

set -e

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

# 3. MariaDB kurulumu ve servisi başlat
echo "MariaDB kuruluyor..."
dnf install -y mariadb-server
systemctl enable --now mariadb

# 4. MariaDB güvenlik ve DB oluşturma
echo "MariaDB güvenlik ayarları ve Semaphore DB oluşturuluyor..."
mysql -u root <<EOF
CREATE DATABASE IF NOT EXISTS semaphore CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE USER IF NOT EXISTS '$SEMAPHORE_DB_USER'@'localhost' IDENTIFIED BY '$SEMAPHORE_DB_PASS';
GRANT ALL PRIVILEGES ON semaphore.* TO '$SEMAPHORE_DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF

# 5. Semaphore kurulumu
echo "Semaphore kuruluyor..."
VER=$(curl -s https://api.github.com/repos/semaphoreui/semaphore/releases/latest \
  | grep '"tag_name":' | head -1 | sed -E 's/.*"([^"]+)".*/\1/' | sed 's/^v//')

wget -q "https://github.com/semaphoreui/semaphore/releases/download/v${VER}/semaphore_${VER}_linux_amd64.rpm"
dnf install -y "semaphore_${VER}_linux_amd64.rpm"

# 6. Semaphore konfig dosyası oluştur
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

# 7. Semaphore setup
/usr/bin/semaphore setup --config /etc/semaphore/config.json <<EOF
1
/var/lib/semaphore
$SEMAPHORE_ADMIN_EMAIL
$SEMAPHORE_ADMIN_USER
$SEMAPHORE_ADMIN_PASS
EOF

# 8. Semaphore server başlat
nohup /usr/bin/semaphore server --config /etc/semaphore/config.json > /var/log/semaphore.log 2>&1 &

echo "Kurulum tamamlandı! Web arayüzüne http://<sunucu_ip>:3000 üzerinden erişebilirsiniz."
#!/bin/bash
# AlmaLinux 9 üzerinde Ansible + MariaDB + Semaphore (2.16.19) kurulumu ve systemd servisi

set -e

# --------------- Ayarlar ----------------
MYSQL_ROOT_PASS="susamuru"
SEMAPHORE_DB="semaphore"
SEMAPHORE_DB_USER="semaphore"
SEMAPHORE_DB_PASS="Sem4ph0re!123"
SEMAPHORE_ADMIN_USER="admin"
SEMAPHORE_ADMIN_EMAIL="harun.elmaci@sans-technology.com"
SEMAPHORE_ADMIN_PASS="AdminPass!123"
SEMAPHORE_VERSION="2.16.19"
SEMAPHORE_INSTALL_DIR="/usr/bin"
SEMAPHORE_CONFIG="/etc/semaphore/config.json"
SEMAPHORE_TMP="/var/lib/semaphore"
SEMAPHORE_PORT=3000
# -----------------------------------------

echo "### Sistem güncelleniyor..."
sudo dnf update -y
sudo dnf install -y wget curl git epel-release

echo "### Ansible kuruluyor..."
sudo dnf install -y ansible

echo "### MariaDB kuruluyor..."
sudo dnf install -y mariadb-server
sudo systemctl enable --now mariadb

echo "### MariaDB root güvenliği..."
sudo mysql -u root <<EOF || true
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASS}';
DELETE FROM mysql.user WHERE User='';
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%';
FLUSH PRIVILEGES;
EOF

echo "### Semaphore için veritabanı ve kullanıcı oluşturuluyor..."
sudo mysql -u root -p"${MYSQL_ROOT_PASS}" <<EOF
CREATE DATABASE IF NOT EXISTS ${SEMAPHORE_DB} CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE USER IF NOT EXISTS '${SEMAPHORE_DB_USER}'@'localhost' IDENTIFIED BY '${SEMAPHORE_DB_PASS}';
GRANT ALL PRIVILEGES ON ${SEMAPHORE_DB}.* TO '${SEMAPHORE_DB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF

echo "### Semaphore indiriliyor..."
wget "https://github.com/semaphoreui/semaphore/releases/download/v${SEMAPHORE_VERSION}/semaphore_${SEMAPHORE_VERSION}_linux_386.rpm" -O "/tmp/semaphore.rpm"
sudo dnf install -y /tmp/semaphore.rpm

echo "### Konfigürasyon klasörü ve tmp path hazırlanıyor..."
sudo mkdir -p $(dirname ${SEMAPHORE_CONFIG})
sudo mkdir -p ${SEMAPHORE_TMP}

echo "### Semaphore config dosyası oluşturuluyor..."
sudo tee ${SEMAPHORE_CONFIG} > /dev/null <<EOF
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
    "cookie_hash": "EaHj/2ncW2oLSX34WdC+Wi7cAnWHRvFMgXTVQaoPoNE=",
    "cookie_encryption": "Xs0vvooNkY7wgW9AP7Lqj4zya3aUeFwrvpcRLytO+eI=",
    "access_key_encryption": "+cfMwpdOKUKFT/7XPkvTu47wxcLKB0QMqLl7xO89GhM="
}
EOF

echo "### Semaphore veritabanı migrasyonları çalıştırılıyor..."
sudo /usr/bin/semaphore migrate --config ${SEMAPHORE_CONFIG}

echo "### Admin kullanıcı oluşturuluyor..."
sudo /usr/bin/semaphore users add \
  --login ${SEMAPHORE_ADMIN_USER} \
  --email ${SEMAPHORE_ADMIN_EMAIL} \
  --name ${SEMAPHORE_ADMIN_USER} \
  --password "${SEMAPHORE_ADMIN_PASS}" \
  --admin \
  --config ${SEMAPHORE_CONFIG} || true

echo "### Systemd servisi oluşturuluyor..."
sudo tee /etc/systemd/system/semaphore.service > /dev/null <<EOF
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
sudo systemctl daemon-reload
sudo systemctl enable semaphore
sudo systemctl start semaphore

echo "### Kurulum tamamlandı!"
echo "Web arayüzüne http://SUNUCU_IP:${SEMAPHORE_PORT} üzerinden erişebilirsiniz."
echo "Admin kullanıcı: ${SEMAPHORE_ADMIN_USER} / ${SEMAPHORE_ADMIN_PASS}"
