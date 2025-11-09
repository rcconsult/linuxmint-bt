# Bluetooth Fix for Mac 2015 Hardware on Linux Mint

## Problem Summary

Your Mac 2015 hardware uses an **Apple Bluetooth Host Controller (05ac:8290)** with a Broadcom BCM chip. The issue is:

- ✅ Hardware is detected
- ✅ Bluetooth service is running
- ❌ **Firmware file is missing** for device 05ac:8290 (or firmware is present but not loading)
- ❌ Device shows `DOWN` status with invalid MAC (00:00:00:00:00:00)
- ❌ Kernel error: `BCM: Reset failed (-110)` or `Connection timed out (110)`
- ❌ USB error: `Failed to suspend device, error -110`

## Root Cause

There are two common issues:

### Issue 1: Missing Firmware
```
Direct firmware load for brcm/BCM-05ac-8290.hcd failed
```
The firmware file is missing from `/lib/firmware/brcm/`.

### Issue 2: USB Communication Timeout (More Common)
```
Bluetooth: hci0: command 0x0c03 tx timeout
Bluetooth: hci0: BCM: Reset failed (-110)
usb 1-8: Failed to suspend device, error -110
```
Even with firmware present, the USB device fails to communicate. This is caused by:
- **USB autosuspend** interfering with Bluetooth initialization
- The device timing out before it can load firmware
- USB controller losing communication with the device

## Solution

### Step 1: Install Firmware (If Not Already Done)

Run the automated firmware installer:

```bash
./bt-install-firmware.sh
```

This script will:
1. Download firmware from the community repository
2. Install the correct firmware file for your device
3. Reset the Bluetooth modules
4. Verify the installation

### Step 2: Fix USB Communication Issues (If Step 1 Didn't Work)

If you see "Connection timed out (110)" errors, the USB communication needs to be fixed:

```bash
./bt-fix-usb-reset.sh
```

This script will:
1. Disable USB autosuspend for the Bluetooth device
2. Try alternative firmware combinations
3. Completely reset all Bluetooth modules in the correct order
4. Attempt to bring up the device
5. Show detailed diagnostics

### Step 3: Make Fixes Permanent (Recommended After Success)

Once Bluetooth is working, make the fix permanent across reboots:

```bash
./bt-permanent-fix.sh
```

This script will:
1. Create a udev rule to permanently disable USB autosuspend
2. Add kernel module parameters for btusb
3. Update initramfs
4. Require a reboot to take full effect

### Manual Fix

If the automated script doesn't work, you can manually install firmware:

1. **Download firmware repository:**
   ```bash
   git clone https://github.com/winterheart/broadcom-bt-firmware.git
   cd broadcom-bt-firmware/brcm
   ```

2. **Install firmware file:**
   ```bash
   sudo cp BCM*.hcd /lib/firmware/brcm/BCM-05ac-8290.hcd
   ```

3. **Reset Bluetooth:**
   ```bash
   sudo modprobe -r btusb
   sudo modprobe btusb
   sudo hciconfig hci0 up
   ```

### Alternative: Extract from macOS

If you have access to macOS on the same machine:

1. Boot into macOS
2. Copy firmware from: `/System/Library/Extensions/IOBluetoothFamily.kext/Contents/PlugIns/BroadcomBluetoothHostControllerUSBTransport.kext/Contents/Resources/`
3. Look for `.dfu` or `.bin` files
4. Convert and copy to Linux

## Diagnostic Tool

Run diagnostics and troubleshooting:

```bash
./bt-fix.sh
```

This will:
- Show current Bluetooth status
- Check for firmware files
- Attempt to reset modules
- Display kernel messages
- Provide specific error information

## Verification

After running the fix, verify Bluetooth is working:

```bash
# Check device status
hciconfig -a

# Should show:
# - Status: UP RUNNING
# - Valid MAC address (not 00:00:00:00:00:00)
# - No errors

# Test scanning
bluetoothctl
> scan on
```

## Expected Output After Fix

