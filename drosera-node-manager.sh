#!/usr/bin/env bash
# =====================================================================
#  Drosera Node — RU/EN interactive manager (systemd-based)
#  Bilingual menus & prompts. Includes version check and safe updater.
#  Target: Ubuntu/Debian (apt). Some steps require sudo privileges.
#  Version: 3.0.0
# =====================================================================
set -Eeuo pipefail

# -----------------------------
# Branding / Logo
# -----------------------------
display_logo() {
  cat <<'EOF'
 _   _           _  _____      
| \ | |         | ||____ |     
|  \| | ___   __| |    / /_ __ 
| . ` |/ _ \ / _` |    \ \ '__|
| |\  | (_) | (_| |.___/ / |   
\_| \_/\___/ \__,_|\____/|_|   
          Drosera
  TG: https://t.me/NodesN3R
EOF
}

# -----------------------------
# Colors / UI
# -----------------------------
clrGreen=$'\033[0;32m'
clrCyan=$'\033[0;36m'
clrBlue=$'\033[0;34m'
clrRed=$'\033[0;31m'
clrYellow=$'\033[1;33m'
clrMag=$'\033[1;35m'
clrReset=$'\033[0m'
clrBold=$'\033[1m'
clrDim=$'\033[2m'

ok()   { echo -e "${clrGreen}[OK]${clrReset} ${*:-}"; }
info() { echo -e "${clrCyan}[INFO]${clrReset} ${*:-}"; }
warn() { echo -e "${clrYellow}[WARN]${clrReset} ${*:-}"; }
err()  { echo -e "${clrRed}[ERROR]${clrReset} ${*:-}"; }
hr()   { echo -e "${clrDim}────────────────────────────────────────────────────────${clrReset}"; }

# -----------------------------
# Config / Paths
# -----------------------------
SCRIPT_NAME="drosera"
SCRIPT_VERSION="3.0.0"
VERSIONS_FILE_URL="https://raw.githubusercontent.com/k2wGG/scripts/main/versions.txt"
SCRIPT_FILE_URL="https://raw.githubusercontent.com/k2wGG/scripts/main/drosera-node-manager.sh"

SERVICE_NAME="drosera"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
HOME_BIN="$HOME/.drosera/bin/drosera-operator"
USR_BIN="/usr/bin/drosera-operator"
DB_PATH="$HOME/.drosera.db"

# -----------------------------
# Language (RU/EN)
# -----------------------------
LANG_CHOICE="ru"  # default is Russian

choose_language() {
  clear; display_logo
  echo -e "
${clrBold}${clrMag}Select language / Выберите язык${clrReset}"
  echo -e "${clrDim}1) Русский${clrReset}"
  echo -e "${clrDim}2) English${clrReset}"
  read -rp "> " ans
  case "${ans:-}" in
    2) LANG_CHOICE="en" ;;
    *) LANG_CHOICE="ru" ;;
  esac
}


