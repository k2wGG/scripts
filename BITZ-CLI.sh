#!/bin/bash

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
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  source "$HOME/.cargo/env"
  sh -c "$(curl -sSfL https://release.solana.com/v1.18.2/install)"
  echo 'export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"' >> ~/.bashrc
  source ~/.bashrc
  solana config set --url https://eclipse.helius-rpc.com
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
  echo "Установка BITZ..."
  cargo install bitz
  pause
}

function start_miner() {
  header
  read -rp "Сколько ядер использовать (например, 4): " CORES
  screen -dmS bitz bash -c "bitz collect --cores $CORES"
  echo "Майнинг запущен в screen-сессии 'bitz'."
  pause
}

function stop_miner() {
  header
  screen -XS bitz quit
  echo "Майнинг остановлен."
  pause
}

function check_account() {
  header
  bitz account
  pause
}

function claim_tokens() {
  header
  bitz claim
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
      9) echo "Выход..." && break ;;
      *) echo "Неверный выбор." && sleep 1 ;;
    esac
  done
}

show_menu
