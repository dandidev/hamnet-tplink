# HAMNET web UI

A minimal, LuCI-free web interface for a HAMNET client router (built and
tested on a TP-Link TL-WR841N / OpenWrt 19.07.10, ath79/tiny, 4 MB flash).
It is split into two packages so the framework stays region-agnostic and the
HAMNET/HU specifics live in an add-on.

| Package | Role |
|---|---|
| `web-hamnet-core` | Framework: uhttpd HTTP Basic Auth, a menu system, shared rendering helpers, base pages, and a reboot action. Knows nothing about Wi-Fi or PPPoE. |
| `web-hamnet-hu` | Region-specific pages: a guided wizard (scan → Wi-Fi connect → PPPoE) using the HAMNET 5 MHz channel plan, plus a live status / edit page. Adds a `HAMNET` entry to the menu. |

The interface is intentionally tiny (pure shell CGI served by `uhttpd`, no
Lua), which is why LuCI is not used: on a 4 MB device the size difference is
decisive.

## Dependencies

- `web-hamnet-core`: `uhttpd` (provides CGI; the package depends on it).
- `web-hamnet-hu`: `web-hamnet-core`, `iw` (scan + link status). The status
  endpoints also use `ubus` and `jsonfilter`, which are part of the base
  system on a normal image.
- PPPoE requires a netifd protocol handler in the image (`ppp-mod-pppoe`,
  which provides `/lib/netifd/proto/pppoe.sh`). Make sure it is selected.

## Layout

```
package/
├── web-hamnet-core/
│   ├── Makefile
│   └── files/
│       ├── etc/hamnet/menu.d/{00-home,90-system}   # menu fragments
│       ├── etc/uci-defaults/90-hamnet-web          # uhttpd auth + LAN bind
│       ├── usr/lib/hamnet/lib.sh                    # shared shell helpers
│       └── www/
│           ├── cgi-bin/hamnet                       # core CGI (home/system/reboot)
│           ├── hamnet/style.css                     # shared stylesheet
│           └── index.html                           # redirect to the CGI
└── web-hamnet-hu/
    ├── Makefile
    └── files/
        ├── etc/hamnet/menu.d/30-hamnet              # "HAMNET" menu entry
        └── www/cgi-bin/hamnet-hu                    # the wizard + status page
```

Menu fragments are single lines (`Label|/cgi-bin/target`); each package drops
its own, so modules self-register without the core knowing about them.

## Building into the firmware

These are in-tree packages. The build copies them into the OpenWrt tree
**before** `make defconfig`, then they are enabled in the device `.config`.

1. Place this `package/` directory in the repository (next to `patches/`).
2. Have the build copy them into the OpenWrt tree (the `packages` target in
   the top-level Makefile does this):

   ```sh
   cp -r package/web-hamnet-core openwrt/package/web-hamnet-core
   cp -r package/web-hamnet-hu   openwrt/package/web-hamnet-hu
   ```

3. Enable them in the device config (e.g. `openwrt-tplink_tl-wr841-v11.config`):

   ```
   CONFIG_PACKAGE_uhttpd=y
   CONFIG_PACKAGE_web-hamnet-core=y
   CONFIG_PACKAGE_web-hamnet-hu=y
   ```

4. Build as usual. To build a single package: `make package/web-hamnet-hu/compile`.

After flashing, verify: `grep web-hamnet openwrt/.config` should show `=y`, and
the `.ipk` files should appear under `bin/targets/ath79/tiny/`.

## Access and authentication

- Open `http://<router-lan-ip>/` (default `http://192.168.1.1/`); it redirects
  to the control panel.
- Protected by uhttpd HTTP Basic Auth, reusing the **root** account
  (`/etc/httpd.conf`, entry `…:root:$p$root`).
- **You must set a root password** (`passwd`) — with an empty root password the
  Basic Auth is effectively open.
- The `uci-defaults` script binds uhttpd to the LAN address. Note the topology
  caveat below: in AP-mode topologies the HAMNET clients share the LAN bridge,
  so the bind alone does not isolate the UI — the password is the real
  protection. (This build is client-only, so that case does not apply here.)
- Basic Auth over plain HTTP sends credentials base64-encoded; acceptable on a
  LAN-only bind. Add TLS (`uhttpd` + `px5g`) if you expose it more widely.

## Using the interface

The `HAMNET` menu opens the **status / edit page** (the daily view):

- Live Wi-Fi and PPPoE status (auto-refreshed every 5 s).
- PPPoE username/password can be edited inline (leave the password blank to
  keep the current one); saving re-dials and the status updates in place.
- Wi-Fi parameters are changed via the **setup wizard**, because changing them
  drops the link.

The **wizard** is three gated steps:

1. **Scan** — pick a frequency (HAMNET channel plan) and bandwidth, scan that
   frequency, and choose a result. The chosen bandwidth and frequency are
   carried forward.
2. **Wi-Fi** — associate at L2 only (`network.wwan` `proto none`); the page
   polls `iw link` and shows whether the radio associated.
3. **PPPoE** — switch `wwan` to `proto pppoe` with the credentials, re-dial,
   and poll `ubus` until an IPv4 address is assigned.

If a step fails you can retry without redoing the earlier ones.

## Important notes and caveats

- **Bandwidth: only 5 MHz is tested.** 10 and 20 MHz are offered but labelled
  experimental.
- **Width source.** On this patched quarter-rate driver `iw … info` reports an
  unreliable `width`, so the UI takes the bandwidth from UCI `chanbw`, not from
  `iw`. Frequency, by contrast, is read live (in MHz) from `iw link`.
- **Client (STA) only.** AP / node operation is intentionally out of scope and
  should be configured from the command line.
- **A scan is disruptive.** Targeted scanning retunes the radio to the chosen
  bandwidth/frequency, which drops the current uplink for the duration. The UI
  asks for confirmation. Administer over the wired LAN so the UI itself stays
  reachable.
- **`iw` vs the supplicant.** While `wpa_supplicant` runs in STA mode,
  `iw … scan` can occasionally conflict with it. If scanning misbehaves, a
  `wpa_cli` based scan is a drop-in alternative.
- **NAT / routing.** With a single HAMNET IP on the PPPoE link, LAN clients
  reach HAMNET via masquerade (NAT) on the router — the default OpenWrt
  firewall already does this (`wan` zone `masq=1`). A NAT-free setup (real
  HAMNET addresses on the LAN) requires a routed subnet assigned by the node
  operator and is a one-time, command-line/topology decision, not handled by
  this UI.

## Tunables

- Settling delay before a scan: `sleep 4` in the scan handler (raise it if the
  driver is slow to come back and scans return empty).
- Association poll window: `tries = 8` (× 2 s) in the Wi-Fi connecting page.
- PPPoE dial poll window: `tries = 12` (× 2 s) in the PPPoE connecting page.

## Adapting to another region

`web-hamnet-core` is region-agnostic. To support a different country/ISP,
write a sibling package (e.g. `web-hamnet-de`) modelled on `web-hamnet-hu`:
adjust the frequency table (`HAM_FREQS`), the allowed widths (`HAM_BWS`), the
interface names (`wireless.sta` / `network.wwan` / `radio0` / `wlan0`), and the
WAN protocol if it is not PPPoE.
