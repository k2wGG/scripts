#!/bin/bash

# Подгружаем окружение Rust (если установлено)
[ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"

SCRIPT_NAME="BITZ-CLI"
SCRIPT_VERSION="1.1.3"
VERSIONS_FILE_URL="https://raw.githubusercontent.com/k2wGG/scripts/main/versions.txt"
SCRIPT_FILE_URL="https://raw.githubusercontent.com/k2wGG/scripts/main/BITZ-CLI.sh"

GREEN='\033[0;32m'
NC='\033[0m'

# === Фиксированный RPC (Eclipse/Helius) ===
RPC_URL="https://eclipse.helius-rpc.com"
solana config set --url "$RPC_URL"

# === Параметры комиссии (Compute Unit price) ===
PRIORITY_FEE=100000      # микролампортов за 1 CU
WAIT_ON_FEE=true         # ждать ли, пока базовая плата упадёт до MIN_FEE_TARGET?
MIN_FEE_TARGET=10000     # лампорт/подпись

# Собираем флаги для bitz
build_fee_flags() {
  echo "--priority-fee $PRIORITY_FEE"
}

show_logo() {
  cat <<'EOF'
 _   _           _  _____      
| \ | |         | ||____ |     
|  \| | ___   __| |    / /_ __ 
| . ` |/ _ \ / _` |    \ \ '__|
| |\  | (_) | (_| |.___/ / |   
\_| \_/\___/ \__,_|\____/|_|   
                               
BITZ CLI Node Manager — автоматизация майнинга
EOF
}

header() {
  clear
  echo -e "${GREEN}"
  show_logo
  echo -e "${NC}"
  echo "Версия скрипта: ${SCRIPT_VERSION}"
  echo "RPC: ${RPC_URL}"
  echo "Комиссии: PRIORITY_FEE=$PRIORITY_FEE, WAIT_ON_FEE=$WAIT_ON_FEE, MIN_FEE_TARGET=$MIN_FEE_TARGET"
  remote_version=$(curl -s "$VERSIONS_FILE_URL" | grep "^${SCRIPT_NAME}=" | cut -d'=' -f2)
  if [[ -n "$remote_version" ]]; then
    if [[ "$remote_version" != "$SCRIPT_VERSION" ]]; then
      echo "⚠️ Доступна новая версия: ${remote_version}"
      echo "  Обновить: wget -O BITZ-CLI.sh $SCRIPT_FILE_URL && chmod +x BITZ-CLI.sh"
    else
      echo "✅ Установлена последняя версия."
    fi
  else
    echo "⚠️ Не удалось проверить обновления."
  fi
  echo ""
}

pause() { read -rp "Нажмите Enter, чтобы продолжить..."; }

install_dependencies() {
  header
  echo "Установка зависимостей..."
  sudo apt update && sudo apt upgrade -y
  sudo apt install -y screen curl nano build-essential pkg-config libssl-dev clang jq

  if ! command -v cargo &>/dev/null; then
    echo "Устанавливаем Rust..."
    curl https://sh.rustup.rs -sSf | sh -s -- -y
    source "$HOME/.cargo/env"
    echo 'source "$HOME/.cargo/env"' >> ~/.bashrc
  fi

  if ! command -v solana &>/dev/null; then
    echo "Устанавливаем Solana CLI..."
    sh -c "$(curl -sSfL https://release.solana.com/v1.18.2/install)"
    echo 'export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"' >> ~/.bashrc
    source ~/.bashrc
  fi

  solana config set --url "$RPC_URL"
  echo "✅ Зависимости установлены."
  pause
}

create_wallet() {
  header
  if [[ -f "$HOME/.config/solana/id.json" ]]; then
    echo "⚠️ Кошелёк уже существует."
    read -rp "Перезаписать? (yes/no): " yn
    if [[ "$yn" == "yes" ]]; then
      solana-keygen new --force
    else
      echo "Отмена."
      pause; return
    fi
  else
    solana-keygen new
  fi
  pause
}

show_private_key() {
  header
  echo "Приватный ключ:"
  cat "$HOME/.config/solana/id.json"
  pause
}

install_bitz() {
  header
  if ! command -v cargo &>/dev/null; then
    echo "Cargo не найден."
    pause; return
  fi
  echo "Установка BITZ..."
  cargo install bitz --force
  pause
}

start_miner() {
  header
  if ! command -v bitz &>/dev/null; then
    echo "❌ 'bitz' не найден."
    pause; return
  fi
  read -rp "Ядер для майнинга (1-16): " CORES
  [[ ! "$CORES" =~ ^[0-9]+$ ]] && echo "Нужно число!" && pause && return

  LOG="$HOME/bitz.log"; rm -f "$LOG"
  FFLAGS=$(build_fee_flags)
  screen -dmS bitz bash -c "bitz $FFLAGS collect --cores $CORES 2>&1 | tee -a '$LOG'"
  sleep 2
  if screen -list | grep -q "\.bitz"; then
    echo "✅ Майнинг запущен (лог: $LOG)"
  else
    echo "❌ Ошибка запуска (см. $LOG)"
  fi
  pause
}

stop_miner() {
  header
  if screen -list | grep -q "\.bitz"; then
    screen -XS bitz quit && echo "🛑 Майнинг остановлен."
  else
    echo "ℹ️ Нет активной сессии."
  fi
  pause
}

check_account() {
  header
  bitz $(build_fee_flags) account
  pause
}

# Получение базовой платы через JSON-RPC
get_current_fee() {
  local resp blockhash resp2
  resp=$(curl -s -X POST -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","id":1,"method":"getLatestBlockhash","params":[{"commitment":"confirmed"}]}' \
    "$RPC_URL")
  blockhash=$(echo "$resp" | jq -r '.result.value.blockhash')
  resp2=$(curl -s -X POST -H "Content-Type: application/json" \
    -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"getFeeCalculatorForBlockhash\",\"params\":[\"$blockhash\",{\"commitment\":\"confirmed\"}]}" \
    "$RPC_URL")
  echo "$resp2" | jq '.result.value.feeCalculator.lamportsPerSignature'
}

wait_for_low_fee() {
  echo "⏳ Ожидаем платы <= $MIN_FEE_TARGET lamports..."
  while true; do
    fee=$(get_current_fee)
    echo "  текущая плата = $fee"
    (( fee <= MIN_FEE_TARGET )) && { echo "✅ OK: $fee"; break; }
    sleep 60
  done
}

show_fee_info() {
  header
  echo "🔍 Инфо по RPC $RPC_URL"
  echo "  Lamports per signature: $(get_current_fee)"
  pause
}

set_fee_settings() {
  header
  echo "🔧 Настройка комиссии"
  read -rp "PRIORITY_FEE [$PRIORITY_FEE]: " x && [[ $x ]] && PRIORITY_FEE=$x
  read -rp "WAIT_ON_FEE (true/false) [$WAIT_ON_FEE]: " x && [[ $x ]] && WAIT_ON_FEE=$x
  read -rp "MIN_FEE_TARGET [$MIN_FEE_TARGET]: " x && [[ $x ]] && MIN_FEE_TARGET=$x
  echo "✅ Сохранено."
  pause
}

claim_tokens() {
  header
  [[ "$WAIT_ON_FEE" == "true" ]] && wait_for_low_fee
  addr=$(bitz account | awk '/Address/ {print $2}')
  FFLAGS=$(build_fee_flags)
  echo "▶️ Claim → $addr ($FFLAGS)"
  bitz $FFLAGS claim --to "$addr" || echo "❌ Ошибка claim"
  pause
}

uninstall_node() {
  header
  echo "⚠️ Удаление всего..."
  read -rp "Подтвердите (yes/no): " yn
  [[ "$yn" != "yes" ]] && echo "Отмена." && pause && return
  cargo uninstall bitz 2>/dev/null
  rm -rf ~/.cargo ~/.rustup ~/.local/share/solana ~/.config/solana ~/bitz.log
  sudo apt remove --purge -y screen jq clang pkg-config libssl-dev
  sudo apt autoremove -y
  echo "✅ Всё удалено."
  pause
}

show_menu() {
  while true; do
    header
    echo "1) Установить зависимости"
    echo "2) Создать кошелёк"
    echo "3) Показать приватный ключ"
    echo "4) Установить BITZ"
    echo "5) Запустить майнинг"
    echo "6) Остановить майнинг"
    echo "7) Проверить баланс"
    echo "8) Вывести токены (claim)"
    echo "9) Показать комиссию"
    echo "10) Настройки комиссии"
    echo "11) Удалить всё"
    echo "12) Выйти"
    read -rp "👉 Введите номер: " choice

    case $choice in
      1) install_dependencies ;;
      2) create_wallet      ;;
      3) show_private_key   ;;
      4) install_bitz       ;;
      5) start_miner        ;;
      6) stop_miner         ;;
      7) check_account      ;;
      8) claim_tokens       ;;
      9) show_fee_info      ;;
      10) set_fee_settings  ;;
      11) uninstall_node    ;;
      12) echo "👋 Выход" && exit 0 ;;
      *) echo "❌ Неверный выбор." && sleep 1 ;;
    esac
  done
}

show_menu
