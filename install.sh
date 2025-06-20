#!/bin/bash
# =============================================================================
# VPN API Installation Script - FadzDigital
# Version: 2.0
# Enhanced with professional animations and styling
# =============================================================================

set -e

# Definisi warna dengan palet modern
declare -r RED='\033[1;31m'
declare -r GREEN='\033[1;32m'
declare -r YELLOW='\033[1;33m'
declare -r BLUE='\033[1;34m'
declare -r PURPLE='\033[1;35m'
declare -r CYAN='\033[1;36m'
declare -r WHITE='\033[1;37m'
declare -r BOLD='\033[1m'
declare -r DIM='\033[2m'
declare -r NC='\033[0m'

# Gradient color array untuk animasi
declare -a GRADIENT=(
    '\033[1;34m'  # Blue
    '\033[1;35m'  # Purple
    '\033[1;36m'  # Cyan
)

# Konfigurasi
declare -r REPO="MikkuChan/scripts"
declare -r BRANCH="main"
declare -r RAW_URL="https://raw.githubusercontent.com/$REPO/$BRANCH"
declare -r INSTALL_DIR="/opt/vpn-api"
declare -r SCRIPT_DIR="$INSTALL_DIR/scripts"
declare -r SERVICE_NAME="vpn-api"
declare -r LOG_FILE="/var/log/vpn-api-install.log"

# Modern ASCII banner menggunakan figlet style
print_banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    cat << 'EOF'
    ╔══════════════════════════════════════════════════════════════════════╗
    ╔═╗─╔╗───────╔╗─╔════╗─█──█─████───█───╦════╗
    ║╬╠═╬╬═╦═╦═╬╦╗─╬═╦╦╦═╦═╦═╗─╚════╦═╦═╦╦═╝
    ║╔╬╩╬╬╬╦╧╬╬╩╦╬╬═╬╬╬╩╬═║─███──╩╬╬═╬╬═╦
    ╚═╩╩╩╩✩╩╩╩╩✩╩╩╩╩✩ ✩✩╩╩✩ ✩✩╩ ╩╩╩✩✩
    ╚ DIGITAL
    ╚══════════════════════════════════════════════════════════════════════╩
EOF
    echo -e "${PURPLE}${BOLD}═══════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}${BOLD}                    VPN API INSTALLER v2.0${NC}"
    echo -e "${GREEN}${BOLD}                      Created by FadzDigital${NC}"
    echo -e "${PURPLE}${BOLD}═══════════════════════════════════════════════════════════════════════${NC}"
    # Animasi pembukaan
    local anim_chars=('█' '▒' '▓' '░')
    for i in {1..3}; do
        for char in "${anim_chars[@]}"; do
            printf "\r${YELLOW}${BOLD}Initializing${char}${DIM}..."
            sleep 0.1
        done
    done
    echo -e "\r${GREEN}${BOLD}✓ Ready to Install!${NC}\n"
}

# Fungsi logging dengan format lebih rapi
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Animasi spinner dengan efek modern
spinner() {
    local pid=$1
    local message="$2"
    local delay=0.05
    local spin='⣾⣽⣻⢿⡿⣟⣯⣷'
    local i=0
    
    while kill -0 $pid 2>/dev/null; do
        printf "\r${GRADIENT[$((i % ${#GRADIENT[@]}))]}${spin:$i:1}${NC} ${CYAN}${message}${NC}"
        sleep $delay
        i=$(( (i + 1) % 8 ))
    done
    
    wait $pid
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        printf "\r${GREEN}${BOLD}✓${NC} ${CYAN}${message}${NC} ${GREEN}[SUCCESS]${NC}\n"
        log "SUCCESS: $message"
    else
        printf "\r${RED}${BOLD}✗${NC} ${CYAN}${message}${NC} ${RED}[FAILED]${NC}\n"
        log "FAILED: $message"
        return $exit_code
    fi
}

