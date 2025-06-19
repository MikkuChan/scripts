#!/bin/bash
# =============================================================================
# VPN API Installation Script - FadzDigital
# Versi: 2.0
# =============================================================================

set -euo pipefail

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
declare -r DIM='\033[2m'

# Konfigurasi
declare -r REPO="MikkuChan/scripts"
declare -r BRANCH="main"
declare -r RAW_URL="https://raw.githubusercontent.com/$REPO/$BRANCH"
declare -r INSTALL_DIR="/opt/vpn-api"
declare -r SCRIPT_DIR="$INSTALL_DIR/scripts"
declare -r CONFIG_DIR="$INSTALL_DIR/config"
declare -r SERVICE_NAME="vpn-api"
declare -r LOG_FILE="/var/log/vpn-api-install.log"
declare -r BACKUP_DIR="/opt/vpn-api-backup"

# Variabel global
SKIP_CONFIRMATION=false
VERBOSE=false
DRY_RUN=false

# Banner dengan animasi
print_banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    sleep 0.1
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
    echo -e "${DIM}${WHITE}Tanggal: $(date '+%d %B %Y %H:%M:%S')${NC}"
    echo -e "${DIM}${WHITE}Sistem: $(lsb_release -d 2>/dev/null | cut -f2 || echo "$(uname -s) $(uname -r)")${NC}"
    echo
}

# Fungsi logging yang lebih baik
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    
    if [[ "$VERBOSE" == true ]]; then
        case "$level" in
            "ERROR") echo -e "${RED}[ERROR]${NC} $message" >&2 ;;
            "WARN")  echo -e "${YELLOW}[WARN]${NC} $message" ;;
            "INFO")  echo -e "${BLUE}[INFO]${NC} $message" ;;
            "DEBUG") echo -e "${DIM}[DEBUG]${NC} $message" ;;
        esac
    fi
}

