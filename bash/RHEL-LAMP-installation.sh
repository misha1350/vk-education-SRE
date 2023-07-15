#!/bin/bash

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
SSH_PORT=3578
REPLICAS=3
BASE_PORT=3306
BASE_DATA_DIR=/var/lib/mysql
BASE_SOCKET_PATH=/var/lib/mysql
BASE_ERROR_LOG_PATH=/var/log/mysqld
PHP_VER=8.2.8



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
  Try running '${YELLOW}sudo ./install.sh${NC}'."
  exit 1
fi

# Обновление системы
echo -e "${YELLOW}\tUpdating system packages${NC}"
# Ускорение загрузки пакетов, если это ограничение не было установлено пользователем ранее
if ! grep -q "^max_parallel_downloads=" /etc/dnf/dnf.conf; then
  echo "max_parallel_downloads=10" >> /etc/dnf/dnf.conf
fi
dnf update -y

# Установка и настройка Apache
echo -e "${YELLOW}\tInstalling Apache${NC}"
dnf install -y httpd
systemctl enable httpd
systemctl start httpd

# Установка и настройка PHP из исходного кода
echo -e "${YELLOW}\tInstalling PHP from source${NC}"
echo -e "${YELLOW}\tInstalling prerequisites${NC}"
dnf install -y gcc make autoconf automake libtool bison libxml2-devel openssl-devel policycoreutils \
libcurl-devel libjpeg-devel libpng-devel freetype-devel libicu-devel httpd-devel sqlite-devel re2c wget

if [ ! -f "php.tar.gz" ]; then
  echo -e "${YELLOW}\tDownloading PHP $PHP_VER source code${NC}"
  wget -O php.tar.gz https://www.php.net/distributions/php-$PHP_VER.tar.gz
fi

if [ ! -d "php-$PHP_VER" ]; then
  tar -xzf php.tar.gz
fi
cd php-$PHP_VER

if [ ! -f "Makefile" ]; then
  echo -e "${YELLOW}\tConfiguring PHP${NC}"
  ./configure --prefix=/usr/local/php --with-apxs2=/usr/bin/apxs --with-config-file-path=/etc \
  --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd
fi

if [ ! -f "sapi/cli/php" ]; then
  # Компиляция с использованием всех потоков процессора - команда nproc возвращает кол-во потоков
  echo -e "${YELLOW}\tCompiling PHP${NC}"
  make -j$(nproc)
  make test
fi

if ! /usr/local/php/bin/php -v > /dev/null 2>&1; then
  echo -e "${YELLOW}\tInstalling compiled PHP binaries${NC}"
  make install
fi

# Проверка на успешную установку PHP - если есть желание, то можно сделать дополнительную проверку на то, что
# версия PHP соответствует версии, которую мы хотели установить - или ниже её, если PHP уже был установлен на машине.
# Но скорее всего для идеальной совместимости, на сервер нужно ставить точно такую же версию PHP, с которой программисты
# работали на своих локальных машинах
echo -e "${YELLOW}\tChecking if PHP has been installed successfully${NC}"
if /usr/local/php/bin/php -v > /dev/null 2>&1; then
  echo -e "${GREEN}\tPHP has been installed successfully${NC}"
else
  echo -e "${RED}\tPHP installation failed! Try launching the script again.${NC}"
  sleep 15
fi


# Установка MySQL
echo -e "${YELLOW}\Installing MySQL${NC}"
dnf install -y @mysql

echo -e "${YELLOW}\tChanging SSH port to $SSH_PORT ${NC}"
# Изменение конфигурации SSH с использованием утилиты sed (Stream EDitor)
sed -i "s/^#Port 22/Port $SSH_PORT/" /etc/ssh/sshd_config
# Политику SELinux и Firewalld необходимо изменить, чтобы порт 3578 был разрешен для SSH
setenforce 0
sudo semanage port -a -t ssh_port_t -p tcp $SSH_PORT
firewall-cmd --permanent --add-port=$SSH_PORT/tcp
firewall-cmd --reload
systemctl restart sshd
setenforce 1

echo -e "${YELLOW}\tRemoving PHP archive${NC}"
rm -rf php.tar.gz php-8.2.8
echo -e "${YELLOW}\tRemove the binaries yourself with `rm -rf php-8.2.8`, if you wish to do so${NC}"

echo -e "${GREEN}\tComplete${NC}"




# for ((i=1; i<=$REPLICAS; i++))
# do
#     PORT=$(($BASE_PORT + $i))

