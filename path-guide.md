# HAMNET Patch guide

## 001 - wireless-regdb db.txt

```sh
# Location
openwrt/build_dir/target-mips_24kc_musl/wireless-regdb-2021.08.28/db.txt

# Copy
cp openwrt/build_dir/target-mips_24kc_musl/wireless-regdb-2021.08.28/db.txt /tmp/db.txt.orig
cp /tmp/db.txt.orig /tmp/db.txt

# Edit
vim /tmp/db.txt

# Patch gen
diff -u /tmp/db.txt.orig /tmp/db.txt > patches/001-db-hamnet.patch
sed -i 's|/tmp/db.txt.orig|a/db.txt|' patches/001-db-hamnet.patch
sed -i 's|/tmp/db.txt|b/db.txt|' patches/001-db-hamnet.patch

# Copy into OpenWrt
cp patches/001-db-hamnet.patch \
    openwrt/package/firmware/wireless-regdb/patches/001-db-hamnet.patch
```

---

## 002 - ath regd.c

```sh
# Location
openwrt/build_dir/target-mips_24kc_musl/linux-ath79_tiny/backports-4.19.237-1/drivers/net/wireless/ath/regd.c

# Copy
cp openwrt/build_dir/target-mips_24kc_musl/linux-ath79_tiny/backports-4.19.237-1/drivers/net/wireless/ath/regd.c /tmp/regd.c.orig
cp /tmp/regd.c.orig /tmp/regd.c

# Edit
vim /tmp/regd.c

# Patch gen
diff -u /tmp/regd.c.orig /tmp/regd.c > patches/002-regd-hamnet.patch
sed -i 's|/tmp/regd.c.orig|a/drivers/net/wireless/ath/regd.c|' patches/002-regd-hamnet.patch
sed -i 's|/tmp/regd.c|b/drivers/net/wireless/ath/regd.c|' patches/002-regd-hamnet.patch

# Copy into OpenWrt
cp patches/002-regd-hamnet.patch \
    openwrt/package/kernel/mac80211/patches/ath/999-ath-hamnet-regd.patch
```

---

## 003 - ath9k common-init.c (chantable)

```sh
# Location
openwrt/build_dir/target-mips_24kc_musl/linux-ath79_tiny/backports-4.19.237-1/drivers/net/wireless/ath/ath9k/common-init.c

# Copy
cp openwrt/build_dir/target-mips_24kc_musl/linux-ath79_tiny/backports-4.19.237-1/drivers/net/wireless/ath/ath9k/common-init.c /tmp/common-init.c.orig
cp /tmp/common-init.c.orig /tmp/common-init.c

# Edit
vim /tmp/common-init.c

# Patch gen
diff -u /tmp/common-init.c.orig /tmp/common-init.c > patches/003-chantable-hamnet.patch
sed -i 's|/tmp/common-init.c.orig|a/drivers/net/wireless/ath/ath9k/common-init.c|' patches/003-chantable-hamnet.patch
sed -i 's|/tmp/common-init.c|b/drivers/net/wireless/ath/ath9k/common-init.c|' patches/003-chantable-hamnet.patch

# Copy into OpenWrt
cp patches/003-chantable-hamnet.patch \
    openwrt/package/kernel/mac80211/patches/ath/997-ath-hamnet-chantable.patch
```

---

## 004 - ath9k hw.h (NUM_CHANNELS)

```sh
# Location
openwrt/build_dir/target-mips_24kc_musl/linux-ath79_tiny/backports-4.19.237-1/drivers/net/wireless/ath/ath9k/hw.h

# Copy
cp openwrt/build_dir/target-mips_24kc_musl/linux-ath79_tiny/backports-4.19.237-1/drivers/net/wireless/ath/ath9k/hw.h /tmp/hw.h.orig
cp /tmp/hw.h.orig /tmp/hw.h

# Edit
vim /tmp/hw.h

# Patch gen
diff -u /tmp/hw.h.orig /tmp/hw.h > patches/004-numchannels-hamnet.patch
sed -i 's|/tmp/hw.h.orig|a/drivers/net/wireless/ath/ath9k/hw.h|' patches/004-numchannels-hamnet.patch
sed -i 's|/tmp/hw.h|b/drivers/net/wireless/ath/ath9k/hw.h|' patches/004-numchannels-hamnet.patch

# Copy into OpenWrt
cp patches/004-numchannels-hamnet.patch \
    openwrt/package/kernel/mac80211/patches/ath/996-ath-hamnet-numchannels.patch
```

---

## 005 - mac80211 Makefile (channel context)
 
Ez a patch a `mac80211` csomag Makefile-ját módosítja — nem kernel forrásfájl, hanem az OpenWrt build rendszer fájlja. Ezért `patch -d` paranccsal kell alkalmazni, nem a `patches/ath/` mappába másolni.
 
```sh
# Location
openwrt/package/kernel/mac80211/Makefile
 
# Copy
cp openwrt/package/kernel/mac80211/Makefile /tmp/mac80211.orig
cp /tmp/mac80211.orig /tmp/mac80211
 
# Edit - ATH9K_CHANNEL_CONTEXT append to config-y list
vim /tmp/mac80211
 
# Patch gen
diff -u /tmp/mac80211.orig /tmp/mac80211 > patches/005-channel-context.patch
sed -i 's|/tmp/mac80211.orig|a/package/kernel/mac80211/Makefile|' patches/005-channel-context.patch
sed -i 's|/tmp/mac80211|b/package/kernel/mac80211/Makefile|' patches/005-channel-context.patch
 
# Apply (in Makefile patch target)
patch -d $(OPENWRT_DIR) -p1 -N --forward < patches/005-channel-context.patch || true
```

## Build

```sh
rm -rf openwrt/build_dir/target-mips_24kc_musl/linux-ath79_tiny/backports-4.19.237-1/.prepared*
rm -rf openwrt/build_dir/target-mips_24kc_musl/wireless-regdb-2021.08.28/.prepared*
make build
```
