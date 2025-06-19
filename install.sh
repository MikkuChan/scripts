#!/bin/bash
# =============================================================================
# VPN API Installation Script - FadzDigital Enhanced
# Versi: 2.0 
# Dibuat dengan ❤️ oleh FadzDigital
# =============================================================================

set -euo pipefail

# Definisi warna yang lebih lengkap
declare -r RED='\033[0;31m'
declare -r GREEN='\033[0;32m'
declare -r YELLOW='\033[1;33m'
declare -r BLUE='\033[0;34m'
declare -r PURPLE='\033[0;35m'
declare -r CYAN='\033[0;36m'
declare -r WHITE='\033[1;37m'
declare -r BOLD='\033[1m'
declare -r DIM='\033[2m'
declare -r UNDERLINE='\033[4m'
declare -r BLINK='\033[5m'
declare -r NC='\033[0m'

# Emoji untuk tampilan yang lebih menarik
declare -r ROCKET="🚀"
declare -r FIRE="🔥"
declare -r SPARKLES="✨"
declare -r CHECK="✅"
declare -r CROSS="❌"
declare -r WARNING="⚠️"
declare -r INFO="ℹ️"
declare -r GEAR="⚙️"
declare -r PACKAGE="📦"
declare -r FOLDER="📁"
declare -r DOWNLOAD="⬇️"
declare -r TRASH="🗑️"
declare -r MAGNIFY="🔍"
declare -r PARTY="🎉"

# Konfigurasi sistem
declare -r REPO="MikkuChan/scripts"
declare -r BRANCH="main"
declare -r RAW_URL="https://raw.githubusercontent.com/$REPO/$BRANCH"
declare -r INSTALL_DIR="/opt/vpn-api"
declare -r SCRIPT_DIR="$INSTALL_DIR/scripts"
declare -r CONFIG_DIR="$INSTALL_DIR/config"
declare -r BACKUP_DIR="$INSTALL_DIR/backup"
declare -r SERVICE_NAME="vpn-api"
declare -r LOG_FILE="/var/log/vpn-api-install.log"
declare -r ERROR_LOG="/var/log/vpn-api-error.log"
declare -r TEMP_DIR="/tmp/vpn-api-install"

# Variabel global untuk tracking
declare -g INSTALL_START_TIME
declare -g CURRENT_STEP=0
declare -g TOTAL_STEPS=10

# Banner yang lebih keren dengan gradient effect
print_banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════════════════════════╗
║                                                                               ║
║  ███████╗ █████╗ ██████╗ ███████╗██████╗ ██╗ ██████╗ ██╗████████╗ █████╗ ██╗ ║
║  ██╔════╝██╔══██╗██╔══██╗╚══███╔╝██╔══██╗██║██╔════╝ ██║╚══██╔══╝██╔══██╗██║ ║
║  █████╗  ███████║██║  ██║  ███╔╝ ██║  ██║██║██║  ███╗██║   ██║   ███████║██║ ║
║  ██╔══╝  ██╔══██║██║  ██║ ███╔╝  ██║  ██║██║██║   ██║██║   ██║   ██╔══██║██║ ║
║  ██║     ██║  ██║██████╔╝███████╗██████╔╝██║╚██████╔╝██║   ██║   ██║  ██║███████╗
║  ╚═╝     ╚═╝  ╚═╝╚═════╝ ╚══════╝╚═════╝ ╚═╝ ╚═════╝ ╚═╝   ╚═╝   ╚═╝  ╚═╝╚══════╝
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    echo -e "${PURPLE}${BOLD}╔═══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}${BOLD}║${NC}${WHITE}${BOLD}                      ${FIRE} INSTALLER VPN API v2.0 ${FIRE}                       ${NC}${PURPLE}${BOLD}║${NC}"
    echo -e "${PURPLE}${BOLD}║${NC}${GREEN}${BOLD}                          ${SPARKLES} by FadzDigital ${SPARKLES}                          ${NC}${PURPLE}${BOLD}║${NC}"
    echo -e "${PURPLE}${BOLD}║${NC}${YELLOW}${DIM}                   Installer Terbaik untuk VPN API Anda                   ${NC}${PURPLE}${BOLD}║${NC}"
    echo -e "${PURPLE}${BOLD}╚═══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${CYAN}${BOLD}${INFO} Waktu mulai instalasi: ${WHITE}$(date '+%d/%m/%Y %H:%M:%S')${NC}"
    echo
}

