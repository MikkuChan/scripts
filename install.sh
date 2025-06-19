#!/bin/bash
# =============================================================================
# VPN API Installation Script - FadzDigital Edition
# Auto-download files from GitHub with enhanced features
# Version: 2.0
# =============================================================================

set -e

# Color definitions
declare -r RED='\033[0;31m'
declare -r GREEN='\033[0;32m'
declare -r YELLOW='\033[1;33m'
declare -r BLUE='\033[0;34m'
declare -r PURPLE='\033[0;35m'
declare -r CYAN='\033[0;36m'
declare -r WHITE='\033[1;37m'
declare -r BOLD='\033[1m'
declare -r UNDERLINE='\033[4m'
declare -r NC='\033[0m'

# Configuration
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
    echo -e "${PURPLE}${BOLD}══════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}${BOLD}                          VPN API INSTALLER v2.0                             ${NC}"
    echo -e "${GREEN}${BOLD}                        Enhanced by FadzDigital                              ${NC}"
    echo -e "${PURPLE}${BOLD}══════════════════════════════════════════════════════════════════════════════${NC}"
    echo
}

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Enhanced spinner with progress
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
        printf "\r${GREEN}${BOLD}✓${NC} ${WHITE}%s${NC} ${GREEN}[SUCCESS]${NC}\n" "$message"
        log "SUCCESS: $message"
    else
        printf "\r${RED}${BOLD}✗${NC} ${WHITE}%s${NC} ${RED}[FAILED]${NC}\n" "$message"
        log "FAILED: $message"
        return $exit_code
    fi
}

# Enhanced run function with better error handling
run() {
    local cmd="$*"
    log "EXECUTING: $cmd"
    
    {
        eval "$cmd"
    } &
    
    local pid=$!
    spinner $pid "$cmd"
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}${BOLD}❌ Error executing: $cmd${NC}"
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

# Check prerequisites
check_prerequisites() {
    echo -e "${YELLOW}${BOLD}🔍 Checking system prerequisites...${NC}"
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}${BOLD}❌ This script must be run as root${NC}"
        echo -e "${YELLOW}   Please run: sudo $0${NC}"
        exit 1
    fi
    
    # Check internet connection
    if ! ping -c 1 github.com &> /dev/null; then
        echo -e "${RED}${BOLD}❌ No internet connection detected${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}${BOLD}✓ Prerequisites check passed${NC}"
}

# Check existing installation
check_existing_installation() {
    if [ -d "$INSTALL_DIR" ] || systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        echo -e "${YELLOW}${BOLD}⚠️  Existing VPN API installation detected${NC}"
        echo -e "${BLUE}   Installation directory: ${WHITE}$INSTALL_DIR${NC}"
        echo -e "${BLUE}   Service status: ${WHITE}$(systemctl is-active $SERVICE_NAME 2>/dev/null || echo 'inactive')${NC}"
        echo
        
        while true; do
            echo -e "${CYAN}${BOLD}Do you want to remove the existing installation and install fresh? [Y/n]: ${NC}"
            read -r response
            case $response in
                [Yy]|[Yy][Ee][Ss]|"")
                    remove_existing_installation
                    break
                    ;;
                [Nn]|[Nn][Oo])
                    echo -e "${RED}${BOLD}Installation cancelled by user${NC}"
                    exit 0
                    ;;
                *)
                    echo -e "${YELLOW}Please answer yes or no${NC}"
                    ;;
            esac
        done
    fi
}

# Remove existing installation
remove_existing_installation() {
    echo -e "${YELLOW}${BOLD}🗑️  Removing existing installation...${NC}"
    
    # Stop and disable service
    if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        run "systemctl stop $SERVICE_NAME"
        run "systemctl disable $SERVICE_NAME"
    fi
    
    # Remove service file
    if [ -f "/etc/systemd/system/$SERVICE_NAME.service" ]; then
        run "rm -f /etc/systemd/system/$SERVICE_NAME.service"
        run "systemctl daemon-reload"
    fi
    
    # Remove installation directory
    if [ -d "$INSTALL_DIR" ]; then
        run "rm -rf $INSTALL_DIR"
    fi
    
    echo -e "${GREEN}${BOLD}✓ Existing installation removed successfully${NC}"
}

# Install dependencies
install_dependencies() {
    echo -e "${YELLOW}${BOLD}📦 Installing dependencies...${NC}"
    
    # Update package list
    run "apt-get update -y"
    
    # Install required packages
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
            log "SKIP: $package already installed"
        fi
    done
    
    echo
    echo -e "${GREEN}${BOLD}✓ Dependencies installed successfully${NC}"
}

# Create directory structure
create_directories() {
    echo -e "${YELLOW}${BOLD}📁 Creating directory structure...${NC}"
    
    run "mkdir -p $SCRIPT_DIR"
    run "mkdir -p /var/log/vpn-api"
    run "chown -R root:root $INSTALL_DIR"
    
    echo -e "${GREEN}${BOLD}✓ Directory structure created${NC}"
}

