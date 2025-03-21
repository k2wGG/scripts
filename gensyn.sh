#!/bin/bash
# ====================================================
# Скрипт управления узлом Gensyn
# (установка, обновление, просмотр логов, перезапуск, удаление)
# ====================================================

# Переменные для проверки версии
SCRIPT_NAME="Gensyn"               # Ключ для поиска в versions.txt
SCRIPT_VERSION="1.0.0"             # Текущая локальная версия скрипта
VERSIONS_FILE_URL="https://raw.githubusercontent.com/k2wGG/scripts/main/versions.txt"
SCRIPT_FILE_URL="https://raw.githubusercontent.com/k2wGG/scripts/main/Gensyn.sh"

# Цвета для оформления вывода
clrRed='\033[0;31m'
clrGreen='\033[0;32m'
clrCyan='\033[0;36m'
clrYellow='\033[1;33m'
clrBlue='\033[0;34m'
clrReset='\033[0m'
clrBold='\033[1m'

# Функции вывода сообщений
print_ok()    { echo -e "${clrGreen}[OK] $1${clrReset}"; }
print_info()  { echo -e "${clrCyan}[INFO] $1${clrReset}"; }
print_warn()  { echo -e "${clrYellow}[WARN] $1${clrReset}"; }
print_error() { echo -e "${clrRed}[ERROR] $1${clrReset}"; }

# Проверка наличия curl и его установка, если отсутствует
if ! command -v curl &> /dev/null; then
    sudo apt update && sudo apt install -y curl
fi

# Функция обновления системы и установки базовых пакетов
system_update() {
    print_info "Обновление системы и установка необходимых пакетов..."
    sudo apt-get update && sudo apt-get upgrade -y
    sudo apt-get install -y curl build-essential git wget lz4 jq make gcc nano automake autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip python3 python3-pip
    print_ok "Базовые пакеты установлены"
}

# Определение команды для работы с Docker Compose
set_dc_command() {
    if docker compose version &> /dev/null; then
        DC="docker compose"
    else
        DC="docker-compose"
    fi
    print_ok "Используется команда: $DC"
}

# Функция установки Docker и Docker Compose
install_docker() {
    print_info "Проверка наличия Docker..."
    if ! command -v docker &> /dev/null; then
        print_warn "Docker не найден, устанавливаем..."
        sudo apt-get install -y docker.io
        print_ok "Docker установлен"
    else
        print_ok "Docker уже установлен"
    fi

    print_info "Проверка наличия Docker Compose..."
    if ! command -v docker-compose &> /dev/null; then
        print_warn "Docker Compose не найден, устанавливаем..."
        sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        print_ok "Docker Compose установлен"
    else
        print_ok "Docker Compose уже установлен"
    fi

    set_dc_command
    sudo usermod -aG docker $USER
    print_ok "Пользователь добавлен в группу docker"
}

