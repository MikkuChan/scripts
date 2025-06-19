#!/bin/bash
# =============================================================================
# VPN API Installation Script - FadzDigital
# Author: FadzDigital
# Created Kamis, 19 Juni 2025
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
declare -r BOLD='\033[1m'
declare -r DIM='\033[2m'
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
declare -r PID_FILE="/var/run/$SERVICE_NAME.pid"
declare -r BACKUP_DIR="/opt/vpn-api-backup"

# System requirements
declare -r MIN_MEMORY_GB=1
declare -r MIN_DISK_GB=2
declare -r REQUIRED_PORTS=(80 443 8080)

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

#  banner with animation
print_banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    
    # Animated banner appearance
    local banner_lines=(
      __           _     _            _
" / _| __ _  __| |___| |_ ___  ___| |__"
"| |_ / _` |/ _` |_  / __/ _ \/ __| '_ \"
"|  _| (_| | (_| |/ /| ||  __/ (__| | | |"
"|_|  \__,_|\__,_/___|\__\___|\___|_| |_|"
)

    
    for line in "${banner_lines[@]}"; do
        echo "$line"
        sleep 0.1
    done
    
    echo -e "${NC}"
    echo -e "${PURPLE}${BOLD}═══════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}${BOLD}                      INSTALLER VPN API v${SCRIPT_VERSION}                        ${NC}"
    echo -e "${GREEN}${BOLD}                           by FadzDigital                             ${NC}"
    echo -e "${DIM}                     Security & Performance                   ${NC}"
    echo -e "${PURPLE}${BOLD}═══════════════════════════════════════════════════════════════════════${NC}"
    echo
}

#  logging with levels
log() {
    local level="${1:-INFO}"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Create log directory if it doesn't exist
    mkdir -p "$(dirname "$LOG_FILE")"
    
    case "$level" in
        "ERROR")
            echo "[$timestamp] [ERROR] $message" | tee -a "$LOG_FILE" >&2
            ;;
        "WARN")
            echo "[$timestamp] [WARN] $message" | tee -a "$LOG_FILE"
            ;;
        "SUCCESS")
            echo "[$timestamp] [SUCCESS] $message" >> "$LOG_FILE"
            ;;
        *)
            echo "[$timestamp] [INFO] $message" >> "$LOG_FILE"
            ;;
    esac
}

