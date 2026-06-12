# HAMNET OpenWrt Firmware — TP-Link TL-WR841N v11

Custom OpenWrt 22.03.7 firmware that unlocks the 2300–2400 MHz HAMNET (13cm amateur radio) band on the TP-Link TL-WR841N v11 router.

> **Legal notice:** Use of the 2300–2400 MHz band requires a valid amateur radio license. This firmware is intended for licensed amateur radio operators only.

---

## Hardware

| | |
|---|---|
| Device | TP-Link TL-WR841N/ND v11 |
| SoC | Qualcomm Atheros QCA9533 |
| WiFi | AR9531 (ath9k driver) |
| Flash | 4 MB |
| RAM | 32 MB |

---

## What the patches do

Four patches are applied to the OpenWrt source tree at build time:

**001 — wireless-regdb db.txt**
Adds `(2300 - 2400 @ 20), (20), NO-IR` to the `country 00` world regulatory domain in the wireless regulatory database.

**002 — ath/regd.c**
Forces the ath driver to use the `WOR0_WORLD` (0x60) regulatory domain when the EEPROM contains the default country code. Also adds the `ATH9K_2GHZ_HAMNET` macro covering 2300–2400 MHz and inserts it into `ATH9K_2GHZ_ALL`. Modifies `ath_regd_init_wiphy` so that world regulatory domains pass through to `wiphy_apply_custom_regulatory`, enabling the HAMNET channel set to be applied to the radio.

**003 — ath9k/common-init.c**
Extends `ath9k_2ghz_chantable[]` with 20 HAMNET channels (2312–2407 MHz in 5 MHz steps) prepended before the standard 2412–2484 MHz channels.

**004 — ath9k/hw.h**
Updates `ATH9K_NUM_CHANNELS` to match the expanded channel table (original 38, new value depends on total channels added).

---

## Build environment

- Docker base image: `ubuntu:22.04`
- OpenWrt version: `v22.03.7`
- Kernel: `4.14.275`
- Backports: `4.19.237` (ath9k driver source)
- wireless-regdb: `2021.08.28`

---

## Project structure

```
hamnet-tplink/
├── Dockerfile
├── Makefile
├── openwrt.config          # seed config
├── patches/
│   ├── 001-db-hamnet.patch
│   ├── 002-regd-hamnet.patch
│   ├── 003-chantable-hamnet.patch
│   └── 004-numchannels-hamnet.patch
└── openwrt/                # git clone (v22.03.7)
```

---

## Quick start

```sh
# 1. Build Docker image
make image

# 2. Clone OpenWrt and apply config
make setup

# 3. Apply HAMNET patches
make patch

# 4. Build firmware
make build
```

Output files are in `openwrt/bin/targets/ath79/tiny/`.

---

## Flashing

SSH uses legacy algorithms on OpenWrt 22.03.x. Add this to `~/.ssh/config`:

```
Host 192.168.1.1
    HostKeyAlgorithms ssh-rsa
    PubkeyAcceptedKeyTypes ssh-rsa
    User root
```

**From stock TP-Link firmware** — use `squashfs-factory.bin` via the web UI at `http://192.168.0.1`.

**From existing OpenWrt** — transfer via HTTP and sysupgrade:

```sh
# On the host machine
cd openwrt/bin/targets/ath79/tiny/
python3 -m http.server 8080

# On the router
wget http://<HOST_IP>:8080/openwrt-ath79-tiny-tplink_tl-wr841-v11-squashfs-sysupgrade.bin -O /tmp/sysupgrade.bin
sysupgrade -v /tmp/sysupgrade.bin
```

**TFTP recovery** — rename to `wr841nv11_tp_recovery.bin`, serve from `192.168.0.86`, hold reset during power-on.

> *atftp*

> *https://openwrt.org/docs/guide-user/troubleshooting/tftpserver*

```shell
sudo cp openwrt/bin/targets/ar71xx/tiny/openwrt-ath79-tiny-tplink_tl-wr841-v11-squashfs-factory.bin /srv/atftp/wr841nv11_tp_recovery.bin
sudo chown -R nobody:nobody /srv/atftp
sudo chmod 644 /srv/atftp/wr841nv11_tp_recovery.bin

sudo ip addr flush dev enp2s0
sudo ip addr add 192.168.0.66/24 dev enp2s0
# sudo ip addr show enp2s0

sudo systemctl stop NetworkManager
sudo atftpd --daemon --user nobody --group nobody --no-fork --logfile - /srv/atftp
```

> *Set IP and connect*
```shell
sudo ip addr flush dev enp2s0
sudo ip addr add 192.168.1.10/24 dev enp2s0
# ssh root@192.168.1.1 -vvv
ssh -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedAlgorithms=+ssh-rsa -o ObscureKeystrokeTiming=no -o LogLevel=ERROR root@192.168.1.1 -vvv
```

---

## Verifying the patch

After boot, check the kernel log and regulatory state:

```sh
# Driver log — should show WOR0_WORLD and regdom_60_61_62
dmesg | grep -i "HAMNET\|ath:"

# Regulatory database — should show (2300 - 2400 @ 20)
iw reg get

# Hardware channel list — should start at 2312 MHz
iw phy phy0 info | grep "MHz"
```

Expected dmesg output:

```
ath: HAMNET: forcing WOR0_WORLD, current_rd=0x60 regdmn=0x60
ath: HAMNET: is_world_regd=1 regpair=0x60
ath: Country alpha2 being used: 00
ath: Regpair used: 0x60
ath: HAMNET: WORLD regd path taken
ath: HAMNET: regdom_60_61_62 selected!
```

---

## Scanning for HAMNET signals

```sh
# Create monitor interface
iw phy phy0 interface add mon0 type monitor
ip link set mon0 up

# Tune to HAMNET frequency (Hungarian network uses 2397 MHz)
iw dev mon0 set freq 2397

# Survey — non-zero busy/receive time indicates activity
iw dev mon0 survey dump | grep -A5 "2397"

# Capture frames (requires tcpdump-mini + libpcap1)
tcpdump -i mon0 -e -s 200 type mgt subtype beacon
```

---

## Patch creation reference

See `patch-guide.md` for the full workflow: locating source files in the build tree, creating `.orig` copies, editing, generating diffs, and fixing patch headers with `sed`.

---

## Known limitations

- **5 MHz channel width** is not supported by this driver build. HAMNET APs use 5 MHz channels; the router can receive but cannot associate as a client without this support.
- **no-IR flag** on HAMNET channels means the radio will not initiate transmissions by default. AP mode requires additional configuration.
- **4 MB flash** leaves very little space for additional packages. PPP, IPv6, and MAC80211 mesh are disabled in the default config to make room.