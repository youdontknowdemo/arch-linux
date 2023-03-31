#!/usr/bin/bash

################################################
##### MangoHud
################################################
sudo -u ${NEW_USER} paru -S --noconfirm goverlay-bin
# References:
# None yet

################################################
##### Steam
################################################

pacman -S --noconfirm steam
# References:
# None yet

# Steam controllers udev rules
curl -sSL https://raw.githubusercontent.com/ValveSoftware/steam-devices/master/60-steam-input.rules -o /etc/udev/rules.d/60-steam-input.rules
udevadm control --reload-rules

################################################
##### Other game launchers
################################################

# Heroic Games Launcher
flatpak install -y flathub com.heroicgameslauncher.hgl

# Lutris
flatpak install -y flathub net.lutris.Lutris

################################################
##### Roblox launcher
################################################

git clone --depth=1 https://aur.archlinux.org/grapejuice-git.git /grapejuice-git
chown -R ${NEW_USER}:${NEW_USER} grapejuice-git
cd grapejuice-git
sudo -u ${NEW_USER} makepkg -si --noconfirm
cd ..
rm -rf grapejuice-git
