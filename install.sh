#!/bin/bash
# =============================================================================
# VPN API Installation Script - Enhanced Edition
# Version: 2.0
# Author: VPN API Team
# License: MIT
# =============================================================================

set -euo pipefail

# =============================================================================
# GLOBAL CONFIGURATIONS
# =============================================================================

# Color definitions (Vibrant and Modern Palette)
declare -r RED='\033[1;31m'      # Neon Red
declare -r GREEN='\033[1;32m'    # Neon Green
declare -r YELLOW='\033[1;33m'   # Bright Yellow
declare -r BLUE='\033[1;34m'     # Electric Blue
declare -r PURPLE='\033[1;35m'   # Neon Purple
declare -r CYAN='\033[1;36m'     # Aqua Cyan
declare -r WHITE='\033[1;37m'    # Bright White
declare -r BOLD='\033[1m'
declare -r DIM='\033[2m'
declare -r NC='\033[0m'          # No Color
declare -r ORANGE='\033[1;38;5;208m'  # Neon Orange
declare -r PINK='\033[1;38;5;201m'    # Neon Pink

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

# Enhanced banner with modern ASCII art and gradient effect
print_banner() {
    clear
    echo -e "${CYAN}${BOLD}"

    # Modern ASCII Art Banner
    local banner_lines=(
        "  ____ ___  ____   ____ ___  _          ____ ___ "
        " | __ )_ _|  _ \\ / ___/ _ \\| |        | __ )_ _|"
        " |  _ \\| || |_) | |  | | | | |        |  _ \\| | "
        " | |_) | ||  _ < | |__| |_| | |___     | |_) | | "
        " |____/___|_| \\_\\ \\____\\___/|_____|    |____/___|"
        "                                                 "
    )

    # Gradient color effect for banner
    local colors=("${CYAN}" "${BLUE}" "${PURPLE}" "${PINK}" "${ORANGE}")
    local color_index=0
    for line in "${banner_lines[@]}"; do
        echo -e "${colors[$color_index]}${line}${NC}"
        color_index=$(( (color_index + 1) % ${#colors[@]} ))
        sleep 0.05  # Smooth animation
    done

    echo -e "${NC}"
    echo -e "${PURPLE}${BOLD}┌────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${WHITE}${BOLD}│                VPN API INSTALLER v${SCRIPT_VERSION}                 │${NC}"
    echo -e "${GREEN}${BOLD}│          Secure • Fast • Modern by VPN API Team          │${NC}"
    echo -e "${DIM}│                Built for Ultimate Performance               │${NC}"
    echo -e "${PURPLE}${BOLD}└────────────────────────────────────────────────────────────┘${NC}"
    echo
}

# Enhanced logging with levels
log() {
    local level="${1:-INFO}"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
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

# Advanced spinner with vibrant animations
spinner() {
    local pid=$1
    local message="$2"
    local animation="${3:-dots}"
    local delay=0.1
    
    case "$animation" in
        "dots")
            local spin='⣾⣽⣻⢿⡿⣟⣯⣷'
            ;;
        "bars")
            local spin='▁▂▃▄▅▆▇█'
            ;;
        "arrows")
            local spin='↻↺'
            ;;
        *)
            local spin='⣾⣽⣻⢿⡿⣟⣯⣷'
            ;;
    esac
    
    local i=0
    local start_time=$(date +%s)
    
    while kill -0 $pid 2>/dev/null; do
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        printf "\r${ORANGE}${BOLD}%c${NC} ${WHITE}%s${NC} ${DIM}[%ds]${NC}" \
               "${spin:$i:1}" "$message" "$elapsed"
        
        sleep $delay
        i=$(( (i + 1) % ${#spin} ))
    done
    
    wait $pid
    local exit_code=$?
    local end_time=$(date +%s)
    local total_time=$((end_time - start_time))
    
    if [ $exit_code -eq 0 ]; then
        printf "\r${GREEN}${BOLD}✅${NC} ${WHITE}%s${NC} ${GREEN}[SUCCESS]${NC} ${DIM}(${total_time}s)${NC}\n"
        log "SUCCESS" "$message (${total_time}s)"
    else
        printf "\r${RED}${BOLD}❌${NC} ${WHITE}%s${NC} ${RED}[FAILED]${NC} ${DIM}(${total_time}s)${NC}\n"
        log "ERROR" "$message failed (${total_time}s)"
        return $exit_code
    fi
}

# Enhanced command execution with retry mechanism
run() {
    local cmd="$*"
    local max_retries="${MAX_RETRIES:-3}"
    local retry_delay="${RETRY_DELAY:-2}"
    local attempt=1
    
    log "Executing: $cmd"
    
    while [ $attempt -le $max_retries ]; do
        {
            eval "$cmd" 2>&1
        } &
        
        local pid=$!
        
        if [ $attempt -eq 1 ]; then
            spinner $pid "$cmd" "dots"
        else
            spinner $pid "$cmd (Attempt $attempt/$max_retries)" "bars"
        fi
        
        local exit_code=$?
        
        if [ $exit_code -eq 0 ]; then
            return 0
        else
            log "WARN" "Attempt $attempt failed for: $cmd"
            
            if [ $attempt -lt $max_retries ]; then
                echo -e "${YELLOW}⚠️ Attempt $attempt failed, retrying in ${retry_delay}s...${NC}"
                sleep $retry_delay
                attempt=$((attempt + 1))
            else
                echo -e "${RED}${BOLD}❌ All attempts failed for: $cmd${NC}"
                log "ERROR" "All attempts failed for: $cmd"
                return $exit_code
            fi
        fi
    done
}

# Enhanced progress bar with ETA and vibrant colors
progress_bar() {
    local current=$1
    local total=$2
    local message="${3:-Processing}"
    local width=50
    local percentage=$((current * 100 / total))
    local completed=$((current * width / total))
    local remaining=$((width - completed))
    
    local eta=""
    if [ $current -gt 0 ] && [ ! -z "${PROGRESS_START_TIME:-}" ]; then
        local elapsed=$(($(date +%s) - PROGRESS_START_TIME))
        local rate=$((current * 1000 / (elapsed + 1)))
        local remaining_items=$((total - current))
        local eta_seconds=$((remaining_items * 1000 / (rate + 1)))
        
        if [ $eta_seconds -lt 60 ]; then
            eta=" ETA: ${eta_seconds}s"
        else
            eta=" ETA: $((eta_seconds / 60))m $((eta_seconds % 60))s"
        fi
    fi
    
    printf "\r${PINK}[${NC}"
    printf "%*s" $completed | tr ' ' '█'
    printf "%*s" $remaining | tr ' ' '░'
    printf "${PINK}] ${WHITE}%d%%${NC} ${YELLOW}(%d/%d)${NC} ${DIM}%s${NC}%s" \
           $percentage $current $total "$message" "$eta"
}

# =============================================================================
# SYSTEM VALIDATION FUNCTIONS
# =============================================================================

check_system_requirements() {
    echo -e "${YELLOW}${BOLD}🔍 Checking system requirements...${NC}"
    
    local checks_passed=0
    local total_checks=7
    
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}${BOLD}❌ Script must be run as root${NC}"
        echo -e "${YELLOW}   Use: sudo $0${NC}"
        return 1
    fi
    checks_passed=$((checks_passed + 1))
    
    if ! command -v apt-get >/dev/null 2>&1; then
        echo -e "${RED}${BOLD}❌ Unsupported OS (Ubuntu/Debian required)${NC}"
        return 1
    fi
    checks_passed=$((checks_passed + 1))
    
    local memory_gb=$(free -g | awk '/^Mem:/{print $2}')
    if [ "$memory_gb" -lt $MIN_MEMORY_GB ]; then
        echo -e "${RED}${BOLD}❌ Insufficient RAM (minimum ${MIN_MEMORY_GB}GB, available ${memory_gb}GB)${NC}"
        return 1
    fi
    checks_passed=$((checks_passed + 1))
    
    local disk_gb=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "$disk_gb" -lt $MIN_DISK_G ]; then
        echo -e "${RED}${BOLD}❌ Insufficient disk space (minimum ${MIN_DISK_GB}G, available ${disk_gb}G)${NC}" 
        return 1
    fi
    checks_passed=$((checks_passed + 1))
    
    if ! ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1; then
        echo -e "${RED}${BOLD}❌ No internet connection${NC}"
        return 1
    fi
    checks_passed=$((checks_passed + 1))
    
    if ! curl -s --connect-timeout 10 https://api.github.com/repos/$REPO >/dev/null; then
        echo -e "${RED}${BOLD}❌ Cannot access GitHub repository${NC}"
        return 1
    fi
    checks_passed=$((checks_passed + 1))
    
    local ports_available=true
    for port in "${REQUIRED_PORTS[@]}"; do
        if netstat -ln 2>/dev/null | grep -q ":$port "; then
            echo -e "${YELLOW}⚠️ Port $port is already in use${NC}"
            ports_available=false
        fi
    done
    
    if [ "$ports_available" = true ]; then
        checks_passed=$((checks_passed + 1))
    fi
    
    echo -e "${GREEN}${BOLD}✅ System checks completed ($checks_passed/$total_checks)${NC}"
    
    if [ $checks_passed -eq $total_checks ]; then
        log "SUCCESS" "All system requirements met"
        return 0
    else
        log "ERROR" "System requirements not met ($checks_passed/$total_checks)"
        return 1
    fi
}

check_existing_installation() {
    local has_existing=false
    
    echo -e "${YELLOW}${BOLD}🔍 Checking for existing installation...${NC}"
    
    if [ -d "$INSTALL_DIR" ]; then
        echo -e "${BLUE}   • Installation directory found: ${WHITE}$INSTALL_DIR${NC}"
        has_existing=true
    fi
    
    if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        echo -e "${BLUE}   • Service active: ${WHITE}$SERVICE_NAME${NC}"
        has_existing=true
    fi
    
    if [ -f "/etc/systemd/system/$SERVICE_NAME.service" ]; then
        echo -e "${BLUE}   • Service file found${NC}"
        has_existing=true
    fi
    
    if [ "$has_existing" = true ]; then
        echo -e "${YELLOW}${BOLD}⚠️ Existing VPN API installation detected${NC}"
        echo
        
        show_current_installation()
        
        echo -e "${CYAN}${BOLD}Available options:${NC}"
        echo -e "${WHITE}  [1] Remove and reinstall (Recommended)${NC}"
        echo -e "${WHITE}  [2] Backup and reinstall${NC}"
        echo -e "${WHITE}  [3] Update only (Keep config)${NC}"
        echo -e "${WHITE}  [4] Cancel installation${NC}"
        echo
        
        while true; do
            echo -e "${CYAN}${BOLD}Select option [1-4]: ${NC}"
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
                    echo -e "${RED}${BOLD}Installation cancelled${NC}"
                    log "INFO" "Installation cancelled by user"
                    exit 0
                    ;;
                *)
                    echo -e "${YELLOW}Invalid option. Please select 1-4${NC}"
                    ;;
            esac
        done
    else
        echo -e "${GREEN}${BOLD}✅ No previous installation found${NC}"
    fi
}

