#!/bin/bash

PACKAGES="ark audacious easyeffects thunar thunar-archive-plugin zen-browser-bin pavucontrol gimp yay tree fastfetch xvidcore x265 x264 wl-clipboard wine-cachyos wev wavpack vulkan-tools vim unzip unrar twolame ttf-nerd-fonts-symbols ttf-nerd-fonts-symbols-mono swaync svt-av1 speex hyprshot sfizz sassc rustup rofi qt6-wayland qt6ct qt5-wayland qt5ct postgresql playerctl pipewire pipewire-alsa opusfile opus openssh opencore-amr openal okular obs-studio obs-vkcapture nwg-look noto-fonts noto-fonts-extra noto-fonts-emoji noto-fonts-cjk mpv neovim man-pages man-db lutris lsp-plugins lldb libwebp libvpx libvorbis libtheora libreoffice-fresh libreoffice-fresh-ca libmpeg2 libmad libheif libdv libde265 libdca libavif less lame kvantum kvantum-qt5 jdk-openjdk jdk21-openjdk jasper iwd ironbar hyprshutdown hyprshot hyprpicker hyprpaper hyprlock hyprland hypridle hwinfo gstreamer gst-plugins-ugly gst-plugins-good gst-plugins-bad gst-plugins-base gst-plugin-pipewire gst-libav gnome-keyring viu github-cli git ghostty gamemode flac filelight ffmpegthumbnailer ffmpeg fakeroot faad2 faac eww egl-wayland2 docker docker-compose docker-buildx discord dav1d dart cmake clinfo claude-code chromium calf aom a52dec eyedropper qalculate-gtk rustup curl wget adwaita-color-schemes adwaita-fonts adwaita-icon-theme"
AUR_PACKAGES="bitwig-studio-5 decent-sampler-bin bbe"

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

echo "Installing aur packages"
yay -Syu --needed ${AUR_PACKAGES}

# TODO qalculate config
# TODO Android + flutter
# TODO zshrc + oh-my-zsh
# TODO .profile
# TODO zellij-picker code compile and stuff
# TODO home bin
# TODO set themes Orchis pink dark + 
# TODO setup fonts
# TODO apply .local and .config
# TODO sforzando
