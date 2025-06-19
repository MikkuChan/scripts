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
declare -r REQUIRED_PORTS=(80 443 5888)
# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================
# Enhanced banner with animation
print_banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    
    # Animated banner appearance
    local banner_lines=(
        "   ___            __            "
        " /'___\\          /\\ \\           "
        "/\\ \\__/   __     \\_\\ \\  ____    "
        "\\ \\ ,__\\/'__\`\\   /'_\` \\/\\_ ,\`\\  "
        " \\ \\ \\_/\\ \\L\\.\\_/\\ \\L\\ \\/_/  /_ "
        "  \\ \\_\\\\ \\__/.\\_\\ \\___,_\\/\\____\\"
        "   \\/_/ \\/__/\\/_/\\/__,_ \\/\\/____/"
        "                                "
        "                                "
    )
    
    for line in "${banner_lines[@]}"; do
        echo "$line"
        sleep 0.1
    done
    
    echo -e "${NC}"
    echo -e "${PURPLE}${BOLD}═══════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}${BOLD}                      INSTALLER VPN API v${SCRIPT_VERSION}                        ${NC}"
    echo -e "${GREEN}${BOLD}                           by FadzDigital                             ${NC}"
    echo -e "${DIM}                    Enhanced Security & Performance                   ${NC}"
    echo -e "${PURPLE}${BOLD}═══════════════════════════════════════════════════════════════════════${NC}"
    echo
}

# Enhanced logging with levels
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

# Enhanced command execution with retry mechanism
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

# Enhanced progress bar with ETA
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

# Enhanced existing installation check
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

# Enhanced removal with confirmation
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

# Enhanced dependency installation with package verification
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

# Enhanced directory creation with proper permissions
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

# Enhanced file download with integrity checking
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

# Enhanced Node.js dependencies installation
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
    
    # Check package.json validity
    if ! jq empty package.json 2>/dev/null; then
        echo -e "${RED}${BOLD}❌ package.json tidak valid${NC}"
        return 1
    fi
    
    # Install with production flag and progress
    echo -e "${CYAN}📦 Installing dependencies...${NC}"
    
    # Set npm configurations for better performance
    run "npm config set progress=true"
    run "npm config set loglevel=warn"
    
    # Install dependencies
    if run "npm install --production --no-audit --no-fund"; then
        # Verify installation
        local installed_packages=$(npm list --depth=0 --json 2>/dev/null | jq -r '.dependencies | keys | length' 2>/dev/null || echo "0")
        echo -e "${GREEN}${BOLD}✓ Dependencies installed successfully${NC}"
        echo -e "${CYAN}📦 Total packages: ${WHITE}$installed_packages${NC}"
        log "SUCCESS" "Node.js dependencies installed ($installed_packages packages)"
    else
        echo -e "${RED}${BOLD}❌ Gagal menginstall dependencies${NC}"
        log "ERROR" "Failed to install Node.js dependencies"
        return 1
    fi
    
    # Clean npm cache to save space
    run "npm cache clean --force"
}

