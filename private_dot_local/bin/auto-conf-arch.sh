#!/usr/bin/bash
# File: auto_conf_arch.sh
# Author: Star_caorui
# Last modified: UTC+8 2021-12-13 10:07

# HACK: Maybe you need install ucode, firmware, graphics driver.

# 偏好设置：
# _USER_NAME=      # 如果启用将会创建特权用户（如果用户名不合规，则不会继续创建用户）
# _USER_PASSWORD=  # 如果启用将会给特权用户创建账户密码.（如果用户名不存在，则不会继续创建密码）
# _ROOT_PASSWORD=  # 如果启用将会给 root 用户创建账户密码
# _PASSWORD_LOGIN= # 如果值是 ENABLE 则允许密码登入，如果值是 DISABLE 则不允许密码登入。
# _SSH_PUBKEY=     # 如果被启用则会允许通过此密钥登入特权用户和 root 用户。

_TIMEZONE=Asia/Shanghai
_LANG=zh_CN.UTF-8
_SHELL=zsh
_EDITOR=nano
#_HOSTNAME=Netech
#_DNS_OVER_HTTPS='https://i.passcloud.xyz/dns-query'

_PASSWORD_LOGIN=DISABLE
_SSH_PUBKEY='ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDCv96Mn19WYF6klxlagKycBkJLRzscs1Ho4WnQltNLDJQJR1PjxFOX3W2UBB6wvsavUe+0HWPFeOCvHajwvYlqPBdsfuA+HPk/x+tTXtBTAS5we4eCm67wYc61T+EnQmY4/Ml10FbXfQ0lfh54Ovug6TZxaJ4cCK5lBwjEj0QzRzwOX5O0py2o9BJvZiAB3RkwZwysdH0t3GO134D+NJ6uoDWXpKr6qyjb2XYGMTTIbdJIEtcyAhLFiPF11T7Rn8cw/jrpIxb5Bg9SLRDAKXTTxbPMHocNnwQL6Fjp5wtDSIai7s7H9la5Lq16M6tWGW/gzOw2GCc2YmWgbStLJ7XAF29QRRpvIy6wH5wLVu73JcQDdJtJ3aivhiS4CiwbWnS1Mpr2BicWvgBoYafJRpitC7yfAEthi1PMY5vFNou9lQyDKtnBRu+PGym5p4Cn4eD4N7J0IiipzhD3u3IL+kbt9NZQVoLsN/2CoU9vKm717QHfimXLckAmM9Gt9YNOiJ0= star@ArchLinux'

if(`curl -s "https://api.ip.sb/geoip" | grep -oP '(?<=country_code":")\w+'` = 'CN') {
  _DISABLE_CLOUDFALRE_FOR_CN='#'
}

function auto_conf_locale() {
  hostnamectl hostname  ${_HOSTNAME}
  timedatectl set-timezone ${_TIMEZONE}
  timedatectl set-ntp true
  hwclock --systohc
  sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
  sed -i 's/#zh_CN.UTF-8 UTF-8/zh_CN.UTF-8 UTF-8/' /etc/locale.gen
  if [[ ${_LANG} != 'en_US.UTF-8' && ${_LANG} != 'zh_CN.UTF-8' ]]; then
    sed -i "s/#${_LANG} UTF-8/${_LANG} UTF-8/" /etc/locale.gen
  fi
  echo "LANG=${_LANG}" > /etc/locale.conf
}

function auto_conf_env() {
  cat 'ENVIRONMENTD="$HOME/.config/environment.d"\
set -a\
if [ -d "\${ENVIRONMENTD}" ]; then\
  for conf in $(ls "${ENVIRONMENTD}"/*.conf)\
  do\
    . "${conf}"\
  done\
fi\
set +a' > /etc/profile.d/environment.sh

  if [[ ! -d ${HOME}/.local/state/${_SHELL}/history ]]; then
    mkdir -p ${HOME}/.local/state/${_SHELL}/
  fi

  if [[ ! -d ${HOME}/.config/chezmoi/chezmoi.toml ]]; then
    mkdir -p ${HOME}/.config/chezmoi/
  fi

  cat > ${HOME}/.config/chezmoi/chezmoi.toml <<-EOF
    [git]
      autoCommit = true
      autoPush = true
  [data]
    signingkey = "6A34401888C9B3A30A7F05CBB415400AEED441E9"
    name = "Star_caorui"
    email = "star_caorui@hotmail.com"
	EOF

  pacman --noconfirm -S chezmoi
  chezmoi init --apply https://github.com/Star-caorui/Star-caorui/
  # Prevent the unavailability of environment variables caused by not restarting the terminal
  export GNUPGHOME=${HOME}/.local/share/gnupg
  if [[ -d ${HOME}/.gnupg ]]; then
    rm ${HOME}/.gnupg
  fi
}

