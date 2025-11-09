#!/bin/bash

# Quick script to disconnect Jabra Elite 85h
JABRA_MAC="XX:XX:XX:XX:XX:XX"

echo "Disconnecting Jabra Elite 85h..."

if bluetoothctl disconnect "$JABRA_MAC"; then
    echo "✓ Disconnected successfully!"
else
    echo "✗ Disconnect failed (may already be disconnected)"
fi
