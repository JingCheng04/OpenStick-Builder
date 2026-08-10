#!/bin/bash
set -e

# ============ 配置变量（按需修改） ============
WIFI_SSID="Openstick"            # 热点名称
WIFI_PASS="password"             # 热点密码
AP_IP="192.168.4.1"              # 网关
AP_NET="192.168.4.0/24"          # 热点网段
DHCP_START="192.168.4.10"        # DHCP 分配起始
DHCP_END="192.168.4.100"         # DHCP 分配结束
DHCP_MASK="255.255.255.0"        # 子网掩码
DNS_SERVERS="8.8.8.8,223.5.5.5"  # DNS
WAN_IF="wwan0"                   # 蜂窝移动网络上行接口
# =============================================

# --- NM 放手 wlan0 ---
cat > /etc/NetworkManager/conf.d/unmanage-wlan0.conf <<EOF
[keyfile]
unmanaged-devices=interface-name:wlan0
EOF
systemctl reload NetworkManager
sleep 2

# --- hostapd 配置（无 country_code，避免 wcn36xx 卡在 COUNTRY_UPDATE） ---
cat > /etc/hostapd/hostapd.conf <<EOF
interface=wlan0
driver=nl80211
ssid=${WIFI_SSID}
hw_mode=g
channel=1
ieee80211n=1
wmm_enabled=1
auth_algs=1
wpa=2
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
wpa_passphrase=${WIFI_PASS}
EOF
chmod 600 /etc/hostapd/hostapd.conf
sed -i 's|#DAEMON_CONF=.*|DAEMON_CONF="/etc/hostapd/hostapd.conf"|' /etc/default/hostapd
systemctl unmask hostapd

# --- hostapd override：前台模式(Type=simple, 无 -B) + 依赖 wlan0-ip + 失败自愈 ---
mkdir -p /etc/systemd/system/hostapd.service.d
cat > /etc/systemd/system/hostapd.service.d/override.conf <<EOF
[Unit]
After=wlan0-ip.service
Requires=wlan0-ip.service

[Service]
Type=simple
PIDFile=
Restart=on-failure
RestartSec=3
ExecStart=
ExecStart=/usr/sbin/hostapd /etc/hostapd/hostapd.conf
EOF

# --- wlan0 静态 IP（等接口就绪，避免开机时序竞争） ---
cat > /etc/systemd/system/wlan0-ip.service <<EOF
[Unit]
Description=Static IP for wlan0 AP
After=sys-subsystem-net-devices-wlan0.device
Wants=sys-subsystem-net-devices-wlan0.device
Before=hostapd.service

[Service]
Type=oneshot
ExecStartPre=/bin/sh -c 'for i in \$(seq 1 30); do ip link show wlan0 >/dev/null 2>&1 && exit 0; sleep 1; done; exit 1'
ExecStart=/usr/sbin/ip addr flush dev wlan0
ExecStart=/usr/sbin/ip addr add ${AP_IP}/24 dev wlan0
ExecStart=/usr/sbin/ip link set wlan0 up
ExecStop=/usr/sbin/ip addr flush dev wlan0
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# --- dnsmasq 发 DHCP（只在 wlan0，port=0 只做 DHCP 不做 DNS，避免与 NM 冲突） ---
cat > /etc/dnsmasq.d/wlan0-ap.conf <<EOF
interface=wlan0
bind-dynamic
port=0
dhcp-range=${DHCP_START},${DHCP_END},${DHCP_MASK},12h
dhcp-option=3,${AP_IP}
dhcp-option=6,${DNS_SERVERS}
EOF

# --- NAT: wlan0 -> WAN ---
cat > /etc/systemd/system/wlan0-nat.service <<EOF
[Unit]
Description=NAT for wlan0 AP to ${WAN_IF}
After=network.target hostapd.service
Wants=hostapd.service

[Service]
Type=oneshot
ExecStart=/usr/sbin/nft add table ip nat
ExecStart=/usr/sbin/nft add chain ip nat postrouting { type nat hook postrouting priority 100 \; }
ExecStart=/usr/sbin/nft add rule ip nat postrouting ip saddr ${AP_NET} oifname "${WAN_IF}" masquerade
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# --- IP 转发持久化 ---
echo 'net.ipv4.ip_forward=1' > /etc/sysctl.d/99-forward.conf
sysctl -w net.ipv4.ip_forward=1

# --- 启用并启动 ---
systemctl daemon-reload
systemctl enable wlan0-ip hostapd dnsmasq wlan0-nat
systemctl restart wlan0-ip hostapd dnsmasq wlan0-nat

echo "=== 完成，状态： ==="
systemctl is-active wlan0-ip hostapd dnsmasq wlan0-nat
sleep 2
iw dev wlan0 info | grep -E 'ssid|type'
ip addr show wlan0 | grep inet
