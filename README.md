# OpenStick Image Builder
Image builder for MSM8916 based 4G modem dongles

This builder uses the precompiled [kernel](https://pkgs.postmarketos.org/package/v24.06/postmarketos/aarch64/linux-postmarketos-qcom-msm8916) provided by [postmarketOS](https://postmarketos.org/) for Qualcomm MSM8916 devices.

> [!NOTE]
> This branch generates a `debian` image, use the [alpine branch](https://github.com/kinsamanka/OpenStick-Builder/tree/alpine) for an `alpine` image.
> <br>
> 默认编译Debian Trixie (在`scripts/debootstrap.sh` RELEASE=${RELEASE=trixie}处指定版本，若改系统版本，部分软件包版本也要对应更改)
> 默认使用国内镜像构建，多线程编译。Docker 国内镜像请自行配置。

## Build Instructions
### Build locally
<del>This has been tested to work on **Ubuntu 22.04**</del>
<br>
**建议使用Ubuntu 24.04 Docker 容器(Tested)**(运行 `run_docker.sh`)
- clone
  ```shell
  # 原项目：https://github.com/kinsamanka/OpenStick-Builder
  # Don't forget to install submodules
  git clone --recurse-submodules https://github.com/JingCheng04/OpenStick-Builder.git
  cd OpenStick-Builder/
  ```
#### Quick
- build
  ```shell
  cd OpenStick-Builder/
  # 如果不是Debian Based 系统，需要启动docker环境
  ./run_docker.sh
  # 如果使用docker，在docker内执行
  sudo ./build.sh
  ```
#### Detailed
- install dependencies
  ```shell
  sudo scripts/install_deps.sh
  ```
- build hyp and lk2nd

  these custom bootloader allows basic support for `extlinux.conf` file, similar to u-boot and depthcharge.
  ```shell
  sudo scripts/build_hyp_aboot.sh
  ```
- extract Qualcomm firmware

  extracts the bootloader and creates a new partition table that utilizes the full emmc space
  ```shell
  sudo scripts/extract_fw.sh
  ```
- create rootfs using debootstrap
  ```shell
  sudo scripts/debootstrap.sh
  ```

- build gadget-tools
  ```shell
  sudo scripts/build_gt.sh
  ```
- create images
  ```shell
  sudo scripts/build_images.sh
  ```

The generated firmware files will be stored under the `files` directory

### On the cloud using Github Actions
1. Fork this repo
2. Run the [Build workflow](../../actions/workflows/build.yml)
   - click and run ***Run workflow***
   - once the workflow is done, click on the workflow summary and then download the resulting artifact

## Customizations
Edit [`scripts/setup.sh`](scripts/setup.sh) to add/remove packages. Note that this script is running inside the `chroot` environment.

## Firmware Installation
> [!WARNING]  
> The following commands can potentially brick your device, making it unbootable. Proceed with caution and at your own risk!

> [!IMPORTANT]  
> Make sure to perform a backup of the original firmware using the command `edl rf orig_fw.bin`

### Prerequisites
- [EDL](https://github.com/bkerler/edl)
- Android fastboot tool
  ```
  sudo apt install fastboot
  ```

### Steps
- Enter Qualcom EDL mode using this [guide](https://wiki.postmarketos.org/wiki/Zhihe_series_LTE_dongles_(generic-zhihe)#How_to_enter_flash_mode)
- Backup required partitions

  The following files are required from the original firmware:
  
     - `fsc.bin`
     - `fsg.bin`
     - `modem.bin`
     - `modemst1.bin`
     - `modemst2.bin`
     - `persist.bin`
     - `sec.bin`

  Skip this step if these files are already present
  ```shell
  for n in fsc fsg modem modemst1 modemst2 persist sec; do
      edl r ${n} ${n}.bin
  done
  ```
- Install `aboot`
  ```shell
  edl w aboot aboot.mbn
  ```
- Reboot to fastboot
  ```shell
  edl e boot
  edl reset
  ```
**如果aboot无法引导fastboot或者报错, 请使用**`adb reboot bootloader`**进入fastboot。**
<br>
如果出厂自带的Android 默认未开启adb, 请参考：[开启adb](https://www.bilibili.com/opus/814871462043189297)
<br>
- Flash firmware
  ```shell
  fastboot flash partition gpt_both0.bin
  fastboot flash aboot aboot.mbn
  fastboot flash hyp hyp.mbn
  fastboot flash rpm rpm.mbn
  fastboot flash sbl1 sbl1.mbn
  fastboot flash tz tz.mbn
  fastboot flash boot boot.bin
  fastboot flash rootfs rootfs.bin
  ```
- Restore original partitions
  ```shell
  for n in fsc fsg modem modemst1 modemst2 persist sec; do
      fastboot flash ${n} ${n}.bin
  done
  ```
- Reboot
  ```shell
  fastboot reboot
  ```

## Post-Install
- Network configuration
  
  | wlan0 | |
  | ----- | ---- |
  | ssid | Openstick |
  | password | openstick |
  | ip addr | 192.168.4.1 |

  | usb0 | |
  | ----- | ---- |
  | ip addr | 192.168.5.1 |

- Default user
  
  | | |
  | ----- | ---- |
  | username | user |
  | password | 1 |

<br>
**如果Network Manager 无法启动Wifi Hotspot，请在Network Manager 中删除热点配置，并使用Hostapd尝试。**
<br>

```shell
# 切换到root
su
# 安装iw
apt update && apt install iw
# 使用Hostapd 配置wifi（如果Network Manager开启wifi失败时尝试）
# 下载脚本
curl -O https://raw.githubusercontent.com/JingCheng04/OpenStick-Builder/main/setup-wifi.sh
# 编辑setup-wifi.sh 中的内容（省略），然后运行
chmod +x ./setup-wifi.sh
./setup-wifi.sh
# 或者使用镜像站：https://gh-proxy.org/https://raw.githubusercontent.com/JingCheng04/OpenStick-Builder/main/setup-wifi.sh
```
<br>
注意修改setup-wifi.sh 中的内容。
<br>
在UFI103s上测试成功
<br>
<br>
**注意：UZ801 可能有无法开启Wifi, 请使用802.11b协议**
 
- If your device is not based on **UZ801**, modify `/boot/extlinux/extlinux.conf` to use the correct devicetree
  ```shell
  sed -i 's/yiming-uz801v3/<BOARD>/' /boot/extlinux/extlinux.conf
  ```

  where `<BOARD>` is
     - `thwc-uf896` for **UF896** boards
     - `thwc-ufi001c` for **UFIxxx** boards
     - `jz01-45-v33` for **JZxxx** boards
     - `fy-mf800` for **MF800** boards

- To maximize the `rootfs` partition
  ```shell
  resize2fs /dev/disk/by-partlabel/rootfs
  ```

- To update the kernel of the `debian` image
  ```shell
  wget -O - http://mirror.postmarketos.org/postmarketos/<branch>/aarch64/linux-postmarketos-qcom-msm8916-<version>.apk \
          | tar xkzf - -C / --exclude=.PKGINFO --exclude=.SIGN* 2>/dev/null
  ```

  Specify the correct `<branch>` and `<version>` values.
