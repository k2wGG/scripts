#!/bin/bash
#-----------------------------------------------------------
# Pipe Node Manager — Custom Edition
#
# Скрипт для управления нодой Pipe:
#   • Бинарный файл: https://dl.pipecdn.app/v0.2.5/pop
#
# Возможности:
#   - Установка ноды
#   - Проверка статуса, логов, поинтов
#   - Обновление и удаление ноды
#-----------------------------------------------------------

# Цвета (константы)
declare -r RED='\033[0;31m'
declare -r GREEN='\033[0;32m'
declare -r YELLOW='\033[0;33m'
declare -r BLUE='\033[0;34m'
declare -r PURPLE='\033[0;35m'
declare -r CYAN='\033[0;36m'
declare -r WHITE='\033[1;37m'
declare -r BOLD='\033[1m'
declare -r NC='\033[0m'

# Глобальные переменные
BASE_DIR="$HOME/pipenetwork"
SERVICE_PATH="/etc/systemd/system/pipe-pop.service"
BIN_NAME="pop"
BIN_URL="https://dl.pipecdn.app/v0.2.5/pop"

#------------------------------------------------------------------
# Функция: Проверка наличия утилиты curl, установка при отсутствии
#------------------------------------------------------------------
ensure_curl_installed() {
    if ! command -v curl &>/dev/null; then
        echo -e "${YELLOW}curl не найден. Устанавливаю...${NC}"
        sudo apt update && sudo apt install -y curl
    fi
}

