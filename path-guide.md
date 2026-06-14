# HAMNET Patch Guide

This guide documents how each patch is created and regenerated. It reflects the
final, working state of the patch set (001–009).

## Patch creation methods

There are two categories of patches, each with its own source:

**Kernel source patches** (001 regdb, 002, 003, 006, 009) — the source files live
inside the downloaded source tarballs in `dl/`. The cleanest workflow is to
extract the original file from the tarball, edit a copy, and diff with **relative
paths** so no path rewriting is needed.

**OpenWrt package patches** (004 hostapd, 005 Makefile, 007 netifd, 008 supplicant)
— these modify files in the OpenWrt tree itself (`package/...`) or in the package
build dir. The original comes from the package source, not the backports tarball.

---

## Recommended workflow (tarball method)

This is the cleanest way to make a kernel source patch. Because you `cd` into the
extracted directory and diff relative paths, the resulting patch already has the
correct `a/` `b/` prefixes — no `sed` rewriting required.

```sh
# 1. Find the source tarball in dl/
ls dl/ | grep -i backport

# 2. Extract ONLY the file you need to a temp location
cd /tmp
tar xf /path/to/dl/backports-4.19.237-1.tar.xz \
    backports-4.19.237-1/net/wireless/scan.c

# 3. cd into the extracted tree and make the .orig copy THERE
cd /tmp/backports-4.19.237-1
cp net/wireless/scan.c net/wireless/scan.c.orig

# 4. Edit the working copy
vim net/wireless/scan.c

# 5. Diff with relative paths (note: run from the tree root)
diff -u net/wireless/scan.c.orig net/wireless/scan.c \
    > /path/to/project/patches/009-scan-hamnet-channel.patch
```

The key is **step 3**: make the `.orig` copy inside the extracted tree, and run
`diff` from the tree root using relative paths. The patch then applies cleanly
with `-p1`.

> The older build_dir method (copy to `/tmp`, diff absolute paths, then `sed` the
> paths to `a/` `b/`) still works, but requires manual path rewriting and is more
> error-prone. Prefer the tarball method above.

---

## 001 — wireless-regdb db.txt

Adds the HAMNET band to the world regulatory domain.

```sh
cd /tmp
tar xf /path/to/dl/wireless-regdb-2021.08.28.tar.xz \
    wireless-regdb-2021.08.28/db.txt
cd /tmp/wireless-regdb-2021.08.28
cp db.txt db.txt.orig

# Edit: add under `country 00:`
#   # HAMNET 13cm band
#   (2300 - 2400 @ 20), (20)
vim db.txt

diff -u db.txt.orig db.txt \
    > /path/to/project/patches/001-db-hamnet.patch
```

Installed into OpenWrt at:
`package/firmware/wireless-regdb/patches/001-db-hamnet.patch`

---

## 002 — ath/regd.c

Forces WOR0_WORLD (0x60) regulatory domain and adds the HAMNET reg rule.

```sh
cd /tmp
tar xf /path/to/dl/backports-4.19.237-1.tar.xz \
    backports-4.19.237-1/drivers/net/wireless/ath/regd.c
cd /tmp/backports-4.19.237-1
cp drivers/net/wireless/ath/regd.c drivers/net/wireless/ath/regd.c.orig

vim drivers/net/wireless/ath/regd.c

diff -u drivers/net/wireless/ath/regd.c.orig \
        drivers/net/wireless/ath/regd.c \
    > /path/to/project/patches/002-regd-hamnet.patch
```

Installed at: `package/kernel/mac80211/patches/ath/999-ath-hamnet-regd.patch`

---

## 003 — ath9k common-init.c (chantable)

Replaces the standard 2.4 GHz channel table with HAMNET frequencies
(2312–2377 MHz, 5 MHz steps).

```sh
cd /tmp
tar xf /path/to/dl/backports-4.19.237-1.tar.xz \
    backports-4.19.237-1/drivers/net/wireless/ath/ath9k/common-init.c
cd /tmp/backports-4.19.237-1
cp drivers/net/wireless/ath/ath9k/common-init.c \
   drivers/net/wireless/ath/ath9k/common-init.c.orig

vim drivers/net/wireless/ath/ath9k/common-init.c

diff -u drivers/net/wireless/ath/ath9k/common-init.c.orig \
        drivers/net/wireless/ath/ath9k/common-init.c \
    > /path/to/project/patches/003-chantable-hamnet.patch
```

Installed at: `package/kernel/mac80211/patches/ath/997-ath-hamnet-chantable.patch`

---

## 006 — ath9k common.c (quarter-rate force)

Forces CHANNEL_QUARTER (5 MHz) for any channel in 2312–2407 MHz, so scan and
connect both run in quarter-rate mode regardless of the nl80211 width.

