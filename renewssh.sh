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
            \"username\": \"$3\",
            \"days_added\": \"$4\",
            \"expired_on\": \"$5\",
            \"status\": \"$6\"
        }
    }"
    exit $7
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
║ <b>RENEW SSH BERHASIL</b>
╠════════════════════════
║ • <b>User:</b> <code>$1</code>
║ • <b>Days Added:</b> <code>$2 days</code>
║ • <b>Expired On:</b> <code>$3</code>
║ • <b>Status:</b> <code>$4</code>
║ • <b>Dibuat pada:</b> <code>$(date +"%d-%m-%Y %H:%M:%S")</code>
╚════════════════════════"
    curl -s --max-time 10 -d "chat_id=$CHAT_ID&disable_web_page_preview=1&text=$TEXT&parse_mode=html" $URL >/dev/null
}

# Cek jika dipanggil via HTTP GET
if [ "$REQUEST_METHOD" = "GET" ]; then
    # Ambil parameter dari query string
    User=$(echo "$QUERY_STRING" | sed -n 's/^.*user=\([^&]*\).*$/\1/p')
    Days=$(echo "$QUERY_STRING" | sed -n 's/^.*days=\([^&]*\).*$/\1/p')
    
    # Mode HTTP GET tidak memerlukan interaksi user
    interactive_mode=false
else
    # Mode interaktif (terminal)
    interactive_mode=true
    
    # Bersihkan layar
    clear
    
    # Tampilkan header
    echo -e " ${NC} ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e " ${NC} ${BGWHITE}              List Member SSH OPENVPN             ${NC}"
    echo -e " ${NC} ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  USERNAME          EXP DATE          STATUS"
    echo -e " ${NC} ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Tampilkan daftar user SSH
    while read expired
    do
        AKUN="$(echo $expired | cut -d: -f1)"
        ID="$(echo $expired | grep -v nobody | cut -d: -f3)"
        exp="$(chage -l $AKUN | grep "Account expires" | awk -F": " '{print $2}')"
        status="$(passwd -S $AKUN | awk '{print $2}' )"
        if [[ $ID -ge 1000 ]]; then
            if [[ "$status" = "L" ]]; then
                printf "%-17s %2s %-17s %2s \n" "  $AKUN" "$exp     " "LOCKED"
            else
                printf "%-17s %2s %-17s %2s \n" "  $AKUN" "$exp     " "UNLOCKED"
            fi
        fi
    done < /etc/passwd
    
    # Tampilkan footer dan input user
    echo -e " ${NC} ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e " ${NC} ${BGWHITE}         Masukan Username Akun SSH OPENVPN        ${NC}"
    echo -e " ${NC} ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    read -p "  Username   : " User
fi

# Verifikasi apakah username ada
egrep "^$User" /etc/passwd >/dev/null
if [ $? -ne 0 ]; then
    if [ "$interactive_mode" = true ]; then
        clear
        echo -e " ${NC} ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e " ${NC} ${BGWHITE}             Perpanjang Masa Aktif SSH            ${NC}"
        echo -e " ${NC} ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e " ${NC} ${RED}» Username Tidak Ditemukan !"
        echo -e " ${NC} ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e ""
        read -p "  Press any key to back"
        m-sshws
        exit 1
    else
        output_json "error" "Username tidak ditemukan" "" "" "" "" 1
    fi
fi

# Input durasi (jika tidak ada dari HTTP GET)
if [ -z "$Days" ]; then
    if [ "$interactive_mode" = true ]; then
        read -p "  Day Extend : " Days
    else
        output_json "error" "Parameter days diperlukan" "" "" "" "" 1
    fi
fi

# Validasi masa aktif
if ! [[ "$Days" =~ ^[0-9]+$ ]]; then
    if [ "$interactive_mode" = true ]; then
        echo -e "${RED}[ERROR] Masa aktif harus berupa angka!${NC}"
        sleep 1
        m-sshws
        exit 1
    else
        output_json "error" "Masa aktif harus berupa angka" "" "" "" "" 1
    fi
fi

# Proses perpanjangan masa aktif
Today=`date +%s`
Days_Detailed=$(( $Days * 86400 ))
Expire_On=$(($Today + $Days_Detailed))
Expiration=$(date -u --date="1970-01-01 $Expire_On sec GMT" +%Y/%m/%d)
Expiration_Display=$(date -u --date="1970-01-01 $Expire_On sec GMT" '+%d %b %Y')

# Unlock dan update masa aktif
passwd -u $User
usermod -e $Expiration $User
egrep "^$User" /etc/passwd >/dev/null

# Kirim notifikasi ke Telegram
status="UNLOCKED"
send_telegram "$User" "$Days" "$Expiration_Display" "$status"

# Tampilkan output sesuai mode
if [ "$interactive_mode" = true ]; then
    # Tampilan Hasil Renew untuk mode interaktif
    clear
    echo -e " ${NC} ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e " ${NC} ${BGWHITE}             Perpanjang Masa Aktif SSH            ${NC}"
    echo -e " ${NC} ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e ""
    echo -e " ${GREEN} Username   : $User"
    echo -e " ${GREEN} Days Added : $Days Days"
    echo -e " ${GREEN} Expires on : $Expiration_Display"
    echo -e ""
    echo -e " ${NC} ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e ""
    read -p "  Press any key to back"
    m-sshws
else
    # Output JSON untuk HTTP GET
    output_json "success" "Berhasil memperbarui masa aktif" "$User" "$Days" "$Expiration_Display" "$status" 0
fi