show_current_installation() {
    echo -e "${CYAN}${BOLD}📋 Current Installation Info:${NC}"
    
    if [ -d "$INSTALL_DIR" ]; then
        local install_size=$(du -sh "$INSTALL_DIR" 2>/dev/null | cut -f1)
        echo -e "${WHITE}   • Installation size: ${GREEN}$install_size${NC}"
        
        if [ -f "$INSTALL_DIR/package.json" ]; then
            local version=$(grep '"version"' "$INSTALL_DIR/package.json" 2>/dev/null | cut -d'"' -f4)
            echo -e "${WHITE}   • Version: ${GREEN}${version:-"Unknown"}${NC}"
        fi
    fi
    
    if systemctl is-enabled --quiet "$SERVICE_NAME" 2>/dev/null; then
        local status=$(systemctl is-active "$SERVICE_NAME" 2>/dev/null)
        local uptime=$(systemctl show "$SERVICE_NAME" --property=ActiveEnterTimestamp --value 2>/dev/null)
        echo -e "${WHITE}   • Service status: ${GREEN}$status${NC}"
        [ -n "$UPTIME" ] && echo -e "${WHITE}   • Uptime: ${GREEN}$uptime${NC}"
    fi
    
    echo
}

backup_existing_installation() {
    echo -e "${YELLOW}${BOLD}💾 Backing up existing installation...${NC}"
    
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
    
    echo -e "${GREEN}${BOLD}✅ Backup saved to: ${WHITE}$backup_path${NC}"
    log "SUCCESS" "Backup created at $backup_path"
}

