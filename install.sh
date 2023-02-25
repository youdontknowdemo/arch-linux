#!/bin/bash

################################################
##### Set variables
################################################

read -p "LUKS password: " LUKS_PASSWORD
export LUKS_PASSWORD

read -p "Username: " NEW_USER
export NEW_USER

read -p "User password: " NEW_USER_PASSWORD
export NEW_USER_PASSWORD

read -p "Hostname: " NEW_HOSTNAME
export NEW_HOSTNAME

read -p "Timezone (timedatectl list-timezones): " TIMEZONE
export TIMEZONE

read -p "Gaming (yes / no): " GAMING
export GAMING

# CPU vendor
if cat /proc/cpuinfo | grep "vendor" | grep "GenuineIntel" > /dev/null; then
    export CPU_MICROCODE="intel-ucode"
elif cat /proc/cpuinfo | grep "vendor" | grep "AuthenticAMD" > /dev/null; then
    export CPU_MICROCODE="amd-ucode"
fi

# GPU vendor
if lspci | grep "VGA" | grep "Intel" > /dev/null; then
    export GPU_PACKAGES="vulkan-intel intel-media-driver intel-gpu-tools"
    export MKINITCPIO_MODULES=" i915"
    export LIBVA_ENV_VAR="LIBVA_DRIVER_NAME=iHD"
elif lspci | grep "VGA" | grep "AMD" > /dev/null; then
    export GPU_PACKAGES="vulkan-radeon libva-mesa-driver radeontop"
    export MKINITCPIO_MODULES=" amdgpu"
    export LIBVA_ENV_VAR="LIBVA_DRIVER_NAME=radeonsi"
fi

################################################
##### Partitioning
################################################

# References:
# https://www.rodsbooks.com/gdisk/sgdisk-walkthrough.html
# https://www.dwarmstrong.org/archlinux-install/

# Delete old partition layout and re-read partition table
wipefs -af /dev/nvme0n1
sgdisk --zap-all --clear /dev/nvme0n1
partprobe /dev/nvme0n1

# Partition disk and re-read partition table
sgdisk -n 1:0:+1G -t 1:ef00 -c 1:boot /dev/nvme0n1
sgdisk -n 2:0:0 -t 2:8309 -c 2:luks /dev/nvme0n1
partprobe /dev/nvme0n1

################################################
##### LUKS / BTRFS
################################################

# Encrypt and open LUKS partition
echo ${LUKS_PASSWORD} | cryptsetup --type luks2 --hash sha512 --use-random --label=luks luksFormat /dev/nvme0n1p2
echo ${LUKS_PASSWORD} | cryptsetup luksOpen /dev/nvme0n1p2 cryptdev

# Create BTRFS
mkfs.btrfs -L cryptdev /dev/mapper/cryptdev

# Mount root device
mount /dev/mapper/cryptdev /mnt

# Create BTRFS subvolumes
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
unmount /mnt

# Mount BTRFS subvolumes
mount -o subvol=@,compress=zstd,noatime,discard,space_cache=v2,ssd /dev/mapper/cryptdev /mnt
mount -o subvol=@home,compress=zstd,noatime,discard,space_cache=v2,ssd /dev/mapper/cryptdev /mnt/home

################################################
##### EFI / Boot
################################################

# Format and mount EFI/boot partition
mkfs.fat -F32 -n boot /dev/nvme0n1p1
mount --mkdir /dev/nvme0n1p1 /mnt/boot

################################################
##### Install system
################################################

# Import mirrorlist
cp ./extra/mirrorlist /etc/pacman.d/mirrorlist

# Synchronize package databases
pacman -Syy

# Install system
pacstrap /mnt base base-devel linux linux-lts linux-firmware btrfs-progs ${CPU_MICROCODE}

# Generate filesystem tab
genfstab -U /mnt >> /mnt/etc/fstab

# Configure system
cp ./setup.sh /mnt/setup.sh
arch-chroot /mnt /bin/bash /setup.sh
umount -R /mnt