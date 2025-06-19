#!/bin/bash
# =============================================================================
# VPN API Installation Script - FadzDigital Enhanced
# Version: 2.0
# Author: FadzDigital
# License: MIT
# =============================================================================
set -euo pipefail

# =============================================================================
# GLOBAL CONFIGURATIONS
# =============================================================================
# Color definitions
declare -r RED='\033[0;31m'
declare -r GREEN='\033[0;32m'
declare -r YELLOW='\033[1;33m'
declare -r BLUE='\033[0;34m'
declare -r PURPLE='\033[0;35m'
declare -r CYAN='\033[0;36m'
declare -r WHITE='\033[1;37m'
declare -r NC='\033[0m'

# Application configuration
declare -r SCRIPT_VERSION="2.0"
declare -r REPO="MikkuChan/scripts"
declare -r BRANCH="main"
declare -r RAW_URL="https://raw.githubusercontent.com/$REPO/$BRANCH"
declare -r INSTALL_DIR="/opt/vpn-api"
declare -r SCRIPT_DIR="$INSTALL_DIR/scripts"
declare -r CONFIG_DIR="$INSTALL_DIR/config"
declare -r SERVICE_NAME="vpn-api"
declare -r LOG_FILE="/var/log/vpn-api-install.log"
declare -r BACKUP_DIR="/opt/vpn-api-backup"
declare -r MIN_MEMORY_GB=1
declare -r MIN_DISK_GB=2
declare -r REQUIRED_PORTS=(80 443 5888)

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================
# Simple banner
print_banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo "============================================================="
    echo "           INSTALLER VPN API v${SCRIPT_VERSION} by FadzDigital"
    echo "============================================================="
    echo -e "${NC}"
}

# Logging function
log() {
    local level="${1:-INFO}"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    mkdir -p "$(dirname "$LOG_FILE")"
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    case "$level" in
        "ERROR") echo -e "${RED}[$timestamp] [ERROR] $message${NC}" >&2 ;;
        "WARN") echo -e "${YELLOW}[$timestamp] [WARN] $message${NC}" ;;
        *) echo -e "${WHITE}[$timestamp] [INFO] $message${NC}" ;;
    esac
}

# Execute command with retry
run() {
    local cmd="$*"
    local max_retries=3
    local attempt=1

    log "INFO" "Executing: $cmd"
    while [ $attempt -le $max_retries ]; do
        if eval "$cmd"; then
            log "SUCCESS" "$cmd"
            return 0
        else
            log "WARN" "Attempt $attempt failed for: $cmd"
            if [ $attempt -lt $max_retries ]; then
                echo -e "${YELLOW}⚠️ Percobaan $attempt gagal, mencoba lagi...${NC}"
                sleep 2
                attempt=$((attempt + 1))
            else
                log "ERROR" "All attempts failed for: $cmd"
                echo -e "${RED}❌ Gagal menjalankan: $cmd${NC}"
                return 1
            fi
        fi
    done
}

# =============================================================================
# SYSTEM VALIDATION FUNCTIONS
# =============================================================================
check_system_requirements() {
    echo -e "${YELLOW}🔍 Memeriksa persyaratan sistem...${NC}"
    local checks_passed=0
    local total_checks=6

    # Check root
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}❌ Script harus dijalankan sebagai root${NC}"
        log "ERROR" "Script not run as root"
        exit 1
    fi
    checks_passed=$((checks_passed + 1))

    # Check OS
    if ! command -v apt-get >/dev/null 2>&1; then
        echo -e "${RED}❌ Sistem operasi tidak didukung (diperlukan Ubuntu/Debian)${NC}"
        log "ERROR" "Unsupported OS"
        exit 1
    fi
    checks_passed=$((checks_passed + 1))

    # Check memory
    local memory_gb=$(free -g | awk '/^Mem:/{print $2}')
    if [ "$memory_gb" -lt $MIN_MEMORY_GB ]; then
        echo -e "${RED}❌ RAM tidak mencukupi (minimal ${MIN_MEMORY_GB}GB)${NC}"
        log "ERROR" "Insufficient memory"
        exit 1
    fi
    checks_passed=$((checks_passed + 1))

    # Check disk
    local disk_gb=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "$disk_gb" -lt $MIN_DISK_GB ]; then
        echo -e "${RED}❌ Ruang disk tidak mencukupi (minimal ${MIN_DISK_GB}GB)${NC}"
        log "ERROR" "Insufficient disk space"
        exit 1
    fi
    checks_passed=$((checks_passed + 1))

    # Check internet
    if ! ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1; then
        echo -e "${RED}❌ Tidak ada koneksi internet${NC}"
        log "ERROR" "No internet connection"
        exit 1
    fi
    checks_passed=$((checks_passed + 1))

    # Check ports
    local ports_available=true
    for port in "${REQUIRED_PORTS[@]}"; do
        if netstat -tuln 2>/dev/null | grep -q ":$port "; then
            echo -e "${YELLOW}⚠️ Port $port sudah digunakan${NC}"
            ports_available=false
        fi
    done
    if [ "$ports_available" = true ]; then
        checks_passed=$((checks_passed + 1))
    fi

    echo -e "${GREEN}✓ Pemeriksaan sistem selesai ($checks_passed/$total_checks)${NC}"
    if [ $checks_passed -ne $total_checks ]; then
        log "ERROR" "System requirements not fully met"
        exit 1
    fi
}

