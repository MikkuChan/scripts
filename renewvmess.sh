#!/bin/bash
# ━━━━━━━━━━━━━━━━※❆※━━━━━━━━━━━━━━━━━
# 𓈃 System Request ➠ Debian 9+/Ubuntu 18.04+/20+
# 𓈃 Developer ➠ MikkuChan
# 𓈃 Email      ➠ fadztechs2@gmail.com
# 𓈃 Telegram   ➠ https://t.me/fadzdigital
# ━━━━━━━━━━━━━━━━※❆※━━━━━━━━━━━━━━━━━

# Warna untuk output terminal
red='\e[1;31m'
green='\e[0;32m'
yellow='\e[0;33m'
NC='\e[0m'
BGWHITE='\e[0;100;37m'

green() { echo -e "\\033[32;1m${*}\\033[0m"; }
red() { echo -e "\\033[31;1m${*}\\033[0m"; }

# Fungsi untuk menampilkan output JSON
output_json() {
    echo -e "Content-Type: application/json\n"
    echo -e "{
        \"status\": \"$1\",
        \"message\": \"$2\",
        \"data\": {
            \"client_name\": \"$3\",
            \"uuid\": \"$4\",
            \"service_name\": \"$5\",
            \"server_name\": \"$6\",
            \"expired_on\": \"$7\"
        }
    }"
    exit $8
}

# Fungsi untuk mengirim notifikasi ke Telegram
send_telegram() {
    BOT_TOKEN=$(cat /etc/telegram_bot/bot_token 2>/dev/null)
    CHAT_ID=$(cat /etc/telegram_bot/chat_id 2>/dev/null)
    
    if [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ]; then
        return 0  # Skip jika tidak ada konfigurasi Telegram
    fi
    
    URL="https://api.telegram.org/bot$BOT_TOKEN/sendMessage"
    TEXT="
╔════════════════════════
║ <b>RENEW VMESS BERHASIL</b>
╠════════════════════════
║ • <b>User:</b> <code>$1</code>
║ • <b>Uuid:</b> <code>$2</code>
║ • <b>Service:</b> <code>$3</code>
║ • <b>Domain:</b> <code>$4</code>
║ • <b>Expired:</b> <code>$5</code>
║ • <b>Dibuat pada:</b> <code>$(date +"%d-%m-%Y %H:%M:%S")</code>
╚════════════════════════"
    curl -s --max-time 10 -d "chat_id=$CHAT_ID&disable_web_page_preview=1&text=$TEXT&parse_mode=html" $URL >/dev/null
}

# Cek jika dipanggil via HTTP GET
if [ "$REQUEST_METHOD" = "GET" ]; then
    # Ambil parameter dari query string
    user=$(echo "$QUERY_STRING" | sed -n 's/^.*user=\([^&]*\).*$/\1/p')
    masaaktif=$(echo "$QUERY_STRING" | sed -n 's/^.*masaaktif=\([^&]*\).*$/\1/p')
    Quota=$(echo "$QUERY_STRING" | sed -n 's/^.*quota=\([^&]*\).*$/\1/p')
    iplim=$(echo "$QUERY_STRING" | sed -n 's/^.*iplim=\([^&]*\).*$/\1/p')
    
    # Mode HTTP GET tidak memerlukan interaksi user
    interactive_mode=false
else
    # Mode interaktif (terminal)
    interactive_mode=true
    
    # Bersihkan layar
    clear
    
    # Hitung jumlah client
    NUMBER_OF_CLIENTS=$(grep -c -E "^### " "/etc/xray/config.json")
    if [[ ${NUMBER_OF_CLIENTS} == '0' ]]; then
        clear
        echo -e "\033[0;33m━━━━━━━━━━━━━━━━※❆※━━━━━━━━━━━━━━━━\033[0m"
        echo -e "${BGWHITE}      🚫 NO CLIENT FOUND                                        \E[0m"
        echo -e "\033[0;33m━━━━━━━━━━━━━━━━※❆※━━━━━━━━━━━━━━━━\033[0m"
        echo ""
        echo "Tidak ada client VMess yang tersedia."
        echo ""
        echo -e "\033[0;33m━━━━━━━━━━━━━━━━※❆※━━━━━━━━━━━━━━━━\033[0m"
        read -p "Tekan ENTER untuk kembali..."
        m-vmess
        exit 1
    fi

    # Menampilkan daftar client
    clear
    echo -e "\033[0;33m━━━━━━━━━━━━━━━━※❆※━━━━━━━━━━━━━━━━\033[0m"
    echo -e "${BGWHITE}        🔄 RENEW VMESS        \E[0m"
    echo -e "\033[0;33m━━━━━━━━━━━━━━━━※❆※━━━━━━━━━━━━━━━━\033[0m"
    echo ""
    grep -E "^### " "/etc/xray/config.json" | cut -d ' ' -f 2-3 | column -t | sort | uniq
    echo ""
    echo -e "\033[0;33m━━━━━━━━━━━━━━━━※❆※━━━━━━━━━━━━━━━━\033[0m"
    read -rp "➠ Masukkan Username : " user
