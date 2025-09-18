# 🚀 Ansible + Semaphore Kurulum Scripti (AlmaLinux 9)

Bu repo, **AlmaLinux 9** üzerinde **Ansible + MariaDB + Semaphore** kurulumunu tek satırda yapabilmeniz için hazırlanmıştır.  
Kurulum sırasında gerekli tüm paketler yüklenir, MariaDB yapılandırılır, Semaphore veritabanı migrasyonları uygulanır ve systemd servisi otomatik başlatılır. ✅

---

## 🔧 Kurulum

Aşağıdaki komutu çalıştırmanız yeterlidir:

```bash
bash <(curl -s https://raw.githubusercontent.com/harunelmaci/ansible-semaphore-install/main/install_semaphorev2.sh)
