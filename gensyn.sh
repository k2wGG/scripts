#!/bin/bash

# Переменные для проверки версии
SCRIPT_NAME="Gensyn"
SCRIPT_VERSION="1.1.0"
VERSIONS_FILE_URL="https://raw.githubusercontent.com/k2wGG/scripts/main/versions.txt"
SCRIPT_FILE_URL="https://raw.githubusercontent.com/k2wGG/scripts/main/Gensyn.sh"

# Цвета для вывода
clrGreen='\033[0;32m'
clrCyan='\033[0;36m'
clrRed='\033[0;31m'
clrYellow='\033[1;33m'
clrReset='\033[0m'
clrBold='\033[1m'

print_ok()    { echo -e "${clrGreen}[OK] $1${clrReset}"; }
print_info()  { echo -e "${clrCyan}[INFO] $1${clrReset}"; }
print_warn()  { echo -e "${clrYellow}[WARN] $1${clrReset}"; }
print_error() { echo -e "${clrRed}[ERROR] $1${clrReset}"; }

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

check_script_version() {
    print_info "Проверка актуальности скрипта..."
    remote_version=$(curl -s "$VERSIONS_FILE_URL" | grep "^${SCRIPT_NAME}=" | cut -d'=' -f2)
    if [ -z "$remote_version" ]; then
        print_warn "Не удалось определить удалённую версию для ${SCRIPT_NAME}"
    elif [ "$remote_version" != "$SCRIPT_VERSION" ]; then
        print_warn "Доступна новая версия: $remote_version (текущая: $SCRIPT_VERSION)"
        print_info "Рекомендуется скачать обновлённый скрипт отсюда:\n$SCRIPT_FILE_URL"
    else
        print_ok "Используется актуальная версия скрипта ($SCRIPT_VERSION)"
    fi
}

check_versions() {
    # Проверка Python
    if command -v python3 &> /dev/null; then
        PYTHON_VERSION=$(python3 -V 2>&1 | awk '{print $2}')
        PYTHON_MAJOR=$(echo $PYTHON_VERSION | cut -d. -f1)
        PYTHON_MINOR=$(echo $PYTHON_VERSION | cut -d. -f2)
        if [ "$PYTHON_MAJOR" -lt 3 ] || { [ "$PYTHON_MAJOR" -eq 3 ] && [ "$PYTHON_MINOR" -lt 10 ]; }; then
            print_error "Требуется Python >= 3.10! Установлено: $PYTHON_VERSION"
            exit 1
        else
            print_ok "Python версия подходит: $PYTHON_VERSION"
        fi
    else
        print_error "Python3 не найден! Установите Python 3.10 или новее."
        exit 1
    fi

    # Проверка Node.js
    if command -v node &> /dev/null; then
        NODE_VERSION=$(node -v | sed 's/v//')
        NODE_MAJOR=$(echo $NODE_VERSION | cut -d. -f1)
        if [ "$NODE_MAJOR" -lt 18 ]; then
            print_error "Требуется Node.js >= 18! Установлено: $NODE_VERSION"
            exit 1
        elif [ "$NODE_MAJOR" -ge 21 ]; then
            print_warn "Node.js $NODE_VERSION может вызвать проблемы с RL Swarm. Рекомендуется использовать Node.js 20.x LTS!"
        else
            print_ok "Node.js версия подходит: $NODE_VERSION"
        fi
    else
        print_error "Node.js не найден! Установите Node.js 20.x LTS."
        exit 1
    fi
}

system_update() {
    print_info "Обновление системы и установка основных пакетов..."
    sudo apt update && sudo apt install -y python3 python3-venv python3-pip curl wget screen git lsof
    print_ok "Базовые пакеты установлены"
}

install_node_yarn() {
    print_info "Установка Node.js и Yarn..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash - && sudo apt update && sudo apt install -y nodejs
    curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
    echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list > /dev/null
    sudo apt update && sudo apt install -y yarn
    print_ok "Node.js и Yarn установлены"
}

clone_repo() {
    print_info "Клонирование репозитория RL Swarm..."
    git clone https://github.com/gensyn-ai/rl-swarm.git "$HOME/rl-swarm" || { print_error "Не удалось клонировать репозиторий"; exit 1; }
    print_ok "Репозиторий клонирован"
}

