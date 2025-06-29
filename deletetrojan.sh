#!/bin/bash
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Script untuk menghapus user Trojan via API
# FadzDigital
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Fungsi untuk validasi autentikasi
validasi_auth() {
    local auth=$1
    
    if [[ "$auth" != "$valid_auth" ]]; then
        echo '{"status": "error", "message": "Invalid authentication key"}'
        exit 1
    fi
}

# Fungsi untuk menghapus user Trojan
hapus_user_trojan() {
    local username=$1
    
    # Cari tanggal expired user dari config.json
    expired_date=$(grep -wE "^#! ${username}" "/etc/xray/config.json" | cut -d ' ' -f 3 | sort | uniq)
    
    # Validasi apakah user ditemukan
    if [ -z "$expired_date" ]; then
        echo "{\"status\":\"error\",\"message\":\"User ${username} tidak ditemukan\"}"
        exit 1
    fi
    
    # 1. Hapus konfigurasi user dari file config xray
    sed -i "/^#! ${username} ${expired_date}/,/^},{/d" /etc/xray/config.json
    
    # 2. Hapus data user dari database trojan
    sed -i "/### ${username} ${expired_date}/,/^},{/d" /etc/trojan/.trojan.db
    
    # 3. Hapus folder user dari direktori trojan
    rm -rf "/etc/trojan/${username}"
    
    # 4. Hapus data limit IP user
    rm -rf "/etc/kyt/limit/trojan/ip/${username}"
    
    # 5. Restart service xray untuk menerapkan perubahan
    systemctl restart xray > /dev/null 2>&1
    
    # Response JSON
    echo "{\"status\":\"success\",\"message\":\"User ${username} berhasil dihapus\",\"expired_date\":\"${expired_date}\"}"
}

# ===== MAIN PROGRAM =====

# Cek apakah dipanggil via HTTP GET (QUERY_STRING ada)
if [ -n "$QUERY_STRING" ]; then
    # Parse parameter dari QUERY_STRING
    declare -A params
    IFS='&' read -ra pairs <<< "$QUERY_STRING"
    for pair in "${pairs[@]}"; do
        IFS='=' read -r key value <<< "$pair"
        params["$key"]=$value
    done
    
    # Cek parameter wajib
    if [ -z "${params[user]}" ] || [ -z "${params[auth]}" ]; then
        echo '{"status":"error","message":"Parameter user dan auth diperlukan"}'
        exit 1
    fi
    
    # Validasi auth key
    validasi_auth "${params[auth]}"
    
    # Jalankan penghapusan user via API
    hapus_user_trojan "${params[user]}"
    
else
    # Jika tidak ada QUERY_STRING, tampilkan error
    echo '{"status":"error","message":"Script hanya mendukung mode API dengan parameter GET"}'
    exit 1
fi
