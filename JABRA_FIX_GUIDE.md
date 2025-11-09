# Jabra Elite 85h Bluetooth Fix Guide

## Problem Summary

The Jabra Elite 85h headset was paired and trusted but kept disconnecting. The headset would not maintain a stable connection to the Linux system.

## Symptoms

- Headset paired and trusted but shows "Connected: no"
- Connection attempts fail with various errors:
  - "Connection refused (111)"
  - "Too many symbolic links (40)"
  - "br-connection-profile-unavailable"
  - "Protocol not available"
  - "Host is down"
- BlueZ logs showing A2DP profile connection failures

## Root Causes Identified

### 1. Faulty PipeWire Configuration
**File**: `~/.config/pipewire/pipewire.conf.d/20-bluetooth.conf`

The configuration attempted to load `libpipewire-module-bluetooth-policy` directly in PipeWire, but this module belongs to WirePlumber, not PipeWire core.

**Error**: `could not load mandatory module "libpipewire-module-bluetooth-policy": No such file or directory`

**Impact**: PipeWire crashed repeatedly, preventing bluetooth audio profiles from loading.

### 2. Missing Bluetooth Experimental Features
The bluetooth daemon needed experimental features enabled for better codec support and compatibility with modern headsets.

### 3. Corrupted Pairing State
The headset had corrupted pairing data that needed to be cleared and re-established.

### 4. Headset Power State Issues
The headset was in a stuck state and needed a power cycle to respond to connection attempts.

## Solutions Applied

### Step 1: Enable Bluetooth Experimental Features

Edit `/etc/bluetooth/main.conf`:

```bash
sudo nano /etc/bluetooth/main.conf
```

Add or uncomment under `[General]`:
```ini
Experimental = true
KernelExperimental = true
```

Restart bluetooth:
```bash
sudo systemctl restart bluetooth
```

**Why**: Enables better codec support and improved bluetooth device compatibility.

### Step 2: Remove Faulty PipeWire Configuration

The incorrect configuration file was removed:

```bash
rm ~/.config/pipewire/pipewire.conf.d/20-bluetooth.conf
```

**Why**: PipeWire was crashing because it couldn't load a non-existent bluetooth module. Bluetooth policy is handled by WirePlumber, not PipeWire directly.

### Step 3: Restart Audio Services

```bash
systemctl --user reset-failed pipewire
systemctl --user start pipewire pipewire-pulse
systemctl --user start wireplumber
```

Verify services are running:
```bash
systemctl --user status pipewire wireplumber
```

**Why**: After removing the bad config, services needed to be restarted to load properly.

### Step 4: Re-pair the Headset

Remove old pairing (using Blueman GUI or bluetoothctl):
```bash
bluetoothctl remove XX:XX:XX:XX:XX:XX
```

Put headset in pairing mode:
1. Turn off headset
2. Hold Bluetooth button for 3-5 seconds until LED flashes blue
3. Wait for "Pairing" announcement

Pair and trust:
```bash
bluetoothctl scan on
# Wait for device to appear
bluetoothctl pair XX:XX:XX:XX:XX:XX
bluetoothctl trust XX:XX:XX:XX:XX:XX
```

**Why**: Cleared corrupted pairing data and established fresh connection.

### Step 5: Power Cycle Headset

If connection still fails:
1. Turn OFF headset completely
2. Wait 5 seconds
3. Turn ON headset
4. Attempt connection

```bash
bluetoothctl connect XX:XX:XX:XX:XX:XX
```

**Why**: Headset can get stuck in a state where it advertises but won't accept connections. Power cycle resets its connection state.

## Verification

Check connection status:
```bash
bluetoothctl info XX:XX:XX:XX:XX:XX | grep -E "Connected|Battery"
```

Expected output:
```
Connected: yes
Battery Percentage: 0x64 (100)
```

Check audio profiles:
```bash
pactl list cards | grep -A 30 "bluez_card.70_BF_92_37_FA_CA"
```

Expected active profile: `a2dp-sink` (High Fidelity Playback)