function auto_conf_doh() {
  if [[ ${_DNS_OVER_HTTPS} ]]; then
    local _DNS_M _DNS_B
    read -r _DNS_M _DNS_B <<-EOF
		  $(awk '{print $2}' /etc/resolv.conf | tr -s '\n' ' ')
		EOF

    cat > /etc/resolv.conf <<-EOF
		  nameserver ::1
		  nameserver 127.0.0.1
      options edns0 single-request-reopen
		EOF
    cat > /etc/dns-over-https/doh-client.conf <<-EOF
		  listen = [
        "127.0.0.1:53",
        "[::1]:53",
      ]

      [upstream]
        upstream_selector = "weighted_round_robin"

      [[upstream.upstream_ietf]]
        url = "${_DNS_OVER_HTTPS}"
        weight = 100

      [others]
      bootstrap = [
        "${_DNS_M}",
        "${_DNS_B}",
      ]

      passthrough = [
        "0.arch.pool.ntp.org",
      ]

      timeout = 30
      no_cookies = true
      no_ecs = false
      no_ipv6 = false
      no_user_agent = false
      verbose = true
      insecure_tls_skip_verify = false
		EOF
    systemctl enable doh-client.service
  fi
}

function auto_conf_iptable() {
  iptables  -F
  ip6tables -F

  iptables  -P INPUT DROP
  ip6tables -P INPUT DROP
  iptables  -P FORWARD DROP
  ip6tables -P FORWARD DROP
  iptables  -P OUTPUT ACCEPT
  ip6tables -P OUTPUT ACCEPT

  iptables  -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
  ip6tables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

  iptables-save  > /etc/iptables/iptables.rules
  ip6tables-save > /etc/iptables/ip6tables.rules

  systemctl enable iptables
  systemctl enable ip6tables
}

function auto_conf_pacman() {
    cat > /etc/pacman.d/mirrorlist <<-EOF
      `_DISABLE_CLOUDFALRE_FOR_CN`Server = https://cloudflaremirrors.com/archlinux/\$repo/os/\$arch
      Server = https://mirrors.bfsu.edu.cn/archlinux/\$repo/os/\$arch
      Server = https://mirrors.neusoft.edu.cn/archlinux/\$repo/os/\$arch
      Server = https://mirrors.tuna.tsinghua.edu.cn/archlinux/\$repo/os/\$arch
		EOF

    cat > /etc/pacman.d/mirrorlist-cn <<-EOF
      Server = https://mirrors.bfsu.edu.cn/archlinuxcn/\$arch
      Server = https://mirrors.tuna.tsinghua.edu.cn/archlinuxcn/\$arch
		EOF

    sed -i 's/#UseSyslog/UseSyslog/' /etc/pacman.conf
    sed -i 's/#Color/Color/' /etc/pacman.conf
    sed -i 's/#VerbosePkgLists/VerbosePkgLists/' /etc/pacman.conf
    sed -i 's/#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf

    if [[ -f '/version' ]]; then
      pacman-key --init && pacman-key --populate archlinux
    else
      cat >> /etc/pacman.conf <<-EOF
        [archlinuxcn]
        Include = /etc/pacman.d/mirrorlist-cn

        #[zhullyb]
        #Server = https://pkg.web-worker.cn/zhullyb

        #[web-worker]
        #Server = https://pkg.web-worker.cn/archlinux
			EOF
      pacman --noconfirm -Sy archlinuxcn-keyring
    fi
    #sed -i 's/#\[zhullyb\]/\[zhullyb\]/' /etc/pacman.conf
    #sed -i 's|#Server = https://pkg.web-worker.cn/zhullyb|Server = https://pkg.web-worker.cn/zhullyb|' /etc/pacman.conf
    #pacman --noconfirm -S zhullyb-keyring #web-worker-keyring
    #pacman-key --lsign-key zhullyb
}

