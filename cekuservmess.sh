#!/bin/bash

# Script untuk mengecek dan menampilkan daftar user Vmess dalam format JSON
# File: cekuservmess.sh

# Fungsi utama untuk mengecek dan menampilkan daftar user
cek_daftar_user() {
    # Inisialisasi array untuk menyimpan data user
    local users=()
    local total_user=0

    # Cek jika file config.json ada
    if [ ! -f "/etc/xray/config.json" ]; then
        echo '{"status":"error","message":"File config.json tidak ditemukan"}'
        return 1
    fi

    # Hitung jumlah user dan kumpulkan data
    total_user=$(grep -c -E "^### " "/etc/xray/config.json")

    # Jika tidak ada user
    if [[ ${total_user} == '0' ]]; then
        echo '{"status":"success","total_user":0,"users":[],"message":"Tidak ada user Vmess"}'
        return 0
    fi

    # Proses setiap user
    while IFS= read -r line; do
        # Ekstrak username dan expired date
        local username=$(echo "$line" | awk '{print $2}')
        local expired=$(echo "$line" | awk '{print $3}')

        # Tambahkan ke array
        users+=("{\"username\":\"$username\",\"expired\":\"$expired\"}")
    done < <(grep -e "^### " "/etc/xray/config.json" | sort | uniq)

    # Gabungkan data user menjadi JSON array
    local user_json=$(IFS=,; echo "[${users[*]}]")

    # Output JSON satu baris tanpa header Content-Type
    echo "{\"status\":\"success\",\"total_user\":$total_user,\"users\":$user_json}"
    return 0
}

# Main execution
if [[ "$REQUEST_METHOD" == "GET" ]]; then
    # Jika dipanggil via HTTP (misal dari API)
    cek_daftar_user
    exit 0
fi

# Jika dijalankan langsung dari terminal (interaktif)
if [ -t 0 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    NC='\033[0m'
    BGWHITE='\e[0;100;37m'
    users_data=$(cek_daftar_user)
    total_user=$(echo "$users_data" | jq -r '.total_user' 2>/dev/null || echo 0)
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BGWHITE}       Daftar User VMESS          ${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    if [ "$total_user" = "0" ]; then
        echo -e "Tidak ada user Vmess yang terdaftar!"
    else
        echo -e "USERNAME\tEXPIRED DATE"
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo "$users_data" | jq -r '.users[] | "\(.username)\t\(.expired)"' 2>/dev/null
    fi
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    read -p "Tekan tombol apapun untuk kembali ke menu"
fi
