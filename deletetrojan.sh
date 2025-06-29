#!/bin/bash
# Script untuk menghapus user Trojan via API HTTP GET
# By FadzDigital
# ==================================================

export PATH=$PATH:/usr/sbin:/sbin
valid_auth="${AUTHKEY:-default_fallback}"

if [ "$REQUEST_METHOD" = "GET" ]; then
    # Ambil parameter user dan auth dari QUERY_STRING
    user=$(echo "$QUERY_STRING" | sed -n 's/^.*user=\([^&]*\).*$/\1/p')
    auth=$(echo "$QUERY_STRING" | sed -n 's/^.*auth=\([^&]*\).*$/\1/p')

    # Cek parameter wajib
    if [ -z "$user" ] || [ -z "$auth" ]; then
        echo '{"status":"error","message":"Parameter user dan auth diperlukan"}'
        exit 1
    fi

    # Validasi auth key dari ENV
    if [ "$auth" != "$valid_auth" ]; then
        echo '{"status": "error", "message": "Invalid authentication key"}'
        exit 1
    fi

    # Cari tanggal expired user dari config.json
    exp=$(grep -wE "^#! $user" "/etc/xray/config.json" | cut -d ' ' -f 3 | sort | uniq)

    # Validasi apakah user ditemukan
    if [ -z "$exp" ]; then
        echo '{"status":"error","message":"User not found"}'
        exit 1
    fi

    # 1. Hapus konfigurasi user dari file config xray
    sed -i "/^#! $user $exp/,/^},{/d" /etc/xray/config.json

    # 2. Hapus data user dari database trojan
    sed -i "/### $user $exp/,/^},{/d" /etc/trojan/.trojan.db

    # 3. Hapus folder user dari direktori trojan
    rm -rf "/etc/trojan/$user"

    # 4. Hapus data limit IP user
    rm -rf "/etc/kyt/limit/trojan/ip/$user"

    # 5. Restart service xray
    systemctl restart xray > /dev/null 2>&1

    # Response sukses
    echo '{"status":"success","message":"User deleted successfully","username":"'"$user"'","expired":"'"$exp"'"}'
    exit 0
fi

# Jika dijalankan via CLI (bukan HTTP GET)
echo '{"status":"error","message":"Script hanya mendukung mode API via HTTP GET"}'
exit 1
