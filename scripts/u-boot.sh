#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
set -e

# Function to clean up variables and other resources
cleanup() {
    unset MAKEFLAGS
    unset CROSS_COMPILE
    unset ARCH
    echo "Cleaned up environment variables."
}

# Trap the EXIT signal to call the cleanup function
trap cleanup EXIT


# Set the number of parallel jobs for make
export MAKEFLAGS="-j$(nproc)"

# Clone u-boot
UBOOT_PATH=../u-boot
# Check if the u-boot directory exists and remove it if it does
if [ -d "$UBOOT_PATH" ]; then
    echo "Removing existing U-Boot directory..."
    sudo rm -rf $UBOOT_PATH
fi
git clone git://git.denx.de/u-boot.git $UBOOT_PATH
cd $UBOOT_PATH
git checkout v2024.07

# Define the options
echo "Build u-boot for:"
options=("QEMU" "BeagleBone Black" "both")

# Function to build u-boot for QEMU
build_qemu() {
    echo "Building u-boot for QEMU..."
    unset CROSS_COMPILE
    unset ARCH
    unset KBUILD_OUTPUT 
    export CROSS_COMPILE=arm-unknown-linux-gnueabi-
    export ARCH=arm
    export KBUILD_OUTPUT=../u-boot-build/qemu
    make distclean
    make qemu_arm_defconfig
    make
    # # copy artifacts
    # mkdir -p ../u-boot-bin/qemu
    # cp u-boot{,.bin,.map,.srec} ../u-boot-bin/qemu
}

# Function to build u-boot for BeagleBone Black
build_beaglebone() {
    echo "Building u-boot for BeagleBone Black..."
    unset CROSS_COMPILE
    unset ARCH
    unset KBUILD_OUTPUT 
    export CROSS_COMPILE=arm-cortex_a8-linux-gnueabihf-
    export ARCH=arm
    export KBUILD_OUTPUT=../u-boot-build/beaglebone_black
    make distclean
    make am335x_evm_defconfig
    make
    # # copy artifacts
    # mkdir -p ../u-boot-bin/beaglebone_black
    # cp u-boot{,.bin,.map,.img,.srec} MLO ../u-boot-bin/beaglebone_black
}

# Function to build u-boot for both
build_both() {
    echo "Building u-boot for both QEMU and BeagleBone Black..."
    build_qemu
    build_beaglebone
}

# Display the menu and prompt for a choice
echo "Please select an option to build u-boot:"
select opt in "${options[@]}"; do
    case $REPLY in
        1)
            build_qemu
            break
            ;;
        2)
            build_beaglebone
            break
            ;;
        3)
            build_both
            break
            ;;
        *)
            echo "Invalid option. Please try again."
            ;;
    esac
done
