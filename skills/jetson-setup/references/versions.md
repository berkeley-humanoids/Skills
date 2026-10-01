# Per-version values

The commands in SKILL.md use the variables on this page. Set them once in each shell. We compared
all values with the NVIDIA release pages, release notes, and BSP scripts on 2026-09-29.

## Summary

| Item | JetPack 7.2.1 | JetPack 6.2.2 |
|---|---|---|
| Jetson Linux (L4T) | 39.2.1 | 36.5 |
| Jetson OS / kernel | Ubuntu 24.04 / 6.8 | Ubuntu 22.04 / 5.15 |
| Supported **host** OS | Ubuntu 22.04, 24.04 | Ubuntu 20.04, 22.04 |
| Source git tag | `jetson_39.2.1` (the release notes give `jetson_39.2.1_GA`, which does not exist) | `jetson_36.5` |
| Kernel source dir | `source/kernel/kernel-noble` | `source/kernel/kernel-jammy-src` |
| Toolchain | NVIDIA `x-tools` GCC 13.2 | Bootlin GCC 11.3 |
| Built kernel release | `6.8.12-<sru>-rt-tegra` (e.g. `6.8.12-1021-rt-tegra`) | `5.15.x-rt-tegra` |
| DTB build output | `source/build/nvidia-public/devicetree/generic-dtbs/` | `source/kernel-devicetree/generic-dts/dtbs/` |
| RT script needs a fix? | No: the 39.2.1 `generic_rt_build.sh` has `--enable EXPERT` | No: on 5.15, `EMBEDDED` selects `EXPERT` |
| Stock `gs_usb` / `ch341`? | Not in defconfig: custom build needed | Not in defconfig: custom build needed |

The `<sru>` number comes from `debian.nvidia-tegra/changelog`. The build reads it only if
`dpkg-parsechangelog` is on the host (package `dpkg-dev`, SKILL.md step 1). The stock kernel also
has it (`6.8.12-1021-tegra` in 39.2.1). Without `dpkg-dev`, the release is `6.8.12-rt-tegra`.
This also works, because the RT kernel has its own module directory.

## JetPack 7.2.1 (L4T 39.2.1)

```bash
export JP=7.2.1 TAG=jetson_39.2.1
export NV=~/Documents/nvidia                     # gitbook layout
export L4T=$NV/nvidia_sdk/JetPack_7.2.1_Linux_JETSON_ORIN_NX_TARGETS/Linux_for_Tegra
export CROSS_COMPILE=$NV/x-tools/aarch64-none-linux-gnu/bin/aarch64-none-linux-gnu-
```

