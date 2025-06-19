#!/bin/bash

# ━━━━━━━━━━━━━━━━※❆※━━━━━━━━━━━━━━━━━
# 𓈃 Backup Script for VPN Server
# 𓈃 Developer: Fadznewbie
# ━━━━━━━━━━━━━━━━※❆※━━━━━━━━━━━━━━━━━

# Validasi auth key
valid_auth="fadznewbie_do"
auth=$(echo "$QUERY_STRING" | grep -o 'auth=[^&]*' | cut -d '=' -f2)

if [[ "$auth" != "$valid_auth" ]]; then
    echo '{"status": "error", "message": "Invalid authentication key"}'
    exit 1
fi

# Fungsi untuk response JSON
json_response() {
    echo '{"status": "'"$1"'", "message": "'"$2"'", "backup_url": "'"$3"'", "details": {"ip": "'"$4"'", "domain": "'"$5"'", "date": "'"$6"'"}}'
    exit $7
}

# Konfigurasi Telegram
if [ -f "/etc/telegram_bot/bot_token" ] && [ -f "/etc/telegram_bot/chat_id" ]; then
    BOT_TOKEN=$(cat /etc/telegram_bot/bot_token)
    CHAT_ID=$(cat /etc/telegram_bot/chat_id)
    TELEGRAM_URL="https://api.telegram.org/bot$BOT_TOKEN/sendMessage"
    TELEGRAM_ENABLED=true
else
    TELEGRAM_ENABLED=false
    echo "[WARNING] Telegram bot configuration not found" >&2
fi

# Informasi VPS
IP=$(curl -sS ipv4.icanhazip.com || echo "unknown")
domain=$(cat /etc/xray/domain 2>/dev/null || echo "unknown")
date=$(date +"%Y-%m-%d")
timestamp=$(date +"%Y-%m-%d %H:%M:%S")

# Fungsi untuk error handling
try() {
    "$@" || { 
        error_msg="Command failed: $*"
        echo "$error_msg" >&2
        
        # Kirim notifikasi error ke Telegram jika aktif
        if [ "$TELEGRAM_ENABLED" = true ]; then
            ERROR_TEXT="
⚠️ BACKUP VPS GAGAL ⚠️
━━━━━━━━━━━━━━━━━━━
🕒 Waktu: $timestamp
📌 IP: $IP
🌐 Domain: $domain
🛑 Error: $error_msg
━━━━━━━━━━━━━━━━━━━"
            curl -s --max-time 10 -d "chat_id=$CHAT_ID&text=$ERROR_TEXT&parse_mode=markdown" $TELEGRAM_URL >/dev/null
        fi
        
        json_response "error" "$error_msg" "" "$IP" "$domain" "$date" 1
    }
}

# Buat folder backup
try mkdir -p /root/backup
echo "[$(date '+%H:%M:%S')] Memulai proses backup..." >&2

# Salin file sistem
echo "[$(date '+%H:%M:%S')] Menyalin file sistem..." >&2
try cp /etc/passwd /root/backup/
try cp /etc/group /root/backup/
try cp /etc/shadow /root/backup/
try cp /etc/gshadow /root/backup/

# Salin konfigurasi VPN
echo "[$(date '+%H:%M:%S')] Menyalin konfigurasi VPN..." >&2
[ -d /etc/xray ] && try cp -r /etc/xray /root/backup/xray
[ -d /etc/kyt ] && try cp -r /etc/kyt /root/backup/kyt
[ -d /etc/vmess ] && try cp -r /etc/vmess /root/backup/vmess
[ -d /etc/vless ] && try cp -r /etc/vless /root/backup/vless
[ -d /etc/trojan ] && try cp -r /etc/trojan /root/backup/trojan
[ -d /etc/shadowsocks ] && try cp -r /etc/shadowsocks /root/backup/shadowsocks

# Kompresi backup
echo "[$(date '+%H:%M:%S')] Mengkompresi backup..." >&2
try cd /root
try zip -r "$IP-$date.zip" backup > /dev/null 2>&1

# Upload ke Google Drive
echo "[$(date '+%H:%M:%S')] Mengunggah ke Google Drive..." >&2
if ! rclone copy "/root/$IP-$date.zip" dr:backup/; then
    error_msg="Gagal mengunggah ke Google Drive"
    echo "$error_msg" >&2
    json_response "error" "$error_msg" "" "$IP" "$domain" "$date" 1
fi

# Dapatkan link download
echo "[$(date '+%H:%M:%S')] Mendapatkan link backup..." >&2
url=$(try rclone link dr:backup/"$IP-$date.zip")
id=$(echo "$url" | grep -o 'id=[^&]*' | cut -d '=' -f2)
link="https://drive.google.com/u/4/uc?id=${id}&export=download"

# Kirim notifikasi Telegram jika aktif
if [ "$TELEGRAM_ENABLED" = true ]; then
    echo "[$(date '+%H:%M:%S')] Mengirim notifikasi Telegram..." >&2
    TEXT="
✅ BACKUP VPS BERHASIL ✅
━━━━━━━━━━━━━━━━━━━
🕒 Waktu: $timestamp
📌 IP: $IP
🌐 Domain: $domain
📅 Tanggal Backup: $date
━━━━━━━━━━━━━━━━━━━
📂 LINK BACKUP:
$link
━━━━━━━━━━━━━━━━━━━
💾 Simpan link ini untuk restore data"
    
    try curl -s --max-time 10 -d "chat_id=$CHAT_ID&disable_web_page_preview=1&text=$TEXT&parse_mode=markdown" $TELEGRAM_URL >/dev/null
fi

# Hapus file lokal
echo "[$(date '+%H:%M:%S')] Membersihkan file temporary..." >&2
rm -rf /root/backup
rm -f "/root/$IP-$date.zip"

# Response sukses
echo "[$(date '+%H:%M:%S')] Backup selesai!" >&2
json_response "success" "Backup completed successfully" "$link" "$IP" "$domain" "$date" 0
