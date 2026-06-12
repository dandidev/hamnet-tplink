OPENWRT_DIR  := $(CURDIR)/openwrt
# Set this to your local download cache directory
CACHE_DIR    := /opt/ham/htchat/cache/dl
PATCHES_DIR  := $(CURDIR)/patches
OPENWRT_TAG  := v19.07.10
# PROFILE      := tplink_tl-wr841-v9
 PROFILE      := tplink_tl-wr841-v11
# PROFILE      := tplink_tl-wr841-v7
CONFIG_SEED  := $(CURDIR)/openwrt-$(PROFILE).config

.PHONY: image build setup patch config clean

image:
	docker build \
		--build-arg UID=$(shell id -u) \
		--build-arg GID=$(shell id -g) \
		-t openwrt-hamnet:ubuntu22 .

build: setup patch
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
	@echo "Applying HAMNET patches..."
	@cp $(PATCHES_DIR)/001-db-hamnet.patch \
		$(OPENWRT_DIR)/package/firmware/wireless-regdb/patches/001-db-hamnet.patch
	@cp $(PATCHES_DIR)/002-regd-hamnet.patch \
		$(OPENWRT_DIR)/package/kernel/mac80211/patches/ath/999-ath-hamnet-regd.patch
	@cp $(PATCHES_DIR)/003-chantable-hamnet.patch \
		$(OPENWRT_DIR)/package/kernel/mac80211/patches/ath/997-ath-hamnet-chantable.patch
	@patch -d $(OPENWRT_DIR) -p1 -N --forward < $(PATCHES_DIR)/005-channel-context.patch || true
	@echo "Done!"

config:
	@echo "Copying config..."
	@cp $(CONFIG_SEED) $(OPENWRT_DIR)/.config
	docker run --rm -it \
		-v "$(OPENWRT_DIR)":/work/openwrt \
		openwrt-hamnet:ubuntu22 \
		bash -c "cd /work/openwrt && make defconfig"

clean:
	docker run --rm \
		-v "$(OPENWRT_DIR)":/work/openwrt \
		openwrt-hamnet:ubuntu22 \
		bash -c "cd /work/openwrt && make clean"