start_gensyn_screen() {
    # Проверка и запуск screen-сессии gensyn для узла
    if screen -list | grep -q "gensyn"; then
        print_warn "Screen-сессия 'gensyn' уже существует! Используйте 'screen -r gensyn' для входа."
        return
    fi
    print_info "Запускаю RL Swarm node в screen-сессии 'gensyn'..."
    screen -dmS gensyn bash -c '
        cd ~/rl-swarm || exit 1
        python3 -m venv .venv
        source .venv/bin/activate
        cd modal-login
        rm -rf node_modules yarn.lock package-lock.json
        yarn install
        yarn upgrade && yarn add next@latest && yarn add viem@latest
        cd ..
        ./run_rl_swarm.sh
    '
    print_ok "Узел запущен в screen-сессии 'gensyn'. Введите 'screen -r gensyn' для подключения."
}

update_node() {
    print_info "Обновление RL Swarm..."
    if [ -d "$HOME/rl-swarm" ]; then
        cd "$HOME/rl-swarm" || exit 1
        git pull
        print_ok "Репозиторий обновлён."
    else
        print_error "Папка rl-swarm не найдена"
    fi
}

delete_rlswarm() {
    print_warn "Сохраняю приватник swarm.pem (если есть)..."
    if [ -f "$HOME/rl-swarm/swarm.pem" ]; then
        cp "$HOME/rl-swarm/swarm.pem" "$HOME/swarm.pem.backup"
        print_ok "swarm.pem скопирован в $HOME/swarm.pem.backup"
    fi
    print_info "Удаляю rl-swarm..."
    rm -rf "$HOME/rl-swarm"
    print_ok "Папка rl-swarm удалена. Приватник сохранён как ~/swarm.pem.backup"
}

restore_swarm_pem() {
    if [ -f "$HOME/swarm.pem.backup" ]; then
        cp "$HOME/swarm.pem.backup" "$HOME/rl-swarm/swarm.pem"
        print_ok "swarm.pem восстановлен из $HOME/swarm.pem.backup"
    else
        print_warn "Бэкап swarm.pem не найден."
    fi
}

setup_cloudflared_screen() {
    print_info "Установка и запуск Cloudflared для HTTPS-туннеля на порт 3000..."
    sudo apt install ufw -y
    sudo ufw allow 22
    sudo ufw allow 3000/tcp
    sudo ufw --force enable

    if ! command -v cloudflared &> /dev/null; then
        wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
        sudo dpkg -i cloudflared-linux-amd64.deb
        rm -f cloudflared-linux-amd64.deb
    fi

    if screen -list | grep -q "cftunnel"; then
        print_warn "Screen-сессия 'cftunnel' уже существует! Используйте 'screen -r cftunnel' для входа."
        return
    fi

    print_info "Запускаю Cloudflared tunnel в screen-сессии 'cftunnel'..."
    screen -dmS cftunnel bash -c 'cloudflared tunnel --url http://localhost:3000'
    print_ok "Cloudflared-туннель запущен в screen 'cftunnel'. Ссылку ищите в выводе ('screen -r cftunnel')."
}

main_menu() {
    while true; do
        clear
        display_logo
        check_script_version
        echo -e "\n${clrBold}Выберите действие:${clrReset}"
        echo "1) Установить зависимости (Python, Node, Yarn)"
        echo "2) Клонировать RL Swarm"
        echo "3) Запустить узел Gensyn в screen (название: gensyn)"
        echo "4) Обновить RL Swarm"
        echo "5) Удалить RL Swarm (сохранить приватник)"
        echo "6) Восстановить swarm.pem из бэкапа"
        echo "7) Запустить HTTPS-туннель Cloudflared (screen: cftunnel)"
        echo "8) Выход"
        read -rp "Введите номер: " choice
        case $choice in
            1) system_update; install_node_yarn ;;
            2) clone_repo ;;
            3) start_gensyn_screen ;;
            4) update_node ;;
            5) delete_rlswarm ;;
            6) restore_swarm_pem ;;
            7) setup_cloudflared_screen ;;
            8) echo -e "${clrGreen}До свидания!${clrReset}"; exit 0 ;;
            *) print_error "Неверный выбор, попробуйте снова." ;;
        esac
        echo -e "\nНажмите Enter для возврата в меню..."
        read -r
    done
}

# Запуск проверки версий и главного меню
check_versions
main_menu