#------------------------------------------------------------------
# Функция: Вывод ASCII‑арт логотипа (уникальное оформление)
#------------------------------------------------------------------
show_logo() {
    cat <<'EOF'
 _   _           _  _____      
| \ | |         | ||____ |     
|  \| | ___   __| |    / /_ __ 
| . ` |/ _ \ / _` |    \ \ '__|
| |\  | (_) | (_| |.___/ / |   
\_| \_/\___/ \__,_|\____/|_|   
                               
Pipe Node Manager — скрипт для автоматики @Nod3r

EOF
}

#------------------------------------------------------------------
# Функция: Логирование информационных сообщений
#------------------------------------------------------------------
log_info() {
    echo -e "${GREEN}[ИНФО]${NC} $1"
}

#------------------------------------------------------------------
# Функция: Логирование сообщений об ошибках
#------------------------------------------------------------------
log_error() {
    echo -e "${RED}[ОШИБКА]${NC} $1"
}

#------------------------------------------------------------------
# Функция: Установка зависимостей
#------------------------------------------------------------------
install_prerequisites() {
    log_info "Устанавливаю необходимые пакеты..."
    sudo apt update && sudo apt install -y curl iptables build-essential git wget jq make gcc nano automake autoconf tmux htop nvme-cli pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip
    log_info "Все зависимости успешно установлены."
}

#------------------------------------------------------------------
# Функция: Подготовка рабочих каталогов
#------------------------------------------------------------------
prepare_directories() {
    log_info "Создаю рабочую директорию и каталог для кэша..."
    mkdir -p "$BASE_DIR/download_cache"
}

#------------------------------------------------------------------
# Функция: Загрузка бинарного файла ноды
#------------------------------------------------------------------
fetch_binary() {
    log_info "Загружаю бинарный файл ноды..."
    cd "$BASE_DIR" || exit 1
    wget "$BIN_URL" -O "$BIN_NAME" || { log_error "Ошибка загрузки бинарного файла."; exit 1; }
    chmod +x "$BIN_NAME"
}

#------------------------------------------------------------------
# Функция: Конфигурация ноды (создание файла .env)
#------------------------------------------------------------------
configure_node() {
    echo -e "${YELLOW}Введите объем оперативной памяти для ноды (например, 8 для 8GB):${NC}"
    read -r NODE_RAM
    echo -e "${YELLOW}Введите размер дискового пространства для ноды (например, 100 для 100GB):${NC}"
    read -r NODE_DISK
    echo -e "${YELLOW}Введите адрес вашего кошелька Solana:${NC}"
    read -r SOL_WALLET

    cat <<EOF > "$BASE_DIR/.env"
ram=$NODE_RAM
max-disk=$NODE_DISK
cache-dir=$BASE_DIR/download_cache
pubKey=$SOL_WALLET
EOF
    log_info "Конфигурация ноды сохранена в файле .env."
}

#------------------------------------------------------------------
# Функция: Создание файла systemd-сервиса и запуск ноды
#------------------------------------------------------------------
deploy_service() {
    local USERNAME home_dir
    USERNAME=$(whoami)
    home_dir=$(eval echo ~$USERNAME)

    log_info "Создаю systemd-сервис..."
    sudo tee "$SERVICE_PATH" >/dev/null <<EOF
[Unit]
Description=Pipe POP Node Service
After=network.target
Wants=network-online.target

[Service]
User=$USERNAME
Group=$USERNAME
WorkingDirectory=$home_dir/pipenetwork
ExecStart=$home_dir/pipenetwork/$BIN_NAME \\
    --ram $(grep '^ram=' "$BASE_DIR/.env" | cut -d'=' -f2) \\
    --max-disk $(grep '^max-disk=' "$BASE_DIR/.env" | cut -d'=' -f2) \\
    --cache-dir $home_dir/pipenetwork/download_cache \\
    --pubKey $(grep '^pubKey=' "$BASE_DIR/.env" | cut -d'=' -f2)
Restart=always
RestartSec=5
LimitNOFILE=65536
LimitNPROC=4096
StandardOutput=journal
StandardError=journal
SyslogIdentifier=dcdn-node

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable pipe-pop
    sudo systemctl start pipe-pop
    log_info "Сервис успешно запущен."
}

#------------------------------------------------------------------
# Функция: Основной процесс установки ноды
#------------------------------------------------------------------
install_node() {
    clear
    echo -e "\n${BOLD}${BLUE}=== Установка ноды Pipe ===${NC}\n"
    install_prerequisites
    prepare_directories
    fetch_binary
    configure_node
    deploy_service
    log_info "Установка ноды завершена!"
    sleep 2
}

#------------------------------------------------------------------
# Функция: Проверка статуса ноды
#------------------------------------------------------------------
node_status() {
    clear
    echo -e "\n${BOLD}${BLUE}=== Проверка статуса ноды ===${NC}\n"
    cd "$BASE_DIR" || exit
    "./$BIN_NAME" --status
    sleep 5
}

#------------------------------------------------------------------
# Функция: Просмотр логов ноды
#------------------------------------------------------------------
view_node_logs() {
    clear
    echo -e "\n${BOLD}${BLUE}=== Просмотр логов ноды ===${NC}\n"
    echo -e "${YELLOW}Нажмите CTRL+C для выхода из просмотра логов.${NC}"
    sudo journalctl -u pipe-pop -f --no-hostname -o cat
}

#------------------------------------------------------------------
# Функция: Проверка поинтов ноды
#------------------------------------------------------------------
check_node_points() {
    clear
    echo -e "\n${BOLD}${BLUE}=== Проверка поинтов ноды ===${NC}\n"
    cd "$BASE_DIR" || exit
    "./$BIN_NAME" --points
    sleep 5
}

#------------------------------------------------------------------
# Функция: Обновление ноды
#------------------------------------------------------------------
update_node() {
    clear
    echo -e "\n${BOLD}${BLUE}=== Обновление ноды Pipe ===${NC}\n"
    sudo systemctl stop pipe-pop
    rm -f "$BASE_DIR/$BIN_NAME"
    wget "$BIN_URL" -O "$BASE_DIR/$BIN_NAME" || { log_error "Ошибка обновления бинарного файла."; exit 1; }
    chmod +x "$BASE_DIR/$BIN_NAME"
    "$BASE_DIR/$BIN_NAME" --refresh
    sudo systemctl restart pipe-pop
    echo -e "${YELLOW}Нажмите CTRL+C для выхода из просмотра логов обновленной ноды.${NC}"
    sudo journalctl -u pipe-pop -f --no-hostname -o cat
}

#------------------------------------------------------------------
# Функция: Удаление ноды
#------------------------------------------------------------------
remove_node() {
    clear
    echo -e "\n${BOLD}${RED}=== Удаление ноды Pipe ===${NC}\n"
    sudo systemctl stop pipe-pop
    sudo systemctl disable pipe-pop
    rm -rf "$BASE_DIR"
    sudo rm -f "$SERVICE_PATH"
    sudo systemctl daemon-reload
    log_info "Нода успешно удалена."
    sleep 2
}

#------------------------------------------------------------------
# Функция: Отображение главного меню и выбор действия
#------------------------------------------------------------------
show_menu() {
    echo -e "\n${BOLD}${WHITE}-------------------------------"
    echo -e "        PIPE NODE MANAGER"
    echo -e "-------------------------------${NC}"
    echo -e "${BLUE}1) Установка ноды"
    echo -e "2) Проверка статуса"
    echo -e "3) Просмотр логов"
    echo -e "4) Проверка поинтов"
    echo -e "5) Обновление ноды"
    echo -e "6) Удаление ноды"
    echo -e "7) Выход${NC}"
    echo -ne "${BOLD}${BLUE}Введите ваш выбор [1-7]: ${NC}"
}

#------------------------------------------------------------------
# Главная функция
#------------------------------------------------------------------
main() {
    ensure_curl_installed
    while true; do
        clear
        show_logo
        show_menu
        read -r choice
        case "$choice" in
            1) install_node ;;
            2) node_status ;;
            3) view_node_logs ;;
            4) check_node_points ;;
            5) update_node ;;
            6) remove_node ;;
            7) echo -e "\n${GREEN}До свидания!${NC}\n"; exit 0 ;;
            *) echo -e "${RED}Неверный выбор. Попробуйте снова.${NC}"; sleep 2 ;;
        esac
    done
}

# Запуск главной функции
main
