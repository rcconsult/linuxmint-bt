#!/bin/bash
# Quick Bluetooth status checker (no sudo required)

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=========================================="
echo "Bluetooth Quick Status"
echo "=========================================="
echo ""

# Check if device exists
echo -e "${YELLOW}Device Status:${NC}"
if hciconfig 2>/dev/null | grep -q "hci0"; then
    HCI_STATUS=$(hciconfig hci0 2>/dev/null | grep -E "UP|DOWN")
    MAC_ADDR=$(hciconfig hci0 2>/dev/null | grep "BD Address" | awk '{print $3}')

    if echo "$HCI_STATUS" | grep -q "UP"; then
        echo -e "  ${GREEN}✓${NC} hci0 is UP"
    else
        echo -e "  ${RED}✗${NC} hci0 is DOWN"
    fi

    if [ "$MAC_ADDR" != "00:00:00:00:00:00" ] && [ -n "$MAC_ADDR" ]; then
        echo -e "  ${GREEN}✓${NC} Valid MAC address: $MAC_ADDR"
    else
        echo -e "  ${RED}✗${NC} Invalid MAC address: $MAC_ADDR"
    fi
else
    echo -e "  ${RED}✗${NC} No Bluetooth device found"
fi

echo ""
echo -e "${YELLOW}Service Status:${NC}"
if systemctl is-active --quiet bluetooth; then
    echo -e "  ${GREEN}✓${NC} Bluetooth service is running"
else
    echo -e "  ${RED}✗${NC} Bluetooth service is not running"
fi

echo ""
echo -e "${YELLOW}Firmware Files:${NC}"
if ls /lib/firmware/brcm/BCM*8290* 2>/dev/null | grep -q .; then
    echo -e "  ${GREEN}✓${NC} Firmware file exists:"
    ls -la /lib/firmware/brcm/BCM*8290* 2>/dev/null
else
    echo -e "  ${RED}✗${NC} Firmware file missing for device 8290"
    echo "    Run: ./bt-install-firmware.sh"
fi

echo ""
echo -e "${YELLOW}Recent Errors:${NC}"
if dmesg 2>/dev/null | grep -i "bluetooth.*error\|BCM.*failed" | tail -3 | grep -q .; then
    dmesg 2>/dev/null | grep -i "bluetooth.*error\|BCM.*failed" | tail -3
else
    echo "  No recent errors"
fi

echo ""
echo "=========================================="
if hciconfig 2>/dev/null | grep -q "UP RUNNING"; then
    echo -e "${GREEN}Status: Bluetooth is working!${NC}"
else
    echo -e "${YELLOW}Status: Bluetooth needs fixing${NC}"
    echo "Run: ./bt-fix.sh for diagnostics"
    echo "Run: ./bt-install-firmware.sh to install firmware"
fi
echo "=========================================="
