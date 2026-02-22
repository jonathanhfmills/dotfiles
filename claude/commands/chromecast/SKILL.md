---
name: chromecast
description: Manage Chromecast with Google TV ("Kitchen TV") via ADB. Sideload APKs, launch apps, check device status. Triggers on "chromecast", "kitchen tv", "adb", "sideload", "android tv".
---

# Chromecast with Google TV — Kitchen TV

## Device Info
- **Name:** Kitchen TV
- **IP:** 11.1.1.1
- **Model:** Chromecast (Google TV), Amlogic SoC
- **Android:** 14
- **CPU:** armeabi-v7a ONLY (32-bit ARM — no arm64!)
- **ADB Serial:** 0A211HFDD0Z73K
- **Already paired:** Yes (pairing persists across reboots)

## Connect via ADB

The device is already paired. Connection port changes on each reboot — user must enable wireless debugging and provide the port.

```bash
# Connect (user provides port from TV screen)
adb connect 11.1.1.1:<PORT>

# Verify connection
adb -s 11.1.1.1:<PORT> shell getprop ro.product.model
```

If connection fails, the device may need re-pairing:
```bash
# Pair first (user provides pairing port + 6-digit code from TV)
adb pair 11.1.1.1:<PAIR_PORT> <CODE>
# Then connect
adb connect 11.1.1.1:<PORT>
```

## Enable Wireless Debugging (user must do this on TV)
1. Settings → System → About → tap "Android TV OS Build" 7 times (enables Developer Options)
2. Settings → System → Developer Options → Wireless debugging → ON
3. TV shows IP:port for connection
4. For pairing: tap "Pair device with pairing code" → shows separate port + 6-digit code

## Sideload APKs

**CRITICAL: Always use armeabi-v7a (32-bit ARM) APKs. arm64 APKs will fail with INSTALL_FAILED_NO_MATCHING_ABIS.**

```bash
# Download APK to temp
curl -L -o /tmp/app.apk "<URL>"

# Verify it's a real APK (not a redirect page)
ls -lh /tmp/app.apk  # Should be multi-MB, not a few hundred bytes
file /tmp/app.apk     # Should say "Zip archive" or "Android application"

# Install
adb -s 11.1.1.1:<PORT> install /tmp/app.apk

# Clean up
rm /tmp/app.apk
```

## Launch Apps

```bash
# Launch via LEANBACK_LAUNCHER (Android TV launcher category)
adb -s 11.1.1.1:<PORT> shell monkey -p <PACKAGE> -c android.intent.category.LEANBACK_LAUNCHER 1
```

## Installed Apps
| App | Package | Version |
|-----|---------|---------|
| Stremio | com.stremio.one | 1.9.5 |
| Tailscale | com.tailscale.ipn | 1.94.2 |

## Useful Commands

```bash
# List installed packages
adb -s 11.1.1.1:<PORT> shell pm list packages

# Check device architecture
adb -s 11.1.1.1:<PORT> shell getprop ro.product.cpu.abilist

# Uninstall app
adb -s 11.1.1.1:<PORT> uninstall <PACKAGE>

# Get Android version
adb -s 11.1.1.1:<PORT> shell getprop ro.build.version.release

# Reboot device
adb -s 11.1.1.1:<PORT> reboot
```

## Finding APKs

- **Official sites first** — check the app's download page for Android TV / armeabi-v7a variants
- **APKMirror** — reputable third-party host, filter by architecture
- **Stremio:** https://www.stremio.com/downloads (select Android TV → armeabi-v7a)
- **Tailscale:** https://pkgs.tailscale.com/stable/ (universal APK covers all architectures)

## Network Discovery

The Chromecast advertises via mDNS:
```bash
avahi-browse -arpt _googlecast._tcp    # Find Cast devices
avahi-browse -arpt _androidtvremote2._tcp  # Find Android TV devices
```

## In-Progress
- Tailscale needs sign-in on the device (device code auth flow at tailscale.com/login/...)