remove_existing_installation() {
    echo -e "${YELLOW}${BOLD}🗑️ Removing existing installation...${NC}"
    
    local removal_steps=4
    local current_step=0
    
    if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        current_step=$((current_step + 1))
        progress_bar $current_step $removal_steps "Stopping service"
        run "systemctl stop $SERVICE_NAME"
    fi
    
    if systemctl is-enabled --quiet "$SERVICE_NAME" 2>/dev/null; then
        current_step=$((current_step + 1))
        progress_bar $current_step $removal_steps "Disabling service"
        run "systemctl disable $SERVICE_NAME"
    fi
    
    if [ -f "/etc/systemd/system/$SERVICE_NAME.service" ]; then
        current_step=$((current_step + 1))
        progress_bar $current_step $removal_steps "Removing service file"
        run "rm -f /etc/systemd/system/$SERVICE_NAME.service"
        run "systemctl daemon-reload"
    fi
    
    if [ -d "$INSTALL_DIR" ]; then
        current_step=$((current_step + 1))
        progress_bar $current_step $removal_steps "Removing installation directory"
        run "rm -rf $INSTALL_DIR"
    fi
    
    echo
    echo -e "${GREEN}${BOLD}✅ Previous installation removed${NC}"
    log "SUCCESS" "Previous installation removed successfully"
}

# =============================================================================
# INSTALLATION FUNCTIONS
# =============================================================================

install_dependencies() {
    echo -e "${YELLOW}${BOLD}📦 Installing dependencies...${NC}"
    
    run "apt-get update -y"
    
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
    local current_count=0
    export PROGRESS_START_TIME=$(date +%s)
    
    for package_info in "${packages[@]}"; do
        local package_name=$(echo "$package_info" | cut -d':' -f1)
        local package_desc=$(echo "$package_info" | cut -d':' -f2)
        
        current=$((current + 1))
        progress_bar $current $total "Installing $package_name"
        
        if ! command -v "$package_name" >/dev/null 2>&1 && ! dpkg -l | grep -q "^ii  $package_name "; then
            if ! run "apt-get install -y $package_name"; then
                echo -e "${RED}${BOLD}❌ Failed to install $package_name${NC}"
                log "ERROR" "Failed to install $package_name"
                return 1
            fi
        else
            log "INFO" "$package_name already installed"
        fi
        
        sleep 0.1
    done
    
    echo
    
    local node_version=$(node --version 2>/dev/null || echo "Not found")
    local npm_version=$(npm --version 2>/dev/null || echo "Not found")
    
    echo -e "${CYAN}📋 Installed versions:${NC}"
    echo -e "${WHITE}   • Node.js: ${GREEN}$node_version${NC}"
    echo -e "${WHITE}   • npm: ${GREEN}$npm_version${NC}"
    
    if command -v node >/dev/null 2>&1; then
        local node_major=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
        if [ "$node_major" -lt 14 ]; then
            echo -e "${YELLOW}⚠️ Outdated Node.js version detected, upgrading...${NC}"
            run "curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -"
            run "apt-get install -y nodejs"
        
        fi
    fi
    
    echo -e "${GREEN}${BOLD}✅ All dependencies installed${NC}"
    log "SUCCESS" "All dependencies installed successfully"
}

