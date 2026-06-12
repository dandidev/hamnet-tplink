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

## 005 - mac80211 Makefile (channel context)

This patch modifies the `mac80211` package Makefile, not a kernel source file.
It is applied via `patch -d` in the Makefile patch target, not copied into `patches/ath/`.

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

---

## Build

```sh
# Full rebuild (forces re-patch of both sources)
rm -rf openwrt/build_dir/target-mips_24kc_musl/linux-ath79_tiny/backports-4.19.237-1/.prepared*
rm -rf openwrt/build_dir/target-mips_24kc_musl/wireless-regdb-2021.08.28/.prepared*
make build
```

```sh
# Rebuild mac80211 only after editing a patch (faster than full rebuild).
# clean wipes the build_dir so the next build re-extracts and re-patches.
make package/kernel/mac80211/clean V=s
make build
```