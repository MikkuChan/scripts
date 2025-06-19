#!/bin/bash
# ━━━━━━━━━━━━━━━━※❆※━━━━━━━━━━━━━━━━━
# 𓈃 Script Restore VPS via HTTP GET
# ━━━━━━━━━━━━━━━━※❆※━━━━━━━━━━━━━━━━━

# Warna ANSI untuk terminal
RED='\033[1;91m'
GREEN='\033[1;92m'
YELLOW='\033[1;93m'
BLUE='\033[1;94m'
CYAN='\033[1;96m'
NC='\033[0m' # Reset warna

# Fungsi untuk response JSON
json_response() {
    echo -e "Content-Type: application/json\r\n"
    echo "$1"
    exit $2
}

# Fungsi decode URL parameter
urldecode() {
    local url_encoded="${1//+/ }"
    printf '%b' "${url_encoded//%/\\x}"
}

# Validasi jika dipanggil via HTTP GET
if [ "$REQUEST_METHOD" = "GET" ]; then
    # Parsing parameter URL
    IFS='&' read -ra PARAMS <<< "$QUERY_STRING"
    
    declare -A param_map
    for param in "${PARAMS[@]}"; do
        IFS='=' read -r key value <<< "$param"
        param_map["$key"]=$(urldecode "$value")
    done
    
    # Validasi parameter wajib
    if [ -z "${param_map[action]}" ] || [ -z "${param_map[linkbackup]}" ] || [ -z "${param_map[auth]}" ]; then
        json_response '{"status": "error", "message": "Missing required parameters (action, linkbackup, auth)"}' 1
    fi
    
    # Validasi auth key
    if [[ "${param_map[auth]}" != "fadznewbie_do" ]]; then
        json_response '{"status": "error", "message": "Invalid authentication key"}' 1
    fi
    
    # Validasi action
    if [[ "${param_map[action]}" != "restore" ]]; then
        json_response '{"status": "error", "message": "Invalid action"}' 1
    fi
    
    # Validasi format linkbackup
    if [[ ! "${param_map[linkbackup]}" =~ ^https?:// ]]; then
        json_response '{"status": "error", "message": "Invalid backup link format (must start with http:// or https://)"}' 1
    fi
    
    # Set variabel
    url="${param_map[linkbackup]}"
fi

# Konfigurasi Telegram Bot
BOT_TOKEN=$(cat /etc/telegram_bot/bot_token 2>/dev/null | tr -d '\n')
CHAT_ID=$(cat /etc/telegram_bot/chat_id 2>/dev/null | tr -d '\n')
export TIME="10"
export URL="https://api.telegram.org/bot$BOT_TOKEN/sendMessage"

# Fungsi Notifikasi ke Telegram
function notif_restore() {
    [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ] && {
        echo -e "${RED}ⓘ Notifikasi Telegram dilewati: Token atau Chat ID tidak ditemukan${NC}" >&2
        return
    }
    
    sleep 2
    TEXT="
━━━━━━━━━━※❆※━━━━━━━━━━
𓈃 RESTORE VPS BERHASIL 𓈃
━━━━━━━━━━※❆※━━━━━━━━━━
✅ Restore VPS Sukses!
📌 VPS telah dikembalikan seperti semula.
━━━━━━━━━━※❆※━━━━━━━━━━
"
    curl_response=$(curl -s --max-time $TIME -d "chat_id=$CHAT_ID&disable_web_page_preview=1&text=$TEXT&parse_mode=html" "$URL" 2>&1)
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}ⓘ Gagal mengirim notifikasi Telegram:${NC} $curl_response" >&2
    else
        echo -e "${GREEN}✓ Notifikasi Telegram terkirim${NC}" >&2
    fi
}

# Fungsi progress bar
step=1
progress() {
    bar="■□□□□□□□□□"
    case $step in
        1) bar="■□□□□□□□□□" ;;
        2) bar="■■■■□□□□□□" ;;
        3) bar="■■■■■■■■□□" ;;
        4) bar="■■■■■■■■■■" ;;
    esac
    echo -ne "\r📂 ${GREEN}$1${NC}   [$bar] $2%"
    step=$((step+1))
    sleep 2
}

# Main Process
if [ "$REQUEST_METHOD" = "GET" ]; then
    echo -e "Content-Type: text/html\r\n"
    echo -e "<pre>"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━※❆※━━━━━━━━━━━━━━━━${NC}"
    echo -e "🔄 ${CYAN}MEMULAI PROSES RESTORE...${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━※❆※━━━━━━━━━━━━━━━━${NC}"
    
    # Debug info
    echo -e "${BLUE}ℹ Info Konfigurasi Bot:${NC}"
    echo -e "Token: ${BOT_TOKEN:0:4}...${BOT_TOKEN: -4}"
    echo -e "Chat ID: $CHAT_ID"
    echo
fi

# Cleanup previous files
rm -f /root/backup.zip
rm -rf /root/backup

progress "Mengunduh file backup" 10
if ! wget -O /root/backup.zip "$url"; then
    json_response '{"status": "error", "message": "Failed to download backup file"}' 1
fi

progress "Mengekstrak file backup" 40
if ! unzip -o /root/backup.zip -d /root/; then
    json_response '{"status": "error", "message": "Failed to extract backup file"}' 1
fi

# Cek direktori backup
if [ ! -d "/root/backup" ]; then
    # Coba cari direktori backup di hasil ekstrak
    extracted_dir=$(find /root -type d -name "backup" | head -n 1)
    if [ -z "$extracted_dir" ]; then
        json_response '{"status": "error", "message": "Backup directory not found in extracted files"}' 1
    else
        mv "$extracted_dir" /root/backup
    fi
fi

progress "Memulihkan konfigurasi VPS" 80
cd /root/backup || {
    json_response '{"status": "error", "message": "Could not access backup directory"}' 1
}

# Restore files
cp -f passwd /etc/ 2>/dev/null
cp -f group /etc/ 2>/dev/null
cp -f shadow /etc/ 2>/dev/null
cp -f gshadow /etc/ 2>/dev/null
cp -f crontab /etc/ 2>/dev/null

# Restore directories
[ -d kyt ] && cp -r kyt /etc/ 2>/dev/null
[ -d xray ] && cp -r xray /etc/ 2>/dev/null
[ -d vmess ] && cp -r vmess /etc/ 2>/dev/null
[ -d vless ] && cp -r vless /etc/ 2>/dev/null
[ -d trojan ] && cp -r trojan /etc/ 2>/dev/null
[ -d shodowshocks ] && cp -r shodowshocks /etc/ 2>/dev/null
[ -d html ] && cp -r html /var/www/ 2>/dev/null

progress "Finalisasi proses restore" 100
notif_restore

# Cleanup
rm -f /root/backup.zip
rm -rf /root/backup

if [ "$REQUEST_METHOD" = "GET" ]; then
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━※❆※━━━━━━━━━━━━━━━━${NC}"
    echo -e "✅ ${GREEN}RESTORE VPS SELESAI${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━※❆※━━━━━━━━━━━━━━━━${NC}"
    echo -e "🔄 ${CYAN}VPS telah dikembalikan seperti semula.${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━※❆※━━━━━━━━━━━━━━━━${NC}"
    echo -e "</pre>"
fi

json_response '{"status": "success", "message": "VPS restore completed successfully"}' 0