create_directories() {
    echo -e "${YELLOW}${BOLD}📁 Creating directory structure...${NC}"
    
    local directories=(
        "$INSTALL_DIR/755:VPN API main directory"
        "$SCRIPT_DIR:755:Scripts directory"
        "$CONFIG_DIR:750:Configuration directory"
        "/var/log/vpn-api:755:Log directory"
        "/var/lib/vpn-api:755:Data directory"
        "/etc/vpn-api:750:config directory"
    )
    
    for dir_info in "${directories[@]}"; do
        local dir_path=$(echo "$dir_info" | cut -d':' | -f1)
        local dir_perms=$(echo "$dir_info" | cut -d':' | -f2)
        local dir_desc=$(echo "$dir_info" | cut -d': | -f3)
        
        if [ ! -d "$dir_path" ]; then
            run "mkdir -p $dir_path"
            run "chmod $dir_perms $dir_path"
            run "chown root:root $dir_path"
            
            echo -e "${GREEN}  ✅ Created: ${WHITE}$dir_path${NC} ${DIM}(${dir_desc})${NC}"
            log "SUCCESS" "Created directory: $dir_path"
        else
            echo -e "${BLUE}  ℹ️ Exists: ${WHITE}$dir_path${NC} ${DIM}(${dir_desc})${NC}"
        fi
    done
    
    echo -e "${GREEN}${BOLD}✅ Directory structure created${NC}"
}

download_files() {
    echo -e "${YELLOW}${BOLD}⬇️ Downloading files from GitHub...${NC}"
    
    cd "$INSTALL_DIR"
    
    local repo_info
    if ! repo_info=$(curl -s "https://api.github.com/repos/$REPO"); then
        echo -e "${RED}${BOLD}❌ Failed to access repository information${NC}"
        return 1
    fi
    
    local main_files=(
        "vpn-api.js:VPN API main application"
        "package.json:Node.js dependencies"
        "README.md:Documentation"
        ".env.example:Environment template"
    )
    
    local sh_files
    if ! sh_files=$(curl -s "https://api.github.com/repos/$REPO/contents?ref=$BRANCH" | jq -r '.[] | select(.name | endswith(".sh")) | select(.name != "install.sh") | .name'); then
        echo -e "${YELLOW}⚠️ Cannot retrieve shell scripts list${NC}"
        sh_files=""
    fi
    
    local total_files=${#main_files[@]}
    [ -n "$sh_files" ] && total_files=$((total_files + $(echo "$sh_files" | wc -l)))
    
    local current_file=0
    export PROGRESS_START_TIME=$(date +%s)
    
    for file_info in "${main_files[@]}"; do
        local filename=$(echo "$file_info" | cut -d':' -f1)
        local filedesc=$(echo "$file_info" | cut -d':' -f2)
        
        current_file=$((current_file + 1))
        progress_bar $current_file $total_files "Downloading $filename"
        
        local download_url="$RAW_URL/$filename"
        local temp_file="/tmp/${filename}.tmp"
        
        if curl -fsSL "$download_url" -o "$temp_file"; then
            if [ -s "$temp_file" ]; then
                mv "$temp_file" "$INSTALL_DIR/$filename"
                chmod 644 "$INSTALL_DIR/$filename"
                log "SUCCESS" "Downloaded: $filename"
            else
                echo -e "\n${YELLOW}⚠️ Empty file: $filename, skipping${NC}"
                rm -f "$temp_file"
            fi
        else
            echo -e "\n${YELLOW}⚠️ Failed to download: $filename, skipping${NC}"
            rm -f "$temp_file"
        fi
    done
    
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
    echo -e "${GREEN}${BOLD}✅ File download completed${NC}"
    
    local downloaded_count=$(find "$INSTALL_DIR" -type f | wc -l)
    echo -e "${CYAN}📋 Summary: ${WHITE}$downloaded_count${NC} files downloaded"
    
    log "SUCCESS" "Downloaded $downloaded_count files successfully"
}

install_node_modules() {
    echo -e "${YELLOW}${BOLD}📦 Installing Node.js dependencies...${NC}"
    
    cd "$INSTALL_DIR"
    
    if [ ! -f "package.json" ]; then
        echo -e "${YELLOW}⚠️ package.json not found, creating default...${NC}"
        
        cat > package.json << EOF
{
  "name": "vpn-api",
  "version": "1.0.0",
  "description": "VPN API Service",
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
  "author": "VPN API Team",
  "license": "MIT"
}
EOF
    fi
    
    if ! jq empty package.json 2>/dev/null; then
        echo -e "${RED}${BOLD}❌ Invalid package.json${NC}"
        return 1
    fi
    
    echo -e "${CYAN}📦 Installing dependencies...${NC}"
    
    run "npm config set progress=true"
    run "npm config set loglevel=warn"
    
    if run "npm install --production --no-audit --no-fund"; then
        local installed_packages=$(npm list --depth=0 --json 2>/dev/null | jq -r '.dependencies | keys | length' 2>/dev/null || echo "0")
        echo -e "${GREEN}${BOLD}✅ Dependencies installed${NC}"
        echo -e "${CYAN}📦 Total packages: ${WHITE}$installed_packages${NC}"
        log "SUCCESS" "Node.js dependencies installed ($installed_packages packages)"
    else
        echo -e "${RED}${BOLD}❌ Failed to install dependencies${NC}"
        log "ERROR" "Failed to install Node.js dependencies"
        return 1
    fi
    
    run "npm cache clean --force"
}

create_service() {
    echo -e "${YELLOW}${BOLD}⚙️ Creating systemd service...${NC}"
    
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

    cat > "/etc/systemd/system/$SERVICE_NAME.service" << EOF
[Unit]
Description=VPN API Service
Documentation=https://github.com/$REPO
After=network.target network-online.target
Wants=network-online.target
RequiresMountsFor=$INSTALL_DIR

[Service]
Type=simple
WorkingDirectory=$INSTALL_DIR
ExecStart=/usr/bin/node $INSTALL_DIR/vpn-api.js
ExecReload=/bin/kill -HUP $MAINPID
ExecStop=/bin/kill -TERM $MAINPID
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
LimitNOPROCS=4096
MemoryMax=1G
CPUQuota=200%

[Install]
WantedBy=multi-user.target
Alias=$SERVICE_NAME.service
EOF

    create_service_management()_scripts
    
    run "systemctl daemon-reload"
    run "systemctl enable $SERVICE_NAME"
    
    echo -e "${GREEN}${BOLD}✅ Service created and enabled${NC}"
    log "SUCCESS" "Systemd service created and enabled"
}

create_service_management()_scripts {
    cat > "$SCRIPT_DIR/vpn-status.sh" << 'EOF'
#!/bin/bash
# VPN API Status Script

SERVICE_NAME="vpn-api"
INSTALL_DIR="/opt/vpn-api"

# Colors
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

echo -e "${CYAN}┬───────────────────────────────${NC}"
echo -e "${WHITE}│ VPN API Service Status        │${NC}"
echo -e "${CYAN}└───────────────────────────────${NC}"

# Service status
if systemctl is-active --quiet $SERVICE_NAME; then
    echo -e "${GREEN}✅ Service Status: RUNNING${NC}"
else
    echo -e "${RED}❌ Service Status: STOPPED${NC}"
fi

# Uptime
if systemctl is-active --quiet $SERVICE_NAME; then
    uptime=$(systemctl show $SERVICE_NAME --property=ActiveEnterTimestamp --value)
    echo -e "${BLUE}⏱️ Started: ${WHITE}$uptime${NC}"
fi

# Memory usage
if pgrep -f "vpn-api.js" > /dev/null; then
    memory=$(ps -o pid,vsz,rss,comm -p $(pgrep -f "vpn-api.js") | tail -n +2)
    echo -e "${BLUE}💾 Memory Usage:${NC}"
    echo "$memory" | while read -r line; do
        echo -e " - ${WHITE}$line${NC}"
    done
fi

# Port status
echo -e "${BLUE}🌐 Port Status:${NC}"
netstat -tlnp 2>/dev/null | grep ":5888" | while read -r line; do
            echo -e " - ${WHITE}$line${NC}"
    done

# Recent logs
echo -e "${BLUE}📜 Recent Logs (last 5):${NC}"
journalctl -u $SERVICE_NAME -n 5 --no-pager | while read -r line; do
        echo -e " - ${WHITE}$line${NC}"
done

echo -e "${CYAN}└───────────────────────────────${NC}"
EOF

    cat > "$SCRIPT_DIR/vpn-restart.sh" << 'EOF'
#!/bin/bash
# VPN API Restart Script

SERVICE_NAME="vpn-api"

echo -e "${YELLOW}🔄 Restarting VPN API service...${NC}"

if systemctl restart $SERVICE_NAME; then
    echo -e "${GREEN}✅ Service restarted successfully${NC}"
    sleep 2
    systemctl status $SERVICE_NAME --no-pager
else
    echo -e "${RED}❌ Failed to restart service${NC}"
    exit 1
fi
EOF

    cat > "$SCRIPT_DIR/vpn-logs.sh" << 'EOF'
#!/bin/bash
# VPN API Log Viewer Script

SERVICE_NAME="vpn-api"

case "${1:-tail}" in
    "tail"|"follow"|"f")
        echo -e "${CYAN}📜 Following service logs (Ctrl+C to exit)... ${NC}"
        journalctl -u $SERVICE_NAME -f
        ;;
    "today")
        echo -e "${CYAN}📅 Today's logs...${NC}"
        journalctl -u $SERVICE_NAME --since today
        ;;
    "errors"|"error")
        echo -e "${CYAN}🚨 Error logs...${NC}"
        journalctl -u $SERVICE_NAME -p err
        ;;
    "all")
        echo -e "${CYAN}📚 All logs...${NC}"
        journalctl -u $SERVICE_NAME --no-pager
        ;;
    *)
        echo "Usage: $0 [tail|today|errors|all]"
        echo -e "${BLUE}  tail   - Follow live logs (default)${NC}"
        echo -e "${BLUE}  today  - Show today's logs${NC}"
        echo -e "${BLUE}  errors - Show error logs only${NC}"
        echo -e "${BLUE}  all    - Show all logs${NC}"
        ;;
