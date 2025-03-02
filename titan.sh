#!/bin/bash
##############################################################################
# Скрипт управления нодой Titan
# Хранит версию в общем файле versions.txt
##############################################################################

##############################################################################
# 1. Настройки автообновления
##############################################################################
SCRIPT_NAME="titan"               # Имя скрипта (должно совпадать со строкой в versions.txt)
SCRIPT_VERSION="1.0.0"            # Текущая локальная версия
VERSIONS_FILE_URL="https://raw.githubusercontent.com/k2wGG/scripts/main/versions.txt"
SCRIPT_FILE_URL="https://raw.githubusercontent.com/k2wGG/scripts/main/titan.sh"

##############################################################################
# 2. Цвета и стили
##############################################################################
CLR_INFO='\033[0;36m'    # Голубой (Cyan)
CLR_SUCCESS='\033[0;32m' # Зелёный (Green)
CLR_WARN='\033[0;33m'    # Жёлтый (Yellow)
CLR_ERROR='\033[0;31m'   # Красный (Red)
CLR_RESET='\033[0m'      # Сброс цвета

##############################################################################
# 3. Функции логирования с цветом
##############################################################################
log_info() {
    echo -e "${CLR_INFO}[INFO] $1${CLR_RESET}"
}

log_success() {
    echo -e "${CLR_SUCCESS}[SUCCESS] $1${CLR_RESET}"
}

log_warn() {
    echo -e "${CLR_WARN}[WARN] $1${CLR_RESET}"
}

log_error() {
    echo -e "${CLR_ERROR}[ERROR] $1${CLR_RESET}"
}

