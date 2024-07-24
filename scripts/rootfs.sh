#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
set -e

# Function to clean up variables and other resources
cleanup() {
    unset MAKEFLAGS
    echo "Cleaned up environment variables."
}

# Trap the EXIT signal to call the cleanup function
trap cleanup EXIT

# change to current directory
cd "$( dirname "${BASH_SOURCE[0]}" )"

# Define the options
options=("QEMU" "BeagleBone Black" "both")
# Display the menu and prompt for a choice
echo "Please select an option to build kernel:"
select opt in "${options[@]}"; do
    if [[ -n "$opt" ]]; then
        break
    else
        echo "Invalid option. Please try again."
    fi
done

# configure initialization procedure
config_init_procedure() {
    cat > "$ROOTFS_PATH/etc/inittab" << "EOF"
::sysinit:/etc/init.d/rcS
::respawn:/sbin/getty 115200 console
::respawn:/sbin/syslogd -n
EOF

    mkdir $ROOTFS_PATH/etc/init.d
    cat > "$ROOTFS_PATH/etc/init.d/rcS" << "EOF"
#!/bin/sh
# automatically mounting proc and sysfs filesystems on startup
/bin/mount -t proc proc /proc 
/bin/mount -t sysfs sysfs /sys
# populate the device nodes from the kernel
mount -t devtmpfs devtmpfs /dev
# make mdev a hot plug client
echo /sbin/mdev > /proc/sys/kernel/hotplug
# mdev to scan the /sys dir for information about current devices
mdev -s
EOF
}

# configure user accounts
config_user_accounts() {
    # configure user accounts
    cat > "$ROOTFS_PATH/etc/passwd" << "EOF"
root:x:0:0:root:/root:/bin/sh
daemon:x:1:1:daemon:/usr/sbin:/bin/false
EOF
    cat > "$ROOTFS_PATH/etc/shadow" << "EOF"
root::10933:0:99999:7:::
daemon:*:10933:0:99999:7:::
EOF
    cat > "$ROOTFS_PATH/etc/group" << "EOF"
root:x:0:
daemon:x:1:
EOF
}

# configure network
config_network() {
    mkdir -p $ROOTFS_PATH/etc/network/if{,-pre}-up.d
    cat > "$ROOTFS_PATH/etc/network/interfaces" << "EOF"
auto lo
iface lo inet loopback
auto eth0
iface eth0 inet static
    address 192.168.178.101
    netmask 255.255.255.0
    network 192.168.178.0
    gateway 192.168.178.1
EOF

    cat > "$ROOTFS_PATH/etc/nsswitch.conf" << "EOF"
passwd: files
group: files
shadow: files
hosts: files dns
networks: files
protocols: files
services: files
EOF

    cat > "$ROOTFS_PATH/etc/hosts" << "EOF"
127.0.0.1 localhost
EOF

    cp $ROOTFS_PATH/../configs/rootfs/{protocols,networks,services} $ROOTFS_PATH/etc
    cp -a $SYSROOT/lib/libnss* $ROOTFS_PATH/lib
    cp -a $SYSROOT/lib/libresolv* $ROOTFS_PATH/lib
}

# Set the number of parallel jobs for make
export MAKEFLAGS="-j$(nproc)"
export ARCH=arm

ROOTFS_PATH=../rootfs
BUSYBOX_PATH=../busybox

# Check if the rootfs directory exists and remove it if it does
if [ -d "$ROOTFS_PATH" ]; then
    echo "Removing existing rootfs directory..."
    sudo rm -rf $ROOTFS_PATH
fi

# Create the directory structure
mkdir -p $ROOTFS_PATH/{bin,dev,etc,home,lib,proc,root,sbin,sys,tmp,usr/{bin,lib,sbin},var}

# populate with busybox basic utils
if [ ! -d "$BUSYBOX_PATH" ]; then
    git clone git://busybox.net/busybox.git $BUSYBOX_PATH
    cd $BUSYBOX_PATH
    git checkout 1_36_stable
else
    cd $BUSYBOX_PATH
fi

make distclean
make defconfig

# Function to build kernel for QEMU
build_qemu() {
    echo "Building busybox for QEMU..."
}

# Function to build kernel for BeagleBone Black
build_beaglebone() {
    echo "Building busybox for BeagleBone Black..."
    SYSROOT=$(arm-cortex_a8-linux-gnueabihf-gcc -print-sysroot)
    # compile busybox source code
    make CROSS_COMPILE=arm-cortex_a8-linux-gnueabihf-
    # install in the rootfs dir
    make ARCH=arm CROSS_COMPILE=arm-cortex_a8-linux-gnueabihf- CONFIG_PREFIX=$ROOTFS_PATH install
    # find out deps and copy them to lib
    arm-cortex_a8-linux-gnueabihf-ldd --root $SYSROOT/lib $ROOTFS_PATH/bin/busybox | grep "=> /" | awk '{print $3}' | while read -r lib; do
        cp -a "$SYSROOT/$lib" "$ROOTFS_PATH/lib"
    done

    config_init_procedure
    config_user_accounts
    config_network
}

# Function to build kernel for both
build_both() {
    echo "Building busybox for both QEMU and BeagleBone Black..."
    build_qemu
    build_beaglebone
}

# REPLY is written the nummeric selection by the command 'select'
case $REPLY in
    1)
        build_qemu
        ;;
    2)
        build_beaglebone
        ;;
    3)
        build_both
        ;;
esac

# Create initramfs
if [ -f /etc/os-release ]; then
  . /etc/os-release
  case "$ID" in
    debian|ubuntu)
      sudo apt install -y uboot-tools
      ;;
    arch|manjaro)
      # Update and upgrade the system
      sudo pacman -Syu --noconfirm
      # Install pre-requisites
      sudo pacman -S --noconfirm uboot-tools
      ;;
    *)
      echo "Unsupported distribution: $ID"
      exit 1
      ;;
  esac
else
  echo "/etc/os-release not found. Unable to determine the distribution."
  exit 1
fi

find $ROOTFS_PATH | cpio -H newc -ov --owner root:root > ../initramfs.cpio
gzip ../initramfs.cpio
mkimage -A arm -O linux -T ramdisk -d ../initramfs.cpio.gz ../uRamdisk
rm ../initramfs.cpio.gz

# Create ext2 image
if [ -f /etc/os-release ]; then
  . /etc/os-release
  case "$ID" in
    debian|ubuntu)
      sudo apt install -y genext2fs
      ;;
    arch|manjaro)
      # Install pre-requisites
      yay -S --noconfirm genext2fs
      ;;
    *)
      echo "Unsupported distribution: $ID"
      exit 1
      ;;
  esac
else
  echo "/etc/os-release not found. Unable to determine the distribution."
  exit 1
fi

genext2fs -b 18432 -d $ROOTFS_PATH -U ../rootfs.ext2
