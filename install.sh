#!/bin/bash
# =============================================================================
# VPN API Installation Script - FadzDigital
# Version: 2.0 (MikkuChan)
# =============================================================================

set -e

# ================================
# 🎨 Warna & Style
# ================================
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

declare -a GRADIENT=(
    '\033[1;34m'
    '\033[1;35m'
    '\033[1;36m'
    '\033[1;32m'
    '\033[1;33m'
    '\033[1;31m'
)

# ================================
# 🔧 Konfigurasi
# ================================
declare -r REPO="MikkuChan/scripts"
declare -r BRANCH="main"
declare -r RAW_URL="https://raw.githubusercontent.com/$REPO/$BRANCH"
declare -r INSTALL_DIR="/opt/vpn-api"
declare -r SCRIPT_DIR="$INSTALL_DIR/scripts"
declare -r SERVICE_NAME="vpn-api"
declare -r LOG_FILE="/var/log/vpn-api-install.log"

declare USER_AUTHKEY=""

# ================================
# 🏳️ Banner
# ================================
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

# ================================
# 📚 Log & Spinner
# ================================
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

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
    if [ $? -eq 0 ]; then
        printf "\r${GREEN}${BOLD}✅${NC} ${WHITE}${message}${NC} ${GREEN}${BOLD}[BERHASIL]${NC}\n"
        log "SUKSES: $message"
    else
        printf "\r${RED}${BOLD}❌${NC} ${WHITE}${message}${NC} ${RED}${BOLD}[GAGAL]${NC}\n"
        log "GAGAL: $message"
        exit 1
    fi
}

run() {
    local cmd="$1"
    local retries=3
    local attempt=1
    log "Menjalankan: ${cmd}"
    while [ $attempt -le $retries ]; do
        {
            eval "$cmd"
        } &
        spinner $! "$cmd (Percobaan $attempt/$retries)"
        if [ $? -eq 0 ]; then
            return 0
        fi
        attempt=$((attempt + 1))
        echo -e "${YELLOW}${BOLD}⚡ Mencoba lagi dalam 3 detik...${NC}"
        sleep 3
    done
    echo -e "${RED}${BOLD}❌ Gagal menjalankan: ${cmd}${NC}"
    exit 1
}

progress_bar() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local completed=$((current * width / total))
    local remaining=$((width - completed))
    printf "\r${PURPLE}${BOLD}Progress: ${NC}${CYAN}["
    printf "%${completed}s" | tr ' ' '█'
    printf "%${remaining}s" | tr ' ' '░'
    printf "] ${WHITE}${BOLD}%3d%%${NC} ${BLUE}(${current}/${total})${NC} " "$percentage"
}

# ================================
# 🔑 Input AUTHKEY
# ================================
get_authkey_input() {
    echo -e "${CYAN}${BOLD}🔐 Masukkan Authentication Key (AUTHKEY) untuk API:${NC}"
    while true; do
        read -rp "   AUTHKEY: " USER_AUTHKEY
        [[ -n "$USER_AUTHKEY" ]] && break
    done
    log "AUTHKEY received"
}

# ================================
# ✅ Prasyarat & Cek
# ================================
check_prerequisites() {
    [[ $EUID -ne 0 ]] && echo -e "${RED}❌ Harus root${NC}" && exit 1
    echo -e "${CYAN}Memeriksa koneksi internet...${NC}"
    run "ping -c 1 github.com"
}

check_existing_installation() {
    if [ -d "${INSTALL_DIR}" ] || pm2 show "${SERVICE_NAME}" &>/dev/null; then
        echo -e "${YELLOW}⚠️  Instalasi lama ditemukan.${NC}"
        run "pm2 stop $SERVICE_NAME || true"
        run "pm2 delete $SERVICE_NAME || true"
        run "rm -rf ${INSTALL_DIR}"
    fi
}

# ================================
# 📦 Install Dependencies (NodeSource)
# ================================
install_dependencies() {
    echo -e "${YELLOW}${BOLD}📦 Menginstall paket yang diperlukan...${NC}"
    run "apt-get update -y"
    packages=("curl" "wget" "git")
    for p in "${packages[@]}"; do run "apt-get install -y $p"; done
    echo -e "${CYAN}🔗 Setup Node.js LTS dari NodeSource${NC}"
    run "curl -fsSL https://deb.nodesource.com/setup_20.x | bash -"
    run "apt-get install -y nodejs"
    NODE_VERSION=$(node -v)
    echo -e "${GREEN}Node.js versi: $NODE_VERSION${NC}"
    run "npm install -g pm2"
}

# ================================
# 📁 Struktur, Download, Install
# ================================
create_directories() {
    run "mkdir -p $SCRIPT_DIR"
}

download_files() {
    cd "$SCRIPT_DIR"
    run "curl -fsSL ${RAW_URL}/vpn-api.js -o vpn-api.js"
    run "curl -fsSL ${RAW_URL}/package.json -o package.json"
}

install_node_modules() {
    cd "$SCRIPT_DIR"
    run "npm install --production"
}

create_env_file() {
    echo "AUTHKEY=$USER_AUTHKEY" > "$SCRIPT_DIR/.env"
    chmod 600 "$SCRIPT_DIR/.env"
}

start_service() {
    cd "$SCRIPT_DIR"
    run "pm2 start vpn-api.js --name $SERVICE_NAME"
    run "pm2 save"
    run "pm2 startup systemd -u root --hp /root"
}

show_summary() {
    echo -e "${GREEN}🎉 INSTALASI SELESAI!${NC}"
    echo "Directory: $INSTALL_DIR"
    echo "Service: $SERVICE_NAME"
    echo "Node.js: $(node -v)"
    echo "PM2 status:"
    pm2 status
}

# ================================
# 🚀 Main
# ================================
main() {
    touch "$LOG_FILE"
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
}

trap 'echo -e "\n${RED}❌ Dihentikan.${NC}"' INT TERM
main "$@"
