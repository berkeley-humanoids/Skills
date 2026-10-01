#!/usr/bin/env bash
# Build a PREEMPT_RT Jetson Linux kernel with gs_usb (USB-CAN) and ch341 (CH340/CH341 USB-serial),
# and the NVIDIA out-of-tree (OOT) modules and DTBs. Follows NVIDIA "Kernel Customization"
# (r36.x = JetPack 6, r39.x = JetPack 7). Does not need root.
#
# Usage: CROSS_COMPILE=<toolchain prefix> build_kernel.sh <Linux_for_Tegra dir>
set -euo pipefail

L4T=$(realpath "${1:?usage: CROSS_COMPILE=<prefix> $0 <Linux_for_Tegra dir>}")
: "${CROSS_COMPILE:?export CROSS_COMPILE, e.g. <x-tools>/aarch64-none-linux-gnu/bin/aarch64-none-linux-gnu-}"
export CROSS_COMPILE
"${CROSS_COMPILE}gcc" --version | head -n 1

cd "$L4T/source"
source ./kernel_src_build_env.sh # KERNEL_SRC_DIR (kernel-jammy-src | kernel-noble), kernel_name on r39
ksrc=kernel/$KERNEL_SRC_DIR
[ -f "$ksrc/Makefile" ] || { echo "ERROR: $ksrc missing. Run ./source_sync.sh -k -t <tag> first." >&2; exit 1; }

./generic_rt_build.sh "enable" # idempotent: prints "already applied" on re-runs

"$ksrc/scripts/config" --file "$ksrc/arch/arm64/configs/defconfig" \
  --module CAN_GS_USB --module USB_SERIAL_CH341

make -C kernel

cfg=$ksrc/.config
for want in CONFIG_PREEMPT_RT=y CONFIG_CAN_GS_USB=m CONFIG_USB_SERIAL_CH341=m; do
  grep -qx "$want" "$cfg" || { echo "ERROR: $want missing from $cfg" >&2; exit 1; }
done

export IGNORE_PREEMPT_RT_PRESENCE=1
export KERNEL_HEADERS=$PWD/$ksrc
[ -n "${kernel_name:-}" ] && export kernel_name
make modules
make dtbs

echo "Built kernel $(cat "$ksrc/include/config/kernel.release")"
echo "Next: sudo -E $(dirname "$(realpath "$0")")/install_kernel.sh $L4T"
