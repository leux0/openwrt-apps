include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-cellscan
PKG_VERSION:=1.10
PKG_RELEASE:=3

PKG_MAINTAINER:=leux
include $(INCLUDE_DIR)/package.mk

define Package/luci-app-cellscan
    PKGARCH:=all
    SECTION:=luci
    CATEGORY:=LuCI
    SUBMENU:=3. Applications
    TITLE:=Cell Scan Results
    DEPENDS:=+coreutils-timeout
endef


define Build/Compile
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller
	$(INSTALL_DATA) ./luasrc/controller/cellscan.lua $(1)/usr/lib/lua/luci/controller/

	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/model/cbi
	$(INSTALL_DATA) ./luasrc/model/cbi/cellscan.lua $(1)/usr/lib/lua/luci/model/cbi/

	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/view/modem
	$(INSTALL_DATA) ./luasrc/view/modem/* $(1)/usr/lib/lua/luci/view/modem/
	
	$(INSTALL_DIR) $(1)/usr/share/modem/
	$(INSTALL_BIN) ./cellscan.sh $(1)/usr/share/modem/cellscan.sh
	
	chmod +x $(1)/usr/share/modem/cellscan.sh
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