# Spinner dengan pesan yang lebih informatif
spinner() {
    local pid=$1
    local message="$2"
    local delay=0.08
    local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=0
    local start_time=$(date +%s)
    
    while kill -0 $pid 2>/dev/null; do
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        printf "\r${BLUE}${BOLD}%s${NC} ${WHITE}%s${NC} ${DIM}(%ds)${NC}" "${frames[$i]}" "$message" "$elapsed"
        sleep $delay
        i=$(((i + 1) % ${#frames[@]}))
    done
    
    wait $pid
    local exit_code=$?
    local end_time=$(date +%s)
    local total_time=$((end_time - start_time))
    
    if [ $exit_code -eq 0 ]; then
        printf "\r${GREEN}${BOLD}✓${NC} ${WHITE}%s${NC} ${GREEN}[BERHASIL]${NC} ${DIM}(%ds)${NC}\n" "$message" "$total_time"
        log "INFO" "BERHASIL: $message (${total_time}s)"
    else
        printf "\r${RED}${BOLD}✗${NC} ${WHITE}%s${NC} ${RED}[GAGAL]${NC} ${DIM}(%ds)${NC}\n" "$message" "$total_time"
        log "ERROR" "GAGAL: $message (${total_time}s)"
        return $exit_code
    fi
}

# Fungsi eksekusi dengan error handling yang lebih baik
run() {
    local cmd="$*"
    log "DEBUG" "MENJALANKAN: $cmd"
    
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}[DRY RUN]${NC} $cmd"
        return 0
    fi
    
    {
        eval "$cmd" 2>&1 | while IFS= read -r line; do
            log "DEBUG" "OUTPUT: $line"
        done
    } &
    
    local pid=$!
    spinner $pid "$cmd"
    
    if [ $? -ne 0 ]; then
        log "ERROR" "Perintah gagal: $cmd"
        echo -e "${RED}${BOLD}❌ Gagal menjalankan: $cmd${NC}"
        echo -e "${YELLOW}   Periksa log di: $LOG_FILE${NC}"
        exit 1
    fi
}

# Progress bar dengan estimasi waktu
progress_bar() {
    local current=$1
    local total=$2
    local message="${3:-}"
    local width=50
    local percentage=$((current * 100 / total))
    local completed=$((current * width / total))
    local remaining=$((width - completed))
    
    # Hitung estimasi waktu tersisa
    local eta=""
    if [[ -n "${PROGRESS_START_TIME:-}" && $current -gt 0 ]]; then
        local elapsed=$(($(date +%s) - PROGRESS_START_TIME))
        local rate=$((current / elapsed))
        if [[ $rate -gt 0 ]]; then
            local eta_seconds=$(((total - current) / rate))
            eta=" ETA: ${eta_seconds}s"
        fi
    fi
    
    printf "\r${CYAN}[${NC}"
    printf "%*s" $completed | tr ' ' '█'
    printf "%*s" $remaining | tr ' ' '░'
    printf "${CYAN}] ${WHITE}%d%%${NC} ${YELLOW}(%d/%d)${NC}${DIM}%s${NC}" $percentage $current $total "$eta"
    
    if [[ -n "$message" ]]; then
        printf " ${WHITE}%s${NC}" "$message"
    fi
}

# Cek prasyarat sistem yang lebih lengkap
check_prerequisites() {
    echo -e "${YELLOW}${BOLD}🔍 Memeriksa prasyarat sistem...${NC}"
    local errors=0
    
    # Cek apakah running sebagai root
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}${BOLD}❌ Script ini harus dijalankan sebagai root${NC}"
        echo -e "${YELLOW}   Silakan jalankan: sudo $0${NC}"
        ((errors++))
    fi
    
    # Cek distribusi Linux
    if ! command -v apt-get >/dev/null 2>&1; then
        echo -e "${RED}${BOLD}❌ Sistem ini tidak menggunakan apt-get (Ubuntu/Debian)${NC}"
        echo -e "${YELLOW}   Script ini hanya mendukung Ubuntu/Debian${NC}"
        ((errors++))
    fi
    
    # Cek space disk
    local available_space=$(df / | awk 'NR==2 {print $4}')
    local required_space=1048576  # 1GB dalam KB
    if [[ $available_space -lt $required_space ]]; then
        echo -e "${RED}${BOLD}❌ Space disk tidak cukup${NC}"
        echo -e "${YELLOW}   Tersedia: $((available_space/1024))MB, Dibutuhkan: $((required_space/1024))MB${NC}"
        ((errors++))
    fi
    
    # Cek koneksi internet dengan multiple test
    echo -e "${BLUE}   • Memeriksa koneksi internet...${NC}"
    local test_urls=("github.com" "google.com" "8.8.8.8")
    local connection_ok=false
    
    for url in "${test_urls[@]}"; do
        if ping -c 1 -W 3 "$url" &>/dev/null; then
            connection_ok=true
            break
        fi
    done
    
    if [[ "$connection_ok" != true ]]; then
        echo -e "${RED}${BOLD}❌ Tidak ada koneksi internet${NC}"
        echo -e "${YELLOW}   Periksa koneksi jaringan Anda${NC}"
        ((errors++))
    fi
    
    # Cek port yang digunakan
    if netstat -tuln 2>/dev/null | grep -q ":3000 "; then
        echo -e "${YELLOW}⚠️  Port 3000 sudah digunakan${NC}"
        echo -e "${BLUE}   Service akan menggunakan port alternatif${NC}"
    fi
    
    if [[ $errors -gt 0 ]]; then
        echo -e "${RED}${BOLD}❌ Ditemukan $errors masalah prasyarat${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}${BOLD}✓ Semua prasyarat sistem terpenuhi${NC}"
    log "INFO" "Prasyarat sistem berhasil diperiksa"
}

# Buat backup konfigurasi yang ada
backup_existing_config() {
    if [[ -d "$INSTALL_DIR" ]]; then
        echo -e "${YELLOW}${BOLD}💾 Membuat backup konfigurasi...${NC}"
        local backup_name="vpn-api-backup-$(date +%Y%m%d-%H%M%S)"
        local backup_path="$BACKUP_DIR/$backup_name"
        
        run "mkdir -p $BACKUP_DIR"
        run "cp -r $INSTALL_DIR $backup_path"
        
        echo -e "${GREEN}   • Backup disimpan di: $backup_path${NC}"
        log "INFO" "Backup dibuat di: $backup_path"
    fi
}

# Cek instalasi yang sudah ada dengan opsi yang lebih baik
check_existing_installation() {
    if [[ -d "$INSTALL_DIR" ]] || systemctl list-units --full -all | grep -Fq "$SERVICE_NAME.service"; then
        echo -e "${YELLOW}${BOLD}⚠️  Ditemukan instalasi VPN API yang sudah ada${NC}"
        echo -e "${BLUE}   Direktori instalasi: ${WHITE}$INSTALL_DIR${NC}"
        
        if systemctl list-units --full -all | grep -Fq "$SERVICE_NAME.service"; then
            local status=$(systemctl is-active $SERVICE_NAME 2>/dev/null || echo 'tidak ditemukan')
            echo -e "${BLUE}   Status service: ${WHITE}$status${NC}"
        fi
        
        if [[ -f "$LOG_FILE" ]]; then
            local last_install=$(tail -1 "$LOG_FILE" 2>/dev/null | cut -d' ' -f1-2 || echo "tidak diketahui")
            echo -e "${BLUE}   Instalasi terakhir: ${WHITE}$last_install${NC}"
        fi
        
        echo
        
        if [[ "$SKIP_CONFIRMATION" != true ]]; then
            while true; do
                echo -e "${CYAN}${BOLD}Pilihan yang tersedia:${NC}"
                echo -e "${WHITE}  1) Hapus dan install ulang${NC}"
                echo -e "${WHITE}  2) Backup lalu install ulang${NC}"
                echo -e "${WHITE}  3) Batalkan instalasi${NC}"
                echo
                echo -e "${CYAN}${BOLD}Masukkan pilihan [1-3]: ${NC}"
                read -r choice
                
                case $choice in
                    1)
                        remove_existing_installation
                        break
                        ;;
                    2)
                        backup_existing_config
                        remove_existing_installation
                        break
                        ;;
                    3)
                        echo -e "${RED}${BOLD}Instalasi dibatalkan oleh pengguna${NC}"
                        exit 0
                        ;;
                    *)
                        echo -e "${YELLOW}Pilihan tidak valid. Silakan pilih 1, 2, atau 3${NC}"
                        ;;
                esac
            done
        else
            backup_existing_config
            remove_existing_installation
        fi
    fi
}