#     # Set the data directory for this replica
#     DATA_DIR=$BASE_DATA_DIR-replica$i

#     # Set the socket file for this replica
#     SOCKET_FILE=$BASE_SOCKET_PATH-replica$i/mysql.sock

#     # Set the pid file for this replica
#     ERROR_LOG=$BASE_ERROR_LOG_PATH/mysqld-replica$i.pid

#     # Create the data directory for this replica if it doesn't exist
#     # if [ ! -d $DATA_DIR ]; then
#     #     mkdir -p $DATA_DIR
#     #     chown -R mysql:mysql $DATA_DIR
#     # fi

#     # Create a new section in the my.cnf file for this replica
#     echo "[mysqld@replica$i]" >> /etc/my.cnf
#     echo "port=$PORT" >> /etc/my.cnf
#     echo "datadir=$DATA_DIR" >> /etc/my.cnf
#     echo "socket=$SOCKET_FILE" >> /etc/my.cnf
#     echo "log-error=$ERROR_LOG" >> /etc/my.cnf
#     echo "" >> /etc/my.cnf
# done

# # # Restart MySQL to apply the changes
# systemctl restart mysqld.service


# # Создание директорий для данных и конфигурации каждого инстанса
# echo -e "${YELLOW}\Создание директорий для данных и конфигурации каждого инстанса${NC}"
# mkdir -p /var/lib/mysql1 /var/lib/mysql2 /var/lib/mysql3
# mkdir -p /etc/my1.cnf.d /etc/my2.cnf.d /etc/my3.cnf.d

# # Копирование основного файла конфигурации для каждого инстанса
# echo -e "${YELLOW}\Копирование основного файла конфигурации для каждого инстанса${NC}"
# cp /etc/my.cnf.d/* /etc/my1.cnf.d/
# cp /etc/my.cnf.d/* /etc/my2.cnf.d/
# cp /etc/my.cnf.d/* /etc/my3.cnf.d/

# # Изменение порта, сокета и директории данных в файле конфигурации для каждого инстанса
# echo -e "${YELLOW}\Изменение порта и директории данных в файле конфигурации для каждого инстанса${NC}"
# sed -i 's!datadir=/var/lib/mysql!datadir=/var/lib/mysql1!g' /etc/my1.cnf.d/community-mysql-server.cnf
# sed -i 's!datadir=/var/lib/mysql!datadir=/var/lib/mysql2!g' /etc/my2.cnf.d/community-mysql-server.cnf
# sed -i 's!datadir=/var/lib/mysql!datadir=/var/lib/mysql3!g' /etc/my3.cnf.d/community-mysql-server.cnf
# echo "Изменение пути к сокету в файле конфигурации для каждого инстанса"
# sed -i 's!^socket=.*!socket=/var/lib/mysql1/mysql.sock!g' /etc/my1.cnf.d/community-mysql-server.cnf
# sed -i 's!^socket=.*!socket=/var/lib/mysql2/mysql.sock!g' /etc/my2.cnf.d/community-mysql-server.cnf
# sed -i 's!^socket=.*!socket=/var/lib/mysql3/mysql.sock!g' /etc/my3.cnf.d/community-mysql-server.cnf
# sed -i 's/port=3306/port=3307/g' /etc/my1.cnf.d/community-mysql-server.cnf
# sed -i 's/port=3306/port=3308/g' /etc/my2.cnf.d/community-mysql-server.cnf
# sed -i 's/port=3306/port=3309/g' /etc/my3.cnf.d/community-mysql-server.cnf
# echo "port=3307" >> /etc/my1.cnf.d/community-mysql-server.cnf
# echo "port=3308" >> /etc/my2.cnf.d/community-mysql-server.cnf
# echo "port=3309" >> /etc/my3.cnf.d/community-mysql-server.cnf

# # Инициализация данных для каждого инстанса
# echo -e "${YELLOW}\Инициализация данных для каждого инстанса${NC}"
# # Данная команда ничего не делает
# mysqld --defaults-file=/etc/my.cnf.d/community-mysql-server.cnf --initialize-insecure

