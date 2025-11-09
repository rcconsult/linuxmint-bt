#!/bin/bash

# Quick script to connect to Jabra Elite 85h
# IMPORTANT: Set your headset's MAC address here
# Find it with: bluetoothctl devices
JABRA_MAC="${JABRA_MAC:-XX:XX:XX:XX:XX:XX}"

if [ "$JABRA_MAC" = "XX:XX:XX:XX:XX:XX" ]; then
    echo "ERROR: Please set your headset MAC address"
    echo "Find it with: bluetoothctl devices"
    echo "Then set: export JABRA_MAC='your:mac:address:here'"
    echo "Or edit this script and replace XX:XX:XX:XX:XX:XX with your MAC address"
    exit 1
fi

echo "Connecting to Jabra Elite 85h..."

# First, ensure bluetooth is on
bluetoothctl power on

# Try to connect
if bluetoothctl connect "$JABRA_MAC"; then
    echo "✓ Connected successfully!"
    sleep 2
    bluetoothctl info "$JABRA_MAC" | grep -E "Connected|Name|Battery"
else
    echo "✗ Connection failed"
    echo
    echo "Troubleshooting:"
    echo "1. Make sure headset is powered on"
    echo "2. Make sure headset is in range"
    echo "3. Check status with: bluetoothctl info $JABRA_MAC"
    echo "4. View logs with: journalctl -u bluetooth -f"
    exit 1
fi
