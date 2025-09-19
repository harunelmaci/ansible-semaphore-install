# Ansible + Semaphore Kurulum Scriptleri

Bu repo, **AlmaLinux 9** ve **Ubuntu 22.04/24.04** üzerinde  
**Ansible + MariaDB + Semaphore** kurulumunu tek satırda yapabilmeniz için hazırlanmıştır.  

Kurulum sırasında gerekli tüm paketler yüklenir, MariaDB yapılandırılır, Semaphore veritabanı migrasyonları uygulanır ve systemd servisi otomatik başlatılır.
Ayrıca **Python `passlib` kütüphanesi** otomatik yüklenir; bu sayede Ansible ile parola hashleme sorunsuz çalışır.  


## Gereksinimler

- Desteklenen işletim sistemleri:
  - AlmaLinux 9
  - Ubuntu 22.04 / 24.04
- Sunucuda **root** yetkisine sahip olmalısınız.
- İnternet erişimi olmalı (GitHub’dan paketler indiriliyor).
- 3000 portu boş olmalı (Semaphore bu portu dinler).
- Kurulum sırasında admin email adresi girilmelidir (boş bırakılamaz).

## Kurulum

 AlmaLinux 9
 
bash <(curl -s https://raw.githubusercontent.com/harunelmaci/ansible-semaphore-install/main/install_semaphore_almalinux.sh)

Ubuntu Linux

bash <(curl -s https://raw.githubusercontent.com/harunelmaci/ansible-semaphore-install/main/install_semaphore_ubuntu.sh)