tr() {
  local k="${1-}"; [[ -z "$k" ]] && return 0
  case "$LANG_CHOICE" in
    en)
      case "$k" in
        script_upd_check) echo "Checking script updates..." ;;
        script_upd_found) echo "New script version found" ;;
        script_upd_ok) echo "Script is up to date" ;;
        need_curl) echo "curl not found, installing..." ;;
        need_jq) echo "jq not found, installing..." ;;
        deps_install) echo "Installing packages and tools..." ;;
        deps_done) echo "Dependencies installed" ;;
        ports_cfg) echo "Configuring firewall rules for ports 31313/31314..." ;;
        port_open) echo "Port opened" ;;
        port_already) echo "Port already allowed" ;;
        latest_check) echo "Checking latest drosera-operator version..." ;;
        not_found_url) echo "Could not resolve latest release asset URL" ;;
        bin_updated) echo "drosera-operator updated in /usr/bin" ;;
        bin_missing) echo "Operator binary not found after extraction" ;;
        versions_title) echo "Version & status" ;;
        path_shown) echo "Operator path (first in PATH)" ;;
        inst_ver) echo "Installed operator version" ;;
        usrbin_ver) echo "/usr/bin version" ;;
        homebin_ver) echo "~/.drosera/bin version" ;;
        latest_rel) echo "Latest release" ;;
        svc_status) echo "Service status" ;;
        running_bin) echo "Running binary" ;;
        running_ver) echo "Running version" ;;
        node_not_running) echo "Node process is not running." ;;
        update_avail) echo "Update available" ;;
        update_node) echo "Updating node to the latest and restarting service..." ;;
        updater_summary) echo "Current versions" ;;
        service_active) echo "Service is active" ;;
        service_inactive) echo "Service is not active after update. Check logs." ;;
        start_node) echo "Starting Drosera node..." ;;
        node_started) echo "Node started" ;;
        logs_hint) echo "Following logs (Ctrl+C to stop)" ;;
        restarting) echo "Restarting service..." ;;
        removed) echo "Node removed" ;;
        menu_title) echo "Drosera Node — Manager" ;;
        m1_deps) echo "Install dependencies" ;;
        m2_deploy_trap) echo "Deploy Trap" ;;
        m3_install_node) echo "Install node" ;;
        m4_register) echo "Register operator" ;;
        m5_start) echo "Start node" ;;
        m6_status) echo "Node status" ;;
        m7_logs) echo "Node logs" ;;
        m8_restart) echo "Restart node" ;;
        m9_remove) echo "Remove node" ;;
        m10_cadet) echo "Cadet Discord Role Trap" ;;
        m11_two) echo "Deploy TWO traps (Discord + HelloWorld)" ;;
        m12_versions) echo "Check versions / status" ;;
        m13_update) echo "Обновить ноду" ;;
        m14_versions_en) echo "Проверить версию" ;;
        m15_lang) echo "Change language / Сменить язык" ;;
        exit) echo "Exit" ;;
        press_enter) echo "Press Enter to return to menu..." ;;
        enter_email) echo "Enter your GitHub email:" ;;
        enter_user) echo "Enter your GitHub username:" ;;
        init_proj) echo "Initializing project..." ;;
        ask_whitelist) echo "Enter your EVM wallet address (for whitelist):" ;;
        ask_priv) echo "Enter your EVM private key:" ;;
        reg_done) echo "Registration completed." ;;
        unit_logs_hint) echo "For logs: journalctl -u drosera.service -f" ;;
        removing) echo "Removing Drosera node..." ;;
        bad_input) echo "Invalid choice, try again." ;;
      esac
      ;;
    *) # ru
      case "$k" in
        script_upd_check) echo "Проверка обновлений скрипта..." ;;
        script_upd_found) echo "Найдена новая версия скрипта" ;;
        script_upd_ok) echo "Версия скрипта актуальна" ;;
        need_curl) echo "curl не найден, устанавливаю..." ;;
        need_jq) echo "jq не найден, устанавливаю..." ;;
        deps_install) echo "Установка необходимых пакетов и инструментов..." ;;
        deps_done) echo "Зависимости установлены" ;;
        ports_cfg) echo "Настройка правил для портов 31313/31314..." ;;
        port_open) echo "Порт открыт" ;;
        port_already) echo "Порт уже открыт" ;;
        latest_check) echo "Проверяю последнюю версию drosera-operator..." ;;
        not_found_url) echo "Не удалось получить ссылку на актуальный релиз" ;;
        bin_updated) echo "drosera-operator обновлён в /usr/bin" ;;
        bin_missing) echo "Бинарник operator не найден после распаковки" ;;
        versions_title) echo "Версии и статус" ;;
        path_shown) echo "Путь бинаря (первый в PATH)" ;;
        inst_ver) echo "Установленная версия бинаря" ;;
        usrbin_ver) echo "Версия /usr/bin" ;;
        homebin_ver) echo "Версия ~/.drosera/bin" ;;
        latest_rel) echo "Последний релиз" ;;
        svc_status) echo "Статус сервиса" ;;
        running_bin) echo "Запущенный бинарь" ;;
        running_ver) echo "Версия процесса" ;;
        node_not_running) echo "Процесс ноды не запущен." ;;
        update_avail) echo "Доступно обновление" ;;
        update_node) echo "Обновляю ноду до последней версии и перезапускаю сервис..." ;;
        updater_summary) echo "Текущие версии" ;;
        service_active) echo "Сервис активен" ;;
        service_inactive) echo "После обновления сервис не активен. Проверьте логи." ;;
        start_node) echo "Запуск ноды Drosera..." ;;
        node_started) echo "Нода запущена" ;;
        logs_hint) echo "Показываю логи (Ctrl+C для выхода)" ;;
        restarting) echo "Перезапуск сервиса..." ;;
        removed) echo "Нода удалена" ;;
        menu_title) echo "Drosera Node — менеджер" ;;
        m1_deps) echo "Установить зависимости" ;;
        m2_deploy_trap) echo "Деплой Trap" ;;
        m3_install_node) echo "Установить ноду" ;;
        m4_register) echo "Зарегистрировать оператора" ;;
        m5_start) echo "Запустить ноду" ;;
        m6_status) echo "Статус ноды" ;;
        m7_logs) echo "Логи ноды" ;;
        m8_restart) echo "Перезапустить ноду" ;;
        m9_remove) echo "Удалить ноду" ;;
        m10_cadet) echo "Cadet Discord Role Trap" ;;
        m11_two) echo "Деплой ДВУХ трапов (Discord + HelloWorld)" ;;
        m12_versions) echo "Проверить версии/статус" ;;
        m13_update) echo "Обновить ноду (update + restart)" ;;
        m14_versions_en) echo "Version (English)" ;;
        m15_lang) echo "Сменить язык / Change language" ;;
        exit) echo "Выход" ;;
        press_enter) echo "Нажмите Enter для продолжения..." ;;
        enter_email) echo "Введите вашу GitHub почту:" ;;
        enter_user) echo "Введите ваш GitHub юзернейм:" ;;
        init_proj) echo "Инициализация проекта..." ;;
        ask_whitelist) echo "Введите адрес вашего EVM кошелька (для whitelist):" ;;
        ask_priv) echo "Введите приватный ключ EVM кошелька:" ;;
        reg_done) echo "Регистрация завершена." ;;
        unit_logs_hint) echo "Для логов: journalctl -u drosera.service -f" ;;
        removing) echo "Удаление ноды Drosera..." ;;
        bad_input) echo "Неверный ввод, попробуйте снова." ;;
      esac
      ;;
  esac
}

