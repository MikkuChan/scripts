#!/bin/bash
# 𓈃 System Request ➠ Debian 9+/Ubuntu 18.04+/20+
# 𓈃 Develovers ➠ MikkuChan
# 𓈃 Email      ➠ fadztechs2@gmail.com
# 𓈃 telegram   ➠ https://t.me/fadzdigital
# 𓈃 whatsapp   ➠ wa.me/+6285727035336

# ==================== KONFIGURASI HTTP ====================
if [[ "$REQUEST_METHOD" == "GET" ]]; then
  Login=$(echo "$QUERY_STRING" | grep -oE '(^|&)user=[^&]*' | cut -d= -f2)
  Pass=$(echo "$QUERY_STRING" | grep -oE '(^|&)pass=[^&]*' | cut -d= -f2)
  masaaktif=$(echo "$QUERY_STRING" | grep -oE '(^|&)exp=[^&]*' | cut -d= -f2)
  Quota=$(echo "$QUERY_STRING" | grep -oE '(^|&)quota=[^&]*' | cut -d= -f2)
  iplimit=$(echo "$QUERY_STRING" | grep -oE '(^|&)iplimit=[^&]*' | cut -d= -f2)
  # auth sudah dihapus

  if [[ -z "$Login" || -z "$Pass" || -z "$masaaktif" || -z "$Quota" || -z "$iplimit" ]]; then
    printf '{"status":"error","message":"Missing required parameters"}\n'
    exit 1
  fi

  # ==================== KONFIGURASI DOMAIN ====================
  domain=$(cat /etc/xray/domain 2>/dev/null)
  IP=$(curl -sS ipv4.icanhazip.com)
  ISP=$(cat /etc/xray/isp 2>/dev/null)
  CITY=$(cat /etc/xray/city 2>/dev/null)

  # ==================== VALIDASI ====================
  if [[ ! "$Login" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    printf '{"status":"error","message":"Username hanya boleh menggunakan huruf, angka, - dan _"}\n'
    exit 1
  fi

  if grep -q "^#ssh# $Login " /etc/ssh/.ssh.db 2>/dev/null; then
    printf '{"status":"error","message":"Username already exists"}\n'
    exit 1
  fi

  if ! [[ "$masaaktif" =~ ^[0-9]+$ ]] || [[ "$masaaktif" -le 0 ]]; then
    printf '{"status":"error","message":"Masa aktif harus angka positif"}\n'
    exit 1
  fi
  if ! [[ "$Quota" =~ ^[0-9]+$ ]]; then
    printf '{"status":"error","message":"Quota harus angka"}\n'
    exit 1
  fi
  if ! [[ "$iplimit" =~ ^[0-9]+$ ]]; then
    printf '{"status":"error","message":"IP limit harus angka"}\n'
    exit 1
  fi

  # ==================== PEMBUATAN AKUN ====================
  tgl=$(date -d "$masaaktif days" +"%d")
  bln=$(date -d "$masaaktif days" +"%b")
  thn=$(date -d "$masaaktif days" +"%Y")
  expe="$tgl $bln, $thn"
  tgl2=$(date +"%d")
  bln2=$(date +"%b")
  thn2=$(date +"%Y")
  tnggl="$tgl2 $bln2, $thn2"
  expi=$(date -d "$masaaktif days" +"%Y-%m-%d")

  if [[ $iplimit -gt 0 ]]; then
    mkdir -p /etc/kyt/limit/ssh/ip
    echo -e "$iplimit" > /etc/kyt/limit/ssh/ip/$Login
  fi

  useradd -e "$expi" -s /bin/false -M "$Login"
  echo -e "$Pass\n$Pass\n"|passwd "$Login" &> /dev/null

  if [ ! -e /etc/ssh ]; then
    mkdir -p /etc/ssh
  fi

  if [ -z ${Quota} ]; then
    Quota="0"
  fi

  c=$(echo "${Quota}" | sed 's/[^0-9]*//g')
  d=$((${c} * 1024 * 1024 * 1024))
  if [[ ${c} != "0" ]]; then
    echo "${d}" >/etc/ssh/${Login}
  fi

  DATADB=$(cat /etc/ssh/.ssh.db 2>/dev/null | grep "^#ssh#" | grep -w "${Login}" | awk '{print $2}')
  if [[ "${DATADB}" != '' ]]; then
    sed -i "/\b${Login}\b/d" /etc/ssh/.ssh.db
  fi
  echo "#ssh# ${Login} ${Pass} ${Quota} ${iplimit} ${expe}" >>/etc/ssh/.ssh.db

  cat > /var/www/html/ssh-$Login.txt <<-END
                     # SSH LOGIN DETAILED #
####### USER DETAIL #######
Username   : $Login
Password   : $Pass
Login      :   $domain:80@$Login:$Pass
Quota      : ${Quota} GB
Status     : Aktif $masaaktif hari
Dibuat     : $tnggl
Expired    : $expe

####### SERVER INFO #######
Domain     : $domain
IP         : $IP
Location   : $CITY
ISP        : $ISP

####### CONNECTION #######
Port OpenSSH     : 443, 80, 22
Port Dropbear    : 443, 109
Port SSH WS      : 80,8080,8081-9999
Port SSH SSL WS  : 443
Port SSH UDP     : 1-65535
Port SSL/TLS     : 400-900
Port OVPN WS SSL : 443
Port OVPN TCP    : 1194
Port OVPN UDP    : 2200
BadVPN UDP       : 7100,7300,7300

####### PAYLOAD WS #######
GET / HTTP/1.1[crlf]Host: [host][crlf]Connection: Upgrade[crlf]User-Agent: [ua][crlf]Upgrade: websocket[crlf][crlf]

####### PAYLOAD WSS #######
GET wss://BUG.COM/ HTTP/1.1[crlf]Host: $domain[crlf]Upgrade: websocket[crlf][crlf]

####### OVPN DOWNLOAD #######
https://$domain:81/
####### SAVE ACCOUNT #######
https://$domain:81/ssh-$Login.txt
####### ARIGATOU #######
END

  TEXT="<b>━━━━━ SSH/OVPN PREMIUM ━━━━━</b>

<b>👤 User Details</b>
┣ <b>Username</b>   : <code>$Login</code>
┣ <b>Password</b>   : <code>$Pass</code>
┣ <b>Login</b>      : <code>$domain:80@$Login:$Pass</code>
┣ <b>Quota</b>      : <code>${Quota} GB</code>
┣ <b>Status</b>     : <code>Aktif $masaaktif hari</code>
┣ <b>Dibuat</b>     : <code>$tnggl</code>
┗ <b>Expired</b>    : <code>$expe</code>

<b>🌎 Server Info</b>
┣ <b>Domain</b>     : <code>$domain</code>
┣ <b>IP</b>         : <code>$IP</code>
┣ <b>Location</b>   : <code>$CITY</code>
┗ <b>ISP</b>        : <code>$ISP</code>

<b>🔌 Connection</b>
┣ <b>Port OpenSSH</b>     : <code>443, 80, 22</code>
┣ <b>Port Dropbear</b>    : <code>443, 109</code>
┣ <b>Port SSH WS</b>      : <code>80,8080,8081-9999</code>
┣ <b>Port SSH SSL WS</b>  : <code>443</code>
┣ <b>Port SSH UDP</b>     : <code>1-65535</code>
┣ <b>Port SSL/TLS</b>     : <code>400-900</code>
┣ <b>Port OVPN WS SSL</b> : <code>443</code>
┣ <b>Port OVPN TCP</b>    : <code>1194</code>
┣ <b>Port OVPN UDP</b>    : <code>2200</code>
┗ <b>BadVPN UDP</b>       : <code>7100,7300,7300</code>

<b>⚡ payload WS</b>
<code>GET / HTTP/1.1[crlf]Host: [host][crlf]Connection: Upgrade[crlf]User-Agent: [ua][crlf]Upgrade: websocket[crlf][crlf]</code>

<b>⚡ Payload WSS</b>
<code>GET wss://BUG.COM/ HTTP/1.1[crlf]Host: $domain[crlf]Upgrade: websocket[crlf][crlf]</code>

<b>📥 OVPN Download</b>
✎ https://$domain:81/

<b>📝 Save Link Akun</b>
✎ https://$domain:81/ssh-$Login.txt

<b>━━━━━━━━━ Thank You ━━━━━━━━</b>
"

  # Kirim notifikasi ke Telegram
  if [ -f "/etc/telegram_bot/bot_token" ] && [ -f "/etc/telegram_bot/chat_id" ]; then
    BOT_TOKEN=$(cat /etc/telegram_bot/bot_token)
    CHAT_ID=$(cat /etc/telegram_bot/chat_id)
    URL="https://api.telegram.org/bot$BOT_TOKEN/sendMessage"
    TEXT_ENCODED=$(echo "$TEXT" | jq -sRr @uri)
    curl -s -d "chat_id=$CHAT_ID&disable_web_page_preview=1&text=$TEXT_ENCODED&parse_mode=html" "$URL" > /dev/null 2>&1
  fi

  # ==================== OUTPUT JSON FINAL ====================
  printf '{"status":"success","username":"%s","password":"%s","expired":"%s","quota_gb":"%s","ip_limit":"%s","created":"%s","domain":"%s","login_url":"%s:80@%s:%s","account_file":"https://%s:81/ssh-%s.txt"}\n' \
    "$Login" "$Pass" "$expi" "$Quota" "$iplimit" "$tnggl" "$domain" "$domain" "$Login" "$Pass" "$domain" "$Login"
  exit 0
fi
