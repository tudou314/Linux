#!/bin/bash
#
#2019-09-12
#ftp-auto-sh

HOST='172.16.16.8'
USER='waresoft'
read -p 'Enter password: ' PASSWD
#PASSWD='password'

ftp -i -n $HOST <<EOF
user ${USER} ${PASSWD}
binary
ls
get xendesktop-server-ip.txt
put auto_find_open_port.txt
quit
EOF
