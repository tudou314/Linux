#!/bin/bash
#centos6/7 zabbix3.2.9_agent or 4
#2019.06.11

sys_release=$(cat /etc/redhat-release  | cut -d'.' -f1 | awk '{print $NF}')
ZBX_SRV_IP="127.0.0.1,172.16.16.28"
Host_ip=$(hostname -I | cut -d' ' -f1)
Err_sys_release=55
Zabbix_agent_exist=56

#配置时区信息
date_timezone_set (){
	ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
	if rpm -q ntpdate;then
		ntpdate ntp3.aliyun.com && clock -w
	else
		yum install ntpdate -y && ntpdate ntp3.aliyun.com && clock -w
	fi
}

#修改zabbix agent 配置
zbx_agent_conf (){
	sed -i "s%ServerActive=127.0.0.1%ServerActive=${ZBX_SRV_IP}%g" /etc/zabbix/zabbix_agentd.conf
	sed -i "s%Server=127.0.0.1%Server=${ZBX_SRV_IP}%g" /etc/zabbix/zabbix_agentd.conf
	#sed -i "s%Hostname=Zabbix server%Hostname=${HOSTNAME}%g" /etc/zabbix/zabbix_agentd.conf
}

#开启服务CentOS7环境
zbx_agent_on_7 (){
	systemctl enable zabbix-agent
	systemctl start zabbix-agent
}

#开启服务CentOS6环境
zbx_agent_on_6 (){
	chkconfig zabbix-agent on
	service zabbix-agent start
}

#设置FW，CentOS7环境
zbx_agent_fw_on_7 (){
	if rpm -q firewalld;then
		#图形界面 yum install firewall-config -y
		if systemctl status firewalld | grep -q "active (running)" ;then
			firewall-cmd --add-service=zabbix-agent --permanent
			firewall-cmd --reload
		fi
	fi
}

#设置FW，CentOS6环境
zbx_agent_fw_on_6 (){
	if rpm -q iptables ;then
		if /etc/init.d/iptables status | egrep -q "not running.";then
			echo "防火墙未开启，跳过"
			if ! grep -q "10050" /etc/sysconfig/iptables ;then
				iptables -I INPUT 4 -m state --state NEW -m tcp -p tcp --dport 10050 -j ACCEPT
				/etc/init.d/iptables save && /etc/init.d/iptables restart
				#默认情况下，插入位置
			fi
		fi
	fi
}

#判断zabbix agent是否已安装
if rpm -q zabbix-agent &>/dev/null;then
	echo "zabbix agent似乎已经安装，请检查" && exit ${Zabbix_agent_exist}
fi

echo "正在检查外网是否畅通"
ping -w2 -c2 mirrors.aliyun.com &>/dev/null && net_stat=yes || net_stat=no

#设置时间，时区
if [ ${net_stat} == yes ];then
	date_timezone_set
else 
	echo "请检查网络环境..." && exit ${Err_net}
fi

#检查系统版本
if [ ${sys_release} -eq 7 ] ;then
	timedatectl set-timezone Asia/Shanghai
	#rpm -ivh https://mirrors.aliyun.com/zabbix/zabbix/4.0/rhel/7/x86_64/zabbix-agent-4.0.9-3.el7.x86_64.rpm
    #rpm -ivh https://repo.zabbix.com/zabbix/3.2/rhel/7/x86_64/zabbix-agent-3.2.9-1.el7.x86_64.rpm
	#rpm -ivh http://repo.zabbix.com/zabbix/4.0/rhel/7/x86_64/zabbix-agent-4.0.9-3.el7.x86_64.rpm
    https://mirrors.aliyun.com/zabbix/zabbix/3.2/rhel/7/x86_64/zabbix-get-3.2.9-1.el7.x86_64.rpm
	zbx_agent_conf && zbx_agent_fw_on_7 && zbx_agent_on_7
elif [ ${sys_release} -eq 6 ] ;then
	:
	#rpm -ivh https://mirrors.aliyun.com/zabbix/zabbix/4.0/rhel/6/x86_64/zabbix-agent-4.0.9-3.el6.x86_64.rpm
	#rpm -ivh http://repo.zabbix.com/zabbix/4.0/rhel/6/x86_64/zabbix-agent-4.0.9-3.el6.x86_64.rpm
    rpm -ivh https://mirrors.aliyun.com/zabbix/zabbix/3.2/rhel/6/x86_64/zabbix-get-3.2.9-1.el6.x86_64.rpm
	zbx_agent_conf && zbx_agent_fw_on_6 && zbx_agent_on_6
else
	echo "请确认系统环境是CentOS" && exit ${Err_sys_release}
fi

echo -e "ZABBIX AGENT installation completed，LocalHost_IP=\e[42;37m\e[1m${Host_ip}\e[0m"
exit 0