Downloads (from <https://developer.nvidia.com/embedded/jetpack/downloads>):

| File | URL |
|---|---|
| BSP | `https://developer.nvidia.com/downloads/embedded/L4T/r39_Release_v2.1/release/Jetson_Linux_R39.2.1_aarch64.tbz2` |
| Sample rootfs | `https://developer.nvidia.com/downloads/embedded/L4T/r39_Release_v2.1/release/Tegra_Linux_Sample-Root-Filesystem_R39.2.1_aarch64.tbz2` |
| Checksums | `https://developer.nvidia.com/downloads/embedded/L4T/r39_Release_v2.1/release/release_sha_hashes.txt` |
| Toolchain | `https://developer.nvidia.com/downloads/embedded/L4T/r38_Release_v2.0/release/x-tools.tbz2` (extracts to `x-tools/aarch64-none-linux-gnu/`) |

Flash commands. Run them in `$L4T`, with the Jetson in recovery mode:

| Target | Command |
|---|---|
| Orin NX / Nano, P3768 or compatible carrier, NVMe | `sudo ./l4t_initrd_flash.sh jetson-orin-nano-devkit internal` |
| Orin NX / Nano, NVMe, Super mode (NVIDIA devkit carrier) | `sudo ./l4t_initrd_flash.sh jetson-orin-nano-devkit-super internal` |
| AGX Orin devkit, eMMC | `sudo ./l4t_initrd_flash.sh --erase-all jetson-agx-orin-devkit internal` |
| AGX Orin devkit, NVMe | `sudo ./l4t_initrd_flash.sh --external-device nvme0n1p1 -c tools/kernel_flash/flash_l4t_t234_nvme.xml jetson-agx-orin-devkit external` |

NVIDIA's Quick Start adds `--erase-all` to all of these commands. Do not use it for NVMe targets.
It discards the full SSD before the flashing environment connects, and this can take longer than
the 120 s that the host waits (SKILL.md step 9). Use it for eMMC.

The Orin NX/Nano configs set `EXTERNAL_DEVICE="nvme0n1p1"`. Thus `internal` writes the QSPI flash
and the NVMe drive.

Known issues from the 39.2.1 release notes that apply to this tutorial:

- 6244887: On **AGX Orin**, a flash with an RT kernel and a connected display can crash the system.
  Flash without a display, or flash the stock kernel and install the RT kernel by OTA.
- 5748062: The TPM hwrng adds RT latency. This does not apply to the stock Orin defconfig, because
  `HW_RANDOM=m` with `TCG_TPM=y` makes `HW_RANDOM_TPM` unavailable.

## JetPack 6.2.2 (L4T 36.5)

```bash
export JP=6.2.2 TAG=jetson_36.5
export NV=~/Documents/nvidia
export L4T=$NV/nvidia_sdk/JetPack_6.2.2_Linux_JETSON_ORIN_NX_TARGETS/Linux_for_Tegra
export CROSS_COMPILE=$NV/toolchain/aarch64--glibc--stable-2022.08-1/bin/aarch64-buildroot-linux-gnu-
```

Downloads (from <https://developer.nvidia.com/embedded/jetson-linux-r365>):

| File | URL |
|---|---|
| BSP | `https://developer.nvidia.com/downloads/embedded/l4t/r36_release_v5.0/release/Jetson_Linux_r36.5.0_aarch64.tbz2` |
| Sample rootfs | `https://developer.nvidia.com/downloads/embedded/l4t/r36_release_v5.0/release/Tegra_Linux_Sample-Root-Filesystem_r36.5.0_aarch64.tbz2` |
| Toolchain | `https://developer.nvidia.com/downloads/embedded/l4t/r36_release_v3.0/toolchain/aarch64--glibc--stable-2022.08-1.tar.bz2` (extract to `$NV/toolchain/`) |
| `overlay_pcie.tbz2` (Orin NX/Nano only) | `https://developer.nvidia.com/downloads/embedded/l4t/overlay/overlay_pcie.tbz2` |

`overlay_pcie.tbz2` holds replacement BPMP firmware. It fixes an intermittent boot failure of
some Orin NX/Nano modules after a power cycle. Apply it before you flash:
`tar xjf overlay_pcie.tbz2 && sudo cp -r overlay_pcie/Linux_for_Tegra/* "$L4T/"`.

Flash commands. Run them in `$L4T`, with the Jetson in recovery mode:

| Target | Command |
|---|---|
| Orin NX / Nano, NVMe | `sudo ./tools/kernel_flash/l4t_initrd_flash.sh --external-device nvme0n1p1 -c tools/kernel_flash/flash_l4t_t234_nvme.xml -p "-c bootloader/generic/cfg/flash_t234_qspi.xml" --showlogs --network usb0 jetson-orin-nano-devkit internal` |
| Orin NX / Nano, NVMe, Super mode | same, with `jetson-orin-nano-devkit-super` |
| AGX Orin devkit, eMMC | `sudo ./flash.sh jetson-agx-orin-devkit internal` |
| AGX Orin devkit, NVMe | `sudo ./tools/kernel_flash/l4t_initrd_flash.sh --external-device nvme0n1p1 -c tools/kernel_flash/flash_l4t_t234_nvme.xml --showlogs --network usb0 jetson-agx-orin-devkit external` |

NVIDIA does not support a 6.2.2 flash from an Ubuntu 24.04 host, and SDK Manager does not offer it.
The command-line flash often works on 24.04, but NVIDIA does not test it. If possible, use a 22.04
host or a VM with USB passthrough.

## Recovery-mode USB IDs

`lsusb` shows `ID 0955:<id> NVIDIA Corp.` when the module is in recovery mode:

| ID | Module |
|---|---|
| 7023 | AGX Orin 32GB (P3701-0000), 64GB (P3701-0005), Industrial (P3701-0008) |
| 7223 | AGX Orin 32GB (P3701-0004) |
| 7323 | Orin NX 16GB (P3767-0000) |
| 7423 | Orin NX 8GB (P3767-0001) |
| 7523 | Orin Nano 8GB (P3767-0003, -0005) |
| 7623 | Orin Nano 4GB (P3767-0004) |

`0955:7020` means that the Jetson runs Linux (USB device mode). It is not in recovery mode.

## References

- Gitbook writeup: <https://tk233.gitbook.io/notes/tools/nvidia-jetson/getting-started-with-jetson-using-sdk-manager-on-ubuntu-22.04>
- NVIDIA Kernel Customization: <https://docs.nvidia.com/jetson/archives/r39.2.1/DeveloperGuide/SD/Kernel/KernelCustomization.html> (r36.5: replace `r39.2.1` with `r36.5`)
- NVIDIA Real-Time Kernel: <https://docs.nvidia.com/jetson/archives/r39.2.1/DeveloperGuide/SD/Kernel/RealTimeKernel.html>
- NVIDIA Quick Start (flash commands): <https://docs.nvidia.com/jetson/archives/r39.2.1/DeveloperGuide/IN/QuickStart.html>
- Release notes: <https://docs.nvidia.com/jetson/archives/r39.2.1/ReleaseNotes/Jetson_Linux_Release_Notes_r39.2.1.pdf>
- AGX Orin devkit user guide: <https://developer.nvidia.com/embedded/learn/jetson-agx-orin-devkit-user-guide/two_ways_to_set_up_software.html>
