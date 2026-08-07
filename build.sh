#!/bin/sh -e

apt update && apt install ca-certificates wget

# 下载启动引导文件
# According to https://github.com/kinsamanka/OpenStick-Builder/issues/24
BOOTLOADER_URL="https://archive.org/download/dragonboard-410c-bootloader-emmc-linux-176/dragonboard-410c-bootloader-emmc-linux-176.zip"
BOOTLOADER_ZIP="dragonboard-410c-bootloader-emmc-linux-176.zip"
# 若文件已存在则跳过下载，否则下载到本目录
echo "\nDownload bootloader firmware: "
echo "${BOOTLOADER_URL}"
# 若文件已存在则跳过下载，否则下载到本目录；下载失败则提示手动下载
if [ -f "${BOOTLOADER_ZIP}" ]; then
  echo "${BOOTLOADER_ZIP} already exists, skip download"
  else
      if ! wget -O "${BOOTLOADER_ZIP}" "${BOOTLOADER_URL}"; then
          # 下载失败，删除残留的不完整文件
          rm -f "${BOOTLOADER_ZIP}"
          echo "Download failed. Please download it manually:"
          echo "  ${BOOTLOADER_URL}"
          echo "and place it as ${BOOTLOADER_ZIP} in this directory, then rerun."
          exit 1
      fi
  fi


echo "Install dependencies\n"
scripts/install_deps.sh

echo "\nBuild hyp and aboot firmware\n"
scripts/build_hyp_aboot.sh

echo "\nExtract MSM8916 firmware\n"
scripts/extract_fw.sh

echo "\nCreate rootfs\n"
scripts/debootstrap.sh

echo "\nBuild gadget-tools\n"
scripts/build_gt.sh

echo "\nCreate images\n"
scripts/build_images.sh
