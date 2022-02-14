#!/usr/bin/bash
# File: auto_conf_arch.sh
# Author: Star_caorui
# Last modified: UTC+8 2021-2-14 3:03

# HACK: Maybe you need install ucode, firmware, graphics driver.
# HACK: Maybe you need install App: axel zip unzip neofetch v2ray php php-fpm php-sqlite nginx-mainline certbot-nginx goaccess
# TODO: ip(6)table: Tencent Cloud SDK

# 偏好设置：
# _ROOT_PASSWORD=  # 如果启用将会给 root 用户创建账户密码

# _ROOT_PASSWORD=
_TIMEZONE=Asia/Shanghai
_LANG=zh_CN.UTF-8
_EDITOR=nano
#_HOSTNAME=iNetech XXX
#_DNS_OVER_HTTPS='https://i.passcloud.xyz/dns-query'

if(`curl -s "https://api.ip.sb/geoip" | grep -oP '(?<=country_code":")\w+'` = 'CN') {
  _DISABLE_CLOUDFALRE_FOR_CN='#'
}

function auto_conf_vps2arch() {
  pacman --noconfirm -S linux-zen
  systemctl disable --now reflector
  pacman --noconfirm -Rsn reflector lvm2 linux
  grub-mkconfig -o /boot/grub/grub.cfg
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
  locale-gen
}

function auto_conf_env() {
  # TODO global env setting
  echo 'http ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers
  # TODO: Install paru.
  sudo -u http paru --noconfirm -S chezmoi sudo zsh zinit-git oh-my-zsh-git zsh-autosuggestions zsh-completions zsh-syntax-highlighting htop git gpg ${_EDITOR}

  mkdir -p ${HOME}/.local/state
  mkdir -p ${HOME}/.config/chezmoi

  cat > ${HOME}/.config/chezmoi/chezmoi.toml <<-EOF
    [git]
      autoCommit = true
      autoPush = true
  [data]
    signingkey = "6A34401888C9B3A30A7F05CBB415400AEED441E9"
    name = "Star_caorui"
    email = "star_caorui@hotmail.com"
	EOF

  chezmoi init --apply https://github.com/Star-caorui/Star-caorui/
  chsh -s /bin/zsh
  # Prevent the unavailability of environment variables caused by not restarting the terminal
  export GNUPGHOME=${HOME}/.local/share/gnupg
  if [[ -d ${HOME}/.gnupg ]]; then
    rm ${HOME}/.gnupg
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

function auto_conf_pacman() {
    cat > /etc/pacman.d/mirrorlist <<-EOF
      Server = ${_DISABLE_CLOUDFALRE_FOR_CN}https://cloudflaremirrors.com/archlinux/\$repo/os/\$arch
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
}

function auto_conf_sshd() {
  iptables  -A INPUT -p tcp --dport 22 -j ACCEPT
  ip6tables -A INPUT -p tcp --dport 22 -j ACCEPT
  iptables-save  > /etc/iptables/iptables.rules
  ip6tables-save > /etc/iptables/ip6tables.rules

  if [[ ${_ROOT_PASSWORD} ]]; then
    echo root:${_ROOT_PASSWORD}|chpasswd
  fi

  # Allow Pubkey Authentication
  sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
  if [[ ${_ROOT_PASSWORD} ]]; then
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

  systemctl restart sshd
}
