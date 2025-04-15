#!/bin/bash

# Подгружаем окружение Rust (если установлено)
[ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"

SCRIPT_NAME="BITZ-CLI"
SCRIPT_VERSION="1.0.0"
VERSIONS_FILE_URL="https://raw.githubusercontent.com/k2wGG/scripts/main/versions.txt"
SCRIPT_FILE_URL="https://raw.githubusercontent.com/k2wGG/scripts/main/BITZ-CLI.sh"

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

function pause() {
  read -rp "Нажмите Enter, чтобы продолжить..."
}

function install_dependencies() {
  header
  echo "Установка зависимостей..."
  sudo apt update && sudo apt upgrade -y
  sudo apt install screen curl nano build-essential pkg-config libssl-dev clang -y

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

  solana config set --url https://eclipse.helius-rpc.com
  echo -e "\n✅ Все зависимости установлены!"
  pause
}

function create_wallet() {
  header
  if [ -f "$HOME/.config/solana/id.json" ]; then
    echo "⚠️ Кошелёк уже существует: $HOME/.config/solana/id.json"
    read -rp "Перезаписать? (yes/no): " confirm
    if [[ "$confirm" == "yes" ]]; then
      solana-keygen new --force
    else
      echo "❌ Создание кошелька отменено."
      pause
      return
    fi
  else
    solana-keygen new
  fi
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
  if ! [[ "$CORES" =~ ^[0-9]+$ ]]; then
    echo "❌ Введите целое число (например, 4)."
    pause
    return
  fi

  LOG_PATH="$HOME/bitz.log"
  rm -f "$LOG_PATH"

  echo "▶️ Запуск майнинга в screen-сессии 'bitz'..."
  screen -dmS bitz bash -c "bitz collect --cores $CORES 2>&1 | tee -a '$LOG_PATH'"

  sleep 2

  if screen -list | grep -q "\.bitz"; then
    echo "✅ Майнинг запущен."
    echo "📄 Лог: $LOG_PATH"
  else
    echo "❌ Screen-сессия 'bitz' не найдена. Возможные причины:"
    echo "   • Команда 'bitz collect' завершилась с ошибкой"
    echo "   • Ошибка в конфигурации RPC или кошельке"
    echo "   • Не хватает зависимостей или сети"
    echo "📄 Проверь лог: $LOG_PATH"
  fi

  pause
}

function stop_miner() {
  header
  if screen -list | grep -q "\.bitz"; then
    screen -XS bitz quit
    echo "🛑 Майнинг остановлен."
  else
    echo "ℹ️ Нет активной screen-сессии 'bitz'. Майнинг уже остановлен или не запускался."
  fi
  pause
}

function check_account() {
  header
  command -v bitz &> /dev/null && bitz account || echo "'bitz' не найден."
  pause
}

function claim_tokens() {
  header
  command -v bitz &> /dev/null && bitz claim || echo "'bitz' не найден."
  pause
}

function uninstall_node() {
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

function show_menu() {
  while true; do
    header
    echo "1. Установить зависимости"
    echo "2. Создать CLI-кошелёк"
    echo "3. Показать приватный ключ"
    echo "4. Установить BITZ"
    echo "5. Запустить майнинг"
    echo "6. Остановить майнинг"
    echo "7. Проверить баланс"
    echo "8. Вывести токены"
    echo "9. Выйти"
    echo "10. 🔧 Удалить всё (ноду, Rust, Solana, screen)"
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
     10) uninstall_node ;;
      *) echo "❌ Неверный выбор." && sleep 1 ;;
    esac
  done
}

show_menu
