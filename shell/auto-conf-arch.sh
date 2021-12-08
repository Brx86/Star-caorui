#!/usr/bin/bash
# File: auto_conf_arch.sh
# Author: Star_caorui
# Last modified: UTC+8 2021-12-9 04:21

# Thanks: Ayatale, vps2arch.

# HACK: Maybe you need install ucode, firmware, graphics driver.


# 脚本配置中心：
# 注：_USER_NAME     如果被注释将不会创建特权用户.
# 注：_USER_PASSWORD 如果被注释将不会给特权用户创建账户密码.
# 注：_ROOT_PASSWORD 如果被注释将不会给 root 用户创建账户密码.

_HOSTNAME=Netech
_TIMEZONE=Asia/Shanghai
_LANG=en_SG.UTF-8
_DNS_SERVER=8.8.8.8
#_USER_NAME=star
#_USER_PASSWORD=password
#_ROOT_PASSWORD=password
_SSH_PUBKEY='ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDCv96Mn19WYF6klxlagKycBkJLRzscs1Ho4WnQltNLDJQJR1PjxFOX3W2UBB6wvsavUe+0HWPFeOCvHajwvYlqPBdsfuA+HPk/x+tTXtBTAS5we4eCm67wYc61T+EnQmY4/Ml10FbXfQ0lfh54Ovug6TZxaJ4cCK5lBwjEj0QzRzwOX5O0py2o9BJvZiAB3RkwZwysdH0t3GO134D+NJ6uoDWXpKr6qyjb2XYGMTTIbdJIEtcyAhLFiPF11T7Rn8cw/jrpIxb5Bg9SLRDAKXTTxbPMHocNnwQL6Fjp5wtDSIai7s7H9la5Lq16M6tWGW/gzOw2GCc2YmWgbStLJ7XAF29QRRpvIy6wH5wLVu73JcQDdJtJ3aivhiS4CiwbWnS1Mpr2BicWvgBoYafJRpitC7yfAEthi1PMY5vFNou9lQyDKtnBRu+PGym5p4Cn4eD4N7J0IiipzhD3u3IL+kbt9NZQVoLsN/2CoU9vKm717QHfimXLckAmM9Gt9YNOiJ0= star@ArchLinux'
_EDITOR=nano
_INPUT_METHOD=fcitx

function init() {
  case `ps -p $$ --no-headers -o comm` in
    sh)
      printf '\033[31;1mSorry, "sh" is not suppot, please use bash or zsh.\033[0m\n'
      exit 1;
      ;;
    bash)
      _SCRIPT_FILENAME=${BASH_SOURCE[0]}
      ;;
    zsh)
      _SCRIPT_FILENAME=${0}
      ;;
    fish)
      # 有生之年可能会适配，主要是 fish 语法太傻逼了。。。
      _SCRIPT_FILENAME=${0}
      ;;
    *)
      _SCRIPT_FILENAME=`ps -p $$ --no-headers -o comm`sh
  esac
}

function auto_tools_help() {
  printf ' \033[31;1mYou can execute the following command.\033[0m\n'
  printf '   \033[32;1mauto_tools_help\033[0m\n'
  printf '   \033[32;1mauto_conf_locale\033[0m\n'
  printf '   \033[32;1mauto_conf_env\033[0m\n'
  printf '   \033[32;1mauto_conf_net\033[0m\n'
  printf '   \033[32;1mauto_conf_iptable\033[0m\n'
  printf '   \033[32;1mauto_conf_pacman\033[0m\n'
  printf '   \033[32;1mauto_conf_sshd\033[0m\n'
  printf '   \033[32;1mauto_conf_shell\033[0m\n'
  printf '   \033[32;1mauto_conf_utility_software\033[0m\n'
  printf '   \033[32;1mauto_conf_bootloader\033[0m\n'
  printf '   \033[32;1mauto_conf_vps2arch\033[0m\n'
  printf '   \033[32;1mauto_install_arch\033[0m\n'
  if [[ ! ${_SCRIPT_LOAD} ]]; then
    printf ' \033[31;1mIf"command not found" occurs, please start the script with the following command\033[0m\n'
    printf "   \033[32;1m\". ${_SCRIPT_FILENAME}\" or \"source ${_SCRIPT_FILENAME}\"\033[0m\n"
  fi
}

