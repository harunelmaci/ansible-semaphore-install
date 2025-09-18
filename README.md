# 🚀 Ansible + Semaphore Kurulum Scriptleri

Bu repo, **AlmaLinux 9** ve **Ubuntu 22.04/24.04** üzerinde  
**Ansible + MariaDB + Semaphore** kurulumunu tek satırda yapabilmeniz için hazırlanmıştır.  

Kurulum sırasında gerekli tüm paketler yüklenir, MariaDB yapılandırılır, Semaphore veritabanı migrasyonları uygulanır ve systemd servisi otomatik başlatılır. ✅

---

## 🔧 Kurulum

### AlmaLinux 9
```bash
bash <(curl -s https://raw.githubusercontent.com/harunelmaci/ansible-semaphore-install/main/install_semaphore_almalinux.sh)
### Ubuntu
bash <(curl -s https://raw.githubusercontent.com/harunelmaci/ansible-semaphore-install/main/install_semaphore_ubuntu.sh)