```sh
cd /tmp
tar xf /path/to/dl/backports-4.19.237-1.tar.xz \
    backports-4.19.237-1/drivers/net/wireless/ath/ath9k/common.c
cd /tmp/backports-4.19.237-1
cp drivers/net/wireless/ath/ath9k/common.c \
   drivers/net/wireless/ath/ath9k/common.c.orig

# Edit: in ath9k_cmn_update_ichannel(), before `ichan->channelFlags = flags;`
#   if (ichan->channel >= 2312 && ichan->channel <= 2407) {
#       flags |= CHANNEL_QUARTER;
#       printk(KERN_DEBUG "ath9k: HAMNET: forced CHANNEL_QUARTER on %d MHz\n",
#              ichan->channel);
#   }
# NOTE: the braces { } are required, otherwise -Wmisleading-indentation
# becomes a fatal error under the kernel's -Werror.
vim drivers/net/wireless/ath/ath9k/common.c

diff -u drivers/net/wireless/ath/ath9k/common.c.orig \
        drivers/net/wireless/ath/ath9k/common.c \
    > /path/to/project/patches/006-common-hamnet-quarter.patch
```

Installed at: `package/kernel/mac80211/patches/ath/996-ath-hamnet-quarter.patch`

---

## 009 — net/wireless/scan.c (receive-side beacon fix)

In `cfg80211_get_bss_channel`, returns the driver-reported RX channel for
5/10 MHz scan widths instead of trusting the DS Parameter Set channel number
(which the standard formula misinterprets for the HAMNET layout). Place the
check **after** the `channel_number < 0` test but **before** the
`ieee80211_channel_to_frequency()` call.

```sh
cd /tmp
tar xf /path/to/dl/backports-4.19.237-1.tar.xz \
    backports-4.19.237-1/net/wireless/scan.c
cd /tmp/backports-4.19.237-1
cp net/wireless/scan.c net/wireless/scan.c.orig

# Edit: add before the freq = ieee80211_channel_to_frequency(...) line
#   /* HAMNET / quarter- and half-rate channels: the channel number to
#    * frequency mapping is not unambiguous, so rely on the driver-reported
#    * RX channel instead of the DS Parameter Set channel number. */
#   if (scan_width == NL80211_BSS_CHAN_WIDTH_5 ||
#       scan_width == NL80211_BSS_CHAN_WIDTH_10)
#       return channel;
vim net/wireless/scan.c

diff -u net/wireless/scan.c.orig net/wireless/scan.c \
    > /path/to/project/patches/009-scan-hamnet-channel.patch
```

Installed at: `package/kernel/mac80211/patches/ath/995-ath-hamnet-scan-channel.patch`

---

## 004 — hostapd freq-to-chan (ieee802_11_common.c)

AP-side: maps HAMNET frequencies (2312–2377 MHz) to operating class 81 and the
correct channel number. This is a hostapd package source, not in the backports
tarball.

```sh
# Source comes from the hostapd package build dir or its source tarball.
cd /tmp
tar xf /path/to/dl/hostapd-*.tar.* src/common/ieee802_11_common.c
# (adjust the extracted path to match the tarball layout)
cp src/common/ieee802_11_common.c src/common/ieee802_11_common.c.orig

# Edit: add the HAMNET branch (2312..2377 -> op_class 81, channel 1..14)
vim src/common/ieee802_11_common.c

diff -u src/common/ieee802_11_common.c.orig \
        src/common/ieee802_11_common.c \
    > /path/to/project/patches/004-hostapd-freq-to-chan.patch
```

Installed at:
`package/network/services/hostapd/patches/999-hostapd-freq-to-chan.patch`

---

## 008 — wpa_supplicant driver_nl80211.c (connect-side 5 MHz)

Client-side: adds NL80211_CHAN_WIDTH_5 to the association/connect message for
HAMNET frequencies. Same hostapd/wpa_supplicant package source.

```sh
cd /tmp
tar xf /path/to/dl/hostapd-*.tar.* src/drivers/driver_nl80211.c
cp src/drivers/driver_nl80211.c src/drivers/driver_nl80211.c.orig

# Edit: in the association path, for freq 2312..2377 add
#   nla_put_u32(msg, NL80211_ATTR_CHANNEL_WIDTH, NL80211_CHAN_WIDTH_5)
#   nla_put_u32(msg, NL80211_ATTR_CENTER_FREQ1, params->freq.freq)
vim src/drivers/driver_nl80211.c

diff -u src/drivers/driver_nl80211.c.orig \
        src/drivers/driver_nl80211.c \
    > /path/to/project/patches/008-supplicant-hamnet-5mhz-connect.patch
```

Installed at:
`package/network/services/hostapd/patches/998-supplicant-hamnet-5mhz-connect.patch`

---

## 005 — mac80211 Makefile (ATH9K_CHANNEL_CONTEXT)

Modifies the mac80211 package Makefile directly (in the OpenWrt tree), not a
kernel source file. Applied via `patch -d`, not copied into `patches/ath/`.

