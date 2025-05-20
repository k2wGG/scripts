#!/bin/bash

SCRIPT_NAME="sahara"
SCRIPT_VERSION="1.2.0"
VERSIONS_FILE_URL="https://raw.githubusercontent.com/k2wGG/scripts/main/versions.txt"
SCRIPT_FILE_URL="https://raw.githubusercontent.com/k2wGG/scripts/main/Sahara.sh"
REPO_URL="https://github.com/SaharaLabsAI/setup-testnet-node.git"
NODE_DIR="sahara-testnet-node"
CONFIG_DIR="$NODE_DIR/chain-data/config"
APP_TOML="$CONFIG_DIR/app.toml"
GENESIS_JSON="$CONFIG_DIR/genesis.json"

show_logo() {
cat <<'EOF'
 _   _           _  _____      
| \ | |         | ||____ |     
|  \| | ___   __| |    / /_ __ 
| . ` |/ _ \ / _` |    \ \ '__|
| |\  | (_) | (_| |.___/ / |   
\_| \_/\___/ \__,_|\____/|_|   
Sahara AI Testnet — скрипт для автоматики @Nod3r
EOF
}

log() { echo -e "\e[36m[$(date '+%H:%M:%S')] $1\e[0m"; }
error() { echo -e "\e[31m[ERROR] $1\e[0m" >&2; }
pause() { read -n1 -r -p "Нажмите любую клавишу для продолжения..." key; echo; }

check_update() {
    log "Проверяем наличие обновлений скрипта..."
    remote_version=$(curl -fsSL "$VERSIONS_FILE_URL" | grep "^$SCRIPT_NAME=" | cut -d'=' -f2)
    if [[ -z "$remote_version" ]]; then
        error "Не удалось получить удалённую версию. Пропускаю проверку."
        return
    fi
    log "Текущая версия скрипта: $SCRIPT_VERSION | Последняя версия: $remote_version"
    if [[ "$remote_version" != "$SCRIPT_VERSION" ]]; then
        echo -e "\e[33mОбнаружено обновление скрипта до $remote_version. Обновляем...\e[0m"
        curl -fsSL "$SCRIPT_FILE_URL" -o $0
        chmod +x $0
        echo "Скрипт обновлен. Запустите его снова!"
        exit 0
    else
        log "Вы используете последнюю версию скрипта."
    fi
}

install_jq() {
    if ! command -v jq &>/dev/null; then
        log "Устанавливаю jq..."
        sudo apt-get update && sudo apt-get install -y jq || { error "Не удалось установить jq!"; exit 1; }
    fi
}

install_docker() {
    if command -v docker &>/dev/null; then
        log "Docker уже установлен."
    else
        log "Устанавливаю Docker..."
        curl -fsSL https://get.docker.com | sh
        sudo systemctl enable docker --now
        sudo usermod -aG docker "$USER"
        log "Docker успешно установлен и запущен."
    fi
}

install_docker_compose() {
    if command -v docker-compose &>/dev/null || docker compose version &>/dev/null; then
        log "Docker Compose уже установлен."
    else
        log "Устанавливаю Docker Compose..."
        DOCKER_COMPOSE_VERSION="v2.20.2"
        sudo curl -L "https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_VERSION/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        log "Docker Compose установлен."
    fi
}

clone_repo() {
    if [ -d "$NODE_DIR" ]; then
        log "Репозиторий уже клонирован."
    else
        log "Клонирую репозиторий Sahara Testnet Node..."
        git clone "$REPO_URL" "$NODE_DIR"
    fi
}

get_latest_state_sync() {
    local RPC_URL="${1:-https://testnet-cos-rpc1.saharalabs.ai}"
    local latest_height=$(curl -s "$RPC_URL/status" | jq -r .result.sync_info.latest_block_height)
    [[ "$latest_height" =~ ^[0-9]+$ ]] || { error "Не удалось получить последний блок с RPC."; return 1; }
    local trust_height=$(( (latest_height / 1000) * 1000 ))
    local trust_hash=$(curl -s "$RPC_URL/commit?height=$trust_height" | jq -r .result.signed_header.commit.block_id.hash)
    [[ $trust_hash =~ ^[A-F0-9]{64}$ ]] || { error "Не удалось получить hash блока на высоте $trust_height."; return 1; }
    echo "$trust_height" "$trust_hash"
}

config_state_sync() {
    install_jq
    log "=== Настройка State Sync ==="
    cd "$CONFIG_DIR" || { error "Не удалось найти config директорию!"; return 1; }
    read -p "Автоматически получить актуальные trust_height/trust_hash? [Y/n]: " auto
    if [[ "$auto" =~ ^[Nn]$ ]]; then
        read -p "Введите trust_height (например, 100000): " trust_height
        read -p "Введите trust_hash (hash блока на trust_height): " trust_hash
    else
        read -p "RPC endpoint (enter для дефолта): " rpc_custom
        result=($(get_latest_state_sync "$rpc_custom"))
        trust_height="${result[0]}"
        trust_hash="${result[1]}"
        log "Автоматически выбран trust_height: $trust_height"
        log "Автоматически выбран trust_hash: $trust_hash"
    fi
    sed -i "s/^trust_height *=.*/trust_height = $trust_height/" config.toml
    sed -i "s/^trust_hash *=.*/trust_hash = \"$trust_hash\"/" config.toml
    log "State Sync успешно настроен!"
    cd ../../..
}

config_moniker() {
    log "=== Настройка имени ноды ==="
    cd "$CONFIG_DIR" || { error "Не удалось найти config директорию!"; return 1; }
    read -p "Введите moniker (имя вашей ноды): " moniker
    sed -i "s/^moniker *=.*/moniker = \"$moniker\"/" config.toml
    log "Moniker установлен!"
    cd ../../..
}

config_external_address() {
    log "=== Настройка внешнего адреса ==="
    cd "$CONFIG_DIR" || { error "Не удалось найти config директорию!"; return 1; }
    read -p "Введите внешний адрес (IP:26656): " external_address
    sed -i "s|^external_address *=.*|external_address = \"$external_address\"|" config.toml
    log "Внешний адрес установлен!"
    cd ../../..
}

config_batch_limit() {
    log "=== Настройка batch-request-limit ==="
    cd "$CONFIG_DIR" || { error "Не удалось найти config директорию!"; return 1; }
    if ! grep -q "^batch-request-limit" app.toml; then
        echo 'batch-request-limit = "500"' >> app.toml
        log "Параметр batch-request-limit добавлен!"
    else
        log "Параметр batch-request-limit уже есть."
    fi
    cd ../../..
}

ensure_minimum_gas_prices() {
    if grep -q "^minimum-gas-prices" "$APP_TOML"; then
        log "minimum-gas-prices уже указан в app.toml"
        return
    fi
    local denom
    if [ -f "$GENESIS_JSON" ]; then
        denom=$(jq -r '.app_state.staking.params.bond_denom // empty' "$GENESIS_JSON")
        [ -z "$denom" ] && denom=$(jq -r '.app_state.bank.denom_metadata[0].base // empty' "$GENESIS_JSON")
    fi
    [ -z "$denom" ] && denom="photino"
    sed -i "1iminimum-gas-prices = \"0.01${denom}\"" "$APP_TOML"
    log "minimum-gas-prices = \"0.01${denom}\" успешно добавлен в app.toml"
}

start_node() {
    ensure_minimum_gas_prices
    log "Запуск ноды..."
    cd "$NODE_DIR" || { error "Папка с нодой не найдена!"; return 1; }
    if command -v docker-compose &>/dev/null; then
        docker-compose up -d
    else
        docker compose up -d
    fi
    log "Нода запущена!"
    cd ..
}

stop_node() {
    log "Остановка ноды..."
    cd "$NODE_DIR" || { error "Папка с нодой не найдена!"; return 1; }
    if command -v docker-compose &>/dev/null; then
        docker-compose down
    else
        docker compose down
    fi
    log "Нода остановлена!"
    cd ..
}

show_logs() {
    cd "$NODE_DIR" || { error "Папка с нодой не найдена!"; return 1; }
    echo "Выберите режим:"
    echo "1) Только по 'finaliz'"
    echo "2) Все логи полностью"
    echo "3) Указать имя контейнера вручную"
    read -p "Выберите (1/2/3): " logmode
    case $logmode in
        1) log "Только логи по 'finaliz' (Ctrl+C для выхода)"; 
           if command -v docker-compose &>/dev/null; then
                docker-compose logs -f | grep finaliz
           else
                docker compose logs -f | grep finaliz
           fi;;
        2) log "Показываю ВСЕ логи (Ctrl+C для выхода)";
           if command -v docker-compose &>/dev/null; then
                docker-compose logs -f
           else
                docker compose logs -f
           fi;;
        3) read -p "Введите имя контейнера (например, sahara-testnet-node-saharad-1): " cname
           log "Логи для $cname (Ctrl+C для выхода)"
           docker logs -f "$cname";;
        *) log "Отмена.";;
    esac
    cd ..
    pause
}

