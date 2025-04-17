#!/bin/bash

# Подгружаем Rust, если установлен
[ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"

SCRIPT_NAME="BITZ-CLI"
SCRIPT_VERSION="1.2.0"
VERSIONS_FILE_URL="https://raw.githubusercontent.com/k2wGG/scripts/main/versions.txt"
SCRIPT_FILE_URL="https://raw.githubusercontent.com/k2wGG/scripts/main/BITZ-CLI.sh"

GREEN='\033[0;32m'
NC='\033[0m'

# === Фиксированный RPC (Eclipse/Helius) ===
RPC_URL="https://eclipse.helius-rpc.com"
solana config set --url "$RPC_URL"

# === Параметры комиссии (Compute Unit price) ===
PRIORITY_FEE=100000      # микролампортов за 1 CU
WAIT_ON_FEE=true         # ждать ли снижения платы перед claim
MIN_FEE_TARGET=10000     # лампорт/подпись, порог для wait

# Собираем флаги для bitz
build_fee_flags(){
  echo "--priority-fee $PRIORITY_FEE"
}

show_logo(){
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

header(){
  clear
  echo -e "${GREEN}"
  show_logo
  echo -e "${NC}"
  echo "Версия скрипта: $SCRIPT_VERSION"
  echo "RPC: $RPC_URL"
  rv=$(curl -s "$VERSIONS_FILE_URL" | grep "^${SCRIPT_NAME}=" | cut -d'=' -f2)
  if [[ -n $rv ]]; then
    if [[ $rv != $SCRIPT_VERSION ]]; then
      echo "⚠️ Доступна новая версия: $rv"
      echo "  wget -O BITZ-CLI.sh $SCRIPT_FILE_URL && chmod +x BITZ-CLI.sh"
    else
      echo "✅ Последняя версия."
    fi
  else
    echo "⚠️ Не удалось проверить обновления."
  fi
  echo
}

pause(){ read -rp "Нажмите Enter..."; }

# 1) Установка зависимостей
install_dependencies(){
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

# 2) Создание/перезапись кошелька
create_wallet(){
  header
  if [[ -f "$HOME/.config/solana/id.json" ]]; then
    read -rp "Перезаписать существующий кошелёк? (yes/no): " yn
    [[ $yn != yes ]] && { echo "Отмена."; pause; return; }
    solana-keygen new --force
  else
    solana-keygen new
  fi
  pause
}

# 3) Показать приватный ключ
show_private_key(){
  header
  echo "Приватный ключ:"
  cat "$HOME/.config/solana/id.json"
  pause
}

# 4) Установить BITZ
install_bitz(){
  header
  if ! command -v cargo &>/dev/null; then echo "Cargo не найден."; pause; return; fi
  echo "Установка BITZ..."
  cargo install bitz --force
  pause
}

# 5) Запустить майнинг
start_miner(){
  header
  if ! command -v bitz &>/dev/null; then echo "'bitz' не найден."; pause; return; fi
  read -rp "Ядер для майнинга (1-16): " CORES
  [[ ! $CORES =~ ^[0-9]+$ ]] && { echo "Нужно число!"; pause; return; }
  LOG=~/bitz.log; rm -f "$LOG"
  FFLAGS=$(build_fee_flags)
  screen -dmS bitz bash -c "bitz $FFLAGS collect --cores $CORES 2>&1 | tee -a '$LOG'"
  sleep 2
  screen -list | grep -q "\.bitz" && echo "✅ Майнинг запущен (лог: $LOG)" || echo "❌ Ошибка запуска (см. $LOG)"
  pause
}

# 6) Остановить майнинг
stop_miner(){
  header
  screen -list | grep -q "\.bitz" && screen -XS bitz quit && echo "🛑 Майнинг остановлен." || echo "ℹ️ Майнер не запущен."
  pause
}

# 7) Проверить баланс
check_account(){
  header
  bitz $(build_fee_flags) account
  pause
}

# Получение базовой платы через Helius (может вернуть empty)
get_current_fee(){
  hb=$(curl -s -X POST -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","id":1,"method":"getLatestBlockhash","params":[{"commitment":"confirmed"}]}' \
    "$RPC_URL" | jq -r '.result.value.blockhash // empty')
  [[ -z $hb ]] && return
  curl -s -X POST -H "Content-Type: application/json" \
    -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"getFeeCalculatorForBlockhash\",\"params\":[\"$hb\",{\"commitment\":\"confirmed\"}]}" \
    "$RPC_URL" | jq -r '.result.value.feeCalculator.lamportsPerSignature // empty'
}

# Фоллбэк: публичный mainnet RPC
get_mainnet_fee(){
  solana fees --url https://api.mainnet-beta.solana.com \
    | awk '/Lamports per signature/ {print $4}'
}

# 8) Ожидание снижения платы до порога
wait_for_low_fee(){
  echo "⏳ Ожидаем плату <= $MIN_FEE_TARGET lamports..."
  while :; do
    fee=$(get_current_fee)
    (( ! fee )) && fee=$(get_mainnet_fee)
    echo "  плата = $fee"
    (( fee <= MIN_FEE_TARGET )) && { echo "✅ OK: $fee"; break; }
    sleep 60
  done
}

# 9) Показать комиссию
show_fee_info(){
  header
  fee=$(get_current_fee)
  if [[ -z $fee ]]; then
    fee=$(get_mainnet_fee)
    echo "Lamports per signature (fallback): $fee"
  else
    echo "Lamports per signature (helius): $fee"
  fi
  pause
}

# 10) Настройка комиссии
set_fee_settings(){
  header
  read -rp "PRIORITY_FEE (микроламп/CU) [$PRIORITY_FEE]: " x && [[ $x ]] && PRIORITY_FEE=$x
  read -rp "WAIT_ON_FEE (true/false) [$WAIT_ON_FEE]: " x && [[ $x ]] && WAIT_ON_FEE=$x
  read -rp "MIN_FEE_TARGET (lamports/signature) [$MIN_FEE_TARGET]: " x && [[ $x ]] && MIN_FEE_TARGET=$x
  echo "✅ Новые настройки сохранены."
  pause
}

# 11) Вывести токены (claim)
claim_tokens(){
  header
  [[ $WAIT_ON_FEE == true ]] && wait_for_low_fee
  addr=$(bitz account | awk '/Address/ {print $2}')
  FFLAGS=$(build_fee_flags)
  echo "▶️ Claim → $addr ($FFLAGS)"
  bitz $FFLAGS claim --to "$addr" || echo "❌ Ошибка при claim"
  pause
}

# 12) Удалить всё
uninstall_node(){
  header
  read -rp "Удалить всё? (yes/no): " yn
  [[ $yn != yes ]] && { echo "Отмена."; pause; return; }
  cargo uninstall bitz 2>/dev/null
  rm -rf ~/.cargo ~/.rustup ~/.local/share/solana ~/.config/solana ~/bitz.log
  sudo apt remove --purge -y screen jq clang pkg-config libssl-dev
  sudo apt autoremove -y
  echo "✅ Всё удалено."
  pause
}

# Главное меню
show_menu(){
  while :; do
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
    read -rp "👉 Выбор: " c
    case $c in
      1) install_dependencies   ;;
      2) create_wallet         ;;
      3) show_private_key      ;;
      4) install_bitz          ;;
      5) start_miner           ;;
      6) stop_miner            ;;
      7) check_account         ;;
      8) claim_tokens          ;;
      9) show_fee_info         ;;
      10) set_fee_settings     ;;
      11) uninstall_node       ;;
      12) exit 0               ;;
      *) echo "❌ Неверный выбор." && sleep 1 ;;
    esac
  done
}

show_menu
