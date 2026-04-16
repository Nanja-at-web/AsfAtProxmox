#!/usr/bin/env bash
# Copyright (c) 2021-2026 community-scripts ORG
# Author: OpenAI
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/JustArchiNET/ArchiSteamFarm | https://github.com/JustArchiNET/ASF-ui | https://github.com/JustArchiNET/ASF-WebConfigGenerator

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

APP_DIR="/opt/archisteamfarm"
CONFIG_DIR="${APP_DIR}/config"
SERVICE_NAME="archisteamfarm"
SERVICE_USER="asf"
SERVICE_GROUP="asf"
API_URL="https://api.github.com/repos/JustArchiNET/ArchiSteamFarm/releases/latest"

function detect_asf_asset() {
  local arch
  arch="$(uname -m)"

  case "$arch" in
    x86_64 | amd64)
      echo "ASF-linux-x64.zip"
      ;;
    aarch64 | arm64)
      echo "ASF-linux-arm64.zip"
      ;;
    armv7l | armv6l | armhf)
      echo "ASF-linux-arm.zip"
      ;;
    *)
      msg_error "Unsupported architecture: $arch"
      exit 1
      ;;
  esac
}

function ensure_service_account() {
  if ! getent group "$SERVICE_GROUP" >/dev/null 2>&1; then
    groupadd --system "$SERVICE_GROUP"
  fi

  if ! id -u "$SERVICE_USER" >/dev/null 2>&1; then
    useradd --system --gid "$SERVICE_GROUP" --create-home --home-dir "/home/${SERVICE_USER}" --shell /usr/sbin/nologin "$SERVICE_USER"
  fi
}

function fetch_latest_asf() {
  local asset_name asset_url tmp_dir
  asset_name="$(detect_asf_asset)"
  asset_url="$(curl -fsSL "$API_URL" | jq -r --arg name "$asset_name" '.assets[] | select(.name == $name) | .browser_download_url')"

  if [[ -z "$asset_url" || "$asset_url" == "null" ]]; then
    msg_error "Failed to locate release asset: $asset_name"
    exit 1
  fi

  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_dir"' RETURN

  curl -fsSL --retry 3 --retry-all-errors -o "$tmp_dir/asf.zip" "$asset_url"
  mkdir -p "$APP_DIR"
  unzip -o "$tmp_dir/asf.zip" -d "$APP_DIR" >/dev/null
}

function generate_password() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -base64 24 | tr -d '=+/' | cut -c1-24
  else
    tr -dc 'A-Za-z0-9' </dev/urandom | head -c 24
  fi
}

function write_asf_config() {
  local ipc_password
  local target_file
  target_file="${CONFIG_DIR}/ASF.json"

  mkdir -p "$CONFIG_DIR"

  if [[ -f "$target_file" ]]; then
    msg_warn "Existing ASF.json detected, keeping current file"
    return 0
  fi

  ipc_password="$(generate_password)"
  cat > "$target_file" <<JSON
{
  "Headless": true,
  "IPC": true,
  "IPCPassword": "${ipc_password}",
  "UpdateChannel": 1,
  "UpdatePeriod": 24
}
JSON

  chmod 640 "$target_file"
  echo "$ipc_password" > /root/.asf_ipc_password
  chmod 600 /root/.asf_ipc_password
}

function write_ipc_config() {
  local target_file
  target_file="${CONFIG_DIR}/IPC.config"

  if [[ -f "$target_file" ]]; then
    msg_warn "Existing IPC.config detected, keeping current file"
    return 0
  fi

  cat > "$target_file" <<'JSON'
{
  "Kestrel": {
    "Endpoints": {
      "HTTP": {
        "Url": "http://*:1242"
      }
    },
    "KnownNetworks": [
      "127.0.0.1/8",
      "::1/128",
      "10.0.0.0/8",
      "172.16.0.0/12",
      "192.168.0.0/16",
      "fc00::/7"
    ],
    "PathBase": "/"
  }
}
JSON

  chmod 644 "$target_file"
}

function write_example_bot() {
  local example_file
  example_file="${CONFIG_DIR}/ExampleBot.json.example"

  if [[ -f "$example_file" ]]; then
    return 0
  fi

  cat > "$example_file" <<'JSON'
{
  "Enabled": false,
  "SteamLogin": "CHANGE_ME",
  "SteamPassword": "CHANGE_ME",
  "PasswordFormat": 0,
  "OnlineStatus": 1,
  "RemoteCommunication": 3,
  "UseLoginKeys": true
}
JSON

  chmod 640 "$example_file"
}

function write_service() {
  cat > "/etc/systemd/system/${SERVICE_NAME}.service" <<EOF2
[Unit]
Description=ArchiSteamFarm
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${SERVICE_USER}
Group=${SERVICE_GROUP}
WorkingDirectory=${APP_DIR}
ExecStart=${APP_DIR}/ArchiSteamFarm
Restart=always
RestartSec=5
KillSignal=SIGINT
TimeoutStopSec=30
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF2

  systemctl daemon-reload
  systemctl enable "${SERVICE_NAME}.service" >/dev/null 2>&1
}

function write_connection_info() {
  local ip_addr ipc_password display_password
  ip_addr="$(hostname -I | awk '{print $1}')"
  display_password="<existing value in ${CONFIG_DIR}/ASF.json>"

  if [[ -f /root/.asf_ipc_password ]]; then
    ipc_password="$(cat /root/.asf_ipc_password)"
    display_password="$ipc_password"
  fi

  cat > /root/asf-lxc-info.txt <<EOF2
ArchiSteamFarm LXC information
==============================

URL: http://${ip_addr}:1242
IPCPassword: ${display_password}
Install directory: ${APP_DIR}
Config directory: ${CONFIG_DIR}
Service: ${SERVICE_NAME}.service

Useful commands
---------------
systemctl status ${SERVICE_NAME}
systemctl restart ${SERVICE_NAME}
journalctl -u ${SERVICE_NAME} -n 100 --no-pager

Example bot template
--------------------
${CONFIG_DIR}/ExampleBot.json.example
EOF2

  chmod 600 /root/asf-lxc-info.txt
}

msg_info "Installing dependencies"
$STD apt-get install -y curl ca-certificates jq unzip openssl nano sudo
msg_ok "Installed dependencies"

msg_info "Creating service account"
ensure_service_account
msg_ok "Created service account"

msg_info "Downloading and extracting latest ASF release"
fetch_latest_asf
msg_ok "Installed ASF"

msg_info "Writing default configuration"
write_asf_config
write_ipc_config
write_example_bot
msg_ok "Wrote default configuration"

msg_info "Setting permissions"
chown -R "${SERVICE_USER}:${SERVICE_GROUP}" "$APP_DIR"
chmod +x "${APP_DIR}/ArchiSteamFarm" 2>/dev/null || true
msg_ok "Permissions set"

msg_info "Creating systemd service"
write_service
msg_ok "Created systemd service"

msg_info "Starting ASF"
systemctl restart "${SERVICE_NAME}.service"
msg_ok "Started ASF"

msg_info "Saving connection details"
write_connection_info
msg_ok "Saved connection details to /root/asf-lxc-info.txt"

motd_ssh
customize
cleanup_lxc