check_existing_installation() {
    echo -e "${YELLOW}🔍 Memeriksa instalasi yang sudah ada...${NC}"
    local has_existing=false

    if [ -d "$INSTALL_DIR" ] || systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null || [ -f "/etc/systemd/system/$SERVICE_NAME.service" ]; then
        has_existing=true
        echo -e "${YELLOW}⚠️ Ditemukan instalasi sebelumnya${NC}"
        echo -e "${CYAN}Pilih opsi [1-2]:${NC}"
        echo -e "${WHITE}  [1] Hapus dan install ulang${NC}"
        echo -e "${WHITE}  [2] Batalkan instalasi${NC}"
        read -r choice
        case $choice in
            1) remove_existing_installation ;;
            2) echo -e "${RED}Instalasi dibatalkan${NC}"; log "INFO" "Installation cancelled"; exit 0 ;;
            *) echo -e "${RED}Pilihan tidak valid${NC}"; exit 1 ;;
        esac
    else
        echo -e "${GREEN}✓ Tidak ada instalasi sebelumnya${NC}"
    fi
}

remove_existing_installation() {
    echo -e "${YELLOW}🗑️ Menghapus instalasi lama...${NC}"
    systemctl stop "$SERVICE_NAME" 2>/dev/null || true
    systemctl disable "$SERVICE_NAME" 2>/dev/null || true
    rm -f "/etc/systemd/system/$SERVICE_NAME.service" 2>/dev/null || true
    systemctl daemon-reload 2>/dev/null || true
    rm -rf "$INSTALL_DIR" 2>/dev/null || true
    echo -e "${GREEN}✓ Instalasi lama dihapus${NC}"
    log "SUCCESS" "Previous installation removed"
}

# =============================================================================
# INSTALLATION FUNCTIONS
# =============================================================================
install_dependencies() {
    echo -e "${YELLOW}📦 Menginstall dependencies...${NC}"
    run "apt-get update -y"
    local packages=("curl" "wget" "git" "nodejs" "npm" "net-tools" "jq")
    for pkg in "${packages[@]}"; do
        if ! dpkg -l | grep -q " $pkg "; then
            run "apt-get install -y $pkg"
        else
            log "INFO" "$pkg already installed"
        fi
    done

    # Verify Node.js version
    local node_major=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
    if [ "$node_major" -lt 14 ]; then
        run "curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -"
        run "apt-get install -y nodejs"
    fi
    echo -e "${GREEN}✓ Dependencies terinstall${NC}"
    log "SUCCESS" "Dependencies installed"
}