# Fungsi eksekusi dengan retry
run() {
    local cmd="$1"
    local retries=3
    local attempt=1
    log "Executing: ${cmd}"
    
    while [ $attempt -le $retries ]; do
        {
            eval "$cmd"
        } &
        local pid=$!
        spinner $pid "$cmd (Attempt $attempt/$retries)"
        
        if [ $? -eq 0 ]; then
            return 0
        fi
        
        attempt=$((attempt + 1))
        if [ $attempt -le $retries ]; then
            echo -e "${YELLOW}${BOLD}⚡ Retrying in 3 seconds...${NC}"
            sleep 3
        fi
        echo -e "${RED}${BOLD}❌ Failed to execute: ${cmd${NC}}"
        exit 1
    done
}

# Progress bar dengan animasi lebih halus
progress_bar() {
    local current=$1
    local total=$2
    local width=40
    local percentage=$((current * 100 / total))
    local completed=$((current * width / total))
    local remaining=$((width - completed))
    
    printf "\r${CYAN}[${NC}"
    printf "%${completed}s" | tr ' ' '█'
    printf "%${remaining}s" | tr ' ' '─'
    printf "${CYAN}] ${WHITE}%3d%%${NC} ${BLUE}(${current}/${total})${NC}"
    sleep 0.05
}

# Cek prasyarat dengan animasi
check_prerequisites() {
    echo -e "${YELLOW}${BOLD}🔎 Checking system prerequisites...${NC}\n"
    
    # Root check
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}${BOLD}❌ This script must be run as root${NC}"
        echo -e "${BLUE}   Run: ${YELLOW}sudo $0${NC}"
        exit 1
    fi
    
    # Internet check with animation
    echo -e "${CYAN}Checking internet connection...${NC}"
    for i in {1..10}; do
        printf "\r${YELLOW}${BOLD}Pinging${NC}${...${i}%}"
        sleep 0.05
    done
    if ! ping -c 1 github.com &> /dev/null; then
        echo -e "\r${RED}${BOLD}❌ No internet connection${NC}\n"
        exit 1
    fi
    echo -e "\r${GREEN}${BOLD}✓ Internet connection established${NC}\n"
    
    echo -e "${GREEN}${BOLD}✓ System prerequisites verified ✅${NC}"
    sleep 1
}

# Cek instalasi yang sudah ada
check_existing_installation() {
    if [ -d "${INSTALL_DIR}" ] || systemctl is-active --quiet "${SERVICE_NAME}" 2>/dev/null; then
        echo -e "${YELLOW}${BOLD}⚠️  Existing installation found${NC}"
        echo -e "${BLUE}   • Installation directory: ${WHITE}${INSTALL_DIR}${NC}"
        echo -e "${BLUE}   • Service status: ${WHITE}$(systemctl is-active $SERVICE_NAME 2>/dev/null || echo 'inactive')${NC}"
        echo
        
        n"
        
        echo -e "${CYAN}${BOLD}Would you like to remove the existing installation and reinstall? [Y/n]: ${NC}"
        read -r response
        case "${response}" in
            [Yy]|[Yy][Ee][Ss]|"" ||
                remove_existing_installation
                ;;
            [Nn]|[Nn][Oo]
                echo -e "${RED}${BOLD}❌ Installation aborted by user${NC}"
                exit 0
                ;;
            *
                echo -e "${YELLOW}Please enter yes or no${NC}"
                check_existing_installation
                ;;
        esac
    fi
}

# Hapus instalasi lama
remove_existing_installation() {
    echo -e "${YELLOW}${BOLD}🗑️  Removing existing installation...${NC}\n"
    
    # Stop service
    if systemctl is-active --quiet "${SERVICE_NAME}" 2>/dev/null; then
        run "systemctl stop $SERVICE_NAME}"
        run "systemctl disable $SERVICE_NAME}"
    fi
    
    # Remove service file
    if [ -f "/etc/systemd/system/${SERVICE_NAME}.service" ]; then
        run "rm -f /etc/systemd/system/$SERVICE_NAME.service"
        run "systemctl daemon-reload"
    fi
    
    # Remove install directory
    if [ -d "${INSTALL_DIR}" ]; then
        run "rm -rf ${INSTALL_DIR}"
    fi
    
    echo -e "${GREEN}${BOLD}✓ Previous installation removed successfully ✅${NC}\n"
    sleep 1
}

