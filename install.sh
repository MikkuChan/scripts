#!/bin/bash
# Skrip Setup VPN API
# Skrip ini memasang Node.js, menyalin skrip VPN, memasang dependensi,
# dan mengonfigurasi service systemd.

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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
    echo -e "\r${GREEN}✔ $*${NC}"
  else
    echo -e "\r${RED}✘ $*${NC}"
    exit 1
  fi
}

echo -e "${GREEN}==============================${NC}"
echo -e "${GREEN}      INSTALASI VPN API       ${NC}"
echo -e "${GREEN}==============================${NC}"

if [[ $EUID -ne 0 ]]; then
  echo -e "${RED}Jalankan skrip ini sebagai root${NC}" >&2
  exit 1
fi

# Pasang Node.js dan npm jika belum ada
if ! command -v node >/dev/null 2>&1; then
  run apt-get update -y
  run apt-get install -y nodejs npm
fi

INSTALL_DIR=/opt/vpn-api
SCRIPT_DIR="$INSTALL_DIR/scripts"
run mkdir -p "$SCRIPT_DIR"

# Salin berkas proyek
run cp vpn-api.js package.json "$INSTALL_DIR"/
run cp *.sh "$SCRIPT_DIR"/
run chmod +x "$SCRIPT_DIR"/*.sh

# Pasang dependensi Node
cd "$INSTALL_DIR"
run npm install --production

# Buat service systemd
echo -e "${YELLOW}Membuat service systemd${NC}"
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
