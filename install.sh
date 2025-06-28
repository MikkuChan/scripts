#!/bin/bash
# =============================================================================
# VPN API Installation Script - FadzDigital
# Version: 2.0 (MikkuChan)
# =============================================================================

set -e

# Definisi warna
declare -r RED='\033[1;31m'
declare -r GREEN='\033[1;32m'
declare -r YELLOW='\033[1;33m'
declare -r BLUE='\033[1;34m'
declare -r PURPLE='\033[1;35m'
declare -r CYAN='\033[1;36m'
declare -r WHITE='\033[1;37m'
declare -r ORANGE='\033[1;38;5;208m'
declare -r PINK='\033[1;38;5;213m'
declare -r BOLD='\033[1m'
declare -r DIM='\033[2m'
declare -r BLINK='\033[5m'
declare -r NC='\033[0m'

# Gradient color array untuk animasi
declare -a GRADIENT=(
    '\033[1;34m'  # Blue
    '\033[1;35m'  # Purple
    '\033[1;36m'  # Cyan
    '\033[1;32m'  # Green
    '\033[1;33m'  # Yellow
    '\033[1;31m'  # Red
)

# Konfigurasi
declare -r REPO="MikkuChan/scripts"
declare -r BRANCH="main"
declare -r RAW_URL="https://raw.githubusercontent.com/$REPO/$BRANCH"
declare -r INSTALL_DIR="/opt/vpn-api"
declare -r SCRIPT_DIR="$INSTALL_DIR/scripts"
declare -r SERVICE_NAME="vpn-api"
declare -r LOG_FILE="/var/log/vpn-api-install.log"

# Variable global untuk menyimpan AUTHKEY
declare USER_AUTHKEY=""

# Banner
print_banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    local banner_lines=(
        "╭━━━╮╱╱╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╭╮╱╱╱╭╮"
        "┃╭━━╯╱╱╱╱┃┃╱╱╱╱╱┃┃╱╱╱╭╯╰╮╱╱┃┃"
        "┃╰━━┳━━┳━╯┣━━━┳━╯┣┳━━╋╮╭╋━━┫┃"
        "┃╭━━┫╭╮┃╭╮┣━━┃┃╭╮┣┫╭╮┣┫┃┃╭╮┃┃"
        "┃┃╱╱┃╭╮┃╰╯┃┃━━┫╰╯┃┃╰╯┃┃╰┫╭╮┃╰╮"
        "╰╯╱╱╰╯╰┻━━┻━━━┻━━┻┻━╮┣┻━┻╯╰┻━╯"
        "╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╭━╯┃"
        "╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╰━━╯"
        "                               "
        "          fadzDigital Zone         "
    )
    for line in "${banner_lines[@]}"; do
        echo -e "${CYAN}${BOLD}${line}${NC}"
    done
    echo -e "${NC}"
    echo -e "${CYAN}${BOLD}"
    local loading_text="Memulai instalasi"
    local dots=""
    for i in {1..10}; do
        dots+="."
        printf "\r${YELLOW}${BOLD}${loading_text}${PINK}${dots}${NC}"
        sleep 0.2
    done
    echo -e "\n${GREEN}${BOLD}✨ Siap untuk menginstall! ✨${NC}\n"
    sleep 1
}

# Fungsi logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Animasi spinner
spinner() {
    local pid=$1
    local message="$2"
    local delay=0.08
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local temp
    while kill -0 $pid 2>/dev/null; do
        temp=${spinstr:0:1}
        printf "\r${GRADIENT[$((RANDOM % ${#GRADIENT[@]}))]}${temp}${NC} ${CYAN}${BOLD}${message}${NC}"
        spinstr=${spinstr:1}${temp}
        sleep $delay
    done
    wait $pid
    local exit_code=$?
    if [ $exit_code -eq 0 ]; then
        printf "\r${GREEN}${BOLD}✅${NC} ${WHITE}${message}${NC} ${GREEN}${BOLD}[BERHASIL]${NC}\n"
        log "SUKSES: $message"
    else
        printf "\r${RED}${BOLD}❌${NC} ${WHITE}${message}${NC} ${RED}${BOLD}[GAGAL]${NC}\n"
        log "GAGAL: $message"
        return $exit_code
    fi
}

