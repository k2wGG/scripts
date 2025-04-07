#!/bin/bash
##############################################################################
# 1. Настройки автообновления
##############################################################################
SCRIPT_NAME="abstract"               # Ключ для поиска в versions.txt
SCRIPT_VERSION="1.0.0"           # Текущая локальная версия скрипта
VERSIONS_FILE_URL="https://raw.githubusercontent.com/k2wGG/scripts/main/versions.txt"
SCRIPT_FILE_URL="https://raw.githubusercontent.com/k2wGG/scripts/main/abstract.sh"

check_for_updates() {
    remote_version=$(curl -s "$VERSIONS_FILE_URL" | grep "^$SCRIPT_NAME=" | cut -d'=' -f2)

    if [[ -z "$remote_version" ]]; then
        echo -e "\033[33m[!] Не удалось получить версию скрипта с сервера\033[0m"
        return
    fi

    if [[ "$remote_version" != "$SCRIPT_VERSION" ]]; then
        echo -e "\033[33m🔄 Доступна новая версия скрипта: $remote_version (текущая: $SCRIPT_VERSION)\033[0m"
        read -rp "Хотите обновить сейчас? [y/N]: " confirm
        if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
            curl -s "$SCRIPT_FILE_URL" -o "$0" && chmod +x "$0"
            echo -e "\033[32m✅ Скрипт обновлен до версии $remote_version. Перезапустите его.\033[0m"
            exit 0
        else
            echo -e "\033[36m➖ Продолжаем с текущей версией ($SCRIPT_VERSION)\033[0m"
        fi
    else
        echo -e "\033[32m✅ Установлена актуальная версия скрипта ($SCRIPT_VERSION)\033[0m"
    fi
}


### === Настройка цветовой схемы === ###
RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
BLUE='\e[34m'
RESET='\e[0m'

### === Функции вывода === ###
info()    { echo -e "${BLUE}[INFO]${RESET} $1"; }
success() { echo -e "${GREEN}[OK]${RESET} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET} $1"; }
error()   { echo -e "${RED}[ERROR]${RESET} $1"; }

### === ASCII логотип === ###
show_logo() {
cat << "LOGO"
 _   _           _  _____      
| \ | |         | ||____ |     
|  \| | ___   __| |    / /_ __ 
| . ` |/ _ \ / _` |    \ \ '__|
| |\  | (_) | (_| |.___/ / |   
\_| \_/\___/ \__,_|\____/|_|   
                               
Abstract Node Manager — скрипт для автоматики @Nod3r
LOGO
}

### === Проверка и установка Docker === ###
setup_docker() {
    if ! docker --version &>/dev/null; then
        warn "Docker не найден. Установка..."
        curl -fsSL https://get.docker.com | sh
        sudo systemctl enable docker && sudo systemctl start docker
        success "Docker установлен"
    else
        success "Docker уже установлен"
    fi
}

### === Проверка и установка Docker Compose === ###
setup_compose() {
    if ! docker compose version &>/dev/null; then
        warn "Docker Compose отсутствует. Установка..."
        sudo apt update && sudo apt install -y docker-compose-plugin
        success "Docker Compose установлен"
    else
        success "Docker Compose уже доступен"
    fi
}

### === Обновление Chain ID (mainnet) === ###
patch_mainnet_config() {
    local cfg="$HOME/abstract-node/external-node/mainnet-external-node.yml"
    info "Изменяем параметры Chain ID..."
    [[ ! -f "$cfg" ]] && { error "Файл не найден: $cfg"; return 1; }

    sed -i.bak \
        -e 's/^EN_L1_CHAIN_ID:.*/EN_L1_CHAIN_ID: 1/' \
        -e 's/^EN_L2_CHAIN_ID:.*/EN_L2_CHAIN_ID: 2741/' "$cfg" && \
        success "Chain ID обновлён"
}

### === Установка и запуск ноды === ###
run_node() {
    local net="$1"
    info "Клонируем исходники Abstract Node..."
    git clone https://github.com/Abstract-Foundation/abstract-node || { error "Клонирование не удалось"; return 1; }
    cd abstract-node/external-node || return 1

    [[ "$net" == "mainnet" ]] && {
        patch_mainnet_config
        docker compose -f mainnet-external-node.yml up -d
    } || {
        docker compose -f testnet-external-node.yml up -d
    }

    success "Нода ($net) успешно установлена и запущена"
}

### === Просмотр логов === ###
view_logs() {
    docker ps --format "Контейнер: {{.Names}}"
    read -rp "Введите имя контейнера: " cname
    [[ -z "$cname" ]] && { error "Имя не введено"; return; }
    docker logs -f --tail 100 "$cname"
}

### === Сброс состояния ноды === ###
wipe_node() {
    local net="$1"
    cd "$HOME/abstract-node/external-node" || return
    docker compose -f "${net}-external-node.yml" down --volumes
    success "Сброс выполнен ($net)"
}

### === Перезапуск контейнера === ###
restart_docker() {
    docker ps --format "Контейнер: {{.Names}}"
    read -rp "Введите имя контейнера: " name
    [[ -z "$name" ]] && { error "Имя не указано"; return; }
    docker restart "$name" && success "Контейнер $name перезапущен"
}

### === Полное удаление ноды === ###
full_cleanup() {
    warn "Все данные ноды будут удалены безвозвратно!"
    read -rp "Подтвердите действие (y/N): " confirm
    [[ "$confirm" != "y" && "$confirm" != "Y" ]] && { info "Удаление отменено"; return; }

    cd "$HOME/abstract-node/external-node" || return
    docker compose -f testnet-external-node.yml down --volumes
    docker compose -f mainnet-external-node.yml down --volumes
    rm -rf ~/abstract-node
    success "Нода и данные удалены"
}

### === Главное меню === ###
main_menu() {
    while true; do
        clear
        show_logo
        echo
        echo -e "${BLUE}Выберите действие (введите число):${RESET}"
        echo "1. Установить Docker и Compose"
        echo "2. Установить Testnet-ноду"
        echo "3. Установить Mainnet-ноду"
        echo "4. Просмотр логов"
        echo "5. Сброс Testnet-ноды"
        echo "6. Сброс Mainnet-ноды"
        echo "7. Перезапуск контейнера"
        echo "8. Полное удаление ноды"
        echo "9. Выход"
        echo
        read -rp "Выберите действие [1-9]: " opt

        case "$opt" in
            1) setup_docker; setup_compose ;;
            2) run_node "testnet" ;;
            3) run_node "mainnet" ;;
            4) view_logs ;;
            5) wipe_node "testnet" ;;
            6) wipe_node "mainnet" ;;
            7) restart_docker ;;
            8) full_cleanup ;;
            9) echo -e "${GREEN}До встречи!${RESET}"; break ;;
            *) error "Неверный выбор" ;;
        esac

        echo
        read -rp "Нажмите Enter для возврата в меню..."
    done
}

### === Запуск скрипта === ###
check_for_updates
main_menu