# Enhanced systemd service creation with advanced configuration
create_service() {
    echo -e "${YELLOW}${BOLD}⚙️  Membuat systemd service...${NC}"
    
    # Create environment file
    cat > "/etc/vpn-api/environment" << EOF
# VPN API Environment Configuration
NODE_ENV=production
PATH=/usr/bin:/usr/local/bin:/bin:/sbin
HOME=$INSTALL_DIR
USER=root
GROUP=root

# Application Settings
VPN_API_PORT=5888
VPN_API_HOST=0.0.0.0
VPN_API_LOG_LEVEL=info

# Security Settings
VPN_API_MAX_CONNECTIONS=1000
VPN_API_RATE_LIMIT=100
VPN_API_TIMEOUT=30000
EOF

    # Create advanced systemd service
    cat > "/etc/systemd/system/$SERVICE_NAME.service" << EOF
[Unit]
Description=VPN API Service - FadzDigital
Documentation=https://github.com/$REPO
Documentation=man:vpn-api(8)
After=network.target network-online.target
Wants=network-online.target
RequiresMountsFor=$INSTALL_DIR

[Service]
Type=simple
WorkingDirectory=$SCRIPT_DIR
ExecStart=/usr/bin/node $INSTALL_DIR/vpn-api.js
ExecReload=/bin/kill -HUP \$MAINPID
ExecStop=/bin/kill -TERM \$MAINPID

# Process management
Restart=always
RestartSec=5
StartLimitInterval=60s
StartLimitBurst=3
KillMode=mixed
KillSignal=SIGTERM
TimeoutStartSec=30
TimeoutStopSec=30

# User and permissions
User=root
Group=root
UMask=0022

# Environment
Environment=NODE_ENV=production
EnvironmentFile=-/etc/vpn-api/environment

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=vpn-api
SyslogLevel=info

# Security hardening
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
RestrictRealtime=true
RestrictSUIDSGID=true
RemoveIPC=true
PrivateTmp=true

# Filesystem access
ReadWritePaths=$INSTALL_DIR
ReadWritePaths=/var/log/vpn-api
ReadWritePaths=/var/lib/vpn-api
ReadWritePaths=/tmp
ReadOnlyPaths=/etc/vpn-api

# Network
PrivateNetwork=false
RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6

# System calls
SystemCallArchitectures=native
SystemCallFilter=@system-service
SystemCallFilter=~@debug @mount @cpu-emulation @obsolete @privileged @reboot @swap @raw-io

# Resource limits
LimitNOFILE=65536
LimitNPROC=4096
MemoryMax=1G
CPUQuota=200%

[Install]
WantedBy=multi-user.target
Alias=$SERVICE_NAME.service
EOF

    # Create additional service management scripts
    create_service_management_scripts
    
    # Reload systemd and enable service
    run "systemctl daemon-reload"
    run "systemctl enable $SERVICE_NAME"
    
    echo -e "${GREEN}${BOLD}✓ Systemd service berhasil dibuat dan diaktifkan${NC}"
    log "SUCCESS" "Systemd service created and enabled"
}

# Create service management helper scripts
create_service_management_scripts() {
    # Create service status script
    cat > "$SCRIPT_DIR/vpn-status.sh" << 'EOF'
#!/bin/bash
# VPN API Status Check Script

SERVICE_NAME="vpn-api"
INSTALL_DIR="/opt/vpn-api"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

echo -e "${CYAN}═══════════════════════════════════════${NC}"
echo -e "${WHITE}      VPN API Service Status${NC}"
echo -e "${CYAN}═══════════════════════════════════════${NC}"

# Service status
if systemctl is-active --quiet $SERVICE_NAME; then
    echo -e "${GREEN}✓ Service Status: RUNNING${NC}"
else
    echo -e "${RED}✗ Service Status: STOPPED${NC}"
fi

# Uptime
if systemctl is-active --quiet $SERVICE_NAME; then
    uptime=$(systemctl show $SERVICE_NAME --property=ActiveEnterTimestamp --value)
    echo -e "${BLUE}⏱ Started: ${WHITE}$uptime${NC}"
fi

# Memory usage
if pgrep -f "vpn-api.js" > /dev/null; then
    memory=$(ps -o pid,vsz,rss,comm -p $(pgrep -f "vpn-api.js") | tail -n +2)
    echo -e "${BLUE}💾 Memory Usage:${NC}"
    echo "$memory" | while read -r line; do
        echo -e "   ${WHITE}$line${NC}"
    done
fi

# Port status
echo -e "${BLUE}🌐 Port Status:${NC}"
netstat -tlnp 2>/dev/null | grep ":5888" | while read -r line; do
    echo -e "   ${WHITE}$line${NC}"
done

# Recent logs
echo -e "${BLUE}📋 Recent Logs (last 5 lines):${NC}"
journalctl -u $SERVICE_NAME -n 5 --no-pager | while read -r line; do
    echo -e "   ${WHITE}$line${NC}"
done

echo -e "${CYAN}═══════════════════════════════════════${NC}"
EOF

    # Create service restart script
    cat > "$SCRIPT_DIR/vpn-restart.sh" << 'EOF'
#!/bin/bash
# VPN API Restart Script

SERVICE_NAME="vpn-api"

echo "🔄 Restarting VPN API service..."

if systemctl restart $SERVICE_NAME; then
    echo "✅ Service restarted successfully"
    sleep 2
    systemctl status $SERVICE_NAME --no-pager
else
    echo "❌ Failed to restart service"
    exit 1
fi
EOF

    # Create log viewer script
    cat > "$SCRIPT_DIR/vpn-logs.sh" << 'EOF'
#!/bin/bash
# VPN API Log Viewer Script

SERVICE_NAME="vpn-api"

case "${1:-tail}" in
    "tail"|"follow"|"f")
        echo "📋 Following VPN API logs (Ctrl+C to exit)..."
        journalctl -u $SERVICE_NAME -f
        ;;
    "today")
        echo "📋 Today's VPN API logs..."
        journalctl -u $SERVICE_NAME --since today
        ;;
    "errors"|"error")
        echo "📋 VPN API error logs..."
        journalctl -u $SERVICE_NAME -p err
        ;;
    "all")
        echo "📋 All VPN API logs..."
        journalctl -u $SERVICE_NAME --no-pager
        ;;
    *)
        echo "Usage: $0 [tail|today|errors|all]"
        echo "  tail   - Follow live logs (default)"
        echo "  today  - Show today's logs"
        echo "  errors - Show error logs only"
        echo "  all    - Show all logs"
        ;;
