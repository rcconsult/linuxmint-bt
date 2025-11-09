#!/bin/bash
# Manual firmware installation - run this in your terminal

echo "Installing Bluetooth firmware for device 05ac:8290..."
echo ""

# Copy the firmware file
sudo cp /tmp/broadcom-bt-firmware/brcm/BCM20702A1-0a5c-21e8.hcd /lib/firmware/brcm/BCM-05ac-8290.hcd

# Also try with the chip vendor ID format
sudo cp /tmp/broadcom-bt-firmware/brcm/BCM20702A1-0a5c-21e8.hcd /lib/firmware/brcm/BCM-0a5c-8290.hcd

echo ""
echo "Firmware installed. Now resetting Bluetooth..."
echo ""

# Reset Bluetooth modules
sudo modprobe -r btusb
sudo modprobe btusb

sleep 2

echo ""
echo "Attempting to bring up Bluetooth..."
sudo hciconfig hci0 up

sleep 1

echo ""
echo "Current status:"
hciconfig -a

echo ""
echo "Done!"
