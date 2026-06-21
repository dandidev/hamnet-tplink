# HAMNET patches — dev workflow (quilt)

For developers editing the patches with quilt. The patch files + `series`
live under `patches/` (mirroring the OpenWrt source tree); the Makefile's
`patch` target copies them into each package's own `patches/` at build time.

Background: https://openwrt.org/docs/guide-developer/toolchain/use-patches-with-buildsystem

## One-time setup: ~/.quiltrc

```sh
QUILT_DIFF_ARGS="--no-timestamps --no-index -p ab --color=auto"
QUILT_REFRESH_ARGS="--no-timestamps --no-index -p ab"
```

## General pattern

Each package is edited the same way:

1. `make clean-patches` — remove copied patches so the source can be prepared clean
2. in the container (`make shell`): `make package/<PKG>/{clean,prepare} V=s` (NO `QUILT=1`)
3. on the host: `cd` into the build_dir source, `export QUILT_PATCHES=...`
4. `quilt push <patch>` up to the one you want to edit
5. `quilt edit <file>` then `quilt refresh`
6. `quilt pop -a` — never leave patches applied

### Creating a NEW patch

```sh
# push up to the patch BEFORE the new one's series position, then:
quilt new <subdir/NNN-name>.patch     # lands after current top in series
quilt edit <path/to/source/file>      # registers + opens the file
quilt refresh
quilt pop -a
```
Then add the new patch to its `series` file and to `PKG_PATCHES` in the Makefile.

---

## kernel: mac80211 / ath  (backports source)

QUILT_PATCHES: `/opt/ham/hamnet-tplink/patches/package/kernel/mac80211/ath`
Source dir:    `openwrt/build_dir/target-mips_24kc_musl/linux-ath79_tiny/backports-4.19.237-1`

```sh
make clean-patches
make shell
  cd /work/openwrt
  make package/kernel/mac80211/{clean,prepare} V=s
  exit
cd openwrt/build_dir/target-mips_24kc_musl/linux-ath79_tiny/backports-4.19.237-1
export QUILT_PATCHES=/opt/ham/hamnet-tplink/patches/package/kernel/mac80211/ath
```

Patches in this stack (series order), with the file each one touches:

| series entry | modifies |
|---|---|
| `010-regd-hamnet.patch` | `drivers/net/wireless/ath/regd.c` |
| `020-ath-num-channels.patch` | `drivers/net/wireless/ath/ath9k/hw.h` |
| `030-chantable-hamnet.patch` | `drivers/net/wireless/ath/ath9k/common-init.c` |
| `035-util-hamnet-chan-map.patch` | `net/wireless/util.c` |
| `040-common-hamnet-quarter.patch` | `drivers/net/wireless/ath/ath9k/common.c` |
| `050-scan-hamnet-channel.patch` | `net/wireless/scan.c` |

Edit e.g. 030 (chantable) or 040 (quarter-rate):
```sh
quilt push 030-chantable-hamnet.patch
quilt edit drivers/net/wireless/ath/ath9k/common-init.c
quilt refresh
quilt pop -a

quilt push 040-common-hamnet-quarter.patch
quilt edit drivers/net/wireless/ath/ath9k/common.c
quilt refresh
quilt pop -a
```

---

## network: hostapd / wpa_supplicant

QUILT_PATCHES: `/opt/ham/hamnet-tplink/patches/package/network/services/hostapd`
Source dir:    `openwrt/build_dir/target-mips_24kc_musl/hostapd-wpad-mini/hostapd-2019-08-08-ca8c2bd2`

```sh
make clean-patches
make shell
  cd /work/openwrt
  make package/network/services/hostapd/{clean,prepare} V=s
  exit
cd openwrt/build_dir/target-mips_24kc_musl/hostapd-wpad-mini/hostapd-2019-08-08-ca8c2bd2
export QUILT_PATCHES=/opt/ham/hamnet-tplink/patches/package/network/services/hostapd
```

| series entry | modifies |
|---|---|
| `010-hostapd-freq-range-expansion.patch` | `src/common/ieee802_11_common.c` |
| `020-supplicant-hamnet-5mhz-connect.patch` | `src/drivers/driver_nl80211.c` |

Edit e.g. 010 (hostapd) or 020 (supplicant):
```sh
quilt push 010-hostapd-freq-range-expansion.patch
quilt edit src/common/ieee802_11_common.c
quilt refresh
quilt pop -a

quilt push 020-supplicant-hamnet-5mhz-connect.patch
quilt edit src/drivers/driver_nl80211.c
quilt refresh
quilt pop -a
```

---

## network: iw

QUILT_PATCHES: `/opt/ham/hamnet-tplink/patches/package/network/utils/iw`
Source dir:    `openwrt/build_dir/target-mips_24kc_musl/iw-tiny/iw-5.0.1`

```sh
make clean-patches
make shell
  cd /work/openwrt
  make package/network/utils/iw/{clean,prepare} V=s
  exit
cd openwrt/build_dir/target-mips_24kc_musl/iw-tiny/iw-5.0.1
export QUILT_PATCHES=/opt/ham/hamnet-tplink/patches/package/network/utils/iw
```

| series entry | modifies |
|---|---|
| `010-iw-hamnet-chan-map.patch` | `util.c` (frequency<->channel mapping) |

```sh
quilt push 010-iw-hamnet-chan-map.patch
quilt edit util.c
quilt refresh
quilt pop -a
```

---

## firmware: wireless-regdb

QUILT_PATCHES: `/opt/ham/hamnet-tplink/patches/package/firmware/wireless-regdb`
Source dir:    `openwrt/build_dir/target-mips_24kc_musl/wireless-regdb-2021.08.28`

```sh
make clean-patches
make shell
  cd /work/openwrt
  make package/firmware/wireless-regdb/{clean,prepare} V=s
  exit
cd openwrt/build_dir/target-mips_24kc_musl/wireless-regdb-2021.08.28
export QUILT_PATCHES=/opt/ham/hamnet-tplink/patches/package/firmware/wireless-regdb
```

| series entry | modifies |
|---|---|
| `001-db-hamnet.patch` | `db.txt` |

```sh
quilt push 001-db-hamnet.patch
quilt edit db.txt
quilt refresh
quilt pop -a
```

---

## Direct tree patches (NOT quilt)

`005-channel-context.patch` and `007-mac80211-sta-freq.patch` are applied
directly to the OpenWrt tree by the Makefile's `patch` target with
`patch -p1 -N --forward`, not through quilt. Edit these patch files by hand;
there is no quilt push/refresh cycle for them.

Note: `-N --forward || true` swallows errors silently — after editing, do a
clean build and verify the change actually landed (it can fail quietly).

---

## Helper (optional)

```sh
qp() { export QUILT_PATCHES=/opt/ham/hamnet-tplink/patches/$1; }
# qp package/kernel/mac80211/ath
# qp package/network/services/hostapd
# qp package/network/utils/iw
```