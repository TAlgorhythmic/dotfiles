#!/bin/bash
set -euo pipefail

# USER is set by login, not by bash itself, so `set -u` would kill the script
# on the usermod lines if this is run from a context that lacks it.
USER="${USER:-$(id -un)}"

PACKAGES="ark audacious easyeffects thunar thunar-archive-plugin zen-browser-bin pavucontrol gimp yay tree fastfetch zip zig zellij xz xvidcore xdg-desktop-portal-hyprland x265 x264 wl-clipboard wireplumber wine-cachyos wev wavpack vulkan-tools virtiofsd virt-viewer virt-manager virglrenderer vim valgrind unzip unrar twolame ttf-nerd-fonts-symbols ttf-nerd-fonts-symbols-mono tree-sitter-cli swtpm swaync svt-av1 strace spice-vdagent speex socat sfizz sassc rustup rofi ripgrep qt6-wayland qt6ct qt5-wayland qt5ct qemu-desktop python python-pip python-pipx postgresql playerctl pipewire pipewire-alsa pipewire-jack pipewire-pulse papirus-icon-theme opusfile opus openssh opencore-amr openal okular obs-studio obs-vkcapture nwg-look noto-fonts noto-fonts-extra noto-fonts-emoji noto-fonts-cjk nodejs npm ninja mpv neovim meson maven man-pages man-db lutris lua luarocks lsp-plugins llvm lldb lld libwebp libvpx libvorbis libvirt libtheora libreoffice-fresh libreoffice-fresh-ca libnotify libmpeg2 libmad libheif libdv libde265 libdca libavif less lame kvantum kvantum-qt5 kotlin jq jdk-openjdk jdk21-openjdk jasper iwd ironbar iptables hyprshutdown hyprshot hyprpolkitagent hyprpicker hyprpaper hyprlock hyprland hypridle hwinfo gtk4 gtk4-layer-shell gstreamer gst-plugins-ugly gst-plugins-good gst-plugins-bad gst-plugins-base gst-plugin-pipewire gst-libav gradle go gnome-keyring glu viu github-cli git ghostty gdb gcc gamemode flac filelight ffmpegthumbnailer ffmpeg fakeroot faad2 faac egl-wayland2 edk2-ovmf docker docker-compose docker-buildx dnsmasq dmidecode discord dav1d dart cmake clinfo claude-code clang chromium calf brightnessctl base-devel aom a52dec eyedropper qalculate-gtk curl wget adwaita-color-schemes adwaita-fonts adwaita-icon-theme"
AUR_PACKAGES="virtio-win eww bitwig-studio-5 decent-sampler-bin bbe"

# Hardware video acceleration: the VA-API/VDPAU frontends plus diagnostic tools
# (vainfo, vdpauinfo). libvdpau-va-gl maps VDPAU onto VA-API for the GPUs that
# no longer ship a native VDPAU driver.
VAAPI_PACKAGES="libva libva-utils libvdpau vdpauinfo libvdpau-va-gl"

echo "Detecting gpu..."
# Append the backend for every GPU actually present. The PCI vendor ID is read
# straight from sysfs so this needs no pciutils and handles hybrid laptops
# (Intel iGPU + NVIDIA dGPU both match and both get their driver).
for VENDOR in $(cat /sys/class/drm/card*/device/vendor 2>/dev/null | sort -u); do
    case "${VENDOR}" in
        0x1002) # AMD/ATI: VA-API lives in mesa now, which provides libva-mesa-driver
            VAAPI_PACKAGES="${VAAPI_PACKAGES} mesa vulkan-radeon"
            ;;
        0x8086) # Intel: intel-media-driver covers Broadwell (Gen8, 2014) and newer,
                # vpl-gpu-rt adds oneVPL on Gen12+. On older iGPUs replace both
                # with libva-intel-driver.
            VAAPI_PACKAGES="${VAAPI_PACKAGES} mesa vulkan-intel intel-media-driver vpl-gpu-rt"
            ;;
        0x10de) # NVIDIA: libva-nvidia-driver bridges VA-API onto NVDEC. The kernel
                # module itself is left to whatever driver package is installed.
            VAAPI_PACKAGES="${VAAPI_PACKAGES} libva-nvidia-driver"
            # nvidia-utils ships the VDPAU/NVDEC libs, but only ask for it when
            # nothing already provides it: the legacy branches (nvidia-580xx-utils
            # and friends) both provide AND conflict with the name, so requesting
            # it outright would drag a Maxwell/Pascal/Volta box onto the current
            # driver, which dropped support for those cards.
            pacman -T nvidia-utils >/dev/null 2>&1 || VAAPI_PACKAGES="${VAAPI_PACKAGES} nvidia-utils"
            ;;
    esac