# Sistem logging yang lebih advanced
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        "INFO")
            echo "[$timestamp] [INFO] $message" >> "$LOG_FILE"
            ;;
        "ERROR")
            echo "[$timestamp] [ERROR] $message" >> "$ERROR_LOG"
            echo "[$timestamp] [ERROR] $message" >> "$LOG_FILE"
            ;;
        "WARN")
            echo "[$timestamp] [WARN] $message" >> "$LOG_FILE"
            ;;
        "SUCCESS")
            echo "[$timestamp] [SUCCESS] $message" >> "$LOG_FILE"
            ;;
    esac
}

# Progress tracking yang lebih detail
update_progress() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    local step_name="$1"
    local percentage=$((CURRENT_STEP * 100 / TOTAL_STEPS))
    
    echo -e "${BLUE}${BOLD}[${WHITE}$CURRENT_STEP${BLUE}/${WHITE}$TOTAL_STEPS${BLUE}]${NC} ${CYAN}Progress: ${WHITE}$percentage%${NC} ${YELLOW}$step_name${NC}"
    log "INFO" "Step $CURRENT_STEP/$TOTAL_STEPS: $step_name"
}

# Spinner animasi yang lebih keren
spinner() {
    local pid=$1
    local message="$2"
    local delay=0.08
    local spin='⣾⣽⣻⢿⡿⣟⣯⣷'
    local colors=("${RED}" "${YELLOW}" "${GREEN}" "${CYAN}" "${BLUE}" "${PURPLE}")
    local i=0
    local color_index=0
    
    while kill -0 $pid 2>/dev/null; do
        local color=${colors[$color_index]}
        printf "\r${color}${BOLD}%c${NC} ${WHITE}%s${NC} " "${spin:$i:1}" "$message"
        sleep $delay
        i=$(((i + 1) % 8))
        color_index=$(((color_index + 1) % 6))
    done
    
    wait $pid
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        printf "\r${GREEN}${BOLD}${CHECK}${NC} ${WHITE}%s${NC} ${GREEN}${BOLD}[BERHASIL]${NC}\n" "$message"
        log "SUCCESS" "$message"
    else
        printf "\r${RED}${BOLD}${CROSS}${NC} ${WHITE}%s${NC} ${RED}${BOLD}[GAGAL]${NC}\n" "$message"
        log "ERROR" "Gagal: $message"
        return $exit_code
    fi
}

