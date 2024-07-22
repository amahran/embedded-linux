# Embedded Linux

Resources for Embedded Linux study group following the book Mastering Embedded Linux Programming, 3rd edition

## Content

- scripts: scripts to automate the build process of different parts of the embedded linux system
- configs: pre-built configuration files produced with defconfig and menuconfig
- patches: git patches to fix issues in the used tools

## Scripts

The scripts require user intervention to select the flavor of the build (e.g. build of QEMU or beaglebone black).

### Prerequisites

- Debian based distro or Arch Linux

### Usage
To run the scripts:
```bash
./<script name>
```

## configs

The configurations for crosstool-ng has been produced according to the instructions in the book and stored
to reduce user intervention.

## patches

crosstool-ng has a bug in the configuration file for gdb native, the patch is to fix this issue

the issue is in crosstool-ng v1.26, where building gdb native uses the shared libraraies from the host machine
instead of the ones from `SYSROOT`. This doesn't happen on Ubuntu/Debian since the host shared libraries are
installed under /usr/lib/x86_64-linux-gnu while it happend on Archlinux because libs are under
/usr/lib. The problem happens with two libs, expat and gmp.

## TODO

- [ ] Add support to Raspberry Pi
- [ ] Add config files for the kernel to avoid user intervention for the newly added options

