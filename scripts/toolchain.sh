#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
set -e

# Function to clean up variables and other resources
cleanup() {
    unset MAKEFLAGS
    unset CROSSTOOL_NG_PATH
    unset CURRENT_SHELL
    unset EXPORT_PATH_BBB
    unset EXPORT_PATH_QEMU
    echo "Cleaned up environment variables."
}

# Trap the EXIT signal to call the cleanup function
trap cleanup EXIT

# change to current directory
cd "$( dirname "${BASH_SOURCE[0]}" )"

# Define the options
options=("QEMU" "BeagleBone Black" "both")
# Display the menu and prompt for a choice
echo "Please select an option to build crosstool-ng:"
select opt in "${options[@]}"; do
    if [[ -n "$opt" ]]; then
        break
    else
        echo "Invalid option. Please try again."
    fi
done

# Determine the distribution and install pre-requisites
if [ -f /etc/os-release ]; then
  . /etc/os-release
  case "$ID" in
    debian|ubuntu)
      # Update and upgrade the system
      sudo apt update && sudo apt -y upgrade
      # Install pre-requisites
      sudo apt install -y autoconf automake bison bzip2 cmake flex g++ gawk gcc gettext \
          git gperf help2man libncurses5-dev libstdc++6 libtool libtool-bin make \
          patch python3-dev rsync texinfo unzip wget xz-utils
      ;;
    arch|manjaro)
      # Update and upgrade the system
      sudo pacman -Syu --noconfirm
      # Install pre-requisites
      sudo pacman -S --noconfirm base-devel git help2man python unzip wget audit rsync
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

# Set the number of parallel jobs for make
export MAKEFLAGS="-j$(nproc)"

# Clone and install crosstool-ng
CROSSTOOL_NG_PATH=../ctng
# Determine the current shell
CURRENT_SHELL=$(echo $SHELL)

# Path to be exported
EXPORT_PATH_BBB="export PATH=~/x-tools/arm-cortex_a8-linux-gnueabihf/bin:\$PATH"
EXPORT_PATH_QEMU="export PATH=~/x-tools/arm-unknown-linux-gnueabi/bin:\$PATH"

# Check if the crosstool-ng directory exists and remove it if it does
if [ -d "$CROSSTOOL_NG_PATH" ]; then
    echo "Removing existing crosstool-ng directory..."
    sudo rm -rf $CROSSTOOL_NG_PATH
fi
git clone https://github.com/crosstool-ng/crosstool-ng.git $CROSSTOOL_NG_PATH
cd $CROSSTOOL_NG_PATH
# Note this is a different version than the one used in the book 1.24
# Some of the tools used in 1.24 cannot be compiled with a gcc version > 10
# Also, some links are outdated
# Although the issue can be easily solved by correcting the links and installing 
# a gcc version <= 10, it's better to use the latest crosstool-ng to make things easy
git checkout crosstool-ng-1.26.0
git apply ../patches/ctng/gdb.patch
./bootstrap
# Prefix is used to tell the make to install the tools in the current working 
# directory, not in the default system locations
./configure --prefix=${PWD}
make
sudo make install

# Function to build crosstool-ng for QEMU
build_qemu() {
    echo "Building crosstool-ng for QEMU..."
    # Clean artifacts generated by any previous build if any
    $CROSSTOOL_NG_PATH/bin/ct-ng distclean
    # copy pre-configured config file with menuconfig
    cp ../configs/ctng/config_qemu $CROSSTOOL_NG_PATH/.config
    # Build the toolchain
    $CROSSTOOL_NG_PATH/bin/ct-ng build
    # Add the toolchain to the system PATH
    if [[ $CURRENT_SHELL == *"zsh"* ]]; then
        echo $EXPORT_PATH_QEMU >> ~/.zshrc
        echo "Path exported to .zshrc"
        echo -e "$(tput bold)\!\!\!\!\!\!\!\! source .zshrc or restart the terminal \!\!\!\!\!\!\!\!$(tput sgr0)"
    elif [[ $CURRENT_SHELL == *"bash"* ]]; then
        echo $EXPORT_PATH_QEMU >> ~/.bashrc
        source ~/.bashrc
        echo "Path exported to .bashrc"
    else
        echo "Unsupported shell: $CURRENT_SHELL"
    fi
}

# Function to build crosstool-ng for BeagleBone Black
build_beaglebone() {
    echo "Building crosstool-ng for BeagleBone Black..."
    $CROSSTOOL_NG_PATH/bin/ct-ng distclean
    cp ../configs/ctng/config_bbb $CROSSTOOL_NG_PATH/.config
    $CROSSTOOL_NG_PATH/bin/ct-ng build
    if [[ $CURRENT_SHELL == *"zsh"* ]]; then
        echo $EXPORT_PATH_BBB >> ~/.zshrc
        source ~/.zshrc
        echo "Path exported to .zshrc"
    elif [[ $CURRENT_SHELL == *"bash"* ]]; then
        echo $EXPORT_PATH_BBB >> ~/.bashrc
        source ~/.bashrc
        echo "Path exported to .bashrc"
    else
        echo "Unsupported shell: $CURRENT_SHELL"
    fi
}

# Function to build crosstool-ng for both
build_both() {
    echo "Building crosstool-ng for both QEMU and BeagleBone Black..."
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

