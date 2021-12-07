# File: auto-conf-arch.sh
# Author: Star_caorui
# Last modified: UTC+8 2021-12-5 11:09

# HACK: Please Install ucode, firmware, graphics driver.

function auto-conf-vps2arch () {
  # Stop, Disable And Remove Reflector.
  systemctl disable --now reflector
  pacman -Rsn reflector

  # Remove lvm2.
  pacman -Rsn lvm2

  # Remove linux kernel, and Install linux-zen kernel.
  pacman -Rsn linux
  pacman -S linux-zen
  grub-mkconfig -o /boot/grub/grub.cfg
}

function auto-conf-locale () {
  ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
  hwclock --systohc
  sed -e 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
  sed -e 's/#en_SG.UTF-8 UTF-8/en_SG.UTF-8 UTF-8/' /etc/locale.gen
  sed -e 's/#zh_CN.UTF-8 UTF-8/zh_CN.UTF-8 UTF-8/' /etc/locale.gen
  echo 'LANG=en_SG.UTF-8' > /etc/locale.conf
  echo 'Netech-Server' > /etc/hostname
}

function auto-conf-env () {
  cat > ${HOME}/.pam_environment <<-EOF
    XDG_CACHE_HOME  DEFAULT=@{HOME}/.cache
    XDG_CONFIG_HOME DEFAULT=@{HOME}/.config
    XDG_DATA_HOME   DEFAULT=@{HOME}/.local/share
    XDG_STATE_HOME  DEFAULT=@{HOME}/.local/state
    XDG_DATA_DIRS   DEFAULT=/usr/local/share:/usr/share
    XDG_CONFIG_DIRS DEFAULT=/etc/xdg

    GNUPGHOME       DEFAULT=${XDG_DATA_HOME}/gnupg
    VSCODE_PORTABLE DEFAULT=${XDG_DATA_HOME}/vscode
    HISTFILE        DEFAULT=${XDG_STATE_HOME}/zsh/history
    _JAVA_OPTIONS   DEFAULT=-Djava.util.prefs.userRoot=${XDG_CONFIG_HOME}/java


    INPUT_METHOD    DEFAULT=fcitx
    XMODIFIERS      DEFAULT=\@im=fcitx
    GTK_IM_MODULE   DEFAULT=fcitx
    QT_IM_MODULE    DEFAULT=fcitx
    SDL_IM_MODULE   DEFAULT=fcitx

    EDITOR          DEFAULT=nano
    VISUAL          DEFAULT=nano
    SUDO_EDITOR     DEFAULT=nano
	EOF
  # Prevent the unavailability of environment variables caused by not restarting the terminal
  export GNUPGHOME=${HOME}/.local/share/gnupg
  rm ${HOME}/.gnupg
}

function auto-conf-net() {
  # Note: 这行代码是从 vps2arch 那里抄过来的.
  # Black Magic!

  # 创建两个局部变量（作用域：函数内）
	local gateway dev

  # read -r 不转译特殊字符（也就是不用加 "\"）
  # read 通过 管道将 awk 处理完的 数据赋值给 gateway dev 变量
	read -r dev gateway <<-EOF
		$(awk '$2 == "00000000" {                /** awk 首先过滤出需要处理的那行数据 **/
      ip = strtonum(sprintf("0x%s", $3));    /** 然后获取网关的ip地址（整形）**/
      # 通过 printf 输出 设备名称，ip地址（ip是在后面的计算分别得到的四段）
      # 通过 用 ip 的 二进制数 和 掩码 进行 与运算，分别得出每段 "." 所对应的 ip地址
      # 通过 右移位运算，将 每段ip 右面的空白部分清掉。
		  printf ("%s\t%d.%d.%d.%d", $1,
		    rshift(and(ip,0x000000ff),00), rshift(and(ip,0x0000ff00),08),
		    rshift(and(ip,0x00ff0000),16), rshift(and(ip,0xff000000),24));
      exit;
    }' < /proc/net/route) # 通过管道让 awk 处理 /proc/net/route 的内容
	EOF

	cat > /etc/systemd/network/default.network <<-EOF
		[Match]
		Name=$dev

		[Network]
		Gateway=$gateway
	EOF
	echo "Address=$(ip addr show dev "$dev" | awk '($1 == "inet") { print $2 }')" >> /etc/systemd/network/default.network
	systemctl enable --now systemd-networkd
}