# # Создание systemd-файлов для каждого инстанса
# echo -e "${YELLOW}\Создание systemd-файлов для каждого инстанса${NC}"
# cp /usr/lib/systemd/system/mysqld.service /usr/lib/systemd/system/mysqld1.service
# cp /usr/lib/systemd/system/mysqld.service /usr/lib/systemd/system/mysqld2.service
# cp /usr/lib/systemd/system/mysqld.service /usr/lib/systemd/system/mysqld3.service
# sed -i 's!ExecStart=/usr/sbin/mysqld $MYSQLD_OPTS!ExecStart=/usr/sbin/mysqld $MYSQLD_OPTS --defaults-file=/etc/my1.cnf!' /usr/lib/systemd/system/mysqld1.service
# sed -i 's!ExecStart=/usr/sbin/mysqld $MYSQLD_OPTS!ExecStart=/usr/sbin/mysqld $MYSQLD_OPTS --defaults-file=/etc/my2.cnf!' /usr/lib/systemd/system/mysqld2.service
# sed -i 's!ExecStart=/usr/sbin/mysqld $MYSQLD_OPTS!ExecStart=/usr/sbin/mysqld $MYSQLD_OPTS --defaults-file=/etc/my3.cnf!' /usr/lib/systemd/system/mysqld3.service

# # Перезагрузка systemd и запуск всех трех инстансов MySQL
# echo -e "${YELLOW}\Перезагрузка systemd и запуск всех трех инстансов MySQL${NC}"
# systemctl daemon-reload
# systemctl start mysqld1
# systemctl start mysqld2
# systemctl start mysqld3

# # Изменение пароля для пользователя root для каждого инстанса
# echo -e "${YELLOW}\Изменение пароля для пользователя root для каждого инстанса${NC}"
# mysql --defaults-file=/etc/my1.cnf -e "ALTER USER 'root'@'localhost' IDENTIFIED BY 'password1';"
# mysql --defaults-file=/etc/my2.cnf -e "ALTER USER 'root'@'localhost' IDENTIFIED BY 'password2';"
# mysql --defaults-file=/etc/my3.cnf -e "ALTER USER 'root'@'localhost' IDENTIFIED BY 'password3';"












# # Some useful functions used in other MySQL helper scripts
# # This scripts defines variables datadir, errlogfile, socketfile

# export LC_ALL=C

# # extract value of a MySQL option from config files
# # Usage: get_mysql_option VARNAME DEFAULT SECTION [ SECTION, ... ]
# # result is returned in $result
# # We use my_print_defaults which prints all options from multiple files,
# # with the more specific ones later; hence take the last match.
# #get_mysql_option(){
# #       if [ $# -ne 3 ] ; then
# #               echo "get_mysql_option requires 3 arguments: section option default_value"
# #               return
# #       fi
# #       sections="$1"
# #       option_name="$2"
# #       default_value="$3"
# #       result=`/usr/bin/my_print_defaults $my_print_defaults_extra_args $sections | sed -n "s/^--${option_name}=//p" | tail -n 1`
# #       if [ -z "$result" ]; then
# #           # not found, use default
# #           result="${default_value}"
# #       fi
# #}

# # For the case of running more instances via systemd, scrits that source
# # this file can get --default-group-suffix or similar option as the first
# # argument. The utility my_print_defaults needs to use it as well, so the
# # scripts sourcing this file work with the same options as the daemon.
# #my_print_defaults_extra_args=''
# #while echo "$1" | grep -q '^--defaults' ; do
# #       my_print_defaults_extra_args="${my_print_defaults_extra_args} $1"
# #       shift
# #done

# # Defaults here had better match what mysqld_safe will default to
# # The option values are generally defined on three important places
# # on the default installation:
# #  1) default values are hardcoded in the code of mysqld daemon or
# #     mysqld_safe script
# #  2) configurable values are defined in /etc/my.cnf
# #  3) default values for helper scripts are specified bellow
# # So, in case values are defined in my.cnf, we need to get that value.
# # In case they are not defined in my.cnf, we need to get the same value
# # in the daemon, as in the helper scripts. Thus, default values here
# # must correspond with values defined in mysqld_safe script and source
# # code itself.

# server_sections="mysqld_safe mysqld server mysqld-8.0 client-server"

# #get_mysql_option "$server_sections"
# datadir="/var/lib/mysql1"
# #datadir="$result"

# # if there is log_error in the my.cnf, my_print_defaults still
# # returns log-error
# # log-error might be defined in mysqld_safe and mysqld sections,
# # the former has bigger priority
# #get_mysql_option "$server_sections" log-error "$datadir/`hostname`.err"
# errlogfile="/var/log/mysql1/mysqld.log"

# #get_mysql_option "$server_sections" socket "/var/lib/mysql/mysql.sock"
# socketfile="$datadir/mysql1.sock"

# #get_mysql_option "$server_sections" pid-file "$datadir/`hostname`.pid"
# pidfile="/var/run/mysqld1/mysqld.pid"
