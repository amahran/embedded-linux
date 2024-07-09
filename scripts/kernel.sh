#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
set -e

# Function to clean up variables and other resources
cleanup() {
    unset MAKEFLAGS
    unset KERNEL_PATH
    unset KERNEL_ARCHIVE
    unset KERNEL_VERSION
    echo "Cleaned up environment variables."
}

# Trap the EXIT signal to call the cleanup function
trap cleanup EXIT

# Set the number of parallel jobs for make
export MAKEFLAGS="-j$(nproc)"

# Download the kernel source longterm version
KERNEL_PATH=../kernel-stable
KERNEL_VERSION=6.6.37
KERNEL_ARCHIVE=linux-$KERNEL_VERSION.tar.xz

# Check if the kernel directory exists and remove it if it does
if [ -d "$KERNEL_PATH" ]; then
    echo "Removing existing kernel directory..."
    sudo rm -rf $KERNEL_PATH
fi

# Create the kernel path
mkdir -p $KERNEL_PATH

# Download and extract the kernel source
wget https://cdn.kernel.org/pub/linux/kernel/v6.x/$KERNEL_ARCHIVE
tar xf $KERNEL_ARCHIVE -C $KERNEL_PATH --strip-components=1
rm $KERNEL_ARCHIVE

# Define the options
echo "Build kernel for:"
options=("QEMU" "BeagleBone Black" "both")

# Function to build kernel for QEMU
build_qemu() {
    echo "Building kernel for QEMU..."
    export KBUILD_OUTPUT=../kernel-build/qemu
    rm -rf $KBUILD_OUTPUT
    # mkdir -p $KBUILD_OUTPUT
    make -C $KERNEL_PATH ARCH=arm CROSS_COMPILE=arm-unknown-linux-gnueabi- mrproper
    make -C $KERNEL_PATH ARCH=arm versatile_defconfig
    make -C $KERNEL_PATH ARCH=arm CROSS_COMPILE=arm-unknown-linux-gnueabi- zImage
    make -C $KERNEL_PATH ARCH=arm CROSS_COMPILE=arm-unknown-linux-gnueabi- modules INSTALL_MOD_PATH=$KBUILD_OUTPUT
    make -C $KERNEL_PATH ARCH=arm CROSS_COMPILE=arm-unknown-linux-gnueabi- dtbs
    cp $KBUILD_OUTPUT/arch/arm/boot/zImage $KBUILD_OUTPUT/
    cp $KBUILD_OUTPUT/arch/arm/boot/dts/arm/versatile-pb.dtb $KBUILD_OUTPUT/
}

# Function to build kernel for BeagleBone Black
build_beaglebone() {
    echo "Building kernel for BeagleBone Black..."
    export KBUILD_OUTPUT=../kernel-build/beaglebone_black
    rm -rf $KBUILD_OUTPUT
    # mkdir -p $KBUILD_OUTPUT
    make -C $KERNEL_PATH ARCH=arm CROSS_COMPILE=arm-cortex_a8-linux-gnueabihf- mrproper
    make -C $KERNEL_PATH ARCH=arm multi_v7_defconfig
    make -C $KERNEL_PATH ARCH=arm CROSS_COMPILE=arm-cortex_a8-linux-gnueabihf- zImage
    make -C $KERNEL_PATH ARCH=arm CROSS_COMPILE=arm-cortex_a8-linux-gnueabihf- modules INSTALL_MOD_PATH=$KBUILD_OUTPUT
    make -C $KERNEL_PATH ARCH=arm CROSS_COMPILE=arm-cortex_a8-linux-gnueabihf- dtbs
    cp $KBUILD_OUTPUT/arch/arm/boot/zImage $KBUILD_OUTPUT/
    cp $KBUILD_OUTPUT/arch/arm/boot/dts/ti/omap/am335x-boneblack.dtb $KBUILD_OUTPUT/
}

# Function to build kernel for both
build_both() {
    echo "Building kernel for both QEMU and BeagleBone Black..."
    build_qemu
    build_beaglebone
}

# Display the menu and prompt for a choice
echo "Please select an option to build kernel:"
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

