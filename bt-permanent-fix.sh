#!/bin/bash
# Permanent fix for Apple BCM Bluetooth USB issues

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=========================================="
echo "Permanent Bluetooth Fix Installer"
echo "=========================================="
echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}Please run without sudo. The script will ask for sudo when needed.${NC}"
    exit 1
fi

echo -e "${YELLOW}This script will make permanent changes to:${NC}"
echo "1. Add a udev rule to disable USB autosuspend for Bluetooth"
echo "2. Add a kernel module parameter to disable autosuspend for btusb"
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled"
    exit 0
fi

echo ""
echo -e "${YELLOW}Step 1: Creating udev rule${NC}"
echo "-------------------"
UDEV_RULE='/etc/udev/rules.d/50-bluetooth-apple.rules'
sudo tee "$UDEV_RULE" > /dev/null <<'EOF'
# Disable USB autosuspend for Apple Bluetooth devices
ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="05ac", ATTRS{idProduct}=="8290", ATTR{power/control}="on"
EOF
echo "Created: $UDEV_RULE"
sudo udevadm control --reload-rules
echo "Udev rules reloaded"
echo ""

echo -e "${YELLOW}Step 2: Creating modprobe configuration${NC}"
echo "-------------------"
MODPROBE_CONF='/etc/modprobe.d/bluetooth-apple.conf'
sudo tee "$MODPROBE_CONF" > /dev/null <<'EOF'
# Disable autosuspend for btusb module to fix Apple Bluetooth
options btusb enable_autosuspend=0
EOF
echo "Created: $MODPROBE_CONF"
echo ""

echo -e "${YELLOW}Step 3: Updating initramfs${NC}"
echo "-------------------"
sudo update-initramfs -u
echo "Initramfs updated"
echo ""

echo -e "${GREEN}Permanent fixes installed!${NC}"
echo ""
echo "Next steps:"
echo "1. Reboot your system: sudo reboot"
echo "2. After reboot, check status with: ./bt-status.sh"
echo ""
echo "=========================================="
