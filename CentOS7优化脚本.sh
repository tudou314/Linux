#!/bin/bash
#CentOS7优化
#tudou314
#2019-03-13


#[ $(id -u) != "0" ] && echo "必须是 root 权限!" && exit 1
if [ $(id -u) -ne  0 ] ;then

        echo "必须是 root 权限!" && exit 1
fi

#检查系统版本
if ! cat /etc/redhat-release  | cut -d'.' -f1 | egrep -q 7 ;then
	echo "请确认系统环境是CentOS7" && exit 2
fi

#Host_IP=$(ip addr|grep "inet " | grep -v 127.0.0.1 | awk '{print $2}'|cut -d/ -f1)
Host_ip=$(hostname -I | cut -d' ' -f1)
Date=$(date +%F_%T)
Echo_net_err="\e[5m\e[1m 阿里云域名无法访问，请检查网络！\e[0m"

Check_net (){
    echo -e "\n 请稍等，正在检测网络环境..."
    ping -w3 -c3 aliyun.com &>/dev/null && net_stat=yes || net_stat=no
    if [ ${net_stat} = "no" ];then
        echo -e "\e[1m外网IP：223.5.5.5 无法访问，安装程序需要时访问网络!\e[0m"
        sleep 4
    fi
}
Check_net 

Install_EPEL (){
    #if rpm -q epel-release >/dev/null ;then
    if [ -f /etc/yum.repos.d/epel.repo ] ;then
        echo -e "\e[5m\e[1m epel源已安装！\e[0m"
    else
        if [ ${net_stat} == "yes" ];then
            #yum install -y epel-release
            curl -o /etc/yum.repos.d/epel.repo http://mirrors.aliyun.com/repo/epel-7.repo && \
            echo -e "\e[5m\e[1mepel源安装完成！\e[0m"
        else 
            echo -e ${Echo_net_err}
        fi
    fi
}

Close_selinux (){
    sed -i "s/SELINUX=enforcing/SELINUX=permissive/"  /etc/selinux/config
    setenforce 0
    echo -e "\e[5m\e[1mSElinux 已关闭！\e[0m"
}

Set_Hostname (){
    HostName=$(hostname)
    read -p"Set hostname (Default: ${HostName}): " HOSTNAME
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

Update_sys (){
    #vi /etc/yum.conf  在[main]的最后添加
    #exclude=kernel*  
    #exclude=centos-release*
    grep -q '^exclude=centos-release' /etc/yum.conf && grep -q '^exclude=kernel' /etc/yum.conf
    if [ $? -ne 0 ];then
        sed -i '/\[main\]/a\exclude=kernel*' /etc/yum.conf &&  sed -i '/\[main\]/a\exclude=centos-release*' /etc/yum.conf  && \
        echo -e "\e[5m\e[1m已设置排除内核更新！\e[0m"
    fi
    
    read -p "选择是否开始更新(y|n)；"  Cha_update
    case ${Cha_update} in
        y|Y)
            yum update ;;
        n|N)
            echo -e "\e[5m\e[1m已选择跳过升级程序包！\e[0m" ;;
         *)
            echo -e "\e[5m\e[1m输入错误！\e[0m" ;;
    esac
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
    
    if [ ${Sudo_user} ];then        
        id ${Sudo_user} &>/dev/null && User_exist=yes || User_exist=no
        
        if [ ${User_exist} == "yes" ] ;then
            #grep "^\${Sudo_user}.*ALL$" /etc/sudoers
            if egrep -v "#|^$" /etc/sudoers | grep "ALL[ ]*$" | grep ${Sudo_user} ;then
                echo -e "\e[5m\e[1msudo用户 ${Sudo_user} 已存在！\e[0m"
            else
                echo "${Sudo_user}  ALL=(ALL)   NOPASSWD: ALL" >> /etc/sudoers && echo "sudo用户 ${Sudo_user} 添加成功"
            fi
        else
            echo -e "\e[5m\e[1m用户 ${Sudo_user} 不存在！\e[0m"
        fi
    else
        echo -e "\e[5m\e[1m未输入！\e[0m"
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
    RepoFile=$(ls /etc/yum.repos.d | grep -v "epel" | grep -v ".*\.bak")
    
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
    cd - >/dev/null
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