# Advanced spinner with different animations
spinner() {
    local pid=$1
    local message="$2"
    local animation="${3:-dots}"
    local delay=0.1
    
    case "$animation" in
        "dots")
            local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
            ;;
        "bars")
            local spin='▁▂▃▄▅▆▇█▇▆▅▄▃▂'
            ;;
        "arrows")
            local spin='←↖↑↗→↘↓↙'
            ;;
        *)
            local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
            ;;
    esac
    
    local i=0
    local start_time=$(date +%s)
    
    while kill -0 $pid 2>/dev/null; do
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        printf "\r${BLUE}${BOLD}%c${NC} ${WHITE}%s${NC} ${DIM}[%ds]${NC}" \
               "${spin:$i:1}" "$message" "$elapsed"
        
        sleep $delay
        i=$(((i + 1) % ${#spin}))
    done
    
    wait $pid
    local exit_code=$?
    local end_time=$(date +%s)
    local total_time=$((end_time - start_time))
    
    if [ $exit_code -eq 0 ]; then
        printf "\r${GREEN}${BOLD}✓${NC} ${WHITE}%s${NC} ${GREEN}[BERHASIL]${NC} ${DIM}(%ds)${NC}\n" \
               "$message" "$total_time"
        log "SUCCESS" "$message (${total_time}s)"
    else
        printf "\r${RED}${BOLD}✗${NC} ${WHITE}%s${NC} ${RED}[GAGAL]${NC} ${DIM}(%ds)${NC}\n" \
               "$message" "$total_time"
        log "ERROR" "$message gagal (${total_time}s)"
        return $exit_code
    fi
}

#  command execution with retry mechanism
run() {
    local cmd="$*"
    local max_retries="${MAX_RETRIES:-3}"
    local retry_delay="${RETRY_DELAY:-2}"
    local attempt=1
    
    log "INFO" "Executing: $cmd"
    
    while [ $attempt -le $max_retries ]; do
        {
            eval "$cmd" 2>&1
        } &
        
        local pid=$!
        
        if [ $attempt -eq 1 ]; then
            spinner $pid "$cmd" "dots"
        else
            spinner $pid "$cmd (percobaan $attempt/$max_retries)" "bars"
        fi
        
        local exit_code=$?
        
        if [ $exit_code -eq 0 ]; then
            return 0
        else
            log "WARN" "Attempt $attempt failed for: $cmd"
            
            if [ $attempt -lt $max_retries ]; then
                echo -e "${YELLOW}⚠️  Percobaan $attempt gagal, mencoba lagi dalam ${retry_delay}s...${NC}"
                sleep $retry_delay
                attempt=$((attempt + 1))
            else
                echo -e "${RED}${BOLD}❌ Semua percobaan gagal untuk: $cmd${NC}"
                log "ERROR" "All attempts failed for: $cmd"
                return $exit_code
            fi
        fi
    done
}

#  progress bar with ETA
progress_bar() {
    local current=$1
    local total=$2
    local message="${3:-Processing}"
    local width=50
    local percentage=$((current * 100 / total))
    local completed=$((current * width / total))
    local remaining=$((width - completed))
    
    # Calculate ETA
    local eta=""
    if [ $current -gt 0 ] && [ ! -z "${PROGRESS_START_TIME:-}" ]; then
        local elapsed=$(($(date +%s) - PROGRESS_START_TIME))
        local rate=$((current * 1000 / (elapsed + 1)))  # items per second * 1000
        local remaining_items=$((total - current))
        local eta_seconds=$((remaining_items * 1000 / (rate + 1)))
        
        if [ $eta_seconds -lt 60 ]; then
            eta=" ETA: ${eta_seconds}s"
        else
            eta=" ETA: $((eta_seconds / 60))m $((eta_seconds % 60))s"
        fi
    fi
    
    printf "\r${CYAN}[${NC}"
    printf "%*s" $completed | tr ' ' '█'
    printf "%*s" $remaining | tr ' ' '░'
    printf "${CYAN}] ${WHITE}%d%%${NC} ${YELLOW}(%d/%d)${NC} ${DIM}%s${NC}%s" \
           $percentage $current $total "$message" "$eta"
}

# =============================================================================
# SYSTEM VALIDATION FUNCTIONS
# =============================================================================

# Comprehensive system check
check_system_requirements() {
    echo -e "${YELLOW}${BOLD}🔍 Memeriksa persyaratan sistem...${NC}"
    
    local checks_passed=0
    local total_checks=7
    
    # Check 1: Root privileges
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}${BOLD}❌ Script harus dijalankan sebagai root${NC}"
        echo -e "${YELLOW}   Gunakan: sudo $0${NC}"
        return 1
    fi
    checks_passed=$((checks_passed + 1))
    
    # Check 2: Operating system
    if ! command -v apt-get >/dev/null 2>&1; then
        echo -e "${RED}${BOLD}❌ Sistem operasi tidak didukung (diperlukan Ubuntu/Debian)${NC}"
        return 1
    fi
    checks_passed=$((checks_passed + 1))
    
    # Check 3: Memory
    local memory_gb=$(free -g | awk '/^Mem:/{print $2}')
    if [ "$memory_gb" -lt $MIN_MEMORY_GB ]; then
        echo -e "${RED}${BOLD}❌ RAM tidak mencukupi (minimal ${MIN_MEMORY_GB}GB, tersedia ${memory_gb}GB)${NC}"
        return 1
    fi
    checks_passed=$((checks_passed + 1))
    
    # Check 4: Disk space
    local disk_gb=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "$disk_gb" -lt $MIN_DISK_GB ]; then
        echo -e "${RED}${BOLD}❌ Ruang disk tidak mencukupi (minimal ${MIN_DISK_GB}GB, tersedia ${disk_gb}GB)${NC}"
        return 1
    fi
    checks_passed=$((checks_passed + 1))
    
    # Check 5: Internet connectivity
    if ! ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1; then
        echo -e "${RED}${BOLD}❌ Tidak ada koneksi internet${NC}"
        return 1
    fi
    checks_passed=$((checks_passed + 1))
    
    # Check 6: GitHub connectivity
    if ! curl -s --connect-timeout 10 https://api.github.com/repos/$REPO >/dev/null; then
        echo -e "${RED}${BOLD}❌ Tidak dapat mengakses GitHub repository${NC}"
        return 1
    fi
    checks_passed=$((checks_passed + 1))
    
    # Check 7: Port availability
    local ports_available=true
    for port in "${REQUIRED_PORTS[@]}"; do
        if netstat -ln 2>/dev/null | grep -q ":$port "; then
            echo -e "${YELLOW}⚠️  Port $port sudah digunakan${NC}"
            ports_available=false
        fi
    done
    
    if [ "$ports_available" = true ]; then
        checks_passed=$((checks_passed + 1))
    fi
    
    # Summary
    echo -e "${GREEN}${BOLD}✓ Pemeriksaan sistem selesai ($checks_passed/$total_checks)${NC}"
    
    if [ $checks_passed -eq $total_checks ]; then
        log "SUCCESS" "All system requirements met"
        return 0
    else
        log "ERROR" "System requirements not met ($checks_passed/$total_checks)"
        return 1
    fi
}

