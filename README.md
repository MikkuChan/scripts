# VPN API Scripts

Repositori ini berisi kumpulan skrip bash dan service kecil Node.js untuk mengelola akun VPN (VMess, VLess, Trojan, dan SSH) secara otomatis melalui HTTP API.

## Fitur

- Membuat & memperpanjang akun VPN via HTTP
- Menghapus akun & cek user aktif
- Backup & restore konfigurasi server
- Respons JSON, cocok untuk otomasi

## Persyaratan

- Sistem Debian/Ubuntu
- Hak akses root (sudo)
- Koneksi internet

## Instalasi Sekali Klik

Jalankan perintah di bawah ini pada terminal (sebagai root/sudo):

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/MikkuChan/scripts/main/install.sh)
```

Perintah di atas akan:
- Mengunduh seluruh file penting dari repo ini secara otomatis.
- Menginstal semua dependensi.
- Membuat service systemd dan langsung menjalankan service VPN API.

Setelah instalasi, service akan otomatis berjalan. Cek status dengan:

```bash
systemctl status vpn-api
```

API berjalan pada port `5888` secara default.

## Contoh Penggunaan

Contoh membuat akun VMess:

```bash
curl "http://localhost:5888/createvmess?user=test&exp=30&quota=10&iplimit=1&auth=kuncirahasia"
```

Setiap endpoint membutuhkan parameter `auth` dengan kunci yang sesuai. Lihat file `vpn-api.js` untuk daftar endpoint dan parameter lengkap.

## Update

Jika ada perubahan pada skrip atau aplikasi, jalankan ulang perintah instalasi atau deploy ulang ke `/opt/vpn-api` lalu restart service:

```bash
sudo systemctl restart vpn-api
```

## Disclaimer

Gunakan skrip ini dengan risiko Anda sendiri. Semua kode disediakan sebagaimana adanya tanpa jaminan apapun. Pastikan meninjau kode sebelum digunakan di server produksi.
