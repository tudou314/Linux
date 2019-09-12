#!/bin/bash
#CentOS7优化
#tudou314
#2019-09-12


Host_IP=$(ip addr|grep "inet "|grep -v 127.0.0.1|awk '{print $2}'|cut -d/ -f1)
Date=$(date +%F_%T)

Install_EPEL (){
    yum install -y epel-release
}

Close_selinux (){
    sed -i "s/SELINUX=enforcing/SELINUX=permissive/"  /etc/selinux/config
    setenforce 0
    echo "SElinux 已关闭！"
}

Set_Hostname (){
    HostName=$(hostname)
    read -p"Set hostname (default hostname: ${HostName}): " HOSTNAME
    hostnamectl set-hostname ${HOSTNAME:-$(hostname)}
    echo "主机名设置为：$(hostname)"
}

Set_IP (){
    Host_conf=$(find /etc/sysconfig/network-scripts/ -type f -name "ifcfg-*" \
    | grep -v "lo" | grep -v ".*\.bak" | sort | head -1 | xargs basename)
    Device=$(echo ${Host_conf} |  cut -d'-' -f2)
    echo "
    E.g:
        TYPE=Ethernet
        DEVICE=${Device}
        BOOTPROTO=static
        IPADDR=172.31.2.2
        NETMASK=255.255.0.0
        GATEWAY=172.31.0.1
        DNS1=223.5.5.5
        ONBOOT=yes
        NAME=${Device}
    "
    read -p 'Any key to continue: '
    vi /etc/sysconfig/network-scripts/${Host_conf}
}

Add_user (){
    User_list="/root/Add_user.txt"
    read -p '输入用户名：' User_name
    id ${User_name} &> /dev/null
    if [ $? -eq 0 ];then
        echo "用户 ${User_name} 已存在。" #&& exit 5
    else
        read -p '设置密码：' User_passwd
        useradd ${User_name} && echo "${User_passwd}" | passwd --stdin ${User_name} \
        && echo -e "\n \n ${Date} \n ${User_name}/${User_passwd}" >> ${User_list} && echo -e "用户 ${User_name} 创建成功，查看 \e[1m\e[41m${User_list}\e[0m"
    fi
}

Set_sudo (){
    read -p '输入需要sudo权限的用户名：' Sudo_user
    id ${Sudo_user} &>/dev/null 
    if [ $? -eq 0 ] ;then
        echo "${Sudo_user}  ALL=(ALL)   NOPASSWD: ALL " >> /etc/sudoers && echo "sudo用户 ${Sudo_user} 添加成功"
    else
        echo "用户 ${Sudo_user} 不存在！"
    fi
}

Yum_package (){
    read -p "输入需要安装的程序包，空格隔开：" Package
    yum install -y ${Package}
}

Set_date_timezone (){
	timedatectl set-timezone Asia/Shanghai
	if rpm -q ntpdate;then
		ntpdate ntp3.aliyun.com && clock -w
	else
		yum install ntpdate -y && ntpdate ntp3.aliyun.com && clock -w
	fi
}

while :;
do
    #clear
    echo -e "\n \e[1m\e[31m
        ####################################################
        #    1. 配置首个网卡静态IP地址(ethx)              ##
        #    2. 设置主机名                                ##    
        #    3. 关闭SElinux                               ##
        #    4. 安装EPEL源                                ##
        #    5. 添加系统用户                              ##
        #    6. 授权sudo用户(sudo执行无需密码)            ##
        #    7. 安装程序包，支持多个                      ##
        #    8. 同步时间及时                              ##
        #    9. 按q键退出优化                             ##
        ####################################################
        \e[0m 
    "
    read -p '按q键退出，选择优化项: ' Select
    echo ""
    #read -p '选择优化项：' Select
    case $Select in
        1)
            Set_IP
            ;;
        2)
            Set_Hostname
            ;;
        3)
            Close_selinux
            ;;
        4)
            Install_EPEL
            ;;
        5)
            Add_user
            ;;
        6)
            Set_sudo
            ;;
        7)
            Yum_package
            ;;
        8)
            Set_date_timezone
            ;;
        q|9)
            echo -e "\e[1m 退出脚本！\e[0m \n" 
            exit 0
            ;;
        
        *)
            echo -e "\e[5m\e[1m无效内容，选择优化项(如:2)或者退出(q)！\e[0m"
            ;;
    esac
done