create_directories() {
    echo -e "${YELLOW}📁 Membuat direktori...${NC}"
    local dirs=(
        "$INSTALL_DIR:755"
        "$SCRIPT_DIR:755"
        "$CONFIG_DIR:750"
        "/var/log/vpn-api:755"
    )
    for dir_info in "${dirs[@]}"; do
        local dir_path=${dir_info%%:*}
        local dir_perms=${dir_info##*:}
        run "mkdir -p $dir_path"
        run "chmod $dir_perms $dir_path"
        run "chown root:root $dir_path"
    done
    echo -e "${GREEN}✓ Direktori dibuat${NC}"
}

download_files() {
    echo -e "${YELLOW}⬇️ Mendownload files...${NC}"
    run "mkdir -p $INSTALL_DIR"
    cd "$INSTALL_DIR"
    local files=(
        "vpn-api.js"
        "package.json"
        ".env.example"
    )
    for file in "${files[@]}"; do
        if run "curl -fsSL $RAW_URL/$file -o $file"; then
            chmod 644 "$file"
            log "SUCCESS" "Downloaded $file"
        else
            echo -e "${YELLOW}⚠️ Gagal download $file, skip...${NC}"
        fi
    done
    echo -e "${GREEN}✓ Download selesai${NC}"
}

install_node_modules() {
    echo -e "${YELLOW}📦 Menginstall Node.js dependencies...${NC}"
    cd "$INSTALL_DIR"
    if [ ! -f "package.json" ]; then
        echo -e "${RED}❌ package.json tidak ditemukan${NC}"
        log "ERROR" "package.json not found"
        exit 1
    fi
    run "npm install --production --no-audit --no-fund"
    echo -e "${GREEN}✓ Node.js dependencies terinstall${NC}"
}

create_service() {
    echo -e "${YELLOW}⚙️ Membuat systemd service...${NC}"
    cat > "/etc/systemd/system/$SERVICE_NAME.service" <<EOF
[Unit]
Description=VPN API Service
After=network.target

[Service]
ExecStart=/usr/bin/node $INSTALL_DIR/vpn-api.js
WorkingDirectory=$INSTALL_DIR
Restart=always
User=root
Group=root
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF
    run "systemctl daemon-reload"
    run "systemctl enable $SERVICE_NAME"
    echo -e "${GREEN}✓ Service dibuat${NC}"
}

start_service() {
    echo -e "${YELLOW}🚀 Menjalankan service...${NC}"
    if run "systemctl start $SERVICE_NAME"; then
        if systemctl is-active --quiet "$SERVICE_NAME"; then
            echo -e "${GREEN}✓ Service berjalan${NC}"
            log "SUCCESS" "Service started"
        else
            echo -e "${RED}❌ Service gagal berjalan${NC}"
            log "ERROR" "Service failed to start"
            exit 1
        fi
    fi
}

show_installation_summary() {
    echo -e "${PURPLE}=============================================================${NC}"
    echo -e "${GREEN}🎉 INSTALASI BERHASIL!${NC}"
    echo -e "${PURPLE}=============================================================${NC}"
    echo -e "${CYAN}📋 Detail:${NC}"
    echo -e "${WHITE}   • Version: ${GREEN}$SCRIPT_VERSION${NC}"
    echo -e "${WHITE}   • Install Directory: ${GREEN}$INSTALL_DIR${NC}"
    echo -e "${WHITE}   • Service Name: ${GREEN}$SERVICE_NAME${NC}"
    echo -e "${WHITE}   • Log File: ${GREEN}$LOG_FILE${NC}"
    echo -e "${CYAN}🔧 Perintah:${NC}"
    echo -e "${WHITE}   • Status: ${YELLOW}systemctl status $SERVICE_NAME${NC}"
    echo -e "${WHITE}   • Logs: ${YELLOW}journalctl -u $SERVICE_NAME -f${NC}"
}

# =============================================================================
# MAIN INSTALLATION FLOW
# =============================================================================
main() {
    print_banner
    check_system_requirements
    check_existing_installation
    install_dependencies
    create_directories
    download_files
    install_node_modules
    create_service
    start_service
    show_installation_summary
    log "SUCCESS" "Installation completed"
    echo -e "${GREEN}🎊 VPN API siap digunakan!${NC}"
}

# Error handling
handle_error() {
    local exit_code=$1
    local line_number=$2
    echo -e "${RED}❌ Error pada baris $line_number (kode: $exit_code)${NC}"
    log "ERROR" "Failed at line $line_number (exit code: $exit_code)"
    tail -n 5 "$LOG_FILE"
    exit $exit_code
}

trap 'handle_error $? $LINENO' ERR

# Execute main
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
else
    echo -e "${RED}Script harus dijalankan, bukan di-source!${NC}"
    exit 1
fi
