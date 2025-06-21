# 🚀 VPN API Scripts - FadzDigital

[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Node.js](https://img.shields.io/badge/Node.js-18%2B-green.svg)](https://nodejs.org/)
[![PM2](https://img.shields.io/badge/PM2-Supported-orange.svg)](https://pm2.keymetrics.io/)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-20.04%2B-purple.svg)](https://ubuntu.com/)

Repositori ini berisi kumpulan skrip bash dan service Node.js yang canggih untuk mengelola akun VPN (VMess, VLess, Trojan, dan SSH) secara otomatis melalui HTTP API. Dirancang khusus untuk kemudahan pengelolaan server VPN dengan sistem yang stabil dan performa tinggi.

---

## ✨ Fitur Unggulan

### 🔧 **Manajemen VPN Lengkap**
- ✅ Membuat & memperpanjang akun VPN via HTTP API
- ✅ Menghapus akun & monitoring user aktif real-time
- ✅ Backup & restore konfigurasi server otomatis
- ✅ Sistem kuota dan limit IP yang fleksibel

### 🌐 **Protokol VPN yang Didukung**
- **VMess** - Protocol modern dengan enkripsi tinggi
- **VLess** - Protocol ringan dan cepat
- **Trojan** - Protocol stealth untuk bypass DPI
- **SSH** - Protocol klasik yang reliable

### 🚀 **Teknologi Modern**
- **PM2** - Process manager untuk stabilitas maksimal
- **Node.js** - Runtime JavaScript yang cepat
- **JSON API** - Response format standar untuk integrasi
- **Auto-restart** - Service otomatis restart jika terjadi error

---

## 📋 Persyaratan Sistem

| Komponen | Requirement |
|----------|-------------|
| **OS** | Ubuntu 20.04+ / Debian 10+ |
| **RAM** | Minimal 1GB (Recommended 2GB+) |
| **Storage** | Minimal 10GB free space |
| **Network** | Koneksi internet stabil |
| **Access** | Root privileges (sudo) |

---

## 🚀 Instalasi Sekali Klik

### **Metode Cepat (Recommended)**

Jalankan perintah berikut pada terminal sebagai **root** atau dengan **sudo**:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/MikkuChan/scripts/main/install.sh)
```

### **Apa yang Dilakukan Script Instalasi:**

🔄 **Proses Otomatis:**
1. ✅ **Pemeriksaan Sistem** - Validasi OS dan dependencies
2. ✅ **Download Files** - Mengunduh semua file dari repository
3. ✅ **Install Dependencies** - Node.js, NPM, PM2, dan tools lainnya
4. ✅ **Setup Environment** - Konfigurasi direktori dan permissions
5. ✅ **Service Configuration** - Setup PM2 process manager
6. ✅ **Auto-Start Setup** - Konfigurasi startup otomatis

📁 **Struktur Instalasi:**
```
/opt/vpn-api/
├── scripts/
│   ├── vpn-api.js          # Main API service
│   ├── package.json        # Node.js dependencies
│   ├── .env               # Environment variables (AUTHKEY)
│   └── *.sh              # VPN management scripts
└── logs/                  # Application logs
```

---

## 🎛️ Manajemen Service dengan PM2

PM2 adalah process manager modern yang memberikan stabilitas dan monitoring yang superior dibanding systemd untuk aplikasi Node.js.

### **Perintah Dasar PM2**

| Aksi | Perintah | Deskripsi |
|------|----------|-----------|
| **Status** | `pm2 status vpn-api` | Cek status aplikasi |
| **Start** | `pm2 start vpn-api` | Menjalankan service |
| **Stop** | `pm2 stop vpn-api` | Menghentikan service |
| **Restart** | `pm2 restart vpn-api` | Restart service |
| **Logs** | `pm2 logs vpn-api` | Melihat log real-time |
| **Monitor** | `pm2 monit` | Dashboard monitoring |

### **Perintah Advanced PM2**

```bash
# Melihat informasi detail aplikasi
pm2 show vpn-api

# Melihat log dengan filter
pm2 logs vpn-api --lines 100

# Flush semua logs
pm2 flush

# Reload aplikasi tanpa downtime
pm2 reload vpn-api

# Save konfigurasi PM2
pm2 save

# Setup startup script (auto-start saat boot)
pm2 startup
```

---

## 🔧 Konfigurasi dan Environment

### **File Konfigurasi Utama**

**📄 `/opt/vpn-api/scripts/.env`**
```env
AUTHKEY=kunci_rahasia_anda
PORT=5888
NODE_ENV=production
```

### **Mengubah Konfigurasi**

```bash
# Edit file environment
nano /opt/vpn-api/scripts/.env

# Restart service setelah perubahan
pm2 restart vpn-api
```

---

## 🌐 API Endpoints dan Contoh Penggunaan

### **Base URL**
```
http://localhost:5888
```

### **Format Request**
Semua endpoint membutuhkan parameter `auth` dengan AUTHKEY yang valid.

### **Contoh Penggunaan API**

#### **1. Membuat Akun VMess**
```bash
curl "http://localhost:5888/createvmess?user=testuser&exp=30&quota=10&iplimit=2&auth=kunci_rahasia_anda"
```

#### **2. Membuat Akun VLess**
```bash
curl "http://localhost:5888/createvless?user=testuser&exp=30&quota=10&iplimit=2&auth=kunci_rahasia_anda"
```

#### **3. Membuat Akun Trojan**
```bash
curl "http://localhost:5888/createtrojan?user=testuser&exp=30&quota=10&iplimit=2&auth=kunci_rahasia_anda"
```

#### **4. Cek User Aktif**
```bash
curl "http://localhost:5888/checkuser?user=testuser&auth=kunci_rahasia_anda"
```

#### **5. Hapus User**
```bash
curl "http://localhost:5888/deleteuser?user=testuser&protocol=vmess&auth=kunci_rahasia_anda"
```

### **Parameter yang Tersedia**

| Parameter | Tipe | Deskripsi | Required |
|-----------|------|-----------|----------|
| `user` | string | Username untuk akun VPN | ✅ |
| `exp` | integer | Masa berlaku dalam hari | ✅ |
| `quota` | integer | Kuota data dalam GB | ✅ |
| `iplimit` | integer | Batas jumlah IP concurrent | ✅ |
| `auth` | string | Authentication key | ✅ |
| `protocol` | string | Protokol VPN (vmess/vless/trojan) | Untuk delete |

---

## 🔍 Monitoring dan Troubleshooting

### **Monitoring Real-time**

```bash
# Dashboard monitoring PM2
pm2 monit

# Cek resource usage
pm2 status

# Monitor logs secara real-time
pm2 logs vpn-api --follow
```

### **Health Check**

```bash
# Test API endpoint
curl "http://localhost:5888/health?auth=kunci_rahasia_anda"

# Cek port yang listening
netstat -tlnp | grep 5888

# Cek process PM2
pm2 list
```

### **Troubleshooting Common Issues**

#### **Problem: Service tidak bisa start**
```bash
# Cek error logs
pm2 logs vpn-api --err

# Restart dengan debug mode
NODE_ENV=development pm2 restart vpn-api
```

#### **Problem: API tidak response**
```bash
# Cek apakah port 5888 terbuka
sudo ufw allow 5888

# Test koneksi local
curl http://localhost:5888/health
```

#### **Problem: Permission denied**
```bash
# Fix ownership direktori
sudo chown -R root:root /opt/vpn-api

# Fix permissions
sudo chmod -R 755 /opt/vpn-api
sudo chmod 600 /opt/vpn-api/scripts/.env
```

---

## 🔄 Update dan Maintenance

### **Update Script**

```bash
# Download script instalasi terbaru
curl -fsSL https://raw.githubusercontent.com/MikkuChan/scripts/main/install.sh -o install.sh

# Jalankan instalasi (akan update existing installation)
bash install.sh
```

### **Backup Konfigurasi**

```bash
# Backup direktori instalasi
tar -czf vpn-api-backup-$(date +%Y%m%d).tar.gz /opt/vpn-api

# Backup hanya konfigurasi
cp /opt/vpn-api/scripts/.env ~/vpn-api-env-backup
```

### **Restore Konfigurasi**

```bash
# Restore dari backup
tar -xzf vpn-api-backup-YYYYMMDD.tar.gz -C /

# Restart service
pm2 restart vpn-api
```

---

## 📊 Performance dan Optimasi

### **Optimasi PM2**

```bash
# Jalankan dalam cluster mode (gunakan semua CPU cores)
pm2 start vpn-api.js --name vpn-api -i max

# Set memory limit
pm2 start vpn-api.js --name vpn-api --max-memory-restart 500M

# Auto restart berdasarkan file changes
pm2 start vpn-api.js --name vpn-api --watch
```

### **Monitoring Resource**

```bash
# Resource usage summary
pm2 monit

# Detailed process info
pm2 show vpn-api

# System resource usage
htop
```

---

## 🛡️ Security Best Practices

### **1. Firewall Configuration**

```bash
# Allow hanya port yang diperlukan
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 5888/tcp  # VPN API
sudo ufw enable
```

### **2. Strong Authentication**

- Gunakan AUTHKEY yang kuat (minimal 32 karakter)
- Ganti AUTHKEY secara berkala
- Jangan share AUTHKEY di public

### **3. Regular Updates**

```bash
# Update sistem
sudo apt update && sudo apt upgrade -y

# Update PM2
npm install -g pm2@latest

# Update Node.js (menggunakan NodeSource)
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt-get install -y nodejs
```

---

## 📚 Advanced Configuration

### **Custom Environment Variables**

Edit `/opt/vpn-api/scripts/.env`:

```env
# API Configuration
AUTHKEY=your_super_secret_key_here
PORT=5888
NODE_ENV=production

# Database Configuration (jika diperlukan)
DB_HOST=localhost
DB_PORT=3306
DB_USER=vpnapi
DB_PASS=secure_password

# Logging Configuration
LOG_LEVEL=info
LOG_FILE=/var/log/vpn-api/app.log

# Rate Limiting
RATE_LIMIT_WINDOW=15
RATE_LIMIT_MAX=100
```

### **Custom PM2 Ecosystem File**

Buat file `ecosystem.config.js`:

```javascript
module.exports = {
  apps: [{
    name: 'vpn-api',
    script: '/opt/vpn-api/scripts/vpn-api.js',
    cwd: '/opt/vpn-api/scripts',
    instances: 'max',
    exec_mode: 'cluster',
    max_memory_restart: '500M',
    env: {
      NODE_ENV: 'production',
      PORT: 5888
    },
    env_development: {
      NODE_ENV: 'development',
      PORT: 5888
    }
  }]
};
```

---

## 🤝 Kontribusi dan Support

### **Cara Berkontribusi**

1. Fork repository ini
2. Buat branch fitur baru (`git checkout -b feature/wow-feature`)
3. Commit perubahan (`git commit -m 'Add wow feature'`)
4. Push ke branch (`git push origin feature/wow-feature`)
5. Buat Pull Request

### **Laporkan Bug**

Jika menemukan bug atau masalah:

1. Cek [Issues](https://github.com/MikkuChan/scripts/issues) yang sudah ada
2. Buat issue baru dengan detail lengkap
3. Sertakan log error dan langkah reproduksi

### **Support**

- 📧 **Email**: support@fadzdigital.com
- 💬 **Telegram**: [@FadzDigital](https://t.me/fadzdigital)
- 🌐 **Website**: [vpntech.my.id](https://vpntech.my.id)

---

## ⚠️ Disclaimer

⚠️ **PENTING**: Gunakan skrip ini dengan risiko Anda sendiri. Semua kode disediakan "sebagaimana adanya" tanpa jaminan apapun. 

### **Rekomendasi Keamanan:**

- ✅ **Selalu review kode** sebelum digunakan di server produksi
- ✅ **Backup data** secara berkala
- ✅ **Monitor aktivitas** sistem secara rutin
- ✅ **Update security patches** secara teratur
- ✅ **Gunakan firewall** dan security measures lainnya

### **Batasan Tanggung Jawab:**

Pengembang tidak bertanggung jawab atas:
- Kerusakan sistem atau kehilangan data
- Pelanggaran kebijakan hosting provider
- Masalah legal terkait penggunaan VPN
- Downtime atau masalah performa

---

## 📄 Lisensi

Proyek ini dilisensikan di bawah [MIT License](LICENSE) - lihat file LICENSE untuk detail lengkap.

---

## 🙏 Acknowledgments

Terima kasih kepada:
- **Node.js Community** untuk runtime yang luar biasa
- **PM2 Team** untuk process manager yang reliable
- **Ubuntu/Debian** untuk platform yang stabil
- **Open Source Community** untuk inspirasi dan kontribusi

---

<div align="center">

**🧐 Jika proyek ini membantu Anda, berikan ⭐ di GitHub! 🌟**

---

**Dibuat oleh [FadzDigital](https://t.me/fadzdigital)**

*Premium VPN Management System - Powered by MikkuChan*

</div>
