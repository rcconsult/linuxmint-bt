#!/bin/bash
# Install Broadcom Bluetooth firmware for Apple devices
# This downloads firmware from the community repository

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=========================================="
echo "Broadcom BT Firmware Installer"
echo "=========================================="
echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}Please run without sudo. The script will ask for sudo when needed.${NC}"
    exit 1
fi

# Create temp directory
TEMP_DIR=$(mktemp -d)
echo "Created temp directory: $TEMP_DIR"

# Clone the firmware repository
echo -e "${YELLOW}Downloading firmware files...${NC}"
cd "$TEMP_DIR"
git clone https://github.com/winterheart/broadcom-bt-firmware.git
cd broadcom-bt-firmware/brcm

echo ""
echo -e "${YELLOW}Available firmware files:${NC}"
ls -1 *.hcd 2>/dev/null | head -10

echo ""
echo -e "${YELLOW}Looking for firmware for device 05ac:8290...${NC}"

# The 8290 device typically needs BCM20702 firmware
# Different Mac models use different firmware
if [ -f "BCM20702A1-0a5c-21e8.hcd" ]; then
    FIRMWARE_FILE="BCM20702A1-0a5c-21e8.hcd"
    echo "Found potential firmware: $FIRMWARE_FILE"
elif [ -f "BCM20703A1-0a5c-8290.hcd" ]; then
    FIRMWARE_FILE="BCM20703A1-0a5c-8290.hcd"
    echo "Found firmware: $FIRMWARE_FILE"
else
    # Try to find any BCM firmware that might work
    FIRMWARE_FILE=$(ls -1 BCM*.hcd 2>/dev/null | head -1)
    if [ -z "$FIRMWARE_FILE" ]; then
        echo -e "${RED}No suitable firmware found${NC}"
        exit 1
    fi
    echo "Found generic firmware: $FIRMWARE_FILE"
fi

echo ""
echo -e "${YELLOW}Installing firmware...${NC}"

# Copy the firmware file with the correct name for the device
sudo cp "$FIRMWARE_FILE" /lib/firmware/brcm/BCM-05ac-8290.hcd
echo "Installed: /lib/firmware/brcm/BCM-05ac-8290.hcd"

# Also try common alternative names
sudo cp "$FIRMWARE_FILE" /lib/firmware/brcm/BCM20702A0-0a5c-8290.hcd 2>/dev/null || true

echo ""
echo -e "${GREEN}Firmware installed successfully!${NC}"
echo ""
echo "Cleaning up..."
cd /
rm -rf "$TEMP_DIR"

echo ""
echo -e "${YELLOW}Now resetting Bluetooth...${NC}"
sudo modprobe -r btusb
sudo modprobe btusb
sleep 2

echo ""
echo "Checking status..."
hciconfig -a

echo ""
echo -e "${GREEN}Done! Try checking Bluetooth status with: hciconfig -a${NC}"
echo "Or run: ./bt-fix.sh to diagnose"
