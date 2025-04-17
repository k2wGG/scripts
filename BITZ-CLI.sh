#!/bin/bash

# Подгружаем окружение Rust (если установлено)
[ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"

SCRIPT_NAME="BITZ-CLI"
SCRIPT_VERSION="1.1.0"
VERSIONS_FILE_URL="https://raw.githubusercontent.com/k2wGG/scripts/main/versions.txt"
SCRIPT_FILE_URL="https://raw.githubusercontent.com/k2wGG/scripts/main/BITZ-CLI.sh"

GREEN='\033[0;32m'
NC='\033[0m'

# ==== Настройки комиссии (Compute Unit Price) ====
# Сколько микролампортов платить за 1 CU
PRIORITY_FEE=100000
# Ожидать ли снижения платы до MIN_FEE_TARGET (true/false)
WAIT_ON_FEE=true
# Порог: если solana fees <= этого, то отправляем транзакцию
MIN_FEE_TARGET=7000
# Динамический расчёт цены (true/false)
DYNAMIC_FEE=false
# RPC для динамического расчёта (если DYNAMIC_FEE=true)
DYNAMIC_FEE_URL="https://eclipse.helius-rpc.com"

# Формируем флаги bitz для комиссии
build_fee_flags() {
  local flags="--priority-fee $PRIORITY_FEE"
  if [[ "$DYNAMIC_FEE" == "true" ]]; then
    flags="$flags --dynamic-fee --dynamic-fee-url $DYNAMIC_FEE_URL"
  fi
  echo "$flags"
}

show_logo() {
  cat <<'EOF'
 _   _           _  _____      
| \ | |         | ||____ |     
|  \| | ___   __| |    / /_ __ 
| . ` |/ _ \ / _` |    \ \ '__|
| |\  | (_) | (_| |.___/ / |   
\_| \_/\___/ \__,_|\____/|_|   
                               
BITZ CLI Node Manager — скрипт для автоматики @Nod3r 
EOF
}

header() {
  clear
  echo -e "${GREEN}"
  show_logo
  echo -e "${NC}"
  echo -e "Версия скрипта: ${SCRIPT_VERSION}"

  remote_version=$(curl -s "$VERSIONS_FILE_URL" | grep "^${SCRIPT_NAME}=" | cut -d "=" -f2)
  if [[ -n "$remote_version" ]]; then
    if [[ "$remote_version" != "$SCRIPT_VERSION" ]]; then
      echo -e "⚠️ Доступна новая версия: ${remote_version}"
      echo -e "📥 Обновить: wget -O BITZ-CLI.sh $SCRIPT_FILE_URL && chmod +x BITZ-CLI.sh"
    else
      echo -e "✅ Установлена последняя версия."
    fi
  else
    echo -e "⚠️ Не удалось проверить обновления."
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
  sudo apt install screen curl nano build-essential pkg-config libssl-dev clang jq -y

  if ! command -v cargo &> /dev/null; then
    echo "Устанавливаем Rust..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
    echo 'source "$HOME/.cargo/env"' >> ~/.bashrc
  else
    source "$HOME/.cargo/env"
  fi

  if ! command -v solana &> /dev/null; then
    echo "Устанавливаем Solana CLI..."
    sh -c "$(curl -sSfL https://release.solana.com/v1.18.2/install)"
    export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"
    echo 'export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"' >> ~/.bashrc
    source ~/.bashrc
  else
    export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"
  fi

  solana config set --url $DYNAMIC_FEE_URL
  echo -e "\n✅ Все зависимости установлены!"
  pause
}

create_wallet() {
  header
  if [ -f "$HOME/.config/solana/id.json" ]; then
    echo "⚠️ Кошелёк уже существует: $HOME/.config/solana/id.json"
    read -rp "Перезаписать? (yes/no): " confirm
    if [[ "$confirm" == "yes" ]]; then
      solana-keygen new --force
    else
      echo "❌ Создание кошелька отменено."
      pause; return
    fi
  else
    solana-keygen new
  fi
  pause
}

show_private_key() {
  header
  echo "Приватный ключ (копируй массив):"
  cat ~/.config/solana/id.json
  pause
}

install_bitz() {
  header
  if ! command -v cargo &> /dev/null; then
    echo "❌ Cargo не найден. Убедись, что Rust установлен (пункт 1)."
    pause; return
  fi
  echo "Установка BITZ..."
  cargo install bitz --force
  pause
}

start_miner() {
  header
  if ! command -v bitz &> /dev/null; then
    echo "❌ 'bitz' не найден. Сначала установите BITZ (пункт 4)."
    pause; return
  fi
  read -rp "Сколько ядер использовать (например, 4): " CORES
  [[ ! "$CORES" =~ ^[0-9]+$ ]] && echo "❌ Неверный ввод." && pause && return

  LOG_PATH="$HOME/bitz.log"
  rm -f "$LOG_PATH"

  FEE_FLAGS=$(build_fee_flags)
  echo "▶️ Запуск майнинга в screen‑сессии 'bitz' с флагами: $FEE_FLAGS"
  screen -dmS bitz bash -c "bitz $FEE_FLAGS collect --cores $CORES 2>&1 | tee -a '$LOG_PATH'"

  sleep 2
  if screen -list | grep -q "\.bitz"; then
    echo "✅ Майнинг запущен. Лог: $LOG_PATH"
  else
    echo "❌ Не удалось запустить майнинг. Смотрите лог: $LOG_PATH"
  fi
  pause
}

stop_miner() {
  header
  if screen -list | grep -q "\.bitz"; then
    screen -XS bitz quit
    echo "🛑 Майнинг остановлен."
  else
    echo "ℹ️ Маиннинг не запущен."
  fi
  pause
}

check_account() {
  header
  if ! command -v bitz &> /dev/null; then
    echo "❌ 'bitz' не найден."
  else
    bitz $(build_fee_flags) account
  fi
  pause
}

wait_for_low_fee() {
  header
  echo "⏳ Ожидание снижения платы до $MIN_FEE_TARGET лампорт/подпись..."
  while true; do
    # Парсим lamports per signature из solana fees
    fee=$(solana fees --url $DYNAMIC_FEE_URL | grep "Lamports per signature" | awk '{print $4}')
    echo "Текущая плата: $fee, цель: $MIN_FEE_TARGET"
    if (( fee <= MIN_FEE_TARGET )); then
      echo "✅ Плата упала до допустимого уровня."
      break
    fi
    sleep 300
  done
}

show_fee_info() {
  header
  echo "📊 Актуальная комиссия Solana (solana fees):"
  solana fees --url $DYNAMIC_FEE_URL       # :contentReference[oaicite:0]{index=0}
  echo ""
  echo "Текущие настройки скрипта:"
  echo "  PRIORITY_FEE        = $PRIORITY_FEE"
  echo "  WAIT_ON_FEE         = $WAIT_ON_FEE"
  echo "  MIN_FEE_TARGET      = $MIN_FEE_TARGET"
  echo "  DYNAMIC_FEE         = $DYNAMIC_FEE"
  echo "  DYNAMIC_FEE_URL     = $DYNAMIC_FEE_URL"
  pause
}

set_fee_settings() {
  header
  echo "🔧 Конфигурация комиссии"
  read -rp "PRIORITY_FEE (микроламп/CU) [$PRIORITY_FEE]: " x && [[ $x ]] && PRIORITY_FEE=$x
  read -rp "WAIT_ON_FEE (true/false) [$WAIT_ON_FEE]: " x && [[ $x ]] && WAIT_ON_FEE=$x
  read -rp "MIN_FEE_TARGET (лампорт/подпись) [$MIN_FEE_TARGET]: " x && [[ $x ]] && MIN_FEE_TARGET=$x
  read -rp "DYNAMIC_FEE (true/false) [$DYNAMIC_FEE]: " x && [[ $x ]] && DYNAMIC_FEE=$x
  read -rp "DYNAMIC_FEE_URL [$DYNAMIC_FEE_URL]: " x && [[ $x ]] && DYNAMIC_FEE_URL=$x
  echo "✅ Настройки сохранены."
  pause
}

claim_tokens() {
  header
  if ! command -v bitz &> /dev/null; then
    echo "❌ 'bitz' не найден."
    pause; return
  fi

  [[ "$WAIT_ON_FEE" == "true" ]] && wait_for_low_fee

  ADDR=$(bitz account | grep Address | awk '{print $2}')
  echo "▶️ Claim → $ADDR с флагами: $(build_fee_flags)"
  bitz $(build_fee_flags) claim --to "$ADDR" \
    || echo "❌ Ошибка при claim"
  pause
}

uninstall_node() {
  header
  echo "⚠️ Удаление BITZ, Rust, Solana, screen..."
  read -rp "Удалить всё? (yes/no): " confirm
  [[ "$confirm" != "yes" ]] && echo "❌ Отменено." && pause && return

  cargo uninstall bitz 2>/dev/null
  rm -rf ~/.cargo ~/.rustup
  rm -rf ~/.local/share/solana ~/.config/solana
  sudo apt remove --purge screen -y
  sudo apt autoremove -y
  rm -f ~/bitz.log

  echo "✅ Всё удалено."
  pause
}

show_menu() {
  while true; do
    header
    echo "1. Установить зависимости"
    echo "2. Создать кошелёк"
    echo "3. Показать приватный ключ"
    echo "4. Установить BITZ"
    echo "5. Запустить майнинг"
    echo "6. Остановить майнинг"
    echo "7. Проверить баланс"
    echo "8. Вывести токены (claim)"
    echo "9. Настройки комиссии"
    echo "10. Показать текущую комиссию"
    echo "11. Удалить всё"
    echo "12. Выйти"
    read -rp "👉 Введите номер: " choice

    case $choice in
      1) install_dependencies ;;
      2) create_wallet       ;;
      3) show_private_key    ;;
      4) install_bitz        ;;
      5) start_miner         ;;
      6) stop_miner          ;;
      7) check_account       ;;
      8) claim_tokens        ;;
      9) set_fee_settings    ;;
      10) show_fee_info      ;;
      11) uninstall_node     ;;
      12) echo "👋 Выход..." && break ;;
      *) echo "❌ Неверный выбор." && sleep 1 ;;
    esac
  done
}

show_menu