function auto-conf-pacman () {
  # Configure pacman mirror list.
  cat > /etc/pacman.d/mirrorlist <<-EOF
    #Server = https://cloudflaremirrors.com/archlinux/$repo/os/$arch
    Server = https://mirrors.bfsu.edu.cn/archlinux/$repo/os/$arch
    Server = https://mirrors.neusoft.edu.cn/archlinux/$repo/os/$arch
    Server = https://mirrors.tuna.tsinghua.edu.cn/archlinux/$repo/os/$arch
	EOF

  cat > /etc/pacman.d/mirrorlist-cn <<-EOF
    Server = https://mirrors.bfsu.edu.cn/archlinuxcn/$arch
    Server = https://mirrors.tuna.tsinghua.edu.cn/archlinuxcn/$arch
	EOF

  # Configure pacman config file.
  sed -e 's/#UseSyslog/UseSyslog/' /etc/pacman.conf
  sed -e 's/#Color/Color/' /etc/pacman.conf
  sed -e 's/#VerbosePkgLists/VerbosePkgLists/' /etc/pacman.conf
  sed -e 's/#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
  cat > /etc/pacman.conf <<-EOF
    [archlinuxcn]
    Include = /etc/pacman.d/mirrorlist-cn

    [zhullyb]
    Server = https://pkg.web-worker.cn/zhullyb

    #[web-worker]
    #Server = https://pkg.web-worker.cn/archlinux
	EOF

  pacman-key --lsign-key zhullyb
  pacman -S archlinuxcn-keyring zhullyb-keyring #web-worker-keyring
}

function auto-conf-iptable () {
  # 清空 iptables/ip6tables 规则
  iptables -F
  ip6tables -F
  # 初始化 入站, 转发, 出站 规则
  iptables -P INPUT DROP
  ip6tables -P INPUT DROP
  iptables -P FORWARD DROP
  ip6tables -P FORWARD DROP
  iptables -P OUTPUT ACCEPT
  ip6tables -P OUTPUT ACCEPT
  # 放行 已建立的连接
  iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
  ip6tables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
  # 放行 sshd 使用的 22 端口
  iptables -A INPUT -p tcp --dport 22 -j ACCEPT
  ip6tables -A INPUT -p tcp --dport 22 -j ACCEPT
  # 放行 webserver 使用的 80 端口
  iptables -A INPUT -p tcp --dport 80 -j ACCEPT
  ip6tables -A INPUT -p tcp --dport 80 -j ACCEPT
  # 放行 webserver 使用的 443 端口
  iptables -A INPUT -p tcp --dport 443 -j ACCEPT
  ip6tables -A INPUT -p tcp --dport 443 -j ACCEPT
  # 保存所作修改
  iptables-save > /etc/iptables/iptables.rules
  ip6tables-save > /etc/iptables/ip6tables.rules
  # 设置开机自启并立即启动 iptables/ip6tables
  systemctl enable --now iptables
  systemctl enable --now ip6tables
  systemctl restart iptable
  systemctl restart ip6table
}