done

echo "Installing packages..."
sudo pacman -Syu --needed ${PACKAGES} ${VAAPI_PACKAGES}

echo "Installing aur packages..."
yay -Syu --needed ${AUR_PACKAGES}

# User setup
echo "Setting up user groups and daemons..."

sudo systemctl enable --now libvirtd.socket
sudo systemctl start --now libvirtd.socket
sudo systemctl enable --now docker
sudo systemctl start --now docker
sudo usermod -aG libvirt "$USER"
sudo usermod -aG docker "$USER"
sudo usermod -aG postgres "$USER"
systemctl --user enable hyprpolkitagent

echo "done"

# setup rustup
echo "Setting up rust..."
rustup default stable
echo "done"

# TODO qalculate config

# Android + flutter
echo "Installing android sdk + flutter..."

export ANDROID_HOME="$HOME/Android/Sdk"
mkdir -p $ANDROID_HOME
mkdir -p android
cd android || exit 1
curl https://dl.google.com/android/repository/commandlinetools-linux-15859902_latest.zip -o tools.zip
unzip tools.zip
mkdir -p "$ANDROID_HOME/cmdline-tools"
rm -rf "$ANDROID_HOME/cmdline-tools/latest"
mv cmdline-tools "$ANDROID_HOME/cmdline-tools/latest"
cd .. || exit 1
rm -rf android
# sdkmanager stops reading once every license is accepted, so `yes` dies of
# SIGPIPE (141) -- which pipefail would turn into a fatal error. Drop pipefail
# for just this pipeline; without it the status is sdkmanager's own, so a real
# failure still aborts under set -e.
set +o pipefail
yes | "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" --sdk_root="$ANDROID_HOME" --licenses
set -o pipefail
"$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" --sdk_root="$ANDROID_HOME" \
	"platform-tools" \
	"platforms;android-34" "platforms;android-35" "platforms;android-36" \
	"build-tools;34.0.0" "build-tools;35.0.0" "build-tools;37.0.0" \
	"ndk;29.0.14206865" \
	"cmake;3.22.1"

[ -d "$HOME/flutter" ] || git clone -b stable https://github.com/flutter/flutter "$HOME/flutter"
"$HOME/flutter/bin/flutter" config --android-sdk "$ANDROID_HOME"
"$HOME/flutter/bin/flutter" config --jdk-dir /usr/lib/jvm/java-21-openjdk/

echo "done"

# zshrc + oh-my-zsh
echo "Installing zsh config..."

rm -rf "$HOME/.oh-my-zsh"
rm -f "$HOME/.zshrc"
cp -r .oh-my-zsh $HOME
cp .zshrc $HOME

echo "done"

# TODO .profile

# home bin scripts and zellij-picker compile
echo "Installing home stuff..."

cp -r bin $HOME
cd zellij-picker || exit 1
cargo build --release
mkdir -p "$HOME/bin"
cp target/release/zellij-picker "$HOME/bin/"
cd .. || exit 1

echo "done"

# Install orchis pink theme
echo "Installing gtk theme (Orchis-Pink-Dark)..."

rm -rf Orchis-theme
git clone https://github.com/vinceliuice/Orchis-theme
cd Orchis-theme || exit 1
./install.sh -t pink -c dark -s standard -l
cd .. || exit 1
rm -rf Orchis-theme

echo "done"

# apply .local and .config
echo "Installing dotfiles..."
mkdir -p "$HOME/.config" "$HOME/.local"
cp -a .config/. "$HOME/.config/"
cp -a .local/.  "$HOME/.local/"

echo "done"

# Install sforzando
echo -n "Installing sforzando..."

mkdir -p sforzando
cd sforzando || exit 1
curl https://sforzando.s3.us-east-1.amazonaws.com/LINUX_plogue-sforzando_1.982_x86_64.zip -o sforzando.zip
unzip -j sforzando.zip
sudo ./install_sforzando.sh
cd .. || exit 1
rm -rf sforzando

echo " done"
