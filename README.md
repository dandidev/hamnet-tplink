# HAMNET OpenWrt Firmware — TP-Link TL-WR841N

Custom OpenWrt firmware that unlocks the 2312–2407 MHz HAMNET (13cm amateur
radio) band on TP-Link TL-WR841N routers, **alongside** the normal 2.4 GHz
channels. The HAMNET channels use 5 MHz quarter-rate operation and a dedicated,
collision-free channel numbering (100–119), so the standard 2.4 GHz channels
(1–14) remain fully available.

> **Legal notice:** Use of the 2300–2400 MHz band requires a valid amateur
> radio license. Operate on your own responsibility, within your license terms.

---

## Supported devices

| Device           | SoC     | WiFi   | OpenWrt version |
|------------------|---------|--------|-----------------|
| TL-WR841N/ND v7  | AR7241  | AR9287 | 19.07.10        |
| TL-WR841N/ND v9  | AR7241  | AR9287 | 19.07.10        |
| TL-WR841N/ND v11 | QCA9533 | AR9531 | 19.07.10        |

All devices have 4 MB flash and 32 MB RAM.

> **Note:** The v11 config (`openwrt-tplink_tl-wr841-v11.config`) includes the
> PPPoE server (`rp-pppoe-server`) for test AP use. The v9 config is client-only.

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

**SSH config** for OpenWrt legacy algorithms:

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

`iw phy phy0 info` lists the HAMNET channels (100–119) above the regular
2.4 GHz channels (1–14).

> **Known cosmetic limitation:** `iw` reports the HAMNET channel width as
> "20 MHz" instead of 5 MHz. This is a display issue only — the radio actually
> operates at 5 MHz quarter-rate (confirmed by the `CHANNEL_QUARTER` flag in
> dmesg and by real traffic on the band).

---

## Channels

HAMNET channels use a dedicated positive numbering (100–119) so they never
collide with the standard 2.4 GHz channels. Both ranges are usable.

**HAMNET 13cm band** — formula: `frequency = 2312 + (channel - 100) * 5`

| Channel | Frequency | | Channel | Frequency |
|---------|-----------|-|---------|-----------|
| 100     | 2312 MHz  | | 110     | 2362 MHz  |
| 101     | 2317 MHz  | | 111     | 2367 MHz  |
| 102     | 2322 MHz  | | 112     | 2372 MHz  |
| 103     | 2327 MHz  | | 113     | 2377 MHz  |
| 104     | 2332 MHz  | | 114     | 2382 MHz  |
| 105     | 2337 MHz  | | 115     | 2387 MHz  |
| 106     | 2342 MHz  | | 116     | 2392 MHz  |
| 107     | 2347 MHz  | | 117     | 2397 MHz  |
| 108     | 2352 MHz  | | 118     | 2402 MHz  |
| 109     | 2357 MHz  | | 119     | 2407 MHz  |

**Standard 2.4 GHz band** — the regular channels 1–14 (2412–2484 MHz) remain
fully available in parallel, with their usual numbering and frequencies unchanged.

> The AP frequency is set via the channel number — there is no direct
> `frequency` UCI option. Pick the channel whose frequency you want
> (e.g. `channel '110'` for 2362 MHz). The chantable mapping is defined in
> `030-chantable-hamnet.patch`; see [patch-guide.md](patch-guide.md).

---

### Client mode

The client connects to a HAMNET AP and authenticates via PPPoE using a callsign
and password. This is the standard way to join the HAMNET network.

**Step 1 — wireless:**

```sh
# Radio — HAMNET 5 MHz quarter-channel, fixed channel
uci set wireless.radio0.channel='110'      # 2362 MHz — set to the AP's channel (see table); channel = (MHz - 2312) / 5 + 100
uci set wireless.radio0.chanbw='5'         # 5 MHz channel width, required by HAMNET
uci set wireless.radio0.country='00'       # patched regdomain that unlocks the 2312-2407 band
uci set wireless.radio0.htmode='NOHT'      # no HT, required for 5 MHz quarter-channel mode
uci set wireless.radio0.disabled='0'

# Remove the stock AP — one radio, one VAP, otherwise HOSTAPD_START_FAILED
uci delete wireless.default_radio0

# STA (client) connecting to the HAMNET AP
uci set wireless.sta=wifi-iface
uci set wireless.sta.device='radio0'
uci set wireless.sta.mode='sta'            # station (client) mode
uci set wireless.sta.ssid='HAMNET-DEMO'    # the AP's SSID
uci set wireless.sta.encryption='none'     # no encryption, required by amateur radio regulations
uci set wireless.sta.network='wwan'        # PPPoE will run on top of this interface
uci commit wireless

wifi
```

**Step 2 — PPPoE interface:**

Authentication uses CHAP with your callsign as the username. The connection is
established over the wireless L2 link — PPPoE runs directly on top of the radio,
no IP is needed underneath it.

```sh
# PPPoE on the STA's logical network (NO device/ifname line!)
uci set network.wwan=interface
uci set network.wwan.proto='pppoe'
uci set network.wwan.username='YOUR_REAL_USERNAME'
uci set network.wwan.password='YOUR_REAL_PASSWORD'
uci set network.wwan.ipv6='0'
uci commit network

ubus call network reload
ifup wwan
```

**Verify the connection:**

```sh
iw dev wlan0 link          # check wireless association (should show the AP's freq)
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

Used for infrastructure nodes or local testing. The AP bridges wireless clients
onto the LAN. On the real HAMNET, a PPPoE concentrator sits behind the AP —
clients authenticate through it, not through the AP itself.

```sh
uci set wireless.radio0.channel='110'       # 2362 MHz — standard Hungarian HAMNET frequency
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

> Set the **same channel on both the AP and the client** (e.g. `110`) for a
> deterministic link. Verify with `iw dev wlan0 info` on each side — the
> frequency in parentheses (e.g. `2362 MHz`) is the truth; the channel number
> should read `110` on both.

---

### PPPoE test server (v11 only)

The v11 firmware includes `rp-pppoe-server` for local testing. This lets you
simulate the full HAMNET authentication flow without a real HAMNET AP — the
router acts as both the AP and the PPPoE concentrator.

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
