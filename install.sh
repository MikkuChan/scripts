#!/bin/bash
# VPN API Setup Script - Otomatis download file dari GitHub

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

REPO="MikkuChan/scripts"
BRANCH="main"
RAW_URL="https://raw.githubusercontent.com/$REPO/$BRANCH"

INSTALL_DIR="/opt/vpn-api"
SCRIPT_DIR="$INSTALL_DIR/scripts"

spinner() {
  local pid=$1
  local delay=0.1
  local spin='|/-\\'
  while kill -0 $pid 2>/dev/null; do
    for i in $(seq 0 3); do
      printf "\r${BLUE}%c${NC}" "${spin:$i:1}"
      sleep $delay
    done
  done
  wait $pid
}

run() {
  echo -e "${YELLOW}$*${NC}"
  "$@" >/dev/null 2>&1 &
  spinner $!
  if [ $? -eq 0 ]; then
    echo -e "\r${GREEN}\u2714 $*${NC}"
  else
    echo -e "\r${RED}\u2718 $*${NC}"
    exit 1
  fi
}

echo -e "${GREEN}==============================${NC}"
echo -e "${GREEN}      VPN API INSTALLER       ${NC}"
echo -e "${GREEN}==============================${NC}"

if [[ $EUID -ne 0 ]]; then
  echo -e "${RED}Script ini harus dijalankan sebagai root${NC}" >&2
  exit 1
fi

# Cek dan install Node.js dan npm jika belum ada
if ! command -v node >/dev/null 2>&1; then
  run apt-get update -y
  run apt-get install -y nodejs npm
fi

run mkdir -p "$SCRIPT_DIR"

cd "$INSTALL_DIR"

# Daftar file utama di root repo
MAIN_FILES=(vpn-api.js package.json)

for file in "${MAIN_FILES[@]}"; do
  echo -e "${YELLOW}Mengunduh $file ...${NC}"
  curl -fsSL "$RAW_URL/$file" -o "$INSTALL_DIR/$file"
done

# Download semua file .sh (kecuali install.sh) dari repo github
# Dapatkan list file .sh dari GitHub API
SH_FILES=$(curl -s "https://api.github.com/repos/$REPO/contents?ref=$BRANCH" | grep 'name.*\.sh' | cut -d '"' -f4 | grep -v 'install.sh')
for file in $SH_FILES; do
  echo -e "${YELLOW}Mengunduh $file ...${NC}"
  curl -fsSL "$RAW_URL/$file" -o "$SCRIPT_DIR/$file"
  chmod +x "$SCRIPT_DIR/$file"
done

# Instalasi node_modules
cd "$INSTALL_DIR"
run npm install --production

# Buat systemd service
echo -e "${YELLOW}Membuat systemd service${NC}"
cat > /etc/systemd/system/vpn-api.service <<'SERVICE'
[Unit]
Description=VPN API Service
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/vpn-api
ExecStart=/usr/bin/node /opt/vpn-api/vpn-api.js
Restart=always
User=root
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
SERVICE

run systemctl daemon-reload
run systemctl enable --now vpn-api.service

echo -e "${GREEN}VPN API berhasil diinstal dan dijalankan.${NC}"