function auto_conf_sshd() {
  iptables  -A INPUT -p tcp --dport 22 -j ACCEPT
  ip6tables -A INPUT -p tcp --dport 22 -j ACCEPT
  iptables-save  > /etc/iptables/iptables.rules
  ip6tables-save > /etc/iptables/ip6tables.rules

  if [[ ! -x `command -v ssh` ]]; then
    pacman --noconfirm -S openssh
  fi

  if [[ ${_ROOT_PASSWORD} ]]; then
    echo root:${_ROOT_PASSWORD}|chpasswd
  fi

  if [[ ! -d ${HOME}/.ssh ]]; then
    install -D -m 700 -o root -g root -d ${HOME}/.ssh
  fi
  echo ${_SSH_PUBKEY} > ${HOME}/.ssh/authorized_keys

  # Allow Pubkey Authentication
  sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
  if [[ ${_PASSWORD_LOGIN} = "ENABLE" ]]; then
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
  else
    # Forbid Password Authentication
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
  fi
  # 防止长时间无操作会话断开
  sed -i 's/#ClientAliveInterval 0/ClientAliveInterval 60/' /etc/ssh/sshd_config
  # Forwarding
  sed -i 's/#AllowAgentForwarding yes/AllowAgentForwarding yes/' /etc/ssh/sshd_config
  sed -i 's/#AllowTcpForwarding yes/AllowAgentForwarding yes/' /etc/ssh/sshd_config
  sed -i 's/#X11Forwarding no/X11Forwarding yes/' /etc/ssh/sshd_config
  sed -i 's/#X11DisplayOffset 10/X11DisplayOffset 10/' /etc/ssh/sshd_config
  sed -i 's/#X11UseLocalhost yes/X11UseLocalhost yes/' /etc/ssh/sshd_config
  echo 'StreamLocalBindUnlink yes' >> /etc/ssh/sshd_config

  systemctl enable sshd
}

function auto_conf_shell() {
  ${AURHELPER} --noconfirm -S zsh zinit-git oh-my-zsh-git zsh-autosuggestions zsh-completions zsh-syntax-highlighting
  ln -sf /usr/share/zsh/plugins/zsh-autosuggestions/ /usr/share/oh-my-zsh/plugins/
  ln -sf /usr/share/zsh/plugins/zsh-syntax-highlighting/ /usr/share/oh-my-zsh/plugins/
  cat > ${HOME}/.zshrc <<-EOF
    # Setting zsh cache.
    ZSH_CACHE_DIR=\${HOME}/.cache/zsh
    if [[ ! -d \${ZSH_CACHE_DIR} ]]; then
      mkdir \${ZSH_CACHE_DIR}
    fi
    # Setting zsh comdump.
    ZSH_COMPDUMP=\${XDG_CACHE_HOME}/zsh/zcompdump-\${SHORT_HOST}-\${ZSH_VERSION
    # Setting zsh config.
    ZSH="/usr/share/oh-my-zsh/"
    ZSH_THEME="gnzh"
    plugins=(sudo zsh-syntax-highlighting zsh-autosuggestions vscode)
    DISABLE_AUTO_UPDATE="true"
    source \${ZSH}/oh-my-zsh.sh
	EOF
  chsh -s /bin/zsh
}

function auto_conf_utility_software() {
  pacman --noconfirm -S htop git gpg ${_EDITOR}
}

function auto_conf_vps2arch() {
  pacman --noconfirm -S linux-zen
  systemctl disable --now reflector
  pacman --noconfirm -Rsn reflector lvm2 linux
  grub-mkconfig -o /boot/grub/grub.cfg
}


# HACK: Maybe you need install App: axel zip unzip neofetch v2ray php php-fpm php-sqlite nginx-mainline certbot-nginx goaccess
# ip(6)table: Tencent Cloud SDK
