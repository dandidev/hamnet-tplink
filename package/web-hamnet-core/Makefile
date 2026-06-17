include $(TOPDIR)/rules.mk

PKG_NAME:=web-hamnet-core
PKG_VERSION:=0.1.0
PKG_RELEASE:=1

include $(INCLUDE_DIR)/package.mk

define Package/web-hamnet-core
  SECTION:=net
  CATEGORY:=Network
  TITLE:=HAMNET minimal web UI (core)
  DEPENDS:=+uhttpd
  PKGARCH:=all
endef

define Package/web-hamnet-core/description
  Minimal, LuCI-free web UI framework for HAMNET routers: uhttpd basic-auth
  setup, a menu framework, shared rendering helpers and a reboot action.
  Region/ISP specific pages are provided by add-ons (e.g. web-hamnet-hu).
endef

# Pure shell/HTML - nothing to compile.
define Build/Compile
endef

define Package/web-hamnet-core/install
	$(INSTALL_DIR) $(1)/www/cgi-bin
	$(INSTALL_BIN)  ./files/www/cgi-bin/hamnet $(1)/www/cgi-bin/hamnet

	$(INSTALL_DIR) $(1)/www/hamnet
	$(INSTALL_DATA) ./files/www/hamnet/style.css $(1)/www/hamnet/style.css
	$(INSTALL_DATA) ./files/www/index.html       $(1)/www/index.html

	$(INSTALL_DIR) $(1)/usr/lib/hamnet
	$(INSTALL_DATA) ./files/usr/lib/hamnet/lib.sh $(1)/usr/lib/hamnet/lib.sh

	$(INSTALL_DIR) $(1)/etc/hamnet/menu.d
	$(INSTALL_DATA) ./files/etc/hamnet/menu.d/00-home   $(1)/etc/hamnet/menu.d/00-home
	$(INSTALL_DATA) ./files/etc/hamnet/menu.d/90-system $(1)/etc/hamnet/menu.d/90-system

	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN)  ./files/etc/uci-defaults/90-hamnet-web $(1)/etc/uci-defaults/90-hamnet-web
endef

$(eval $(call BuildPackage,web-hamnet-core))
