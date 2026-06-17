include $(TOPDIR)/rules.mk

PKG_NAME:=web-hamnet-hu
PKG_VERSION:=0.1.0
PKG_RELEASE:=1

include $(INCLUDE_DIR)/package.mk

define Package/web-hamnet-hu
  SECTION:=net
  CATEGORY:=Network
  TITLE:=HAMNET web UI - HU (scan / wi-fi / pppoe wizard)
  DEPENDS:=+web-hamnet-core +iw
  PKGARCH:=all
endef

define Package/web-hamnet-hu/description
  Region-specific pages for the HAMNET web UI: a guided wizard (scan ->
  wi-fi connect -> pppoe) using the HAMNET 5 MHz channel plan, plus a live
  status / edit page. Adds a "HAMNET" entry to web-hamnet-core.
endef

# Pure shell/HTML - nothing to compile.
define Build/Compile
endef

define Package/web-hamnet-hu/install
	$(INSTALL_DIR) $(1)/www/cgi-bin
	$(INSTALL_BIN)  ./files/www/cgi-bin/hamnet-hu $(1)/www/cgi-bin/hamnet-hu

	$(INSTALL_DIR) $(1)/etc/hamnet/menu.d
	$(INSTALL_DATA) ./files/etc/hamnet/menu.d/30-hamnet $(1)/etc/hamnet/menu.d/30-hamnet
endef

$(eval $(call BuildPackage,web-hamnet-hu))
