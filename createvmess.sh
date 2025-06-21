#!/bin/bash
# ========================================
#  System Request  Debian 9+/Ubuntu 18.04+/20+
#  telegram    https://t.me/fadzdigital
#  whatsapp    wa.me/6285727035336
# ========================================

# ==================== KONFIGURASI HTTP ====================
# Jika dipanggil via web server (http), set output sebagai JSON
if [[ "$REQUEST_METHOD" == "GET" ]]; then
  # Ambil parameter dari query string
  user=$(echo "$QUERY_STRING" | grep -oE '(^|&)user=[^&]*' | cut -d= -f2)
  uuid_arg=$(echo "$QUERY_STRING" | grep -oE '(^|&)uuid=[^&]*' | cut -d= -f2)
  masaaktif=$(echo "$QUERY_STRING" | grep -oE '(^|&)exp=[^&]*' | cut -d= -f2)
  Quota=$(echo "$QUERY_STRING" | grep -oE '(^|&)quota=[^&]*' | cut -d= -f2)
  iplimit=$(echo "$QUERY_STRING" | grep -oE '(^|&)iplimit=[^&]*' | cut -d= -f2)
  # auth sudah dihapus

  # Validasi parameter wajib
  if [[ -z "$user" || -z "$masaaktif" || -z "$Quota" || -z "$iplimit" ]]; then
    echo -e "Content-Type: application/json\r\n"
    printf '{"status":"error","message":"Missing required parameters"}\n'
    exit 1
  fi
  
  # Generate UUID jika auto atau kosong
  if [[ "$uuid_arg" == "auto" || -z "$uuid_arg" ]]; then
    uuid=$(cat /proc/sys/kernel/random/uuid)
  else
    # Validasi format UUID
    if [[ ${#uuid_arg} -ne 36 || ! "$uuid_arg" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]]; then
      echo -e "Content-Type: application/json\r\n"
      printf '{"status":"error","message":"Invalid UUID format"}\n'
      exit 1
    fi
    uuid="$uuid_arg"
  fi

  # Set flag non-interactive
  non_interactive=true
fi

# ==================== KONFIGURASI AWAL ====================
source /var/lib/kyt/ipvps.conf 2>/dev/null
if [[ "$IP" = "" ]]; then
  domain=$(cat /etc/xray/domain)
else
  domain=$IP
fi

# ==================== PROSES PEMBUATAN AKUN ====================
if [[ "$non_interactive" == "true" ]]; then
  # Validasi username
  if [[ -z "$user" ]]; then
    echo -e "Content-Type: application/json\r\n"
    printf '{"status":"error","message":"Username cannot be empty"}\n'
    exit 1
  fi
  if [[ ! "$user" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo -e "Content-Type: application/json\r\n"
    printf '{"status":"error","message":"Username hanya boleh menggunakan huruf, angka, - dan _"}\n'
    exit 1
  fi

  # Cek duplikasi username
  user_exists_config=false
  if grep -q "\"email\"[[:space:]]*:[[:space:]]*\"$user\"" /etc/xray/config.json; then
    user_exists_config=true
  fi
  user_exists_db=false
  if [[ -f "/etc/vmess/.vmess.db" ]]; then
    if grep -q "^### $user " /etc/vmess/.vmess.db; then
      user_exists_db=true
    fi
  fi
  if [[ "$user_exists_config" == "true" ]] || [[ "$user_exists_db" == "true" ]]; then
    echo -e "Content-Type: application/json\r\n"
    printf '{"status":"error","message":"Username already exists"}\n'
    exit 1
  fi

  # Validasi masa aktif
  if ! [[ "$masaaktif" =~ ^[0-9]+$ ]] || [[ "$masaaktif" -le 0 ]]; then
    echo -e "Content-Type: application/json\r\n"
    printf '{"status":"error","message":"Masa aktif harus angka positif"}\n'
    exit 1
  fi

  # Validasi quota
  if ! [[ "$Quota" =~ ^[0-9]+$ ]]; then
    echo -e "Content-Type: application/json\r\n"
    printf '{"status":"error","message":"Quota harus angka"}\n'
    exit 1
  fi

  # Validasi iplimit
  if ! [[ "$iplimit" =~ ^[0-9]+$ ]]; then
    echo -e "Content-Type: application/json\r\n"
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

  # Proses pembuatan akun VMESS
  sed -i '/#vmess$/a\### '"$user $exp"'\
},{"id": "'""$uuid""'","alterId": '"0"',"email": "'""$user""'"' /etc/xray/config.json
  sed -i '/#vmessgrpc$/a\### '"$user $exp"'\
},{"id": "'""$uuid""'","alterId": '"0"',"email": "'""$user""'"' /etc/xray/config.json

  # Buat konfigurasi VMESS
  asu=$(cat <<EOF
      {
      "v": "2",
      "ps": "${user}",
      "add": "${domain}",
      "port": "443",
      "id": "${uuid}",
      "aid": "0",
      "net": "ws",
      "path": "/vmess",
      "type": "none",
      "host": "${domain}",
      "tls": "tls"
}
EOF
)
  ask=$(cat <<EOF
      {
      "v": "2",
      "ps": "${user}",
      "add": "${domain}",
      "port": "80",
      "id": "${uuid}",
      "aid": "0",
      "net": "ws",
      "path": "/vmess",
      "type": "none",
      "host": "${domain}",
      "tls": "none"
}
EOF
)
  grpc=$(cat <<EOF
      {
      "v": "2",
      "ps": "${user}",
      "add": "${domain}",
      "port": "443",
      "id": "${uuid}",
      "aid": "0",
      "net": "grpc",
      "path": "vmess-grpc",
      "type": "none",
      "host": "${domain}",
      "tls": "tls"
}
EOF
)
  vmesslink1="vmess://$(echo $asu | base64 -w 0)"
  vmesslink2="vmess://$(echo $ask | base64 -w 0)"
  vmesslink3="vmess://$(echo $grpc | base64 -w 0)"

  # Restart layanan
  systemctl restart xray > /dev/null 2>&1
  service cron restart > /dev/null 2>&1

  # Buat file konfigurasi
  cat >/var/www/html/vmess-$user.txt <<-END

           # FORMAT OpenClash #

# Format Vmess WS TLS

- name: Vmess-$user-WS TLS
  type: vmess
  server: ${domain}
  port: 443
  uuid: ${uuid}
  alterId: 0
  cipher: auto
  udp: true
  tls: true
  skip-cert-verify: true
  servername: ${domain}
  network: ws
  ws-opts:
    path: /vmess
    headers:
      Host: ${domain}

# Format Vmess WS Non TLS

- name: Vmess-$user-WS Non TLS
  type: vmess
  server: ${domain}
  port: 80
  uuid: ${uuid}
  alterId: 0
  cipher: auto
  udp: true
  tls: false
  skip-cert-verify: false
  servername: ${domain}
  network: ws
  ws-opts:
    path: /vmess
    headers:
      Host: ${domain}

# Format Vmess gRPC

- name: Vmess-$user-gRPC (SNI)
  server: ${domain}
  port: 443
  type: vmess
  uuid: ${uuid}
  alterId: 0
  cipher: auto
  network: grpc
  tls: true
  servername: ${domain}
  skip-cert-verify: true
  grpc-opts:
    grpc-service-name: vmess-grpc

              #  VMESS WS TLS #

${vmesslink1}

         # VMESS WS NON TLS #

${vmesslink2}

           # VMESS WS gRPC #

${vmesslink3}


END

  # Set limit IP jika diperlukan
  if [[ $iplimit -gt 0 ]]; then
    mkdir -p /etc/kyt/limit/vmess/ip
    echo -e "$iplimit" > /etc/kyt/limit/vmess/ip/$user
  fi

  # Set quota jika diperlukan
  if [ -z ${Quota} ]; then
    Quota="0"
  fi

  c=$(echo "${Quota}" | sed 's/[^0-9]*//g')
  d=$((${c} * 1024 * 1024 * 1024))

  if [[ ${c} != "0" ]]; then
    echo "${d}" >/etc/vmess/${user}
  fi

  # Update database
  DATADB=$(cat /etc/vmess/.vmess.db 2>/dev/null | grep "^###" | grep -w "${user}" | awk '{print $2}')
  if [[ "${DATADB}" != '' ]]; then
    sed -i "/\b${user}\b/d" /etc/vmess/.vmess.db
  fi
  echo "### ${user} ${exp} ${uuid} ${Quota} ${iplimit}" >>/etc/vmess/.vmess.db

  # ======== KIRIM PESAN TELEGRAM JIKA KONFIGURASI ADA =======
  if [ -f "/etc/telegram_bot/bot_token" ] && [ -f "/etc/telegram_bot/chat_id" ]; then
    BOT_TOKEN=$(cat /etc/telegram_bot/bot_token)
    CHAT_ID=$(cat /etc/telegram_bot/chat_id)
    location=$(curl -s ipinfo.io/json)
    CITY=$(echo "$location" | jq -r '.city')
    ISP=$(echo "$location" | jq -r '.org')
    MYIP=$(curl -s ifconfig.me)
    CITY=${CITY:-"Unknown"}
    ISP=${ISP:-"Unknown"}
    TEXT="<b>━━━━━━ VMESS PREMIUM ━━━━━</b>

<b>👤 User Details</b>
┣ <b>Username</b>   : <code>$user</code>
┣ <b>UUID</b>       : <code>$uuid</code>
┣ <b>Quota</b>      : <code>${Quota} GB</code>
┣ <b>Status</b>     : <code>Aktif $masaaktif hari</code>
┣ <b>Dibuat</b>     : <code>$tnggl</code>
┗ <b>Expired</b>    : <code>$expe</code>

<b>🌎 Server Info</b>
┣ <b>Domain</b>     : <code>$domain</code>
┣ <b>IP</b>         : <code>$MYIP</code>
┣ <b>Location</b>   : <code>$CITY</code>
┗ <b>ISP</b>        : <code>$ISP</code>

<b>🔗 Connection</b>
┣ <b>TLS Port</b>        : <code>400-900</code>
┣ <b>Non-TLS Port</b>    : <code>80, 8080, 8081-9999</code>
┣ <b>Network</b>         : <code>ws, grpc</code>
┣ <b>Path</b>            : <code>/vmess</code>
┣ <b>gRPC Service</b>    : <code>vmess-grpc</code>
┣ <b>Security</b>        : <code>auto</code>
┗ <b>alterId</b>         : <code>0</code>

<b>━━━━━ VMESS Premium Links ━━━━━</b>
<b>📍 WS TLS</b>
<pre>$vmesslink1</pre>
<b>📍 WS Non-TLS</b>
<pre>$vmesslink2</pre>
<b>📍 gRPC</b>
<pre>$vmesslink3</pre>

<b>📥 Config File (Clash/OpenClash):</b>
➤ https://${domain}:81/vmess-$user.txt

<b>✨ Tools & Resources</b>
┣  https://vpntech.my.id/converteryaml
┗  https://vpntech.my.id/auto-configuration

<b>❓ Butuh Bantuan?</b>
➤ https://wa.me/6285727035336

<b>━━━━━━━━━ Thank You ━━━━━━━━</b>
"
    TEXT_ENCODED=$(echo "$TEXT" | jq -sRr @uri)
    curl -s -d "chat_id=$CHAT_ID&disable_web_page_preview=1&text=$TEXT_ENCODED&parse_mode=html" "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" > /dev/null 2>&1
  fi

  # Output JSON untuk response HTTP (1 baris JSON valid)
  printf '{"status":"success","username":"%s","uuid":"%s","domain":"%s","expired":"%s","quota_gb":"%s","ip_limit":"%s","created":"%s","ws_tls":"%s","ws_ntls":"%s","grpc":"%s"}\n' \
    "$user" "$uuid" "$domain" "$exp" "$Quota" "$iplimit" "$tnggl" "$vmesslink1" "$vmesslink2" "$vmesslink3"
  exit 0
fi
