#!/bin/sh -e

apt update
apt install -y \
    android-sdk-libsparse-utils \
    autoconf \
    automake \
    binfmt-support \
    cmake \
    debian-archive-keyring \
    debootstrap \
    device-tree-compiler \
    fdisk \
    g++-aarch64-linux-gnu \
    gcc-aarch64-linux-gnu \
    gcc-arm-none-eabi \
    libtool \
    make \
    pkg-config \
    python3-cryptography \
    python3-pyasn1-modules \
    python3-pycryptodome \
    qemu-user-static \
    unzip \
    wget \
    e2fsprogs

# 更新 debian 13 签名 keyring
wget -O /tmp/dak.deb \
    http://mirrors.bfsu.edu.cn/debian/pool/main/d/debian-archive-keyring/debian-archive-keyring_2025.1_all.deb
dpkg -i /tmp/dak.deb
rm -f /tmp/dak.deb