esac
EOF

    chmod +x "$SCRIPT_DIR"/*.sh
    log "SUCCESS_LOGGED" "Service management scripts created"
}

start_service() {
    echo -e "${YELLOW}${BOLD}🚀 Starting VPN API service...${NC}"
    
    if run "systemctl start $SERVICE_NAME"; then
        echo -e "${BLUE}⏳ Waiting for service to start...${NC}"
        
        local wait_time=0
        local max_wait=30
        
        while [ $wait_time -lt $max_wait ]; do
            if systemctl is-active --quiet "$SERVICE_NAME"; then
                if netstat -tlnp 2>/dev/null | grep -q ":5888.*LISTEN"; then
                    echo -e "${GREEN}${BOLD}✅ Service started successfully${NC}"
                    log "SUCCESS" "VPN API service started successfully"
                    
                    show_service_info()
                    return 0
                fi
            fi
            
            sleep 1
            wait_time=$((wait_time + 1))
            printf "."
        done
        
        echo -e "${RED}${BOLD}❌ Service not responding after ${max_wait}s${NC}"
        echo -e "${YELLOW}   Check status with: systemctl status $SERVICE_NAME${NC}"
        log "ERROR" "Service not responding after startup"
        return 1
    else
        echo -e "${RED}${BOLD}❌ Failed to start service${NC}"
        echo -e "${YELLOW}   Check logs with: journalctl -u $SERVICE_NAME -f${NC}"
        log "ERROR" "Failed to start VPN service"
        return 1
    fi
}

show_service_info() {
    echo -e "${CYAN}${BOLD}📊 Service Information:${NC}"
    
    local status=$(systemctl is-active $SERVICE_NAME)
    echo -e "${WHITE}   • Status: ${GREEN}$status${NC}"
    
    local pid=$(systemctl show $SERVICE_NAME --property=MainPID --value)
    if [ "$pid" != "0" ]; then
        echo -e "${WHITE}   • Process ID: ${GREEN}$pid${NC}"
        
        local memory=$(ps -o rss= -p "$pid" 2>/dev/null | awk '{print int($1/1024)"MB"}')
        echo -e "${WHITE}   • Memory Usage: ${GREEN}$memory${NC}"
    fi
    
    local ports=$(netstat -tlnp 2>/dev/null | grep "$(basename $0)" | awk '{print $4}' | cut -d':' -f2 | sort -u | tr '\n' ' ')
    if [ -n "$ports" ]; then
        echo -e "${WHITE}   • Listening Ports: ${GREEN}$ports${NC}"
    fi
}

# =============================================================================
# Post-Installation Functions
# =============================================================================

create_configuration() {
    echo -e "${YELLOW}${BOLD}⚙️ Creating configuration files...${NC}"
    
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

    if [ -f "$INSTALL_DIR/.env.example" ] && [ ! -f "$INSTALL_DIR/.env" ]; then
        cp "$INSTALL_DIR/.env.example" "$INSTALL_DIR/.env"
        echo -e "${GREEN}  ✅ Environment file created${NC}"
    fi
    
    chmod 640 "$CONFIG_DIR/config.json"
    [ -f "$INSTALL_DIR/.env" ] && chmod 600 "$INSTALL_DIR/.env"
    
    echo -e "${GREEN}${BOLD}✅ Configuration files created${NC}"
    log "SUCCESS" "Configuration files created"
}

setup_log_rotation() {
    echo -e "${YELLOW}${BOLD}📝 Setting up log rotation...${NC}"
    
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

    if logrotate -d /etc/logrotate.d/vpn-api >/dev/null 2>&1; then
        echo -e "${GREEN}${BOLD}✅ Log rotation configured${NC}"
        log "SUCCESS" "Log rotation configured"
    else
        echo -e "${YELLOW}⚠️ Log rotation configuration warning${NC}"
    fi
}

create_maintenance_scripts() {
    echo -e "${YELLOW}${BOLD}🛠️ Creating maintenance scripts...${NC}"
    
    cat > "$SCRIPT_DIR/update-api.sh" << EOF
#!/bin/bash
# VPN API Update Script

INSTALL_DIR="/opt/vpn-api"
SERVICE_NAME="vpn-api"
BACKUP_DIR="/opt/vpn-api-backup"

echo -e "${YELLOW}🔗 Updating VPN API...${NC}"

backup_name="pre-update-\$(date +%Y%m%d-%H%M%S)"
mkdir -p "\$BACKUP_DIR/\$backup_name"
cp -r "\$INSTALL_DIR"/* "\$BACKUP_DIR/\$backup_name/"

echo -e "${GREEN}✅ Backup created: \$BACKUP_DIR/\$backup_name${NC}"

systemctl stop \$SERVICE_NAME

cd "\$INSTALL_DIR"
curl -fsSL "https://raw.githubusercontent.com/MikkuChan/scripts/main/vpn-api.js" -o vpn-api.js.new
curl -fsSL "https://raw.githubusercontent.com/MikkuChan/scripts/main/package.json" -o package.json.new

if [ -f "vpn-api.js.new" ] && [ -s "vpn-api.js.new" ]; then
    mv vpn-api.js.new vpn-api.js
    echo -e "${GREEN}✅ Main application updated${NC}"
fi

if [ -f "package.json.new" ] && [ -s "package.json.new" ]; then
    mv package.json.new package.json
    npm install --production
    echo -e "${GREEN}✅ Dependencies updated${NC}"
fi

systemctl start \$SERVICE_NAME

if systemctl is-active --quiet \$SERVICE_NAME; then
    echo -e "${GREEN}✅ VPN API updated successfully${NC}"
else
    echo -e "${RED}❌ Update failed, restoring backup...${NC}"
    systemctl stop \$SERVICE_NAME
    cp -r "\$BACKUP_DIR/\$backup_name"/* "\$INSTALL_DIR/"
    systemctl start \$SERVICE_NAME
    echo -e "${GREEN}✅ Backup restored${NC}"
fi
EOF

    cat > "$SCRIPT_DIR/health-check.sh" << EOF
#!/bin/bash
# VPN API Health Check Script

SERVICE_NAME="vpn-api"
LOG_FILE="/var/log/vpn-api/health.log"
API_PORT="5888"

log_message() {
    echo "\$(date '+%Y-%m-%d %H:%M:%S') - \$1" >> "\$LOG_FILE"
}

if ! systemctl is-active --quiet \$SERVICE_NAME; then
    log_message "ERROR: Service is not running"
    systemctl start \$SERVICE_NAME
    log_message "INFO: Attempted to restart service"
    exit 1
fi

if ! netstat -tlnp 2>/dev/null | grep -q ":\$API_PORT.*LISTEN"; then
    log_message "ERROR: Port \$API_PORT is not listening"
    systemctl restart \$SERVICE_NAME
    log_message "INFO: Restarted service due to port issue"
    exit 1
fi

memory_usage=\$(ps -o rss= -p \$(pgrep -f "vpn-api.js") 2>/dev/null | awk '{print int(\$1/1024)}')
if [ "\$memory_usage" -gt 500 ]; then
    log_message "WARN: High memory usage: \${memory_usage}MB"
fi

log_message "INFO: Health check passed"
exit 0
EOF

    cat > "$SCRIPT_DIR/cleanup.sh" << EOF
#!/bin/bash
# VPN API Cleanup Script

echo -e "${YELLOW}🧹 Cleaning up VPN API...${NC}"

npm cache clean --force

find /var/log/vpn-api -name "*.log.*" -mtime +7 -delete

if [ -d "/opt/vpn-api-backup" ]; then
    cd /opt/vpn-api-backup
    ls -t | tail -n +11 | xargs -r rm -rf
fi

find /tmp -name "vpn-api-*" -mtime +1 -delete

echo -e "${GREEN}✅ Cleanup completed${NC}"
EOF

    chmod +x "$SCRIPT_DIR"/*.sh
    
    (crontab -l 2>/dev/null; echo "*/5 * * * * $SCRIPT_DIR/health-check.sh") | crontab -
    
    echo -e "${GREEN}${BOLD}✅ Maintenance scripts created${NC}"
    log "SUCCESS" "Maintenance scripts created"
}

