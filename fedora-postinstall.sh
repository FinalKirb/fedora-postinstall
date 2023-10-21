#!/bin/bash
set -e # Exit the Script on Error Message

# TODO execute functions, create mother functions that run other functions (system_update -> update_flatpak % update_dnf)


# Redirect output to a log file in the same directory
LOG_FILE="fedora-postinstall.log"
ERROR_LOG_FILE="fedora-postinstall-error.log"
exec > >(tee -i "$LOG_FILE")
exec 2> >(tee -i "$ERROR_LOG_FILE")
echo
date

PACKAGES_DNF="vim tldr htop bpytop neofetch hwinfo gnome-tweaks timeshift veracrypt mpv steam libreoffice-base libreoffice-draw nextcloud-client goverlay mangohud vkbasalt gamemode virt-manager qemu wine winetricks"
PACKAGES_DNF_UNINSTALL="gnome-tour rhythmbox"
PACKAGES_FLATPAK="com.mattjakeman.ExtensionManager com.github.tchx84.Flatseal ca.desrt.dconf-editor net.nokyan.Resources com.bitwarden.desktop org.keepassxc.KeePassXC org.bleachbit.BleachBit uk.org.greenend.chiark.sgtatham.putty io.github.peazip.PeaZip io.gitlab.librewolf-community net.mullvad.MullvadBrowser com.github.micahflee.torbrowser-launcher com.discordapp.Discord dev.pulsar_edit.Pulsar com.obsproject.Studio org.qbittorrent.qBittorrent org.gimp.GIMP org.kde.krita org.kde.kdenlive org.audacityteam.Audacity org.atheme.audacious org.upscayl.Upscayl io.github.seadve.Mousai fr.romainvigier.MetadataCleaner"


# Function to check for root privileges
check_rootaccess() {
  if [ "$EUID" -ne 0 ]; then
    echo "Error: No Root privileges. Please run the script with 'sudo' (recommended!!) or as root user." >&2
    exit 1
  fi
}


# Function for initial prompt
initial_prompt() {
    echo
    echo "##############################################"
    echo "#          Post-Installation Script          #"
    echo "#                By FinalKirb                #"
    echo "##############################################"
    echo
    echo "IMPORTANT: This script comes with NO WARRANTY. It is intended to be used ONCE on a fresh FEDORA LINUX system. By running this script, you acknowledge that you have read and understood the risks involved. The script will perform system updates and software installations. Please be aware that the script may modify system configurations, and that there is a possibility of data loss or system breakage."
    echo
    read -p "Continue at your own risk. Do you wish to proceed? (y/n): " confirm
    if [ "$confirm" != "y" ]; then # Press "y" to run the script
      echo "Script aborted."
      echo
      exit 1
    fi
    echo
}




##############################################
#                   System                   #
##############################################


# Function to run all 'system' functions
batch_system() {
speed_up_dnf
enable_flatpak
enable_rpmfusion
update_system
uninstall_unwanted_software
install_software_dnf
install_software_flatpak
install_codecs
update_system
system_cleanup
}


# Function to speed up DNF
speed_up_dnf() {
  echo "Speeding up DNF..."
  if grep -q 'max_parallel_downloads' /etc/dnf/dnf.conf; then
   echo "max_parallel_downloads is already set up in /etc/dnf/dnf.conf, skipping step."
   return
  else
    echo "max_parallel_downloads=10" | sudo tee -a /etc/dnf/dnf.conf
    echo "DNF has been sped up."
  fi
  echo
}


# Function to enable Flatpak
enable_flatpak() {
  if ! command -v flatpak >/dev/null 2>&1; then # 'flatpak' command not found -> install flatpak
    echo "Installing Flatpak..."
    sudo dnf -y install flatpak
    if [ $? -ne 0 ]; then # Checks if the output of the previous command is an error message
      echo "Error: Flatpak could not be installed, skipping step." >&2
      echo
      return
    fi
  fi
  sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
  sudo flatpak -y update
  echo "Flatpak has been enabled."
  echo
}


# Function to enable RPMFusion
enable_rpmfusion() {
  echo "Enabling RPMFusion..."
  RPMFUSION_FREE_URL="https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm"
  RPMFUSION_NONFREE_URL="https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"

  sudo dnf -y install $RPMFUSION_FREE_URL $RPMFUSION_NONFREE_URL
  if [ $? -ne 0 ]; then
    echo "Error: RPMFusion could not be installed, skipping step." >&2
    echo
    return
  fi
  echo "RPMFusion has been enabled."
  echo
}


