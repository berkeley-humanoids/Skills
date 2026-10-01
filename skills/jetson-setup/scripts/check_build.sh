#!/usr/bin/env bash
# Host check before the flash: Linux_for_Tegra must flash the RT kernel (with gs_usb and ch341)
# as the default boot entry, next to the stock kernel. Read-only. With sudo, it also examines the
# initrd, which root owns. Exit code = number of failed checks.
#
# Usage: [sudo] check_build.sh <Linux_for_Tegra dir>
set -u  # no pipefail: `cmd | grep -q` must not fail on SIGPIPE

L4T=$(realpath "${1:?usage: $0 <Linux_for_Tegra dir>}")
source "$L4T/source/kernel_src_build_env.sh"
ksrc=$L4T/source/kernel/$KERNEL_SRC_DIR
boot=$L4T/rootfs/boot
fail=0
check() { if eval "$2" >/dev/null 2>&1; then echo "PASS  $1"; else echo "FAIL  $1"; fail=$((fail + 1)); fi; }

rel=$(cat "$ksrc/include/config/kernel.release" 2>/dev/null)
mods=$L4T/rootfs/lib/modules/$rel
echo "kernel release: ${rel:-<not built>}"

check "built .config has CONFIG_PREEMPT_RT=y" "grep -qx CONFIG_PREEMPT_RT=y '$ksrc/.config'"
check "built .config has CONFIG_CAN_GS_USB=m" "grep -qx CONFIG_CAN_GS_USB=m '$ksrc/.config'"
check "built .config has CONFIG_USB_SERIAL_CH341=m" "grep -qx CONFIG_USB_SERIAL_CH341=m '$ksrc/.config'"
check "release name ends in -rt-tegra" "[[ '$rel' == *-rt-tegra ]]"
check "kernel/Image is stock (flashing environment)" "! grep -aq PREEMPT_RT '$L4T/kernel/Image'"
check "rootfs/boot/Image.real-time is the built Image" "cmp -s '$ksrc/arch/arm64/boot/Image' '$boot/Image.real-time'"
check "extlinux.conf has LABEL real-time" "grep -q '^LABEL real-time' '$boot/extlinux/extlinux.conf'"
check "extlinux.conf has DEFAULT real-time" "grep -q '^DEFAULT real-time' '$boot/extlinux/extlinux.conf'"
check "gs_usb module installed in rootfs" "find '$mods' -name 'gs_usb.ko*' | grep -q ."
check "ch341 module installed in rootfs" "find '$mods' -name 'ch341.ko*' | grep -q ."
check "gs_usb listed in modules.dep" "grep -q gs_usb '$mods/modules.dep'"
check "NVIDIA OOT modules installed (nvgpu)" "find '$mods/updates' -name 'nvgpu.ko*' | grep -q ."
check "gs_usb vermagic is PREEMPT_RT" "modinfo -F vermagic \"\$(find '$mods' -name 'gs_usb.ko*' | head -n 1)\" | grep -q preempt_rt"
if [ "$(id -u)" -eq 0 ]; then
  check "initrd has modules for $rel" "zcat '$boot/initrd' | cpio -it --quiet | grep -q 'lib/modules/$rel/'"
else
  echo "SKIP  initrd contents (run with sudo to check)"
fi

if grep -q ':1000:' "$L4T/rootfs/etc/passwd"; then
  echo "INFO  default user pre-created: boots to login, no oem-config wizard"
else
  echo "INFO  no default user: first boot runs the oem-config wizard (needs monitor + keyboard)"
fi

exit "$fail"
