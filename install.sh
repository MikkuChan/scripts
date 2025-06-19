#!/bin/bash
# =============================================================================
# VPN API Installation Script - FadzDigital
# Otomatis download file dari GitHub dengan fitur lengkap
# Versi: 2.0
# =============================================================================

set -e

# Definisi warna
declare -r RED='\033[0;31m'
declare -r GREEN='\033[0;32m'
declare -r YELLOW='\033[1;33m'
declare -r BLUE='\033[0;34m'
declare -r PURPLE='\033[0;35m'
declare -r CYAN='\033[0;36m'
declare -r WHITE='\033[1;37m'
declare -r BOLD='\033[1m'
declare -r NC='\033[0m'

# Konfigurasi
declare -r REPO="MikkuChan/scripts"
declare -r BRANCH="main"
declare -r RAW_URL="https://raw.githubusercontent.com/$REPO/$BRANCH"
declare -r INSTALL_DIR="/opt/vpn-api"
declare -r SCRIPT_DIR="$INSTALL_DIR/scripts"
declare -r SERVICE_NAME="vpn-api"
declare -r LOG_FILE="/var/log/vpn-api-install.log"

# Banner
print_banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    cat << 'EOF'
 ███████╗ █████╗ ██████╗ ███████╗██████╗ ██╗ ██████╗ ██╗████████╗ █████╗ ██╗     
 ██╔════╝██╔══██╗██╔══██╗╚══███╔╝██╔══██╗██║██╔════╝ ██║╚══██╔══╝██╔══██╗██║     
 █████╗  ███████║██║  ██║  ███╔╝ ██║  ██║██║██║  ███╗██║   ██║   ███████║██║     
 ██╔══╝  ██╔══██║██║  ██║ ███╔╝  ██║  ██║██║██║   ██║██║   ██║   ██╔══██║██║     
 ██║     ██║  ██║██████╔╝███████╗██████╔╝██║╚██████╔╝██║   ██║   ██║  ██║███████╗
 ╚═╝     ╚═╝  ╚═╝╚═════╝ ╚══════╝╚═════╝ ╚═╝ ╚═════╝ ╚═╝   ╚═╝   ╚═╝  ╚═╝╚══════╝
EOF
    echo -e "${NC}"
    echo -e "${PURPLE}${BOLD}═══════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}${BOLD}                         INSTALLER VPN API v2.0                       ${NC}"
    echo -e "${GREEN}${BOLD}                           by FadzDigital                             ${NC}"
    echo -e "${PURPLE}${BOLD}═══════════════════════════════════════════════════════════════════════${NC}"
    echo
}

# Fungsi logging
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Spinner dengan progress
spinner() {
    local pid=$1
    local message="$2"
    local delay=0.1
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0
    
    while kill -0 $pid 2>/dev/null; do
        printf "\r${BLUE}${BOLD}%c${NC} ${WHITE}%s${NC}" "${spin:$i:1}" "$message"
        sleep $delay
        i=$(((i + 1) % 10))
    done
    
    wait $pid
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        printf "\r${GREEN}${BOLD}✓${NC} ${WHITE}%s${NC} ${GREEN}[BERHASIL]${NC}\n" "$message"
        log "BERHASIL: $message"
    else
        printf "\r${RED}${BOLD}✗${NC} ${WHITE}%s${NC} ${RED}[GAGAL]${NC}\n" "$message"
        log "GAGAL: $message"
        return $exit_code
    fi
}

# Fungsi eksekusi dengan error handling
run() {
    local cmd="$*"
    log "MENJALANKAN: $cmd"
    
    {
        eval "$cmd"
    } &
    
    local pid=$!
    spinner $pid "$cmd"
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}${BOLD}❌ Gagal menjalankan: $cmd${NC}"
        exit 1
    fi
}

# Progress bar
progress_bar() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local completed=$((current * width / total))
    local remaining=$((width - completed))
    
    printf "\r${CYAN}[${NC}"
    printf "%*s" $completed | tr ' ' '█'
    printf "%*s" $remaining | tr ' ' '░'
    printf "${CYAN}] ${WHITE}%d%%${NC} ${YELLOW}(%d/%d)${NC}" $percentage $current $total
}

# Cek prasyarat sistem
check_prerequisites() {
    echo -e "${YELLOW}${BOLD}🔍 Memeriksa prasyarat sistem...${NC}"
    
    # Cek apakah running sebagai root
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}${BOLD}❌ Script ini harus dijalankan sebagai root${NC}"
        echo -e "${YELLOW}   Silakan jalankan: sudo $0${NC}"
        exit 1
    fi
    
    # Cek koneksi internet
    if ! ping -c 1 github.com &> /dev/null; then
        echo -e "${RED}${BOLD}❌ Tidak ada koneksi internet${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}${BOLD}✓ Prasyarat sistem terpenuhi${NC}"
}

