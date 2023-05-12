#!/bin/bash

# Скрипт установки

# [1]
RED='\033[1;31m'
YELLOW='\033[1;33m'
GREEN='\033[1;32m'
FANCY_QUESTION='\033[43m\033[30m'
NC='\033[0m' # No Colour

is_notLinux() {
  case "$(uname -s)" in
  *Linux* ) false ;;
  * ) true ;;
  esac
}

is_notDebian() {
  case "$(uname -v)" in
  *Debian* ) false ;;
  * ) true ;;
  esac
}

# [2]
if is_notLinux; then
  echo -e "${RED}ERROR:${NC} Linux not detected."
  exit 1
fi

# [3]
if is_notDebian; then
  echo -e "${YELLOW}This script was made with Debian in mind."
  echo -e "If you wish to continue, wait 10 seconds.${NC}"
  echo -e "You may press Ctrl+C now to aboirt this script."
  sleep 10
fi

# [4]
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}ERROR:${NC} Script needs to be run as root. \
  Try using 'sudo ./install.sh'."
  exit 1
fi

# Обновляем систему
echo -e "${YELLOW}\tUpdating system packages ${NC}"
apt update -y && apt upgrade -y

# [5] 
echo -e "${YELLOW}\tInstalling Docker, Ansible ${NC}"
apt install -y docker.io python3
pip3 install ansible docker

# [6] Unsure if needed
echo -e "${FANCY_QUESTION}Do you wish to attempt to add non-root permissions for Docker?"
echo -e "This is needed for Ansible to work properly, but is a security risk. [y/n]${NC}"
read -r PROMPT
if [[ $PROMPT =~ [yY](es)* ]]; then
  echo -e "${YELLOW}Adding non-root permissions for Docker for this user${NC}"
  usermod -aG docker $USER
  echo -e "${YELLOW}It is required that you REBOOT your system for the changes to take effect.${NC}"
fi

# [7] 
echo -e "${GREEN}Now execute playbook.yml with"
echo -e "'ansible-playbook playbook.yml'${NC}"

# docker run --name example-postgres -e POSTGRES_USER=user \
# -e POSTGRES_PASSWORD=1234 -e POSTGRES_DB=session5 \
# -e POSTGRES_ROOT_PASSWORD=123qwe -v postgres_data:/var/lib/postgresql/data \
# -v postgres_config:/etc/postgresql -dp 5432:5432 postgres

# [8]
# if test "$ID" = "debian" -o "$ID_LIKE" = "debian" -o "$ID" = "linuxmint"; then
# apt update && apt upgrade
# apt install -y docker ansible

# elif test "$ID" = "manjaro" -o "$ID" = "arch" -o "$ID_LIKE" = "arch"; then
# pacman -Syyu
# pacman -S --needed docker ansible

# elif test "$ID" = "opensuse-tumbleweed" -o "$ID_LIKE" = "opensuse suse"; then
# zypper refresh
# zypper install docker ansible

# elif test "$ID" = "fedora" -o "$ID" = "nobara"; then
# dnf install docker ansible 
 
# else
#   echo "${RED}ERROR:${NC} Your distribution is not supported."
#   exit 1
# fi
