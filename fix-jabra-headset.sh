#!/bin/bash

# Fix for Jabra Elite 85h disconnection issues
# This script addresses common bluetooth headset problems on Linux

set -e

JABRA_MAC="XX:XX:XX:XX:XX:XX"

echo "=== Jabra Elite 85h Disconnection Fix ==="
echo

# Function to check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "This script needs sudo privileges for some operations."
        echo "Please run with sudo or enter your password when prompted."
        echo
    fi
}

# Step 1: Enable bluetooth experimental features for better codec support
enable_experimental_features() {
    echo "Step 1: Enabling bluetooth experimental features..."

    BLUETOOTH_CONF="/etc/bluetooth/main.conf"

    if sudo grep -q "^Experimental = true" "$BLUETOOTH_CONF"; then
        echo "  ✓ Experimental features already enabled"
    else
        echo "  Enabling experimental features in $BLUETOOTH_CONF"
        sudo sed -i 's/^#Experimental = false/Experimental = true/' "$BLUETOOTH_CONF"
        sudo sed -i 's/^Experimental = false/Experimental = true/' "$BLUETOOTH_CONF"

        # If not found, add it to [General] section
        if ! sudo grep -q "^Experimental = true" "$BLUETOOTH_CONF"; then
            sudo sed -i '/^\[General\]/a Experimental = true' "$BLUETOOTH_CONF"
        fi
        echo "  ✓ Experimental features enabled"
    fi

    # Also enable kernel experimental features for better compatibility
    if sudo grep -q "^KernelExperimental = true" "$BLUETOOTH_CONF"; then
        echo "  ✓ Kernel experimental features already enabled"
    else
        echo "  Enabling kernel experimental features"
        sudo sed -i 's/^#KernelExperimental = false/KernelExperimental = true/' "$BLUETOOTH_CONF"
        sudo sed -i 's/^KernelExperimental = false/KernelExperimental = true/' "$BLUETOOTH_CONF"

        if ! sudo grep -q "^KernelExperimental = true" "$BLUETOOTH_CONF"; then
            sudo sed -i '/^\[General\]/a KernelExperimental = true' "$BLUETOOTH_CONF"
        fi
        echo "  ✓ Kernel experimental features enabled"
    fi
    echo
}

# Step 2: Disable USB autosuspend for bluetooth controller
disable_usb_autosuspend() {
    echo "Step 2: Disabling USB autosuspend for Bluetooth controller..."

    # Find the bluetooth USB device
    BT_USB_PATH=$(lsusb | grep -i bluetooth | awk '{print $2"/"$4}' | sed 's/:$//' | head -1)

    if [ -z "$BT_USB_PATH" ]; then
        echo "  ⚠ Bluetooth USB device not found, skipping"
        return
    fi

    BT_BUS=$(echo $BT_USB_PATH | cut -d'/' -f1)
    BT_DEV=$(echo $BT_USB_PATH | cut -d'/' -f2)

    # Find the USB device path in sysfs
    for usbdev in /sys/bus/usb/devices/*; do
        if [ -f "$usbdev/busnum" ] && [ -f "$usbdev/devnum" ]; then
            bus=$(cat "$usbdev/busnum" | sed 's/^0*//')
            dev=$(cat "$usbdev/devnum" | sed 's/^0*//')
            if [ "$bus" = "$BT_BUS" ] && [ "$dev" = "$BT_DEV" ]; then
                USBDEV_NAME=$(basename "$usbdev")
                echo "  Found bluetooth device: $USBDEV_NAME"

                # Disable autosuspend
                if [ -f "/sys/bus/usb/devices/$USBDEV_NAME/power/control" ]; then
                    echo "  Setting power control to 'on' for $USBDEV_NAME"
                    echo 'on' | sudo tee "/sys/bus/usb/devices/$USBDEV_NAME/power/control" > /dev/null
                    echo "  ✓ USB autosuspend disabled for bluetooth controller"
                fi

                # Make it permanent
                UDEV_RULE="/etc/udev/rules.d/50-bluetooth-usb-disable-autosuspend.rules"
                if [ -f "$UDEV_RULE" ]; then
                    echo "  ✓ Udev rule already exists"
                else
                    echo "  Creating udev rule for permanent fix..."
                    echo "# Disable USB autosuspend for Bluetooth controller" | sudo tee "$UDEV_RULE" > /dev/null
                    echo 'ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="05ac", ATTR{idProduct}=="8290", ATTR{power/control}="on"' | sudo tee -a "$UDEV_RULE" > /dev/null
                    sudo udevadm control --reload-rules
                    echo "  ✓ Udev rule created"
                fi
                break
            fi
        fi
    done
    echo
}