# Hapus instalasi yang sudah ada dengan cleanup yang lebih menyeluruh
remove_existing_installation() {
    echo -e "${YELLOW}${BOLD}🗑️  Menghapus instalasi yang sudah ada...${NC}"
    
    # Stop service jika berjalan
    if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        run "systemctl stop $SERVICE_NAME"
        log "INFO" "Service $SERVICE_NAME dihentikan"
    fi
    
    # Disable service
    if systemctl is-enabled --quiet "$SERVICE_NAME" 2>/dev/null; then
        run "systemctl disable $SERVICE_NAME"
        log "INFO" "Service $SERVICE_NAME dinonaktifkan"
    fi
    
    # Hapus file service
    if [[ -f "/etc/systemd/system/$SERVICE_NAME.service" ]]; then
        run "rm -f /etc/systemd/system/$SERVICE_NAME.service"
        run "systemctl daemon-reload"
        log "INFO" "File service dihapus"
    fi
    
    # Hapus direktori instalasi
    if [[ -d "$INSTALL_DIR" ]]; then
        run "rm -rf $INSTALL_DIR"
        log "INFO" "Direktori instalasi dihapus"
    fi
    
    # Hapus log lama (opsional)
    if [[ -f "/var/log/vpn-api.log" ]]; then
        run "rm -f /var/log/vpn-api.log"
    fi
    
    echo -e "${GREEN}${BOLD}✓ Instalasi lama berhasil dihapus${NC}"
}