```
hci0:   Type: Primary  Bus: USB
        BD Address: XX:XX:XX:XX:XX:XX  ACL MTU: 1021:8  SCO MTU: 64:1
        UP RUNNING
        RX bytes:... acl:... sco:... events:... errors:0
        TX bytes:... acl:... sco:... commands:... errors:0
```

## Troubleshooting

### If it still doesn't work:

1. **Check kernel messages:**
   ```bash
   dmesg | grep -i bluetooth
   ```

2. **Verify firmware is loaded:**
   ```bash
   ls -la /lib/firmware/brcm/BCM*8290*
   ```

3. **Check USB device:**
   ```bash
   lsusb | grep Bluetooth
   ```

4. **Restart Bluetooth service:**
   ```bash
   sudo systemctl restart bluetooth
   ```

5. **Try different firmware:** The repository has multiple firmware files. Try different BCM20702 or BCM20703 variants.

6. **If nothing works, reboot:** Sometimes a full system reboot is required to reset the USB controller:
   ```bash
   sudo reboot
   ```
   After reboot, run `./bt-fix-usb-reset.sh` again.

## Known Mac Models with This Issue

- MacBook Pro 2015 (11,x / 12,x)
- MacBook Air 2015
- iMac 2015

All these models use Broadcom Bluetooth chips that require specific firmware on Linux.

## Additional Resources

- [Broadcom BT Firmware Repository](https://github.com/winterheart/broadcom-bt-firmware)
- [Linux Bluetooth Wiki](https://wiki.archlinux.org/title/Bluetooth)
- [Debian Wiki - Bluetooth](https://wiki.debian.org/BluetoothUser)

## Complete Fix Guide

**[COMPLETE_FIX_GUIDE.md](COMPLETE_FIX_GUIDE.md)** - Complete documentation covering both adapter hardware fixes AND headset connection issues

## Jabra Elite 85h Headset Connection Issues

If your Jabra Elite 85h (or similar bluetooth headset) is paired but keeps disconnecting, see:

**[JABRA_FIX_GUIDE.md](JABRA_FIX_GUIDE.md)** - Focused guide for Jabra headset disconnection issues
**[COMPLETE_FIX_GUIDE.md](COMPLETE_FIX_GUIDE.md)** - Complete guide including adapter fixes

**Quick helper scripts:**
- `connect-jabra.sh` - Quick connect to Jabra Elite 85h
- `disconnect-jabra.sh` - Quick disconnect from Jabra Elite 85h
- `monitor-jabra.sh` - Monitor connection stability

**Configuration:** Before using these scripts, you need to set your headset's MAC address:
1. Find your MAC address: `bluetoothctl devices`
2. Either:
   - Export as environment variable: `export JABRA_MAC='XX:XX:XX:XX:XX:XX'`
   - Or edit each script and replace `XX:XX:XX:XX:XX:XX` with your actual MAC address

**Common issues covered:**
- PipeWire/WirePlumber configuration problems
- A2DP audio profile failures
- Headset pairing state corruption
- Bluetooth experimental features

## Files in This Directory

### Hardware Bluetooth Controller Fixes
- `bt-install-firmware.sh` - Downloads and installs firmware (Step 1)
- `bt-fix-usb-reset.sh` - Fixes USB communication issues (Step 2)
- `bt-permanent-fix.sh` - Makes fixes permanent (Step 3)
- `bt-fix.sh` - Basic diagnostic and troubleshooting script
- `bt-status.sh` - Quick status checker

### Jabra Headset Fixes
- `fix-jabra-headset.sh` - Comprehensive fix for Jabra Elite 85h disconnections
- `connect-jabra.sh` - Quick connect helper
- `disconnect-jabra.sh` - Quick disconnect helper
- `monitor-jabra.sh` - Connection stability monitor
- `JABRA_FIX_GUIDE.md` - Detailed troubleshooting guide

### Documentation
- `README.md` - This file
- `JABRA_FIX_GUIDE.md` - Jabra headset troubleshooting guide

---

**Note:** This is a common issue with Mac hardware on Linux. The fix is well-established in the Linux community, and the firmware repository is maintained specifically for this purpose.