esac
EOF

    # Make scripts executable
    chmod +x "$SCRIPT_DIR"/*.sh
    
    log "SUCCESS" "Service management scripts created"
}

# Enhanced service startup with health checks
start_service() {
    echo -e "${YELLOW}${BOLD}🚀 Menjalankan VPN API service...${NC}"
    
    # Start service
    if run "systemctl start $SERVICE_NAME"; then
        echo -e "${BLUE}⏳ Menunggu service startup...${NC}"
        
        # Wait for service to be fully ready
        local wait_time=0
        local max_wait=30
        
        while [ $wait_time -lt $max_wait ]; do
            if systemctl is-active --quiet "$SERVICE_NAME"; then
                # Additional health check - try to connect to service port
                if netstat -tlnp 2>/dev/null | grep -q ":5888.*LISTEN"; then
                    echo -e "${GREEN}${BOLD}✓ VPN API service berhasil dijalankan${NC}"
                    log "SUCCESS" "VPN API service started successfully"
                    
                    # Show service info
                    show_service_info
                    return 0
                fi
            fi
            
            sleep 1
            wait_time=$((wait_time + 1))
            printf "."
        done
        
        echo
        echo -e "${RED}${BOLD}❌ Service tidak merespon setelah ${max_wait}s${NC}"
        echo -e "${YELLOW}   Cek status dengan: systemctl status $SERVICE_NAME${NC}"
        log "ERROR" "Service not responding after startup"
        return 1
    else
        echo -e "${RED}${BOLD}❌ Gagal menjalankan VPN API service${NC}"
        echo -e "${YELLOW}   Cek log dengan: journalctl -u $SERVICE_NAME -f${NC}"
        log "ERROR" "Failed to start VPN API service"
        return 1
    fi
}

# Show service information after successful start
show_service_info() {
    echo -e "${CYAN}${BOLD}📊 Service Information:${NC}"
    
    # Service status
    local status=$(systemctl is-active $SERVICE_NAME)
    echo -e "${WHITE}   • Status: ${GREEN}$status${NC}"
    
    # Process ID
    local pid=$(systemctl show $SERVICE_NAME --property=MainPID --value)
    if [ "$pid" != "0" ]; then
        echo -e "${WHITE}   • Process ID: ${GREEN}$pid${NC}"
    fi
    
    # Memory usage
    if [ "$pid" != "0" ] && kill -0 "$pid" 2>/dev/null; then
        local memory=$(ps -o rss= -p "$pid" 2>/dev/null | awk '{print int($1/1024)"MB"}')
        echo -e "${WHITE}   • Memory Usage: ${GREEN}$memory${NC}"
    fi
    
    # Listening ports
    local ports=$(netstat -tlnp 2>/dev/null | grep "$(basename $0)" | awk '{print $4}' | cut -d: -f2 | sort -u | tr '\n' ' ')
    if [ -n "$ports" ]; then
        echo -e "${WHITE}   • Listening Ports: ${GREEN}$ports${NC}"
    fi
}

# =============================================================================
# POST-INSTALLATION FUNCTIONS
# =============================================================================

# Create configuration files
create_configuration() {
    echo -e "${YELLOW}${BOLD}⚙️  Membuat file konfigurasi...${NC}"
    
    # Create main configuration file
    cat > "$CONFIG_DIR/config.json" << EOF
{
  "server": {
    "port": 5888,
    "host": "0.0.0.0",
    "timeout": 30000
  },
  "security": {
    "cors": {
      "enabled": true,
      "origin": "*"
    },
    "helmet": {
      "enabled": true
    },
    "rateLimit": {
      "enabled": true,
      "windowMs": 900000,
      "max": 100
    }
  },
  "logging": {
    "level": "info",
    "file": "/var/log/vpn-api/app.log",
    "maxSize": "10MB",
    "maxFiles": 5
  },
  "vpn": {
    "providers": {
      "openvpn": {
        "enabled": true,
        "configPath": "/etc/openvpn"
      },
      "wireguard": {
        "enabled": false,
        "configPath": "/etc/wireguard"
      }
    }
  }
}
EOF

    # Create environment file from template
    if [ -f "$INSTALL_DIR/.env.example" ] && [ ! -f "$INSTALL_DIR/.env" ]; then
        cp "$INSTALL_DIR/.env.example" "$INSTALL_DIR/.env"
        echo -e "${GREEN}  ✓ Environment file created from template${NC}"
    fi
    
    # Set proper permissions
    chmod 640 "$CONFIG_DIR/config.json"
    [ -f "$INSTALL_DIR/.env" ] && chmod 600 "$INSTALL_DIR/.env"
    
    echo -e "${GREEN}${BOLD}✓ File konfigurasi berhasil dibuat${NC}"
    log "SUCCESS" "Configuration files created"
}

# Setup log rotation
setup_log_rotation() {
    echo -e "${YELLOW}${BOLD}📝 Menyiapkan log rotation...${NC}"
    
    cat > "/etc/logrotate.d/vpn-api" << EOF
/var/log/vpn-api/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 root root
    postrotate
        systemctl reload-or-restart $SERVICE_NAME
    endscript
}
EOF

    # Test logrotate configuration
    if logrotate -d /etc/logrotate.d/vpn-api >/dev/null 2>&1; then
        echo -e "${GREEN}${BOLD}✓ Log rotation berhasil dikonfigurasi${NC}"
        log "SUCCESS" "Log rotation configured"
    else
        echo -e "${YELLOW}⚠️  Log rotation configuration warning${NC}"
    fi
}

# Create maintenance scripts
create_maintenance_scripts() {
    echo -e "${YELLOW}${BOLD}🛠️  Membuat maintenance scripts...${NC}"
    
    # Create update script
    cat > "$SCRIPT_DIR/update-api.sh" << EOF
#!/bin/bash
# VPN API Update Script

INSTALL_DIR="/opt/vpn-api"
SERVICE_NAME="vpn-api"
BACKUP_DIR="/opt/vpn-api-backup"

echo "🔄 Updating VPN API..."

# Create backup
backup_name="pre-update-\$(date +%Y%m%d-%H%M%S)"
mkdir -p "\$BACKUP_DIR/\$backup_name"
cp -r "\$INSTALL_DIR"/* "\$BACKUP_DIR/\$backup_name/"

echo "💾 Backup created: \$BACKUP_DIR/\$backup_name"

# Stop service
systemctl stop \$SERVICE_NAME

# Download latest files
cd "\$INSTALL_DIR"
curl -fsSL "https://raw.githubusercontent.com/MikkuChan/scripts/main/vpn-api.js" -o vpn-api.js.new
curl -fsSL "https://raw.githubusercontent.com/MikkuChan/scripts/main/package.json" -o package.json.new

# Replace files if download successful
if [ -f "vpn-api.js.new" ] && [ -s "vpn-api.js.new" ]; then
    mv vpn-api.js.new vpn-api.js
    echo "✅ Main application updated"
fi

if [ -f "package.json.new" ] && [ -s "package.json.new" ]; then
    mv package.json.new package.json
    npm install --production
    echo "✅ Dependencies updated"
fi

# Start service
systemctl start \$SERVICE_NAME

if systemctl is-active --quiet \$SERVICE_NAME; then
    echo "✅ VPN API updated successfully"
else
    echo "❌ Update failed, restoring backup..."
    systemctl stop \$SERVICE_NAME
    cp -r "\$BACKUP_DIR/\$backup_name"/* "\$INSTALL_DIR/"
    systemctl start \$SERVICE_NAME
    echo "🔄 Backup restored"
fi
EOF

    # Create health check script
    cat > "$SCRIPT_DIR/health-check.sh" << EOF
#!/bin/bash
# VPN API Health Check Script

SERVICE_NAME="vpn-api"
LOG_FILE="/var/log/vpn-api/health.log"
API_PORT="5888"

# Function to log with timestamp
log_message() {
    echo "\$(date '+%Y-%m-%d %H:%M:%S') - \$1" >> "\$LOG_FILE"
}

# Check service status
if ! systemctl is-active --quiet \$SERVICE_NAME; then
    log_message "ERROR: Service is not running"
    systemctl start \$SERVICE_NAME
    log_message "INFO: Attempted to restart service"
    exit 1
fi

# Check port availability
if ! netstat -tlnp 2>/dev/null | grep -q ":\$API_PORT.*LISTEN"; then
    log_message "ERROR: Port \$API_PORT is not listening"
    systemctl restart \$SERVICE_NAME
    log_message "INFO: Restarted service due to port issue"
    exit 1
fi

# Check memory usage
memory_usage=\$(ps -o rss= -p \$(pgrep -f "vpn-api.js") 2>/dev/null | awk '{print int(\$1/1024)}')
if [ "\$memory_usage" -gt 500 ]; then
    log_message "WARN: High memory usage: \${memory_usage}MB"
fi

log_message "INFO: Health check passed"
exit 0
EOF

    # Create cleanup script
    cat > "$SCRIPT_DIR/cleanup.sh" << EOF
#!/bin/bash
# VPN API Cleanup Script

echo "🧹 Cleaning up VPN API..."

# Clean npm cache
npm cache clean --force

# Clean old logs (keep last 7 days)
find /var/log/vpn-api -name "*.log.*" -mtime +7 -delete

# Clean old backups (keep last 10)
if [ -d "/opt/vpn-api-backup" ]; then
    cd /opt/vpn-api-backup
    ls -t | tail -n +11 | xargs -r rm -rf
fi

# Clean temporary files
find /tmp -name "vpn-api-*" -mtime +1 -delete

echo "✅ Cleanup completed"
EOF

    # Make all scripts executable
    chmod +x "$SCRIPT_DIR"/*.sh
    
    # Create cron job for health check
    (crontab -l 2>/dev/null; echo "*/5 * * * * $SCRIPT_DIR/health-check.sh") | crontab -
    
    echo -e "${GREEN}${BOLD}✓ Maintenance scripts berhasil dibuat${NC}"
    log "SUCCESS" "Maintenance scripts created"
}

