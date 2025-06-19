# VPN API Scripts

This repository contains a collection of bash scripts and a small Node.js
service to manage VPN accounts (VMess, VLess, Trojan and SSH). The API exposes
a simple HTTP interface to execute the scripts.

## Features

- Create and renew VPN accounts via HTTP requests
- Delete accounts and check active users
- Backup and restore server configuration
- JSON responses suitable for automation

## Requirements

- Debian/Ubuntu based system
- Root privileges for installation
- Internet connection to install dependencies

## Installation

Run the provided `install.sh` script as root. It will install Node.js,
copy the scripts to `/opt/vpn-api`, install Node dependencies and set up a
systemd service named `vpn-api` with colorful progress output.

For a one-line install, you can execute:

```bash
curl -fsSL https://raw.githubusercontent.com/yourusername/vpn-api/main/install.sh | sudo bash
```

After installation the service will start automatically. You can check its
status with:

```bash
systemctl status vpn-api
```

The API listens on port `5888` by default.

## Usage

Example of creating a VMess account:

```bash
curl "http://localhost:5888/createvmess?user=test&exp=30&quota=10&iplimit=1&auth=fadznewbie_do"
```

Each endpoint requires the `auth` parameter with the correct key. See
`vpn-api.js` for a list of available endpoints and parameters.

## Updating

If you modify the scripts or the Node.js application, redeploy them to
`/opt/vpn-api` and restart the service:

```bash
sudo systemctl restart vpn-api
```

## Disclaimer

Use these scripts at your own risk. They are provided as-is without any
warranty. Review the code before running it in a production environment.
