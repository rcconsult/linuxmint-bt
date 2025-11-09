#!/bin/bash

JABRA_MAC="XX:XX:XX:XX:XX:XX"
CHECKS=6
INTERVAL=10

echo "Monitoring Jabra Elite 85h connection stability..."
echo "Time: $(date '+%H:%M:%S') - Starting monitor"
echo ""

for i in $(seq 1 $CHECKS); do
    sleep $INTERVAL
    STATUS=$(bluetoothctl info "$JABRA_MAC" | grep "Connected:" | awk '{print $2}')
    TIMESTAMP=$(date '+%H:%M:%S')

    if [ "$STATUS" = "yes" ]; then
        echo "[$TIMESTAMP] ✓ Connected (check $i/$CHECKS)"
    else
        echo "[$TIMESTAMP] ✗ DISCONNECTED (check $i/$CHECKS)"
        echo ""
        echo "Connection lost! Checking logs..."
        journalctl -u bluetooth --since "30 seconds ago" --no-pager | tail -10
        exit 1
    fi
done

echo ""
echo "✓ Connection remained stable for 60 seconds!"
echo ""
bluetoothctl info "$JABRA_MAC" | grep -E "Connected|Battery"
