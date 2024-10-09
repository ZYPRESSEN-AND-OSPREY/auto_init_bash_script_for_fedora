#!/bin/bash
# 检查系统类型
source /etc/os-release
configure_dnf() {
	if ! grep -q "^fastestmirror=True" /etc/dnf/dnf.conf; then
		echo "fastestmirror=True" | sudo tee -a /etc/dnf/dnf.conf
		echo "fastestmirror 已成功添加到 /etc/dnf/dnf.conf"
	else
		echo "fastestmirror 已经存在于 /etc/dnf/dnf.conf 中"
	fi
}
install_rpmfusion() {
	sudo dnf install -y "https://mirrors.rpmfusion.org/free/$1/rpmfusion-free-release-$(rpm -E %$2).noarch.rpm" \
	"https://mirrors.rpmfusion.org/nonfree/$1/rpmfusion-nonfree-release-$(rpm -E %$2).noarch.rpm"
}
 
if [ -f /etc/redhat-release ]; then
	case "$ID" in
	rocky)
	echo "This is Rocky Linux."
	sudo yum install -y dnf
	configure_dnf
	install_rpmfusion "el" "rhel"
;;
fedora)
echo "This is Fedora."
configure_dnf
install_rpmfusion "fedora" "fedora"
;;
*)
echo "This redhat-release is neither Rocky Linux nor Fedora."
exit 1
;;
esac
PKG_MANAGER="dnf"
INSTALL_CMD="sudo dnf install -y"
UPDATE_CMD="sudo dnf update -y"
elif [ -f /etc/arch-release ]; then
PKG_MANAGER="pacman"
INSTALL_CMD="sudo pacman -S --noconfirm"
UPDATE_CMD="sudo pacman -Syu --noconfirm"
else
echo "未知的Linux发行版"
exit 1
fi
echo "使用的包管理器是: $PKG_MANAGER"
# 更新和升级软件包列表
echo "Updating and upgrading package lists..."
$UPDATE_CMD
# 安装必要的软件包
echo "Installing essential packages..."
if [[ "$ID" == "rocky" ]]; then
	$INSTALL_CMD curl wget  g++ gcc gdb fish neovim vim translate-shell fastfetch neofetch tmux htop  ranger cockpit cockpit-machines -y
elif [[ "$ID" == "fedora" ]]; then
	$INSTALL_CMD curl wget  g++ gcc gdb fish neovim vim translate-shell fastfetch neofetch tmux htop cpu-x ranger cockpit cockpit-machines -y
else
	$INSTALL_CMD curl wget  g++ gcc gdb fish neovim vim translate-shell fastfetch neofetch tmux htop cpu-x ranger cockpit cockpit-machines -y
fi
sudo systemctl enable --now cockpit.socket
systemctl status cockpit.socket > cockpit.socket
echo "cockpit started ,you can see you machine at your ip_address:9090"
read -p "install packages need GUI?(Y/y/N)" GUIPACK
if [[ "$GUIPACK" =~ ^[Yy]$ ]]; then
	if [[ "$ID" == "rocky" ]]; then
		$INSTALL_CMD  putty remmina bleachbit -y
	elif [[ "$ID" == "fedora" ]]; then
		$INSTALL_CMD  putty remmina bleachbit sysmontask -y
	else
		$INSTALL_CMD  putty remmina bleachbit -y
	fi
	echo "GUI_PACKAGES install complete."
fi
# 更改默认shell为fish
echo "Changing default shell to fish..."
sudo chsh -s /usr/bin/fish
chsh -s /usr/bin/fish
read -p "Install KiCad, QUCS, and JLCEDA? (Y/y): " kicadin
if [[ "$kicadin" =~ ^[Yy]$ ]]; then
	if [[ "$ID" == "rocky" ]]; then
		echo "only JLCEDA can be install"
	elif [[ "$ID" == "fedora" ]]; then
		$INSTALL_CMD kicad qucs -y
	else
		$INSTALL_CMD kicad qucs -y
	fi
	wget https://image.lceda.cn/files/lceda-pro-linux-x64-2.2.27.1.zip
	unzip lceda-pro-linux-x64-2.2.27.1.zip
	sudo bash ./install.sh
	rm lceda-pro-linux-x64-2.2.27.1.zip
	echo "EDA software installation completed"
fi
#安装Visual Studio Code
echo "Installing Visual Studio Code..."
if [ "$PKG_MANAGER" = "pacman" ]; then
    sudo pacman -S --noconfirm base-devel git
    git clone https://aur.archlinux.org/visual-studio-code-bin.git
    cd visual-studio-code-bin
    makepkg -si --noconfirm
    cd ..
    rm -rf visual-studio-code-bin
elif [ "$PKG_MANAGER" = "dnf" ]; then
	sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
	sudo sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'
	sudo dnf check-update
	sudo dnf install code -y
	sudo dnf upgrade --refresh
	read -p "Install flatpak and some TOOLS? (Y/y): " clouds
	if [[ "$clouds" =~ ^[Yy]$ ]]; then
	    sudo dnf install -y flatpak
	    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
	    flatpak install -y flathub io.github.peazip.PeaZip com.github.flxzt.rnote
	fi
fi
read -p "Install Steam? (Y/y): " inssteam
if [[ "$inssteam" =~ ^[Yy]$ ]]; then
	if [ "$PKG_MANAGER" = "pacman" ]; then
		echo "your environment is arch,skip."
	elif [ "$PKG_MANAGER" = "dnf" ]; then
		sudo dnf install steam -y
	fi
fi
# 配置本地化
echo "Configuring locales..."
if [ "$PKG_MANAGER" = "dnf" ]; then
    sudo localectl set-locale LANG=en_US.UTF-8
elif [ "$PKG_MANAGER" = "pacman" ]; then
    sudo localectl set-locale LANG=en_US.UTF-8
else
    echo "Unsupported package manager: $PKG_MANAGER"
    exit 1
fi
cat cockpit.socket
rm cockpit.socket
echo "Installation and setup complete!"