#  existing installation check
check_existing_installation() {
    local has_existing=false
    
    echo -e "${YELLOW}${BOLD}🔍 Memeriksa instalasi yang sudah ada...${NC}"
    
    if [ -d "$INSTALL_DIR" ]; then
        echo -e "${BLUE}   • Direktori instalasi ditemukan: ${WHITE}$INSTALL_DIR${NC}"
        has_existing=true
    fi
    
    if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        echo -e "${BLUE}   • Service aktif: ${WHITE}$SERVICE_NAME${NC}"
        has_existing=true
    fi
    
    if [ -f "/etc/systemd/system/$SERVICE_NAME.service" ]; then
        echo -e "${BLUE}   • Service file ditemukan${NC}"
        has_existing=true
    fi
    
    if [ "$has_existing" = true ]; then
        echo -e "${YELLOW}${BOLD}⚠️  Ditemukan instalasi VPN API yang sudah ada${NC}"
        echo
        
        # Show current installation info
        show_current_installation_info
        
        echo -e "${CYAN}${BOLD}Pilihan yang tersedia:${NC}"
        echo -e "${WHITE}  [1] Hapus dan install ulang (Recommended)${NC}"
        echo -e "${WHITE}  [2] Backup dan install ulang${NC}"
        echo -e "${WHITE}  [3] Update saja (Keep config)${NC}"
        echo -e "${WHITE}  [4] Batalkan instalasi${NC}"
        echo
        
        while true; do
            echo -e "${CYAN}${BOLD}Pilih opsi [1-4]: ${NC}"
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
                    UPDATE_MODE=true
                    break
                    ;;
                4)
                    echo -e "${RED}${BOLD}Instalasi dibatalkan oleh pengguna${NC}"
                    log "INFO" "Installation cancelled by user"
                    exit 0
                    ;;
                *)
                    echo -e "${YELLOW}Pilihan tidak valid. Silakan pilih 1-4${NC}"
                    ;;
            esac
        done
    else
        echo -e "${GREEN}${BOLD}✓ Tidak ada instalasi sebelumnya${NC}"
    fi
}

