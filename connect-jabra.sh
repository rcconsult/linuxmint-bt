#!/bin/bash

# Quick script to connect to Jabra Elite 85h
JABRA_MAC="XX:XX:XX:XX:XX:XX"

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
