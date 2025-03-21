
#!/bin/bash
##############################################################################
# 1. Настройки автообновления
##############################################################################
SCRIPT_NAME="layeredge-CLI"               # Имя скрипта (должно совпадать со строкой в versions.txt)
SCRIPT_VERSION="1.0.0"            # Текущая локальная версия
VERSIONS_FILE_URL="https://raw.githubusercontent.com/k2wGG/scripts/main/versions.txt"
SCRIPT_FILE_URL="https://raw.githubusercontent.com/k2wGG/scripts/main/layeredge-CLI.sh"

##############################################################################
# Цвета текста и базовые переменные
##############################################################################
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
MAGENTA='\033[1;35m'
CYAN='\033[1;36m'
RESET='\033[0m'

# Функции для логирования сообщений
msg_info()    { echo -e "${CYAN}[INFO] $1${RESET}"; }
msg_success() { echo -e "${GREEN}[OK] $1${RESET}"; }
msg_warn()    { echo -e "${YELLOW}[WARN] $1${RESET}"; }
msg_error()   { echo -e "${RED}[ERROR] $1${RESET}"; }

# Проверка и установка curl (если отсутствует)
if ! command -v curl &> /dev/null; then
    msg_info "curl не найден – устанавливаю..."
    sudo apt update && sudo apt install -y curl
fi

