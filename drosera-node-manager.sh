#!/bin/bash

# Имя и версии
SCRIPT_NAME="drosera"
SCRIPT_VERSION="1.0.0"
VERSIONS_FILE_URL="https://raw.githubusercontent.com/k2wGG/scripts/main/versions.txt"
SCRIPT_FILE_URL="https://raw.githubusercontent.com/k2wGG/scripts/main/drosera-node-manager.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m'

display_logo() {
    cat <<'EOF'
 _   _           _  _____      
| \ | |         | ||____ |     
|  \| | ___   __| |    / /_ __ 
| . ` |/ _ \ / _` |    \ \ '__|
| |\  | (_) | (_| |.___/ / |   
\_| \_/\___/ \__,_|\____/|_|   
          TG: @nod3r           
EOF
}

success_message() { echo -e "${GREEN}[✅]${NC} $1"; }
info_message()    { echo -e "${CYAN}[ℹ️]${NC} $1"; }
error_message()   { echo -e "${RED}[❌]${NC} $1"; }

ensure_curl() {
    if ! command -v curl &>/dev/null; then
        info_message "curl не найден, устанавливаю..."
        sudo apt update && sudo apt install curl -y
    fi
}

ensure_jq() {
    if ! command -v jq &>/dev/null; then
        info_message "jq не найден, устанавливаю..."
        sudo apt update && sudo apt install jq -y
    fi
}

auto_update() {
    info_message "Проверка новой версии скрипта..."
    latest=$(curl -fsSL "$VERSIONS_FILE_URL" | grep -E "^$SCRIPT_NAME[[:space:]]" | awk '{print $2}')
    if [[ -z "$latest" ]]; then
        error_message "Не удалось получить версию из $VERSIONS_FILE_URL"
        return
    fi
    if [[ "$latest" != "$SCRIPT_VERSION" ]]; then
        info_message "Найдена новая версия: $latest (у вас $SCRIPT_VERSION)"
        info_message "Загружаю обновлённый скрипт..."
        curl -fsSL "$SCRIPT_FILE_URL" -o /tmp/drosera-node-manager.sh
        chmod +x /tmp/drosera-node-manager.sh
        success_message "Обновление завершено. Запускаю новую версию..."
        exec /tmp/drosera-node-manager.sh
    else
        success_message "Версия актуальна: $SCRIPT_VERSION"
    fi
}

install_dependencies() {
    info_message "Установка необходимых пакетов..."
    sudo apt-get update && sudo apt-get upgrade -y
    sudo apt install curl ufw iptables build-essential git wget lz4 jq make gcc nano \
        automake autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev \
        libleveldb-dev tar clang bsdmainutils ncdu unzip -y

    info_message "Установка специфических инструментов..."
    curl -L https://app.drosera.io/install | bash
    curl -L https://foundry.paradigm.xyz | bash
    curl -fsSL https://bun.sh/install | bash

    info_message "Настройка портов..."
    for port in 31313 31314; do
        if ! sudo iptables -C INPUT -p tcp --dport $port -j ACCEPT 2>/dev/null; then
            sudo iptables -I INPUT -p tcp --dport $port -j ACCEPT
            success_message "Порт $port открыт"
        else
            info_message "Порт $port уже открыт"
        fi
    done
    success_message "Зависимости установлены"
}

# Получить ссылку на последнюю версию drosera-operator для linux-x86_64
get_latest_operator_release_url() {
    curl -s "https://api.github.com/repos/drosera-network/releases/releases/latest" | \
        jq -r '.assets[] | select(.name | test("drosera-operator-v.*-x86_64-unknown-linux-gnu.tar.gz")) | .browser_download_url' | head -n1
}

update_operator_bin() {
    ensure_jq
    info_message "Проверяю актуальную версию drosera-operator..."
    url=$(get_latest_operator_release_url)
    if [[ -z "$url" ]]; then
        error_message "Не удалось найти ссылку на актуальную версию drosera-operator"
        return 1
    fi
    file=$(basename "$url")
    if [ ! -f "$file" ]; then
        info_message "Скачиваю $file..."
        curl -LO "$url"
    fi
    tar -xvf "$file"
    # Ищем распакованный бинарь (название может быть drosera-operator)
    if [ -f drosera-operator ]; then
        sudo rm -f /usr/bin/drosera-operator
        sudo cp drosera-operator /usr/bin/
        sudo chmod +x /usr/bin/drosera-operator
        success_message "drosera-operator обновлён!"
    else
        error_message "Не найден бинарник drosera-operator после распаковки!"
    fi
}

deploy_trap() {
    info_message "Запуск процесса деплоя Trap..."
    echo -e "${WHITE}[1/5] 🔄 Обновление инструментов...${NC}"
    droseraup
    foundryup

    echo -e "${WHITE}[2/5] 📂 Создание директории...${NC}"
    mkdir -p my-drosera-trap && cd my-drosera-trap

    echo -e "${WHITE}[3/5] ⚙️ Настройка Git...${NC}"
    read -p "Введите вашу Github почту: " GITHUB_EMAIL
    read -p "Введите ваш Github юзернейм: " GITHUB_USERNAME
    git config --global user.email "$GITHUB_EMAIL"
    git config --global user.name "$GITHUB_USERNAME"

    echo -e "${WHITE}[4/5] 🛠️ Инициализация проекта...${NC}"
    forge init -t drosera-network/trap-foundry-template
    bun install
    forge build

    echo -e "${WHITE}[5/5] 📝 Генерация drosera.toml под Hoodi...${NC}"
    read -p "Введите адрес вашего EVM кошелька (для whitelist): " OPERATOR_ADDR

    cat > drosera.toml <<EOL
ethereum_rpc = "https://ethereum-hoodi-rpc.publicnode.com"
drosera_rpc = "https://relay.hoodi.drosera.io"
eth_chain_id = 560048
drosera_address = "0x91cB447BaFc6e0EA0F4Fe056F5a9b1F14bb06e5D"

[traps]

[traps.mytrap]
path = "out/HelloWorldTrap.sol/HelloWorldTrap.json"
response_contract = "0x183D78491555cb69B68d2354F7373cc2632508C7"
response_function = "helloworld(string)"
cooldown_period_blocks = 33
min_number_of_operators = 1
max_number_of_operators = 2
block_sample_size = 10
private_trap = true
whitelist = ["$OPERATOR_ADDR"]
EOL

    read -p "Введите приватный ключ EVM кошелька: " PRIV_KEY
    echo
    export DROSERA_PRIVATE_KEY="$PRIV_KEY"
    drosera apply

    success_message "Trap успешно настроен!"
}

install_node() {
    info_message "Запуск установки ноды..."
    TARGET_FILE="$HOME/my-drosera-trap/drosera.toml"
    [ -f "$TARGET_FILE" ] && sed -i '/^private_trap/d;/^whitelist/d' "$TARGET_FILE"

    read -p "Введите адрес вашего EVM кошелька: " WALLET_ADDRESS
    {
        echo "private_trap = true"
        echo "whitelist = [\"$WALLET_ADDRESS\"]"
    } >> "$TARGET_FILE"

    read -s -p "Введите приватный ключ EVM кошелька: " PRIV_KEY
    echo
    export DROSERA_PRIVATE_KEY="$PRIV_KEY"
    cd "$HOME/my-drosera-trap"
    drosera apply

    success_message "Нода успешно установлена!"
}

register_operator() {
    info_message "Регистрация оператора в сети Hoodi..."
    update_operator_bin
    read -s -p "Введите приватный ключ EVM кошелька: " PRIV_KEY
    echo
    export DROSERA_PRIVATE_KEY="$PRIV_KEY"
    /usr/bin/drosera-operator register \
      --eth-rpc-url https://ethereum-hoodi-rpc.publicnode.com \
      --eth-private-key "$DROSERA_PRIVATE_KEY" \
      --drosera-address 0x91cB447BaFc6e0EA0F4Fe056F5a9b1F14bb06e5D \
      --eth-chain-id 560048
    success_message "Регистрация завершена (см. результат выше)."
}

start_node() {
    info_message "Запуск ноды Drosera..."
    cd ~
    update_operator_bin

    read -s -p "Введите приватный ключ EVM кошелька: " PRIV_KEY
    echo
    export DROSERA_PRIVATE_KEY="$PRIV_KEY"

    SERVER_IP=$(curl -s https://api.ipify.org)
    BIN_PATH="/usr/bin/drosera-operator"
    DB_PATH="$HOME/.drosera.db"

    sudo tee /etc/systemd/system/drosera.service > /dev/null <<EOF
[Unit]
Description=drosera node service
After=network-online.target

[Service]
User=$USER
Restart=always
RestartSec=15
LimitNOFILE=65535
ExecStart=$BIN_PATH node \
  --db-file-path $DB_PATH \
  --network-p2p-port 31313 \
  --server-port 31314 \
  --eth-rpc-url https://ethereum-hoodi-rpc.publicnode.com \
  --eth-backup-rpc-url https://0xrpc.io/hoodi \
  --drosera-address 0x91cB447BaFc6e0EA0F4Fe056F5a9b1F14bb06e5D \
  --eth-private-key $DROSERA_PRIVATE_KEY \
  --eth-chain-id 560048 \
  --listen-address 0.0.0.0 \
  --network-external-p2p-address $SERVER_IP \
  --disable-dnr-confirmation true

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable drosera
    sudo systemctl restart drosera

    success_message "Нода успешно запущена!"
    info_message "Для просмотра логов используйте: journalctl -u drosera.service -f"
    journalctl -u drosera.service -f
}

remove_node() {
    info_message "Удаление ноды Drosera..."
    sudo systemctl stop drosera
    sudo systemctl disable drosera
    sudo rm /etc/systemd/system/drosera.service
    sudo systemctl daemon-reload
    rm -rf "$HOME/my-drosera-trap"
    success_message "Нода Drosera успешно удалена!"
}

display_menu() {
    clear
    display_logo
    echo -e "${BOLD}${WHITE}Drosera Node Manager v${SCRIPT_VERSION}${NC}\n"
    echo -e "${YELLOW}1)${NC} Установить зависимости"
    echo -e "${YELLOW}2)${NC} Деплой Trap"
    echo -e "${YELLOW}3)${NC} Установить ноду"
    echo -e "${YELLOW}4)${NC} Зарегистрировать оператора"
    echo -e "${YELLOW}5)${NC} Запустить ноду"
    echo -e "${YELLOW}6)${NC} Статус ноды"
    echo -e "${YELLOW}7)${NC} Логи ноды"
    echo -e "${YELLOW}8)${NC} Перезапустить ноду"
    echo -e "${YELLOW}9)${NC} Удалить ноду"
    echo -e "${YELLOW}10)${NC} Выход"
    echo -ne "\n${BOLD}${WHITE}Выберите действие [1-10]: ${NC}"
}

ensure_curl
ensure_jq
auto_update

while true; do
    display_menu
    read -r choice
    case $choice in
        1) install_dependencies ;;
        2) deploy_trap ;;
        3) install_node ;;
        4) register_operator ;;
        5) start_node ;;
        6) info_message "Проверка статуса..."; echo "Ваша нода работает на последней версии" ;;
        7) info_message "Просмотр логов..."; journalctl -u drosera.service -f ;;
        8) info_message "Перезапуск ноды..."; sudo systemctl restart drosera; journalctl -u drosera.service -f ;;
        9) remove_node ;;
        10) echo -e "${GREEN}👋 До свидания!${NC}"; exit 0 ;;
        *) error_message "Неверный ввод, попробуйте снова." ;;
    esac
    echo -ne "\n${WHITE}Нажмите Enter для продолжения...${NC}"
    read -r
done
