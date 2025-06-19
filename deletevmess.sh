#!/bin/bash

# Script untuk menghapus user Vmess via HTTP GET dengan autentikasi
# File: deletevmess_api.sh

# ================================================
# KONFIGURASI AWAL
# ================================================

# Validasi auth key
valid_auth="fadznewbie_do"

# Format output selalu JSON
response_json() {
    echo "$1"
    exit $2
}

# ================================================
# PROSES AUTENTIKASI
# ================================================

# Ambil parameter dari query string
auth=$(echo "$QUERY_STRING" | grep -oE 'auth=[^&]+' | cut -d= -f2)
user=$(echo "$QUERY_STRING" | grep -oE 'user=[^&]+' | cut -d= -f2)

# Validasi parameter wajib
if [[ "$auth" != "$valid_auth" ]]; then
    response_json '{"status":"error","message":"Invalid authentication key"}' 1
fi

if [ -z "$user" ]; then
    response_json '{"status":"error","message":"Username parameter is required"}' 1
fi

# ================================================
# FUNGSI UTAMA (TANPA DEPENDENCY INTERAKTIF)
# ================================================

# Cari user di config.json
exp=$(grep -wE "^### $user" "/etc/xray/config.json" | cut -d ' ' -f 3 | sort | uniq)

if [ -z "$exp" ]; then
    response_json '{"status":"error","message":"User not found"}' 1
fi

# Proses penghapusan
sed -i "/^### $user $exp/,/^},{/d" /etc/xray/config.json
sed -i "/^### $user $exp/,/^},{/d" /etc/vmess/.vmess.db
rm -rf "/etc/vmess/$user" 2>/dev/null
rm -rf "/etc/kyt/limit/vmess/ip/$user" 2>/dev/null

# Restart service
systemctl restart xray >/dev/null 2>&1

# Response sukses
response_json '{
    "status": "success",
    "message": "User deleted successfully",
    "data": {
        "username": "'"$user"'",
        "expired_date": "'"$exp"'"
    }
}' 0