# -----------------------------
# Prerequisites
# -----------------------------
ensure_curl() { command -v curl >/dev/null 2>&1 || { info "$(tr need_curl)"; sudo apt update && sudo apt install -y curl; }; }
ensure_jq()   { command -v jq   >/dev/null 2>&1 || { info "$(tr need_jq)";   sudo apt update && sudo apt install -y jq;   }; }

# -----------------------------
# Script self-update
# -----------------------------
auto_update() {
  info "$(tr script_upd_check)"
  local latest
  latest=$(curl -fsSL "$VERSIONS_FILE_URL" | grep -E "^$SCRIPT_NAME[[:space:]]" | awk '{print $2}' || true)
  if [[ -z "${latest:-}" ]]; then return 0; fi
  if [[ "$latest" != "$SCRIPT_VERSION" ]]; then
    info "$(tr script_upd_found): $latest (you have $SCRIPT_VERSION)"
    curl -fsSL "$SCRIPT_FILE_URL" -o /tmp/drosera-node-manager.sh
    chmod +x /tmp/drosera-node-manager.sh
    exec /tmp/drosera-node-manager.sh
  else
    ok "$(tr script_upd_ok): $SCRIPT_VERSION"
  fi
}

# -----------------------------
# Dependencies & ports
# -----------------------------
install_dependencies() {
  info "$(tr deps_install)"
  sudo apt-get update && sudo apt-get upgrade -y
  sudo apt install -y curl ufw iptables build-essential git wget lz4 jq make gcc nano \
    automake autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev \
    libleveldb-dev tar clang bsdmainutils ncdu unzip

  # extra toolchains
  curl -L https://app.drosera.io/install | bash
  curl -L https://foundry.paradigm.xyz | bash
  curl -fsSL https://bun.sh/install | bash

  info "$(tr ports_cfg)"
  for port in 31313 31314; do
    if ! sudo iptables -C INPUT -p tcp --dport $port -j ACCEPT 2>/dev/null; then
      sudo iptables -I INPUT -p tcp --dport $port -j ACCEPT
      ok "$(tr port_open): $port"
    else
      info "$(tr port_already): $port"
    fi
  done
  ok "$(tr deps_done)"
}