# Progress bar yang lebih cantik dengan animasi
animated_progress_bar() {
    local current=$1
    local total=$2
    local message="$3"
    local width=40
    local percentage=$((current * 100 / total))
    local completed=$((current * width / total))
    local remaining=$((width - completed))
    
    # Warna gradient untuk progress bar
    local bar_color
    if [ $percentage -lt 30 ]; then
        bar_color="${RED}"
    elif [ $percentage -lt 70 ]; then
        bar_color="${YELLOW}"
    else
        bar_color="${GREEN}"
    fi
    
    printf "\r${CYAN}${BOLD}╔${"%-$(($width + 20))s"}╗${NC}\n" ""
    printf "${CYAN}${BOLD}║${NC} ${WHITE}$message${NC}%*s${CYAN}${BOLD}║${NC}\n" $((width + 20 - ${#message} - 1)) ""
    printf "${CYAN}${BOLD}║${NC} ${bar_color}["
    printf "%*s" $completed | tr ' ' '█'
    printf "%*s" $remaining | tr ' ' '░'
    printf "${bar_color}] ${WHITE}%3d%%${NC} ${CYAN}${BOLD}║${NC}\n" $percentage
    printf "${CYAN}${BOLD}╚${"%-$(($width + 20))s"}╝${NC}\n" ""
}

# Fungsi untuk menampilkan info sistem
show_system_info() {
    echo -e "${CYAN}${BOLD}${INFO} Informasi Sistem:${NC}"
    echo -e "${WHITE}   OS: ${GREEN}$(lsb_release -d 2>/dev/null | cut -f2 || echo "$(uname -s) $(uname -r)")${NC}"
    echo -e "${WHITE}   Arsitektur: ${GREEN}$(uname -m)${NC}"
    echo -e "${WHITE}   Kernel: ${GREEN}$(uname -r)${NC}"
    echo -e "${WHITE}   Memory: ${GREEN}$(free -h | awk '/^Mem:/ {print $2}')${NC}"
    echo -e "${WHITE}   Disk Space: ${GREEN}$(df -h / | awk 'NR==2 {print $4}') tersedia${NC}"
    echo -e "${WHITE}   User: ${GREEN}$(whoami)${NC}"
    echo
}

# Validasi sistem yang lebih ketat
check_prerequisites() {
    update_progress "Memeriksa prasyarat sistem"
    show_system_info
    
    # Array untuk menyimpan error
    local errors=()
    
    # Cek apakah running sebagai root
    if [[ $EUID -ne 0 ]]; then
        errors+=("Script ini harus dijalankan sebagai root. Gunakan: sudo $0")
    fi
    
    # Cek versi OS yang didukung
    if command -v lsb_release >/dev/null 2>&1; then
        local os_version=$(lsb_release -rs)
        local os_id=$(lsb_release -is)
        if [[ "$os_id" == "Ubuntu" ]] && [[ $(echo "$os_version < 18.04" | bc -l) -eq 1 ]]; then
            errors+=("Ubuntu versi minimum yang didukung adalah 18.04")
        fi
    fi
    
    # Cek space disk minimum (1GB)
    local available_space=$(df / | awk 'NR==2 {print $4}')
    if [[ $available_space -lt 1048576 ]]; then
        errors+=("Space disk tidak mencukupi. Minimal diperlukan 1GB")
    fi
    
    # Cek koneksi internet dengan multiple test
    local connection_tests=("github.com" "google.com" "8.8.8.8")
    local connection_ok=false
    
    for host in "${connection_tests[@]}"; do
        if ping -c 1 -W 3 "$host" &> /dev/null; then
            connection_ok=true
            break
        fi
    done
    
    if [[ "$connection_ok" != true ]]; then
        errors+=("Tidak ada koneksi internet yang stabil")
    fi
    
    # Cek port yang digunakan
    local ports_to_check=(80 443 3000 8080)
    local port_conflicts=()
    
    for port in "${ports_to_check[@]}"; do
        if netstat -tuln 2>/dev/null | grep -q ":$port "; then
            port_conflicts+=("$port")
        fi
    done
    
    if [[ ${#port_conflicts[@]} -gt 0 ]]; then
        errors+=("Port konflik terdeteksi: ${port_conflicts[*]}")
    fi
    
    # Tampilkan error jika ada
    if [[ ${#errors[@]} -gt 0 ]]; then
        echo -e "${RED}${BOLD}${CROSS} Ditemukan masalah pada sistem:${NC}"
        for error in "${errors[@]}"; do
            echo -e "${RED}   • $error${NC}"
        done
        echo
        exit 1
    fi
    
    echo -e "${GREEN}${BOLD}${CHECK} Semua prasyarat sistem terpenuhi${NC}"
    log "INFO" "Prasyarat sistem berhasil divalidasi"
}

# Deteksi instalasi yang sudah ada dengan info lebih detail
check_existing_installation() {
    update_progress "Memeriksa instalasi yang sudah ada"
    
    local existing_found=false
    local install_info=()
    
    # Cek direktori instalasi
    if [ -d "$INSTALL_DIR" ]; then
        existing_found=true
        local dir_size=$(du -sh "$INSTALL_DIR" 2>/dev/null | cut -f1)
        install_info+=("Direktori: $INSTALL_DIR ($dir_size)")
    fi
    
    # Cek service
    if systemctl list-unit-files | grep -q "$SERVICE_NAME.service"; then
        existing_found=true
        local service_status=$(systemctl is-active "$SERVICE_NAME" 2>/dev/null || echo "tidak aktif")
        install_info+=("Service: $SERVICE_NAME ($service_status)")
    fi
    
    # Cek proses yang berjalan
    if pgrep -f "vpn-api" >/dev/null; then
        existing_found=true
        install_info+=("Proses VPN API sedang berjalan")
    fi
    
    if [[ "$existing_found" == true ]]; then
        echo -e "${YELLOW}${BOLD}${WARNING} Ditemukan instalasi VPN API yang sudah ada:${NC}"
        for info in "${install_info[@]}"; do
            echo -e "${BLUE}   • $info${NC}"
        done
        echo
        
        echo -e "${CYAN}${BOLD}Pilihan tersedia:${NC}"
        echo -e "${WHITE}   1) ${GREEN}Hapus dan install ulang${NC}"
        echo -e "${WHITE}   2) ${YELLOW}Backup dan install ulang${NC}"
        echo -e "${WHITE}   3) ${RED}Batalkan instalasi${NC}"
        echo
        
        while true; do
            echo -e "${CYAN}${BOLD}Pilih opsi [1-3]: ${NC}"
            read -r choice
            case $choice in
                1)
                    remove_existing_installation
                    break
                    ;;
                2)
                    backup_existing_installation
                    remove_existing_installation
                    break
                    ;;
                3)
                    echo -e "${RED}${BOLD}${CROSS} Instalasi dibatalkan oleh pengguna${NC}"
                    exit 0
                    ;;
                *)
                    echo -e "${YELLOW}Pilihan tidak valid. Silakan pilih 1, 2, atau 3${NC}"
                    ;;
            esac
        done
    fi
}

# Backup instalasi yang sudah ada
backup_existing_installation() {
    echo -e "${YELLOW}${BOLD}${PACKAGE} Membuat backup instalasi yang sudah ada...${NC}"
    
    local backup_name="vpn-api-backup-$(date +%Y%m%d-%H%M%S)"
    local backup_path="/tmp/$backup_name"
    
    mkdir -p "$backup_path"
    
    if [ -d "$INSTALL_DIR" ]; then
        cp -r "$INSTALL_DIR" "$backup_path/" 2>/dev/null || true
        log "INFO" "Backup direktori instalasi ke $backup_path"
    fi
    
    if systemctl list-unit-files | grep -q "$SERVICE_NAME.service"; then
        systemctl show "$SERVICE_NAME" > "$backup_path/service-config.txt" 2>/dev/null || true
        log "INFO" "Backup konfigurasi service"
    fi
    
    # Kompres backup
    tar -czf "$backup_path.tar.gz" -C "/tmp" "$backup_name" 2>/dev/null || true
    rm -rf "$backup_path"
    
    echo -e "${GREEN}${BOLD}${CHECK} Backup berhasil dibuat: ${WHITE}$backup_path.tar.gz${NC}"
    log "SUCCESS" "Backup dibuat di $backup_path.tar.gz"
}

# Penghapusan instalasi yang lebih aman
remove_existing_installation() {
    update_progress "Menghapus instalasi yang sudah ada"
    
    # Stop service dengan timeout
    if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        echo -e "${YELLOW}Menghentikan service...${NC}"
        timeout 30 systemctl stop "$SERVICE_NAME" || {
            echo -e "${RED}Service tidak bisa dihentikan dengan normal, memaksa...${NC}"
            systemctl kill "$SERVICE_NAME"
            sleep 2
        }
    fi
    
    # Disable service
    if systemctl is-enabled --quiet "$SERVICE_NAME" 2>/dev/null; then
        systemctl disable "$SERVICE_NAME" >/dev/null 2>&1
    fi
    
    # Hapus file service
    if [ -f "/etc/systemd/system/$SERVICE_NAME.service" ]; then
        rm -f "/etc/systemd/system/$SERVICE_NAME.service"
        systemctl daemon-reload
    fi
    
    # Hapus direktori instalasi dengan aman
    if [ -d "$INSTALL_DIR" ]; then
        # Kill proses yang masih menggunakan direktori
        lsof +D "$INSTALL_DIR" 2>/dev/null | awk 'NR>1 {print $2}' | xargs -r kill -9 2>/dev/null || true
        sleep 1
        rm -rf "$INSTALL_DIR"
    fi
    
    # Bersihkan log lama
    rm -f "$LOG_FILE" "$ERROR_LOG" 2>/dev/null || true
    
    echo -e "${GREEN}${BOLD}${CHECK} Instalasi lama berhasil dihapus${NC}"
    log "SUCCESS" "Instalasi lama berhasil dihapus"
}

# Install dependencies dengan versi terbaru
install_dependencies() {
    update_progress "Menginstall dependencies yang diperlukan"
    
    # Update sistem terlebih dahulu
    echo -e "${YELLOW}Memperbarui daftar paket...${NC}"
    {
        DEBIAN_FRONTEND=noninteractive apt-get update -y
    } &
    spinner $! "Memperbarui daftar paket sistem"
    
    # Install Node.js dari NodeSource untuk versi terbaru
    if ! command -v node >/dev/null 2>&1 || [[ $(node -v | cut -d'v' -f2 | cut -d'.' -f1) -lt 16 ]]; then
        echo -e "${YELLOW}Menginstall Node.js versi terbaru...${NC}"
        {
            curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
            DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs
        } &
        spinner $! "Menginstall Node.js LTS"
    fi
    
    # Daftar paket yang diperlukan
    local packages=(
        "curl"
        "wget" 
        "git"
        "unzip"
        "build-essential"
        "python3"
        "python3-pip"
        "nginx"
        "ufw"
        "htop"
        "nano"
        "jq"
        "bc"
    )
    
    local total=${#packages[@]}
    local installed=0
    local skipped=0
    
    echo -e "${YELLOW}Menginstall paket-paket yang diperlukan...${NC}"
    
    for package in "${packages[@]}"; do
        if ! dpkg -l | grep -q "^ii  $package "; then
            {
                DEBIAN_FRONTEND=noninteractive apt-get install -y "$package"
            } &
            spinner $! "Menginstall $package"
            installed=$((installed + 1))
        else
            echo -e "${DIM}${package} sudah terinstall${NC}"
            skipped=$((skipped + 1))
        fi
    done
    
    echo -e "${GREEN}${BOLD}${CHECK} Dependencies berhasil diinstall${NC}"
    echo -e "${WHITE}   • Diinstall: ${GREEN}$installed${NC} paket"
    echo -e "${WHITE}   • Dilewati: ${YELLOW}$skipped${NC} paket"
    log "SUCCESS" "Dependencies berhasil diinstall: $installed baru, $skipped dilewati"
}

# Buat struktur direktori yang lebih lengkap
create_directories() {
    update_progress "Membuat struktur direktori"
    
    local directories=(
        "$INSTALL_DIR"
        "$SCRIPT_DIR"
        "$CONFIG_DIR"
        "$BACKUP_DIR"
        "/var/log/vpn-api"
        "/var/lib/vpn-api"
        "$TEMP_DIR"
    )
    
    echo -e "${YELLOW}Membuat direktori sistem...${NC}"
    
    for dir in "${directories[@]}"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            echo -e "${GREEN}   ${CHECK} $dir${NC}"
            log "INFO" "Direktori dibuat: $dir"
        else
            echo -e "${DIM}   $dir sudah ada${NC}"
        fi
    done
    
    # Set permission yang tepat
    chown -R root:root "$INSTALL_DIR"
    chmod -R 755 "$INSTALL_DIR"
    chmod 700 "$CONFIG_DIR"
    
    echo -e "${GREEN}${BOLD}${CHECK} Struktur direktori berhasil dibuat${NC}"
}

# Download dengan retry dan validasi
download_with_retry() {
    local url="$1"
    local output="$2"
    local max_attempts=3
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -fsSL --connect-timeout 10 --max-time 60 "$url" -o "$output"; then
            # Validasi file yang didownload
            if [ -s "$output" ]; then
                return 0
            else
                rm -f "$output"
                echo -e "${YELLOW}File kosong, mencoba ulang... (${attempt}/${max_attempts})${NC}"
            fi
        else
            echo -e "${YELLOW}Download gagal, mencoba ulang... (${attempt}/${max_attempts})${NC}"
        fi
        
        attempt=$((attempt + 1))
        sleep 2
    done
    
    return 1
}

# Download files dengan progress yang lebih detail
download_files() {
    update_progress "Mendownload file dari repository"
    
    cd "$INSTALL_DIR"
    
    # File-file utama yang diperlukan
    local main_files=(
        "vpn-api.js"
        "package.json"
        "README.md"
        ".env.example"
    )
    
    # Download file utama
    echo -e "${YELLOW}${DOWNLOAD} Mendownload file utama...${NC}"
    local downloaded=0
    local total_main=${#main_files[@]}
    
    for file in "${main_files[@]}"; do
        if download_with_retry "$RAW_URL/$file" "$INSTALL_DIR/$file"; then
            downloaded=$((downloaded + 1))
            animated_progress_bar $downloaded $total_main "Download: $file"
            log "SUCCESS" "Downloaded: $file"
        else
            echo -e "${RED}${BOLD}${CROSS} Gagal download $file setelah beberapa percobaan${NC}"
            log "ERROR" "Gagal download $file"
            exit 1
        fi
        sleep 0.5
    done
    
    # Download shell scripts
    echo -e "${YELLOW}${DOWNLOAD} Mendownload script utilitas...${NC}"
    local sh_files_api="https://api.github.com/repos/$REPO/contents?ref=$BRANCH"
    local sh_files_list
    
    if sh_files_list=$(curl -s "$sh_files_api" | jq -r '.[] | select(.name | endswith(".sh")) | select(.name != "install.sh") | .name' 2>/dev/null); then
        local sh_count=0
        local total_sh=$(echo "$sh_files_list" | wc -l)
        
        for file in $sh_files_list; do
            if download_with_retry "$RAW_URL/$file" "$SCRIPT_DIR/$file"; then
                chmod +x "$SCRIPT_DIR/$file"
                sh_count=$((sh_count + 1))
                animated_progress_bar $sh_count $total_sh "Script: $file"
                log "SUCCESS" "Downloaded script: $file"
            else
                echo -e "${YELLOW}${WARNING} Gagal download script $file (opsional)${NC}"
                log "WARN" "Gagal download script opsional: $file"
            fi
            sleep 0.3
        done
    fi
    
    # Buat file konfigurasi default
    if [ -f ".env.example" ]; then
        cp ".env.example" "$CONFIG_DIR/.env"
        echo -e "${GREEN}${CHECK} File konfigurasi default dibuat${NC}"
    fi
    
    echo -e "${GREEN}${BOLD}${CHECK} Semua file berhasil didownload${NC}"
    log "SUCCESS" "Download file selesai"
}

# Install Node.js modules dengan error handling
install_node_modules() {
    update_progress "Menginstall Node.js dependencies"
    
    cd "$INSTALL_DIR"
    
    if [ -f "package.json" ]; then
        echo -e "${YELLOW}${PACKAGE} Menginstall packages Node.js...${NC}"
        
        # Set npm configuration untuk produksi
        npm config set fund false
        npm config set audit false
        
        {
            npm install --only=production --no-optional --silent
        } &
        spinner $! "Menginstall Node.js packages"
        
        # Verifikasi instalasi
        if [ -d "node_modules" ] && [ -f "package-lock.json" ]; then
            local package_count=$(find node_modules -maxdepth 1 -type d | wc -l)
            echo -e "${GREEN}${BOLD}${CHECK} Node.js dependencies berhasil diinstall (${package_count} packages)${NC}"
            log "SUCCESS" "Node.js dependencies diinstall: $package_count packages"
        else
            echo -e "${RED}${BOLD}${CROSS} Gagal menginstall Node.js dependencies${NC}"
            log "ERROR" "Gagal menginstall Node.js dependencies"
            exit 1
        fi
    else
        echo -e "${YELLOW}${WARNING} package.json tidak ditemukan, membuat yang default...${NC}"
        
        # Buat package.json minimal
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
    "express": "^4.18.2",
    "cors": "^2.8.5",
    "helmet": "^7.0.0",
    "dotenv": "^16.3.1"
  },
  "author": "FadzDigital",
  "license": "MIT"
}
EOF
        
        npm install --only=production --silent
        log "SUCCESS" "Package.json default dibuat dan dependencies diinstall"
    fi
}

# Buat systemd service yang lebih robust
create_service() {
    update_progress "Mengkonfigurasi systemd service"
    
    echo -e "${YELLOW}${GEAR} Membuat service configuration...${NC}"
    
    # Buat service file dengan konfigurasi lengkap
    cat > "/etc/systemd/system/$SERVICE_NAME.service" << EOF
[Unit]
Description=VPN API Service - Powered by FadzDigital
Documentation=https://github.com/$REPO
After=network.target network-online.target
Wants=network-online.target
StartLimitBurst=3
StartLimitIntervalSec=60

[Service]
Type=simple
WorkingDirectory=$SCRIPT_DIR
ExecStart=/usr/bin/node $INSTALL_DIR/vpn-api.js
ExecReload=/bin/kill -HUP \$MAINPID
ExecStop=/bin/kill -TERM \$MAINPID
TimeoutStartSec=30
TimeoutStopSec=30
Restart=always
RestartSec=10
User=root
Group=root

# Environment variables
Environment=NODE_ENV=production
Environment=PATH=/usr/bin:/usr/local/bin
Environment=HOME=$INSTALL_DIR

# Logging
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable --now "$SERVICE_NAME.service"
    log "SUCCESS" "Systemd service $SERVICE_NAME berhasil dikonfigurasi dan dijalankan"
    echo -e "${GREEN}${BOLD}${CHECK} Systemd service berhasil dikonfigurasi dan dijalankan${NC}"
}

# Selesai & summary
finish_installation() {
    update_progress "Instalasi selesai"
    local end_time=$(date +%s)
    local duration=$((end_time - INSTALL_START_TIME))
    echo
    echo -e "${PARTY}${GREEN}${BOLD} Instalasi VPN API Selesai! ${NC}${PARTY}"
    echo -e "${CYAN}${BOLD}Waktu instalasi: ${WHITE}$duration detik${NC}"
    echo -e "${GREEN}${BOLD}${CHECK} Service aktif: ${WHITE}vpn-api${NC}"
    echo -e "${CYAN}Cek status: ${WHITE}systemctl status vpn-api${NC}"
    echo -e "${CYAN}Log:         ${WHITE}journalctl -u vpn-api -f${NC}"
    echo -e "${CYAN}API folder:  ${WHITE}$INSTALL_DIR${NC}"
    echo -e "${CYAN}Script:      ${WHITE}$SCRIPT_DIR${NC}"
    echo -e "${CYAN}Config:      ${WHITE}$CONFIG_DIR/.env${NC}"
    echo -e "${CYAN}Backup:      ${WHITE}$BACKUP_DIR${NC}"
    echo -e "${CYAN}Uninstall:   ${WHITE}systemctl stop vpn-api && systemctl disable vpn-api && rm /etc/systemd/system/vpn-api.service${NC}"
    echo -e "${GREEN}${BOLD}Terima kasih telah menggunakan installer by FadzDigital!${NC}"
    echo
}

# Main program eksekusi
main() {
    INSTALL_START_TIME=$(date +%s)
    print_banner
    check_prerequisites
    check_existing_installation
    install_dependencies
    create_directories
    download_files
    install_node_modules
    create_service
    finish_installation
}

main "$@"