function auto_conf_locale() {
  timedatectl set-timezone ${_TIMEZONE}
  timedatectl set-ntp true
  hwclock --systohc
  sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
  sed -i 's/#en_SG.UTF-8 UTF-8/en_SG.UTF-8 UTF-8/' /etc/locale.gen
  sed -i 's/#zh_CN.UTF-8 UTF-8/zh_CN.UTF-8 UTF-8/' /etc/locale.gen
  if [[ ${_LANG} != 'en_US.UTF-8' && ${_LANG} != 'en_SG.UTF-8' && ${_LANG} != 'zh_CN.UTF-8' ]]; then
    sed -i "s/#${_LANG} UTF-8/${_LANG} UTF-8/" /etc/locale.gen
  fi
  echo "LANG=${_LANG}" > /etc/locale.conf
}

function auto_conf_env() {
  cat > ${HOME}/.pam_environment <<-EOF
    XDG_CACHE_HOME  DEFAULT=@{HOME}/.cache
    XDG_CONFIG_HOME DEFAULT=@{HOME}/.config
    XDG_DATA_HOME   DEFAULT=@{HOME}/.local/share
    XDG_STATE_HOME  DEFAULT=@{HOME}/.local/state
    XDG_DATA_DIRS   DEFAULT=/usr/local/share:/usr/share
    XDG_CONFIG_DIRS DEFAULT=/etc/xdg

    GNUPGHOME       DEFAULT=\${XDG_DATA_HOME}/gnupg
    VSCODE_PORTABLE DEFAULT=\${XDG_DATA_HOME}/vscode
    HISTFILE        DEFAULT=\${XDG_STATE_HOME}/zsh/history
    _JAVA_OPTIONS   DEFAULT=-Djava.util.prefs.userRoot=\${XDG_CONFIG_HOME}/java


    INPUT_METHOD    DEFAULT=${_INPUT_METHOD}
    XMODIFIERS      DEFAULT=\@im=${_INPUT_METHOD}
    GTK_IM_MODULE   DEFAULT=${_INPUT_METHOD}
    QT_IM_MODULE    DEFAULT=${_INPUT_METHOD}
    SDL_IM_MODULE   DEFAULT=${_INPUT_METHOD}

    EDITOR          DEFAULT=${_EDITOR}
    VISUAL          DEFAULT=${_EDITOR}
    SUDO_EDITOR     DEFAULT=${_EDITOR}
	EOF
  # Prevent the unavailability of environment variables caused by not restarting the terminal
  export GNUPGHOME=${HOME}/.local/share/gnupg
  if [[ -d ${HOME}/.gnupg ]]; then
    rm ${HOME}/.gnupg
  fi
}

function auto_conf_net() {
  # 这行代码是从 vps2arch 那里抄过来的. 感谢 vps2arch 的作者！
  # Black Magic!

	local gateway dev

	read -r dev gateway <<-EOF
		`awk '$2 == "00000000" {
      ip = strtonum(sprintf("0x%s", $3));
		  printf ("%s\t%d.%d.%d.%d", $1,
		    rshift(and(ip,0x000000ff),00), rshift(and(ip,0x0000ff00),08),
		    rshift(and(ip,0x00ff0000),16), rshift(and(ip,0xff000000),24));
      exit;
    }' < /proc/net/route`
	EOF

	cat > /etc/systemd/network/10-default.link <<-EOF
		[Match]
		MACAddress=`cat /sys/class/net/${dev}/address`

		[Link]
		Name=${dev}
	EOF
	cat > /etc/systemd/network/default.network <<-EOF
		[Match]
		Name=${dev}

		[Network]
		Gateway=${gateway}
	EOF
	echo "Address=`ip addr show dev ${dev} | awk '($1 == "inet") { print $2 }'`" >> /etc/systemd/network/default.network
  echo "nameserver $_DNS_SERVER" > /etc/resolv.conf
  cat > /etc/hosts <<-EOF
		127.0.0.1       localhost
		::1             localhost
    127.0.0.1       ${_HOSTNAME}
    ::1             ${_HOSTNAME}
	EOF
  echo ${_HOSTNAME} > /etc/hostname

  systemctl enable --now systemd-resolved
	systemctl enable --now systemd-networkd
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

  systemctl enable --now iptables
  systemctl enable --now ip6tables
}

