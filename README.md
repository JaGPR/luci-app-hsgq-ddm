# luci-app-hsgq-ddm

Optical diagnostics for **HSGQ / ODI DFP-34X GPON SFP ONU sticks** in OpenWrt's LuCI.

See your fibre link's health right on the router: receive/transmit power, laser
temperature, voltage and bias current, GPON activation state, FEC/BIP error
counters, optical alarms, T-CONT/GEM allocations, OMCI managed entities, SFP
host-link traffic and history charts. The data is read from the stick over telnet.

> A fork of [luci-app-vsol-ddm](https://github.com/AliLostInTheDark/luci-app-vsol-ddm)
> by AliLostInTheDark, adapted for Realtek-based GPON **SFP sticks**. All credit for
> the original design goes to its authors. See [NOTICE](NOTICE) for what changed.

---

## Contents
- [Supported devices](#supported-devices)
- [Requirements](#requirements)
- [Installation](#installation)
- [Configuration](#configuration)
- [Reaching the stick's management address](#reaching-the-sticks-management-address)
- [What the dashboard shows](#what-the-dashboard-shows)
- [Upgrade and uninstall](#upgrade-and-uninstall)
- [Troubleshooting](#troubleshooting)
- [Security notes](#security-notes)
- [How it works](#how-it-works)
- [Building a package from source](#building-a-package-from-source)
- [License](#license)

---

## Supported devices

| Device | Status |
|---|---|
| **HSGQ GPON SFP stick** (ODI DFP-34X-2C2 inside) | ✅ Tested |
| ODI DFP-34X family / other Realtek RTL960x GPON SFP sticks with a Linux telnet login | Should work. Please open an issue with your results |

**How to tell if yours is compatible:** telnet to the stick. If you get a Linux
`login:` prompt, then a `#` shell, and `diag pon get transceiver rx-power` prints
`Rx Power: … dBm`, it's the same platform.

For VSOL V2802RH and other ONTs with a Cisco-style CLI, use the original
[luci-app-vsol-ddm](https://github.com/AliLostInTheDark/luci-app-vsol-ddm). Both
packages can be installed side by side.

## Requirements
- OpenWrt **23.05 or newer** with **LuCI** (tested on 25.12)
- BusyBox `nc` (included in standard OpenWrt builds)
- The router can reach the stick's **management IP** (see [below](#reaching-the-sticks-management-address))
- The stick's **telnet username and password**

## Installation

### Option A: one-line installer (recommended)
Run this on the router (SSH in as root):

```sh
wget -qO /tmp/install.sh https://raw.githubusercontent.com/JaGPR/luci-app-hsgq-ddm/main/install.sh && sh /tmp/install.sh
```

If `wget` reports an SSL error, install HTTPS support first:
`apk add ca-bundle` (OpenWrt 24+) or `opkg update && opkg install ca-bundle` (23.05).

The installer:
1. checks that it's running on OpenWrt with LuCI,
2. downloads this repository,
3. copies the files into place. An existing `/etc/config/hsgq_ddm` is **kept**, so reinstalling never wipes your settings,
4. seeds missing defaults without overwriting existing values,
5. registers the page with LuCI.

It doesn't reboot anything and doesn't touch any other package.

Preview without changing anything:
```sh
wget -qO /tmp/install.sh https://raw.githubusercontent.com/JaGPR/luci-app-hsgq-ddm/main/install.sh
DRY_RUN=1 sh /tmp/install.sh
```

### Option B: from a release package
If a `.apk` (OpenWrt 24+) or `.ipk` (23.05) is attached to a
[release](https://github.com/JaGPR/luci-app-hsgq-ddm/releases):
```sh
apk add --allow-untrusted ./luci-app-hsgq-ddm-*.apk    # OpenWrt 24+
opkg install ./luci-app-hsgq-ddm_*.ipk                  # OpenWrt 23.05
```
Or upload it on **System → Software** in LuCI.

### After installing
**Log out of LuCI and log back in.** LuCI grants page permissions at login, so the
new menu entry only appears in a fresh session. If it's still missing, press Ctrl+F5.

## Configuration
Go to **Status → HSGQ GPON DDM → Settings**:

| Setting | Value |
|---|---|
| Enable | On |
| ONT address | The stick's management IP. **Often `192.168.1.1`** |
| Telnet port | `23` |
| Username / Password | The stick's telnet login (set by you or your ISP) |
| Polling interval | How often the dashboard refreshes (3 s default) |
| Connection timeout | `20` s (a full read takes about 9 s) |
| Optical class | `B+` for standard GPON (the ODI optic doesn't report its class) |

Click **Save & Apply**, then **Test connection**, then open **Optical Diagnostics**.

There are **no default address or credentials** on purpose. Until you set them,
the page shows "Not configured" and makes no connection attempts.

## Reaching the stick's management address
The stick's management IP (often `192.168.1.1`) usually sits on its own subnet,
and sometimes its own VLAN, so the router needs an interface on that subnet:

1. **Network → Interfaces → Add new interface**
   - Name: `onu_mgmt`, Protocol: **Static address**
   - Device: the port or VLAN the stick is on (e.g. `wan`, or `eth1.124` if the management traffic is VLAN-tagged)
2. IPv4 address: a free address on the stick's subnet, e.g. `192.168.1.4`, netmask `255.255.255.0`
3. **Advanced Settings → untick "Use default gateway"** ⚠️
   Otherwise the stick's address becomes the router's default route and the
   router's own traffic (DNS, NTP, updates) gets sent to the stick.
4. **Firewall Settings:** put it in the `wan` zone.
5. Save & Apply, then check with `ping 192.168.1.1` from the router.

> If your LAN also uses `192.168.1.0/24`, the addresses clash. Move your LAN to
> a different subnet before adding the management interface.

## What the dashboard shows
- **Signal gauges:** Rx power, Tx power, temperature, voltage, bias current, each graded against GPON Class B+ limits (Rx −27 to −8 dBm, Tx 0 to +4 dBm)
- **OMCI management:** ONU state (O1–O5), registration, GPON serial, PLOAM, RDI, T-CONT allocations, GEM ports
- **Laser & optics:** optic vendor/part (e.g. ODI DFP-34X-2C2), FEC, FEC codewords, BIP errors, LOS/LOF/LOM/SF/SD alarms
- **SFP host interface & traffic:** the stick's SFP link into your switch or router (speed/duplex), MAC, packets/bytes/errors/drops
- **System:** model, firmware, kernel, CPU load, uptime
- **History:** charts of Rx/Tx power, temperature and bias (one sample a minute, last 24 h, kept in RAM)
- **OMCI entities:** Ethernet UNI, VLAN filters, extended VLAN tagging rules, VEIP
- **Reboot button** (asks for confirmation; the fibre link drops for about a minute)

> **Traffic counters** reset periodically on the stick (most likely the GPON
> 15-minute performance-monitoring cycle), so they show the current counting
> period, not totals since boot.

## Upgrade and uninstall
**Upgrade:** run the installer again. Your settings are kept.

**Uninstall:**
```sh
wget -qO /tmp/uninstall.sh https://raw.githubusercontent.com/JaGPR/luci-app-hsgq-ddm/main/uninstall.sh && sh /tmp/uninstall.sh
```
Run it as `KEEP_CONFIG=1 sh /tmp/uninstall.sh` to keep `/etc/config/hsgq_ddm`.

## Troubleshooting

| Symptom | Fix |
|---|---|
| Menu entry missing after install | Log out and back in to LuCI, then press Ctrl+F5 |
| "Not configured" | Set address, username and password in Settings |
| "Unable to connect or authenticate" | `ping <stick IP>` from the router. Check the login works with `telnet <stick IP>`, and that the timeout is ≥ 15 s |
| Works sometimes, then times out | The stick allows only a few telnet sessions. Close other telnet sessions and extra dashboard tabs |
| Values look stale / old | The backend refuses to show data older than 45 s as live. Check the stick is reachable |
| Optical class shows "assumed" | Normal for the ODI optic: it doesn't report its class. Set it in Settings (B+ for standard GPON) |

Diagnostics from the router shell:
```sh
ubus call hsgq_ddm test_connection     # login test
ubus call hsgq_ddm get_status          # full telemetry JSON
logread | grep -i hsgq                 # service messages
```

## Security notes
- The password is stored in `/etc/config/hsgq_ddm` (mode `600`, root only), the same way OpenWrt stores other credentials.
- Telnet is unencrypted. Keep the stick's management address on a link only the router can reach. Never expose it to the internet.
- The page is only available to LuCI users with the `luci-app-hsgq-ddm` permission.

## How it works
A small rpcd backend (`/usr/libexec/rpcd/hsgq_ddm`, POSIX shell) opens one
telnet session with BusyBox `nc`, logs in with paced input (the stick's Linux
`login` can drop input typed too early), and runs Realtek `diag` commands one
at a time. An awk parser turns the output into JSON for the LuCI view. Sessions
are serialised with a lock and cached, so several open tabs never pile up telnet
logins. Values that couldn't be read are shown as `--`, never as a guessed number.
A background service records one history sample per minute.

No compiled code, so one package works on every router architecture.

## Building a package from source
With an OpenWrt buildroot or SDK:
```sh
git clone https://github.com/JaGPR/luci-app-hsgq-ddm package/luci-app-hsgq-ddm
make package/luci-app-hsgq-ddm/compile V=s
```
The package is `PKGARCH:=all`.

## License
Apache License 2.0, see [LICENSE](LICENSE).
Based on [luci-app-vsol-ddm](https://github.com/AliLostInTheDark/luci-app-vsol-ddm) (Apache-2.0); see [NOTICE](NOTICE).
Not affiliated with HSGQ, ODI, VSOL or OpenWrt.
