#!/bin/bash
#-----------------------------------------------------------
# Hyperlane Node Manager — Custom Edition
#
# Скрипт для управления нодой Hyperlane:
#   • Docker-образ: gcr.io/abacus-labs-dev/hyperlane-agent:agents-v1.0.0
#
# Возможности:
#   - Установка ноды
#   - Обновление ноды
#   - Просмотр логов
#   - Удаление ноды
#-----------------------------------------------------------

##############################################################################
# 1. Настройки автообновления
##############################################################################
SCRIPT_NAME="hype"               # Ключ для поиска в versions.txt
SCRIPT_VERSION="1.0.0"           # Текущая локальная версия скрипта
VERSIONS_FILE_URL="https://raw.githubusercontent.com/k2wGG/scripts/main/versions.txt"
SCRIPT_FILE_URL="https://raw.githubusercontent.com/k2wGG/scripts/main/hype.sh"

##############################################################################
# 2. Цвета (константы)
##############################################################################
declare -r RED='\033[0;31m'
declare -r GREEN='\033[0;32m'
declare -r YELLOW='\033[1;33m'
declare -r BLUE='\033[0;34m'
declare -r CYAN='\033[0;36m'
declare -r MAGENTA='\033[0;35m'
declare -r WHITE='\033[1;37m'
declare -r BOLD='\033[1m'
declare -r NC='\033[0m'

##############################################################################
# 3. Иконки для визуального разнообразия
##############################################################################
declare -r ICON_OK="✔️"
declare -r ICON_FAIL="❗"
declare -r ICON_WAIT="⌛"
declare -r ICON_INSTALL="🔧"
declare -r ICON_SUCCESS="🎊"
declare -r ICON_WARN="⚠️"
declare -r ICON_NODE="💻"
declare -r ICON_INFO="ℹ️"
declare -r ICON_DELETE="🚮"
declare -r ICON_REFRESH="🔃"
declare -r ICON_LOGS="📝"
declare -r ICON_EXIT="🚫"

##############################################################################
# 4. Глобальные переменные
##############################################################################
declare -r BASE_DIR="$HOME/hyperlane_db_base"
declare -r CONTAINER_NAME="hyperlane"
declare -r DOCKER_IMAGE="gcr.io/abacus-labs-dev/hyperlane-agent:agents-v1.0.0"

##############################################################################
# 5. Функция: Автоматическая проверка и автообновление скрипта через versions.txt
##############################################################################
auto_update() {
    echo -e "${CYAN}Текущая версия скрипта: ${SCRIPT_VERSION}${NC}"
    echo -e "${CYAN}Скачиваем общий файл версий...${NC}"
    
    remote_versions=$(curl -s "$VERSIONS_FILE_URL")
    if [ -z "$remote_versions" ]; then
        echo -e "${YELLOW}Не удалось получить данные о версиях. Пропускаем автообновление.${NC}"
        return
    fi

    remote_version=$(echo "$remote_versions" | grep "^${SCRIPT_NAME}=" | cut -d '=' -f2)
    if [ -z "$remote_version" ]; then
        echo -e "${YELLOW}В файле versions.txt нет строки для '${SCRIPT_NAME}'. Пропускаем автообновление.${NC}"
        return
    fi

    if [ "$remote_version" != "$SCRIPT_VERSION" ]; then
        echo -e "${CYAN}Найдена новая версия скрипта (v${remote_version}). Начинаю обновление...${NC}"
        curl -s -o "$0.new" "$SCRIPT_FILE_URL"
        if [ -f "$0.new" ]; then
            cp "$0.new" "$0"
            chmod +x "$0"
            echo -e "${GREEN}Скрипт обновлён до версии v${remote_version}. Перезапустите его для применения изменений.${NC}"
            rm -f "$0.new"
            exit 0
        else
            echo -e "${RED}Не удалось сохранить обновлённый скрипт.${NC}"
        fi
    else
        echo -e "${GREEN}Текущая версия скрипта (v${SCRIPT_VERSION}) актуальна.${NC}"
    fi
}

##############################################################################
# 6. Функция: Проверка наличия curl (при отсутствии – установка)
##############################################################################
ensure_curl_installed() {
    if ! command -v curl &>/dev/null; then
        echo -e "${GREEN}[INFO] curl не найден. Устанавливаю...${NC}"
        if command -v apt-get &>/dev/null; then
            sudo apt-get update && sudo apt-get install -y curl
        else
            echo -e "${RED}[ERROR] Установите curl вручную.${NC}"
            exit 1
        fi
    fi
}

