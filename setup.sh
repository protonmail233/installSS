#!/bin/bash
check_system(){
    source /etc/os-release
    if [[ "${ID}" == "debian" && ${VERSION_ID} -ge 8 ]];then
        apt-get update && apt-get install lsb-release wget curl ca-certificates apt-transport-https language-pack-en -y
        cat > /etc/apt/sources.list << EOF
deb http://debian-archive.trafficmanager.net/debian $(lsb_release -sc) main contrib non-free
deb http://debian-archive.trafficmanager.net/debian-security $(lsb_release -sc)/updates main contrib non-free
deb http://debian-archive.trafficmanager.net/debian $(lsb_release -sc)-updates main contrib non-free
deb http://debian-archive.trafficmanager.net/debian $(lsb_release -sc)-backports main contrib non-free
EOF
        wget -O /etc/apt/trusted.gpg.d/nginx-mainline.gpg https://packages.sury.org/nginx-mainline/apt.gpg
        cat >> /etc/apt/sources.list.d/nginx.list << EOF
deb https://packages.sury.org/nginx-mainline/ $(lsb_release -sc) main
EOF
        wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
        sh -c 'echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list'
        apt-get update && apt-get dist-upgrade -y 

    elif [[ "${ID}" == "ubuntu" && `echo "${VERSION_ID}" | cut -d '.' -f1` -ge 16 ]];then
        apt-get install lsb-release wget curl ca-certificates -y
        cat > /etc/apt/sources.list << EOF
deb http://azure.archive.ubuntu.com/ubuntu/ $(lsb_release -sc) main restricted universe multiverse
deb http://azure.archive.ubuntu.com/ubuntu/ $(lsb_release -sc)-security main restricted universe multiverse
deb http://azure.archive.ubuntu.com/ubuntu/ $(lsb_release -sc)-updates main restricted universe multiverse
deb http://azure.archive.ubuntu.com/ubuntu/ $(lsb_release -sc)-backports main restricted universe multiverse
EOF
        apt-get update && apt-get install software-properties-common landscape-common update-notifier-common -y
        add-apt-repository ppa:ondrej/php -y
        add-apt-repository ppa:ondrej/nginx-mainline -y
        apt-get update && apt-get dist-upgrade -y
    else
        echo "System version not supported"
        exit 1
    fi
}
lemp_install(){
    apt-get install vim git sudo unzip screen dialog gnupg2 htop mtr nload hdparm python-pip python-dev python3-pip python3-dev build-essential openssl libelf-dev libffi-dev libssl-dev fail2ban libsodium-dev nginx-light php7.2-fpm php7.2-mysql php7.2-curl php7.2-gd php7.2-mbstring php7.2-xml php7.2-xmlrpc php7.2-zip php7.2-opcache -y
    pip3 install pip -U && pip2 install pip -U && hash -r
    curl -sL https://deb.nodesource.com/setup_8.x | bash -
    curl -sL https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
    echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
    apt-get update && apt-get install nodejs yarn -y && yarn global add pm2
    apt autoremove && apt autoclean
    echo "* soft nofile 512000" >> /etc/security/limits.conf
    echo "* hard nofile 512000" >> /etc/security/limits.conf
    ulimit -n 512000
    sed -i 's/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/' /etc/php/7.2/fpm/php.ini
    cat > /var/www/html/index.php << EOF
<?php phpinfo(); ?>
EOF
    cat > /etc/nginx/sites-available/default << EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    root /var/www/html;
    index index.php index.html index.nginx-debian.html;
    server_name _;
    location / {
        try_files \$uri \$uri/ =404;
    }
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php7.2-fpm.sock;
    }
    location ~ /\.ht {
        deny all;
    }
}
EOF
    systemctl restart php7.2-fpm && systemctl restart nginx
}
version_cp(){
    test "$(echo "$@" | tr " " "\n" | sort -rV | head -n 1)" == "$1"
}
bbr_install(){
    local kernel_version=$(uname -r | cut -d- -f1)
    if version_cp ${kernel_version} 4.9; then
        modprobe tcp_bbr
        echo "tcp_bbr" >> /etc/modules-load.d/modules.conf
        echo 3 > /proc/sys/net/ipv4/tcp_fastopen
        echo 1 > /proc/sys/net/ipv4/icmp_echo_ignore_all
        cat > /etc/sysctl.conf << EOF
vm.swappiness = 10
vm.vfs_cache_pressure = 50
net.ipv4.icmp_echo_ignore_all = 1
net.core.default_qdisc = fq_codel
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_fastopen = 3
EOF
        sysctl -p
        sysctl net.ipv4.tcp_available_congestion_control
        sysctl net.ipv4.tcp_congestion_control
        lsmod | grep bbr
    else
        case $(lsb_release -sc) in
        jessie)
            apt-get -t jessie-backports install linux-image-amd64 linux-headers-amd64 -y
            update-grub && reboot
            ;;
        xenial)
            apt-get install --install-recommends linux-generic-hwe-16.04 -y
            update-grub && reboot
            ;;
        *)
            exit 1
            ;;
        esac
    fi
}
ssr_install(){
    echo "sshd: ALL" > /etc/hosts.allow
    pip install setuptools -U && pip install cryptography pyOpenSSL -U && pip install cymysql requests pyasn1 ndg-httpsclient urllib3 speedtest-cli
    cd /root/ && git clone https://github.com/S8Cloud/shadowsocks.git && cd shadowsocks && vi userapiconfig.py
    pm2 start server.json && pm2 startup && pm2 save && cd /root/ && curl ipv4.ip.sb
}

action=$1
[ -z $1 ] && action=normal
case "$action" in
    bbr)
        bbr_install
        ;;
    normal)
        check_system
        lemp_install
        bbr_install
        ;;
    ssr)
        ssr_install
        ;;
    *)
        exit 1
        ;;
esac