# -----------------------------
# Operator binary helpers
# -----------------------------
get_drosera_operator() { command -v drosera-operator 2>/dev/null || echo "$HOME_BIN"; }

get_latest_operator_release_url() {
  # Pick correct asset by architecture (x86_64 / aarch64)
  local arch pattern
  arch=$(uname -m)
  case "$arch" in
    x86_64|amd64) pattern="drosera-operator-v.*-x86_64-unknown-linux-gnu\.tar\.gz" ;;
    aarch64|arm64) pattern="drosera-operator-v.*-aarch64-unknown-linux-gnu\.tar\.gz" ;;
    *) pattern="drosera-operator-v.*-$(uname -m)-unknown-linux-gnu\.tar\.gz" ;;
  esac
  curl -s "https://api.github.com/repos/drosera-network/releases/releases/latest" |
    jq -r --arg re "$pattern" '.assets[] | select(.name | test($re)) | .browser_download_url' | head -n1
}


get_latest_operator_version() {
  ensure_jq
  local json ver
  json=$(curl -s "https://api.github.com/repos/drosera-network/releases/releases/latest" || true)
  ver=$(echo "$json" | jq -r '.tag_name // ""' | sed -E 's/^[^0-9]*([0-9]+\.[0-9]+\.[0-9]+).*$/\1/')
  if [[ -z "$ver" || "$ver" == "null" ]]; then
    ver=$(echo "$json" | jq -r '.assets[].name' | grep -m1 -oE '[0-9]+\.[0-9]+\.[0-9]+')
  fi
  [[ -n "$ver" ]] && echo "$ver"
}

get_operator_version_of() {
  local p="$1"
  if [[ -x "$p" ]]; then
    "$p" --version 2>/dev/null | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | head -n1
  fi
}

get_installed_operator_version() {
  local op; op="$(get_drosera_operator)"
  if [[ -x "$op" ]]; then "$op" --version 2>/dev/null | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | head -n1; fi
}

update_operator_bin() {
  ensure_jq
  info "$(tr latest_check)"
  local url file
  url=$(get_latest_operator_release_url)
  if [[ -z "$url" ]]; then err "$(tr not_found_url)"; return 1; fi
  file=$(basename "$url")
  [[ -f "$file" ]] || curl -LO "$url"
  tar -xvf "$file"
  if [[ -f drosera-operator ]]; then
    sudo install -m 0755 drosera-operator "$USR_BIN"
    ok "$(tr bin_updated)"
  else
    err "$(tr bin_missing)"; return 1
  fi
}

sync_operator_bin() {
  if [[ -x "$HOME_BIN" ]]; then sudo install -m 0755 "$HOME_BIN" "$USR_BIN"; ok "$(tr bin_updated)"; else err "~/.drosera/bin missing operator"; return 1; fi
}

