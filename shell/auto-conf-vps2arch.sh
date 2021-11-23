# File: auto-conf-vps2arch.sh
# Author: Star_caorui
# Last modified: UTC+8 2021-11-23 07:43

# Stop, Disable And Remove Reflector.
systemctl stop reflector
systemctl disable reflector
pacman -Rsn reflector

# Remove lvm2.
pacman -Rsn lvm2

# Remove linux kernel, and Install linux-zen kernel.
pacman -Rsn linux
pacman -S linux-zen
grub-mkconfig -o /boot/grub/grub.cfg

# Configure pacman mirror list.
echo '#Server = https://cloudflaremirrors.com/archlinux/$repo/os/$arch
Server = https://mirrors.bfsu.edu.cn/archlinux/$repo/os/$arch
Server = https://mirrors.neusoft.edu.cn/archlinux/$repo/os/$arch
Server = https://mirrors.tuna.tsinghua.edu.cn/archlinux/$repo/os/$arch' > /etc/pacman.d/mirrorlist

# Configure pacman config file.
sed -e 's/#UseSyslog/UseSyslog/' /etc/pacman.conf
sed -e 's/#Color/Color/' /etc/pacman.conf
sed -e 's/#VerbosePkgLists/VerbosePkgLists/' /etc/pacman.conf
sed -e 's/#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
echo -e '\n[archlinuxcn]' >> /etc/pacman.conf
echo 'Include = /etc/pacman.d/mirrorlist-cn' >> /etc/pacman.conf
echo 'Server = https://mirrors.bfsu.edu.cn/archlinuxcn/$arch
Server = https://mirrors.tuna.tsinghua.edu.cn/archlinuxcn/$arch' > /etc/pacman.d/mirrorlist-cn
echo -e '\n[web-worker]' >> /etc/pacman.conf
echo 'Server = https://pkg.web-worker.cn/archlinux' >> /etc/pacman.conf
echo -e '\n[zhullyb]' >> /etc/pacman.conf
echo 'Server = https://pkg.web-worker.cn/zhullyb' >> /etc/pacman.conf
pacman -S archlinuxcn-keyring web-worker-keyring zhullyb-keyring

# Configure shell
pacman -S oh-my-zsh-git zsh-autosuggestions zsh-syntax-highlighting
ln -sf /usr/share/zsh/plugins/zsh-autosuggestions/ /usr/share/oh-my-zsh/plugins/
ln -sf /usr/share/zsh/plugins/zsh-syntax-highlighting/ /usr/share/oh-my-zsh/plugins/
echo 'XDG_CONFIG_HOME DEFAULT=@{HOME}/.config
XDG_CACHE_HOME  DEFAULT=@{HOME}/.cache
XDG_DATA_HOME   DEFAULT=@{HOME}/.local/share
XDG_STATE_HOME  DEFAULT=@{HOME}/.local/state
XDG_DATA_DIRS   DEFAULT=/usr/local/share:/usr/share
XDG_CONFIG_DIRS DEFAULT=/etc/xdg

GNUPGHOME       DEFAULT=${XDG_DATA_HOME}/gnupg
VSCODE_PORTABLE DEFAULT=${XDG_DATA_HOME}/vscode
_JAVA_OPTIONS   DEFAULT=-Djava.util.prefs.userRoot=${XDG_CONFIG_HOME}/java
HISTFILE        DEFAULT=${XDG_STATE_HOME}/zsh/history

GTK_IM_MODULE   DEFAULT=fcitx
QT_IM_MODULE    DEFAULT=fcitx
XMODIFIERS      DEFAULT=\@im=fcitx
INPUT_METHOD    DEFAULT=fcitx
SDL_IM_MODULE   DEFAULT=fcitx

EDITOR          DEFAULT=nano
VISUAL          DEFAULT=nano
SUDO_EDITOR     DEFAULT=nano' > ${HOME}/.pam_environment
echo '# Setting zsh cache.
ZSH_CACHE_DIR=${HOME}/.cache/zsh
if [[ ! -d ${ZSH_CACHE_DIR} ]]; then
  mkdir ${ZSH_CACHE_DIR}
fi

# Setting zsh comdump.
ZSH_COMPDUMP=${XDG_CACHE_HOME}/zsh/zcompdump-${SHORT_HOST}-${ZSH_VERSION}

# Setting zsh config.
ZSH="/usr/share/oh-my-zsh/"
DISABLE_AUTO_UPDATE="true"
ZSH_THEME="gnzh"
plugins=(sudo zsh-syntax-highlighting zsh-autosuggestions vscode)
source ${ZSH}/oh-my-zsh.sh' > ${HOME}/.zshrc
export GNUPGHOME="$XDG_DATA_HOME"/gnupg # Prevent the unavailability of environment variables caused by not restarting the terminal
rm ${HOME}/.gnupg
cp ../.config $HOME/ -r
chsh -s /bin/zsh
