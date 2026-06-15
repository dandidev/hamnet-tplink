# HAMNET OpenWrt Firmware — TP-Link TL-WR841N

Custom OpenWrt firmware that unlocks the 2300–2400 MHz HAMNET (13cm amateur radio) band on TP-Link TL-WR841N routers.

> **Legal notice:** Use of the 2300–2400 MHz band requires a valid amateur radio license.

---

## Supported devices

| Device | SoC | WiFi | OpenWrt version |
|---|---|---|---|
| TL-WR841N/ND v7 | AR7241 | AR9287 | 19.07.10 |
| TL-WR841N/ND v9 | AR7241 | AR9287 | 19.07.10 |
| TL-WR841N/ND v11 | QCA9533 | AR9531 | 19.07.10 |

Both devices have 4 MB flash and 32 MB RAM.

> **Note:** The v11 config (`openwrt-tplink_tl-wr841-v11.config`) includes the PPPoE server (`rp-pppoe-server`) for test AP use. The v9 config is client-only.

## Build environment

- Docker base image: `ubuntu:22.04`
- Kernel: `4.14.275`, Backports: `4.19.237`, wireless-regdb: `2021.08.28`

---

## Quick start

```sh
# Set PROFILE in Makefile, then:
# make image
# make setup
# make patch

# Edit config - select cache dir and router type
# cp .env.example .env

make build
```

Output: `openwrt/bin/targets/ath79/tiny/`

---

## Flashing

**From stock firmware** — use `squashfs-factory.bin` via the web UI at `http://192.168.0.1`.

**From existing OpenWrt:**

```sh
# Host
cd openwrt/bin/targets/ath79/tiny/
python3 -m http.server 8080

# Router
wget http://<HOST_IP>:8080/openwrt-ath79-tiny-tplink_tl-wr841-<version>-squashfs-sysupgrade.bin \
    -O /tmp/sysupgrade.bin
sysupgrade -v /tmp/sysupgrade.bin
```

**SSH config** for OpenWrt 22.03.x legacy algorithms:

```
Host 192.168.1.1
    HostKeyAlgorithms ssh-rsa
    PubkeyAcceptedKeyTypes ssh-rsa
    User root
```

**TFTP recovery** — rename to `wr841nv11_tp_recovery.bin`, serve from `192.168.0.86`, hold reset during power-on.

---

## Verifying

```sh
dmesg | grep -i "HAMNET\|ath:"
iw reg get
iw phy phy0 info | grep "MHz"
```

Expected dmesg:

```
ath: HAMNET: forcing WOR0_WORLD, current_rd=0x60 regdmn=0x60
ath: HAMNET: is_world_regd=1 regpair=0x60
ath: Country alpha2 being used: 00
ath: Regpair used: 0x60
ath: HAMNET: WORLD regd path taken
ath: HAMNET: regdom_60_61_62 selected!
```

---

## Configuration

The HAMNET chantable uses a remapped channel↔frequency layout (see patch 003).
Channels are numbered 1–14 and map to 2312–2377 MHz in 5 MHz steps.
Formula: `frequency = 2312 + (channel - 1) * 5`

| Channel | Frequency |
|---|---|
| 1 | 2312 MHz |
| 2 | 2317 MHz |
| 3 | 2322 MHz |
| 4 | 2327 MHz |
| 5 | 2332 MHz |
| 6 | 2337 MHz |
| 7 | 2342 MHz |
| 8 | 2347 MHz |
| 9 | 2352 MHz |
| 10 | 2357 MHz |
| 11 | 2362 MHz |
| 12 | 2367 MHz |
| 13 | 2372 MHz |
| 14 | 2377 MHz |

> The AP frequency is set via the channel number — there is no direct `frequency` UCI option. Pick the channel whose frequency you want (e.g. `channel '11'` for 2362 MHz).

---

### Client mode

The client connects to a HAMNET AP and authenticates via PPPoE using a callsign and password. This is the standard way to join the HAMNET network.

**Step 1 — wireless:**

