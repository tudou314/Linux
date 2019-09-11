#!/bin/bash
#Centos7 zabbix4_server lamp
#Centos7最小化安装完成以后执行
#tudou314
#2019.06.11

Host_ip="$(hostname -I | cut -d' ' -f1)"
Zabbix_web_exist=55
Err_net=56
Err_zabbix_conf=57
Err_db=58
Err_listen_port=59
Err_sys_release=60

#配置时区信息
date_timezone_set (){
	timedatectl set-timezone Asia/Shanghai
	if rpm -q ntpdate;then
		ntpdate ntp3.aliyun.com && clock -w
	else
		yum install ntpdate -y && ntpdate ntp3.aliyun.com && clock -w
	fi
}

#zabbix repo仓库
zabbix_repo_install (){
	rpm -ivh https://mirrors.aliyun.com/zabbix/zabbix/4.0/rhel/7/x86_64/zabbix-release-4.0-1.el7.noarch.rpm
	if [ -f /etc/yum.repos.d/zabbix.repo ];then
		sed -i 's$http://repo.zabbix.com$https://mirrors.aliyun.com/zabbix$g' /etc/yum.repos.d/zabbix.repo
	fi
}

#zabbix web前端先决条件
zabbix_web_pre (){
	rpm -q yum-utils && res=yes || res=no
	if [ "$res" == yes ];then
		yum-config-manager --enable rhel-7-server-optional-rpms
	else
		yum install yum-utils -y && yum-config-manager --enable rhel-7-server-optional-rpms
	fi
}

#安装zabbix server端及数据库
zabbix_server_install () {
	yum install -y zabbix-server-mysql zabbix-web-mysql zabbix-agent zabbix-get mariadb mariadb-server 
}

#安装数据库
#mariadb_install (){
#	yum install -y  mariadb mariadb-server
#}

#开启数据库
mariadb_start (){
	systemctl enable mariadb
	systemctl start mariadb
}

#创建数据库
zabbix_db_create (){
	mysql -uroot  <<EOF
	create database if not exists zabbix character set utf8 collate utf8_bin;
	grant all privileges on zabbix.* to zabbix@localhost identified by 'zabbix';
	quit
EOF
	mysqladmin -uroot password 'zabbix'
}

#导入zabbix数据库
zabbix_db_import (){
	Zabbix_release=$(rpm -aq zabbix-server-mysql | cut -d'-' -f4)
	#echo "${Zabbix_release}"
	zcat /usr/share/doc/zabbix-server-mysql-${Zabbix_release}/create.sql.gz | mysql -uzabbix -pzabbix zabbix
}

#配置文件 zabbix.conf
zabbix_conf (){
	sed -i 's%# DBPassword=%DBPassword=zabbix%g' /etc/zabbix/zabbix_server.conf
	#sed -i 
}

#配置php.ini
php_ini_conf (){
	if egrep -n "Asia/Shanghai" /etc/php.ini ;then
		echo "php.ini的时区已经配置."
	else
		sed -i 's%;date.timezone =%date.timezone = Asia/Shanghai%g' /etc/php.ini
	fi
}

#防火墙及selinux配置
fw_selinux_set (){
	yum install -y policycoreutils-python
	setenforce 1
	semanage permissive -a zabbix_t
	# setsebool -P httpd_can_connect_zabbix on
	systemctl enable firewalld
	systemctl start firewalld
	firewall-cmd --add-service=http --permanent
    firewall-cmd --add-port=10051/tcp --permanent
    #yum install firewalld -y
	#firewall-cmd --add-service=zabbix-server --permanent
	firewall-cmd --reload
}

#开启服务
zabbix_service (){
	systemctl enable httpd
	systemctl start httpd
	systemctl enable zabbix-server
	systemctl start zabbix-server
	systemctl enable zabbix-agent
	systemctl start zabbix-agent
}

#判断zabbix服务端是否已安装
if rpm -q zabbix-server-mysql zabbix-web-mysql &>/dev/null;then
	echo "zabbix服务端似乎已经安装，请再次确认。或重置环境后重新安装" && exit ${Zabbix_web_exist}
fi

#检查系统版本
if ! cat /etc/redhat-release  | cut -d'.' -f1 | egrep -q 7 ;then
	echo "请确认系统环境是CentOS7" && exit ${Err_sys_release}
fi

echo "正在检查外网是否畅通"
ping -w2 -c2 223.5.5.5 &>/dev/null && net_stat=yes || net_stat=no

#设置时间，时区
if [ ${net_stat} == yes ];then
	date_timezone_set
else 
	echo "请检查网络环境..." && exit ${Err_net}
fi

#安装zabbix包及相关软件
if rpm -q zabbix-release;then 
	zabbix_web_pre && zabbix_server_install 
else 
	zabbix_repo_install && zabbix_web_pre && zabbix_server_install 
fi

#配置zabbix连接数据库密码
if [ -f /etc/zabbix/zabbix_server.conf ];then
	zabbix_conf
else
	echo "请检查/etc/zabbix/zabbix_server.conf文件是否存在" && exit ${Err_zabbix_conf}
fi

#创建导入zabbix数据库
rpm -q mariadb-server mariadb &>/dev/null
if [ $? -eq 0 ];then
	mariadb_start && zabbix_db_create && zabbix_db_import
else
	echo "请检查数据库启动及创建情况" && exit ${Err_db}
fi

#开启相关服务及配置防火墙，selinux
rpm -q httpd zabbix-web-mysql &>/dev/null
if [ $? -eq 0 ] ;then
	zabbix_conf && php_ini_conf && fw_selinux_set && zabbix_service
	setsebool -P httpd_can_connect_zabbix on
fi

#web打开，进行下一步设置
if ss -tnlp | grep -q "zabbix_server" && ss -tnlp | grep -q "httpd" ;then
	echo -e "
------------------------------------------------------------+    
|   zabbix已完成安装配置                                    |
|   浏览器打开：\e[42;37m\e[1mhttp://${Host_ip}/zabbix\e[0m |
|   进入下一步设置                                          |
------------------------------------------------------------+
"
else
	echo "请检查服务是否启动，端口侦听是否正常" && exit ${Err_listen_port}
fi

#卸载：yum remove zabbix-web-mysql zabbix-server-mysql mariadb-server httpd php -y
#1、注意设置数据库root密码
#2、注意如需中文显示，需要修改绘图时中文显示的字体

exit 0