# Install dependencies
install_dependencies() {
    echo -e "${YELLOW}${BOLD}📦 Installing required packages...${NC}\n"
    
    # Update package list
    run "apt-get update -y"
    
    # Install packages
    local packages=("curl" "wget" "nodejs" "-nodejs" npm "git")
    local total=${#packages[@]}
    local current=0
    
    for package in "${packages[@]}"; do
        current=$((current + 1))
        if ! command -v "${package}" >/dev/null 2>&1 && ! dpkg -l | grep -q "^ii  $package "; then
            progress_bar $current $total
            run "apt-get install -y $package"
        else
            progress_bar $current $total
            log "SKIPPED: $package already installed"
            sleep 0.1
        fi
    done
    
    echo -e "\n${GREEN}${BOLD}✓ All packages installed successfully ✅${NC}\n"
    sleep 1
}

# Buat struktur direktori
create_directories() {
    echo -e "${YELLOW}${BOLD}📁 Creating directory structure...${NC}\n"
    
    run "mkdir -p $SCRIPT_DIR"
    run "mkdir -p /var/log/vpn-api"
    run "chown -R root:root $INSTALL_DIR"
    
    echo -e "${GREEN}${BOLD}✓ Directory structure created successfully ✅${NC}\n"
    sleep 1
}

# Download file dari GitHub
download_files() {
    echo -e "${YELLOW}${BOLD}⬇️  Downloading files from GitHub...${NC}\n"
    
    cd "${INSTALL_DIR}"
    
    # Main files
    local main_files=("vpn-api.js" "package.json")
    local total_files=0
    local current_file=0
    
    # Count total files
    total_files=${#main_files[@]}
    local sh_files
    sh_files=$(curl -s "https://api.github.com/repos/$REPO/contents?ref=$BRANCH" | grep 'name.*\.sh' | cut -d '"' -f4 | grep -v 'install.sh' | wc -l)
    total_files=$((total_files + sh_files))
    
    # Download main files
    for file in "${main_files[@]}"; do
        current_file=$((current_file + 1))
        progress_bar $current_file $total_files
        if curl -fsSL "${RAW_URL}/${file}" -o "${INSTALL_DIR}/${file}"; then
            log "DOWNLOADED: $file"
            sleep 0.1
        else
            echo -e "\n${RED}${BOLD}❌ Failed to download ${file}${NC}"
            exit 1
        fi
    done
    
    # Download shell scripts
    local sh_file_list
    sh_file_list=$(curl -s "https://api.github.com/repos/$REPO/contents?ref=$BRANCH" | grep 'name.*\.sh' | cut -d '"' -f4 | grep -v 'install.sh')
    
    for file in $sh_file_list; do
        current_file=$((current_file + 1))
        progress_bar $current_file $total_files
        if curl -fsSL "${RAW_URL}/${file}" -o "${SCRIPT_DIR}/${file}"; then
            chmod +x "${SCRIPT_DIR}/${file}"
            log "DOWNLOADED: $file"
            sleep 0.1
        else
            echo -e "\n${RED}${BOLD}❌ Failed to download ${file}${NC}"
            exit 1
        fi
    done
    
    echo -e "\n${GREEN}${BOLD}✓ All files downloaded successfully ✅${NC}\n"
    sleep 1
}

# Install Node.js dependencies
install_node_modules() {
    echo -e "${YELLOW}${BOLD}📦 Installing Node.js dependencies...${NC}\n"
    
    cd "${INSTALL_DIR}"
    
    if [ -f "package.json" ]; then
        run "npm install --production --silent"
        echo -e "${GREEN}${BOLD}✓ Node.js dependencies installed successfully ✅${NC}\n"
    else
        echo -e "${YELLOW}⚠️  package.json not found, skipping npm install${NC}\n"
    fi
    sleep 1
}

# Buat systemd service
create_service() {
    echo -e "${YELLOW}${BOLD}⚙️  Creating systemd service...${NC}\n"
    
    cat > "/etc/systemd/system/${SERVICE_NAME}.service" << EOF
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

# Security settings
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$INSTALL_DIR /var/log/vpn-api /tmp

[Install]
WantedBy=multi-user.target
EOF

    run "systemctl daemon-reload"
    run "systemctl enable $SERVICE_NAME"
    
    echo -e "${GREEN}${BOLD}✓ Systemd service created and enabled successfully ✅${NC}\n"
    sleep 1
}

# Jalankan service
start_service() {
    echo -e "${YELLOW}${BOLD}🚀 Starting VPN API service...${NC}\n"
    
    run "systemctl start $SERVICE_NAME"
    
    # Wait and check status
    sleep 2
    
    if systemctl is-active --quiet "${SERVICE_NAME}"; then
        echo -e "${GREEN}${BOLD}✓ VPN API service started successfully ✅${NC}\n"
    else
        echo -e "${RED}${BOLD}❌ Failed to start VPN API service${NC}"
        echo -e "${YELLOW}   Check logs with: ${CYAN}journalctl -u ${SERVICE_NAME} -f${NC}\n"
        exit 1
    fi
    sleep 1
}

# Tampilkan ringkasan
show_summary() {
    echo -e "${PURPLE}${BOLD}═══════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}${BOLD}                    🎉 INSTALLATION COMPLETED SUCCESSFULLY! 🎉${NC}"
    echo -e "${PURPLE}${BOLD}═══════════════════════════════════════════════════════════════════════${NC}\n"
    
    echo -e "${CYAN}${BOLD}📋 Installation Summary:${NC}"
    echo -e "${WHITE}   • Installation Directory: ${GREEN}${INSTALL_DIR}${NC}"
    echo -e "${WHITE}   • Service Name: ${GREEN}${SERVICE_NAME}${NC}"
    echo -e "${WHITE}   • Service Status: ${GREEN}$(systemctl is-active ${SERVICE_NAME})${NC}"
    echo -e "${WHITE}   • Log File: ${GREEN}${LOG_FILE}${NC}\n"
    
    echo -e "${CYAN}${BOLD}🔧 Useful Commands:${NC}"
    echo -e "${WHITE}   • Check service status: ${YELLOW}systemctl status ${SERVICE_NAME}${NC}"
    echo -e "${WHITE}   • View service logs: ${YELLOW}journalctl -u ${SERVICE_NAME} -f${NC}"
    echo -e "${WHITE}   • Restart service: ${YELLOW}systemctl restart ${SERVICE_NAME}${NC}"
    echo -e "${WHITE}   • Stop service: ${YELLOW}systemctl stop ${SERVICE_NAME}${NC}\n"
    
    echo -e "${GREEN}${BOLD}✨ Powered by FadzDigital ✨${NC}"
    echo -e "${PURPLE}${BOLD}═══════════════════════════════════════════════════════════════════════${NC}\n"
    
    # Animasi penutup
    local anim="🚀 Installation Complete!"
    for ((i=0; i<${#anim}; i++)); do
        printf "${GREEN}${BOLD}%s${NC}" "${anim:$i:1}"
        sleep 0.05
    done
    echo -e "\n"
}

# Fungsi utama
main() {
    # Initialize log
    touch "${LOG_FILE}"
    log "VPN API Installation Started"
    
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
    
    log "VPN API Installation Completed Successfully"
}

# Error handling
trap 'echo -e "\n${RED}${BOLD}❌ Installation interrupted!${NC}\n"; log "Installation interrupted"; exit 1' INT TERM

# Jalankan instalasi
main "$@"