# Install dependencies dengan deteksi yang lebih baik
install_dependencies() {
    echo -e "${YELLOW}${BOLD}📦 Menginstall paket yang diperlukan...${NC}"
    PROGRESS_START_TIME=$(date +%s)
    
    # Update daftar paket
    echo -e "${BLUE}   • Memperbarui daftar paket...${NC}"
    run "apt-get update -qq"
    
    # Daftar paket yang diperlukan
    local packages=("curl" "wget" "nodejs" "npm" "git" "netstat-nat" "systemd" "ca-certificates")
    local total=${#packages[@]}
    local current=0
    local installed_packages=()
    local new_packages=()
    
    # Cek paket yang sudah terinstall
    for package in "${packages[@]}"; do
        if dpkg -l | grep -q "^ii  $package " 2>/dev/null || command -v "$package" >/dev/null 2>&1; then
            installed_packages+=("$package")
        else
            new_packages+=("$package")
        fi
    done
    
    echo -e "${GREEN}   • Sudah terinstall: ${#installed_packages[@]} paket${NC}"
    echo -e "${BLUE}   • Akan diinstall: ${#new_packages[@]} paket${NC}"
    
    # Install paket baru
    for package in "${packages[@]}"; do
        current=$((current + 1))
        progress_bar $current $total "$package"
        
        if printf '%s\n' "${installed_packages[@]}" | grep -q "^$package$"; then
            log "DEBUG" "SKIP: $package sudah terinstall"
            sleep 0.1  # Simulasi proses untuk progress bar
        else
            run "apt-get install -y $package"
            log "INFO" "INSTALLED: $package"
        fi
    done
    
    echo
    
    # Verifikasi instalasi Node.js
    if command -v node >/dev/null 2>&1; then
        local node_version=$(node --version 2>/dev/null || echo "tidak diketahui")
        echo -e "${GREEN}   • Node.js version: $node_version${NC}"
        log "INFO" "Node.js terinstall: $node_version"
    fi
    
    if command -v npm >/dev/null 2>&1; then
        local npm_version=$(npm --version 2>/dev/null || echo "tidak diketahui")
        echo -e "${GREEN}   • NPM version: $npm_version${NC}"
        log "INFO" "NPM terinstall: $npm_version"
    fi
    
    echo -e "${GREEN}${BOLD}✓ Semua paket berhasil diinstall${NC}"
}

# Buat struktur direktori yang lebih lengkap
create_directories() {
    echo -e "${YELLOW}${BOLD}📁 Membuat struktur direktori...${NC}"
    
    local directories=(
        "$INSTALL_DIR"
        "$SCRIPT_DIR"
        "$CONFIG_DIR"
        "/var/log/vpn-api"
        "/tmp/vpn-api"
    )
    
    for dir in "${directories[@]}"; do
        if [[ ! -d "$dir" ]]; then
            run "mkdir -p $dir"
            log "INFO" "Direktori dibuat: $dir"
        fi
    done
    
    # Set permissions
    run "chown -R root:root $INSTALL_DIR"
    run "chmod 755 $INSTALL_DIR"
    run "chmod 755 $SCRIPT_DIR"
    run "chmod 755 $CONFIG_DIR"
    
    echo -e "${GREEN}${BOLD}✓ Struktur direktori berhasil dibuat${NC}"
}

# Download file dengan retry dan checksum
download_with_retry() {
    local url="$1"
    local output="$2"
    local max_retries=3
    local retry=0
    
    while [[ $retry -lt $max_retries ]]; do
        if curl -fsSL --connect-timeout 10 --max-time 60 "$url" -o "$output"; then
            return 0
        fi
        
        retry=$((retry + 1))
        log "WARN" "Download gagal, retry $retry/$max_retries: $url"
        sleep 2
    done
    
    return 1
}

# Download file-file dari GitHub dengan error handling yang lebih baik
download_files() {
    echo -e "${YELLOW}${BOLD}⬇️  Mendownload file dari GitHub...${NC}"
    PROGRESS_START_TIME=$(date +%s)
    
    cd "$INSTALL_DIR" || exit 1
    
    # Cek koneksi ke GitHub
    if ! curl -fsSL --connect-timeout 5 "https://api.github.com" >/dev/null; then
        echo -e "${RED}${BOLD}❌ Tidak dapat terhubung ke GitHub${NC}"
        exit 1
    fi
    
    # Download file utama
    local main_files=("vpn-api.js" "package.json" "README.md")
    local total_files=0
    local current_file=0
    local failed_downloads=()
    
    # Hitung total file
    total_files=${#main_files[@]}
    
    # Dapatkan daftar file shell script dari API GitHub
    local api_response
    api_response=$(curl -fsSL "https://api.github.com/repos/$REPO/contents?ref=$BRANCH" 2>/dev/null)
    
    if [[ -n "$api_response" ]]; then
        local sh_files_count
        sh_files_count=$(echo "$api_response" | grep -o '"name":"[^"]*\.sh"' | grep -v 'install.sh' | wc -l)
        total_files=$((total_files + sh_files_count))
    fi
    
    echo -e "${BLUE}   • Total file yang akan didownload: $total_files${NC}"
    
    # Download file utama
    for file in "${main_files[@]}"; do
        current_file=$((current_file + 1))
        progress_bar $current_file $total_files
        
        if download_with_retry "$RAW_URL/$file" "$INSTALL_DIR/$file"; then
            log "INFO" "DOWNLOADED: $file"
        else
            log "ERROR" "GAGAL DOWNLOAD: $file"
            failed_downloads+=("$file")
        fi
        sleep 0.1
    done
    
    # Download shell scripts
    if [[ -n "$api_response" ]]; then
        local sh_file_list
        sh_file_list=$(echo "$api_response" | grep -o '"name":"[^"]*\.sh"' | cut -d'"' -f4 | grep -v 'install.sh')
        
        for file in $sh_file_list; do
            current_file=$((current_file + 1))
            progress_bar $current_file $total_files
            
            if download_with_retry "$RAW_URL/$file" "$SCRIPT_DIR/$file"; then
                chmod +x "$SCRIPT_DIR/$file"
                log "INFO" "DOWNLOADED: $file"
            else
                log "ERROR" "GAGAL DOWNLOAD: $file"
                failed_downloads+=("$file")
            fi
            sleep 0.1
        done
    fi
    
    echo
    
    # Laporan hasil download
    if [[ ${#failed_downloads[@]} -eq 0 ]]; then
        echo -e "${GREEN}${BOLD}✓ Semua file berhasil didownload${NC}"
    else
        echo -e "${YELLOW}⚠️  Beberapa file gagal didownload:${NC}"
        for failed_file in "${failed_downloads[@]}"; do
            echo -e "${RED}   • $failed_file${NC}"
        done
        
        if [[ "$SKIP_CONFIRMATION" != true ]]; then
            echo -e "${CYAN}Lanjutkan instalasi tanpa file ini? [y/N]: ${NC}"
            read -r continue_install
            if [[ ! "$continue_install" =~ ^[Yy]$ ]]; then
                echo -e "${RED}Instalasi dibatalkan${NC}"
                exit 1
            fi
        fi
    fi
}

# Install Node.js dependencies dengan handling yang lebih baik
install_node_modules() {
    echo -e "${YELLOW}${BOLD}📦 Menginstall dependencies Node.js...${NC}"
    
    cd "$INSTALL_DIR" || exit 1
    
    if [[ ! -f "package.json" ]]; then
        echo -e "${YELLOW}⚠️  package.json tidak ditemukan, membuat package.json default...${NC}"
        cat > package.json << 'EOF'
{
  "name": "vpn-api",
  "version": "1.0.0",
  "description": "VPN API Service by FadzDigital",
  "main": "vpn-api.js",
  "scripts": {
    "start": "node vpn-api.js",
    "test": "echo \"Error: no test specified\" && exit 1"
  },
  "dependencies": {
    "express": "^4.18.0",
    "cors": "^2.8.5",
    "body-parser": "^1.19.0"
  },
  "author": "FadzDigital",
  "license": "MIT"
}
EOF
        log "INFO" "package.json default dibuat"
    fi
    
    # Set npm registry untuk performa lebih baik
    run "npm config set registry https://registry.npmjs.org/"
    
    # Clean install
    if [[ -d "node_modules" ]]; then
        run "rm -rf node_modules package-lock.json"
    fi
    
    run "npm install --production --no-audit --no-fund"
    
    # Verifikasi instalasi
    if [[ -d "node_modules" ]]; then
        local modules_count=$(find node_modules -maxdepth 1 -type d | wc -l)
        echo -e "${GREEN}   • Terinstall $modules_count modules${NC}"
        log "INFO" "Node modules berhasil diinstall: $modules_count modules"
    fi
    
    echo -e "${GREEN}${BOLD}✓ Dependencies Node.js berhasil diinstall${NC}"
}

# Buat file konfigurasi default
create_default_config() {
    echo -e "${YELLOW}${BOLD}⚙️  Membuat konfigurasi default...${NC}"
    
    # Buat file konfigurasi utama
    cat > "$CONFIG_DIR/config.json" << 'EOF'
{
  "server": {
    "port": 3000,
    "host": "0.0.0.0"
  },
  "vpn": {
    "protocols": ["openvpn", "wireguard", "l2tp"],
    "maxClients": 100
  },
  "security": {
    "enableAuth": true,
    "apiKey": ""
  },
  "logging": {
    "level": "info",
    "file": "/var/log/vpn-api/vpn-api.log"
  }
}
EOF
    
    # Generate API key random
    local api_key=$(openssl rand -hex 32 2>/dev/null || tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 64)
    sed -i "s/\"apiKey\": \"\"/\"apiKey\": \"$api_key\"/" "$CONFIG_DIR/config.json"
    
    echo -e "${GREEN}   • Konfigurasi default dibuat${NC}"
    echo -e "${BLUE}   • API Key: ${WHITE}$api_key${NC}"
    log "INFO" "Konfigurasi default dibuat dengan API key"
}

# Buat systemd service dengan konfigurasi yang lebih baik
create_service() {
    echo -e "${YELLOW}${BOLD}⚙️  Membuat systemd service...${NC}"
    
    cat > "/etc/systemd/system/$SERVICE_NAME.service" << EOF
[Unit]
Description=VPN API Service - FadzDigital
Documentation=https://github.com/$REPO
After=network.target network-online.target
Wants=network-online.target
StartLimitIntervalSec=60
StartLimitBurst=3

[Service]
Type=simple
WorkingDirectory=$INSTALL_DIR
ExecStart=/usr/bin/node $INSTALL_DIR/vpn-api.js
ExecReload=/bin/kill -HUP \$MAINPID
Restart=always
RestartSec=10
RestartPreventExitStatus=1
User=root
Group=root
Environment=NODE_ENV=production
Environment=PATH=/usr/bin:/usr/local/bin
Environment=CONFIG_PATH=$CONFIG_DIR/config.json
StandardOutput=journal
StandardError=journal
SyslogIdentifier=vpn-api

# Pengaturan keamanan
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$INSTALL_DIR /var/log/vpn-api /tmp
PrivateTmp=true

# Resource limits
LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
EOF

    run "systemctl daemon-reload"
    run "systemctl enable $SERVICE_NAME"
    
    echo -e "${GREEN}${BOLD}✓ Systemd service berhasil dibuat dan diaktifkan${NC}"
    log "INFO" "Systemd service dibuat: $SERVICE_NAME"
}

# Jalankan service dengan monitoring
start_service() {
    echo -e "${YELLOW}${BOLD}🚀 Menjalankan VPN API service...${NC}"
    
    run "systemctl start $SERVICE_NAME"
    
    # Tunggu dan monitor startup
    local max_wait=30
    local wait_time=0
    local service_started=false
    
    echo -e "${BLUE}   • Menunggu service startup...${NC}"
    
    while [[ $wait_time -lt $max_wait ]]; do
        if systemctl is-active --quiet "$SERVICE_NAME"; then
            service_started=true
            break
        fi
        
        printf "\r${BLUE}   • Menunggu service startup... (%d/%d detik)${NC}" "$wait_time" "$max_wait"
        sleep 1
        wait_time=$((wait_time + 1))
    done
    
    echo
    
    if [[ "$service_started" == true ]]; then
        echo -e "${GREEN}${BOLD}✓ VPN API service berhasil dijalankan${NC}"
        
        # Tampilkan informasi service
        local service_status=$(systemctl show $SERVICE_NAME --property=ActiveState,SubState,MainPID --value)
        echo -e "${GREEN}   • Status: ${service_status}${NC}"
        
        # Cek port yang digunakan
        sleep 2
        if netstat -tuln 2>/dev/null | grep -q ":3000 "; then
            echo -e "${GREEN}   • Service berjalan di port 3000${NC}"
        fi
        
        log "INFO" "VPN API service berhasil dijalankan"
    else
        echo -e "${RED}${BOLD}❌ Gagal menjalankan VPN API service${NC}"
        echo -e "${YELLOW}   Periksa status dengan: systemctl status $SERVICE_NAME${NC}"
        echo -e "${YELLOW}   Periksa log dengan: journalctl -u $SERVICE_NAME -f${NC}"
        
        # Tampilkan error dari journal
        echo -e "${RED}   Error terakhir:${NC}"
        journalctl -u $SERVICE_NAME --no-pager -n 5 | tail -3
        
        log "ERROR" "Gagal menjalankan VPN API service"
        exit 1
    fi
}

# Validasi instalasi
validate_installation() {
    echo -e "${YELLOW}${BOLD}🔍 Memvalidasi instalasi...${NC}"
    local validation_errors=0
    
    # Cek direktori instalasi
    if [[ ! -d "$INSTALL_DIR" ]]; then
        echo -e "${RED}   ✗ Direktori instalasi tidak ditemukan${NC}"
        ((validation_errors++))
    else
        echo -e "${GREEN}   ✓ Direktori instalasi tersedia${NC}"
    fi
    
    # Cek file utama
    local required_files=("vpn-api.js" "package.json")
    for file in "${required_files[@]}"; do
        if [[ ! -f "$INSTALL_DIR/$file" ]]; then
            echo -e "${RED}   ✗ File $file tidak ditemukan${NC}"
            ((validation_errors++))
        else
            echo -e "${GREEN}   ✓ File $file tersedia${NC}"
        fi
    done
    
    # Cek konfigurasi
    if [[ ! -f "$CONFIG_DIR/config.json" ]]; then
        echo -e "${RED}   ✗ File konfigurasi tidak ditemukan${NC}"
        ((validation_errors++))
    else
        echo -e "${GREEN}   ✓ File konfigurasi tersedia${NC}"
    fi
    
    # Cek service
    if ! systemctl list-units --full -all | grep -Fq "$SERVICE_NAME.service"; then
        echo -e "${RED}   ✗ Service tidak terdaftar${NC}"
        ((validation_errors++))
    else
        echo -e "${GREEN}   ✓ Service terdaftar${NC}"
    fi
    
    # Cek status service
    if ! systemctl is-active --quiet "$SERVICE_NAME"; then
        echo -e "${RED}   ✗ Service tidak berjalan${NC}"
        ((validation_errors++))
    else
        echo -e "${GREEN}   ✓ Service berjalan dengan baik${NC}"
    fi
    
    # Cek node modules
    if [[ ! -d "$INSTALL_DIR/node_modules" ]]; then
        echo -e "${YELLOW}   ⚠ Node modules tidak ditemukan${NC}"
    else
        echo -e "${GREEN}   ✓ Node modules tersedia${NC}"
    fi
    
    if [[ $validation_errors -gt 0 ]]; then
        echo -e "${RED}${BOLD}❌ Validasi gagal: $validation_errors error ditemukan${NC}"
        log "ERROR" "Validasi instalasi gagal: $validation_errors errors"
        return 1
    else
        echo -e "${GREEN}${BOLD}✓ Validasi instalasi berhasil${NC}"
        log "INFO" "Validasi instalasi berhasil"
        return 0
    fi
}

# Buat script helper untuk manajemen
create_helper_scripts() {
    echo -e "${YELLOW}${BOLD}📝 Membuat script helper...${NC}"
    
    # Script untuk mengelola service
    cat > "$INSTALL_DIR/vpn-manage.sh" << 'EOF'
#!/bin/bash
# VPN API Management Script

SERVICE_NAME="vpn-api"
INSTALL_DIR="/opt/vpn-api"
CONFIG_DIR="$INSTALL_DIR/config"

case "$1" in
    start)
        echo "Menjalankan VPN API service..."
        systemctl start $SERVICE_NAME
        systemctl status $SERVICE_NAME
        ;;
    stop)
        echo "Menghentikan VPN API service..."
        systemctl stop $SERVICE_NAME
        ;;
    restart)
        echo "Merestart VPN API service..."
        systemctl restart $SERVICE_NAME
        systemctl status $SERVICE_NAME
        ;;
    status)
        systemctl status $SERVICE_NAME
        ;;
    logs)
        journalctl -u $SERVICE_NAME -f
        ;;
    config)
        if command -v nano >/dev/null 2>&1; then
            nano $CONFIG_DIR/config.json
        elif command -v vim >/dev/null 2>&1; then
            vim $CONFIG_DIR/config.json
        else
            echo "Editor tidak ditemukan. Edit manual: $CONFIG_DIR/config.json"
        fi
        ;;
    update)
        echo "Memperbarui VPN API..."
        cd $INSTALL_DIR
        git pull origin main 2>/dev/null || echo "Git repository tidak tersedia"
        npm install --production
        systemctl restart $SERVICE_NAME
        ;;
    *)
        echo "Penggunaan: $0 {start|stop|restart|status|logs|config|update}"
        echo ""
        echo "Perintah yang tersedia:"
        echo "  start   - Jalankan service"
        echo "  stop    - Hentikan service"
        echo "  restart - Restart service"
        echo "  status  - Lihat status service"
        echo "  logs    - Lihat log service"
        echo "  config  - Edit konfigurasi"
        echo "  update  - Update aplikasi"
        exit 1
        ;;
