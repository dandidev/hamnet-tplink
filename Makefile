-include .env
export

OPENWRT_DIR  := $(CURDIR)/openwrt
PATCHES_DIR  := $(CURDIR)/patches
FILES_DIR    := $(CURDIR)/files
OPENWRT_TAG  := v19.07.10
PROFILE      ?= tplink_tl-wr841-v11
CACHE_DIR    ?= $(CURDIR)/.dl-cache
CONFIG_SEED  := $(CURDIR)/openwrt-$(PROFILE).config

PKG_PATCHES := \
  package/firmware/wireless-regdb/001-db-hamnet.patch:package/firmware/wireless-regdb/patches/001-db-hamnet.patch \
  package/kernel/mac80211/ath/010-regd-hamnet.patch:package/kernel/mac80211/patches/ath/991-ath-hamnet-regd.patch \
  package/kernel/mac80211/ath/020-ath-num-channels.patch:package/kernel/mac80211/patches/ath/992-ath-num-channels.patch \
  package/kernel/mac80211/ath/030-chantable-hamnet.patch:package/kernel/mac80211/patches/ath/993-ath-hamnet-chantable.patch \
  package/kernel/mac80211/ath/035-util-hamnet-chan-map.patch:package/kernel/mac80211/patches/ath/994-util-hamnet-chan-map.patch \
  package/kernel/mac80211/ath/040-common-hamnet-quarter.patch:package/kernel/mac80211/patches/ath/995-ath-hamnet-quarter.patch \
  package/kernel/mac80211/ath/050-scan-hamnet-channel.patch:package/kernel/mac80211/patches/ath/996-ath-hamnet-scan-channel.patch \
  package/network/services/hostapd/010-hostapd-freq-range-expansion.patch:package/network/services/hostapd/patches/991-hostapd-freq-to-chan.patch \
  package/network/services/hostapd/020-supplicant-hamnet-5mhz-connect.patch:package/network/services/hostapd/patches/992-supplicant-hamnet-5mhz-connect.patch \
  package/network/utils/iw/010-iw-hamnet-chan-map.patch:package/network/utils/iw/patches/991-iw-hamnet-chan-map.patch

.PHONY: image build setup patch clean-patches config files shell clean

image:
	docker build \
		--build-arg UID=$(shell id -u) \
		--build-arg GID=$(shell id -g) \
		-t openwrt-hamnet:ubuntu22 .

build: config files setup patch
	docker run --rm -it \
		--network host \
		-v "$(OPENWRT_DIR)":/work/openwrt \
		-v "$(CACHE_DIR)":/work/openwrt/dl \
		-v "$(PATCHES_DIR)":/work/patches \
		openwrt-hamnet:ubuntu22 \
		bash -c "cd /work/openwrt && make -j$(shell nproc) V=s 2>&1 | tee /work/openwrt/build.log"

setup:
	@if [ ! -d "$(OPENWRT_DIR)/.git" ]; then \
		git clone --branch $(OPENWRT_TAG) \
			https://github.com/openwrt/openwrt.git $(OPENWRT_DIR); \
	else \
		echo "OpenWrt already cloned, skipping..."; \
	fi
	@if [ ! -f "$(OPENWRT_DIR)/.config" ]; then \
		$(MAKE) config; \
	fi

patch:
	@echo "Forcing rebuild of patched packages..."
	rm -rf $(OPENWRT_DIR)/build_dir/target-*/linux-*/backports-* 2>/dev/null || true
	rm -rf $(OPENWRT_DIR)/build_dir/*/hostapd-* 2>/dev/null || true
	rm -rf $(OPENWRT_DIR)/build_dir/*/wireless-regdb-* 2>/dev/null || true
	@echo "Applying HAMNET patches..."
	@for pair in $(PKG_PATCHES); do \
		src="$(PATCHES_DIR)/$${pair%%:*}"; \
		dst="$(OPENWRT_DIR)/$${pair##*:}"; \
		cp "$$src" "$$dst"; \
	done
	@patch -d $(OPENWRT_DIR) -p1 -N --forward < $(PATCHES_DIR)/005-channel-context.patch || true
	@patch -d $(OPENWRT_DIR) -p1 -N --forward < $(PATCHES_DIR)/007-mac80211-sta-freq.patch || true
	@echo "Done!"

clean-patches:
	@echo "Removing copied HAMNET patches..."
	@for pair in $(PKG_PATCHES); do \
		dst="$(OPENWRT_DIR)/$${pair##*:}"; \
		rm -f "$$dst"; \
	done
	@echo "Done!"

files:
	@echo "Staging overlay files..."
	rm -rf $(OPENWRT_DIR)/files
	cp -r $(FILES_DIR) $(OPENWRT_DIR)

config:
	@echo "Copying config..."
	@cp $(CONFIG_SEED) $(OPENWRT_DIR)/.config
	docker run --rm -it \
		--network host \
		-v "$(OPENWRT_DIR)":/work/openwrt \
		openwrt-hamnet:ubuntu22 \
		bash -c "cd /work/openwrt && \
			[ -d feeds/packages ] || ./scripts/feeds update packages && \
			./scripts/feeds install rp-pppoe && \
			make defconfig"

shell:
	docker run --rm -it \
		--network host \
		-v "$(OPENWRT_DIR)":/work/openwrt \
		-v "$(CACHE_DIR)":/work/openwrt/dl \
		-v "$(PATCHES_DIR)":/work/patches \
		openwrt-hamnet:ubuntu22 \
		bash

clean:
	docker run --rm \
		-v "$(OPENWRT_DIR)":/work/openwrt \
		openwrt-hamnet:ubuntu22 \
		bash -c "cd /work/openwrt && make clean"