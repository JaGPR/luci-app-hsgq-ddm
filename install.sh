#!/bin/sh
# luci-app-hsgq-ddm installer for OpenWrt (no SDK, no package signing needed).
#
#   wget -qO /tmp/install.sh https://raw.githubusercontent.com/JaGPR/luci-app-hsgq-ddm/main/install.sh && sh /tmp/install.sh
#
# Environment overrides:
#   REPO=user/luci-app-hsgq-ddm   GitHub repository to install from
#   BRANCH=main                   branch or tag
#   TARBALL=/tmp/x.tar.gz         install from a local archive instead of GitHub
#   DRY_RUN=1                     print every step, change nothing
#
# Licensed under the Apache License, Version 2.0. See LICENSE and NOTICE.

set -e

REPO="${REPO:-JaGPR/luci-app-hsgq-ddm}"
BRANCH="${BRANCH:-main}"
WORK="/tmp/hsgq-ddm-install.$$"

say()  { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; rm -rf "$WORK"; exit 1; }
run()  { if [ "$DRY_RUN" = "1" ]; then echo "    [dry-run] $*"; else eval "$@"; fi; }

[ "$(id -u)" = "0" ] || die "run this as root on the OpenWrt router"
[ -f /etc/openwrt_release ] || die "this does not look like OpenWrt (/etc/openwrt_release missing)"
command -v uci >/dev/null    || die "uci not found"
command -v nc >/dev/null     || die "BusyBox nc is required (it talks telnet to the stick)"
[ -d /www/luci-static ]      || die "LuCI is not installed (install luci first)"

# Every telnet session is bounded with `timeout ... nc`. Stock OpenWrt BusyBox has
# no timeout applet, so the coreutils one is required (same as luci-app-vsol-ddm).
if ! command -v timeout >/dev/null 2>&1; then
	say "Installing required dependency: coreutils-timeout"
	if command -v apk >/dev/null 2>&1; then
		run "apk update >/dev/null && apk add coreutils-timeout" || die "could not install coreutils-timeout (run: apk add coreutils-timeout)"
	elif command -v opkg >/dev/null 2>&1; then
		run "opkg update >/dev/null && opkg install coreutils-timeout" || die "could not install coreutils-timeout (run: opkg update && opkg install coreutils-timeout)"
	else
		die "no package manager found; install coreutils-timeout manually"
	fi
	[ "$DRY_RUN" = "1" ] || command -v timeout >/dev/null 2>&1 || die "timeout is still missing after installing coreutils-timeout"
fi

mkdir -p "$WORK"

# 1. Fetch the source
if [ -n "$TARBALL" ]; then
	say "Using local archive $TARBALL"
	cp "$TARBALL" "$WORK/src.tar.gz" || die "cannot read $TARBALL"
else
	URL="https://codeload.github.com/$REPO/tar.gz/refs/heads/$BRANCH"
	say "Downloading $REPO ($BRANCH)"
	wget -qO "$WORK/src.tar.gz" "$URL" || die "download failed: $URL (is HTTPS support installed? try: apk add ca-bundle / opkg install ca-bundle)"
fi
tar -xzf "$WORK/src.tar.gz" -C "$WORK" || die "archive is not a valid .tar.gz"
SRC="$(find "$WORK" -maxdepth 2 -type f -name Makefile -path '*hsgq-ddm*' | head -1 | xargs dirname 2>/dev/null)"
[ -n "$SRC" ] && [ -f "$SRC/root/usr/libexec/rpcd/hsgq_ddm" ] || die "archive does not contain luci-app-hsgq-ddm"

# 2. Install files (config is only created if it does not exist yet)
say "Installing files"
run "mkdir -p /usr/libexec/rpcd /usr/share/hsgq_ddm /www/luci-static/resources/view/hsgq_ddm /etc/init.d /etc/config /usr/share/luci/menu.d /usr/share/rpcd/acl.d /lib/upgrade/keep.d"
run "cp '$SRC/root/usr/libexec/rpcd/hsgq_ddm' /usr/libexec/rpcd/hsgq_ddm"
run "cp '$SRC'/root/usr/share/hsgq_ddm/*.awk /usr/share/hsgq_ddm/"
run "cp '$SRC'/htdocs/luci-static/resources/view/hsgq_ddm/*.js /www/luci-static/resources/view/hsgq_ddm/"
run "cp '$SRC/root/etc/init.d/hsgq_ddm' /etc/init.d/hsgq_ddm"
run "cp '$SRC/root/usr/share/luci/menu.d/luci-app-hsgq-ddm.json' /usr/share/luci/menu.d/"
run "cp '$SRC/root/usr/share/rpcd/acl.d/luci-app-hsgq-ddm.json' /usr/share/rpcd/acl.d/"
run "cp '$SRC/root/lib/upgrade/keep.d/luci-app-hsgq-ddm' /lib/upgrade/keep.d/"
if [ -f /etc/config/hsgq_ddm ]; then
	say "Keeping existing /etc/config/hsgq_ddm (your address and login are preserved)"
else
	run "cp '$SRC/root/etc/config/hsgq_ddm' /etc/config/hsgq_ddm"
fi
run "chmod 755 /usr/libexec/rpcd/hsgq_ddm /etc/init.d/hsgq_ddm"
run "chmod 600 /etc/config/hsgq_ddm"
run "chmod 644 /usr/share/hsgq_ddm/*.awk /www/luci-static/resources/view/hsgq_ddm/*.js /usr/share/luci/menu.d/luci-app-hsgq-ddm.json /usr/share/rpcd/acl.d/luci-app-hsgq-ddm.json /lib/upgrade/keep.d/luci-app-hsgq-ddm"

# 3. Seed defaults (never overwrites existing values), register with rpcd, start
say "Applying defaults and registering with LuCI"
run "sh '$SRC/root/etc/uci-defaults/80_luci-app-hsgq-ddm'"
run "/etc/init.d/rpcd reload"

rm -rf "$WORK"

say "Done."
cat <<'EOF'

  Next steps:
   1. Log out of LuCI and log back in (new menu permissions are granted at login).
   2. Open  Status -> HSGQ GPON DDM -> Settings
      - ONT address: the stick's management IP (often 192.168.1.1)
      - Telnet username / password: the stick's own login
      - Save & Apply, then press "Test connection"
   3. Open  Status -> HSGQ GPON DDM -> Optical Diagnostics

  The router must be able to reach the stick's management IP
  (see the README: "Reaching the stick's management address").
EOF