# Show current installation information
show_current_installation_info() {
    echo -e "${CYAN}${BOLD}📋 Informasi Instalasi Saat Ini:${NC}"
    
    if [ -d "$INSTALL_DIR" ]; then
        local install_size=$(du -sh "$INSTALL_DIR" 2>/dev/null | cut -f1)
        echo -e "${WHITE}   • Ukuran instalasi: ${GREEN}$install_size${NC}"
        
        if [ -f "$INSTALL_DIR/package.json" ]; then
            local version=$(grep '"version"' "$INSTALL_DIR/package.json" 2>/dev/null | cut -d'"' -f4)
            echo -e "${WHITE}   • Versi: ${GREEN}${version:-"Unknown"}${NC}"
        fi
    fi
    
    if systemctl is-enabled --quiet "$SERVICE_NAME" 2>/dev/null; then
        local status=$(systemctl is-active "$SERVICE_NAME" 2>/dev/null)
        local uptime=$(systemctl show "$SERVICE_NAME" --property=ActiveEnterTimestamp --value 2>/dev/null)
        echo -e "${WHITE}   • Status service: ${GREEN}$status${NC}"
        [ -n "$uptime" ] && echo -e "${WHITE}   • Uptime: ${GREEN}$uptime${NC}"
    fi
    
    echo
}

# Backup existing installation
backup_existing_installation() {
    echo -e "${YELLOW}${BOLD}💾 Membuat backup instalasi lama...${NC}"
    
    local backup_name="vpn-api-backup-$(date +%Y%m%d-%H%M%S)"
    local backup_path="$BACKUP_DIR/$backup_name"
    
    run "mkdir -p $backup_path"
    
    if [ -d "$INSTALL_DIR" ]; then
        run "cp -r $INSTALL_DIR/* $backup_path/"
    fi
    
    if [ -f "/etc/systemd/system/$SERVICE_NAME.service" ]; then
        run "cp /etc/systemd/system/$SERVICE_NAME.service $backup_path/"
    fi
    
    # Create backup info
    cat > "$backup_path/backup-info.txt" << EOF
Backup Information
==================
Created: $(date)
Original Path: $INSTALL_DIR
Service Name: $SERVICE_NAME
System: $(uname -a)
User: $(whoami)
EOF
    
    echo -e "${GREEN}${BOLD}✓ Backup disimpan di: ${WHITE}$backup_path${NC}"
    log "SUCCESS" "Backup created at $backup_path"
}

#  removal with confirmation
remove_existing_installation() {
    echo -e "${YELLOW}${BOLD}🗑️  Menghapus instalasi yang sudah ada...${NC}"
    
    local removal_steps=4
    local current_step=0
    
    # Stop service
    if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        current_step=$((current_step + 1))
        progress_bar $current_step $removal_steps "Menghentikan service"
        run "systemctl stop $SERVICE_NAME"
    fi
    
    # Disable service
    if systemctl is-enabled --quiet "$SERVICE_NAME" 2>/dev/null; then
        current_step=$((current_step + 1))
        progress_bar $current_step $removal_steps "Menonaktifkan service"
        run "systemctl disable $SERVICE_NAME"
    fi
    
    # Remove service file
    if [ -f "/etc/systemd/system/$SERVICE_NAME.service" ]; then
        current_step=$((current_step + 1))
        progress_bar $current_step $removal_steps "Menghapus service file"
        run "rm -f /etc/systemd/system/$SERVICE_NAME.service"
        run "systemctl daemon-reload"
    fi
    
    # Remove installation directory
    if [ -d "$INSTALL_DIR" ]; then
        current_step=$((current_step + 1))
        progress_bar $current_step $removal_steps "Menghapus direktori instalasi"
        run "rm -rf $INSTALL_DIR"
    fi
    
    echo
    echo -e "${GREEN}${BOLD}✓ Instalasi lama berhasil dihapus${NC}"
    log "SUCCESS" "Previous installation removed successfully"
}

# =============================================================================
# INSTALLATION FUNCTIONS
# =============================================================================