# -----------------------------
# Version & status
# -----------------------------
check_node_version() {
  ensure_jq
  echo -e "${clrBold}$(tr versions_title)${clrReset}"; hr
  local op_path installed latest svc pid run_path run_ver usr_ver home_ver
  op_path="$(get_drosera_operator)"; installed="$(get_installed_operator_version || true)"; latest="$(get_latest_operator_version || true)"
  svc=$(systemctl is-active "$SERVICE_NAME" 2>/dev/null || true)
  usr_ver="$(get_operator_version_of "$USR_BIN" || true)"; home_ver="$(get_operator_version_of "$HOME_BIN" || true)"
  echo "PATH: $PATH"
  echo "$(tr path_shown): $op_path"
  echo "$(tr inst_ver): ${installed:-unknown}"
  echo "$(tr usrbin_ver): ${usr_ver:-unknown}"
  echo "$(tr homebin_ver): ${home_ver:-unknown}"
  echo "$(tr latest_rel): ${latest:-unknown}"
  echo "$(tr svc_status): ${svc:-unknown}"
  pid=$(pgrep -f 'drosera-operator.*node' | head -n1 || true)
  if [[ -n "$pid" ]]; then
    run_path=$(readlink -f "/proc/$pid/exe" 2>/dev/null || true)
    run_ver=$(get_operator_version_of "$run_path")
    echo "$(tr running_bin): $run_path"
    echo "$(tr running_ver): ${run_ver:-unknown} (PID $pid)"
  else
    echo "$(tr node_not_running)"
  fi
  if [[ -n "${installed:-}" && -n "${latest:-}" && "$installed" != "$latest" ]]; then echo "$(tr update_avail): $installed → $latest"; fi
}

print_versions_en() {
  # Print versions using current language (RU/EN)
  check_node_version
}


# -----------------------------
# App flows (deploys and node ops)

# Ensure trap deps & remappings exist (supports new package name @drosera/contracts)
ensure_trap_deps() {
  # Ensure Drosera contracts and forge-std are available and remapped
  local have_lib="lib/contracts/src/Trap.sol"
  local forge_std_core="lib/forge-std/src/Test.sol"
  local forge_std_nested="lib/contracts/lib/forge-std/src/Test.sol"

  # 1) Contracts via Foundry (preferred)
  if [[ ! -f "$have_lib" ]]; then
    forge install drosera-network/contracts || true
  fi

  # 2) Remap drosera-contracts -> lib/contracts/src
  if [[ -f foundry.toml ]]; then
    sed -i 's|drosera-contracts/=node_modules/drosera-contracts/src/|drosera-contracts/=lib/contracts/src/|g' foundry.toml 2>/dev/null || true
    sed -i 's|drosera-contracts/=node_modules/@drosera/contracts/src/|drosera-contracts/=lib/contracts/src/|g' foundry.toml 2>/dev/null || true
  fi
  if [[ -f remappings.txt ]]; then
    if grep -q '^drosera-contracts/=' remappings.txt; then
      sed -i 's|^drosera-contracts/=.*|drosera-contracts/=lib/contracts/src/|' remappings.txt
    else
      echo 'drosera-contracts/=lib/contracts/src/' >> remappings.txt
    fi
  else
    echo 'drosera-contracts/=lib/contracts/src/' > remappings.txt
  fi

  # 3) Ensure forge-std present and mapped
  if [[ ! -f "$forge_std_core" && ! -f "$forge_std_nested" ]]; then
    forge install foundry-rs/forge-std || true
  fi
  local fs_target
  if [[ -f "$forge_std_core" ]]; then
    fs_target='lib/forge-std/src/'
  else
    fs_target='lib/contracts/lib/forge-std/src/'
  fi
  if [[ -f foundry.toml ]]; then
    sed -i "s|forge-std/=node_modules/forge-std/|forge-std/=$fs_target|g" foundry.toml 2>/dev/null || true
  fi
  if [[ -f remappings.txt ]]; then
    if grep -q '^forge-std/=' remappings.txt; then
      sed -i "s|^forge-std/=.*|forge-std/=$fs_target|" remappings.txt
    else
      echo "forge-std/=$fs_target" >> remappings.txt
    fi
  else
    echo "forge-std/=$fs_target" >> remappings.txt
  fi
}