# Функция вывода ASCII‑логотипа
display_logo() {
    cat <<'EOF'
 _   _           _  _____      
| \ | |         | ||____ |     
|  \| | ___   __| |    / /_ __ 
| . ` |/ _ \ / _` |    \ \ '__|
| |\  | (_) | (_| |.___/ / |   
\_| \_/\___/ \__,_|\____/|_|
          Gensyn
           Канал: @nod3r
EOF
}

# Функция проверки версии скрипта
check_version() {
    print_info "Проверка версии скрипта..."
    remote_version=$(curl -s "$VERSIONS_FILE_URL" | grep "^${SCRIPT_NAME}=" | cut -d'=' -f2)
    if [ -z "$remote_version" ]; then
        print_warn "Не удалось определить удалённую версию для ${SCRIPT_NAME}"
    elif [ "$remote_version" != "$SCRIPT_VERSION" ]; then
        print_info "Доступна новая версия: $remote_version (текущая: $SCRIPT_VERSION)"
        print_info "Обновите скрипт, скачав его с: $SCRIPT_FILE_URL"
    else
        print_ok "Установлена последняя версия ($SCRIPT_VERSION)"
    fi
}

# Функция создания файла docker-compose.yml
generate_compose() {
    print_info "Генерация файла docker-compose.yml..."
    [ -f docker-compose.yml ] && mv docker-compose.yml docker-compose.yml.bak
    cat << 'EOF' > docker-compose.yml
version: '3'

services:
  collector:
    image: otel/opentelemetry-collector-contrib:0.120.0
    ports:
      - "4317:4317"
      - "4318:4318"
      - "55679:55679"
    environment:
      - OTEL_LOG_LEVEL=DEBUG

  node:
    image: europe-docker.pkg.dev/gensyn-public-b7d9/public/rl-swarm:v0.0.2
    command: ./run_hivemind_docker.sh
    environment:
      - OTEL_EXPORTER_OTLP_ENDPOINT=http://collector:4317
      - PEER_MULTI_ADDRS=/ip4/38.101.215.13/tcp/30002/p2p/QmQ2gEXoPJg6iMBSUFWGzAabS2VhnzuS782Y637hGjfsRJ
      - HOST_MULTI_ADDRS=/ip4/0.0.0.0/tcp/38331
    ports:
      - "38331:38331"
    depends_on:
      - collector

  web:
    build:
      context: .
      dockerfile: Dockerfile.webserver
    environment:
      - OTEL_SERVICE_NAME=rlswarm-web
      - OTEL_EXPORTER_OTLP_ENDPOINT=http://collector:4317
      - INITIAL_PEERS=/ip4/38.101.215.13/tcp/30002/p2p/QmQ2gEXoPJg6iMBSUFWGzAabS2VhnzuS782Y637hGjfsRJ
    ports:
      - "8177:8000"
    depends_on:
      - collector
      - node
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/api/healthz"]
      interval: 30s
      retries: 3
EOF
    print_ok "Файл docker-compose.yml создан"
}

# --- Функции управления узлом ---

start_node() {
    echo -e "\n${clrBold}${clrBlue}--- Запуск узла Gensyn ---${clrReset}\n"
    system_update
    install_docker
    print_info "Клонирование репозитория..."
    git clone https://github.com/gensyn-ai/rl-swarm/ || { print_error "Не удалось клонировать репозиторий"; return; }
    cd rl-swarm || return
    generate_compose
    $DC pull
    $DC up -d
    print_ok "Узел Gensyn запущен"
    $DC logs node
}

update_node() {
    echo -e "\n${clrBold}${clrBlue}--- Обновление узла Gensyn ---${clrReset}\n"
    if [ ! -d "$HOME/rl-swarm" ]; then
        print_error "Папка узла не найдена. Сначала запустите узел."
        return
    fi
    cd "$HOME/rl-swarm" || return
    set_dc_command
    new_image="rl-swarm:v0.0.2"
    sed -i "s#\(image: europe-docker.pkg.dev/gensyn-public-b7d9/public/\).*#\1${new_image}#g" docker-compose.yml
    $DC pull
    $DC up -d --force-recreate
    print_ok "Узел обновлён до версии ${new_image}"
    $DC logs node
}

show_logs() {
    echo -e "\n${clrBold}${clrBlue}--- Просмотр логов узла ---${clrReset}\n"
    if [ ! -d "$HOME/rl-swarm" ]; then
        print_error "Папка узла не найдена. Сначала запустите узел."
        return
    fi
    cd "$HOME/rl-swarm" || return
    set_dc_command
    $DC logs node
}

restart_node() {
    echo -e "\n${clrBold}${clrBlue}--- Перезапуск узла Gensyn ---${clrReset}\n"
    if [ ! -d "$HOME/rl-swarm" ]; then
        print_error "Папка узла не найдена. Сначала запустите узел."
        return
    fi
    cd "$HOME/rl-swarm" || return
    set_dc_command
    $DC restart
    print_ok "Узел перезапущен"
    $DC logs node
}

delete_node() {
    echo -e "\n${clrBold}${clrRed}--- Удаление узла Gensyn ---${clrReset}\n"
    if [ ! -d "$HOME/rl-swarm" ]; then
        print_warn "Папка узла не обнаружена. Возможно, узел уже удалён."
        return
    fi
    cd "$HOME/rl-swarm" || return
    set_dc_command
    $DC down -v
    cd "$HOME"
    rm -rf "$HOME/rl-swarm"
    print_ok "Узел Gensyn удалён"
}

# --- Главное меню ---
while true; do
    clear
    display_logo
    check_version
    echo -e "\n${clrBold}Выберите действие:${clrReset}"
    echo "  1) Запустить узел"
    echo "  2) Обновить узел"
    echo "  3) Посмотреть логи"
    echo "  4) Перезапустить узел"
    echo "  5) Удалить узел"
    echo "  6) Выход"
    echo -en "\nВведите номер: "
    read -r choice
    case $choice in
        1) start_node ;;
        2) update_node ;;
        3) show_logs ;;
        4) restart_node ;;
        5) delete_node ;;
        6) echo -e "\n${clrGreen}До свидания!${clrReset}\n"; exit 0 ;;
        *) echo -e "\n${clrRed}Неверный выбор, попробуйте снова.${clrReset}" ;;
    esac
    echo -e "\nНажмите Enter для возврата в меню..."
    read -r
done
