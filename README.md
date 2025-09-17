# # Ansible + Semaphore Otomatik Kurulum Scripti

Bu repo, **AlmaLinux 9** (veya RHEL/CentOS türevleri) üzerinde **Ansible + Semaphore** kurulumunu tam otomatik gerçekleştiren bir bash script içerir.  
Kurulum sırasında gerekli paketler yüklenir, MariaDB ayarlanır, Semaphore kurulup `systemd` servisi olarak başlatılır.

---

## 🚀 Kurulum

Sunucuda aşağıdaki komutu çalıştırmanız yeterlidir:

```bash
bash <(curl -s https://raw.githubusercontent.com/harunelmaci/ansible-semaphore-install/main/install_semaphorev2.sh)