# Adding DNF Repositories
#install_repositories() {
# sudo dnf config-manager --add-repo https://rpm.librewolf.net/librewolf-repo.repo
# echo "DNF Repositories have been installed."
# echo
#}


# Function to update the system
update_system() {
  update_dnf
  update_flatpak
  update_firmware
  echo "The System has been updated."
  echo
}


# Function to update the dnf packages
update_dnf() {
  echo "Updating DNF Packages..."
  sudo dnf clean all
  sudo dnf -y update --refresh
  if [ $? -ne 0 ]; then # Checks if the output of the previous command is an error message
    echo "Error: DNF Packages could not be updated, skipping step." >&2
    echo
    return
  else
    echo "DNF Packages have been updated."
    echo
  fi
}


# Function to update the flatpak packages
update_flatpak() {
  echo "Updating Flatpak Packages..."
  if ! command -v flatpak >/dev/null 2>&1; then
    echo "Error: 'flatpak' command not found, skipping step." >&2
    echo
    return
  fi
  sudo flatpak -y update
  if [ $? -ne 0 ]; then # Checks if the output of the previous command is an error message
    echo "Error: Flatpak Packages could not be updated, skipping step." >&2
    echo
    return
  fi

    echo "Flatpak Packages have been updated"
    echo
}


# Function to update the firmware
update_firmware() {
  echo "Updating the Firmware..."

  if ! command -v fwupdmgr >/dev/null 2>&1; then # Check if 'fwupdmgr' command is not available
    echo "Error: 'fwupdmgr' command not found, skipping step." >&2
    echo
    return
  fi

  sudo fwupdmgr get-devices
  sudo fwupdmgr refresh --force
  sudo fwupdmgr get-updates
  sudo fwupdmgr update

  if [ $? -ne 0 ]; then # Checks if the output of the previous command is an error message
    echo "Error: Firmware update failed. Check the logs for more information." >&2
    echo
    return
  fi
  echo "The Firmware has been updated."
  echo
}


# Function to remove unwanted software
uninstall_unwanted_software() {
	echo "Uninstalling unwanted software..."
	sudo dnf -y remove $PACKAGES_DNF_UNINSTALL
	echo "Unwanted software has been uninstalled."
	echo
}


# Function to install DNF packages
install_software_dnf() {
	echo "Installing DNF Packages..."
	sudo dnf -y install $PACKAGES_DNF
  if [ $? -ne 0 ]; then # Checks if the output of the previous command is an error message
    echo "Error: DNF installation failed. Check the logs for more information." >&2
    echo
    return
  fi
  echo "DNF Packages have been installed."
  echo
}


# Function to install Flatpak packages
install_software_flatpak() {
	echo "Installing Flatpak Packages..."
	sudo flatpak -y install $PACKAGES_FLATPAK
  echo "Flatpak Packages have been installed."
  echo
}


# Function to install multimedia codecs
install_codecs() {
  echo "Installing Non-Free Multimedia Codecs"
  sudo dnf -y swap ffmpeg-free ffmpeg --allowerasing
  echo "Non-Free Multimedia Codecs have been installed."
  echo
}


# Function to clean up system dependencies
system_cleanup() {
  echo "Cleaning up the system... (You will be prompted to confirm the changes)"
  sudo dnf autoremove
  echo "Dependencies have been cleaned up."
  echo
}




##############################################
#              Personalization               #
##############################################


# Function to run all 'personalization' functions.
batch_personalize() {
  setup_mouse
  setup_keyboard
  setup_fonts
  setup_desktop
  enable_nightlight
  setup_nautilus
  setup_texteditor
}


# Function to enable dark mode
enable_darkmode() {
  echo "Enabling dark mode..."
  gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
  gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'
  echo "Dark mode has been enabled."
  echo
}


# Function to enable night light
enable_nightlight() {
  echo "Enabling night light..."
  gsettings set org.gnome.settings-daemon.plugins.color night-light-enabled 'true'
  gsettings set org.gnome.settings-daemon.plugins.color night-light-schedule-automatic 'false'
  gsettings set org.gnome.settings-daemon.plugins.color night-light-schedule-from '22'
  gsettings set org.gnome.settings-daemon.plugins.color night-light-schedule-to '9'
  gsettings set org.gnome.settings-daemon.plugins.color night-light-temperature '4000'
  echo "Night light has been enabled."
  echo
}