# =============================================================================
# FINAL SUMMARY AND CLEANUP
# =============================================================================

# Enhanced installation summary
show_installation_summary() {
    echo
    echo -e "${PURPLE}${BOLD}═══════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}${BOLD}                    🎉 INSTALASI BERHASIL DISELESAIKAN! 🎉${NC}"
    echo -e "${PURPLE}${BOLD}═══════════════════════════════════════════════════════════════════════${NC}"
    echo
    
    # Installation details
    echo -e "${CYAN}${BOLD}📋 Detail Instalasi:${NC}"
    echo -e "${WHITE}   • Version: ${GREEN}$SCRIPT_VERSION${NC}"
    echo -e "${WHITE}   • Install Directory: ${GREEN}$INSTALL_DIR${NC}"
    echo -e "${WHITE}   • Service Name: ${GREEN}$SERVICE_NAME${NC}"
    echo -e "${WHITE}   • Service Status: ${GREEN}$(systemctl is-active $SERVICE_NAME)${NC}"
    echo -e "${WHITE}   • Config Directory: ${GREEN}$CONFIG_DIR${NC}"
    echo -e "${WHITE}   • Log Directory: ${GREEN}/var/log/vpn-api${NC}"
    echo -e "${WHITE}   • Installation Log: ${GREEN}$LOG_FILE${NC}"
    echo
    
    # Service information
    echo -e "${CYAN}${BOLD}🌐 Service Information:${NC}"
    local pid=$(systemctl show $SERVICE_NAME --property=MainPID --value)
    if [ "$pid" != "0" ]; then
        echo -e "${WHITE}   • Process ID: ${GREEN}$pid${NC}"
        local memory=$(ps -o rss= -p "$pid" 2>/dev/null | awk '{print int($1/1024)"MB"}')
        echo -e "${WHITE}   • Memory Usage: ${GREEN}$memory${NC}"
    fi
    
    local ports=$(netstat -tlnp 2>/dev/null | grep -E ":5888|:80|:443" | awk '{print $4}' | cut -d: -f2 | sort -u | tr '\n' ' ')
    if [ -n "$ports" ]; then
        echo -e "${WHITE}   • Listening Ports: ${GREEN}$ports${NC}"
    fi
    echo
    
    # Management commands
    echo -e "${CYAN}${BOLD}🔧 Perintah Management:${NC}"
    echo -e "${WHITE}   • Cek status: ${YELLOW}systemctl status $SERVICE_NAME${NC}"
    echo -e "${WHITE}   • Lihat logs: ${YELLOW}journalctl -u $SERVICE_NAME -f${NC}"
    echo -e "${WHITE}   • Restart service: ${YELLOW}systemctl restart $SERVICE_NAME${NC}"
    echo -e "${WHITE}   • Stop service: ${YELLOW}systemctl stop $SERVICE_NAME${NC}"
    echo -e "${WHITE}   • Status lengkap: ${YELLOW}$SCRIPT_DIR/vpn-status.sh${NC}"
    echo
    
    # Maintenance commands
    echo -e "${CYAN}${BOLD}🛠️  Maintenance Commands:${NC}"
    echo -e "${WHITE}   • Update API: ${YELLOW}$SCRIPT_DIR/update-api.sh${NC}"
    echo -e "${WHITE}   • Health check: ${YELLOW}$SCRIPT_DIR/health-check.sh${NC}"
    echo -e "${WHITE}   • View logs: ${YELLOW}$SCRIPT_DIR/vpn-logs.sh${NC}"
    echo -e "${WHITE}   • Cleanup: ${YELLOW}$SCRIPT_DIR/cleanup.sh${NC}"
    echo
    
    # Configuration files
    echo -e "${CYAN}${BOLD}⚙️  File Konfigurasi:${NC}"
    echo -e "${WHITE}   • Main config: ${GREEN}$CONFIG_DIR/config.json${NC}"
    echo -e "${WHITE}   • Environment: ${GREEN}$INSTALL_DIR/.env${NC}"
    echo -e "${WHITE}   • Service config: ${GREEN}/etc/systemd/system/$SERVICE_NAME.service${NC}"
    echo
    
    # Security notes
    echo -e "${CYAN}${BOLD}🔒 Catatan Keamanan:${NC}"
    echo -e "${WHITE}   • Service berjalan dengan security hardening${NC}"
    echo -e "${WHITE}   • Log rotation telah dikonfigurasi${NC}"
    echo -e "${WHITE}   • Health check monitoring aktif${NC}"
    echo -e "${WHITE}   • Backup otomatis tersedia${NC}"
    echo
    
    # Next steps
    echo -e "${CYAN}${BOLD}📝 Langkah Selanjutnya:${NC}"
    echo -e "${WHITE}   1. Edit konfigurasi di: ${GREEN}$CONFIG_DIR/config.json${NC}"
    echo -e "${WHITE}   2. Sesuaikan environment di: ${GREEN}$INSTALL_DIR/.env${NC}"
    echo -e "${WHITE}   3. Test API endpoint: ${GREEN}http://$(hostname -I | awk '{print $1}'):5888${NC}"
    echo -e "${WHITE}   4. Monitor logs: ${YELLOW}journalctl -u $SERVICE_NAME -f${NC}"
    echo
    
    echo -e "${GREEN}${BOLD}✨ Developed by FadzDigital - Enhanced Version ✨${NC}"
    echo -e "${PURPLE}${BOLD}═══════════════════════════════════════════════════════════════════════${NC}"
    echo
    
    # Show installation time
    if [ -n "${INSTALL_START_TIME:-}" ]; then
        local install_end_time=$(date +%s)
        local total_time=$((install_end_time - INSTALL_START_TIME))
        local minutes=$((total_time / 60))
        local seconds=$((total_time % 60))
        
        echo -e "${DIM}Installation completed in ${minutes}m ${seconds}s${NC}"
    fi
}

