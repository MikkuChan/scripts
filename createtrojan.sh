#!/bin/bash
# 𓈃 System Request ➠ Debian 9+/Ubuntu 18.04+/20+
# 𓈃 Develovers ➠ MikkuChan
# 𓈃 Email      ➠ fadztechs2@gmail.com
# 𓈃 telegram   ➠ https://t.me/fadzdigital
# 𓈃 whatsapp   ➠ wa.me/+6285727035336

# ==================== KONFIGURASI HTTP ====================
if [[ "$REQUEST_METHOD" == "GET" ]]; then
  user=$(echo "$QUERY_STRING" | grep -oE '(^|&)user=[^&]*' | cut -d= -f2)
  uuid_arg=$(echo "$QUERY_STRING" | grep -oE '(^|&)uuid=[^&]*' | cut -d= -f2)
  masaaktif=$(echo "$QUERY_STRING" | grep -oE '(^|&)exp=[^&]*' | cut -d= -f2)
  Quota=$(echo "$QUERY_STRING" | grep -oE '(^|&)quota=[^&]*' | cut -d= -f2)
  iplimit=$(echo "$QUERY_STRING" | grep -oE '(^|&)iplimit=[^&]*' | cut -d= -f2)
  # auth sudah dihapus

  if [[ -z "$user" || -z "$masaaktif" || -z "$Quota" || -z "$iplimit" ]]; then
    printf '{"status":"error","message":"Missing required parameters"}\n'
    exit 1
  fi

  if [[ "$uuid_arg" == "auto" || -z "$uuid_arg" ]]; then
    uuid=$(cat /proc/sys/kernel/random/uuid)
  else
    if [[ ${#uuid_arg} -ne 36 || ! "$uuid_arg" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]]; then
      printf '{"status":"error","message":"Invalid UUID format"}\n'
      exit 1
    fi
    uuid="$uuid_arg"
  fi

  # Baca domain
  source /var/lib/kyt/ipvps.conf 2>/dev/null
  if [[ "$IP" == "" ]]; then
    domain=$(cat /etc/xray/domain)
  else
    domain=$IP
  fi

  if [[ ! "$user" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    printf '{"status":"error","message":"Username hanya boleh menggunakan huruf, angka, - dan _"}\n'
    exit 1
  fi

  user_exists_config=false
  if grep -q "\"email\"[[:space:]]*:[[:space:]]*\"$user\"" /etc/xray/config.json; then
    user_exists_config=true
  fi
  user_exists_db=false
  if [[ -f "/etc/trojan/.trojan.db" ]]; then
    if grep -q "^### $user " /etc/trojan/.trojan.db; then
      user_exists_db=true
    fi
  fi
  if [[ "$user_exists_config" == "true" ]] || [[ "$user_exists_db" == "true" ]]; then
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

  # Hitung tanggal kadaluarsa
  tgl=$(date -d "$masaaktif days" +"%d")
  bln=$(date -d "$masaaktif days" +"%b")
  thn=$(date -d "$masaaktif days" +"%Y")
  expe="$tgl $bln, $thn"
  tgl2=$(date +"%d")
  bln2=$(date +"%b")
  thn2=$(date +"%Y")
  tnggl="$tgl2 $bln2, $thn2"
  exp=$(date -d "$masaaktif days" +"%Y-%m-%d")

  sed -i '/#trojanws$/a\#! '"$user $exp"'\
},{"password": "'""$uuid""'","email": "'""$user""'"' /etc/xray/config.json
  sed -i '/#trojangrpc$/a\#! '"$user $exp"'\
},{"password": "'""$uuid""'","email": "'""$user""'"' /etc/xray/config.json

  systemctl restart xray > /dev/null 2>&1
  service cron restart > /dev/null 2>&1

  trojanlink="trojan://${uuid}@${domain}:443?path=%2Ftrojan-ws&security=tls&host=${domain}&type=ws&sni=${domain}#${user}"
  trojanlink1="trojan://${uuid}@${domain}:443?mode=gun&security=tls&type=grpc&serviceName=trojan-grpc&sni=${domain}#${user}"

  cat >/var/www/html/trojan-$user.txt <<-END
# Format TROJAN For Clash #

- name: Trojan-$user-GO/WS
  server: ${domain}
  port: 443
  type: trojan
  password: ${uuid}
  network: ws
  sni: ${domain}
  skip-cert-verify: true
  udp: true
  ws-opts:
    path: /trojan-ws
    headers:
        Host: ${domain}

- name: Trojan-$user-gRPC
  type: trojan
  server: ${domain}
  port: 443
  password: ${uuid}
  udp: true
  sni: ${domain}
  skip-cert-verify: true
  network: grpc
  grpc-opts:
    grpc-service-name: trojan-grpc

# TROJAN WS TLS
${trojanlink}

# TROJAN WS gRPC
${trojanlink1}
END

  if [[ $iplimit -gt 0 ]]; then
    mkdir -p /etc/kyt/limit/trojan/ip
    echo -e "$iplimit" > /etc/kyt/limit/trojan/ip/$user
  fi
  if [ -z ${Quota} ]; then
    Quota="0"
  fi
  c=$(echo "${Quota}" | sed 's/[^0-9]*//g')
  d=$((${c} * 1024 * 1024 * 1024))
  if [[ ${c} != "0" ]]; then
    echo "${d}" >/etc/trojan/${user}
  fi
  DATADB=$(cat /etc/trojan/.trojan.db 2>/dev/null | grep "^###" | grep -w "${user}" | awk '{print $2}')
  if [[ "${DATADB}" != '' ]]; then
    sed -i "/\b${user}\b/d" /etc/trojan/.trojan.db
  fi
  echo "### ${user} ${exp} ${uuid} ${Quota} ${iplimit}" >>/etc/trojan/.trojan.db

  # ==================== KIRIM TELEGRAM ====================
  if [ -f "/etc/telegram_bot/bot_token" ] && [ -f "/etc/telegram_bot/chat_id" ]; then
    BOT_TOKEN=$(cat /etc/telegram_bot/bot_token)
    CHAT_ID=$(cat /etc/telegram_bot/chat_id)
    location=$(curl -s ipinfo.io/json)
    CITY=$(echo "$location" | jq -r '.city')
    ISP=$(echo "$location" | jq -r '.org')
    MYIP=$(curl -s ifconfig.me)
    CITY=${CITY:-"Saya Gatau"}
    ISP=${ISP:-"Saya Gatau"}
    TEXT="<b>━━━ DETAIL AKUN TROJAN ━━━</b>

<b>👤 User Details</b>
┣ <b>Username</b>   : <code>${user}</code>
┣ <b>Uuid </b>       : <code>${uuid}</code>
┣ <b>Quota</b>      : <code>${Quota} GB</code>
┣ <b>Status</b>     : <code>Aktif $masaaktif hari</code>
┣ <b>Dibuat</b>     : <code>$tnggl</code>
┗ <b>Expired</b>    : <code>$expe</code>

<b>🌎 Server Info</b>
┣ <b>Domain</b>     : <code>${domain}</code>
┣ <b>IP</b>         : <code>$MYIP</code>
┣ <b>Location</b>   : <code>$CITY</code>
┗ <b>ISP</b>        : <code>$ISP</code>

<b>🔗 Connection</b>
┣ <b>TLS Port</b>        : <code>400-900</code>
┣ <b>Network</b>         : <code>ws, grpc</code>
┣ <b>Path</b>            : <code>/trojan-ws</code>
┗ <b>gRPC Service</b>    : <code>trojan-grpc</code>

<b>━━━━━ TROJAN Premium Links ━━━━━</b>
<b>📍 WS TLS</b>
<pre>${trojanlink}</pre>
<b>📍 gRPC</b>
<pre>${trojanlink1}</pre>

<b>📥 Config File (Clash/OpenClash):</b>
✎ https://${domain}:81/trojan-$user.txt

<b>✨ Tools & Resources</b>
┣ https://vpntech.my.id/converteryaml
┗ https://vpntech.my.id/auto-configuration

<b>❓ Butuh Bantuan?</b>
✎ https://wa.me/6285727035336

<b>━━━━━━━━━ Thank You ━━━━━━━━</b>"
    TEXT_ENCODED=$(echo "$TEXT" | jq -sRr @uri)
    curl -s -d "chat_id=$CHAT_ID&disable_web_page_preview=1&text=$TEXT_ENCODED&parse_mode=html" "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" > /dev/null 2>&1
  fi

  # ==================== OUTPUT JSON FINAL ====================
  printf '{"status":"success","username":"%s","uuid":"%s","domain":"%s","expired":"%s","quota_gb":"%s","ip_limit":"%s","created":"%s","ws_tls":"%s","grpc":"%s","config_url":"https://%s:81/trojan-%s.txt"}\n' \
    "$user" "$uuid" "$domain" "$exp" "$Quota" "$iplimit" "$tnggl" "$trojanlink" "$trojanlink1" "$domain" "$user"
  exit 0
fi