# =============================================================================
# FINAL SUMMARY AND CLEANUP
# =============================================================================

show_installation_summary() {
    echo
    echo -e "${PURPLE}${BOLD}┌────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${GREEN}${BOLD}│        🎉 INSTALLATION COMPLETED SUCCESSFULLY! 🎉         │${NC}"
    echo -e "${PURPLE}${BOLD}└────────────────────────────────────────────────────────────┘${NC}"
    echo
    
    echo -e "${CYAN}${BOLD}📋 Installation Details:${NC}"
    echo -e "${WHITE}   • Version: ${GREEN}$SCRIPT_VERSION${NC}"
    echo -e "${WHITE}   • Install Directory: ${GREEN}$INSTALL_DIR${NC}"
    echo -e "${WHITE}   • Service Name: ${GREEN}$SERVICE_NAME${NC}"
    echo -e "${WHITE}   • Service Status: ${GREEN}$(systemctl is-active $SERVICE_NAME)${NC}"
    echo -e "${WHITE}   • Config Directory: ${GREEN}$CONFIG_DIR${NC}"
    echo -e "${WHITE}   • Log Directory: ${GREEN}/var/log/vpn-api${NC}"
    echo -e "${WHITE}   • Installation Log: ${GREEN}$LOG_FILE${NC}"
    echo
    
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
    
    echo -e "${CYAN}${BOLD}🔧 Management Commands:${NC}"
    echo -e "${WHITE}   • Check status: ${YELLOW}systemctl status $SERVICE_NAME${NC}"
    echo -e "${WHITE}   • View logs: ${YELLOW}journalctl -u $SERVICE_NAME -f${NC}"
    echo -e "${WHITE}   • Restart service: ${YELLOW}systemctl restart $SERVICE_NAME${NC}"
    echo -e "${WHITE}   • Stop service: ${YELLOW}systemctl stop $SERVICE_NAME${NC}"
    echo -e "${WHITE}   • Detailed status: ${YELLOW}$SCRIPT_DIR/vpn-status.sh${NC}"
    echo
    
    echo -e "${CYAN}${BOLD}🛠️ Maintenance Commands:${NC}"
    echo -e "${WHITE}   • Update API: ${YELLOW}$SCRIPT_DIR/update-api.sh${NC}"
    echo -e "${WHITE}   • Health check: ${YELLOW}$SCRIPT_DIR/health-check.sh${NC}"
    echo -e "${WHITE}   • View logs: ${YELLOW}$SCRIPT_DIR/vpn-logs.sh${NC}"
    echo -e "${WHITE}   • Cleanup: ${YELLOW}$SCRIPT_DIR/cleanup.sh${NC}"
    echo
    
    echo -e "${CYAN}${BOLD}⚙️ Configuration Files:${NC}"
    echo -e "${WHITE}   • Main config: ${GREEN}$CONFIG_DIR/config.json${NC}"
    echo -e "${WHITE}   • Environment: ${GREEN}$INSTALL_DIR/.env${NC}"
    echo -e "${WHITE}   • Service config: ${GREEN}/etc/systemd/system/$SERVICE_NAME.service${NC}"
    echo
    
    echo -e "${CYAN}${BOLD}🔒 Security Notes:${NC}"
    echo -e "${WHITE}   • Service runs with security hardening${NC}"
    echo -e "${WHITE}   • Log rotation configured${NC}"
    echo -e "${WHITE}   • Health monitoring enabled${NC}"
    echo -e "${WHITE}   • Automatic backups available${NC}"
    echo
    
    echo -e "${CYAN}${BOLD}📝 Next Steps:${NC}"
    echo -e "${WHITE}   1. Edit configuration: ${GREEN}$CONFIG_DIR/config.json${NC}"
    echo -e "${WHITE}   2. Adjust environment: ${GREEN}$INSTALL_DIR/.env${NC}"
    echo -e "${WHITE}   3. Test API endpoint: ${GREEN}http://$(hostname -I | awk '{print $1}'):5888${NC}"
    echo -e "${WHITE}   4. Monitor logs: ${YELLOW}journalctl -u $SERVICE_NAME -f${NC}"
    echo
    
    echo -e "${GREEN}${BOLD}✨ Powered by VPN API Team ✨${NC}"
    echo -e "${PURPLE}${BOLD}└────────────────────────────────────────────────────────────┘${NC}"
    echo
    
    if [ -n "${INSTALL_START_TIME:-}" ]; then
        local install_end_time=$(date +%s)
        local total_time=$((install_end_time - INSTALL_START_TIME))
        local minutes=$((total_time / 60))
        local seconds=$((total_time % 60))
        
        echo -e "${DIM}Installation completed in ${minutes}m ${seconds}s${NC}"
    fi
}

