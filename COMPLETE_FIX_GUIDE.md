# Complete Bluetooth Fix Guide for MacBook Pro 2015 on Linux Mint

**System**: Linux Mint on MacBook Pro 2015
**Bluetooth Controller**: Apple Inc. Bluetooth Host Controller (05ac:8290)
**Chip**: BCM20703A1 Generic USB UHE Apple 20Mhz
**Date**: 2025-11-09

This guide documents the complete bluetooth fix journey from getting the hardware working to fixing headset disconnection issues.

---

## Table of Contents

1. [Part 1: Bluetooth Adapter Hardware Fixes](#part-1-bluetooth-adapter-hardware-fixes)
2. [Part 2: Jabra Elite 85h Headset Disconnection Fixes](#part-2-jabra-elite-85h-headset-disconnection-fixes)
3. [Quick Reference](#quick-reference)

---

## Part 1: Bluetooth Adapter Hardware Fixes

### Problem Summary

Mac 2015 hardware uses an Apple Bluetooth Host Controller with a Broadcom BCM20703A1 chip. Common issues:

- ✅ Hardware detected
- ✅ Bluetooth service running
- ❌ Firmware file missing or not loading
- ❌ Device shows `DOWN` status with invalid MAC (00:00:00:00:00:00)
- ❌ Kernel errors: `BCM: Reset failed (-110)` or `Connection timed out (110)`
- ❌ USB errors: `Failed to suspend device, error -110`

### Root Causes

#### Issue 1: Missing Firmware
```
Direct firmware load for brcm/BCM-05ac-8290.hcd failed
```
The required firmware file is missing from `/lib/firmware/brcm/`.

#### Issue 2: USB Communication Timeout (More Common)
```
Bluetooth: hci0: command 0x0c03 tx timeout
Bluetooth: hci0: BCM: Reset failed (-110)
usb 1-8: Failed to suspend device, error -110
```
Even with firmware present, USB autosuspend interferes with bluetooth initialization.

### Solutions Applied

#### Step 1: Install Firmware

Automated script:
```bash
./bt-install-firmware.sh
```

This downloads firmware from the community repository and installs it for device 05ac:8290.

**Manual installation:**
```bash
# Download repository
git clone https://github.com/winterheart/broadcom-bt-firmware.git
cd broadcom-bt-firmware/brcm

# Install firmware
sudo cp BCM20703A1*.hcd /lib/firmware/brcm/BCM-05ac-8290.hcd

# Reset modules
sudo modprobe -r btusb
sudo modprobe btusb
sudo hciconfig hci0 up
```

#### Step 2: Fix USB Communication Issues

If "Connection timed out (110)" errors occur:

```bash
./bt-fix-usb-reset.sh
```

This script:
1. Disables USB autosuspend for the Bluetooth device
2. Tries alternative firmware combinations
3. Resets all Bluetooth modules in correct order
4. Shows detailed diagnostics

**Manual fix:**
```bash
# Find bluetooth USB device
lsusb | grep -i bluetooth

# Disable autosuspend
echo 'on' | sudo tee /sys/bus/usb/devices/1-8/power/control
```

#### Step 3: Make Fixes Permanent

```bash
./bt-permanent-fix.sh
```

Creates udev rules and kernel module parameters. Requires reboot.

### Verification

After fix, verify:
```bash
hciconfig -a
```

Expected output:
```
hci0:   Type: Primary  Bus: USB
        BD Address: XX:XX:XX:XX:XX:XX  ACL MTU: 1021:8  SCO MTU: 64:1
        UP RUNNING
```

Kernel messages should show:
```
Bluetooth: hci0: BCM: chip id 102 build 0729
Bluetooth: hci0: BCM: product 05ac:8290
Bluetooth: hci0: BCM20703A1 Generic USB UHE Apple 20Mhz fcbga_X87
```

---

## Part 2: Jabra Elite 85h Headset Disconnection Fixes

### Problem Summary

After getting the bluetooth adapter working, the Jabra Elite 85h headset was paired and trusted but kept disconnecting.

### Symptoms

- Headset paired and trusted but shows "Connected: no"
- Connection attempts fail with errors:
  - "Connection refused (111)"
  - "Too many symbolic links (40)"
  - "br-connection-profile-unavailable"
  - "Protocol not available"
  - "Host is down"
- BlueZ logs showing A2DP profile connection failures

### Root Causes Identified

#### 1. Faulty PipeWire Configuration (CRITICAL)

**File**: `~/.config/pipewire/pipewire.conf.d/20-bluetooth.conf`

The configuration attempted to load `libpipewire-module-bluetooth-policy` directly in PipeWire:

```conf
context.modules = [
    {   name = libpipewire-module-bluetooth-policy
        args = { ... }
    }
]
```

**Error**: `could not load mandatory module "libpipewire-module-bluetooth-policy": No such file or directory`

**Why it's wrong**: Bluetooth policy modules belong to **WirePlumber**, not PipeWire core. PipeWire handles the audio pipeline, WirePlumber handles bluetooth device policy and session management.

**Impact**: PipeWire crashed repeatedly, preventing bluetooth audio profiles from loading. Without working PipeWire, no A2DP audio profile could connect.

#### 2. Missing Bluetooth Experimental Features

Modern bluetooth headsets need experimental features enabled for proper codec support.

#### 3. Corrupted Pairing State

The headset had corrupted pairing data that needed to be cleared.

#### 4. Headset Power State Issues

The headset was in a stuck state where it advertised but wouldn't accept connections.

### Audio Stack Architecture

Understanding the stack is critical:

```
┌─────────────────────────────────┐
│  BlueZ (bluetoothd)            │  ← Core bluetooth protocol
└────────────┬────────────────────┘
             │
┌────────────▼────────────────────┐
│  WirePlumber                    │  ← Session manager, bluetooth device policy
└────────────┬────────────────────┘
             │
┌────────────▼────────────────────┐
│  PipeWire                       │  ← Audio server/pipeline
└────────────┬────────────────────┘
             │
┌────────────▼────────────────────┐
│  PipeWire-Pulse                │  ← PulseAudio compatibility
└─────────────────────────────────┘
```

**Key point**: Don't mix WirePlumber modules into PipeWire configuration!

### Solutions Applied

#### Step 1: Enable Bluetooth Experimental Features

Edit `/etc/bluetooth/main.conf`:

```bash
sudo nano /etc/bluetooth/main.conf
```

Add under `[General]`:
```ini
Experimental = true
KernelExperimental = true
```

Restart bluetooth:
```bash
sudo systemctl restart bluetooth
```

**Why**: Enables better codec support (SBC-XQ, mSBC) and improved device compatibility.

#### Step 2: Remove Faulty PipeWire Configuration (CRITICAL)

```bash
rm ~/.config/pipewire/pipewire.conf.d/20-bluetooth.conf
```

**Why**: The configuration was causing PipeWire to crash on startup. Bluetooth policy should be handled by WirePlumber's own configuration, not loaded as a PipeWire module.

#### Step 3: Restart Audio Services

```bash
# Reset any failed states
systemctl --user reset-failed pipewire

# Start services in correct order
systemctl --user start pipewire pipewire-pulse
systemctl --user start wireplumber

# Verify they're running
systemctl --user status pipewire wireplumber
```

**Expected**: Both services should show "active (running)"

**Check for errors**:
```bash
journalctl --user -u pipewire --since "5 minutes ago"
```

Should NOT see: "could not load mandatory module" errors

#### Step 4: Re-pair the Headset

Remove old corrupted pairing:
```bash
bluetoothctl remove XX:XX:XX:XX:XX:XX
```

Put headset in pairing mode:
1. Turn off headset
2. Hold Bluetooth button for 3-5 seconds until LED flashes blue rapidly
3. Wait for "Pairing" voice announcement

Pair using GUI (Blueman) or command line:
```bash
bluetoothctl scan on
# Wait for device to appear
bluetoothctl pair XX:XX:XX:XX:XX:XX
bluetoothctl trust XX:XX:XX:XX:XX:XX
```

**Why**: Clears corrupted pairing data and establishes fresh connection with properly working audio stack.

#### Step 5: Power Cycle Headset

If connection still fails after pairing:
1. Turn OFF headset completely
2. Wait 5 seconds
3. Turn ON headset
4. Attempt connection:
   ```bash
   bluetoothctl connect XX:XX:XX:XX:XX:XX
   ```

**Why**: Headset can get stuck advertising but not accepting connections. Power cycle resets its internal state.

### Verification

Check connection status:
```bash
bluetoothctl info XX:XX:XX:XX:XX:XX | grep -E "Connected|Battery"
```

Expected:
```
Connected: yes
Battery Percentage: 0x64 (100)
```

Check audio profiles:
```bash
pactl list cards | grep -A 30 "bluez_card.70_BF_92_37_FA_CA"
```

Expected active profile: `a2dp-sink` (High Fidelity Playback)

Available profiles should include:
- `a2dp-sink` - High quality music playback (SBC codec)
- `a2dp-sink-sbc_xq` - Extra high quality (SBC-XQ codec)
- `headset-head-unit-msbc` - Voice calls with wideband audio (mSBC codec)

### Monitor Connection Stability

```bash
./monitor-jabra.sh
```

This monitors the connection for 60 seconds, checking every 10 seconds. Should show all checks passing.

---

## Quick Reference

### Daily Use Scripts

**Connect to Jabra headset:**
```bash
./connect-jabra.sh
```

**Disconnect from Jabra headset:**
```bash
./disconnect-jabra.sh
```

**Monitor connection stability:**
```bash
./monitor-jabra.sh
```

### Troubleshooting Commands

**Check bluetooth adapter status:**
```bash
hciconfig -a
./bt-status.sh
```

**Check audio services:**
```bash
systemctl --user status pipewire wireplumber
pactl info
```

**Check bluetooth daemon logs:**
```bash
journalctl -u bluetooth -f
```

**Check PipeWire logs:**
```bash
journalctl --user -u pipewire -f
journalctl --user -u wireplumber -f
```

**Check what's using bluetooth:**
```bash
bluetoothctl devices
bluetoothctl info XX:XX:XX:XX:XX:XX  # Jabra
```

### Common Error Messages and Fixes

| Error | Cause | Solution |
|-------|-------|----------|
| `BCM: Reset failed (-110)` | USB timeout | Run `./bt-fix-usb-reset.sh` |
| `Direct firmware load failed` | Missing firmware | Run `./bt-install-firmware.sh` |
| `could not load mandatory module` | Wrong PipeWire config | Remove `~/.config/pipewire/pipewire.conf.d/20-bluetooth.conf` |
| `br-connection-profile-unavailable` | Audio services not running | Restart pipewire and wireplumber |
| `Protocol not available` | Audio profiles not loaded | Check PipeWire/WirePlumber status |
| `Host is down` | Headset off or stuck | Power cycle headset |
| `Connection refused (111)` | Corrupted pairing | Remove and re-pair device |

---

## System Configuration Summary

### Hardware
- **Computer**: MacBook Pro 2015
- **Bluetooth**: Apple Inc. Host Controller (05ac:8290)
- **Chip**: Broadcom BCM20703A1
- **Headset**: Jabra Elite 85h (XX:XX:XX:XX:XX:XX)

### Software
- **OS**: Linux Mint (based on Ubuntu)
- **Kernel**: 6.8.0-87-generic
- **Bluetooth**: BlueZ 5.x
- **Audio**: PipeWire 1.0.5 with WirePlumber

### Key Files Modified
1. `/etc/bluetooth/main.conf` - Enabled experimental features
2. `~/.config/pipewire/pipewire.conf.d/20-bluetooth.conf` - REMOVED (was faulty)

### Scripts Created
- `bt-install-firmware.sh` - Install adapter firmware
- `bt-fix-usb-reset.sh` - Fix USB communication
- `bt-permanent-fix.sh` - Make adapter fixes permanent
- `bt-fix.sh` - Basic diagnostics
- `bt-status.sh` - Quick status check
- `fix-jabra-headset.sh` - Comprehensive headset fix (deprecated, had bad config)
- `connect-jabra.sh` - Quick connect helper
- `disconnect-jabra.sh` - Quick disconnect helper
- `monitor-jabra.sh` - Connection stability monitor

---

## Key Learnings

### 1. PipeWire vs WirePlumber Module Separation

**CRITICAL**: Never load bluetooth-policy modules in PipeWire configuration!

- `libpipewire-module-bluetooth-policy` belongs to WirePlumber
- Loading it in PipeWire config causes PipeWire to crash
- This prevents all bluetooth audio from working

### 2. Service Dependency Order

PipeWire must start before WirePlumber:
```
PipeWire → PipeWire-Pulse → WirePlumber
```

If PipeWire fails, WirePlumber shows "dependency failed"

### 3. Pairing State Corruption

Sometimes the only fix is complete re-pairing:
1. Remove device from system
2. Clear headset pairing (factory reset if needed)
3. Pair fresh

### 4. Headset Power Cycles

Bluetooth headsets can get into stuck states where they:
- Advertise their presence
- Show in scan results
- Refuse connection attempts

Power cycling usually fixes this.

### 5. Mac Hardware on Linux

Mac 2015 hardware requires:
- Community-maintained firmware files
- Disabling USB autosuspend
- Sometimes kernel module parameters

The fix is well-established but not automatic.

---

## Monitoring for Future Issues

### Watch for These Signs

**Adapter issues:**
```bash
dmesg | grep -i bluetooth
# Look for: timeout, reset failed, firmware errors
```

**Audio stack issues:**
```bash
journalctl --user -u pipewire --since "1 hour ago"
# Look for: "could not load", "failed to create context"
```

**Connection issues:**
```bash
journalctl -u bluetooth --since "10 minutes ago"
# Look for: "Connection refused", "Host is down", "Protocol not available"
```

### Preventive Maintenance

1. **Don't modify PipeWire/WirePlumber configs** unless you understand the architecture
2. **Keep bluetooth experimental features enabled** - needed for modern devices
3. **Monitor for firmware updates** - check broadcom-bt-firmware repo occasionally
4. **Document any changes** - bluetooth debugging is complex

---

## Date Fixed
2025-11-09

## Status
✓ Bluetooth adapter working
✓ Jabra Elite 85h connecting reliably
✓ A2DP audio profile active
✓ Battery reporting functional
✓ Connection stable (verified 60+ seconds)
