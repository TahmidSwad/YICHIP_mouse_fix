# yichip-mouse-fix

A small systemd + udev workaround for YICHIP `3151:3020` wireless receivers whose **mouse HID interface fails to initialize** on Linux.

The receiver usually shows up with two HID interfaces:

- `1.0` — keyboard, works
- `1.1` — mouse, probe times out with `-110`

Interface numbers can vary; the script detects the mouse interface by its HID class and protocol, not by a hard-coded number.

The kernel then logs:

```text
usbhid 1-2:1.1: can't add hid device: -110
usbhid 1-2:1.1: probe with driver usbhid failed with error -110
```

`-110` is `ETIMEDOUT`. No mouse input device is created, even though the dongle and keyboard half are detected.

## Why rebinding the interface doesn't work

A common workaround is:

```bash
echo 1-2:1.1 | sudo tee /sys/bus/usb/drivers/usbhid/bind
```

That just retries the same failing probe, which times out again. The receiver needs a **full USB reset/re-enumeration**, not an interface-level rebind.

## What this does

At boot, and whenever the dongle is plugged in, the service:

1. Finds the receiver by USB ID `3151:3020` — no hard-coded USB port.
2. Checks whether the mouse HID interface is bound to `usbhid` and has a relative-axis input node.
3. Waits 30 seconds for the initial probe to finish so it isn't interrupted mid-timeout.
4. Resets the whole receiver with `authorized=0` → `authorized=1`, falling back to USB unbind/bind if needed.
5. Waits up to 60 seconds for the re-probe, then retries up to 5 times with backoff.
6. Exits immediately if the mouse is already working.

A udev rule also starts the service on hotplug and keeps the receiver out of USB autosuspend.

## Requirements

- Linux with `systemd` and `udev`
- Root access to install the service and udev rule

Developed on:

- Fedora Linux 45
- Kernel `7.3.4`
- GNOME on Wayland
- YICHIP `3151:3020` wireless receiver

Other systemd-based distributions should work, but kernel behavior may differ.

## Install

```bash
git clone https://github.com/TahmidSwad/YICHIP_mouse_fix
cd yichip-mouse-fix
sudo bash install.sh
```

The installer:

- installs `/usr/local/sbin/yichip-mouse-fix`
- installs and enables `yichip-mouse-fix.service`
- installs `/etc/udev/rules.d/99-yichip-mouse-fix.rules`
- disables and masks `fix-yichip-mouse.service` if an older interface-only workaround exists

## Verify

```bash
systemctl status yichip-mouse-fix.service --no-pager
journalctl -u yichip-mouse-fix.service -b --no-pager
```

A successful run ends with one of:

```text
YICHIP mouse interface is working.
YICHIP mouse interface recovered.
```

The service is a one-shot job, so `inactive (dead)` after it finishes is normal.

To test immediately without rebooting:

```bash
sudo systemctl restart yichip-mouse-fix.service
journalctl -u yichip-mouse-fix.service -b -f
```

You can also confirm the input device exists:

```bash
grep -H . /sys/class/input/input*/name | grep -i yichip
ls /sys/bus/hid/devices/ | grep -i '3151:3020'
```

## Files

| File | Purpose |
| --- | --- |
| `yichip-mouse-fix` | Main recovery script |
| `yichip-mouse-fix.service` | Runs the script at boot |
| `99-yichip-mouse-fix.rules` | Starts the service on hotplug and disables autosuspend |
| `install.sh` | Installs and enables everything |

## Troubleshooting

**The service fails after all attempts**

Make sure the mouse itself is switched on and awake. A receiver reset cannot make a powered-off mouse appear. Then restart the service:

```bash
sudo systemctl restart yichip-mouse-fix.service
```

**The keyboard disconnects briefly during the fix**

That is expected. The keyboard and mouse are two interfaces on the same receiver, so resetting the receiver resets both halves.

**Check the raw kernel messages**

```bash
journalctl -k -b --no-pager | grep -i -E '3151|3020|usbhid|yichip'
```

**The dongle is on a different bus or port**

Nothing to change. The script locates the receiver by vendor/product ID at runtime.

## Uninstall

```bash
sudo systemctl disable --now yichip-mouse-fix.service
sudo rm -f /usr/local/sbin/yichip-mouse-fix
sudo rm -f /etc/systemd/system/yichip-mouse-fix.service
sudo rm -f /etc/udev/rules.d/99-yichip-mouse-fix.rules
sudo systemctl daemon-reload
sudo udevadm control --reload-rules
```

If you want to re-enable the old `fix-yichip-mouse.service` workaround:

```bash
sudo systemctl unmask fix-yichip-mouse.service
sudo systemctl enable fix-yichip-mouse.service
```

## Notes

- This is a workaround for a device/kernel initialization issue, not a kernel fix.
- The underlying problem has been reported with this USB ID on Fedora, Arch, and Bazzite. It is intermittent and appears timing-related.
- If the problem persists across ports, kernels, and resets, a different dongle or mouse is the most reliable fix.

## Related reports

- [ublue-os/bazzite#3007 — USB Mouse Not Working: YICHIP Wireless Device ID 3151:3020](https://github.com/ublue-os/bazzite/issues/3007)
- [Arch Linux forum — Block individual hardware from USBHID](https://bbs.archlinux.org/viewtopic.php?id=312066)
- [Fedora Discussion — Wireless combo keyboard + mouse not working](https://discussion.fedoraproject.org/t/wireless-combo-keyboard-mouse-not-working/75019)
