#!/bin/bash
# Advanced Bluetooth fix for Apple BCM devices with USB communication issues

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=========================================="
echo "Advanced Bluetooth USB Reset Tool"
echo "=========================================="
echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}Please run without sudo. The script will ask for sudo when needed.${NC}"
    exit 1
fi

echo -e "${YELLOW}Step 1: Disable USB autosuspend for Bluetooth device${NC}"
echo "-------------------"
# Find the USB device path
USB_DEVICE=$(find /sys/bus/usb/devices/ -name "*" | grep -E "/[0-9]+-[0-9]+$" -type l 2>/dev/null | head -1)
if [ -n "$USB_DEVICE" ]; then
    echo "Found Bluetooth USB device at: $USB_DEVICE"
    sudo sh -c "echo on > $USB_DEVICE/power/control"
    echo "USB autosuspend disabled"
    cat $USB_DEVICE/power/control
else
    echo -e "${YELLOW}Could not find USB device 1-8, continuing anyway...${NC}"
fi
echo ""

echo -e "${YELLOW}Step 2: Trying different firmware combinations${NC}"
echo "-------------------"
# Try multiple firmware file combinations
if [ -f "/tmp/broadcom-bt-firmware/brcm/BCM20702A1-0a5c-21e8.hcd" ]; then
    echo "Trying BCM20702A1 firmware..."
    sudo cp /tmp/broadcom-bt-firmware/brcm/BCM20702A1-0a5c-21e8.hcd /lib/firmware/brcm/BCM-05ac-8290.hcd
    sudo cp /tmp/broadcom-bt-firmware/brcm/BCM20702A1-0a5c-21e8.hcd /lib/firmware/brcm/BCM-0a5c-8290.hcd
    sudo cp /tmp/broadcom-bt-firmware/brcm/BCM20702A1-0a5c-21e8.hcd /lib/firmware/brcm/BCM20702A1-05ac-8290.hcd
    echo "Firmware files updated"
fi
echo ""

echo -e "${YELLOW}Step 3: Complete Bluetooth module reset${NC}"
echo "-------------------"
# Remove all Bluetooth modules
sudo modprobe -r bnep || true
sudo modprobe -r btusb || true
sudo modprobe -r btrtl || true
sudo modprobe -r btbcm || true
sudo modprobe -r btintel || true
sudo modprobe -r bluetooth || true
sleep 2

# Reload in correct order
echo "Reloading Bluetooth modules..."
sudo modprobe bluetooth
sudo modprobe btbcm
sudo modprobe btusb
sleep 3
echo "Modules reloaded"
echo ""

echo -e "${YELLOW}Step 4: Check kernel messages${NC}"
echo "-------------------"
dmesg | grep -i "bluetooth\|BCM\|hci0" | tail -15
echo ""

echo -e "${YELLOW}Step 5: Try to bring up Bluetooth${NC}"
echo "-------------------"
sleep 2
sudo hciconfig hci0 up 2>&1 || echo "Failed to bring up hci0"
sleep 1
echo ""

echo -e "${YELLOW}Step 6: Final status${NC}"
echo "-------------------"
hciconfig -a
echo ""

echo "=========================================="
if hciconfig hci0 2>/dev/null | grep -q "UP"; then
    echo -e "${GREEN}SUCCESS: Bluetooth is UP!${NC}"
else
    echo -e "${RED}FAILED: Bluetooth is still DOWN${NC}"
    echo ""
    echo "This device may require:"
    echo "1. A system reboot to reset the USB controller"
    echo "2. Different firmware (try extracting from macOS)"
    echo "3. A kernel parameter: btusb.enable_autosuspend=0"
    echo ""
    echo "To permanently disable USB autosuspend for Bluetooth:"
    echo "Add this to /etc/udev/rules.d/50-bluetooth.rules:"
    echo 'ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="05ac", ATTRS{idProduct}=="8290", ATTR{power/control}="on"'
fi
echo "=========================================="