# -----------------------------
# App flows (deploys and node ops)
# -----------------------------
deploy_trap() {
  info "Updating tools (droseraup, foundryup)..."; droseraup || true; foundryup || true
  mkdir -p "$HOME/my-drosera-trap" && cd "$HOME/my-drosera-trap"
  read -rp "$(tr enter_email) " GITHUB_EMAIL
  read -rp "$(tr enter_user)  " GITHUB_USERNAME
  git config --global user.email "$GITHUB_EMAIL"; git config --global user.name "$GITHUB_USERNAME"
  info "$(tr init_proj)"
  if [[ ! -f foundry.toml ]]; then
    forge init -t drosera-network/trap-foundry-template
  fi
  bun install || true
  ensure_trap_deps
  forge build
  read -rp "$(tr ask_whitelist) " OPERATOR_ADDR
  cat > drosera.toml <<EOL
ethereum_rpc = "https://ethereum-hoodi-rpc.publicnode.com"
drosera_rpc = "https://relay.hoodi.drosera.io"
eth_chain_id = 560048
drosera_address = "0x91cB447BaFc6e0EA0F4Fe056F5a9b1F14bb06e5D"

[traps]

[traps.mytrap]
path = "out/HelloWorldTrap.sol/HelloWorldTrap.json"
response_contract = "0x183D78491555cb69B68d2354F7373cc2632508C7"
response_function = "helloworld(string)"
cooldown_period_blocks = 33
min_number_of_operators = 1
max_number_of_operators = 2
block_sample_size = 10
private_trap = true
whitelist = ["$OPERATOR_ADDR"]
EOL
  read -s -rp "$(tr ask_priv) " PRIV_KEY; echo
  export DROSERA_PRIVATE_KEY="$PRIV_KEY"
  drosera apply
  ok "Trap deployed"
}

