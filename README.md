# Skrip API VPN

Repositori ini berisi kumpulan skrip bash dan layanan Node.js kecil untuk mengelola akun VPN (VMess, VLess, Trojan, dan SSH). API menampilkan antarmuka HTTP sederhana untuk menjalankan skrip-skrip tersebut.

## Fitur

- Membuat dan memperpanjang akun VPN melalui permintaan HTTP
- Menghapus akun serta memeriksa pengguna aktif
- Mencadangkan dan memulihkan konfigurasi server
- Respons JSON yang cocok untuk otomatisasi

## Persyaratan

- Sistem berbasis Debian/Ubuntu
- Hak akses root saat instalasi
- Koneksi internet untuk mengunduh dependensi

## Instalasi

Jalankan skrip `install.sh` dengan hak root. Skrip akan memasang Node.js, menyalin skrip ke `/opt/vpn-api`, memasang dependensi Node, dan membuat service systemd bernama `vpn-api` dengan output berwarna.

Untuk instalasi satu baris, jalankan perintah berikut:

```bash
curl -fsSL https://raw.githubusercontent.com/MikkuChan/scripts/refs/heads/main/install.sh?token=GHSAT0AAAAAAC4XSAYFV3XQW55PORB3K2NI2CT4QJQ | sudo bash
```

Setelah instalasi selesai, service akan langsung berjalan. Anda dapat memeriksa statusnya dengan:

```bash
systemctl status vpn-api
```

API berjalan pada port `5888` secara default.

## Penggunaan

Contoh membuat akun VMess:

```bash
curl "http://localhost:5888/createvmess?user=test&exp=30&quota=10&iplimit=1&auth=fadznewbie_do"
```

Setiap endpoint memerlukan parameter `auth` dengan kunci yang benar. Lihat `vpn-api.js` untuk daftar endpoint dan parameter lengkap.

## Pembaruan

Jika Anda melakukan perubahan pada skrip ataupun aplikasi Node.js, salin kembali ke `/opt/vpn-api` dan restart service:

```bash
sudo systemctl restart vpn-api
```

## Penafian

Gunakan skrip-skrip ini dengan risiko Anda sendiri. Disediakan apa adanya tanpa jaminan apa pun. Periksa kode sebelum menjalankan di lingkungan produksi.