# Cek instalasi yang sudah ada
check_existing_installation() {
    if [ -d "$INSTALL_DIR" ] || systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        echo -e "${YELLOW}${BOLD}⚠️  Ditemukan instalasi VPN API yang sudah ada${NC}"
        echo -e "${BLUE}   Direktori instalasi: ${WHITE}$INSTALL_DIR${NC}"
        echo -e "${BLUE}   Status service: ${WHITE}$(systemctl is-active $SERVICE_NAME 2>/dev/null || echo 'tidak aktif')${NC}"
        echo
        
        while true; do
            echo -e "${CYAN}${BOLD}Apakah Anda ingin menghapus instalasi lama dan install ulang? [Y/n]: ${NC}"
            read -r response
            case $response in
                [Yy]|[Yy][Ee][Ss]|"")
                    remove_existing_installation
                    break
                    ;;
                [Nn]|[Nn][Oo])
                    echo -e "${RED}${BOLD}Instalasi dibatalkan oleh pengguna${NC}"
                    exit 0
                    ;;
                *)
                    echo -e "${YELLOW}Silakan jawab ya atau tidak${NC}"
                    ;;
            esac
        done
    fi
}

# Hapus instalasi yang sudah ada
remove_existing_installation() {
    echo -e "${YELLOW}${BOLD}🗑️  Menghapus instalasi yang sudah ada...${NC}"
    
    # Stop dan disable service
    if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        run "systemctl stop $SERVICE_NAME"
        run "systemctl disable $SERVICE_NAME"
    fi
    
    # Hapus file service
    if [ -f "/etc/systemd/system/$SERVICE_NAME.service" ]; then
        run "rm -f /etc/systemd/system/$SERVICE_NAME.service"
        run "systemctl daemon-reload"
    fi
    
    # Hapus direktori instalasi
    if [ -d "$INSTALL_DIR" ]; then
        run "rm -rf $INSTALL_DIR"
    fi
    
    echo -e "${GREEN}${BOLD}✓ Instalasi lama berhasil dihapus${NC}"
}

