#!/usr/bin/env bash
# Copyright (c) 2021-2026 community-scripts ORG
# Author: OpenAI
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/JustArchiNET/ArchiSteamFarm | https://github.com/JustArchiNET/ASF-ui | https://github.com/JustArchiNET/ASF-WebConfigGenerator

set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive

APP_DIR="/opt/archisteamfarm"
CONFIG_DIR="${APP_DIR}/config"
SERVICE_NAME="archisteamfarm"
SERVICE_USER="asf"
SERVICE_GROUP="asf"
API_URL="https://api.github.com/repos/JustArchiNET/ArchiSteamFarm/releases/latest"

log_info() { echo "[INFO] $*"; }
log_ok() { echo "[OK] $*"; }
log_warn() { echo "[WARN] $*"; }
log_error() { echo "[ERROR] $*" >&2; }

trap 'log_error "Installation failed near line ${LINENO}"' ERR

require_root() {
  if [[ "$(id -u)" -ne 0 ]]; then
    log_error "Run this installer as root."
    exit 1
  fi
}

get_primary_ip() {
  local detected_ip
  detected_ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
  if [[ -n "${detected_ip}" ]]; then
    echo "${detected_ip}"
    return 0
  fi
  detected_ip="$(ip route get 1.1.1.1 2>/dev/null | awk '/src/ {for (i=1; i<=NF; i++) if ($i == "src") {print $(i+1); exit}}')"
  echo "${detected_ip:-127.0.0.1}"
}

detect_asf_asset() {
  case "$(uname -m)" in
    x86_64 | amd64) echo "ASF-linux-x64.zip" ;;
    aarch64 | arm64) echo "ASF-linux-arm64.zip" ;;
    armv7l | armv6l | armhf) echo "ASF-linux-arm.zip" ;;
    *)
      log_error "Unsupported architecture: $(uname -m)"
      exit 1
      ;;
  esac
}

install_dependencies() {
  log_info "Updating APT package index"
  apt-get update
  log_info "Installing runtime dependencies"
  apt-get install -y curl ca-certificates jq unzip openssl nano sudo
  log_ok "Dependencies installed"
}

ensure_service_account() {
  if ! getent group "${SERVICE_GROUP}" >/dev/null 2>&1; then
    groupadd --system "${SERVICE_GROUP}"
  fi
  if ! id -u "${SERVICE_USER}" >/dev/null 2>&1; then
    useradd --system --gid "${SERVICE_GROUP}" --create-home --home-dir "/home/${SERVICE_USER}" --shell /usr/sbin/nologin "${SERVICE_USER}"
  fi
  log_ok "Service account ready"
}

fetch_latest_asf() {
  local asset_name asset_url tmp_dir
  asset_name="$(detect_asf_asset)"
  asset_url="$(curl -fsSL "${API_URL}" | jq -r --arg name "${asset_name}" '.assets[] | select(.name == $name) | .browser_download_url')"

  if [[ -z "${asset_url}" || "${asset_url}" == "null" ]]; then
    log_error "Failed to resolve latest ASF asset URL for ${asset_name}"
    exit 1
  fi

  tmp_dir="$(mktemp -d)"
  curl -fsSL --retry 3 --retry-all-errors -o "${tmp_dir}/asf.zip" "${asset_url}"
  mkdir -p "${APP_DIR}"
  unzip -o "${tmp_dir}/asf.zip" -d "${APP_DIR}" >/dev/null
  rm -rf "${tmp_dir}"
  log_ok "ASF extracted to ${APP_DIR}"
}

generate_password() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -base64 24 | tr -d '=+/' | cut -c1-24
  else
    tr -dc 'A-Za-z0-9' </dev/urandom | head -c 24
  fi
}

write_asf_config() {
  local ipc_password target_file
  target_file="${CONFIG_DIR}/ASF.json"
  mkdir -p "${CONFIG_DIR}"

  if [[ -f "${target_file}" ]]; then
    log_warn "Existing ASF.json detected, keeping it"
    return 0
  fi

  ipc_password="$(generate_password)"
  cat > "${target_file}" <<JSON
{
  "Headless": true,
  "IPC": true,
  "IPCPassword": "${ipc_password}",
  "UpdateChannel": 1,
  "UpdatePeriod": 24
}
JSON

  chmod 640 "${target_file}"
  echo "${ipc_password}" > /root/.asf_ipc_password
  chmod 600 /root/.asf_ipc_password
  log_ok "ASF.json created"
}

write_ipc_config() {
  local target_file
  target_file="${CONFIG_DIR}/IPC.config"

  if [[ -f "${target_file}" ]]; then
    log_warn "Existing IPC.config detected, keeping it"
    return 0
  fi

  cat > "${target_file}" <<'JSON'
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

  chmod 644 "${target_file}"
  log_ok "IPC.config created"
}

write_example_bot() {
  local example_file
  example_file="${CONFIG_DIR}/ExampleBot.json.example"

  if [[ -f "${example_file}" ]]; then
    return 0
  fi

  cat > "${example_file}" <<'JSON'
{
  "Enabled": false,
  "SteamLogin": "CHANGE_ME",
  "PasswordFormat": 0,
  "OnlineStatus": 1,
  "RemoteCommunication": 3,
  "UseLoginKeys": true
}
JSON

  chmod 640 "${example_file}"
  log_ok "Example bot file created"
}

write_service() {
  cat > "/etc/systemd/system/${SERVICE_NAME}.service" <<EOF
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
EOF

  systemctl daemon-reload
  systemctl enable "${SERVICE_NAME}.service" >/dev/null 2>&1
  log_ok "Systemd service written"
}

set_permissions() {
  chown -R "${SERVICE_USER}:${SERVICE_GROUP}" "${APP_DIR}"
  chmod +x "${APP_DIR}/ArchiSteamFarm" 2>/dev/null || true
  log_ok "Permissions set"
}

start_and_validate_service() {
  systemctl restart "${SERVICE_NAME}.service"
  sleep 3
  if ! systemctl is-active --quiet "${SERVICE_NAME}.service"; then
    log_error "${SERVICE_NAME}.service did not start"
    systemctl status "${SERVICE_NAME}.service" --no-pager -l || true
    journalctl -u "${SERVICE_NAME}.service" -n 50 --no-pager || true
    exit 1
  fi
  log_ok "${SERVICE_NAME}.service is active"
}

write_connection_info() {
  local ip_addr ipc_password display_password
  ip_addr="$(get_primary_ip)"
  display_password="see ${CONFIG_DIR}/ASF.json"

  if [[ -f /root/.asf_ipc_password ]]; then
    ipc_password="$(cat /root/.asf_ipc_password)"
    display_password="${ipc_password}"
  fi

  cat > /root/asf-lxc-info.txt <<EOF
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
EOF

  chmod 600 /root/asf-lxc-info.txt
  log_ok "Connection details saved"
}

main() {
  require_root
  install_dependencies
  ensure_service_account
  fetch_latest_asf
  write_asf_config
  write_ipc_config
  write_example_bot
  set_permissions
  write_service
  start_and_validate_service
  write_connection_info
  log_ok "ASF installation finished successfully"
}

main "$@"