# Function to set up the mouse/touchpad
setup_mouse() {
  echo "Setting up mouse settings..."
  gsettings set org.gnome.desktop.peripherals.mouse accel-profile 'flat' # Disables mouse acceleration
  gsettings set org.gnome.desktop.peripherals.mouse speed '0.55'

  echo "Setting up touchpad settings..."
  gsettings set org.gnome.desktop.peripherals.touchpad disable-while-typing 'false'
  gsettings set org.gnome.desktop.peripherals.touchpad tap-to-click 'true'
  gsettings set org.gnome.desktop.peripherals.touchpad two-finger-scrolling-enabled 'true'

  echo "Mouse and Touchpad settings have been set up."
  echo
}


# Function to set up keyboard shortcuts and preferences
setup_keyboard() {
  echo "Setting up keyboard shortcuts..."
  gsettings set org.gnome.desktop.wm.keybindings activate-window-menu '[]'
  gsettings set org.gnome.desktop.wm.keybindings minimize '[]'
  gsettings set org.gnome.desktop.wm.keybindings switch-input-source '[]'
  gsettings set org.gnome.desktop.wm.keybindings switch-input-source-backward '[]'
  gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-left "['<Control><Super>Left']"
  gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-right "['<Control><Super>Right']"
  gsettings set org.gnome.settings-daemon.plugins.media-keys control-center '['<Super>i']' # Super + i -> Opens gnome settings
  gsettings set org.gnome.settings-daemon.plugins.media-keys www '['<Super>b']' # Super + b -> Opens default browser

  # Custom keybinds
  gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ name 'Gnome Terminal'
  gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ command 'gnome-terminal'
  gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ binding '<Super>t'

  gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/ name 'Nautilus File Manager'
  gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/ command 'nautilus'
  gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/ binding '<Super>e'

  gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/ name 'Discord'
  gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/ command 'flatpak run com.discordapp.Discord'
  gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/ binding '<Super>d'

  gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings '['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/']'

  echo "Keyboard shortcuts have been set up."
  echo
  echo "Setting up keyboard preferences..."
  gsettings set org.gnome.desktop.wm.preferences action-double-click-titlebar 'toggle-maximize'
  gsettings set org.gnome.desktop.wm.preferences action-middle-click-titlebar 'none'
  gsettings set org.gnome.desktop.wm.preferences button-layout 'appmenu:minimize,maximize,close'
  echo "Keyboard preferences have been set up."
  echo
}


# Function to set up fonts
setup_fonts() {
  echo "Setting up fonts..."
  gsettings set org.gnome.desktop.interface font-name 'Cantarell 12'
  gsettings set org.gnome.desktop.interface document-font-name 'Cantarell 12'
  gsettings set org.gnome.desktop.interface monospace-font-name 'Source Code Pro 11'
  gsettings set org.gnome.desktop.wm.preferences titlebar-font 'Cantarell Bold 12'
  gsettings set org.gnome.desktop.interface font-antialiasing 'rgba'
  echo "Fonts have been set up."
  echo
}


# Function to set up desktop settings
setup_desktop() {
  echo "Setting up the desktop..."
  gsettings set org.gnome.desktop.interface enable-hot-corners 'false'
  gsettings set org.gnome.desktop.interface clock-show-seconds 'true'
  gsettings set org.gnome.desktop.interface clock-show-weekday 'true'
  gsettings set org.gnome.desktop.calendar show-weekdate 'true'
  gsettings set org.gnome.mutter attach-modal-dialogs 'false'
  gsettings set org.gnome.desktop.interface show-battery-percentage 'true'
  gsettings set org.gnome.system.locale 'de_CH.UTF-8'
  echo "The desktop has been set up."
  echo
}


# Function to set up nautilus settings
setup_nautilus() {
  echo "Setting up nautilus..."
  gsettings set org.gnome.nautilus.list-view default-column-order ['name', 'type', 'size', 'owner', 'group', 'permissions', 'mime_type', 'where', 'date_modified', 'date_modified_with_time', 'date_accessed', 'date_created', 'recency', 'starred']
  gsettings set org.gnome.nautilus.list-view default-visible-columns ['name', 'type', 'size', 'date_modified']
  gsettings set org.gnome.nautilus.preferences default-folder-viewer 'list-view'
  gsettings set org.gnome.nautilus.preferences default-sort-order 'type'
  gsettings set org.gnome.nautilus.preferences show-create-link 'true'
  gsettings set org.gnome.nautilus.preferences show-delete-permanently 'true'
  gsettings set org.gnome.nautilus.preferences show-hidden-files 'true'
  gsettings set org.gnome.nautilus.preferences thumbnail-limit '100'

  # File Chooser
  gsettings set org.gtk.gtk4.Settings.FileChooser sort-column 'type'
  gsettings set org.gtk.gtk4.Settings.FileChooser sort-directories-first 'true'
  gsettings set org.gtk.gtk4.Settings.FileChooser show-hidden 'true'
  echo "Nautilus has been set up."
  echo
}


