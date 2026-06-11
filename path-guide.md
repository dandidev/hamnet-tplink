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

## Makefile patch target

```makefile
patch:
	@echo "Applying HAMNET patches..."
	@cp $(PATCHES_DIR)/001-db-hamnet.patch \
		$(OPENWRT_DIR)/package/firmware/wireless-regdb/patches/001-db-hamnet.patch
	@cp $(PATCHES_DIR)/002-regd-hamnet.patch \
		$(OPENWRT_DIR)/package/kernel/mac80211/patches/ath/999-ath-hamnet-regd.patch
	@cp $(PATCHES_DIR)/003-chantable-hamnet.patch \
		$(OPENWRT_DIR)/package/kernel/mac80211/patches/ath/997-ath-hamnet-chantable.patch
	@cp $(PATCHES_DIR)/004-numchannels-hamnet.patch \
		$(OPENWRT_DIR)/package/kernel/mac80211/patches/ath/996-ath-hamnet-numchannels.patch
	@echo "Done!"
```

## Build

```sh
rm -rf openwrt/build_dir/target-mips_24kc_musl/linux-ath79_tiny/backports-4.19.237-1/.prepared*
rm -rf openwrt/build_dir/target-mips_24kc_musl/wireless-regdb-2021.08.28/.prepared*
make build
```