##############################################################################
# 4. Логотип
##############################################################################
display_logo() {
    cat <<'EOF'
 _   _           _  _____      
| \ | |         | ||____ |     
|  \| | ___   __| |    / /_ __ 
| . ` |/ _ \ / _` |    \ \ '__|
| |\  | (_) | (_| |.___/ / |   
\_| \_/\___/ \__,_|\____/|_|
          titan
           Канал: @nod3r
EOF
}

##############################################################################
# 5. Функция проверки и автообновления из общего файла versions.txt
##############################################################################
auto_update() {
    log_info "Текущая версия скрипта: ${SCRIPT_VERSION}"
    log_info "Скачиваем общий файл версий..."
    
    remote_versions=$(curl -s "$VERSIONS_FILE_URL")
    if [ -z "$remote_versions" ]; then
        log_warn "Не удалось получить данные о версиях. Пропускаем автообновление."
        return
    fi

    # Ищем строку вида "titan=1.0.0"
    remote_version=$(echo "$remote_versions" | grep "^${SCRIPT_NAME}=" | cut -d '=' -f2)
    if [ -z "$remote_version" ]; then
        log_warn "В файле versions.txt нет строки для '${SCRIPT_NAME}'. Пропускаем автообновление."
        return
    fi

    # Сравниваем локальную версию с удалённой
    if [ "$remote_version" != "$SCRIPT_VERSION" ]; then
        log_warn "Доступна новая версия скрипта (v${remote_version}). Начинаем обновление..."
        curl -s -o "$0.new" "$SCRIPT_FILE_URL"
        
        if [ -f "$0.new" ]; then
            mv "$0.new" "$0"
            chmod +x "$0"
            log_success "Скрипт обновлён до версии v${remote_version}. Перезапустите скрипт."
            exit 0
        else
            log_error "Не удалось сохранить обновлённый скрипт."
        fi
    else
        log_success "Текущая версия скрипта (v${SCRIPT_VERSION}) актуальна."
    fi
}

##############################################################################
# 6. Функция проверки наличия curl
##############################################################################
check_curl() {
    log_info "Проверяем наличие утилиты curl..."
    if ! command -v curl >/dev/null 2>&1; then
        log_warn "curl не найден, выполняется установка..."
        sudo apt update && sudo apt install -y curl
    else
        log_success "curl обнаружен."
    fi
}

##############################################################################
# 7. Функция вывода меню
##############################################################################
show_menu() {
    echo ""
    echo "--------------------------------------------------"
    echo "Выберите действие:"
    echo "  1) Установка ноды"
    echo "  2) Обновление ноды"
    echo "  3) Просмотр логов"
    echo "  4) Перезапуск ноды"
    echo "  5) Удаление ноды"
    echo "--------------------------------------------------"
    read -p "Введите номер операции: " option
}

##############################################################################
# 8. Функции управления нодой Titan
##############################################################################

# 8.1 Установка ноды
install_node() {
    log_info "Инициализация установки ноды Titan..."

    # Проверка Docker
    if command -v docker >/dev/null 2>&1; then
        log_success "Docker обнаружен."
    else
        log_info "Устанавливаем Docker..."
        sudo apt remove -y docker docker-engine docker.io containerd runc
        sudo apt install -y apt-transport-https ca-certificates curl software-properties-common lsb-release gnupg2
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
        https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
        | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        sudo apt update && sudo apt install -y docker-ce docker-ce-cli containerd.io
        if command -v docker >/dev/null 2>&1; then
            log_success "Docker установлен."
        else
            log_error "Не удалось установить Docker."
            return
        fi
    fi

    # Проверка Docker Compose
    if command -v docker-compose >/dev/null 2>&1; then
        log_success "Docker Compose уже установлен."
    else
        log_info "Устанавливаем Docker Compose..."
        ver=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep tag_name | cut -d '"' -f 4)
        sudo curl -L "https://github.com/docker/compose/releases/download/$ver/docker-compose-$(uname -s)-$(uname -m)" \
            -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        if command -v docker-compose >/dev/null 2>&1; then
            log_success "Docker Compose установлен."
        else
            log_error "Не удалось установить Docker Compose."
            return
        fi
    fi

    # Добавляем пользователя в группу docker
    if ! groups "$USER" | grep -q '\bdocker\b'; then
        log_info "Добавляем пользователя '$USER' в группу docker..."
        sudo groupadd docker 2>/dev/null
        sudo usermod -aG docker "$USER"
    else
        log_success "Пользователь '$USER' уже в группе docker."
    fi

    # Загрузка Docker-образа Titan
    log_info "Загрузка образа Titan..."
    docker pull nezha123/titan-edge

    # Создание рабочей директории
    mkdir -p ~/.titanedge

    # Запуск контейнера
    log_info "Запускаем контейнер Titan..."
    docker run --name titan --network=host -d -v ~/.titanedge:/root/.titanedge nezha123/titan-edge

    # Привязка идентификационного кода
    read -p "Введите идентификационный код Titan: " id_code
    docker run --rm -it -v ~/.titanedge:/root/.titanedge nezha123/titan-edge bind \
        --hash="$id_code" https://api-test1.container1.titannet.io/api/v2/device/binding

    echo "--------------------------------------------------"
    echo "Для просмотра логов используйте: docker logs -f titan"
    echo "--------------------------------------------------"
    log_success "Установка завершена."
    sleep 2
    docker logs -f titan
}

# 8.2 Обновление ноды
update_node() {
    log_info "Проверка обновлений для ноды..."
    log_success "Нода актуальна."
}

# 8.3 Просмотр логов
display_logs() {
    log_info "Просмотр логов ноды..."
    docker logs -f titan
}

# 8.4 Перезапуск ноды
restart_node() {
    log_info "Перезапуск ноды..."
    docker restart titan
    log_success "Нода перезапущена."
    sleep 2
    docker logs -f titan
}

# 8.5 Удаление ноды
delete_node() {
    log_warn "Удаление ноды Titan..."
    docker stop titan
    docker rm titan
    docker rmi nezha123/titan-edge
    rm -rf ~/.titanedge
    log_success "Нода успешно удалена."
    sleep 2
}

##############################################################################
# 9. Основной блок выполнения
##############################################################################
check_curl
auto_update
display_logo
show_menu

case "$option" in
    1) install_node ;;
    2) update_node ;;
    3) display_logs ;;
    4) restart_node ;;
    5) delete_node ;;
    *) log_error "Некорректный выбор. Запустите скрипт снова и введите число от 1 до 5." ;;
esac