Install_clamav (){
    Detect_clamav (){
        read -p "输入要查杀的目录(如：/var )：" Detect_doc
        echo "更新程序中..."
        freshclam && clamscan -vri "${Detect_doc:-'/etc'}" -l /tmp/clamscan-$(date +%F).log && \
        echo -e "\e[1m可查看文件 /tmp/clamscan-$(date +%F).log \e[0m"
     }
     
    if [ ${net_stat} == "yes" ];then
        if rpm -q clamav >/dev/null ;then
            Detect_clamav
            #echo -e "\e[5m\e[1mClamAV 已经安装！\e[0m"
        else
            yum install -y epel-release && yum install -y clamav
            Detect_clamav
        fi
    else 
            echo -e ${Echo_net_err}
    fi
}

Install_zabbix_agent (){
#    sys_release=$(cat /etc/redhat-release  | cut -d'.' -f1 | awk '{print $NF}')
    ZBX_SRV_IP="127.0.0.1,172.16.16.28"
#    Host_ip=$(hostname -I | cut -d' ' -f1)
#    Err_sys_release=55
#    Zabbix_agent_exist=56

    #配置时区信息
    date_timezone_set (){
        #ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
        timedatectl set-timezone Asia/Shanghai
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

    #设置FW，CentOS7环境
    zbx_agent_fw_on_7 (){
        if rpm -q firewalld;then
            #图形界面 yum install firewall-config -y
            if systemctl status firewalld | grep -q "active (running)" ;then
                #firewall-cmd --add-service=zabbix-agent --permanent
                firewall-cmd --add-port=10050/tcp --permanent
                firewall-cmd --reload
            fi
        fi
    }

    #判断zabbix agent是否已安装
    if rpm -q zabbix-agent &>/dev/null;then
        echo -e "\e[5m\e[1mzabbix agent似乎已经安装，请检查配置! \e[0m" #&& exit ${Zabbix_agent_exist}
        echo "------------------------------------------------------------"
        continue
    else
        date_timezone_set  && \
        rpm -ivh https://mirrors.aliyun.com/zabbix/zabbix/3.2/rhel/7/x86_64/zabbix-agent-3.2.9-1.el7.x86_64.rpm && \
        zbx_agent_conf && zbx_agent_fw_on_7 && zbx_agent_on_7 && \
        echo -e "\e[5m\e[1mZabbix客户端安装完成！\e[0m"
    fi
}

Set_motd (){
    Check_motd=$(wc -w /etc/motd | cut -d' ' -f1)
    if [ ${Check_motd} -eq 0 ] ;then
        read -p "输入系统登录后提示语(默认为主机名与IP地址)：" Host_motd
        if [ yes"${Host_motd}" != yes ];then
            echo "
            ###############################
            ##
            ##       ${Host_motd}
            ##                  
            ##                  
            ###############################
            " >/etc/motd && \
            echo -e "\e[5m\e[1m自定义登录提示语添加成功！\e[0m" && \
            cat /etc/motd
        else
            echo "

            ###############################
            ##          
            ##       $(hostname)
            ##       ${Host_motd:-$(hostname -I | cut -d' ' -f1)}
            ##                  
            ##                  
            ###############################
            " >/etc/motd && \
            echo -e "\e[5m\e[1m默认登录提示语添加成功！\e[0m" && \
            cat /etc/motd
        fi
    else
        echo -e "\e[5m\e[1m登录提示语已存在！\e[0m" && \
        cat /etc/motd 
    fi
}

Anti_crack_sshd (){
    if [ ${net_stat} == "yes" ];then
        if [ -f /etc/init.d/daemon-control-denyhosts ] ;then
            echo -e "
                \e[1m防暴力破解程序Denyhosts已经安装！
            如需重新安装请删除 /etc/init.d/daemon-control-denyhosts 
            以及 /usr/share/denyhosts等文件
            \e[0m"
        else
            wget -O DenyHosts-2.6.tar.gz -c -t 3 'https://sourceforge.net/projects/denyhosts/files/latest/download'  && \
            tar zxvf DenyHosts-2.6.tar.gz && \
            cd DenyHosts-2.6 && \
            python setup.py install && \
            cd /usr/share/denyhosts/ && \
            cp denyhosts.cfg-dist denyhosts.cfg && \
            cp daemon-control-dist daemon-control && \
            ln -s /usr/share/denyhosts/daemon-control /etc/init.d/daemon-control-denyhosts && \
            sed -i 's/DENY_THRESHOLD_ROOT = 1/DENY_THRESHOLD_ROOT = 6/g' /usr/share/denyhosts/denyhosts.cfg && \
            sed -i 's/HOSTNAME_LOOKUP=YES/HOSTNAME_LOOKUP=NO/g' /usr/share/denyhosts/denyhosts.cfg && \
            /etc/init.d/daemon-control-denyhosts start && \
            echo -e "\e[5m\e[1m防暴力破解程序Denyhosts安装成功！/etc/init.d/daemon-control-denyhosts \e[0m" || echo -e "\e[5m\e[1m安装失败，请查看原因！\e[0m"
        fi
    else 
                echo -e ${Echo_net_err}
    fi
}

System_info (){
sysversion=$(rpm -q centos-release|cut -d- -f3)
line="
-------------------------------------------------
"
#[ -d logs ] || mkdir logs
#Syslogs=sysinfo-logs
#mkdir -p ${Syslogs}
#sys_check_file="${Syslogs}/$(ip a show dev eth0|grep -w inet|awk '{print $2}'|awk -F '/' '{print $1}')-`date +%Y%m%d`.txt"
sys_check_file="$(ip a show dev eth0|grep -w inet|awk '{print $2}'|awk -F '/' '{print $1}')-`date +%Y%m%d`.txt"
    
# 获取系统cpu信息
function get_cpu_info() {
    Physical_CPUs=$(grep "physical id" /proc/cpuinfo| sort | uniq | wc -l)
    Virt_CPUs=$(grep "processor" /proc/cpuinfo | wc -l)
    CPU_Kernels=$(grep "cores" /proc/cpuinfo|uniq| awk -F ': ' '{print $2}')
    CPU_Type=$(grep "model name" /proc/cpuinfo | awk -F ': ' '{print $2}' | sort | uniq)
    CPU_Arch=$(uname -m)
    #cat <<EOF
    echo "
CPU信息:

物理CPU个数: $Physical_CPUs
逻辑CPU个数: $Virt_CPUs
每CPU核心数: $CPU_Kernels
CPU型号: $CPU_Type
CPU架构: $CPU_Arch
    "
}

# 获取系统内存信息
function get_mem_info() {
    check_mem=$(free -m)
    MemTotal=$(grep MemTotal /proc/meminfo| awk '{print $2}')  #KB
    MemFree=$(grep MemFree /proc/meminfo| awk '{print $2}')    #KB
    let MemUsed=MemTotal-MemFree
    MemPercent=$(awk "BEGIN {if($MemTotal==0){printf 100}else{printf \"%.2f\",$MemUsed*100/$MemTotal}}")
    report_MemTotal="$((MemTotal/1024))""MB"        #内存总容量(MB)
    report_MemFree="$((MemFree/1024))""MB"          #内存剩余(MB)
    report_MemUsedPercent="$(awk "BEGIN {if($MemTotal==0){printf 100}else{printf \"%.2f\",$MemUsed*100/$MemTotal}}")""%"   #内存使用率%
    
    echo "
内存信息(MB)：
${check_mem}
"
}

# 获取系统网络信息
function get_net_info() {
    pri_ipadd=$(ip a show dev eth0|grep -w inet|awk '{print $2}'|awk -F '/' '{print $1}')
    #pub_ipadd=$(curl ifconfig.me -s)
    gateway=$(ip route | grep default | awk '{print $3}')
    mac_info=$(ip link| egrep -v "lo"|grep link|awk '{print $2}')
    dns_config=$(egrep -v "^$|^#" /etc/resolv.conf)
    route_info=$(ip route)
    #route_info=$(route -n)
    echo "
IP信息:

系统公网地址: ${pub_ipadd}
系统私网地址: ${pri_ipadd}
网关地址: ${gateway}
MAC地址: ${mac_info}

路由信息:
${route_info}

DNS 信息:
${dns_config}
"
}

# 获取系统磁盘信息
function get_disk_info() {
    disk_info=$(fdisk -l|grep "Disk /dev"|cut -d, -f1)
    disk_use=$(df -hTP|awk '$2!="tmpfs"{print}')
    disk_inode=$(df -hiP|awk '$1!="tmpfs"{print}')
    
    echo "
磁盘信息:
${disk_info}

磁盘使用:
${disk_use}

inode信息:
${disk_inode}
    "
}

# 获取系统信息
function get_systatus_info() {
    sys_os=$(uname -o)
    sys_release=$(cat /etc/redhat-release)
    sys_kernel=$(uname -r)
    sys_hostname=$(hostname)
    sys_selinux=$(getenforce)
    sys_lang=$(echo $LANG)
    sys_lastreboot=$(who -b | awk '{print $3,$4}')
    sys_runtime=$(uptime |awk '{print  $3,$4}'|cut -d, -f1)
    sys_time=$(date)
    sys_load=$(uptime |cut -d: -f5)

    echo "
系统信息:

系统: ${sys_os}
发行版本:   ${sys_release}
系统内核:   ${sys_kernel}
主机名:    ${sys_hostname}
selinux状态:  ${sys_selinux}
系统语言:   ${sys_lang}
系统当前时间: ${sys_time}
系统最后重启时间:   ${sys_lastreboot}
系统运行时间: ${sys_runtime}
系统负载:   ${sys_load}
    "
}

# 获取服务信息
function get_service_info() {
    #port_listen=$(netstat -lntup|grep -v "Active Internet")
    port_listen=$(ss -lut)
    kernel_config=$(sysctl -p 2>/dev/null)
    if [ ${sysversion} -gt 6 ];then
        service_config=$(systemctl list-unit-files --type=service --state=enabled|grep "enabled")
        run_service=$(systemctl list-units --type=service --state=running |grep ".service")
    else
        service_config=$(/sbin/chkconfig | grep -E ":on|:启用" |column -t)
        run_service=$(/sbin/service --status-all|grep -E "running")
    fi
    echo "
服务启动配置:

${service_config}
${line}
运行的服务:

${run_service}
${line}
监听端口:

${port_listen}
${line}
内核参考配置:

${kernel_config}
    "
}

function get_sys_user() {
    login_user=$(awk -F: '{if ($NF=="/bin/bash") print $0}' /etc/passwd)
    ssh_config=$(egrep -v "^#|^$" /etc/ssh/sshd_config)
    sudo_config=$(egrep -v "^#|^$" /etc/sudoers |grep -v "^Defaults")
    host_config=$(egrep -v "^#|^$" /etc/hosts)
    crond_config=$(for cronuser in /var/spool/cron/* ;do ls ${cronuser} 2>/dev/null|cut -d/ -f5;egrep -v "^$|^#" ${cronuser} 2>/dev/null;echo "";done)
    echo "
系统登录用户:

${login_user}
${line}
ssh 配置信息:

${ssh_config}
${line}
sudo 配置用户:

${sudo_config}
${line}
定时任务配置:

${crond_config}
${line}
hosts 信息:

${host_config}
    "
}

function process_top_info() {

    top_title=$(top -b n1|head -7|tail -1)
    cpu_top10=$(top b -n1 | head -17 | tail -11)
    mem_top10=$(top -b n1|head -17|tail -10|sort -k10 -r)
    
    echo "
CPU占用top10:

${top_title}
${cpu_top10}
${line}
内存占用top10:

${top_title}
${mem_top10}
"
}

function sys_check() {
    echo "系统信息如下："
    echo -e "${line} "
    get_cpu_info
    echo -e "${line} "
    get_mem_info
    echo -e "${line} "
    get_net_info
    echo -e "${line} "
    get_disk_info
    echo -e "${line} "
    get_systatus_info
    echo -e "${line} "
    get_service_info
    echo -e "${line} "
    get_sys_user
    echo -e "${line} "
    process_top_info
}
    
sys_check > ${sys_check_file}
echo -e "\e[5m\e[1m系统信息收集完毕，查看：$(pwd)/${sys_check_file}\e[0m"

}

Main_config() {
while :;
do
    #clear
    Oneline="------------------------------------------------------------"
    
    Title (){
    echo -e "\n \e[1m\e[31m
        ############## CentOS7系统优化 ####################
        #                                                 #
        #      1. 配置首个网卡静态IP地址(ethx)            #
        #      2. 设置主机名                              #
        #      3. 关闭SElinux                             #
        #      4. 安装EPEL源                              #
        #      5. 添加系统用户                            #
        #      6. 授权sudo用户(sudo执行无需密码)          #
        #      7. 安装程序包，支持多个                    #
        #      8. 同步时间及时区                          #
        #      9. 配置yum源repo文件为阿里云               #
        #     10. 放行防火墙端口                          #
        #     11. 安装ClamAV杀毒软件并查杀                #
        #     12. 安装Zabbix客户端                        #
        #     13. 设置系统登录提示语                      #
        #     14. 更新程序包(排除内核)                    #
        #     15. 收集系统信息                            #
        #     16. 按q键退出优化                           #
        #                                                 #
        ###################################################
        \e[0m 
    "
    }
    Title
    
    read -p '按q键退出，选择优化项: ' Select
    echo ""
    #read -p '选择优化项：' Select
    case $Select in
        1)
            Set_IP
            echo "$Oneline"
            sleep 3
            ;;
        2)
            Set_Hostname
            echo "$Oneline"
            sleep 3
            ;;
        3)
            Close_selinux
            echo "$Oneline"
            sleep 3
            ;;
        4)
            Install_EPEL
            echo "$Oneline"
            sleep 3
            ;;
        5)
            Add_user
            echo "$Oneline"
            sleep 3
            ;;
        6)
            Set_sudo
            echo "$Oneline"
            sleep 3
            ;;
        7)
            Yum_package
            echo "$Oneline"
            sleep 3
            ;;
        8)
            Set_date_timezone
            echo "$Oneline"
            sleep 3
            ;;
        9)
            Set_aliyun_repofile
            echo "$Oneline"
            sleep 3
            ;;
        10)
            Set_firewalld
            echo "$Oneline"
            sleep 3
            ;;
        11)
            Install_clamav
            echo "$Oneline"
            sleep 3
            ;;
        12)
            Install_zabbix_agent
            echo "$Oneline"
            sleep 3
            ;;
        13)
            Set_motd
            echo "$Oneline"
            sleep 3
            ;;
        14)
            Update_sys
            echo "$Oneline"
            sleep 3
            ;;
        15)
            System_info
            echo "$Oneline"
            sleep 3
            ;;
        q|16)
            echo -e "\e[5m\e[1m 退出脚本！\e[0m \n" 
            exit 0 ;;
        *)
            echo -e "\e[5m\e[1m无效内容，选择优化项(如:2)或者退出(q)！\e[0m" 
            sleep 3
            ;;
    esac
done
}

Main_config