# Install dependencies
install_dependencies() {
    echo -e "${YELLOW}${BOLD}📦 Menginstall paket yang diperlukan...${NC}"
    
    # Update daftar paket
    run "apt-get update -y"
    
    # Install paket yang diperlukan
    local packages=("curl" "wget" "nodejs" "npm" "git")
    local total=${#packages[@]}
    local current=0
    
    for package in "${packages[@]}"; do
        current=$((current + 1))
        if ! command -v "$package" >/dev/null 2>&1 && ! dpkg -l | grep -q "^ii  $package "; then
            progress_bar $current $total
            run "apt-get install -y $package"
        else
            progress_bar $current $total
            log "SKIP: $package sudah terinstall"
        fi
    done
    
    echo
    echo -e "${GREEN}${BOLD}✓ Semua paket berhasil diinstall${NC}"
}

# Buat struktur direktori
create_directories() {
    echo -e "${YELLOW}${BOLD}📁 Membuat struktur direktori...${NC}"
    
    run "mkdir -p $SCRIPT_DIR"
    run "mkdir -p /var/log/vpn-api"
    run "chown -R root:root $INSTALL_DIR"
    
    echo -e "${GREEN}${BOLD}✓ Struktur direktori berhasil dibuat${NC}"
}

# Download file-file dari GitHub
download_files() {
    echo -e "${YELLOW}${BOLD}⬇️  Mendownload file dari GitHub...${NC}"
    
    cd "$INSTALL_DIR"
    
    # Download file utama
    local main_files=("vpn-api.js" "package.json")
    local total_files=0
    local current_file=0
    
    # Hitung total file dulu
    total_files=${#main_files[@]}
    
    # Hitung file shell script
    local sh_files
    sh_files=$(curl -s "https://api.github.com/repos/$REPO/contents?ref=$BRANCH" | grep 'name.*\.sh' | cut -d '"' -f4 | grep -v 'install.sh' | wc -l)
    total_files=$((total_files + sh_files))
    
    # Download file utama
    for file in "${main_files[@]}"; do
        current_file=$((current_file + 1))
        progress_bar $current_file $total_files
        
        if curl -fsSL "$RAW_URL/$file" -o "$INSTALL_DIR/$file"; then
            log "DOWNLOADED: $file"
        else
            echo -e "\n${RED}${BOLD}❌ Gagal download $file${NC}"
            exit 1
        fi
    done
    
    # Download shell scripts
    local sh_file_list
    sh_file_list=$(curl -s "https://api.github.com/repos/$REPO/contents?ref=$BRANCH" | grep 'name.*\.sh' | cut -d '"' -f4 | grep -v 'install.sh')
    
    for file in $sh_file_list; do
        current_file=$((current_file + 1))
        progress_bar $current_file $total_files
        
        if curl -fsSL "$RAW_URL/$file" -o "$SCRIPT_DIR/$file"; then
            chmod +x "$SCRIPT_DIR/$file"
            log "DOWNLOADED: $file"
        else
            echo -e "\n${RED}${BOLD}❌ Gagal download $file${NC}"
            exit 1
        fi
    done
    
    echo
    echo -e "${GREEN}${BOLD}✓ Semua file berhasil didownload${NC}"
}

# Install Node.js dependencies
install_node_modules() {
    echo -e "${YELLOW}${BOLD}📦 Menginstall dependencies Node.js...${NC}"
    
    cd "$INSTALL_DIR"
    
    if [ -f "package.json" ]; then
        run "npm install --production --silent"
        echo -e "${GREEN}${BOLD}✓ Dependencies Node.js berhasil diinstall${NC}"
    else
        echo -e "${YELLOW}⚠️  package.json tidak ditemukan, skip npm install${NC}"
    fi
}

# Buat systemd service
create_service() {
    echo -e "${YELLOW}${BOLD}⚙️  Membuat systemd service...${NC}"
    
    cat > "/etc/systemd/system/$SERVICE_NAME.service" << EOF
[Unit]
Description=VPN API Service - FadzDigital
Documentation=https://github.com/$REPO
After=network.target network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=$SCRIPT_DIR
ExecStart=/usr/bin/node $INSTALL_DIR/vpn-api.js
ExecReload=/bin/kill -HUP \$MAINPID
Restart=always
RestartSec=5
User=root
Group=root
Environment=NODE_ENV=production
Environment=PATH=/usr/bin:/usr/local/bin
StandardOutput=journal
StandardError=journal
SyslogIdentifier=vpn-api

# Pengaturan keamanan
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$INSTALL_DIR /var/log/vpn-api /tmp

[Install]
WantedBy=multi-user.target
EOF

    run "systemctl daemon-reload"
    run "systemctl enable $SERVICE_NAME"
    
    echo -e "${GREEN}${BOLD}✓ Systemd service berhasil dibuat dan diaktifkan${NC}"
}

# Jalankan service
start_service() {
    echo -e "${YELLOW}${BOLD}🚀 Menjalankan VPN API service...${NC}"
    
    run "systemctl start $SERVICE_NAME"
    
    # Tunggu sebentar dan cek status
    sleep 2
    
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        echo -e "${GREEN}${BOLD}✓ VPN API service berhasil dijalankan${NC}"
    else
        echo -e "${RED}${BOLD}❌ Gagal menjalankan VPN API service${NC}"
        echo -e "${YELLOW}   Cek log dengan: journalctl -u $SERVICE_NAME -f${NC}"
        exit 1
    fi
}

# Tampilkan ringkasan instalasi
show_summary() {
    echo
    echo -e "${PURPLE}${BOLD}═══════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}${BOLD}                    🎉 INSTALASI BERHASIL DISELESAIKAN! 🎉${NC}"
    echo -e "${PURPLE}${BOLD}═══════════════════════════════════════════════════════════════════════${NC}"
    echo
    echo -e "${CYAN}${BOLD}📋 Ringkasan Instalasi:${NC}"
    echo -e "${WHITE}   • Direktori Instalasi: ${GREEN}$INSTALL_DIR${NC}"
    echo -e "${WHITE}   • Nama Service: ${GREEN}$SERVICE_NAME${NC}"
    echo -e "${WHITE}   • Status Service: ${GREEN}$(systemctl is-active $SERVICE_NAME)${NC}"
    echo -e "${WHITE}   • File Log: ${GREEN}$LOG_FILE${NC}"
    echo
    echo -e "${CYAN}${BOLD}🔧 Perintah Berguna:${NC}"
    echo -e "${WHITE}   • Cek status service: ${YELLOW}systemctl status $SERVICE_NAME${NC}"
    echo -e "${WHITE}   • Lihat log service: ${YELLOW}journalctl -u $SERVICE_NAME -f${NC}"
    echo -e "${WHITE}   • Restart service: ${YELLOW}systemctl restart $SERVICE_NAME${NC}"
    echo -e "${WHITE}   • Stop service: ${YELLOW}systemctl stop $SERVICE_NAME${NC}"
    echo
    echo -e "${GREEN}${BOLD}✨ Dikembangkan oleh FadzDigital ✨${NC}"
    echo -e "${PURPLE}${BOLD}═══════════════════════════════════════════════════════════════════════${NC}"
}

# Fungsi utama instalasi
main() {
    # Inisialisasi file log
    touch "$LOG_FILE"
    log "Instalasi VPN API Dimulai"
    
    print_banner
    check_prerequisites
    check_existing_installation
    install_dependencies
    create_directories
    download_files
    install_node_modules
    create_service
    start_service
    show_summary
    
    log "Instalasi VPN API Berhasil Diselesaikan"
}

# Error handling
trap 'echo -e "\n${RED}${BOLD}❌ Instalasi dihentikan!${NC}"; log "Instalasi dihentikan"; exit 1' INT TERM

# Jalankan fungsi utama
main "$@"
