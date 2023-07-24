#!/bin/bash

# Скрипт принимает целое число - кол-во реплик MySQL, которое необходимо развернуть в Docker-контейнерах.
# Каждая реплика использует около 400МБ ОЗУ.
REPLICAS=$1
if ! [[ "$REPLICAS" =~ ^[0-9]+$ ]]; then
  echo -e "${RED}ERROR:${NC} The provided value for REPLICAS is not an integer number."
  exit 1
fi

# Для отправки скрипта на удалённый сервер, достаточно подключиться к нему по SSH, 
# скопировать весь этот скрипт и вставить в окно терминала на своей локальной машине, с которым 
# подключились по SSH. Таким образом, можно даже не вводить команду scp и сэкономить некоторое время.

# Для того, чтобы этот скрипт выполнился, необходимо выполнить команду:
# chmod +x /путь/к/скрипту.sh

RED='\033[1;31m'
YELLOW='\033[1;33m'
GREEN='\033[1;32m'
FANCY_QUESTION='\033[43m\033[30m'
NC='\033[0m' # No Colour

DISTRO_NAME=$(grep '^NAME=' /etc/os-release | cut -d'=' -f2 | tr -d '"')
BASE_PORT=3306

is_notLinux() {
  case "$(uname -s)" in
  *Linux* ) false ;;
  * ) true ;;
  esac
}

is_notRPM() {
  if [ -d /etc/yum.repos.d ] || [ -x "$(command -v dnf)" ]; then
    false
  else
    true
  fi
}

# Проверка на то, что скрипт запущен на Linux
if is_notLinux; then
  echo -e "${RED}ERROR:${NC} Linux not detected."
  exit 1
fi

# Проверка на то, что скрипт запущен на RHEL-based системе
if is_notRPM; then
  echo -e "${FANCY_QUESTION}This script was made with RHEL-based systems in mind."
  echo -e "It may not work on your $DISTRO_NAME machine."
  echo -e "If you wish to continue, wait 15 seconds.${NC}"
  echo -e "${YELLOW}You may press Ctrl+C now to abort this script.${NC}"
  sleep 15
else
  echo -e "${GREEN}\tDetected: $DISTRO_NAME${NC}"
fi

# Проверка на выполнение скрипта с правами root-пользователя
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}ERROR:${NC} Script needs to be run as root. \
  Try running '${YELLOW}sudo ./filename.sh${NC}'."
  exit 1
fi

# Обновление системы
echo -e "${YELLOW}\tUpdating system packages${NC}"
# Ускорение загрузки пакетов, если это ограничение не было установлено пользователем ранее
if ! grep -q "^max_parallel_downloads=" /etc/dnf/dnf.conf; then
  echo "max_parallel_downloads=10" >> /etc/dnf/dnf.conf
fi
dnf update -y

# Установка Docker
echo -e "${YELLOW}\tInstalling Docker${NC}"
if ! grep -q "docker-ce-stable" /etc/yum.repos.d/docker-ce.repo 2> /dev/null; then
  dnf -y install dnf-plugins-core
  dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
fi
dnf install -y docker-ce docker-ce-cli containerd.io docker-compose nc
systemctl enable --now docker
docker --version
docker-compose --version

# Создание файла docker-compose.yml
cat > docker-compose.yml <<EOL
version: '3.8'
services:
EOL

for ((i=1;i<=REPLICAS;i++)); do
  cat >> docker-compose.yml <<EOL
  mysql$i:
    image: mysql:latest
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: password$i
      MYSQL_USER: user$i
      MYSQL_PASSWORD: password$i
    ports:
      - "$((BASE_PORT + i)):3306"
EOL
done


# Запуск контейнеров через Docker Compose
docker-compose up -d

# Проверка доступности контейнеров
for ((i=1;i<=REPLICAS;i++)); do 
    port=$((BASE_PORT + i))
    if nc -zv localhost $port; then 
        echo -e "${GREEN}MySQL instance on port $port is running and accessible${NC}" 
    else 
        echo -e "${RED}ERROR:${NC} MySQL instance on port $port is not accessible" 
    fi 
done 