function auto_conf_pacman() {
  # Configure pacman mirror list.
  cat > /etc/pacman.d/mirrorlist <<-EOF
    #Server = https://cloudflaremirrors.com/archlinux/\$repo/os/\$arch
    Server = https://mirrors.bfsu.edu.cn/archlinux/\$repo/os/\$arch
    Server = https://mirrors.neusoft.edu.cn/archlinux/\$repo/os/\$arch
    Server = https://mirrors.tuna.tsinghua.edu.cn/archlinux/\$repo/os/\$arch
	EOF

  cat > /etc/pacman.d/mirrorlist-cn <<-EOF
    Server = https://mirrors.bfsu.edu.cn/archlinuxcn/\$arch
    Server = https://mirrors.tuna.tsinghua.edu.cn/archlinuxcn/\$arch
	EOF

  # Configure pacman config file.
  sed -i 's/#UseSyslog/UseSyslog/' /etc/pacman.conf
  sed -i 's/#Color/Color/' /etc/pacman.conf
  sed -i 's/#VerbosePkgLists/VerbosePkgLists/' /etc/pacman.conf
  sed -i 's/#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf

  if [[ -f '/version' ]]; then
    pacman-key --init && pacman-key --populate archlinux
  fi

  if [[ ! -f '/version' ]]; then
    cat >> /etc/pacman.conf <<-EOF
      [archlinuxcn]
      Include = /etc/pacman.d/mirrorlist-cn

      [zhullyb]
      Server = https://pkg.web-worker.cn/zhullyb

      #[web-worker]
      #Server = https://pkg.web-worker.cn/archlinux
		EOF
    pacman --noconfirm -Sy archlinuxcn-keyring zhullyb-keyring #web-worker-keyring
    pacman-key --lsign-key zhullyb
  fi
}

function auto_conf_sshd() {
  if [[ ! -x `command -v ssh` ]]; then
    pacman --noconfirm -S openssh
  fi

  iptables  -A INPUT -p tcp --dport 22 -j ACCEPT
  ip6tables -A INPUT -p tcp --dport 22 -j ACCEPT

  iptables-save  > /etc/iptables/iptables.rules
  ip6tables-save > /etc/iptables/ip6tables.rules

  systemctl restart iptables
  systemctl restart ip6tables

  if [[ ! -d ${HOME}/.ssh ]]; then
    install -D -m 700 -o root -g root -d ${HOME}/.ssh
  fi
  if [[ ${_ROOT_PASSWORD} ]]; then
    echo root:${_ROOT_PASSWORD}|chpasswd
  fi
  echo ${_SSH_PUBKEY} > ${HOME}/.ssh/authorized_keys

  # Allow Pubkey Authentication
  sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
  # Forbid Password Authentication
  sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
  sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
  # 防止长时间无操作会话断开
  sed -i 's/#ClientAliveInterval 0/ClientAliveInterval 60/' /etc/ssh/sshd_config
  # Forwarding
  sed -i 's/#AllowAgentForwarding yes/AllowAgentForwarding yes/' /etc/ssh/sshd_config
  sed -i 's/#AllowTcpForwarding yes/AllowAgentForwarding yes/' /etc/ssh/sshd_config
  sed -i 's/#X11Forwarding no/X11Forwarding yes/' /etc/ssh/sshd_config
  sed -i 's/#X11DisplayOffset 10/X11DisplayOffset 10/' /etc/ssh/sshd_config
  sed -i 's/#X11UseLocalhost yes/X11UseLocalhost yes/' /etc/ssh/sshd_config
  echo 'StreamLocalBindUnlink yes' >> /etc/ssh/sshd_config

  systemctl enable --now sshd
}