## Available Scripts

### connect-jabra.sh
Quick connect to Jabra Elite 85h headset.

```bash
./connect-jabra.sh
```

### disconnect-jabra.sh
Quick disconnect from Jabra Elite 85h headset.

```bash
./disconnect-jabra.sh
```

### monitor-jabra.sh
Monitor connection stability for 60 seconds (6 checks every 10 seconds).

```bash
./monitor-jabra.sh
```

Useful for verifying the headset stays connected after fixes.

## Troubleshooting

### Issue: "Protocol not available" or "br-connection-profile-unavailable"

**Cause**: Audio services (PipeWire/WirePlumber) not running or not providing bluetooth profiles.

**Solution**:
```bash
# Check service status
systemctl --user status pipewire pipewire-pulse wireplumber

# If failed, check logs
journalctl --user -u pipewire --since "5 minutes ago"

# Restart services
systemctl --user restart pipewire pipewire-pulse wireplumber
```

### Issue: "Host is down" or "No route to host"

**Cause**: Headset is off, out of range, or in stuck state.

**Solution**:
1. Verify headset is powered on
2. Ensure headset is within range
3. Power cycle the headset
4. Ensure headset isn't connected to another device

### Issue: Connection succeeds but no audio

**Cause**: Wrong audio profile selected.

**Solution**:
```bash
# Check current profile
pactl list cards | grep -A 5 "bluez_card.70_BF_92_37_FA_CA"

# Switch to A2DP for music
pactl set-card-profile bluez_card.70_BF_92_37_FA_CA a2dp-sink

# Or use pavucontrol GUI
pavucontrol
```

### Issue: Headset disconnects randomly

**Cause**: USB power management, interference, or range issues.

**Check logs when disconnection occurs**:
```bash
journalctl -u bluetooth -f
```

**Potential solutions**:
1. Disable USB autosuspend for bluetooth controller
2. Check for WiFi interference (2.4GHz band conflicts)
3. Ensure headset firmware is up to date
4. Reduce distance between headset and computer

## System Configuration

### Bluetooth Controller
- Device: Apple Inc. Bluetooth Host Controller (05ac:8290)
- Chip: BCM20703A1 Generic USB UHE Apple 20Mhz

### Audio System
- Server: PipeWire 1.0.5
- Session Manager: WirePlumber
- Compatibility layer: PipeWire-PulseAudio

### OS
- Linux Mint (based on Ubuntu)
- Kernel: 6.8.0-87-generic

## Key Learnings

1. **PipeWire Module Confusion**: Bluetooth policy modules belong to WirePlumber, not PipeWire core. Don't try to load bluetooth-policy in PipeWire configuration.

2. **Service Dependencies**: PipeWire must start before WirePlumber. If PipeWire crashes, WirePlumber will fail with "dependency failed".

3. **Pairing State Matters**: Sometimes the only fix is to remove and re-pair the device with fresh state.

4. **Headset Power Cycles**: Bluetooth headsets can get into stuck states where they advertise but won't accept connections. Power cycling usually fixes this.

5. **Experimental Features**: Modern bluetooth headsets often need experimental features enabled in BlueZ for proper codec support.

## Logs to Check

When troubleshooting bluetooth issues:

```bash
# Bluetooth daemon logs
journalctl -u bluetooth -f

# Audio service logs
journalctl --user -u pipewire -f
journalctl --user -u wireplumber -f

# Check for errors in last 5 minutes
journalctl -u bluetooth --since "5 minutes ago" --no-pager

# Check for specific device
journalctl -u bluetooth --since "5 minutes ago" --no-pager | grep -i jabra
```

## Date Fixed
2025-11-09

## Device Info
- **Model**: Jabra Elite 85h
- **MAC Address**: XX:XX:XX:XX:XX:XX
- **Bluetooth Version**: v0067p248Bd0106
- **Supported Profiles**: A2DP, HFP/HSP, AVRCP
- **Audio Codecs**: SBC, SBC-XQ, mSBC (for calls)
