#!/bin/bash

# Подгружаем окружение Rust (если установлено)
[ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"

SCRIPT_NAME="BITZ-CLI"               # Имя скрипта (должно совпадать со строкой в versions.txt)
SCRIPT_VERSION="1.0.0"            # Текущая локальная версия
VERSIONS_FILE_URL="https://raw.githubusercontent.com/k2wGG/scripts/main/versions.txt"
SCRIPT_FILE_URL="https://raw.githubusercontent.com/k2wGG/scripts/main/BITZ-CLI.sh"


# Цвета
GREEN='\033[0;32m'
NC='\033[0m'

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

function header() {
  clear
  echo -e "${GREEN}"
  show_logo
  echo -e "${NC}"
}

function pause() {
  read -rp "Нажмите Enter, чтобы продолжить..."
}

function install_dependencies() {
  header
  echo "Установка зависимостей..."
  sudo apt update && sudo apt upgrade -y
  sudo apt install screen curl nano build-essential pkg-config libssl-dev clang -y

  # Установка Rust
  if ! command -v cargo &> /dev/null; then
    echo "Устанавливаем Rust..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
    echo 'source "$HOME/.cargo/env"' >> ~/.bashrc
  else
    source "$HOME/.cargo/env"
  fi

  # Установка Solana CLI
  if ! command -v solana &> /dev/null; then
    echo "Устанавливаем Solana CLI..."
    sh -c "$(curl -sSfL https://release.solana.com/v1.18.2/install)"
    export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"
    echo 'export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"' >> ~/.bashrc
    source ~/.bashrc
  else
    export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"
  fi

  # Настройка RPC
  solana config set --url https://eclipse.helius-rpc.com

  echo -e "\n✅ Все зависимости установлены!"
  pause
}

function create_wallet() {
  header
  solana-keygen new
  pause
}

function show_private_key() {
  header
  echo "Приватный ключ (копируй массив):"
  cat ~/.config/solana/id.json
  pause
}

function install_bitz() {
  header
  if ! command -v cargo &> /dev/null; then
    echo "❌ Cargo не найден. Убедись, что Rust установлен (пункт 1)."
    pause
    return
  fi

  echo "Установка BITZ..."
  cargo install bitz --force
  pause
}

function start_miner() {
  header
  if ! command -v bitz &> /dev/null; then
    echo "❌ Команда 'bitz' не найдена. Сначала установите BITZ (пункт 4)."
    pause
    return
  fi

  read -rp "Сколько ядер использовать (например, 4): " CORES

  # Удалим предыдущий лог
  rm -f ~/bitz.log

  # Запускаем miner с логированием
  screen -dmS bitz bash -c "bitz collect --cores $CORES | tee -a ~/bitz.log"

  sleep 2
  screen -ls | grep -q bitz
  if [[ $? -eq 0 ]]; then
    echo "✅ Майнинг запущен в screen-сессии 'bitz'."
    echo "📄 Лог: ~/bitz.log"
  else
    echo "⚠️ Что-то пошло не так — screen не запустился."
    echo "Попробуй вручную: screen -S bitz, затем bitz collect"
  fi
  pause
}

function stop_miner() {
  header
  screen -XS bitz quit 2>/dev/null
  echo "🛑 Майнинг остановлен (если был активен)."
  pause
}

function check_account() {
  header
  if command -v bitz &> /dev/null; then
    bitz account
  else
    echo "Команда 'bitz' не найдена."
  fi
  pause
}

function claim_tokens() {
  header
  if command -v bitz &> /dev/null; then
    bitz claim
  else
    echo "Команда 'bitz' не найдена."
  fi
  pause
}

function show_menu() {
  while true; do
    header
    echo "Выберите действие:"
    echo "1. Установить зависимости"
    echo "2. Создать CLI-кошелёк"
    echo "3. Показать приватный ключ"
    echo "4. Установить BITZ"
    echo "5. Запустить майнинг"
    echo "6. Остановить майнинг"
    echo "7. Проверить баланс"
    echo "8. Вывести токены"
    echo "9. Выйти"
    read -rp "👉 Введите номер: " choice

    case $choice in
      1) install_dependencies ;;
      2) create_wallet ;;
      3) show_private_key ;;
      4) install_bitz ;;
      5) start_miner ;;
      6) stop_miner ;;
      7) check_account ;;
      8) claim_tokens ;;
      9) echo "👋 Выход..." && break ;;
      *) echo "Неверный выбор." && sleep 1 ;;
    esac
  done
}

show_menu
