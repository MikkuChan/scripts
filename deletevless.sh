#!/bin/bash
# Script untuk menghapus user VLess via HTTP GET
# FadzDigital
# ==================================================

export PATH=$PATH:/usr/sbin:/sbin
valid_auth="${AUTHKEY:-default_fallback}"

# FUNGSI UTAMA
# Cek jika dipanggil via HTTP GET
if [ "$REQUEST_METHOD" = "GET" ]; then
  # Ambil parameter dari query string
  user=$(echo "$QUERY_STRING" | sed -n 's/^.*user=\([^&]*\).*$/\1/p')
  auth=$(echo "$QUERY_STRING" | sed -n 's/^.*auth=\([^&]*\).*$/\1/p')

  # Validasi auth key
  if [ -z "$auth" ] || [ "$auth" != "$valid_auth" ]; then
    echo '{"status": "error", "message": "Invalid authentication key"}'
    exit 1
  fi

  # Validasi username
  if [ -z "$user" ]; then
    echo '{"status": "error", "message": "Username is required"}'
    exit 1
  fi

  # Cari user di config.json
  exp=$(grep -wE "^#& $user" "/etc/xray/config.json" | cut -d ' ' -f 3 | sort | uniq)

  # Jika user tidak ditemukan
  if [ -z "$exp" ]; then
    echo '{"status": "error", "message": "User not found"}'
    exit 1
  fi

  # Proses penghapusan user
  sed -i "/^#& $user $exp/,/^},{/d" /etc/xray/config.json
  sed -i "/^#& $user $exp/,/^},{/d" /etc/vless/.vless.db
  rm -rf "/etc/vless/$user"
  rm -rf "/etc/kyt/limit/vless/ip/$user"
  systemctl restart xray > /dev/null 2>&1

  # Berikan response sukses
  echo '{"status": "success", "message": "User deleted successfully", "username": "'$user'", "expired": "'$exp'"}'
  exit 0
fi

# Jika dijalankan via CLI (bukan HTTP)
echo '{"status": "error", "message": "Script ini dirancang untuk dijalankan via HTTP request"}'
exit 1