# Fungsi eksekusi
run() {
    local cmd="$1"
    local retries=3
    local attempt=1
    log "Menjalankan: ${cmd}"
    while [ $attempt -le $retries ]; do
        {
            eval "$cmd"
        } &
        local pid=$!
        spinner $pid "$cmd (Percobaan $attempt/$retries)"
        if [ $? -eq 0 ]; then
            return 0
        fi
        attempt=$((attempt + 1))
        if [ $attempt -le $retries ]; then
            echo -e "${YELLOW}${BOLD}⚡ Mencoba lagi dalam 3 detik...${NC}"
            sleep 3
        fi
    done
    echo -e "${RED}${BOLD}❌ Gagal menjalankan: ${cmd}${NC}"
    exit 1
}

# Progress bar dengan animasi
progress_bar() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local completed=$((current * width / total))
    local remaining=$((width - completed))
    printf "\r${PURPLE}${BOLD}Progress: ${NC}${CYAN}[${NC}"
    printf "%${completed}s" | tr ' ' '█'
    printf "%${remaining}s" | tr ' ' '░'
    printf "${CYAN}]${NC} ${WHITE}${BOLD}%3d%%${NC} ${BLUE}(${current}/${total})${NC} " "$percentage"
    sleep 0.03
}

# Fungsi untuk input AUTHKEY
get_authkey_input() {
    echo -e "${CYAN}${BOLD}🔐 Masukkan Authentication Key (AUTHKEY) untuk API:${NC}"
    while true; do
        read -rp "   AUTHKEY: " USER_AUTHKEY
        if [[ -n "$USER_AUTHKEY" ]]; then
            echo -e "${GREEN}${BOLD}✅ AUTHKEY berhasil dimasukkan${NC}\n"
            log "AUTHKEY input received from user"
            break
        else
            echo -e "${RED}${BOLD}❌ AUTHKEY tidak boleh kosong! Silakan masukkan AUTHKEY yang valid.${NC}"
        fi
    done
}

# Cek prasyarat
check_prerequisites() {
    echo -e "${YELLOW}${BOLD}🔍 Memeriksa prasyarat sistem...${NC}\n"
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}${BOLD}❌ Script ini harus dijalankan sebagai root${NC}"
        echo -e "${BLUE}   Jalankan: ${YELLOW}sudo $0${NC}"
        exit 1
    fi
    echo -e "${CYAN}Memeriksa koneksi internet...${NC}"
    ping_dots=""
    for i in {1..10}; do
        ping_dots+="."
        printf "\r${YELLOW}${BOLD}Ping ke server${PINK}${ping_dots}${NC}"
        sleep 0.1
    done
    if ! ping -c 1 github.com &> /dev/null; then
        echo -e "\r${RED}${BOLD}❌ Tidak ada koneksi internet${NC}\n"
        exit 1
    fi
    echo -e "\r${GREEN}${BOLD}✅ Koneksi internet tersedia${NC}                  \n"
    echo -e "${GREEN}${BOLD}✅ Prasyarat sistem sudah terpenuhi ✅${NC}"
    sleep 1
}

# Cek instalasi yang sudah ada
check_existing_installation() {
    if [ -d "${INSTALL_DIR}" ] || pm2 show "${SERVICE_NAME}" &>/dev/null; then
        echo -e "${YELLOW}${BOLD}⚠️  Instalasi sebelumnya ditemukan${NC}"
        echo -e "${BLUE}   • Direktori instalasi: ${WHITE}${INSTALL_DIR}${NC}"
        echo -e "${BLUE}   • Status PM2: ${WHITE}$(pm2 show $SERVICE_NAME 2>/dev/null | grep -o 'status.*online\|status.*stopped' | head -1 || echo 'tidak ditemukan')${NC}"
        echo
        while true; do
            echo -e "${CYAN}${BOLD}Apakah Anda ingin menghapus instalasi lama dan install ulang? [Y/n]: ${NC}"
            read -r response
            case "${response}" in
                [Yy]|[Yy][Ee][Ss]|"")
                    remove_existing_installation
                    break
                    ;;
                [Nn]|[Nn][Oo])
                    echo -e "${RED}${BOLD}❌ Instalasi dibatalkan oleh pengguna${NC}"
                    exit 0
                    ;;
                *)
                    echo -e "${YELLOW}Silakan masukkan yes atau no${NC}"
                    ;;
            esac
        done
    fi
}

