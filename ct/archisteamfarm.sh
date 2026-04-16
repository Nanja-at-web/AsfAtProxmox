#!/usr/bin/env bash

source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)

# Copyright (c) 2021-2026 community-scripts ORG
# Author: OpenAI
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/JustArchiNET/ArchiSteamFarm | https://github.com/JustArchiNET/ASF-ui | https://github.com/JustArchiNET/ASF-WebConfigGenerator

APP="ArchiSteamFarm"

var_tags="${var_tags:-steam}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-2048}"
var_disk="${var_disk:-8}"
var_os="${var_os:-debian}"
var_version="${var_version:-12}"
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

function detect_asf_asset() {
  case "$(uname -m)" in
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
      msg_error "Unsupported architecture: $(uname -m)"
      exit 1
      ;;
  esac
}

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  if [[ ! -d /opt/archisteamfarm ]]; then
    msg_error "No ${APP} installation found!"
    exit 1
  fi

  if [[ ! -f /etc/systemd/system/archisteamfarm.service && ! -f /lib/systemd/system/archisteamfarm.service ]]; then
    msg_error "No ${APP} systemd service found!"
    exit 1
  fi

  msg_info "Installing update dependencies"
  if command -v apt-get &>/dev/null; then
    apt-get update >/dev/null 2>&1
    apt-get install -y curl jq unzip ca-certificates >/dev/null 2>&1
  fi
  msg_ok "Update dependencies ready"

  local api_url asset_name asset_url tmp_dir
  api_url="https://api.github.com/repos/JustArchiNET/ArchiSteamFarm/releases/latest"
  asset_name="$(detect_asf_asset)"

  asset_url="$(curl -fsSL "$api_url" | jq -r --arg name "$asset_name" '.assets[] | select(.name == $name) | .browser_download_url')"
  if [[ -z "$asset_url" || "$asset_url" == "null" ]]; then
    msg_error "Unable to resolve latest ASF asset URL for ${asset_name}"
    exit 1
  fi

  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_dir"' EXIT

  msg_info "Stopping ${APP}"
  systemctl stop archisteamfarm.service
  msg_ok "Stopped ${APP}"

  msg_info "Downloading latest ${APP} release"
  curl -fsSL --retry 3 --retry-all-errors -o "$tmp_dir/asf.zip" "$asset_url"
  msg_ok "Downloaded latest ${APP} release"

  msg_info "Deploying updated files"
  unzip -o "$tmp_dir/asf.zip" -d /opt/archisteamfarm >/dev/null
  chown -R asf:asf /opt/archisteamfarm
  chmod +x /opt/archisteamfarm/ArchiSteamFarm 2>/dev/null || true
  systemctl daemon-reload
  msg_ok "Deployed updated files"

  msg_info "Starting ${APP}"
  systemctl restart archisteamfarm.service
  msg_ok "Started ${APP}"

  rm -rf "$tmp_dir"
  trap - EXIT
}

start
build_container
description

msg_ok "Completed successfully!\n"

echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW}Access the ASF Web UI using:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:1242${CL}"
echo -e "${INFO}${YW}Inside the container, read first-login details from:${CL}"
echo -e "${TAB}${BGN}/root/asf-lxc-info.txt${CL}"
