#!/bin/bash
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Script untuk mengecek daftar user SSH/OpenVPN
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Output: Jika via HTTP GET, hasil hanya JSON satu baris tanpa header Content-Type.

# Fungsi untuk output JSON
output_json() {
    echo "$1"
    exit $2
}

# Cek jika dipanggil via HTTP GET
if [ "$REQUEST_METHOD" = "GET" ]; then
    interactive_mode=false
else
    interactive_mode=true
fi

users=()

# Loop untuk membaca setiap baris dari file /etc/passwd
while read expired
do
    AKUN="$(echo $expired | cut -d: -f1)"
    ID="$(echo $expired | grep -v nobody | cut -d: -f3)"
    if [[ $ID -ge 1000 ]]; then
        exp="$(chage -l $AKUN | grep "Account expires" | awk -F": " '{print $2}')"
        status="$(passwd -S $AKUN | awk '{print $2}' )"
        users+=("{\"username\":\"$AKUN\",\"expired\":\"$exp\",\"status\":\"$status\"}")
    fi
done < /etc/passwd

if [ "$interactive_mode" = false ]; then
    # Output JSON satu baris tanpa header Content-Type
    output_json "{\"status\":\"success\",\"users\":[$(IFS=,; echo "${users[*]}")]}" 0
else
    RED='\e[1;31m'
    GREEN='\e[0;32m'
    YELLOW='\e[0;33m'
    NC='\e[0m'
    BGWHITE='\e[0;100;37m'
    clear
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo -e "${YELLOW}${BGWHITE}            MEMBER SSH OPENVPN            ${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo "USERNAME          EXP DATE          "
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    for user in "${users[@]}"; do
        username=$(echo "$user" | jq -r '.username')
        exp=$(echo "$user" | jq -r '.expired')
        status=$(echo "$user" | jq -r '.status')
        printf "%-17s %2s %-17s %2s \n" "$username" "$exp     "
    done
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
fi
