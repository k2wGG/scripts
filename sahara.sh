#!/bin/bash

SCRIPT_NAME="sahara"
SCRIPT_VERSION="1.0.0"
VERSIONS_FILE_URL="https://raw.githubusercontent.com/k2wGG/scripts/main/versions.txt"
SCRIPT_FILE_URL="https://raw.githubusercontent.com/k2wGG/scripts/main/Sahara.sh"
REPO_URL="https://github.com/SaharaLabsAI/setup-testnet-node.git"
NODE_DIR="sahara-testnet-node"
CONFIG_DIR="$NODE_DIR/chain-data/config"

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

log() {
    echo -e "\e[36m[$(date '+%H:%M:%S')] $1\e[0m"
}
error() {
    echo -e "\e[31m[ERROR] $1\e[0m" >&2
}

pause() {
    read -n1 -r -p "Нажмите любую клавишу для продолжения..." key
    echo
}

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

config_state_sync() {
    log "=== Настройка State Sync ==="
    cd "$CONFIG_DIR" || { error "Не удалось найти config директорию!"; return 1; }

    read -p "Введите trust_height (например, 100000): " trust_height
    read -p "Введите trust_hash (hash блока на trust_height): " trust_hash

    sed -i "s/^trust_height = .*/trust_height = $trust_height/" config.toml
    sed -i "s/^trust_hash = .*/trust_hash = \"$trust_hash\"/" config.toml

    log "State Sync успешно настроен!"
    cd ../../..
}

config_moniker() {
    log "=== Настройка имени ноды ==="
    cd "$CONFIG_DIR" || { error "Не удалось найти config директорию!"; return 1; }
    read -p "Введите moniker (имя вашей ноды): " moniker
    sed -i "s/^moniker = .*/moniker = \"$moniker\"/" config.toml
    log "Moniker установлен!"
    cd ../../..
}

config_external_address() {
    log "=== Настройка внешнего адреса ==="
    cd "$CONFIG_DIR" || { error "Не удалось найти config директорию!"; return 1; }
    read -p "Введите внешний адрес (IP:26656): " external_address
    sed -i "s|^external_address = .*|external_address = \"$external_address\"|" config.toml
    log "Внешний адрес установлен!"
    cd ../../..
}

config_batch_limit() {
    log "=== Настройка batch-request-limit ==="
    cd "$CONFIG_DIR" || { error "Не удалось найти config директорию!"; return 1; }
    if ! grep -q "batch-request-limit" app.toml; then
        echo 'batch-request-limit = "500"' >> app.toml
        log "Параметр batch-request-limit добавлен!"
    else
        log "Параметр batch-request-limit уже есть."
    fi
    cd ../../..
}

start_node() {
    log "Запуск ноды..."
    cd "$NODE_DIR" || { error "Папка с нодой не найдена!"; return 1; }
    docker compose up -d
    log "Нода запущена!"
    cd ..
}

stop_node() {
    log "Остановка ноды..."
    cd "$NODE_DIR" || { error "Папка с нодой не найдена!"; return 1; }
    docker compose down
    log "Нода остановлена!"
    cd ..
}

show_logs() {
    cd "$NODE_DIR" || { error "Папка с нодой не найдена!"; return 1; }
    log "Показываю логи (Ctrl+C для выхода)..."
    docker compose logs -f | grep finaliz
    cd ..
}

update_script() {
    check_update
}

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
        echo "7) Запустить ноду"
        echo "8) Остановить ноду"
        echo "9) Просмотреть логи (finaliz)"
        echo "10) Обновить скрипт"
        echo "11) Обновить репозиторий ноды"
        echo "0) Выйти"
        echo
        read -p "Выберите действие: " choice

        case $choice in
            1) install_docker; install_docker_compose; pause ;;
            2) clone_repo; pause ;;
            3) config_state_sync; pause ;;
            4) config_moniker; pause ;;
            5) config_external_address; pause ;;
            6) config_batch_limit; pause ;;
            7) start_node; pause ;;
            8) stop_node; pause ;;
            9) show_logs; pause ;;
            10) update_script ;;
            11) update_repo; pause ;;
            0) echo "Выход..."; exit 0 ;;
            *) echo "Неверный ввод!"; sleep 1 ;;
        esac
    done
}

# Запуск скрипта
main_menu