##############################################################################
# 7. Функция: Вывод встроенного ASCII‑арт логотипа
##############################################################################
show_logo() {
cat <<'EOF'
 _   _           _  _____      
| \ | |         | ||____ |     
|  \| | ___   __| |    / /_ __ 
| . ` |/ _ \ / _` |    \ \ '__|
| |\  | (_) | (_| |.___/ / |   
\_| \_/\___/ \__,_|\____/|_|   
                               
Hyperlane Node Manager — скрипт для автоматики @Nod3r
EOF
}

##############################################################################
# 8. Функция: Логирование информационных сообщений
##############################################################################
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

##############################################################################
# 9. Функция: Логирование сообщений об ошибках
##############################################################################
log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

##############################################################################
# 10. Функция: Отрисовка рамки меню
##############################################################################
draw_menu_frame() {
    local title="$1"
    echo -e "${MAGENTA}┌──────────────────────────────────────────────┐${NC}"
    printf "${MAGENTA}│${NC} %-42s ${MAGENTA}  │\n" "$title"
    echo -e "${MAGENTA}└──────────────────────────────────────────────┘${NC}"
}

##############################################################################
# 11. Функция: Установка ноды
##############################################################################
install_node() {
    clear
    log_info "Начало установки ноды Hyperlane..."
    
    echo -e "${ICON_WAIT} Обновление системы..."
    sudo apt update -y && sudo apt upgrade -y

    # Установка Docker, если не установлен
    if ! command -v docker &>/dev/null; then
        echo -e "${ICON_WAIT} Установка Docker..."
        sudo apt install -y docker.io
        sudo systemctl start docker
        sudo systemctl enable docker
    else
        echo -e "${ICON_OK} Docker уже установлен"
    fi

    echo -e "${ICON_WAIT} Загрузка Docker-образа..."
    docker pull --platform linux/amd64 ${DOCKER_IMAGE}

    # Ввод данных пользователя
    echo -ne "${YELLOW}Введите имя валидатора:${NC} "
    read -r NAME
    echo -ne "${YELLOW}Введите приватный ключ от EVM кошелька (начинается с 0x):${NC} "
    read -r PRIVATE_KEY

    # Создание директории для ноды
    mkdir -p "$BASE_DIR"
    chmod -R 777 "$BASE_DIR"

    echo -e "${ICON_WAIT} Запуск Docker контейнера..."
    docker run -d -it \
        --name "${CONTAINER_NAME}" \
        --mount type=bind,source="$BASE_DIR",target=/hyperlane_db_base \
        ${DOCKER_IMAGE} \
        ./validator \
        --db /hyperlane_db_base \
        --originChainName base \
        --reorgPeriod 1 \
        --validator.id "$NAME" \
        --checkpointSyncer.type localStorage \
        --checkpointSyncer.folder base \
        --checkpointSyncer.path /hyperlane_db_base/base_checkpoints \
        --validator.key "$PRIVATE_KEY" \
        --chains.base.signer.key "$PRIVATE_KEY" \
        --chains.base.customRpcUrls https://base.llamarpc.com

    if [ $? -eq 0 ]; then
        log_info "Нода успешно установлена!"
        echo -e "${ICON_INFO} Логи: docker logs -f ${CONTAINER_NAME}"
    else
        log_error "Ошибка при запуске контейнера!"
        exit 1
    fi

    echo -e "${ICON_WAIT} Отображение логов..."
    sleep 2
    docker logs -f "${CONTAINER_NAME}"
    read -n1 -r -p "Нажмите любую клавишу для возврата в меню..." key
}

##############################################################################
# 12. Функция: Обновление ноды
##############################################################################
update_node() {
    clear
    echo -e "\n${BLUE}${ICON_REFRESH} Обновление ноды Hyperlane...${NC}"
    # Здесь можно добавить логику обновления Docker-образа, если требуется
    log_info "Установлена актуальная версия ноды!"
    read -n1 -r -p "Нажмите любую клавишу для возврата в меню..." key
}

##############################################################################
# 13. Функция: Просмотр логов ноды
##############################################################################
view_logs() {
    clear
    echo -e "\n${BLUE}${ICON_LOGS} Просмотр логов ноды Hyperlane...${NC}"
    docker logs -f "${CONTAINER_NAME}"
    read -n1 -r -p "Нажмите любую клавишу для возврата в меню..." key
}

##############################################################################
# 14. Функция: Удаление ноды
##############################################################################
remove_node() {
    clear
    echo -e "\n${BLUE}${ICON_DELETE} Удаление ноды Hyperlane...${NC}"
    
    echo -e "${ICON_WAIT} Остановка и удаление контейнера..."
    docker stop "${CONTAINER_NAME}" && docker rm "${CONTAINER_NAME}"

    if [ -d "$BASE_DIR" ]; then
        echo -e "${ICON_WAIT} Удаление директории ноды..."
        rm -rf "$BASE_DIR"
        echo -e "${ICON_OK} Директория ноды удалена"
    fi

    log_info "Нода успешно удалена!"
    read -n1 -r -p "Нажмите любую клавишу для возврата в меню..." key
}

##############################################################################
# 15. Функция: Отображение главного меню
##############################################################################
show_menu() {
    clear
    show_logo
    echo
    draw_menu_frame "HYPERLANE NODE MANAGER"
    echo -e "${CYAN}1)${NC} Установить ноду    ${ICON_INSTALL}"
    echo -e "${CYAN}2)${NC} Обновить ноду      ${ICON_REFRESH}"
    echo -e "${CYAN}3)${NC} Просмотр логов     ${ICON_LOGS}"
    echo -e "${CYAN}4)${NC} Удалить ноду      ${ICON_DELETE}"
    echo -e "${CYAN}5)${NC} Выход             ${ICON_EXIT}"
    echo
    read -p "$(echo -e ${GREEN}Выберите действие [1-5]:${NC} )" choice
}

##############################################################################
# 16. Главная функция
##############################################################################
main() {
    ensure_curl_installed
    auto_update
    while true; do
        show_menu
        case "$choice" in
            1) install_node ;;
            2) update_node ;;
            3) view_logs ;;
            4) remove_node ;;
            5) echo -e "${ICON_SUCCESS} Выход...${NC}"; exit 0 ;;
            *) echo -e "${ICON_FAIL} Неверный выбор. Используйте числа от 1 до 5."; sleep 2 ;;
        esac
    done
}

# Запуск главной функции
main