delete_node() {
    read -p "Вы уверены, что хотите полностью удалить ноду и все её данные? [y/N]: " confirm
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        stop_node
        if [ -d "$NODE_DIR" ]; then
            rm -rf "$NODE_DIR"
            log "Папка $NODE_DIR и все данные удалены!"
        else
            log "Папка $NODE_DIR не найдена."
        fi
    else
        log "Удаление отменено."
    fi
    pause
}

update_script() { check_update; }
update_repo() {
    if [ -d "$NODE_DIR" ]; then
        log "Обновляю репозиторий Sahara Testnet Node..."
        cd "$NODE_DIR"
        git pull
        cd ..
        log "Репозиторий обновлен!"
    else
        error "Репозиторий не найден. Клонируйте его сначала."
    fi
}

main_menu() {
    while true; do
        clear
        show_logo
        echo
        log "Текущая версия скрипта: $SCRIPT_VERSION"
        echo
        echo -e "\e[35m=== Главное меню ===\e[0m"
        echo "1) Установить Docker и Docker Compose"
        echo "2) Клонировать репозиторий с нодой"
        echo "3) Настроить State Sync (trust_height, trust_hash)"
        echo "4) Настроить имя ноды (moniker)"
        echo "5) Настроить внешний адрес"
        echo "6) Установить batch-request-limit"
        echo "7) Запустить ноду (автофикс gas и batch)"
        echo "8) Остановить ноду"
        echo "9) Просмотреть логи"
        echo "10) Обновить скрипт"
        echo "11) Обновить репозиторий ноды"
        echo "12) Полное удаление ноды"
        echo "0) Выйти"
        echo
        read -p "Выберите действие: " choice

        case $choice in
            1) install_docker; install_docker_compose; install_jq; pause ;;
            2) clone_repo; pause ;;
            3) config_state_sync; pause ;;
            4) config_moniker; pause ;;
            5) config_external_address; pause ;;
            6) config_batch_limit; pause ;;
            7) start_node; pause ;;
            8) stop_node; pause ;;
            9) show_logs ;;
            10) update_script ;;
            11) update_repo; pause ;;
            12) delete_node ;;
            0) echo "Выход..."; exit 0 ;;
            *) echo "Неверный ввод!"; sleep 1 ;;
        esac
    done
}

main_menu
