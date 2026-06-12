# HAMNET OpenWrt Firmware — TP-Link TL-WR841N

Custom OpenWrt firmware that unlocks the 2300–2400 MHz HAMNET (13cm amateur radio) band on TP-Link TL-WR841N routers.

> **Legal notice:** Use of the 2300–2400 MHz band requires a valid amateur radio license.

---

## Supported devices

| Device | SoC | WiFi | OpenWrt version |
|---|---|---|---|
| TL-WR841N/ND v11 | QCA9533 | AR9531 | 19.07.10 |
| TL-WR841N/ND v7 | AR7241 | AR9287 | 19.07.10 |

Both devices have 4 MB flash and 32 MB RAM.

---

## What the patches do

**001 — wireless-regdb db.txt**
Adds `(2300 - 2400 @ 20), (20)` to the `country 00` world regulatory domain. TX is allowed.

**002 — ath/regd.c**
Forces the ath driver to use `WOR0_WORLD` (0x60) when the EEPROM contains the default country code. Adds the `ATH9K_2GHZ_HAMNET` macro and patches `ath_regd_init_wiphy` to apply the HAMNET channel set to the radio.

**003 — ath9k/common-init.c**
Extends `ath9k_2ghz_chantable[]` with 20 HAMNET channels (2312–2407 MHz, 5 MHz steps).

**004 — ath9k/hw.h**
Updates `ATH9K_NUM_CHANNELS` to match the expanded channel table.

**005 — package/kernel/mac80211/Makefile**
Adds `ATH9K_CHANNEL_CONTEXT` to enable 5 MHz channel width support.

---

## Build environment

- Docker base image: `ubuntu:22.04`
- Kernel: `4.14.275`, Backports: `4.19.237`, wireless-regdb: `2021.08.28`

---

## Project structure

```
hamnet-tplink/
├── Dockerfile
├── Makefile
├── openwrt-tplink_tl-wr841-v11.config
├── openwrt-tplink_tl-wr841-v7.config
├── patches/
│   ├── 001-db-hamnet.patch
│   ├── 002-regd-hamnet.patch
│   ├── 003-chantable-hamnet.patch
│   ├── 004-numchannels-hamnet.patch
│   └── 005-channel-context.patch
└── openwrt/
```

---

## Quick start

```sh
# Set PROFILE in Makefile, then:
make image
make setup
make patch
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

## Scanning

```sh
iw phy phy0 interface add mon0 type monitor
ip link set mon0 up
iw dev mon0 set freq 2362
iw dev mon0 survey dump | grep -A5 "2362"
tcpdump -i mon0 -e -s 200 type mgt subtype beacon
```

See `connection-guide.md` for full connection instructions.

See `patch-guide.md` for patch creation workflow.