# Hapus instalasi lama
remove_existing_installation() {
    echo -e "${YELLOW}${BOLD}🗑️  Menghapus instalasi sebelumnya...${NC}\n"
    if pm2 show "${SERVICE_NAME}" &>/dev/null; then
        run "pm2 stop $SERVICE_NAME"
        run "pm2 delete $SERVICE_NAME"
    fi
    if [ -d "${INSTALL_DIR}" ]; then
        run "rm -rf ${INSTALL_DIR}"
    fi
    echo -e "${GREEN}${BOLD}✅ Instalasi sebelumnya berhasil dihapus ✅${NC}\n"
    sleep 1
}

# ===============================
# Install dependencies (REVISI)
# ===============================
install_dependencies() {
    echo -e "${YELLOW}${BOLD}📦 Menginstall paket yang diperlukan...${NC}\n"

    # Update APT repository
    run "apt-get update -y"

    # Install basic packages dulu
    packages=("curl" "wget" "git")
    total=${#packages[@]}
    current=0
    for package in "${packages[@]}"; do
        current=$((current + 1))
        if ! command -v "${package}" >/dev/null 2>&1 && ! dpkg -l | grep -q "^ii  $package "; then
            progress_bar $current $total
            run "apt-get install -y $package"
        else
            progress_bar $current $total
            log "DILEWATI: $package sudah terinstall"
            sleep 0.1
        fi
    done

    echo -e "\n${CYAN}${BOLD}🔗 Menambahkan NodeSource repository untuk Node.js LTS (20.x)...${NC}"
    # Tambah NodeSource repo
    run "curl -fsSL https://deb.nodesource.com/setup_20.x | bash -"
    run "apt-get install -y nodejs"

    # Verifikasi versi Node.js
    NODE_VERSION=$(node -v)
    echo -e "${GREEN}${BOLD}✅ Node.js berhasil diinstall: ${NODE_VERSION}${NC}"
    log "Node.js versi terpasang: ${NODE_VERSION}"

    echo -e "${YELLOW}${BOLD}📦 Menginstall PM2 secara global...${NC}"
    if ! command -v pm2 >/dev/null 2>&1; then
        run "npm install -g pm2"
    fi
    echo -e "${GREEN}${BOLD}✅ PM2 berhasil diinstall ✅${NC}\n"
    sleep 1
}

# Buat struktur direktori
create_directories() {
    echo -e "${YELLOW}${BOLD}📁 Membuat struktur direktori...${NC}\n"
    run "mkdir -p $INSTALL_DIR"
    run "mkdir -p $SCRIPT_DIR"
    run "mkdir -p /var/log/vpn-api"
    run "chown -R root:root $INSTALL_DIR"
    echo -e "${GREEN}${BOLD}✅ Struktur direktori berhasil dibuat ✅${NC}\n"
    sleep 1
}

# Download file dari GitHub
download_files() {
    echo -e "${YELLOW}${BOLD}🔄 Memproses file instalasi...${NC}\n"
    cd "${SCRIPT_DIR}"
    main_files=("vpn-api.js" "package.json")
    total_files=0
    current_file=0
    total_files=${#main_files[@]}
    sh_files=$(curl -s "https://api.github.com/repos/$REPO/contents?ref=$BRANCH" | grep 'name.*\.sh' | cut -d '"' -f4 | grep -v 'install.sh' | wc -l)
    total_files=$((total_files + sh_files))
    for file in "${main_files[@]}"; do
        current_file=$((current_file + 1))
        progress_bar $current_file $total_files
        if curl -fsSL "${RAW_URL}/${file}" -o "${SCRIPT_DIR}/${file}"; then
            log "DIUNDUH: $file"
            sleep 0.1
        else
            echo -e "\n${RED}${BOLD}❌ Gagal Memproses file instalasi ${file}${NC}"
            exit 1
        fi
    done
    sh_file_list=$(curl -s "https://api.github.com/repos/$REPO/contents?ref=$BRANCH" | grep 'name.*\.sh' | cut -d '"' -f4 | grep -v 'install.sh')
    for file in $sh_file_list; do
        current_file=$((current_file + 1))
        progress_bar $current_file $total_files
        if curl -fsSL "${RAW_URL}/${file}" -o "${SCRIPT_DIR}/${file}"; then
            chmod +x "${SCRIPT_DIR}/${file}"
            log "DIUNDUH: $file"
            sleep 0.1
        else
            echo -e "\n${RED}${BOLD}❌ Gagal Memproses file instalasi ${file}${NC}"
            exit 1
        fi
    done
    echo -e "\n${GREEN}${BOLD}✅ Semua file berhasil diunduh ✅${NC}\n"
    sleep 1
}

# Install Node.js dependencies
install_node_modules() {
    echo -e "${YELLOW}${BOLD}📦 Menginstall dependencies Node.js...${NC}\n"
    cd "${SCRIPT_DIR}"
    if [ -f "package.json" ]; then
        run "npm install --production --silent"
        echo -e "${GREEN}${BOLD}✅ Dependencies Node.js berhasil diinstall ✅${NC}\n"
    else
        echo -e "${YELLOW}⚠️  package.json tidak ditemukan, melewati npm install${NC}\n"
    fi
    sleep 1
}

# Buat file .env DI SCRIPT_DIR
create_env_file() {
    echo -e "${YELLOW}${BOLD}🔐 Membuat file konfigurasi .env...${NC}\n"
    local env_path="${SCRIPT_DIR}/.env"
    if [ ! -d "${SCRIPT_DIR}" ]; then
        echo -e "${RED}${BOLD}❌ Direktori script tidak ditemukan!${NC}"
        exit 1
    fi
    if [ -n "$USER_AUTHKEY" ]; then
        echo "AUTHKEY=$USER_AUTHKEY" > "$env_path"
        chmod 600 "$env_path"
        chown root:root "$env_path"
        if [ -f "$env_path" ] && [ -s "$env_path" ]; then
            echo -e "${GREEN}${BOLD}✅ File .env berhasil dibuat di ${env_path}${NC}"
            echo -e "${WHITE}   • AUTHKEY: ${GREEN}${USER_AUTHKEY}${NC}"
            echo -e "${WHITE}   • Permission: ${GREEN}600 (read/write owner only)${NC}"
            log "File .env created successfully with AUTHKEY: $USER_AUTHKEY"
        else
            echo -e "${RED}${BOLD}❌ Gagal membuat file .env${NC}"
            exit 1
        fi
    else
        echo -e "${RED}${BOLD}❌ AUTHKEY tidak tersedia untuk membuat file .env${NC}"
        exit 1
    fi
    echo
    sleep 1
}

# Jalankan service dengan PM2
start_service() {
    echo -e "${YELLOW}${BOLD}🚀 Memulai VPN API service dengan PM2...${NC}\n"
    cd "${SCRIPT_DIR}"
    
    # Start aplikasi dengan PM2
    run "pm2 start vpn-api.js --name $SERVICE_NAME"
    
    # Save PM2 process list
    run "pm2 save"
    
    # Setup PM2 startup
    run "pm2 startup systemd -u root --hp /root"
    
    sleep 2
    if pm2 show "${SERVICE_NAME}" | grep -q "online"; then
        echo -e "${GREEN}${BOLD}✅ VPN API service berhasil dimulai dengan PM2 ✅${NC}\n"
    else
        echo -e "${RED}${BOLD}❌ Gagal memulai VPN API service${NC}"
        echo -e "${YELLOW}   Periksa log dengan: ${CYAN}pm2 logs ${SERVICE_NAME}${NC}\n"
        exit 1
    fi
    sleep 1
}

# Tampilkan ringkasan
show_summary() {
    echo -e "${PURPLE}${BOLD}════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}${BOLD}               🎉 INSTALASI BERHASIL DISELESAIKAN! 🎉${NC}"
    echo -e "${PURPLE}${BOLD}════════════════════════════════════════════════════════════════════${NC}\n"
    echo -e "${CYAN}${BOLD}📋 Ringkasan Instalasi:${NC}"
    echo -e "${WHITE}   • Direktori Instalasi: ${GREEN}${INSTALL_DIR}${NC}"
    echo -e "${WHITE}   • Direktori Script: ${GREEN}${SCRIPT_DIR}${NC}"
    echo -e "${WHITE}   • Nama Service: ${GREEN}${SERVICE_NAME}${NC}"
    echo -e "${WHITE}   • Status PM2: ${GREEN}$(pm2 show ${SERVICE_NAME} 2>/dev/null | grep -o 'status.*online\|status.*stopped' | head -1 || echo 'tidak aktif')${NC}"
    echo -e "${WHITE}   • File Log: ${GREEN}${LOG_FILE}${NC}"
    echo -e "${WHITE}   • File .env: ${GREEN}${SCRIPT_DIR}/.env${NC}"
    if [ -f "${SCRIPT_DIR}/.env" ]; then
        echo -e "${WHITE}   • Status .env: ${GREEN}✅ Berhasil dibuat${NC}"
        echo -e "${WHITE}   • AUTHKEY: ${GREEN}${USER_AUTHKEY}${NC}"
    else
        echo -e "${WHITE}   • Status .env: ${RED}❌ Tidak ditemukan${NC}"
    fi
    echo
    echo -e "${CYAN}${BOLD}🔧 Perintah PM2 Berguna:${NC}"
    echo -e "${WHITE}   • Cek status service: ${YELLOW}pm2 status ${SERVICE_NAME}${NC}"
    echo -e "${WHITE}   • Lihat log service: ${YELLOW}pm2 logs ${SERVICE_NAME}${NC}"
    echo -e "${WHITE}   • Restart service: ${YELLOW}pm2 restart ${SERVICE_NAME}${NC}"
    echo -e "${WHITE}   • Stop service: ${YELLOW}pm2 stop ${SERVICE_NAME}${NC}"
    echo -e "${WHITE}   • Monitor semua process: ${YELLOW}pm2 monit${NC}"
    echo -e "${WHITE}   • Edit .env: ${YELLOW}nano ${SCRIPT_DIR}/.env${NC}\n"
    echo -e "${PINK}${BOLD}✨ Powered by FadzDigital ✨${NC}"
    echo -e "${ORANGE}${BOLD}🚀 Premium VPN Management System 🚀${NC}"
    echo -e "${PURPLE}${BOLD}════════════════════════════════════════════════════════════════════${NC}\n"
    success_msg="🎊 INSTALASI SELESAI! 🎊"
    echo -e "${GREEN}${BOLD}${BLINK}"
    for ((i=0; i<${#success_msg}; i++)); do
        printf "%s" "${success_msg:$i:1}"
        sleep 0.05
    done
    echo -e "${NC}\n"
    echo -e "${CYAN}${BOLD}Terima kasih telah menggunakan FadzDigital VPN API!${NC}"
    echo -e "${YELLOW}${BOLD}Untuk support dan update, kunjungi: https://github.com/MikkuChan/scripts${NC}\n"
}

main() {
    touch "${LOG_FILE}"
    log "VPN API Installation Started"
    print_banner
    get_authkey_input
    check_prerequisites
    check_existing_installation
    install_dependencies
    create_directories
    download_files
    install_node_modules
    create_env_file
    start_service
    show_summary
    log "VPN API Installation Completed Successfully"
}

trap 'echo -e "\n${RED}${BOLD}❌ Instalasi terinterupsi!${NC}\n"; log "Installation interrupted"; exit 1' INT TERM
main "$@"