#  dependency installation with package verification
install_dependencies() {
    echo -e "${YELLOW}${BOLD}📦 Menginstall dependencies...${NC}"
    
    # Update package list
    run "apt-get update -y"
    
    # Install essential packages
    local packages=(
        "curl:Command line tool for transferring data"
        "wget:Network downloader"
        "git:Version control system"
        "nodejs:JavaScript runtime"
        "npm:Node.js package manager"
        "systemd:System and service manager"
        "netstat-nat:Network statistics"
        "jq:JSON processor"
        "unzip:Archive extraction"
        "htop:Process viewer"
    )
    
    local total=${#packages[@]}
    local current=0
    export PROGRESS_START_TIME=$(date +%s)
    
    for package_info in "${packages[@]}"; do
        local package_name=$(echo "$package_info" | cut -d':' -f1)
        local package_desc=$(echo "$package_info" | cut -d':' -f2)
        
        current=$((current + 1))
        progress_bar $current $total "Installing $package_name"
        
        if ! command -v "$package_name" >/dev/null 2>&1 && ! dpkg -l | grep -q "^ii  $package_name "; then
            if ! run "apt-get install -y $package_name"; then
                echo -e "${RED}${BOLD}❌ Gagal menginstall $package_name${NC}"
                log "ERROR" "Failed to install $package_name"
                return 1
            fi
        else
            log "INFO" "$package_name already installed"
        fi
        
        sleep 0.1  # Small delay for visual effect
    done
    
    echo
    
    # Verify Node.js and npm versions
    local node_version=$(node --version 2>/dev/null || echo "Not found")
    local npm_version=$(npm --version 2>/dev/null || echo "Not found")
    
    echo -e "${CYAN}📋 Versi yang terinstall:${NC}"
    echo -e "${WHITE}   • Node.js: ${GREEN}$node_version${NC}"
    echo -e "${WHITE}   • npm: ${GREEN}$npm_version${NC}"
    
    # Check if Node.js version is compatible (minimum v14)
    if command -v node >/dev/null 2>&1; then
        local node_major=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
        if [ "$node_major" -lt 14 ]; then
            echo -e "${YELLOW}⚠️  Node.js versi lama terdeteksi, mengupgrade...${NC}"
            run "curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -"
            run "apt-get install -y nodejs"
        fi
    fi
    
    echo -e "${GREEN}${BOLD}✓ Semua dependencies berhasil diinstall${NC}"
    log "SUCCESS" "All dependencies installed successfully"
}

#  directory creation with proper permissions
create_directories() {
    echo -e "${YELLOW}${BOLD}📁 Membuat struktur direktori...${NC}"
    
    local directories=(
        "$INSTALL_DIR:755:VPN API main directory"
        "$SCRIPT_DIR:755:Scripts directory"
        "$CONFIG_DIR:750:Configuration directory"
        "/var/log/vpn-api:755:Log directory"
        "/var/lib/vpn-api:755:Data directory"
        "/etc/vpn-api:750:System config directory"
    )
    
    for dir_info in "${directories[@]}"; do
        local dir_path=$(echo "$dir_info" | cut -d':' -f1)
        local dir_perms=$(echo "$dir_info" | cut -d':' -f2)
        local dir_desc=$(echo "$dir_info" | cut -d':' -f3)
        
        if [ ! -d "$dir_path" ]; then
            run "mkdir -p $dir_path"
            run "chmod $dir_perms $dir_path"
            run "chown root:root $dir_path"
            
            echo -e "${GREEN}  ✓ Created: ${WHITE}$dir_path${NC} ${DIM}($dir_desc)${NC}"
            log "SUCCESS" "Created directory: $dir_path"
        else
            echo -e "${BLUE}  ℹ Exists: ${WHITE}$dir_path${NC} ${DIM}($dir_desc)${NC}"
        fi
    done
    
    echo -e "${GREEN}${BOLD}✓ Struktur direktori berhasil dibuat${NC}"
}

#  file download with integrity checking
download_files() {
    echo -e "${YELLOW}${BOLD}⬇️  Mendownload files dari GitHub...${NC}"
    
    cd "$INSTALL_DIR"
    
    # Get repository information
    local repo_info
    if ! repo_info=$(curl -s "https://api.github.com/repos/$REPO"); then
        echo -e "${RED}${BOLD}❌ Gagal mengakses repository information${NC}"
        return 1
    fi
    
    # Main application files
    local main_files=(
        "vpn-api.js:VPN API main application"
        "package.json:Node.js dependencies"
        "README.md:Documentation"
        ".env.example:Environment template"
    )
    
    # Get shell scripts from repository
    local sh_files
    if ! sh_files=$(curl -s "https://api.github.com/repos/$REPO/contents?ref=$BRANCH" | jq -r '.[] | select(.name | endswith(".sh")) | select(.name != "install.sh") | .name'); then
        echo -e "${YELLOW}⚠️  Tidak dapat mengambil daftar shell scripts${NC}"
        sh_files=""
    fi
    
    # Calculate total files
    local total_files=${#main_files[@]}
    [ -n "$sh_files" ] && total_files=$((total_files + $(echo "$sh_files" | wc -l)))
    
    local current_file=0
    export PROGRESS_START_TIME=$(date +%s)
    
    # Download main files
    for file_info in "${main_files[@]}"; do
        local filename=$(echo "$file_info" | cut -d':' -f1)
        local filedesc=$(echo "$file_info" | cut -d':' -f2)
        
        current_file=$((current_file + 1))
        progress_bar $current_file $total_files "Downloading $filename"
        
        local download_url="$RAW_URL/$filename"
        local temp_file="/tmp/${filename}.tmp"
        
        # Download to temporary file first
        if curl -fsSL "$download_url" -o "$temp_file"; then
            # Verify file is not empty and move to final location
            if [ -s "$temp_file" ]; then
                mv "$temp_file" "$INSTALL_DIR/$filename"
                chmod 644 "$INSTALL_DIR/$filename"
                log "SUCCESS" "Downloaded: $filename"
            else
                echo -e "\n${YELLOW}⚠️  File kosong: $filename, skip...${NC}"
                rm -f "$temp_file"
            fi
        else
            echo -e "\n${YELLOW}⚠️  Gagal download: $filename, skip...${NC}"
            rm -f "$temp_file"
        fi
    done
    
    # Download shell scripts
    if [ -n "$sh_files" ]; then
        while IFS= read -r filename; do
            [ -z "$filename" ] && continue
            
            current_file=$((current_file + 1))
            progress_bar $current_file $total_files "Downloading $filename"
            
            local download_url="$RAW_URL/$filename"
            local temp_file="/tmp/${filename}.tmp"
            
            if curl -fsSL "$download_url" -o "$temp_file"; then
                if [ -s "$temp_file" ]; then
                    mv "$temp_file" "$SCRIPT_DIR/$filename"
                    chmod +x "$SCRIPT_DIR/$filename"
                    log "SUCCESS" "Downloaded script: $filename"
                else
                    rm -f "$temp_file"
                fi
            else
                rm -f "$temp_file"
            fi
        done <<< "$sh_files"
    fi
    
    echo
    echo -e "${GREEN}${BOLD}✓ File download selesai${NC}"
    
    # Show downloaded files summary
    local downloaded_count=$(find "$INSTALL_DIR" -type f | wc -l)
    echo -e "${CYAN}📋 Summary: ${WHITE}$downloaded_count${NC} files downloaded"
    
    log "SUCCESS" "Downloaded $downloaded_count files successfully"
}

#  Node.js dependencies installation
install_node_modules() {
    echo -e "${YELLOW}${BOLD}📦 Menginstall Node.js dependencies...${NC}"
    
    cd "$INSTALL_DIR"
    
    if [ ! -f "package.json" ]; then
        echo -e "${YELLOW}⚠️  package.json tidak ditemukan, membuat default...${NC}"
        
        # Create basic package.json if not exists
        cat > package.json << EOF
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
    "helmet": "^6.0.0",
    "morgan": "^1.10.0",
    "dotenv": "^16.0.0"
  },
  "engines": {
    "node": ">=14.0.0"
  },
    "author": "FadzDigital",
    "license": "MIT"
}
EOF
    fi

    # Install node modules (production only)
    if [ -f "package.json" ]; then
        run "npm install --only=production --no-optional --silent"
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}${BOLD}✓ Node.js dependencies berhasil diinstall${NC}"
            log "SUCCESS" "Node.js dependencies installed"
        else
            echo -e "${RED}${BOLD}❌ Gagal menginstall Node.js dependencies${NC}"
            log "ERROR" "Failed to install Node.js dependencies"
            exit 1
        fi
    fi
}

