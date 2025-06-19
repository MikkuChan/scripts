#!/bin/bash
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Script untuk mengecek dan menampilkan daftar user Trojan
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Fungsi untuk output JSON tanpa header Content-Type
output_json() {
    echo "$1"
    exit $2
}

# Cek jika dipanggil via HTTP GET
[ "$REQUEST_METHOD" = "GET" ] && interactive_mode=false || interactive_mode=true

# Fungsi untuk mendapatkan user unik (tanpa duplikat WS/gRPC)
get_unique_trojan_users() {
    declare -A unique_users
    while read -r line; do
        if [[ "$line" =~ ^\#\!\ ([^ ]+)\ (.+) ]]; then
            username="${BASH_REMATCH[1]}"
            expired="${BASH_REMATCH[2]}"
            unique_users["$username"]="$expired"
        fi
    done < "/etc/xray/config.json"
    local users=()
    for user in "${!unique_users[@]}"; do
        users+=("{\"username\":\"$user\",\"expired\":\"${unique_users[$user]}\"}")
    done
    [ ${#users[@]} -eq 0 ] && echo "[]" || echo "[$(IFS=,; echo "${users[*]}")]"
}

# Main program
users_json=$(get_unique_trojan_users)
count=$(echo "$users_json" | jq 'length')

if [ "$interactive_mode" = true ]; then
    RED='\e[1;31m'
    GREEN='\e[0;32m'
    YELLOW='\e[0;33m'
    NC='\e[0m'
    BGWHITE='\e[0;100;37m'
    clear
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo -e "${BGWHITE}         Daftar Akun Trojan        ${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    if [ "$count" -eq 0 ]; then
        echo "Tidak ada user Trojan"
    else
        echo -e "USERNAME\tEXPIRED DATE"
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
        echo "$users_json" | jq -r '.[] | "\(.username)\t\(.expired)"'
    fi
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    read -p "Tekan enter untuk kembali"
    m-trojan
else
    if [ "$count" -eq 0 ]; then
        output_json "{\"status\":\"success\",\"message\":\"No Trojan users found\",\"users\":[],\"count\":0}" 0
    else
        output_json "{\"status\":\"success\",\"users\":$users_json,\"count\":$count}" 0
    fi
fi
