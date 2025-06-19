#!/bin/bash
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Script untuk menghapus user SSH/OpenVPN via CLI atau API
# Support pemanggilan HTTP GET dengan parameter:
# Contoh: ./deletessh.sh?user=namauser&auth=fadznewbie_do
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Definisi warna untuk tampilan terminal
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
NC='\e[0m'               # No Color (reset warna)
BGWHITE='\e[0;100;37m'   # Background putih dengan teks hitam
# Fungsi untuk menampilkan bantuan
tampilkan_bantuan() {
    echo -e "${YELLOW}Penggunaan:${NC}"
    echo -e "  CLI : ./deletessh.sh (interaktif)"
    echo -e "  HTTP: ./deletessh.sh?user=USERNAME&auth=fadznewbie_do"
}
# Fungsi untuk menghapus user
hapus_user() {
    local username=$1
    local via_api=$2
    
    # Cek apakah user ada
    if getent passwd "$username" > /dev/null 2>&1; then
        # Hapus user dan home directory-nya
        userdel -r "$username" > /dev/null 2>&1
        
        # Hapus dari file config lain jika perlu (contoh: /etc/xray/config.json)
        # [Tambahkan kode Anda di sini jika diperlukan]
        
        # Tampilkan hasil
        if [ "$via_api" = true ]; then
            echo -e "{\"status\":\"success\",\"message\":\"User $username berhasil dihapus\"}"
        else
            echo -e "${GREEN}User $username berhasil dihapus!${NC}"
            read -p "Tekan enter untuk kembali ke menu"
        fi
        return 0
    else
        if [ "$via_api" = true ]; then
            echo -e "{\"status\":\"error\",\"message\":\"User $username tidak ditemukan\"}"
        else
            echo -e "${RED}Gagal: User $username tidak ditemukan!${NC}"
            read -p "Tekan enter untuk mencoba lagi"
        fi
        return 1
    fi
}
# Fungsi untuk mode interaktif (CLI)
mode_interaktif() {
    clear
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BGWHITE}          HAPUS USER SSH/OpenVPN          ${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Tampilkan daftar user
    echo "Daftar User:"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    cut -d: -f1,3 /etc/passwd | grep -E ":[0-9]{4}$" | cut -d: -f1 | sort | column
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Minta input username
    read -p "Masukkan username yang akan dihapus: " username
    
    # Validasi input
    if [ -z "$username" ]; then
        echo -e "${RED}Error: Username tidak boleh kosong!${NC}"
        read -p "Tekan enter untuk mencoba lagi"
        mode_interaktif
        return
    fi
    
    # Proses penghapusan
    hapus_user "$username" false
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
        echo -e "{\"status\":\"error\",\"message\":\"Parameter user dan auth diperlukan\"}"
        exit 1
    fi
    
    # Validasi kunci autentikasi
    if [ "${params[auth]}" != "fadznewbie_do" ]; then
        echo -e "{\"status\":\"error\",\"message\":\"Kunci autentikasi salah\"}"
        exit 1
    fi
    
    # Jalankan penghapusan user via API
    hapus_user "${params[user]}" true
    
else
    # Jalankan mode interaktif (CLI)
    mode_interaktif
fi