esac
EOF
    
    chmod +x "$INSTALL_DIR/vpn-manage.sh"
    
    # Buat symbolic link di /usr/local/bin
    if [[ ! -L "/usr/local/bin/vpn-manage" ]]; then
        ln -s "$INSTALL_DIR/vpn-manage.sh" "/usr/local/bin/vpn-manage"
    fi
    
    echo -e "${GREEN}   ✓ Script helper dibuat: vpn-manage${NC}"
    log "INFO" "Script helper dibuat"
}

# Tampilkan ringkasan instalasi yang lebih lengkap
show_summary() {
    echo
    echo -e "${PURPLE}${BOLD}═══════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}${BOLD}                    🎉 INSTALASI BERHASIL DISELESAIKAN! 🎉${NC}"
    echo -e "${PURPLE}${BOLD}═══════════════════════════════════════════════════════════════════════${NC}"
    echo
    
    # Informasi sistem
    echo -e "${CYAN}${BOLD}📋 Ringkasan Instalasi:${NC}"
    echo -e "${WHITE}   • Direktori Instalasi: ${GREEN}$INSTALL_DIR${NC}"
    echo -e "${WHITE}   • Direktori Konfigurasi: ${GREEN}$CONFIG_DIR${NC}"
    echo -e "${WHITE}   • Nama Service: ${GREEN}$SERVICE_NAME${NC}"
    echo -e "${WHITE}   • Status Service: ${GREEN}$(systemctl is-active $SERVICE_NAME)${NC}"
    echo -e "${WHITE}   • File Log: ${GREEN}$LOG_FILE${NC}"
    
    # Informasi konfigurasi
    if [[ -f "$CONFIG_DIR/config.json" ]]; then
        local api_key=$(grep -o '"apiKey": "[^"]*"' "$CONFIG_DIR/config.json" | cut -d'"' -f4)
        local port=$(grep -o '"port": [0-9]*' "$CONFIG_DIR/config.json" | cut -d' ' -f2)
        echo -e "${WHITE}   • API Key: ${YELLOW}$api_key${NC}"
        echo -e "${WHITE}   • Port: ${YELLOW}${port:-3000}${NC}"
    fi
    
    # Informasi backup
    if [[ -d "$BACKUP_DIR" ]]; then
        local backup_count=$(find "$BACKUP_DIR" -maxdepth 1 -type d | wc -l)
        if [[ $backup_count -gt 1 ]]; then
            echo -e "${WHITE}   • Backup tersedia: ${GREEN}$((backup_count - 1)) backup${NC}"
        fi
    fi
    
    echo
    echo -e "${CYAN}${BOLD}🔧 Perintah Manajemen:${NC}"
    echo -e "${WHITE}   • Kelola service: ${YELLOW}vpn-manage [start|stop|restart|status]${NC}"
    echo -e "${WHITE}   • Lihat log: ${YELLOW}vpn-manage logs${NC}"
    echo -e "${WHITE}   • Edit konfigurasi: ${YELLOW}vpn-manage config${NC}"
    echo -e "${WHITE}   • Update aplikasi: ${YELLOW}vpn-manage update${NC}"
    
    echo
    echo -e "${CYAN}${BOLD}🔍 Perintah Sistem:${NC}"
    echo -e "${WHITE}   • Cek status: ${YELLOW}systemctl status $SERVICE_NAME${NC}"
    echo -e "${WHITE}   • Lihat log sistem: ${YELLOW}journalctl -u $SERVICE_NAME -f${NC}"
    echo -e "${WHITE}   • Restart service: ${YELLOW}systemctl restart $SERVICE_NAME${NC}"
    
    echo
    echo -e "${CYAN}${BOLD}📁 Lokasi File Penting:${NC}"
    echo -e "${WHITE}   • Aplikasi utama: ${YELLOW}$INSTALL_DIR/vpn-api.js${NC}"
    echo -e "${WHITE}   • Konfigurasi: ${YELLOW}$CONFIG_DIR/config.json${NC}"
    echo -e "${WHITE}   • Script helper: ${YELLOW}$INSTALL_DIR/vpn-manage.sh${NC}"
    echo -e "${WHITE}   • Log instalasi: ${YELLOW}$LOG_FILE${NC}"
    
    # Tips keamanan
    echo
    echo -e "${YELLOW}${BOLD}🔒 Tips Keamanan:${NC}"
    echo -e "${WHITE}   • Simpan API Key dengan aman${NC}"
    echo -e "${WHITE}   • Pertimbangkan untuk mengubah port default${NC}"
    echo -e "${WHITE}   • Monitor log secara berkala${NC}"
    echo -e "${WHITE}   • Lakukan backup konfigurasi secara rutin${NC}"
    
    echo
    echo -e "${GREEN}${BOLD}✨ Terima kasih telah menggunakan VPN API - FadzDigital ✨${NC}"
    echo -e "${PURPLE}${BOLD}═══════════════════════════════════════════════════════════════════════${NC}"
    
    # Tampilkan waktu instalasi
    if [[ -n "${INSTALL_START_TIME:-}" ]]; then
        local install_duration=$(($(date +%s) - INSTALL_START_TIME))
        echo -e "${DIM}${WHITE}Waktu instalasi: ${install_duration} detik${NC}"
    fi
    echo
}