function auto-conf-sshd () {
  if [ ! -d ${HOME}/.ssh ]; then
    mkdir ${HOME}/.ssh
  fi
  chmod 700 ${HOME}/.ssh
  echo 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDCv96Mn19WYF6klxlagKycBkJLRzscs1Ho4WnQltNLDJQJR1PjxFOX3W2UBB6wvsavUe+0HWPFeOCvHajwvYlqPBdsfuA+HPk/x+tTXtBTAS5we4eCm67wYc61T+EnQmY4/Ml10FbXfQ0lfh54Ovug6TZxaJ4cCK5lBwjEj0QzRzwOX5O0py2o9BJvZiAB3RkwZwysdH0t3GO134D+NJ6uoDWXpKr6qyjb2XYGMTTIbdJIEtcyAhLFiPF11T7Rn8cw/jrpIxb5Bg9SLRDAKXTTxbPMHocNnwQL6Fjp5wtDSIai7s7H9la5Lq16M6tWGW/gzOw2GCc2YmWgbStLJ7XAF29QRRpvIy6wH5wLVu73JcQDdJtJ3aivhiS4CiwbWnS1Mpr2BicWvgBoYafJRpitC7yfAEthi1PMY5vFNou9lQyDKtnBRu+PGym5p4Cn4eD4N7J0IiipzhD3u3IL+kbt9NZQVoLsN/2CoU9vKm717QHfimXLckAmM9Gt9YNOiJ0= star@ArchLinux' > ${HOME}/.ssh/authorized_keys

  # Allow Pubkey Authentication
  sed -e 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
  # Forbid Password Authentication
  sed -e 's/#PermitRootLogin prohibit-password/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
  sed -e 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
  # 防止长时间无操作会话断开
  sed -e 's/#ClientAliveInterval 0/ClientAliveInterval 60/' /etc/ssh/sshd_config
  # Forwarding
  sed -e 's/#AllowAgentForwarding yes/AllowAgentForwarding yes/' /etc/ssh/sshd_config
  sed -e 's/#AllowTcpForwarding yes/AllowAgentForwarding yes/' /etc/ssh/sshd_config
  sed -e 's/#X11Forwarding no/X11Forwarding yes/' /etc/ssh/sshd_config
  sed -e 's/#X11DisplayOffset 10/X11DisplayOffset 10/' /etc/ssh/sshd_config
  sed -e 's/#X11UseLocalhost yes/X11UseLocalhost yes/' /etc/ssh/sshd_config
  echo 'StreamLocalBindUnlink yes' >> /etc/ssh/sshd_config

  systemctl enable --now sshd
  systemctl restart sshd
}


function auto-conf-shell () {
  pacman -S zsh oh-my-zsh-git zsh-autosuggestions zsh-syntax-highlighting
  ln -sf /usr/share/zsh/plugins/zsh-autosuggestions/ /usr/share/oh-my-zsh/plugins/
  ln -sf /usr/share/zsh/plugins/zsh-syntax-highlighting/ /usr/share/oh-my-zsh/plugins/
  cat > ${HOME}/.zshrc <<-EOF
    # Setting zsh cache.
    ZSH_CACHE_DIR=${HOME}/.cache/zsh
    if [[ ! -d ${ZSH_CACHE_DIR} ]]; then
      mkdir ${ZSH_CACHE_DIR}
    fi

    # Setting zsh comdump.
    ZSH_COMPDUMP=${XDG_CACHE_HOME}/zsh/zcompdump-${SHORT_HOST}-${ZSH_VERSION}

    # Setting zsh config.
    ZSH="/usr/share/oh-my-zsh/"
    ZSH_THEME="gnzh"
    plugins=(sudo zsh-syntax-highlighting zsh-autosuggestions vscode)
    DISABLE_AUTO_UPDATE="true"
    source ${ZSH}/oh-my-zsh.sh
	EOF
  chsh -s /bin/zsh
}

function auto-conf-configure () {
  pacman -S htop nano git gpg axel zip unzip
  cp -r ../.config $HOME/
}

# TODO: 服务器环境配置
# App: neofetch v2ray php php-fpm php-sqlite nginx-mainline certbot-nginx goaccess

# TODO: 对接 Tencent Cloud SDK
# ip(6)table: Tencent Cloud SDK

echo -e '\033[31;1m You can execute the following command.\033[0m'
echo -e '\033[32;1m  auto-conf-vps2arch\n  auto-conf-locale\n  auto-conf-env\n  auto-conf-net\n  auto-conf-iptable\n  auto-conf-pacman\n  auto-conf-sshd\n  auto-conf-shell\033[0m'
