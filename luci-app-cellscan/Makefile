include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-cellscan
PKG_VERSION:=1.01
PKG_RELEASE:=2

PKG_MAINTAINER:=newton_miku
include $(INCLUDE_DIR)/package.mk

define Package/luci-app-cellscan
    PKGARCH:=all
    SECTION:=luci
    CATEGORY:=LuCI
    SUBMENU:=3. Applications
    TITLE:=Cell Scan Results
    DEPENDS:=+lua +lua-cjson
endef


define Build/Compile
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller
	$(INSTALL_DATA) ./luasrc/controller/cellscan.lua $(1)/usr/lib/lua/luci/controller/

	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/model/cbi
	$(INSTALL_DATA) ./luasrc/model/cbi/cellscan.lua $(1)/usr/lib/lua/luci/model/cbi/

	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/view/cellscan
	$(INSTALL_DATA) ./luasrc/view/cellscan/* $(1)/usr/lib/lua/luci/view/cellscan/
	
	$(INSTALL_DIR) $(1)/usr/share/modem/
	$(INSTALL_BIN) ./keyPairCellScan.sh $(1)/usr/share/modem/keyPairCellScan.sh
	
	chmod +x $(1)/usr/share/modem/keyPairCellScan.sh
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