# Create .env config from example if not exists
setup_env_file() {
    echo -e "${YELLOW}${BOLD}⚙️  Setup konfigurasi environment...${NC}"
    if [ -f "$INSTALL_DIR/.env.example" ] && [ ! -f "$CONFIG_DIR/.env" ]; then
        cp "$INSTALL_DIR/.env.example" "$CONFIG_DIR/.env"
        chmod 640 "$CONFIG_DIR/.env"
        echo -e "${GREEN}${BOLD}✓ File konfigurasi .env dibuat${NC}"
        log "SUCCESS" ".env configuration created"
    fi
}

# Create systemd service with watermark
create_systemd_service() {
    echo -e "${YELLOW}${BOLD}🛠️  Setup systemd service...${NC}"
    local service_path="/etc/systemd/system/$SERVICE_NAME.service"
    cat > "$service_path" << EOF
[Unit]
Description=VPN API Service - Powered by FadzDigital
Documentation=https://github.com/MikkuChan/scripts
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/vpn-api
ExecStart=/usr/bin/node /opt/vpn-api/vpn-api.js
Restart=always
User=root
Environment=NODE_ENV=production
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    run "systemctl daemon-reload"
    run "systemctl enable --now $SERVICE_NAME"
    echo -e "${GREEN}${BOLD}✓ Systemd service aktif dan berjalan${NC}"
    log "SUCCESS" "Systemd service registered & started"
}

