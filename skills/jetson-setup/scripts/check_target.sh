#!/usr/bin/env bash
# Check after the flash, on the Jetson: RT kernel, USB-CAN (gs_usb), CH341 serial, brltty.
# It loads modules, so run it with sudo. Exit code = number of failed checks.
#
# Usage: sudo ./check_target.sh
set -u  # no pipefail: `cmd | grep -q` must not fail on SIGPIPE

fail=0
check() { if eval "$2" >/dev/null 2>&1; then echo "PASS  $1"; else echo "FAIL  $1"; fail=$((fail + 1)); fi; }

echo "L4T:     $(head -n 1 /etc/nv_tegra_release)"
echo "kernel:  $(uname -r) | $(uname -v)"
echo "jetpack: $(dpkg-query -W -f='${Version}' nvidia-jetpack 2>/dev/null || echo 'not installed (sudo apt install nvidia-jetpack)')"

check "kernel is PREEMPT_RT (uname -v)" "uname -v | grep -q PREEMPT_RT"
[ -e /sys/kernel/realtime ] && check "/sys/kernel/realtime is 1" "[ \"\$(cat /sys/kernel/realtime)\" = 1 ]"
check "gs_usb module loads" "modprobe gs_usb"
check "ch341 module loads" "modprobe ch341"
check "can_raw module loads" "modprobe can_raw"
check "NVIDIA GPU driver loaded (nvgpu)" "lsmod | grep -q '^nvgpu'"
check "brltty is not running (it steals CH341 devices)" "! systemctl is-active --quiet brltty"

# A gs_usb adapter shows up as a CAN netdev; the native Orin CAN controller is mttcan.
for dev in /sys/class/net/*; do
  [ "$(cat "$dev/type" 2>/dev/null)" = 280 ] || continue  # ARPHRD_CAN
  echo "CAN:     $(basename "$dev") driver=$(basename "$(readlink -f "$dev/device/driver")" 2>/dev/null)"
done
ls /dev/ttyUSB* /dev/ttyACM* 2>/dev/null | sed 's/^/serial:  /'

exit "$fail"
