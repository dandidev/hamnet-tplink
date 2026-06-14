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

> The AP frequency is set via the channel number — there is no direct
> `frequency` UCI option. Pick the channel whose frequency you want
> (e.g. `channel '11'` for 2362 MHz).

### AP mode

```sh
uci set wireless.radio0.channel='11'        # 2362 MHz
uci set wireless.radio0.chanbw='5'
uci set wireless.radio0.country='00'
uci set wireless.radio0.htmode='NOHT'
uci set wireless.radio0.disabled='0'

uci set wireless.default_radio0.mode='ap'
uci set wireless.default_radio0.ssid='HAMNET-DEMO'
uci set wireless.default_radio0.encryption='none'
uci set wireless.default_radio0.network='lan'

uci commit wireless
wifi
```

### Client mode

```sh
uci set wireless.radio0.channel='auto'
uci set wireless.radio0.chanbw='5'
uci set wireless.radio0.country='00'
uci set wireless.radio0.disabled='0'

uci set wireless.sta.mode='sta'
uci set wireless.sta.ssid='HAMNET-DEMO'
uci set wireless.sta.encryption='none'
uci set wireless.sta.network='wwan'
uci set wireless.sta.freq_list='2312 2317 2322 2327 2332 2337 2342 2347 2352 2357 2362 2367 2372 2377'

uci commit wireless
wifi
```

Verify the connection on the client:

```sh
iw dev wlan0 link
```

Expected output:

```
Connected to c4:6e:1f:b2:b3:ac (on wlan0)
        SSID: HAMNET-DEMO
        freq: 2362
        tx bitrate: 1.0 MBit/s
```

See `connection-guide.md` for full connection instructions.

See `patch-guide.md` for patch creation workflow.