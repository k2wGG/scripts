#!/bin/bash

# Подгружаем окружение Rust (если установлено)
[ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"

SCRIPT_NAME="BITZ-CLI"
SCRIPT_VERSION="1.1.1"
VERSIONS_FILE_URL="https://raw.githubusercontent.com/k2wGG/scripts/main/versions.txt"
SCRIPT_FILE_URL="https://raw.githubusercontent.com/k2wGG/scripts/main/BITZ-CLI.sh"

GREEN='\033[0;32m'
NC='\033[0m'

# === Фиксированный RPC (Eclipse/Helius) ===
RPC_URL="https://eclipse.helius-rpc.com"
solana config set --url $RPC_URL

# === Параметры комиссии (Compute Unit price) ===
# Сколько микролампортов платить за 1 CU
PRIORITY_FEE=100000
# Ждать ли, пока плата упадёт до MIN_FEE_TARGET?
WAIT_ON_FEE=true
# Нижний порог лампорт/подпись для отправки
MIN_FEE_TARGET=10000

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
  remote_version=$(curl -s "$VERSIONS_FILE_URL" \
                     | grep "^${SCRIPT_NAME}=" \
                     | cut -d'=' -f2)
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

pause() {
  read -rp "Нажмите Enter, чтобы продолжить..."
}

install_dependencies() {
  header
  echo "Установка зависимостей..."
  sudo apt update && sudo apt upgrade -y
  sudo apt install -y screen curl nano build-essential pkg-config \
                      libssl-dev clang jq

  # Rust / cargo
  if ! command -v cargo &>/dev/null; then
    echo "Устанавливаем Rust..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
      | sh -s -- -y
    source "$HOME/.cargo/env"
    echo 'source "$HOME/.cargo/env"' >> ~/.bashrc
  else
    source "$HOME/.cargo/env"
  fi

  # Solana CLI
  if ! command -v solana &>/dev/null; then
    echo "Устанавливаем Solana CLI..."
    sh -c "$(curl -sSfL https://release.solana.com/v1.18.2/install)"
    export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"
    echo 'export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"' \
      >> ~/.bashrc
    source ~/.bashrc
  fi

  solana config set --url $RPC_URL
  echo -e "\n✅ Зависимости установлены."
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
      pause
      return
    fi
  else
    solana-keygen new
  fi
  pause
}

show_private_key() {
  header
  echo "Приватный ключ (id.json):"
  cat "$HOME/.config/solana/id.json"
  pause
}

install_bitz() {
  header
  if ! command -v cargo &>/dev/null; then
    echo "Cargo не найден. Сначала установите Rust."
    pause
    return
  fi
  echo "Установка BITZ..."
  cargo install bitz --force
  pause
}

start_miner() {
  header
  if ! command -v bitz &>/dev/null; then
    echo "❌ 'bitz' не найден. Установите BITZ (пункт 4)."
    pause
    return
  fi

  read -rp "Сколько ядер использовать (4 из 16): " CORES
  if [[ ! "$CORES" =~ ^[0-9]+$ ]]; then
    echo "❌ Введите число."
    pause
    return
  fi

  LOG="$HOME/bitz.log"
  rm -f "$LOG"

  FFLAGS=$(build_fee_flags)
  echo "▶️ Запуск майнинга: bitz $FFLAGS collect --cores $CORES"
  screen -dmS bitz bash -c "bitz $FFLAGS collect --cores $CORES 2>&1 | tee -a '$LOG'"

  sleep 2
  if screen -list | grep -q "\.bitz"; then
    echo "✅ Майнинг запущен. Лог: $LOG"
  else
    echo "❌ Не удалось запустить. Смотрите лог: $LOG"
  fi
  pause
}

stop_miner() {
  header
  if screen -list | grep -q "\.bitz"; then
    screen -XS bitz quit
    echo "🛑 Майнинг остановлен."
  else
    echo "ℹ️ Нет активной сессии."
  fi
  pause
}

check_account() {
  header
  if ! command -v bitz &>/dev/null; then
    echo "❌ 'bitz' не найден."
  else
    bitz $(build_fee_flags) account
  fi
  pause
}

# Берём базовую плату через JSON-RPC getLatestBlockhash
get_current_fee() {
  curl -s -X POST -H "Content-Type: application/json" \
    -d '{
      "jsonrpc":"2.0",
      "id":1,
      "method":"getLatestBlockhash",
      "params":[{"commitment":"confirmed"}]
    }' \
    "$RPC_URL" \
  | jq '.result.value.feeCalculator.lamportsPerSignature'
}

# Ждём, пока базовая плата упадёт до MIN_FEE_TARGET
wait_for_low_fee() {
  echo "⏳ Ожидание платы ≤ $MIN_FEE_TARGET..."
  while true; do
    fee=$(get_current_fee)
    echo "  текущая базовая плата = $fee"
    if (( fee <= MIN_FEE_TARGET )); then
      echo "✅ Плата достигла $fee."
      break
    fi
    sleep 60
  done
}

show_fee_info() {
  header
  echo "🔍 Инфо по RPC $RPC_URL"
  echo "  Lamports per signature (базовая): $(get_current_fee)"
  echo ""
  echo "Текущие параметры:"
  echo "  PRIORITY_FEE  = $PRIORITY_FEE"
  echo "  WAIT_ON_FEE   = $WAIT_ON_FEE"
  echo "  MIN_FEE_TARGET= $MIN_FEE_TARGET"
  pause
}

claim_tokens() {
  header
  if ! command -v bitz &>/dev/null; then
    echo "❌ 'bitz' не найден."
    pause
    return
  fi

  if [[ "$WAIT_ON_FEE" == "true" ]]; then
    wait_for_low_fee
  fi

  ADDR=$(bitz account | grep Address | awk '{print $2}')
  FFLAGS=$(build_fee_flags)
  echo "▶️ Claim → $ADDR (flags: $FFLAGS)"
  bitz $FFLAGS claim --to "$ADDR" \
    || echo "❌ Ошибка при claim"
  pause
}

uninstall_node() {
  header
  echo "⚠️ Удаление всего:"
  read -rp "Подтвердите (yes/no): " yn
  if [[ "$yn" != "yes" ]]; then
    echo "Отмена."
    pause
    return
  fi

  cargo uninstall bitz 2>/dev/null
  rm -rf ~/.cargo ~/.rustup
  rm -rf ~/.local/share/solana ~/.config/solana
  sudo apt remove --purge -y screen
  sudo apt autoremove -y
  rm -f ~/bitz.log

  echo "✅ Удалено."
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
    echo "10) Удалить всё"
    echo "11) Выйти"
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
      10) uninstall_node    ;;
      11) echo "👋 Выход" && exit 0 ;;
      *) echo "❌ Неверный выбор." && sleep 1 ;;
    esac
  done
}

show_menu