# Function to set up the text editor
setup_texteditor() {
  echo "Setting up the text editor..."
  gsettings set org.gnome.TextEditor highlight-current-line 'true'
  gsettings set org.gnome.TextEditor show-line-numbers 'true'
  gsettings set org.gnome.TextEditor spellcheck 'false'
  echo "Text Editor has been set up."
  echo
}


# Function to set up aliases in .bashrc
setup_aliases() {
  echo "Setting up .bashrc aliases"

  if [ ! -f  "$HOME/.bashrc" ]; then # Checks if the $HOME/.bashrc file exists. If it doesn't, then it'll create the file.
    touch $HOME/.bashrc
  fi

  cat <<EOL >> "$HOME/.bashrc" # Creates a temporary 'here document' (<<EOL (content) EOL) which passes a block of text to a command, in this case cat, which delegates/writes the 'here document' with the aliases to .bashrc

# Custom Aliases
alias shutdown='sudo shutdown'
alias reboot='sudo reboot'

alias cd..='cd ..'
alias ..='cd ..'
alias ...='cd ../..'

alias vi='vim'
alias clr='clear'

alias rm='rm -iv'
alias mv='mv -i'
alias cp='cp -iv'
alias ln='ln -i'
alias mkdir='mkdir -pv'

alias count='find . -type f | wc -l'
alias ports='netstat -tulpn'

EOL

echo ".bashrc aliases have been set up."
echo
}




##############################################
#             Privacy / Security             #
##############################################


# Function to run all 'security' functions
batch_security() {
  reduce_inactivity_time
  enable_remove_old_temp_files
  disable_recent_files
  disable_show_password
  disable_lockscreen_notifications
  install_fail2ban
}


# Function to reduce inactivity time
reduce_inactivity_time() {
  echo "Reducing inactivity time..."
  gsettings set org.gnome.desktop.session idle-delay '60'
  echo "Inactivity time has been reduced to 1 minute."
  echo
}


# Function to periodically remove old temp files
enable_remove_old_temp_files() {
  echo "Enabling automatic removal of old temp-files..."
  gsettings set org.gnome.desktop.privacy remove-old-temp-files 'true'
  echo "Automatic removal of old temp-files has been enabled."
}


# Function to disable recent files
disable_recent_files() {
  echo "Disabling recent files..."
  gsettings set org.gnome.desktop.privacy remember-recent-files 'false'
  echo "'Recent files' has been disabled."
  echo
}


# Function to disable the 'show password' button
disable_show_password() {
  echo "Disabling the 'Show Password' button on login..."
  gsettings set org.gnome.desktop.lockdown disable-show-password 'true'
  echo "The 'Show Password' button has been disabled."
  echo
}


# Function to disable notifications in the lock screen
disable_lockscreen_notifications() {
  echo "Disabling notifications in the lock screen..."
  gsettings set org.gnome.desktop.notifications show-in-lock-screen 'false'
  echo "Notifications in the lock screens have been disabled."
  echo
}


# Function to install & configure fail2ban
install_fail2ban() {
	echo "Installing and configuring Fail2Ban..."
	sudo dnf -y install fail2ban
	sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local

	echo "
	[sshd]
	enabled = true
	port = ssh
	filter = sshd
	logpath = /var/log/auth.log
	maxretry = 3
	bantime = 3600
	" >> /etc/fail2ban/jail.local

	sudo systemctl start fail2ban
	sudo systemctl enable fail2ban

	echo "Fail2Ban has been installed and configured."
	echo
}




##############################################
#             Running the script             #
##############################################

# Execute initial prompt
check_rootaccess
initial_prompt

# Execute functions
batch_system
batch_personalize
batch_security
echo
echo "Post-Installation script completed successfully, it is advised to reboot your system now."
echo
exit
