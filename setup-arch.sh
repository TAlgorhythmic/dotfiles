#!/bin/bash

PACKAGES="ark audacious easyeffects thunar thunar-archive-plugin zen-browser-bin pavucontrol gimp yay tree fastfetch zig zellij xvidcore xdg-desktop-portal-hyprland x265 x264 wl-clipboard wireplumber wine-cachyos wev wavpack vulkan-tools vim valgrind unzip unrar twolame ttf-nerd-fonts-symbols ttf-nerd-fonts-symbols-mono tree-sitter-cli swaync svt-av1 strace speex socat sfizz sassc rustup rofi ripgrep qt6-wayland qt6ct qt5-wayland qt5ct python python-pip python-pipx postgresql playerctl pipewire pipewire-alsa pipewire-jack pipewire-pulse papirus-icon-theme opusfile opus openssh opencore-amr openal okular obs-studio obs-vkcapture nwg-look noto-fonts noto-fonts-extra noto-fonts-emoji noto-fonts-cjk nodejs npm ninja mpv neovim meson maven man-pages man-db lutris lua luarocks lsp-plugins llvm lldb lld libwebp libvpx libvorbis libtheora libreoffice-fresh libreoffice-fresh-ca libnotify libmpeg2 libmad libheif libdv libde265 libdca libavif less lame kvantum kvantum-qt5 jq jdk-openjdk jdk21-openjdk jasper iwd ironbar hyprshutdown hyprshot hyprpolkitagent hyprpicker hyprpaper hyprlock hyprland hypridle hwinfo gtk4 gtk4-layer-shell gstreamer gst-plugins-ugly gst-plugins-good gst-plugins-bad gst-plugins-base gst-plugin-pipewire gst-libav gradle go gnome-keyring viu github-cli git ghostty gdb gcc gamemode flac filelight ffmpegthumbnailer ffmpeg fakeroot faad2 faac egl-wayland2 docker docker-compose docker-buildx discord dav1d dart cmake clinfo claude-code clang chromium calf brightnessctl base-devel aom a52dec eyedropper qalculate-gtk curl wget adwaita-color-schemes adwaita-fonts adwaita-icon-theme"
AUR_PACKAGES="eww bitwig-studio-5 decent-sampler-bin bbe"

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
# TODO set themes Orchis pink dark: build/install it separately, NOT from the
#      package list -- it links against the installed libadwaita/gtk and has to
#      match them. nwg-look expects the theme name "Orchis-Pink-Dark".
#      The Apple-cursors cursor theme it pairs with now ships in this repo, at
#      .local/share/icons/, so that one just needs .local applied.
# TODO setup fonts -- IosevkaTerm Nerd Font already ships in
#      .local/share/fonts, so this is covered by applying .local (no package)
# TODO apply .local and .config
# TODO sforzando
