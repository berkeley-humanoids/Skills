#!/usr/bin/env bash
# Install the kernel from build_kernel.sh into the Linux_for_Tegra rootfs as a second boot entry.
# The layout is the same as in the NVIDIA RT kernel OTA packages:
#   rootfs/boot/Image            stock kernel (also kernel/Image, which the flashing environment boots)
#   rootfs/boot/Image.real-time  RT kernel, extlinux LABEL real-time, set as DEFAULT
#   rootfs/boot/initrd           one initrd with the modules of both kernels
# kernel/Image stays stock, because an RT kernel can crash during the flash (NVIDIA issue 6244887).
# INSTALL_DTBS=1 also replaces kernel/dtb/ with the DTBs from the source build.
#
# Usage: sudo -E CROSS_COMPILE=<toolchain prefix> install_kernel.sh <Linux_for_Tegra dir>
set -euo pipefail

L4T=$(realpath "${1:?usage: sudo -E $0 <Linux_for_Tegra dir>}")
[ "$(id -u)" -eq 0 ] || { echo "ERROR: run with sudo -E" >&2; exit 1; }
# kbuild re-checks the compiler during install; the host gcc would trigger a reconfigure.
: "${CROSS_COMPILE:?CROSS_COMPILE not set. Use sudo -E so the build environment is kept.}"
export CROSS_COMPILE
boot=$L4T/rootfs/boot
[ -f "$L4T/rootfs/etc/lsb-release" ] || { echo "ERROR: $L4T/rootfs is empty. Extract the sample rootfs and run apply_binaries.sh first." >&2; exit 1; }
if grep -aq PREEMPT_RT "$L4T/kernel/Image"; then
  echo "ERROR: $L4T/kernel/Image is an RT kernel. Restore the stock one: tar xf Jetson_Linux_*_aarch64.tbz2 Linux_for_Tegra/kernel/Image" >&2
  exit 1
fi

cd "$L4T/source"
source ./kernel_src_build_env.sh
ksrc=kernel/$KERNEL_SRC_DIR
export INSTALL_MOD_PATH=$L4T/rootfs/
export KERNEL_HEADERS=$PWD/$ksrc
[ -n "${kernel_name:-}" ] && export kernel_name

make install -C kernel # Image to rootfs/boot/Image, in-tree modules to rootfs/lib/modules/<release>/
mv "$boot/Image" "$boot/Image.real-time"
install -m 644 "$L4T/kernel/Image" "$boot/Image"
make modules_install # NVIDIA OOT modules to rootfs/lib/modules/<release>/updates/

if [ "${INSTALL_DTBS:-0}" = 1 ]; then
  if [ -d build/nvidia-public/devicetree/generic-dtbs ]; then
    cp build/nvidia-public/devicetree/generic-dtbs/* "$L4T/kernel/dtb/"  # r39.x
  else
    cp kernel-devicetree/generic-dts/dtbs/* "$L4T/kernel/dtb/"           # r36.x
  fi
fi

conf=$boot/extlinux/extlinux.conf
if ! grep -q '^LABEL real-time' "$conf"; then
  cat >> "$conf" <<'EOF'

LABEL real-time
      MENU LABEL real-time kernel
      LINUX /boot/Image.real-time
      INITRD /boot/initrd
      APPEND ${cbootargs}
EOF
fi
sed -i 's/^DEFAULT .*/DEFAULT real-time/' "$conf"

cd "$L4T"
./tools/l4t_update_initrd.sh # nv-update-initrd adds modules for /boot/Image and /boot/Image.real-time
echo "Installed kernel $(cat "source/$ksrc/include/config/kernel.release") as $boot/Image.real-time (DEFAULT real-time)"
