#!/bin/bash
INST_ARCH=x86_64
INST_NAME="Plogue sforzando"
INST_PATH=/opt/Plogue
INST_PKGS=(
    plogue-aria_1.982_amd64.deb
    plogue-sforzando_1.982_amd64.deb
    plogue-tablewarp2_1.982_amd64.deb
)

set -euo pipefail

# Function for Debian-based systems.
# This will internally check for required dependencies
debian_branch() {
    echo "Identified Debian-derived distribution."

	echo "This script will require 'sudo' and call 'apt' to install a few .deb files"
	echo "into '${INST_PATH}' and also integrate into your desktop (/usr/share)"
	echo "It will also try and install any missing dependencies."
	read -p "Continue(Y/N)? " answer
	if [[ "$answer" != "Y" && "$answer" != "y" ]]; then
		echo "Exiting..."
		exit 1
	fi

	for deb in "${INST_PKGS[@]}"; do
	  [[ -f $deb ]] || { echo "Package '$deb' not found!" >&2; exit 1; }
      echo "---------------------------------------------------------"
	  echo "Installing $deb"
	  #sudo dpkg -i $deb
	  #dpkg does not automatically install dependencies. and the -y removes some Y/N prompts
	  sudo apt install -y "./$deb"
	done
}

# Function for non-Debian systems
non_debian_branch() {

    echo "Running other-distro install..."
	echo -n "Checking for presence of basic utilities: "
	for cmd in ar tar sudo rsync; do
	  command -v "$cmd" &>/dev/null || {
		echo "ERROR: '$cmd' not found – install binutils (for ar) and tar." >&2
		exit 1
	  }
	done
	echo "Ok!"

	echo "---------------------------------------------------------------------------------"
	echo "This script will attempt to install the necessary files on your system."
	echo "Compatibility may vary, as it was originally designed for Debian-based distros."
	echo "It extracts various .deb files and places the required components accordingly:"
	echo "namely ${INST_PATH}, /usr/lib/vst3 (and CLAP), and /usr/share/doc (and icons)."

	read -p "Continue(Y/N)? " answer

	if [[ "$answer" != "Y" && "$answer" != "y" ]]; then
		echo "Exiting..."
		exit 1
	fi

	# -----------------------------------------------------------------------------#
	# unpack loop
	for deb in "${INST_PKGS[@]}"; do
		[[ -f $deb ]] || { echo "Package '$deb' not found!" >&2; exit 1; }

		#tmp=$(mktemp -d)
		tmp="TMP_EXTRACTED"

		echo "Unpacking $deb into $tmp"

		mkdir -p $tmp
		#trap 'rm -rf "$tmp"' RETURN  # clean-up even on failure
		(
			cd "$tmp"
			ar x "$OLDPWD/$deb"                # extracts control.tar.* data.tar.* etc.
			data_archive=$(echo data.tar.*)    # handles .xz .zst .gz …
			[[ -f $data_archive ]] || { echo "No data.tar.* inside $deb" >&2; exit 1; }

			tar --extract \
			--file="$data_archive" \
			--directory="." \
			--preserve-permissions \
			--no-same-owner
		)
	done

	#We could have extracted to "/" but this is too dangerous!
	
	#we want to fake dpkg remember? all that is root:root
	sudo chown -R root:root $tmp/ 

	echo "Copying required files to /opt/Plogue"
	sudo rsync -a --info=progress2 $tmp/opt/Plogue/ /opt/Plogue

	echo "Copying vst3 plugin into /usr/lib/vst3"
	sudo rsync -a --info=progress2 $tmp/usr/lib/vst3/ /usr/lib/vst3

	echo "Copying clap plugin into /usr/lib/clap"
	sudo rsync -a --info=progress2 $tmp/usr/lib/clap/ /usr/lib/clap

	echo "Copying '.desktop' integration to /usr/share/applications"
	sudo rsync -a --info=progress2 $tmp/usr/share/applications/ /usr/share/applications
	
	echo "Copying Documentation to /usr/share/doc"
	sudo rsync -a --info=progress2 $tmp/usr/share/doc/ /usr/share/doc
	
	echo "Copying Icons to /usr/share/icons/hicolor/256x256/apps"
	sudo rsync -a --info=progress2 $tmp/usr/share/icons/hicolor/256x256/apps/ /usr/share/icons/hicolor/256x256/apps

	echo "Refreshing icons and application caches"
	sudo gtk-update-icon-cache --force /usr/share/icons/hicolor
	sudo update-desktop-database /usr/share/applications

	echo "Deleting $tmp"
	sudo rm -rf $tmp
}

# -----------------------------------------------------------------------------#
# -----------------------------------------------------------------------------#
# -----------------------------------------------------------------------------#
# -----------------------------------------------------------------------------#

LOCAL_ARCH=$(uname -m)

echo "---------------------------------------------------------"
echo "${INST_NAME} Install script"
echo "---------------------------------------------------------"
echo "Local architecture: ${LOCAL_ARCH}"

if [ "$LOCAL_ARCH" != "$INST_ARCH" ]; then
    echo "Error! You are trying to install '${INST_ARCH}' packages on a '${LOCAL_ARCH}' distro!"
    echo "Please download and run the appropriate archive."
	exit 1
fi

echo -n "Checking for presence of '${INST_PATH}'... "
if [ -d ${INST_PATH} ]; then
	echo " it already exists!"
else
	echo " does not exist."
fi

# Main logic
if [[ -f /etc/debian_version ]]; then
    debian_branch
else
    non_debian_branch
fi

echo "---------------------------------------------------------"
echo "${INST_NAME} installation is completed!"
echo "---------------------------------------------------------"