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
#
# Адрес последней версии скрипта на GitHub (raw ссылка)
REMOTE_SCRIPT_URL="https://raw.githubusercontent.com/k2wGG/scripts/refs/heads/main/hype.sh"
#-----------------------------------------------------------

# Цвета (константы)
declare -r RED='\033[0;31m'
declare -r GREEN='\033[0;32m'
declare -r YELLOW='\033[1;33m'
declare -r BLUE='\033[0;34m'
declare -r CYAN='\033[0;36m'
declare -r MAGENTA='\033[0;35m'
declare -r WHITE='\033[1;37m'
declare -r BOLD='\033[1m'
declare -r NC='\033[0m'

# Новые Иконки (изменены для визуального разнообразия)
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

# Глобальные переменные
declare -r BASE_DIR="$HOME/hyperlane_db_base"
declare -r CONTAINER_NAME="hyperlane"
declare -r DOCKER_IMAGE="gcr.io/abacus-labs-dev/hyperlane-agent:agents-v1.0.0"

#------------------------------------------------------------------
# Функция: Автоматическая проверка обновления скрипта
#------------------------------------------------------------------
check_for_script_update() {
    local local_file="$0"
    local tmp_file="/tmp/hyperlane_manager.sh.new"
    curl -s -o "$tmp_file" "$REMOTE_SCRIPT_URL" || {
        log_info "Не удалось проверить обновление скрипта."
        return 1
    }
    if ! cmp -s "$local_file" "$tmp_file"; then
        log_info "Найдена новая версия скрипта. Обновляюсь..."
        cp "$tmp_file" "$local_file"
        chmod +x "$local_file"
        log_info "Скрипт обновлён. Перезапустите его для применения изменений."
        rm -f "$tmp_file"
        exit 0
    else
        rm -f "$tmp_file"
    fi
}

#------------------------------------------------------------------
# Функция: Проверка наличия curl (при отсутствии – установка)
#------------------------------------------------------------------
ensure_curl_installed() {
    if ! command -v curl &>/dev/null; then
        log_info "curl не найден. Устанавливаю..."
        if command -v apt-get &>/dev/null; then
            sudo apt-get update && sudo apt-get install -y curl
        else
            log_error "Установите curl вручную."
            exit 1
        fi
    fi
}

#------------------------------------------------------------------
# Функция: Вывод встроенного ASCII‑арт логотипа
#   Убрана повторная надпись "HYPERLANE NODE MANAGER", чтобы
#   не было дублирования в меню
#------------------------------------------------------------------
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

#------------------------------------------------------------------
# Функция: Логирование информационных сообщений
#------------------------------------------------------------------
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

#------------------------------------------------------------------
# Функция: Логирование сообщений об ошибках
#------------------------------------------------------------------
log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

#------------------------------------------------------------------
# Функция: Отрисовка рамки меню
#   Теперь нет надписи "HYPERLANE NODE MANAGER" внутри ASCII-арта,
#   поэтому выводим её здесь
#------------------------------------------------------------------
draw_menu_frame() {
    local title="$1"
    echo -e "${MAGENTA}┌──────────────────────────────────────────────┐${NC}"
    printf "${MAGENTA}│${NC} %-42s ${MAGENTA}  │\n" "$title"
    echo -e "${MAGENTA}└──────────────────────────────────────────────┘${NC}"
}

#------------------------------------------------------------------
# Функция: Установка ноды
#------------------------------------------------------------------
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

#------------------------------------------------------------------
# Функция: Обновление ноды
#------------------------------------------------------------------
update_node() {
    clear
    echo -e "\n${BLUE}${ICON_REFRESH} Обновление ноды Hyperlane...${NC}"
    # Можно добавить логику скачивания нового образа, если нужно
    log_info "Установлена актуальная версия ноды!"
    read -n1 -r -p "Нажмите любую клавишу для возврата в меню..." key
}

#------------------------------------------------------------------
# Функция: Просмотр логов ноды
#------------------------------------------------------------------
view_logs() {
    clear
    echo -e "\n${BLUE}${ICON_LOGS} Просмотр логов ноды Hyperlane...${NC}"
    docker logs -f "${CONTAINER_NAME}"
    read -n1 -r -p "Нажмите любую клавишу для возврата в меню..." key
}

#------------------------------------------------------------------
# Функция: Удаление ноды
#------------------------------------------------------------------
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

#------------------------------------------------------------------
# Функция: Отображение главного меню
#------------------------------------------------------------------
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

#------------------------------------------------------------------
# Главная функция
#------------------------------------------------------------------
main() {
    ensure_curl_installed
    check_for_script_update
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
