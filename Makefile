#
# luci-app-hsgq-ddm - optical diagnostics for HSGQ / ODI DFP-34X GPON SFP sticks.
#
# Modified from luci-app-vsol-ddm (https://github.com/AliLostInTheDark/luci-app-vsol-ddm).
# Licensed under the Apache License, Version 2.0. See LICENSE and NOTICE.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-hsgq-ddm
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

PKG_LICENSE:=Apache-2.0
PKG_LICENSE_FILES:=LICENSE NOTICE
PKG_MAINTAINER:=Jagpreet Singh <21BCS1337@cuchd.in>
PKG_URL:=https://github.com/JaGPR/luci-app-hsgq-ddm

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

# Shell + awk driving BusyBox nc: no compiled component, so one package
# installs on every architecture.
define Package/luci-app-hsgq-ddm
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=HSGQ GPON SFP stick Optical Diagnostics & DDM Monitor
  DEPENDS:=+luci-base
  PKGARCH:=all
endef

define Package/luci-app-hsgq-ddm/description
  LuCI dashboard for HSGQ / ODI DFP-34X (Realtek RTL960x) GPON SFP ONU sticks:
  optical DDM (Rx/Tx power, temperature, voltage, bias), GPON activation state,
  FEC/BIP error counters, alarms, T-CONT/GEM allocations, OMCI managed entities,
  SFP host-link traffic counters and history charts, read over telnet.
endef

# Kept across package upgrade. Sysupgrade retention is handled by
# /lib/upgrade/keep.d/luci-app-hsgq-ddm, installed below.
define Package/luci-app-hsgq-ddm/conffiles
/etc/config/hsgq_ddm
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
endef

define Build/Compile
endef

define Package/luci-app-hsgq-ddm/install
	$(INSTALL_DIR) $(1)/usr/share/hsgq_ddm
	$(INSTALL_DATA) ./root/usr/share/hsgq_ddm/* $(1)/usr/share/hsgq_ddm/

	$(INSTALL_DIR) $(1)/www/luci-static/resources/view/hsgq_ddm
	$(INSTALL_DATA) ./htdocs/luci-static/resources/view/hsgq_ddm/* $(1)/www/luci-static/resources/view/hsgq_ddm/

	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./root/etc/init.d/hsgq_ddm $(1)/etc/init.d/hsgq_ddm

	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./root/etc/config/hsgq_ddm $(1)/etc/config/hsgq_ddm

	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./root/etc/uci-defaults/80_luci-app-hsgq-ddm $(1)/etc/uci-defaults/

	$(INSTALL_DIR) $(1)/lib/upgrade/keep.d
	$(INSTALL_DATA) ./root/lib/upgrade/keep.d/luci-app-hsgq-ddm $(1)/lib/upgrade/keep.d/luci-app-hsgq-ddm

	$(INSTALL_DIR) $(1)/usr/libexec/rpcd
	$(INSTALL_BIN) ./root/usr/libexec/rpcd/hsgq_ddm $(1)/usr/libexec/rpcd/hsgq_ddm

	$(INSTALL_DIR) $(1)/usr/share/luci/menu.d
	$(INSTALL_DATA) ./root/usr/share/luci/menu.d/luci-app-hsgq-ddm.json $(1)/usr/share/luci/menu.d/

	$(INSTALL_DIR) $(1)/usr/share/rpcd/acl.d
	$(INSTALL_DATA) ./root/usr/share/rpcd/acl.d/luci-app-hsgq-ddm.json $(1)/usr/share/rpcd/acl.d/
endef

define Package/luci-app-hsgq-ddm/postinst
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] || {
	rm -rf /tmp/luci-indexcache* /tmp/luci-modulecache* /tmp/hsgq_ddm_cache.json
	/etc/init.d/rpcd reload 2>/dev/null || true
}
exit 0
endef

define Package/luci-app-hsgq-ddm/prerm
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] || {
	/etc/init.d/hsgq_ddm stop 2>/dev/null || true
	/etc/init.d/hsgq_ddm disable 2>/dev/null || true
}
exit 0
endef

define Package/luci-app-hsgq-ddm/postrm
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] || {
	rm -rf /tmp/luci-indexcache* /tmp/luci-modulecache* /tmp/hsgq_ddm_*
	/etc/init.d/rpcd reload 2>/dev/null || true
}
exit 0
endef

$(eval $(call BuildPackage,luci-app-hsgq-ddm))
