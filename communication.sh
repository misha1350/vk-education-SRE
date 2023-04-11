#!/bin/bash
# Вместо статически указанного IP-адреса ниже, я взял бы IP-адрес сервера-хоста через 
# утилиту ifconfig, однако в последний раз, когда я проверял её наличие на сервере,
# её не было. Проверить возможности нет, но выглядело бы это примерно вот так:
# IP=$(ifconfig | grep 'inet'| grep -v '0.0.0.0' | grep 'broadcast' | head -1 | cut -d: -f2 | awk '{print $2}')

touch /var/log/incoming.txt
tee /var/log/incoming.txt > /dev/null <<EOF
This is a file that was sent over the network from $IP
EOF

rsync -avz /var/log/testfile.txt 192.168.3.35:/tmp/log

# Ключи были бы созданы заранее
ssh admini@192.168.3.35 find /tmp/log -type f -mtime +7 -exec rm {} \;

# После этого, можно создать cronjob, который будет запускать этот скрипт каждый день, например, в 3:00 ночи:
# 0 3 * * * /home/admini/scripts/communication.sh