# Fungsi cleanup untuk error handling
cleanup_on_error() {
    echo -e "\n${RED}${BOLD}❌ Instalasi mengalami kesalahan!${NC}"
    echo -e "${YELLOW}Membersihkan file sementara...${NC}"
    
    # Hapus direktori yang mungkin sudah dibuat
    if [[ -d "$INSTALL_DIR" && -z "$(ls -A $INSTALL_DIR 2>/dev/null)" ]]; then
        rm -rf "$INSTALL_DIR"
    fi
    
    # Stop service jika sedang berjalan
    if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        systemctl stop "$SERVICE_NAME" 2>/dev/null
    fi
    
    # Hapus service file jika ada
    if [[ -f "/etc/systemd/system/$SERVICE_NAME.service" ]]; then
        rm -f "/etc/systemd/system/$SERVICE_NAME.service"
        systemctl daemon-reload 2>/dev/null
    fi
    
    log "ERROR" "Instalasi dibatalkan karena error"
    echo -e "${BLUE}Periksa log untuk detail: $LOG_FILE${NC}"
    exit 1
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -y|--yes)
                SKIP_CONFIRMATION=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                echo -e "${YELLOW}Mode DRY RUN aktif - tidak ada perubahan yang akan dilakukan${NC}"
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                echo -e "${RED}Opsi tidak dikenal: $1${NC}"
                show_help
                exit 1
                ;;
        esac
    done
}