##############################################################################
# 4. Логотип
##############################################################################
displayLogo() {
    cat <<'EOF'
 _   _           _  _____      
| \ | |         | ||____ |     
|  \| | ___   __| |    / /_ __ 
| . ` |/ _ \ / _` |    \ \ '__|
| |\  | (_) | (_| |.___/ / |   
\_| \_/\___/ \__,_|\____/|_|
    layeredge CLI Manager
        Канал: @nod3r
EOF
}

##############################################################################
# Функция автообновления (использует настройки из начала скрипта)
##############################################################################
selfUpdate() {
    msg_info "Проверка обновлений скрипта..."
    remote_info=$(curl -s "$VERSIONS_FILE_URL" | grep "^$SCRIPT_NAME")
    if [ -z "$remote_info" ]; then
        msg_warn "Не удалось получить информацию о версии."
        read -p "Нажмите Enter для продолжения..."
        return
    fi
    remote_version=$(echo "$remote_info" | awk '{print $2}')
    if [ "$remote_version" != "$SCRIPT_VERSION" ]; then
        msg_info "Найдена новая версия: $remote_version. Обновляю..."
        temp_file=$(mktemp)
        if curl -s -o "$temp_file" "$SCRIPT_FILE_URL"; then
            cp "$temp_file" "$0"
            chmod +x "$0"
            msg_success "Скрипт обновлён до версии $remote_version."
        else
            msg_error "Ошибка при загрузке обновлённого скрипта."
        fi
        rm "$temp_file"
        read -p "Нажмите Enter для продолжения..."
    else
        msg_info "Установлена актуальная версия: $SCRIPT_VERSION."
        read -p "Нажмите Enter для продолжения..."
    fi
}

##############################################################################
# Функция установки зависимостей и базовой настройки
##############################################################################
setupEnvironment() {
    msg_info "Обновляю систему и устанавливаю необходимые пакеты..."
    sudo apt update && sudo apt install -y curl iptables build-essential git wget jq make gcc nano automake autoconf tmux htop nvme-cli pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip screen
    msg_success "Зависимости установлены."

    msg_info "Клонирую репозиторий Light Node..."
    git clone https://github.com/Layer-Edge/light-node.git ~/light-node
    cd ~/light-node || exit 1

    # Установка Go
    GO_VERSION="1.21.3"
    msg_info "Скачиваю и устанавливаю Go версии ${GO_VERSION}..."
    wget "https://golang.org/dl/go${GO_VERSION}.linux-amd64.tar.gz"
    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf "go${GO_VERSION}.linux-amd64.tar.gz"
    rm "go${GO_VERSION}.linux-amd64.tar.gz"
    [ ! -f ~/.bash_profile ] && touch ~/.bash_profile
    grep -q "/usr/local/go/bin" ~/.bash_profile || echo 'export PATH=$PATH:/usr/local/go/bin:~/go/bin' >> ~/.bash_profile
    source ~/.bash_profile

    # Установка или обновление Rust
    if ! command -v rustc &> /dev/null; then
        msg_info "Rust не найден – устанавливаю через rustup..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source "$HOME/.cargo/env"
        msg_success "Rust установлен."
    else
        msg_info "Rust найден – обновляю..."
        rustup update
        source "$HOME/.cargo/env"
        msg_success "Rust обновлён."
    fi

    # Установка RISC Zero
    msg_info "Устанавливаю RISC Zero..."
    curl -L https://risczero.com/install | bash
    source "$HOME/.bashrc"
    sleep 5
    rzup install

    # Создание конфигурационного файла .env
    msg_info "Формирую конфигурационный файл (.env)..."
    read -p "Введите ваш приватный ключ (без 0x): " userKey
    cat <<EOF > ~/light-node/.env
GRPC_URL=grpc.testnet.layeredge.io:9090
CONTRACT_ADDR=cosmos1ufs3tlq4umljk0qfe8k5ya0x6hpavn897u2cnf9k0en9jr7qarqqt56709
ZK_PROVER_URL=http://127.0.0.1:3001
ZK_PROVER_URL=https://layeredge.mintair.xyz/
API_REQUEST_TIMEOUT=300
POINTS_API=https://light-node.layeredge.io
PRIVATE_KEY='$userKey'
EOF
    msg_success "Настройка завершена."
    cd ~ || exit 1
    read -p "Нажмите Enter для возврата в главное меню..."
}

##############################################################################
# Функция запуска Merkle-сервиса
##############################################################################
launchMerkleService() {
    msg_info "Настраиваю и запускаю Merkle-сервис..."
    CURRENT_USER=$(whoami)
    HOME_DIR=$(eval echo ~$CURRENT_USER)
    sudo bash -c "cat > /etc/systemd/system/merkle.service <<EOF
[Unit]
Description=Merkle Service for Light Node
After=network.target

[Service]
User=${CURRENT_USER}
Environment=PATH=${HOME_DIR}/.cargo/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin
WorkingDirectory=${HOME_DIR}/light-node/risc0-merkle-service
ExecStart=/usr/bin/env bash -c \"cargo build && cargo run --release\"
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF"
    sudo systemctl daemon-reload
    sudo systemctl enable merkle.service
    sudo systemctl start merkle.service
    msg_success "Merkle-сервис запущен."
    read -p "Нажмите Enter для просмотра логов (или Ctrl+C для отмены)..."
    sudo journalctl -u merkle.service -f
}

##############################################################################
# Функция запуска Light Node
##############################################################################
launchLightNode() {
    msg_info "Настраиваю и запускаю Light Node..."
    CURRENT_USER=$(whoami)
    HOME_DIR=$(eval echo ~$CURRENT_USER)
    GO_BIN=$(which go)
    if [ -z "$GO_BIN" ]; then
        msg_error "Go не найден – проверьте установку."
        return
    fi
    sudo bash -c "cat > /etc/systemd/system/light-node.service <<EOF
[Unit]
Description=Light Node Service
After=network.target

[Service]
User=${CURRENT_USER}
WorkingDirectory=${HOME_DIR}/light-node
ExecStartPre=${GO_BIN} build
ExecStart=${HOME_DIR}/light-node
Restart=always
RestartSec=10
TimeoutStartSec=200

[Install]
WantedBy=multi-user.target
EOF"
    sudo systemctl daemon-reload
    sudo systemctl enable light-node.service
    sudo systemctl start light-node.service
    msg_success "Light Node запущен."
    read -p "Нажмите Enter для просмотра логов (или Ctrl+C для отмены)..."
    sudo journalctl -u light-node.service -f
}

##############################################################################
# Функция просмотра логов Light Node
##############################################################################
viewNodeLogs() {
    msg_info "Отображаю логи Light Node..."
    sudo journalctl -u light-node.service -f
}

##############################################################################
# Функция перезапуска Light Node
##############################################################################
restartLightNode() {
    msg_info "Перезапускаю Light Node..."
    sudo systemctl restart light-node.service
    msg_success "Нода успешно перезапущена."
    read -p "Нажмите Enter для просмотра логов (или Ctrl+C для отмены)..."
    sudo journalctl -u light-node.service -f
}

##############################################################################
# Функция обновления Light Node
##############################################################################
updateLightNode() {
    msg_info "Обновляю Light Node..."
    cd ~/light-node || exit 1
    sudo systemctl stop light-node.service
    msg_success "Нода остановлена."
    msg_info "Обновляю конфигурацию..."
    rm -f .env
    read -p "Введите новый приватный ключ (без 0x): " newKey
    cat <<EOF > .env
GRPC_URL=grpc.testnet.layeredge.io:9090
CONTRACT_ADDR=cosmos1ufs3tlq4umljk0qfe8k5ya0x6hpavn897u2cnf9k0en9jr7qarqqt56709
ZK_PROVER_URL=http://127.0.0.1:3001
ZK_PROVER_URL=https://layeredge.mintair.xyz/
API_REQUEST_TIMEOUT=300
POINTS_API=https://light-node.layeredge.io
PRIVATE_KEY='$newKey'
EOF
    cd ~ || exit 1
    sudo systemctl restart light-node.service
    msg_success "Нода обновлена и запущена."
    read -p "Нажмите Enter для просмотра логов (или Ctrl+C для отмены)..."
    sudo journalctl -u light-node.service -f
}

##############################################################################
# Функция удаления Light Node и связанных сервисов
##############################################################################
removeLightNode() {
    msg_warn "Внимание! Все данные Light Node будут удалены!"
    read -p "Вы уверены, что хотите удалить ноду? (y/n): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        sudo systemctl stop light-node.service
        sudo systemctl disable light-node.service
        sudo systemctl stop merkle.service
        sudo systemctl disable merkle.service
        sudo rm /etc/systemd/system/light-node.service /etc/systemd/system/merkle.service
        sudo systemctl daemon-reload
        rm -rf ~/light-node
        msg_success "Light Node и все связанные данные удалены."
    else
        msg_info "Удаление отменено."
    fi
    read -p "Нажмите Enter для продолжения..."
}

##############################################################################
# Функция отображения главного меню
##############################################################################
showMenu() {
    echo -e "${YELLOW}Выберите действие:${RESET}"
    echo -e "${MAGENTA}1) Подготовка системы / установка зависимостей${RESET}"
    echo -e "${MAGENTA}2) Запустить Merkle-сервис${RESET}"
    echo -e "${MAGENTA}3) Запустить ноду${RESET}"
    echo -e "${MAGENTA}4) Просмотр логов ноды${RESET}"
    echo -e "${MAGENTA}5) Перезапустить ноду${RESET}"
    echo -e "${MAGENTA}6) Обновить ноду${RESET}"
    echo -e "${MAGENTA}7) Удалить ноду${RESET}"
    echo -e "${MAGENTA}8) Автообновление скрипта${RESET}"
    echo -e "${MAGENTA}9) Выход${RESET}"
    echo -ne "${BLUE}Введите номер (1-9): ${RESET}"
}

##############################################################################
# Главный цикл работы скрипта
##############################################################################
while true; do
    displayLogo
    showMenu
    read -r choice
    case "$choice" in
        1) setupEnvironment ;;
        2) launchMerkleService ;;
        3) launchLightNode ;;
        4) viewNodeLogs ;;
        5) restartLightNode ;;
        6) updateLightNode ;;
        7) removeLightNode ;;
        8) selfUpdate ;;
        9) msg_info "Выход из layeredge CLI Manager. До встречи!"; exit 0 ;;
        *) msg_error "Неверный выбор. Попробуйте снова."; sleep 2 ;;
    esac
done