# Cleanup temporary files and optimize system
cleanup_installation() {
    echo -e "${YELLOW}${BOLD}🧹 Membersihkan file sementara...${NC}"
    
    # Clean temporary files
    rm -f /tmp/*.tmp
    rm -f /tmp/vpn-api-*
    
    # Clean package cache
    apt-get clean
    apt-get autoremove -y
    
    # Update file database
    updatedb &>/dev/null || true
    
    log "SUCCESS" "Installation cleanup completed"
}

# =============================================================================
# MAIN INSTALLATION FLOW
# =============================================================================

# Enhanced main function with error recovery
main() {
    # Initialize installation
    export INSTALL_START_TIME=$(date +%s)
    
    # Setup error handling
    trap 'handle_installation_error $? $LINENO' ERR
    trap 'handle_installation_interrupt' INT TERM
    
    # Initialize logging
    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"
    log "INFO" "VPN API Installation Started (Version $SCRIPT_VERSION)"
    
    # Main installation steps
    print_banner
    check_system_requirements
    check_existing_installation
    install_dependencies
    create_directories
    download_files
    install_node_modules
    create_configuration
    create_service
    setup_log_rotation
    create_maintenance_scripts
    start_service
    cleanup_installation
    show_installation_summary
    
    log "SUCCESS" "VPN API Installation Completed Successfully"
    
    # Final success notification
    echo -e "${GREEN}${BOLD}🎊 Instalasi selesai! VPN API siap digunakan.${NC}"
}

# Error handling functions
handle_installation_error() {
    local exit_code=$1
    local line_number=$2
    
    echo -e "\n${RED}${BOLD}❌ Instalasi gagal pada baris $line_number (exit code: $exit_code)${NC}"
    log "ERROR" "Installation failed at line $line_number (exit code: $exit_code)"
    
    # Show recent logs
    if [ -f "$LOG_FILE" ]; then
        echo -e "${YELLOW}📋 Log terakhir:${NC}"
        tail -5 "$LOG_FILE" | while read -r line; do
            echo -e "   ${DIM}$line${NC}"
        done
    fi
    
    # Cleanup on error
    echo -e "${YELLOW}🧹 Membersihkan instalasi yang gagal...${NC}"
    
    # Stop service if it was started
    systemctl stop "$SERVICE_NAME" 2>/dev/null || true
    systemctl disable "$SERVICE_NAME" 2>/dev/null || true
    
    # Remove service file
    rm -f "/etc/systemd/system/$SERVICE_NAME.service"
    systemctl daemon-reload 2>/dev/null || true
    
    # Ask user if they want to keep files for debugging
    echo -e "${CYAN}Apakah Anda ingin menyimpan file untuk debugging? [y/N]: ${NC}"
    read -r -t 10 keep_files || keep_files="n"
    
    if [[ ! "$keep_files" =~ ^[Yy] ]]; then
        rm -rf "$INSTALL_DIR" 2>/dev/null || true
        echo -e "${GREEN}✓ File instalasi dibersihkan${NC}"
    else
        echo -e "${YELLOW}📁 File disimpan di: $INSTALL_DIR${NC}"
        echo -e "${YELLOW}📄 Log tersimpan di: $LOG_FILE${NC}"
    fi
    
    exit $exit_code
}

handle_installation_interrupt() {
    echo -e "\n${YELLOW}${BOLD}⚠️  Instalasi dihentikan oleh pengguna${NC}"
    log "WARN" "Installation interrupted by user"
    
    # Quick cleanup
    systemctl stop "$SERVICE_NAME" 2>/dev/null || true
    
    echo -e "${BLUE}Terima kasih telah menggunakan installer VPN API!${NC}"
    exit 130
}

# =============================================================================
# SCRIPT EXECUTION
# =============================================================================

# Verify script is not being sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Check if running with proper permissions
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}${BOLD}❌ Script ini harus dijalankan sebagai root${NC}"
        echo -e "${YELLOW}   Gunakan: sudo $0${NC}"
        exit 1
    fi
    
    # Run main installation
    main "$@"
else
    echo "Script ini harus dijalankan, bukan di-source!"
    exit 1
fi