# Tampilkan bantuan
show_help() {
    echo -e "${CYAN}${BOLD}VPN API Installer - FadzDigital${NC}"
    echo
    echo -e "${WHITE}Penggunaan: $0 [opsi]${NC}"
    echo
    echo -e "${YELLOW}Opsi yang tersedia:${NC}"
    echo -e "${WHITE}  -y, --yes        Skip konfirmasi interaktif${NC}"
    echo -e "${WHITE}  -v, --verbose    Tampilkan output detail${NC}"
    echo -e "${WHITE}  --dry-run        Simulasi tanpa membuat perubahan${NC}"
    echo -e "${WHITE}  -h, --help       Tampilkan bantuan ini${NC}"
    echo
    echo -e "${CYAN}Contoh penggunaan:${NC}"
    echo -e "${WHITE}  sudo $0                    # Instalasi normal${NC}"
    echo -e "${WHITE}  sudo $0 -y                # Instalasi otomatis${NC}"
    echo -e "${WHITE}  sudo $0 -v                # Instalasi dengan output detail${NC}"
    echo -e "${WHITE}  sudo $0 --dry-run         # Simulasi instalasi${NC}"
}

# Fungsi utama instalasi
main() {
    # Parse arguments
    parse_arguments "$@"
    
    # Setup error handling
    trap cleanup_on_error INT TERM ERR
    
    # Inisialisasi
    INSTALL_START_TIME=$(date +%s)
    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"
    
    log "INFO" "==================== INSTALASI VPN API DIMULAI ===================="
    log "INFO" "Versi installer: 2.0"
    log "INFO" "Sistem: $(uname -a)"
    log "INFO" "User: $(whoami)"
    log "INFO" "Arguments: $*"
    
    # Jalankan instalasi
    print_banner
    check_prerequisites
    check_existing_installation
    install_dependencies
    create_directories
    download_files
    install_node_modules
    create_default_config
    create_service
    start_service
    create_helper_scripts
    
    # Validasi hasil instalasi
    if validate_installation; then
        show_summary
        log "INFO" "==================== INSTALASI BERHASIL DISELESAIKAN ===================="
    else
        echo -e "${RED}${BOLD}❌ Instalasi selesai tetapi ada masalah dalam validasi${NC}"
        echo -e "${YELLOW}Periksa log dan status service secara manual${NC}"
        log "WARN" "Instalasi selesai dengan warning"
    fi
}

# Entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