function auto_conf_shell() {
  pacman --noconfirm -S zsh oh-my-zsh-git zsh-autosuggestions zsh-syntax-highlighting
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

function auto_conf_utility_software() {
  pacman --noconfirm -S htop nano git gpg
  if [[ -d ../.config ]]; then
    cp -r ../.config ${HOME}/
  fi
}

function auto_conf_bootloader() {
  if [[ ! -d /sys/firmware/efi/efivars ]]; then
    if [[ ! -x `command -v grub-install` ]]; then
      pacman --noconfirm -S grub
    fi
    grub-install --target=i386-pc --recheck --force /dev/`cat /proc/diskstats | awk '{print $3}' | grep '[a-z]d[a-z]' | grep -v '[0-9]' | head -n 1`
    grub-mkconfig -o /boot/grub/grub.cfg
  fi
}

function auto_conf_vps2arch() {
  # Stop, Disable And Remove Reflector.
  systemctl disable --now reflector
  pacman --noconfirm -Rsn reflector

  # Remove lvm2.
  pacman --noconfirm -Rsn lvm2

  # Remove linux kernel, and Install linux-zen kernel.
  pacman --noconfirm -Rsn linux
  pacman --noconfirm -S linux-zen
  auto_conf_bootloader
}

function auto_install_arch_create_user() {
  pacman --noconfirm -S sudo
  sed -i 's/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers

  useradd ${_USER_NAME} -m -G wheel
  if [[ ${_USER_PASSWORD} ]]; then
    echo ${_USER_NAME}:${_USER_PASSWORD}|chpasswd
  fi

  install -D -m 600 -o ${_USER_NAME} -g wheel ${HOME}/.pam_environment /home/${_USER_NAME}/.pam_environment

  if [[ ! -d /home/${_USER_NAME}/.ssh ]]; then
    install -D -m 700 -o ${_USER_NAME} -g wheel -d /home/${_USER_NAME}/.ssh
  fi
  echo ${_SSH_PUBKEY} > /home/${_USER_NAME}/.ssh/authorized_keys

  install -D -m 700 -o ${_USER_NAME} -g wheel ${HOME}/.zshrc /home/${_USER_NAME}/.zshrc
  chsh -s /bin/zsh

  if [[ -d ../.config ]]; then
    cp -r ../.config ${HOME}/
  fi
}

function auto_install_arch_p1() {
  local rootfs_path base_url rootfs_url sha256sums_url

  rootfs_path=/tmp/arch-rootfs
  base_url=https://mirrors.bfsu.edu.cn/lxc-images/images/archlinux/current/amd64/default/

  if [[ ! -d ${rootfs_path} ]]; then
    mkdir -p ${rootfs_path}
  fi

  if [[ -x `command -v wget` ]]; then
    rootfs_url=${base_url}`wget -q -O - ${base_url} | grep -o '[0-9].*/"' | tail -n1 | sed -e 's/"//'`rootfs.tar.xz
    sha256sums_url=${base_url}`wget -q -O - ${base_url} | grep -o '[0-9].*/"' | tail -n1 | sed -e 's/"//'`SHA256SUMS
  	wget -q --show-progress ${rootfs_url}
    wget -q --show-progress ${sha256sums_url}
  elif [[ -x `command -v curl` ]]; then
    rootfs_url=${base_url}`curl -s ${base_url} | grep -o '[0-9].*/"' | tail -n1 | sed -e 's/"//'`rootfs.tar.xz
    sha256sums_url=${base_url}`curl -s ${base_url} | grep -o '[0-9].*/"' | tail -n1 | sed -e 's/"//'`SHA256SUMS
  	curl -fLO ${rootfs_url}
    curl -fLO ${sha256sums_url}
  else
	  echo "This script needs wget or curl." >&2
	  exit 2
  fi

  echo $(cat SHA256SUMS | awk '$2 == "rootfs.tar.xz"') > SHA256SUMS
  sha256sum -c SHA256SUMS > /dev/null
  if [[ $? != 0 ]]; then
    rm rootfs.tar.xz SHA256SUMS
    auto_install_arch_p1
  fi

  tar xf rootfs.tar.xz -C ${rootfs_path}
  mount --bind ${rootfs_path} ${rootfs_path}

  install -D -m 755 -o root -g root ${_SCRIPT_FILENAME} ${rootfs_path}/${_SCRIPT_FILENAME}
  echo "_SCRIPT_FILENAME_STATIC=${_SCRIPT_FILENAME}" >> ${rootfs_path}/${_SCRIPT_FILENAME}
  echo 'auto_install_arch' >> ${rootfs_path}/${_SCRIPT_FILENAME}
  ${rootfs_path}/bin/arch-chroot ${rootfs_path} /${_SCRIPT_FILENAME}
}

function auto_install_arch_p2() {
  local mount_path

  mount_path='/mnt'

  mount `df -h / | awk '$6 == "/" {print $1}'` ${mount_path}
  rm -rf `find ${mount_path} -maxdepth 1 | grep -E -v "(dev|proc|run|sys|tmp)" | awk 'NR!=1 {print}' | sort`
  auto_conf_pacman
  pacstrap ${mount_path} base base-devel linux-zen
  genfstab -U ${mount_path} >> ${mount_path}/etc/fstab
  rm ${mount_path}/etc/resolv.conf
  install -D -m 755 -o root -g root /${_SCRIPT_FILENAME_STATIC} ${mount_path}/${_SCRIPT_FILENAME_STATIC}
  arch-chroot ${mount_path} /${_SCRIPT_FILENAME_STATIC}
}

function auto_install_arch_p3() {
  auto_conf_net
  auto_conf_sshd
  auto_conf_bootloader

  sed -i '$d' /${_SCRIPT_FILENAME_STATIC}
  sed -i '$d' /${_SCRIPT_FILENAME_STATIC}
  mv /${_SCRIPT_FILENAME_STATIC} /root/${_SCRIPT_FILENAME_STATIC}
  echo 'auto_install_arch_p4' >> /root/${_SCRIPT_FILENAME_STATIC}
  echo "source /root/${_SCRIPT_FILENAME_STATIC}" > /root/.bashrc
  sync
  reboot
}

function auto_install_arch_p4() {
  auto_conf_locale
  auto_conf_iptable
  auto_conf_sshd
  auto_conf_pacman
  auto_conf_env
  auto_conf_shell
  auto_conf_utility_software

  if [[ ${_USER_NAME} ]]; then
    auto_install_arch_create_user
  fi

  sed -i '$d' /root/${_SCRIPT_FILENAME_STATIC}
}

function auto_install_arch() {
  if [[ `cat /etc/*-release | grep -E -w 'ID=.*' | awk -F '=' '{print $2}'` != 'arch' ]]; then
    auto_install_arch_p1
  else
    if [[ -f '/version' ]]; then
      auto_install_arch_p2
    else
      auto_install_arch_p3
    fi
  fi
}

init
# If auto_conf_arch is not loaded, will execute following code.
if [[ ! -f '/version' ]]; then
  if [[ ! ${_SCRIPT_LOAD} ]]; then
    auto_tools_help
    _SCRIPT_LOAD='\033[31;1mThis script is load, you can use\033[0m \033[32;1mauto_tools_help\033[0m \033[31;1mto get help.\033[0m\n'
  else
    printf "${_SCRIPT_LOAD}"
  fi
fi
# HACK: Maybe you need install App: axel zip unzip neofetch v2ray php php-fpm php-sqlite nginx-mainline certbot-nginx goaccess
# HACK: 对接 Tencent Cloud SDK
# ip(6)table: Tencent Cloud SDK
  #iptables  -A INPUT -p tcp --dport 80 -j ACCEPT
  #ip6tables -A INPUT -p tcp --dport 80 -j ACCEPT
  #iptables  -A INPUT -p tcp --dport 443 -j ACCEPT
  #ip6tables -A INPUT -p tcp --dport 443 -j ACCEPT