fi

# Verifikasi apakah username ada
if ! grep -qw "$user" "/etc/xray/config.json"; then
    if [ "$interactive_mode" = true ]; then
        clear
        echo -e "\033[0;33m━━━━━━━━━━━━━━━━※❆※━━━━━━━━━━━━━━━━\033[0m"
        echo -e "${BGWHITE}      🚫 USER TIDAK DITEMUKAN   \E[0m"
        echo -e "\033[0;33m━━━━━━━━━━━━━━━━※❆※━━━━━━━━━━━━━━━━\033[0m"
        echo ""
        echo "Username yang dimasukkan tidak ditemukan."
        echo -e "\033[0;33m━━━━━━━━━━━━━━━━※❆※━━━━━━━━━━━━━━━━\033[0m"
        read -p "Tekan ENTER untuk kembali..."
        m-vmess
        exit 1
    else
        output_json "error" "Username tidak ditemukan" "" "" "" "" "" 1
    fi
fi

# Input durasi (jika tidak ada dari HTTP GET)
if [ -z "$masaaktif" ]; then
    if [ "$interactive_mode" = true ]; then
        read -rp "➠ Masa Aktif (Hari) : " masaaktif
    else
        output_json "error" "Parameter masaaktif diperlukan" "" "" "" "" "" 1
    fi
fi

# Validasi masa aktif
if ! [[ "$masaaktif" =~ ^[0-9]+$ ]]; then
    if [ "$interactive_mode" = true ]; then
        red "[ERROR] Masa aktif harus berupa angka!"
        sleep 1
        m-vmess
        exit 1
    else
        output_json "error" "Masa aktif harus berupa angka" "" "" "" "" "" 1
    fi
fi

# Input Kuota dan Limit IP (jika tidak ada dari HTTP GET)
if [ -z "$Quota" ] && [ "$interactive_mode" = true ]; then
    read -rp "➠ Limit User (GB) : " Quota
fi

if [ -z "$iplim" ] && [ "$interactive_mode" = true ]; then
    read -rp "➠ Limit User (IP) : " iplim
fi

# Konversi kuota ke byte
if [ -z "$Quota" ]; then
    Quota="0"
fi
c=$(echo "${Quota}" | sed 's/[^0-9]*//g')
d=$((${c} * 1024 * 1024 * 1024))
if [[ ${c} != "0" ]]; then
    echo "${d}" > /etc/vmess/${user}
fi

# Perpanjang masa aktif
exp=$(grep -wE "^### $user" "/etc/xray/config.json" | cut -d ' ' -f 3 | sort | uniq)
now=$(date +%Y-%m-%d)
d1=$(date -d "$exp" +%s)
d2=$(date -d "$now" +%s)
exp2=$(( (d1 - d2) / 86400 ))
exp3=$(($exp2 + $masaaktif))
exp4=$(date -d "$exp3 days" +"%Y-%m-%d")

# Update config
sed -i "/### $user/c\### $user $exp4" /etc/xray/config.json
sed -i "/### $user/c\### $user $exp4" /etc/vmess/.vmess.db
systemctl restart xray > /dev/null 2>&1

# Hostname VPS
SERVERNAMES=$(cat /etc/xray/domain)

# Ambil UUID client
uuid=$(grep -A 5 "### $user" /etc/xray/config.json | grep '"id"' | cut -d '"' -f 4 | head -1)

# Kirim notifikasi ke Telegram
send_telegram "$user" "$uuid" "VMESS" "$SERVERNAMES" "$exp4"

# Tampilkan output sesuai mode
if [ "$interactive_mode" = true ]; then
    # Tampilan Hasil Renew untuk mode interaktif
    clear
    echo -e "\033[0;33m━━━━━━━━━━━━━━━━※❆※━━━━━━━━━━━━━━━━\033[0m"
    echo -e "       𓈃 SUCCESFULLY RENEWED𓈃"
    echo -e "\033[0;33m━━━━━━━━━━━━━━━━※❆※━━━━━━━━━━━━━━━━\033[0m"
    echo "➠ CLIENT NAME     : $user"
    echo "➠ UUID            : $uuid"
    echo "➠ SERVICENAME    : VMESS"
    echo "➠ SERVERNAME      : $SERVERNAMES"
    echo "➠ EXPIRED ON      : $exp4"
    echo -e "\033[0;33m━━━━━━━━━━━━━━━━※❆※━━━━━━━━━━━━━━━━\033[0m"
    echo ""
    read -p "Onii-chan, Tekan ENTER untuk kembali..."
    m-vmess
else
    # Output JSON untuk HTTP GET
    output_json "success" "Berhasil memperbarui masa aktif" "$user" "$uuid" "VMESS" "$SERVERNAMES" "$exp4" 0
fi