deploy_two_traps() {
  info "Updating tools (droseraup, foundryup)..."; droseraup || true; foundryup || true
  mkdir -p "$HOME/my-drosera-trap" && cd "$HOME/my-drosera-trap"
  read -rp "$(tr enter_email) " GITHUB_EMAIL
  read -rp "$(tr enter_user)  " GITHUB_USERNAME
  git config --global user.email "$GITHUB_EMAIL"; git config --global user.name "$GITHUB_USERNAME"
  if [[ ! -f foundry.toml ]]; then forge init -t drosera-network/trap-foundry-template; fi
  bun install || true
  ensure_trap_deps
  forge build
  read -rp "$(tr ask_whitelist) " OPERATOR_ADDR
  cat > drosera.toml <<EOL
ethereum_rpc = "https://ethereum-hoodi-rpc.publicnode.com"
drosera_rpc = "https://relay.hoodi.drosera.io"
eth_chain_id = 560048
drosera_address = "0x91cB447BaFc6e0EA0F4Fe056F5a9b1F14bb06e5D"

[traps]

[traps.mytrap]
path = "out/HelloWorldTrap.sol/HelloWorldTrap.json"
response_contract = "0x183D78491555cb69B68d2354F7373cc2632508C7"
response_function = "helloworld(string)"
cooldown_period_blocks = 33
min_number_of_operators = 1
max_number_of_operators = 2
block_sample_size = 10
private_trap = true
whitelist = ["$OPERATOR_ADDR"]

[traps.discord]
path = "out/Trap.sol/Trap.json"
response_contract = "0x25E2CeF36020A736CF8a4D2cAdD2EBE3940F4608"
response_function = "respondWithDiscordName(string)"
cooldown_period_blocks = 33
min_number_of_operators = 1
max_number_of_operators = 2
block_sample_size = 10
private_trap = true
whitelist = ["$OPERATOR_ADDR"]
EOL
  read -s -rp "$(tr ask_priv) " PRIV_KEY; echo
  info "First apply..."; drosera apply --private-key "$PRIV_KEY" | tee apply.log
  DISCORD_ADDRESS=$(grep -oE '0x[0-9a-fA-F]{40}' apply.log | tail -1 || true)
  if [[ -n "${DISCORD_ADDRESS:-}" ]]; then
    awk -v addr="$DISCORD_ADDRESS" '
      /^\[traps.discord\]/ { insec=1 }
      insec && /^whitelist/ && !x { print; print "address = \"" addr "\""; x=1; next }
      /^\[/ && $0 != "[traps.discord]" { insec=0 }
      { print }
    ' drosera.toml > drosera.toml.tmp && mv drosera.toml.tmp drosera.toml
  fi
  info "Second apply..."; drosera apply --private-key "$PRIV_KEY" | tee apply2.log
  ok "Two traps deployed"
}

install_node() {
  info "Installing node..."
  local TARGET_FILE="$HOME/my-drosera-trap/drosera.toml"
  [[ -f "$TARGET_FILE" ]] && sed -i '/^private_trap/d;/^whitelist/d' "$TARGET_FILE"
  read -rp "$(tr ask_whitelist) " WALLET_ADDRESS
  {
    echo "private_trap = true"; echo "whitelist = [\"$WALLET_ADDRESS\"]"
  } >> "$TARGET_FILE"
  read -s -rp "$(tr ask_priv) " PRIV_KEY; echo
  export DROSERA_PRIVATE_KEY="$PRIV_KEY"; (cd "$HOME/my-drosera-trap" && drosera apply)
  ok "Node installed"
}

register_operator() {
  info "Registering operator..."; update_operator_bin
  read -s -rp "$(tr ask_priv) " PRIV_KEY; echo
  export DROSERA_PRIVATE_KEY="$PRIV_KEY"
  "$(get_drosera_operator)" register \
    --eth-rpc-url https://ethereum-hoodi-rpc.publicnode.com \
    --eth-private-key "$DROSERA_PRIVATE_KEY" \
    --drosera-address 0x91cB447BaFc6e0EA0F4Fe056F5a9b1F14bb06e5D \
    --eth-chain-id 560048
  ok "$(tr reg_done)"
}

start_node() {
  info "$(tr start_node)"
  update_operator_bin
  read -s -rp "$(tr ask_priv) " PRIV_KEY; echo
  export DROSERA_PRIVATE_KEY="$PRIV_KEY"
  local SERVER_IP; SERVER_IP=$(curl -s https://api.ipify.org)
  local BIN_PATH; BIN_PATH="$(get_drosera_operator)"
  sudo tee "$SERVICE_FILE" >/dev/null <<EOF
[Unit]
Description=drosera node service
After=network-online.target

[Service]
User=$USER
Restart=always
RestartSec=15
LimitNOFILE=65535
ExecStart=$BIN_PATH node \
  --db-file-path $DB_PATH \
  --network-p2p-port 31313 \
  --server-port 31314 \
  --eth-rpc-url https://ethereum-hoodi-rpc.publicnode.com \
  --eth-backup-rpc-url https://0xrpc.io/hoodi \
  --drosera-address 0x91cB447BaFc6e0EA0F4Fe056F5a9b1F14bb06e5D \
  --eth-private-key $DROSERA_PRIVATE_KEY \
  --eth-chain-id 560048 \
  --listen-address 0.0.0.0 \
  --network-external-p2p-address $SERVER_IP \
  --disable-dnr-confirmation true

[Install]
WantedBy=multi-user.target
EOF
  sudo systemctl daemon-reload
  sudo systemctl enable "$SERVICE_NAME"
  sudo systemctl restart "$SERVICE_NAME"
  ok "$(tr node_started)"; info "$(tr unit_logs_hint)"
}

restart_node() { info "$(tr restarting)"; sudo systemctl restart "$SERVICE_NAME"; }

show_status() { systemctl status "$SERVICE_NAME" --no-pager || true; }

follow_logs() { info "$(tr logs_hint)"; journalctl -u "$SERVICE_NAME" -fn 200; }

# Safe updater with restart
update_node_safe() {
  info "$(tr update_node)"
  local latest installed home_ver usr_ver
  latest=$(get_latest_operator_version || echo "")
  installed=$(get_installed_operator_version || echo "")
  home_ver=$(get_operator_version_of "$HOME_BIN" || echo "")
  usr_ver=$(get_operator_version_of "$USR_BIN" || echo "")
  info "$(tr updater_summary): installed=$installed, /usr/bin=$usr_ver, ~/.drosera=$home_ver, latest=${latest:-unknown}"
  if command -v droseraup >/dev/null 2>&1; then droseraup || true; home_ver=$(get_operator_version_of "$HOME_BIN" || echo "$home_ver"); fi
  if [[ -n "$latest" && "$home_ver" == "$latest" ]]; then sync_operator_bin || true; else update_operator_bin || true; fi
  usr_ver=$(get_operator_version_of "$USR_BIN" || echo "")
  if [[ -n "$latest" && "$usr_ver" != "$latest" && -x "$HOME_BIN" ]]; then sudo install -m 0755 "$HOME_BIN" "$USR_BIN"; usr_ver=$(get_operator_version_of "$USR_BIN" || echo ""); fi
  sudo systemctl daemon-reload || true
  sudo systemctl restart "$SERVICE_NAME" || true
  sleep 2
  local status run_pid run_path run_ver
  status=$(systemctl is-active "$SERVICE_NAME" 2>/dev/null || true)
  run_pid=$(pgrep -f 'drosera-operator.*node' | head -n1 || true)
  if [[ -n "$run_pid" ]]; then run_path=$(readlink -f "/proc/$run_pid/exe" 2>/dev/null || true); run_ver=$(get_operator_version_of "$run_path"); fi
  if [[ "$status" == "active" ]]; then ok "$(tr service_active). $(tr running_ver): ${run_ver:-unknown}"; else err "$(tr service_inactive)"; fi
}

remove_node() {
  info "$(tr removing)"; sudo systemctl stop "$SERVICE_NAME" || true; sudo systemctl disable "$SERVICE_NAME" || true
  sudo rm -f "$SERVICE_FILE"; sudo systemctl daemon-reload || true
  rm -rf "$HOME/my-drosera-trap" || true
  ok "$(tr removed)"
}

# -----------------------------
# Menu
# -----------------------------
menu() {
  while true; do
    clear; display_logo; hr
    echo -e "${clrBold}${clrMag}$(tr menu_title)${clrReset} ${clrDim}(v${SCRIPT_VERSION})${clrReset}\n"
    echo -e "${clrGreen}1)${clrReset} $(tr m1_deps)"
    echo -e "${clrGreen}2)${clrReset} $(tr m2_deploy_trap)"
    echo -e "${clrGreen}3)${clrReset} $(tr m3_install_node)"
    echo -e "${clrGreen}4)${clrReset} $(tr m4_register)"
    echo -e "${clrGreen}5)${clrReset} $(tr m5_start)"
    echo -e "${clrGreen}6)${clrReset} $(tr m6_status)"
    echo -e "${clrGreen}7)${clrReset} $(tr m7_logs)"
    echo -e "${clrGreen}8)${clrReset} $(tr m8_restart)"
    echo -e "${clrGreen}9)${clrReset} $(tr m9_remove)"
    echo -e "${clrGreen}10)${clrReset} $(tr m10_cadet)"
    echo -e "${clrGreen}11)${clrReset} $(tr m11_two)"
    echo -e "${clrGreen}12)${clrReset} $(tr m12_versions)"
    echo -e "${clrGreen}13)${clrReset} $(tr m13_update)"
    echo -e "${clrGreen}14)${clrReset} $(tr m14_versions_en)"
    echo -e "${clrGreen}15)${clrReset} $(tr m15_lang)"
    echo -e "${clrGreen}0)${clrReset} $(tr exit)"
    hr
    read -rp "> " choice
    case "${choice:-}" in
      1) install_dependencies ;;
      2) deploy_trap ;;
      3) install_node ;;
      4) register_operator ;;
      5) start_node ;;
      6) show_status ;;
      7) follow_logs ;;
      8) restart_node ;;
      9) remove_node ;;
      10) deploy_discord_cadet ;;  # optional: you can wire your existing function here if you keep it
      11) deploy_two_traps ;;
      12) check_node_version ;;
      13) update_node_safe ;;
      14) print_versions_en ;;
      15) choose_language ;;
      0) exit 0 ;;
      *) err "$(tr bad_input)" ;;
    esac
    echo -e "\n$(tr press_enter)"; read -r
  done
}

# -----------------------------
# Entrypoint
# -----------------------------
ensure_curl; ensure_jq; choose_language; auto_update; menu
