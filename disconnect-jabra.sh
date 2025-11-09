#!/bin/bash

# Quick script to disconnect Jabra Elite 85h
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

echo "Disconnecting Jabra Elite 85h..."

if bluetoothctl disconnect "$JABRA_MAC"; then
    echo "✓ Disconnected successfully!"
else
    echo "✗ Disconnect failed (may already be disconnected)"
fi
