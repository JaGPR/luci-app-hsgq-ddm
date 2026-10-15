#!/bin/sh
# Removes luci-app-hsgq-ddm installed by install.sh.
#   wget -qO /tmp/uninstall.sh https://raw.githubusercontent.com/JaGPR/luci-app-hsgq-ddm/main/uninstall.sh && sh /tmp/uninstall.sh
# KEEP_CONFIG=1 keeps /etc/config/hsgq_ddm (address and login) for a later reinstall.
#
# Licensed under the Apache License, Version 2.0. See LICENSE and NOTICE.

[ "$(id -u)" = "0" ] || { echo "run as root" >&2; exit 1; }

/etc/init.d/hsgq_ddm stop 2>/dev/null
/etc/init.d/hsgq_ddm disable 2>/dev/null

rm -f  /usr/libexec/rpcd/hsgq_ddm /etc/init.d/hsgq_ddm \
       /usr/share/luci/menu.d/luci-app-hsgq-ddm.json /usr/share/rpcd/acl.d/luci-app-hsgq-ddm.json \
       /lib/upgrade/keep.d/luci-app-hsgq-ddm /etc/uci-defaults/80_luci-app-hsgq-ddm
rm -rf /usr/share/hsgq_ddm /www/luci-static/resources/view/hsgq_ddm
rm -f  /tmp/hsgq_ddm_* /tmp/hsgq_ddm.lock
[ "$KEEP_CONFIG" = "1" ] || rm -f /etc/config/hsgq_ddm

rm -rf /tmp/luci-indexcache* /tmp/luci-modulecache*
/etc/init.d/rpcd reload 2>/dev/null

echo "luci-app-hsgq-ddm removed.$([ "$KEEP_CONFIG" = "1" ] && echo " Config kept in /etc/config/hsgq_ddm.")"
