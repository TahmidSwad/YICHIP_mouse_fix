#!/usr/bin/bash
# Install and enable the YICHIP 3151:3020 mouse recovery service.
# Run with: sudo bash install.sh

set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "Run this installer as root: sudo bash install.sh" >&2
    exit 1
fi

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

install -m 0755 "$SCRIPT_DIR/yichip-mouse-fix" /usr/local/sbin/yichip-mouse-fix
install -m 0644 "$SCRIPT_DIR/yichip-mouse-fix.service" /etc/systemd/system/yichip-mouse-fix.service
install -m 0644 "$SCRIPT_DIR/99-yichip-mouse-fix.rules" /etc/udev/rules.d/99-yichip-mouse-fix.rules

# Disable and mask the old interface-only workaround. The new service resets
# the whole receiver, which is required after a failed usbhid probe.
systemctl disable --now fix-yichip-mouse.service 2>/dev/null || true
systemctl mask fix-yichip-mouse.service 2>/dev/null || true

systemctl daemon-reload
udevadm control --reload-rules

# Re-trigger the receiver so the udev rule starts the service now.
udevadm trigger --subsystem-match=usb --attr-match=idVendor=3151 --attr-match=idProduct=3020 2>/dev/null || true

systemctl enable yichip-mouse-fix.service
systemctl start --no-block yichip-mouse-fix.service || true

echo
echo "Installed. Current status:"
systemctl status yichip-mouse-fix.service --no-pager || true
echo
echo "Live logs: journalctl -u yichip-mouse-fix.service -b --no-pager -f"
