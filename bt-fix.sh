#!/bin/bash
# Bluetooth fix script for Mac 2015 hardware on Linux Mint
# This script attempts to fix the BCM Bluetooth firmware issue

set -e

echo "=========================================="
echo "Bluetooth Diagnostic & Fix Tool"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Step 1: Current Bluetooth Status${NC}"
echo "-------------------"
hciconfig -a 2>/dev/null || echo "No Bluetooth devices found"
echo ""

echo -e "${YELLOW}Step 2: Checking for firmware files${NC}"
echo "-------------------"
ls -la /lib/firmware/brcm/*.hcd* 2>/dev/null || echo "No HCD firmware files found"
echo ""

echo -e "${YELLOW}Step 3: Attempting to reset Bluetooth modules${NC}"
echo "-------------------"
sudo modprobe -r btusb
sudo modprobe -r btbcm
sleep 1
sudo modprobe btbcm
sudo modprobe btusb
sleep 2
echo "Modules reloaded"
echo ""

echo -e "${YELLOW}Step 4: Checking kernel messages${NC}"
echo "-------------------"
dmesg | grep -i "bluetooth\|BCM" | tail -20
echo ""

echo -e "${YELLOW}Step 5: Attempting to bring up hci0${NC}"
echo "-------------------"
sudo hciconfig hci0 up 2>&1 || echo "Failed to bring up hci0"
echo ""

echo -e "${YELLOW}Step 6: Final status${NC}"
echo "-------------------"
hciconfig -a 2>/dev/null || echo "No Bluetooth devices found"
echo ""

echo -e "${YELLOW}Step 7: Checking if firmware is the issue${NC}"
echo "-------------------"
if dmesg | grep -q "Direct firmware load.*05ac.*8290.*failed"; then
    echo -e "${RED}Missing firmware file for device 05ac:8290${NC}"
    echo ""
    echo "The firmware file is missing. You need to:"
    echo "1. Download firmware from: https://github.com/winterheart/broadcom-bt-firmware"
    echo "2. Or extract it from macOS"
    echo ""
    echo "Quick fix option:"
    echo "Run this command to download and install the firmware:"
    echo ""
    echo "  ./bt-install-firmware.sh"
    echo ""
else
    echo -e "${GREEN}Firmware appears to be loading${NC}"
fi

echo ""
echo "=========================================="
echo "Diagnostic complete"
echo "=========================================="