```sh
cp openwrt/package/kernel/mac80211/Makefile /tmp/mac80211.orig
cp /tmp/mac80211.orig /tmp/mac80211

# Edit: append ATH9K_CHANNEL_CONTEXT to the config-y list
vim /tmp/mac80211

diff -u /tmp/mac80211.orig /tmp/mac80211 \
    > /path/to/project/patches/005-channel-context.patch
sed -i 's|/tmp/mac80211.orig|a/package/kernel/mac80211/Makefile|' \
    /path/to/project/patches/005-channel-context.patch
sed -i 's|/tmp/mac80211|b/package/kernel/mac80211/Makefile|' \
    /path/to/project/patches/005-channel-context.patch
```

Applied in the Makefile patch target:
```sh
patch -d $(OPENWRT_DIR) -p1 -N --forward < patches/005-channel-context.patch || true
```

---

## 007 — netifd mac80211.sh (STA scan_freq)

Modifies the mac80211 package shell script in the OpenWrt tree. In
`mac80211_setup_supplicant`, STA mode must pass `$freq $htmode $noscan` to
`wpa_supplicant_add_network` (same as AP mode), so the generated supplicant
config includes `scan_freq`. Applied via `patch -d`.

```sh
F=openwrt/package/kernel/mac80211/files/lib/netifd/wireless/mac80211.sh
cp $F /tmp/mac80211.sh.orig
cp /tmp/mac80211.sh.orig /tmp/mac80211.sh

# Edit: in mac80211_setup_supplicant(), change the sta branch from
#   wpa_supplicant_add_network "$ifname"
# to
#   wpa_supplicant_add_network "$ifname" "$freq" "$htmode" "$noscan"
vim /tmp/mac80211.sh

diff -u /tmp/mac80211.sh.orig /tmp/mac80211.sh \
    > /path/to/project/patches/007-mac80211-sta-freq.patch
sed -i 's|/tmp/mac80211.sh.orig|a/package/kernel/mac80211/files/lib/netifd/wireless/mac80211.sh|' \
    /path/to/project/patches/007-mac80211-sta-freq.patch
sed -i 's|/tmp/mac80211.sh|b/package/kernel/mac80211/files/lib/netifd/wireless/mac80211.sh|' \
    /path/to/project/patches/007-mac80211-sta-freq.patch
```

Applied in the Makefile patch target:
```sh
patch -d $(OPENWRT_DIR) -p1 -N --forward < patches/007-mac80211-sta-freq.patch || true
```

---

## Patch installation summary

| Patch | Target file | Install method | Destination |
|---|---|---|---|
| 001 | wireless-regdb db.txt | `cp` | `firmware/wireless-regdb/patches/001-...` |
| 002 | ath/regd.c | `cp` | `mac80211/patches/ath/999-...` |
| 003 | ath9k/common-init.c | `cp` | `mac80211/patches/ath/997-...` |
| 006 | ath9k/common.c | `cp` | `mac80211/patches/ath/996-...` |
| 009 | net/wireless/scan.c | `cp` | `mac80211/patches/ath/995-...` |
| 004 | hostapd ieee802_11_common.c | `cp` | `services/hostapd/patches/999-...` |
| 008 | wpa_supplicant driver_nl80211.c | `cp` | `services/hostapd/patches/998-...` |
| 005 | mac80211 Makefile | `patch -d` | applied in-tree |
| 007 | netifd mac80211.sh | `patch -d` | applied in-tree |

The `ath/` patch numbering (995–999) controls apply order within the backports
build. Since these patches touch different files they do not conflict, but the
numbering keeps them grouped and predictable:

```
995 - scan-channel   (009)
996 - quarter        (006)
997 - chantable      (003)
999 - regd           (002)
```

---

## Build

```sh
# Full rebuild (forces re-extract and re-patch of all sources)
rm -rf openwrt/build_dir/target-mips_24kc_musl/linux-ath79_tiny/backports-4.19.237-1/.prepared*
rm -rf openwrt/build_dir/target-mips_24kc_musl/wireless-regdb-2021.08.28/.prepared*
make build
```

```sh
# Rebuild mac80211 only after editing a patch (faster than full rebuild).
make package/kernel/mac80211/clean V=s
make build
```

---

## Debug printk workflow (for future diagnostics)

During development the receive-side bug (009) was found by adding temporary
`printk` lines and bisecting the frame-processing chain. The method:

1. Edit the source directly in `build_dir` (fast iteration).
2. Rebuild **without** clean so the edit is not wiped by a re-prepare:
   `make package/kernel/mac80211/compile V=s`
3. Verify the edit survived: `grep -c "HAMNET-DBG" <source-file>` (should be > 0).
4. Flash, then read `dmesg | grep HAMNET-DBG`.
5. One printk, one build, one conclusion — then bisect further.

When the fix is final, regenerate it as a proper patch (tarball method above) so
it survives a clean build. Temporary debug printks must not end up in the final
patches.