```sh
uci set wireless.radio0.channel='auto'   # scan all HAMNET frequencies
uci set wireless.radio0.chanbw='5'       # 5 MHz channel width, required by HAMNET
uci set wireless.radio0.country='00'     # world regulatory domain, unlocks amateur bands
uci set wireless.radio0.htmode='NOHT'    # no HT, compatible with 5 MHz quarter-channel mode
uci set wireless.radio0.disabled='0'

uci set wireless.sta=wifi-iface
uci set wireless.sta.device='radio0'
uci set wireless.sta.mode='sta'          # station (client) mode
uci set wireless.sta.ssid='HAMNET-DEMO'
uci set wireless.sta.encryption='none'   # no encryption — required by amateur radio regulations
uci set wireless.sta.network='wwan'      # bind to the wwan interface for PPPoE
uci set wireless.sta.freq_list='2312 2317 2322 2327 2332 2337 2342 2347 2352 2357 2362 2367 2372 2377'

uci commit wireless
wifi
```

**Step 2 — PPPoE interface:**

Authentication uses CHAP with your callsign as the username. The connection is established over the wireless L2 link — PPPoE runs directly on top of the radio, no IP is needed underneath it.

```sh
uci set network.wwan=interface
uci set network.wwan.device='wlan0'
uci set network.wwan.proto='pppoe'              # PPPoE over wireless L2
uci set network.wwan.username='<your callsign>'
uci set network.wwan.password='<password from hamnetradio.hu/portal>'
uci commit network
/etc/init.d/network restart
```

**Verify the connection:**

```sh
iw dev wlan0 link          # check wireless association
ip addr show pppoe-wwan    # should show a 44.x.x.x address
ping 44.168.1.1            # ping the PPPoE gateway
```

Expected output after successful connection:

```
1738: pppoe-wwan: <POINTOPOINT,MULTICAST,NOARP,UP,LOWER_UP> mtu 1492
      inet 44.168.1.100 peer 44.168.1.1/32 scope global pppoe-wwan
```

---

### AP mode

Used for infrastructure nodes or local testing. The AP bridges wireless clients onto the LAN. On the real HAMNET, a PPPoE concentrator sits behind the AP — clients authenticate through it, not through the AP itself.

```sh
uci set wireless.radio0.channel='11'        # 2362 MHz — standard Hungarian HAMNET frequency
uci set wireless.radio0.chanbw='5'          # 5 MHz channel width
uci set wireless.radio0.country='00'        # world regulatory domain
uci set wireless.radio0.htmode='NOHT'       # required for 5 MHz quarter-channel operation
uci set wireless.radio0.disabled='0'

uci set wireless.default_radio0.mode='ap'
uci set wireless.default_radio0.ssid='HAMNET-DEMO'
uci set wireless.default_radio0.encryption='none'   # no encryption on amateur radio
uci set wireless.default_radio0.network='lan'       # bridge to LAN/br-lan

uci commit wireless
wifi
```

---

### PPPoE test server (v11 only)

The v11 firmware includes `rp-pppoe-server` for local testing. This lets you simulate the full HAMNET authentication flow without a real HAMNET AP — the router acts as both the AP and the PPPoE concentrator.

**Setup:**

```sh
# Authentication credentials
printf 'NONE\t*\ttesztjelszo\t44.168.1.100\n' > /etc/ppp/chap-secrets

# PPP options — CHAP auth, no routing side-effects
cat > /etc/ppp/pppoe-server-options << 'EOF'
require-chap
nodefaultroute
noipdefault
lcp-echo-interval 10
lcp-echo-failure 3
mru 1492
mtu 1492
EOF
```

**Start the server:**

```sh
# -k  kernel mode — routes PPPoE frames directly through kmod-pppoe,
#     bypassing the userspace pty bridge which doesn't work on OpenWrt
# -I  interface to listen on (br-lan bridges wlan0 and eth0)
# -L  local (server) PPP endpoint address
# -R  start of client address pool
# -N  maximum concurrent sessions
pppoe-server -k -I br-lan -L 44.168.1.1 -R 44.168.1.100 -N 5 &
```

**Auto-start on boot:**

```sh
cat > /etc/init.d/pppoe-server << 'EOF'
#!/bin/sh /etc/rc.common
START=95

start() {
    pppoe-server -k -I br-lan -L 44.168.1.1 -R 44.168.1.100 -N 5 &
}

stop() {
    killall pppoe-server
}
EOF

chmod +x /etc/init.d/pppoe-server
/etc/init.d/pppoe-server enable
```

**Verify a client connected:**

```sh
logread | grep -E "authorized|pppoe-server"
# Expected: pppd[...]: peer from calling number XX:XX:XX authorized
#           pppd[...]: remote IP address 44.168.1.100
```

---

See `connection-guide.md` for full connection instructions.
See `patch-guide.md` for patch creation workflow.