cleanup_installation() {
    echo -e "${YELLOW}${BOLD}🧹 Cleaning up temporary files...${NC}"
    
    rm -f /tmp/*.tmp
    rm -f /tmp/vpn-api-*
    
    apt-get clean
    apt-get autoremove -y
    
    updatedb &>/dev/null || true
    
    log "SUCCESS" "Installation cleanup completed"
}

# =============================================================================
# MAIN INSTALLATION FLOW
# =============================================================================

main() {
    export INSTALL_START_TIME=$(date +%s)
    
    trap 'handle_installation_error $? $LINENO' ERR
    trap 'handle_installation_interrupt' INT TERM
    
    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"
    log "INFO" "VPN API Installation Started (Version $SCRIPT_VERSION)"
    
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
    
    echo -e "${GREEN}${BOLD}🎊 Installation complete! VPN API is ready to use.${NC}"
}

handle_installation_error() {
    local exit_code=$1
    local line_number=$2
    
    echo -e "\n${RED}${BOLD}❌ Installation failed at line $line_number (exit code: $exit_code)${NC}"
    log "ERROR" "Installation failed at line $line_number (exit code: $exit_code)"
    
    if [ -f "$LOG_FILE" ]; then
        echo -e "${YELLOW}📜 Recent logs:${NC}"
        tail -5 "$LOG_FILE" | while read -r line; do
            echo -e "   ${DIM}$line${NC}"
        done
    fi
    
    echo -e "${YELLOW}🧹 Cleaning up failed installation...${NC}"
    
    systemctl stop "$SERVICE_NAME" 2>/dev/null || true
    systemctl disable "$SERVICE_NAME" 2>/dev/null || true
    
    rm -f "/etc/systemd/system/$SERVICE_NAME.service"
    systemctl daemon-reload 2>/dev/null || true
    
    echo -e "${CYAN}Keep files for debugging? [y/N]: ${NC}"
    read -r -t 10 keep_files || keep_files="n"
    
    if [[ ! "$keep_files" =~ ^[Yy] ]]; then
        rm -rf "$INSTALL_DIR" 2>/dev/null || true
        echo -e "${GREEN}✅ Installation files cleaned${NC}"
    else
        echo -e "${YELLOW}📁 Files retained at: $INSTALL_DIR${NC}"
        echo -e "${YELLOW}📜 Logs saved at: $LOG_FILE${NC}"
    fi
    
    exit $exit_code
}

handle_installation_interrupt() {
    echo -e "\n${YELLOW}${BOLD}⚠️ Installation interrupted${NC}"
    log "WARN" "Installation interrupted by user"
    
    systemctl stop "$SERVICE_NAME" 2>/dev/null || true
    
    echo -e "${BLUE}Thank you for using VPN API installer!${NC}"
    exit 130
}

# =============================================================================
# SCRIPT EXECUTION
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}${BOLD}❌ Script must be run as root${NC}"
        echo -e "${YELLOW}   Use: sudo $0${NC}"
        exit 1
    fi
    
    main "$@"
else
    echo "Script must be executed, not sourced!"
    exit 1
fi