# Show installation summary and usage info
show_summary() {
    echo
    echo -e "${GREEN}${BOLD}🎉 Instalasi VPN API berhasil!${NC}"
    echo -e "${CYAN}Service status: ${WHITE}systemctl status $SERVICE_NAME${NC}"
    echo -e "${CYAN}Log:            ${WHITE}journalctl -u $SERVICE_NAME -f${NC}"
    echo -e "${CYAN}Config:         ${WHITE}$CONFIG_DIR/.env${NC}"
    echo -e "${CYAN}Scripts:        ${WHITE}$SCRIPT_DIR${NC}"
    echo -e "${CYAN}Uninstall:      ${WHITE}systemctl stop $SERVICE_NAME && systemctl disable $SERVICE_NAME && rm /etc/systemd/system/$SERVICE_NAME.service${NC}"
    echo -e "${GREEN}${BOLD}Terima kasih telah menggunakan VPN API by FadzDigital!${NC}"
    echo
}

# =============================================================================
# MAIN INSTALLATION FLOW
# =============================================================================

main() {
    print_banner

    # Step 1: System checks
    check_system_requirements || exit 1

    # Step 2: Existing installation check
    check_existing_installation

    # Step 3: Install dependencies
    install_dependencies

    # Step 4: Create directories
    create_directories

    # Step 5: Download files
    download_files

    # Step 6: Install node modules
    install_node_modules

    # Step 7: Setup .env config
    setup_env_file

    # Step 8: Setup systemd service
    create_systemd_service

    # Step 9: Show summary
    show_summary
}

main "$@"
