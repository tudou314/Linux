#!/bin/bash
#CentOS7优化
#tudou314
#2019-09-12


#[ $(id -u) != "0" ] && echo "必须是 root 权限!" && exit 1
if [ $(id -u) -ne  0 ] ;then
        echo "必须是 root 权限!" && exit 1
fi

#检查系统版本
if ! cat /etc/redhat-release  | cut -d'.' -f1 | egrep -q 7 ;then
	echo "请确认系统环境是CentOS7" && exit 2
fi

#Host_IP=$(ip addr|grep "inet " | grep -v 127.0.0.1 | awk '{print $2}'|cut -d/ -f1)
Date=$(date +%F_%T)
Echo_net_err="\e[5m\e[1m 外网无法访问！\e[0m"

Test_net (){
    echo -e "\n 请稍等，正在检测网络环境..."
    ping -w2 -c2 223.5.5.5 &>/dev/null && net_stat=yes || net_stat=no
    if [ ${net_stat} = "no" ];then
        echo "外网IP：223.5.5.5 无法访问，安装程序需要时访问网络"
        sleep 5
    fi
}
Test_net

Install_EPEL (){
    if rpm -q epel-release >/dev/null ;then
        echo -e "\e[5m\e[1m epel源已安装！\e[0m"
    else
        if [ ${net_stat} == "yes" ];then
            yum install -y epel-release
        else 
            echo -e ${Echo_net_err}
        fi
    fi
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
    示例(重点IP,掩码,网关):
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
    if [ ${net_stat} == "yes" ];then
        read -p "输入需要安装的程序包，空格隔开：" Package
        yum install -y ${Package}
    else 
        echo -e ${Echo_net_err}
    fi
}

Set_date_timezone (){
    if [ ${net_stat} == "yes" ];then
        timedatectl set-timezone Asia/Shanghai
        if rpm -q ntpdate;then
            ntpdate ntp3.aliyun.com && clock -w
        else
            yum install ntpdate -y && ntpdate ntp3.aliyun.com && clock -w
        fi
    else 
        echo -e ${Echo_net_err} 
    fi
}

Set_aliyun_repofile (){
    cd /etc/yum.repos.d
    RepoFile=$(ls /etc/yum.repos.d | grep -v "epel")
    
    if [ ${net_stat} == "yes" ];then
        if [ ! -f CentOS7-Base-Aliyun.repo ] ;then
                for File in ${RepoFile}
                do
                    mv $File ${File}.bak
                    #echo $File
                    #sleep 1
                done
        curl -o /etc/yum.repos.d/CentOS7-Base-Aliyun.repo http://mirrors.aliyun.com/repo/Centos-7.repo && \
        yum clean all && yum makecache 
        else
            echo -e "\e[5m\e[1m阿里云repo已配置！\e[0m"
        fi
    else
        echo -e ${Echo_net_err}
    fi     
}

Set_firewalld (){
    Switch_firewalld(){
        read -p "输入需要放行的端口(如: 80/tcp 或 161/udp)：" On_port
        firewall-cmd --permanent --add-port=${On_port} && \
        firewall-cmd --reload
    }

    if [ ${net_stat} == "yes" ];then
        if ! rpm -q firewalld >/dev/null ;then
            yum install -y firewalld
        fi
       
        if firewall-cmd --state ;then
            Switch_firewalld
        else
            systemctl start firewalld && systemctl enable firewalld 
            Switch_firewalld
        fi
    else 
        echo -e ${Echo_net_err}
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
        #    8. 同步时间及时区                            ##
        #    9. 配置yum源repo文件为阿里云                 ##
        #    10. 放行防火墙端口                           ##
        #    11. 按q键退出优化                            ##
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
        9)
            Set_aliyun_repofile
            ;;
        10)
            Set_firewalld
            ;;
        q|11)
            echo -e "\e[5m\e[1m 退出脚本！\e[0m \n" 
            exit 0
            ;;
        *)
            echo -e "\e[5m\e[1m无效内容，选择优化项(如:2)或者退出(q)！\e[0m"
            ;;
    esac
done