# Download files
download_files() {
    echo -e "${YELLOW}${BOLD}⬇️  Downloading files from GitHub...${NC}"
    
    cd "$INSTALL_DIR"
    
    # Download main files
    local main_files=("vpn-api.js" "package.json")
    local total_files=0
    local current_file=0
    
    # Count total files first
    total_files=${#main_files[@]}
    
    # Get shell scripts count
    local sh_files
    sh_files=$(curl -s "https://api.github.com/repos/$REPO/contents?ref=$BRANCH" | grep 'name.*\.sh' | cut -d '"' -f4 | grep -v 'install.sh' | wc -l)
    total_files=$((total_files + sh_files))
    
    # Download main files
    for file in "${main_files[@]}"; do
        current_file=$((current_file + 1))
        progress_bar $current_file $total_files
        
        if curl -fsSL "$RAW_URL/$file" -o "$INSTALL_DIR/$file"; then
            log "DOWNLOADED: $file"
        else
            echo -e "\n${RED}${BOLD}❌ Failed to download $file${NC}"
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
            echo -e "\n${RED}${BOLD}❌ Failed to download $file${NC}"
            exit 1
        fi
    done
    
    echo
    echo -e "${GREEN}${BOLD}✓ All files downloaded successfully${NC}"
}

# Install Node.js dependencies
install_node_modules() {
    echo -e "${YELLOW}${BOLD}📦 Installing Node.js dependencies...${NC}"
    
    cd "$INSTALL_DIR"
    
    if [ -f "package.json" ]; then
        run "npm install --production --silent"
        echo -e "${GREEN}${BOLD}✓ Node.js dependencies installed${NC}"
    else
        echo -e "${YELLOW}⚠️  package.json not found, skipping npm install${NC}"
    fi
}

# Create systemd service
create_service() {
    echo -e "${YELLOW}${BOLD}⚙️  Creating systemd service...${NC}"
    
    cat > "/etc/systemd/system/$SERVICE_NAME.service" << EOF
[Unit]
Description=VPN API Service - FadzDigital Edition
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
    
    echo -e "${GREEN}${BOLD}✓ Systemd service created and enabled${NC}"
}

# Start service
start_service() {
    echo -e "${YELLOW}${BOLD}🚀 Starting VPN API service...${NC}"
    
    run "systemctl start $SERVICE_NAME"
    
    # Wait a moment and check status
    sleep 2
    
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        echo -e "${GREEN}${BOLD}✓ VPN API service started successfully${NC}"
    else
        echo -e "${RED}${BOLD}❌ Failed to start VPN API service${NC}"
        echo -e "${YELLOW}   Check logs with: journalctl -u $SERVICE_NAME -f${NC}"
        exit 1
    fi
}

# Show installation summary
show_summary() {
    echo
    echo -e "${PURPLE}${BOLD}══════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}${BOLD}                    🎉 INSTALLATION COMPLETED SUCCESSFULLY! 🎉${NC}"
    echo -e "${PURPLE}${BOLD}══════════════════════════════════════════════════════════════════════════════${NC}"
    echo
    echo -e "${CYAN}${BOLD}📋 Installation Summary:${NC}"
    echo -e "${WHITE}   • Installation Directory: ${GREEN}$INSTALL_DIR${NC}"
    echo -e "${WHITE}   • Service Name: ${GREEN}$SERVICE_NAME${NC}"
    echo -e "${WHITE}   • Service Status: ${GREEN}$(systemctl is-active $SERVICE_NAME)${NC}"
    echo -e "${WHITE}   • Log File: ${GREEN}$LOG_FILE${NC}"
    echo
    echo -e "${CYAN}${BOLD}🔧 Useful Commands:${NC}"
    echo -e "${WHITE}   • Check service status: ${YELLOW}systemctl status $SERVICE_NAME${NC}"
    echo -e "${WHITE}   • View service logs: ${YELLOW}journalctl -u $SERVICE_NAME -f${NC}"
    echo -e "${WHITE}   • Restart service: ${YELLOW}systemctl restart $SERVICE_NAME${NC}"
    echo -e "${WHITE}   • Stop service: ${YELLOW}systemctl stop $SERVICE_NAME${NC}"
    echo
    echo -e "${GREEN}${BOLD}✨ Powered by FadzDigital - Premium VPN Solutions ✨${NC}"
    echo -e "${PURPLE}${BOLD}══════════════════════════════════════════════════════════════════════════════${NC}"
}

# Main installation function
main() {
    # Initialize log file
    touch "$LOG_FILE"
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
trap 'echo -e "\n${RED}${BOLD}❌ Installation interrupted!${NC}"; log "Installation interrupted"; exit 1' INT TERM

# Run main function
main "$@"