# Step 3: Configure PipeWire for bluetooth
configure_pipewire() {
    echo "Step 3: Configuring PipeWire for bluetooth..."

    PIPEWIRE_DIR="$HOME/.config/pipewire"
    PIPEWIRE_CONF="$PIPEWIRE_DIR/pipewire.conf.d"

    mkdir -p "$PIPEWIRE_CONF"

    BT_CONF="$PIPEWIRE_CONF/20-bluetooth.conf"

    cat > "$BT_CONF" << 'EOF'
# Bluetooth configuration for better stability
context.modules = [
    {   name = libpipewire-module-bluetooth-policy
        args = {
            # Automatically switch to A2DP sink profile when audio starts
            auto.switch = true
            # Increase connection quality
            msbc.support = true
        }
    }
]

# Enable high-quality bluetooth codecs
bluez5.enable-msbc = true
bluez5.enable-sbc-xq = true
bluez5.enable-hw-volume = true

# Reduce latency
bluez5.a2dp.opus.pro.application = audio
bluez5.a2dp.opus.pro.bidi.application = audio
EOF

    echo "  ✓ PipeWire bluetooth configuration created"
    echo
}

# Step 4: Restart bluetooth services
restart_bluetooth() {
    echo "Step 4: Restarting bluetooth services..."

    echo "  Restarting bluetooth daemon..."
    sudo systemctl restart bluetooth
    sleep 2

    echo "  Restarting PipeWire..."
    systemctl --user restart pipewire pipewire-pulse
    sleep 2

    echo "  ✓ Services restarted"
    echo
}

# Step 5: Remove and re-pair the Jabra headset
repair_jabra() {
    echo "Step 5: Re-pairing Jabra headset (optional)..."
    echo
    read -p "Do you want to remove and re-pair the Jabra headset? This may fix corrupted pairing data. [y/N]: " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "  Removing Jabra Elite 85h..."
        bluetoothctl remove "$JABRA_MAC" 2>/dev/null || true
        sleep 2

        echo
        echo "  Please put your Jabra Elite 85h into pairing mode:"
        echo "  1. Turn off the headset"
        echo "  2. Press and hold the Bluetooth button until the LED flashes blue"
        echo
        read -p "Press Enter when ready to scan and pair..."

        bluetoothctl scan on &
        SCAN_PID=$!
        sleep 10
        kill $SCAN_PID 2>/dev/null || true

        echo "  Pairing with Jabra..."
        bluetoothctl pair "$JABRA_MAC"
        bluetoothctl trust "$JABRA_MAC"
        bluetoothctl connect "$JABRA_MAC"

        echo "  ✓ Jabra headset re-paired"
    else
        echo "  Skipping re-pairing"
    fi
    echo
}

# Step 6: Test connection
test_connection() {
    echo "Step 6: Testing connection..."
    echo

    echo "  Attempting to connect to Jabra Elite 85h..."
    if bluetoothctl connect "$JABRA_MAC"; then
        echo "  ✓ Successfully connected!"
        echo
        bluetoothctl info "$JABRA_MAC" | grep -E "Connected|Name|Battery"
    else
        echo "  ⚠ Connection failed. Try manually:"
        echo "    bluetoothctl connect $JABRA_MAC"
    fi
    echo
}

# Main execution
check_root
enable_experimental_features
disable_usb_autosuspend
configure_pipewire
restart_bluetooth
repair_jabra
test_connection

echo "=== Fix Complete ==="
echo
echo "If you still experience disconnections:"
echo "1. Check bluetooth logs: journalctl -u bluetooth -f"
echo "2. Monitor the connection: bluetoothctl info $JABRA_MAC"
echo "3. Try connecting with: bluetoothctl connect $JABRA_MAC"
echo
