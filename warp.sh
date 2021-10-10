#!/bin/bash
#v6就是添加v6,v4就是添加v4
type46=${1:-'v6'}
case $type46 in
IPV4|ipv4|v4|4)
    type46='v4'
    ;;
IPV6|ipv6|v6|6|*)
    type46='v6'
    ;;
esac

red='\e[31m'
none='\e[0m'

clear
echo -e "${red}运行添加warp ip$type46${none}"

if [[ "$OSTYPE" == "linux-gnu" ]]; then
    if [ -f /etc/redhat-release ]; then
        cmd=yum
        wireguard=wireguard-tools
        $cmd -y install epel-release
        #$cmd makecache
    elif [ -f /etc/debian_version ]; then
        cmd=apt-get
        wireguard=wireguard
        $cmd update
        if [ "$(cat /etc/apt/sources.list|grep debian)" ]; then
            echo "deb http://deb.debian.org/debian/ unstable main" > /etc/apt/sources.list.d/unstable.list
            printf 'Package: *\nPin: release a=unstable\nPin-Priority: 150\n' > /etc/apt/preferences.d/limit-unstable
        fi
    fi
else
    echo -e "暂仅支持 Linux(CentOS/Ubuntu/Debian) 系统\n其他系统可参考[https://haoduck.com/774.html]手动进行配置"
fi

[[ -z "$(command -v wget)" ]] || [[ -z "$(command -v wg-quick)" ]] && $cmd install -y wget $wireguard
# wireguard-go
wireguard_go="/usr/local/sbin/wireguard-go"
if [[ ! -f "$wireguard_go" ]];then
    wget https://github.com/P3TERX/wireguard-go-builder/releases/download/0.0.20201118/wireguard-go-linux-amd64.tar.gz
    tar zxf wireguard-go-linux-amd64.tar.gz
    mv wireguard-go $wireguard_go
    ln -s $wireguard_go /bin/wireguard_go
    rm -f wireguard-go-linux-amd64.tar.gz
    fi
# wgcf
wgcf="/usr/local/sbin/wgcf"
if [[ ! -f "$wgcf" ]];then   
    wget https://github.com/ViRb3/wgcf/releases/download/v2.2.2/wgcf_2.2.2_linux_amd64 -O $wgcf
    chmod +x $wgcf
    ln -s $wgcf /bin/wgcf
fi
wgcf_conf="wgcf-profile.conf"
if [[ ! -f "wgcf_conf" ]];then
    i=0
    while [[ ! -f "wgcf-account.toml" ]];do
        echo|$wgcf register
        let i++
        if [[ $i -ge 5 ]];then #5次都失败，就退出
            echo "wgcf生成配置失败！"
            echo "可以尝试手动执行${red} echo|$wgcf register ${none}生成配置"
            exit 1
        fi
    done
    i=0
    while [[ ! -f "$wgcf_conf" ]];do
        $wgcf generate
        let i++
        if [[ $i -ge 5 ]];then #5次都失败，就退出
            echo "wgcf生成配置失败！"
            echo "可以尝试手动执行${red} $wgcf generate ${none}生成配置"
            exit 1
        fi
    done
fi
if [[ "$type46" == 'v6' ]]; then
    sed -i "s@^\(AllowedIPs = 0.0.0.0/0\)@#\1@g" $wgcf_conf
else
    sed -i "s@^\(AllowedIPs = ::/0\)@#\1@g" $wgcf_conf
fi

mkdir -p /etc/wireguard
/bin/cp -f wgcf-profile.conf /etc/wireguard/wgcf.conf
# systemctl
[[ ! -f "/usr/local/bin/resolvconf" ]] && ln -s /usr/bin/resolvectl /usr/local/bin/resolvconf
[[ ! -f "/etc/systemd/system/dbus-org.freedesktop.resolve1.service" ]] && ln -sf /lib/systemd/system/systemd-resolved.service /etc/systemd/system/dbus-org.freedesktop.resolve1.service
#systemctl enable wg-quick@wgcf
systemctl stop wg-quick@wgcf
systemctl start wg-quick@wgcf

if [[ "$type46" == 'v6' ]]; then
    ping="ping -6 2606:4700:4700::1111"
else
    ping="ping -4 1.1.1.1"
fi
ip=$(wget -qO- ip$type46.ip.sb)
echo -e "完成了，可以执行${red} $ping ${none}试试看了
    如果没出问题
    这里应该能显示你刚添加的WARP的IP:${red} $ip ${none}<=如果这里是空的，大概是失败了
    确定OK后执行${red} systemctl enable wg-quick@wgcf ${none}配置开机自启
    无法连通网络的话执行${red} systemctl stop wg-quick@wgcf ${none}或者重启即可关闭"
