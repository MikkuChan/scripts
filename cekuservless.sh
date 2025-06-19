#!/bin/bash
# =================================================================
# Script untuk mengecek dan menampilkan daftar user VLESS
# Support: HTTP GET API dan Terminal
# Format Config: #& username expired_date
# =================================================================

# Fungsi untuk output JSON (tanpa header Content-Type)
json_output() {
    echo "$1"
    exit $2
}

# Cek mode (HTTP GET atau terminal)
if [ "$REQUEST_METHOD" = "GET" ]; then
    INTERACTIVE=false
else
    INTERACTIVE=true
    clear
fi

# Fungsi utama untuk mendapatkan data user
get_vless_users() {
    declare -A users
    local config_file="/etc/xray/config.json"
    local user_count=0

    if [ ! -f "$config_file" ]; then
        echo "[]"
        return 1
    fi

    while IFS= read -r line; do
        if [[ "$line" =~ ^\#\&\ ([^ ]+)\ (.+) ]]; then
            username="${BASH_REMATCH[1]}"
            expired="${BASH_REMATCH[2]}"
            users["$username"]="$expired"
            ((user_count++))
        fi
    done < "$config_file"

    if [ $user_count -gt 0 ]; then
        local json_users=()
        for user in "${!users[@]}"; do
            json_users+=("{\"username\":\"$user\",\"expired\":\"${users[$user]}\"}")
        done
        echo "[$(IFS=,; echo "${json_users[*]}")]"
    else
        echo "[]"
    fi
}

# Main program
users_data=$(get_vless_users)
user_count=$(echo "$users_data" | jq 'length' 2>/dev/null || echo 0)

if $INTERACTIVE; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    NC='\033[0m'
    BGWHITE='\e[0;100;37m'
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BGWHITE}        Daftar User VLESS         ${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    if [ $user_count -eq 0 ]; then
        echo -e "\nTidak ada user VLESS yang terdaftar!\n"
    else
        echo -e "USERNAME\tEXPIRED DATE"
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo "$users_data" | jq -r '.[] | "\(.username)\t\(.expired)"' 2>/dev/null
    fi

    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    read -p "Tekan enter untuk kembali ke menu"
    m-vless 2>/dev/null || exit 0
else
    if [ $user_count -eq 0 ]; then
        json_output "{\"status\":\"success\",\"message\":\"No VLESS users found\",\"users\":[],\"count\":0}" 0
    else
        json_output "{\"status\":\"success\",\"count\":$user_count,\"users\":$users_data}" 0
    fi
fi
