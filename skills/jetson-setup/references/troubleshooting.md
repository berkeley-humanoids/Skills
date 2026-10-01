# Troubleshooting

Find the symptom, then do the fix. Each entry gives its source: the gitbook writeup, the NVIDIA
documentation, or the tests of this tutorial.

## Host and flashing

**`ERROR Flash Jetson Linux - flash: exportfs: Failed to stat /home/.../JetPack_..._TARGETS/: No such file or directory`** (gitbook)

The flash exports the rootfs over NFS. A line in `/etc/exports` points to a workspace that does not
exist. Delete all uncommented lines in `/etc/exports` (`sudoedit /etc/exports`), then flash again.
The flash tool adds and removes its own line.

**The flash stops with `Error: Timeout` / `Device ping failed after RCM boot`, but `lsusb` shows `0955:7035 Jetson device in initrd flashing mode` one or two minutes later** (tests: Orin NX, Yahboom carrier, 256 GB NVMe)

The flashing environment booted, but too slowly. The host waits 120 s. With `--erase-all`, the
flashing environment runs `blkdiscard` on the full NVMe drive **before** it starts the USB
connection to the host. Some SSDs take minutes. The `dmesg` of the Jetson then shows
`nvme ... opcode 0x9 ... timeout, aborting req_op:DISCARD`. Flash again without `--erase-all`.
The flash tool still writes a new GPT and all partitions.

To put the Jetson into recovery mode again without a power cycle, reboot the flashing environment:
`sudo ip a add fe80::2/64 dev <host usb iface>`, then
`sshpass -p root ssh root@fe80::1%<host usb iface> 'busybox reboot -f'`. The Jetson goes into
recovery mode only if the QSPI boot fails or the jumper is in place. If not, do a power cycle with the jumper.

**The flash stops with `Device ping failed after RCM boot`, and `0955:7035` does not appear**

The flashing environment did not boot. Get a serial log from the debug UART. Make sure that
`kernel/Image` is the stock kernel (NVIDIA issue 6244887: an RT kernel can crash during the flash).

**The Jetson does not show in `lsusb`, or shows as `0955:7020`**

The Jetson is not in recovery mode. Disconnect power. Set the FC REC–GND jumper, or hold the Force
Recovery button. Connect power. Use the USB-C port for the flash: on AGX Orin, the port next to the 40-pin header.

**The host `dmesg` shows `Cannot enable. Maybe the USB cable is bad?`, and the flash fails** (NVIDIA release notes, issue 4229251)

Use a different USB port on the host (a rear port, not a hub). Then try a different cable. If the
problem continues, reboot the host.

**SDK Manager cannot connect to the Jetson after the reboot at about 30%** (gitbook)

Wait until the Jetson has fully booted, then click **Install**. If USB still fails, select Ethernet
and enter the IP address of the Jetson.

**SDK Manager does not offer JetPack 6 on an Ubuntu 24.04 host**

JetPack 6 supports only Ubuntu 20.04 and 22.04 hosts. Use a 22.04 host, a VM with USB
passthrough, or JetPack 7.2.1.

**SDK Manager keeps a bad state** (gitbook)

Run `rm -rf ~/.nvsdkm/`.

**The Jetson goes into recovery mode at each power-on**

Remove the FC REC–GND jumper. If the jumper is not the cause, see the next section.

### Board returns to recovery mode after flashing

The log shows `Flash is successful` and the jumper is removed, but each power-on shows `0955:7323`
(tests: Orin NX 16GB, Yahboom carrier). Do these checks in order:

1. **Jumper.** The Jetson reads the jumper at power-on. Disconnect power and USB-C, remove the jumper, and connect power.
2. **Failed boot or requested recovery.** In recovery mode, read the last boot error. This is
   read-only and takes about one minute:

   ```bash
   cd "$L4T" && sudo ./flash.sh --read-info jetson-orin-nano-devkit internal 2>&1 | grep last_boot_error
   ```

   Read it after a cold power-on. `0` means that the jumper holds the Jetson in recovery mode. A
   non-zero value (for example `4294636284`) means that the BootROM tried the QSPI boot and failed.
   After a warm reboot from an RCM session, the value can be `0` even when the QSPI flash is bad.
3. **QSPI erase.** In the flash log, `Erasing 65536 Kibyte @ 0 -- 100 % complete` must come minutes
   after `Starting to flash the QSPI` (3 min 40 s on a good Orin NX). If it comes in milliseconds,
   the chip ignored the erase.
4. **RCM boot.** To use the Jetson now, boot it from the host. RCM boot sends the boot firmware over
   USB and boots the flashed NVMe. It does not read the QSPI flash and it writes nothing:

   ```bash
   sudo ./flash.sh --rcm-boot jetson-orin-nano-devkit nvme0n1p1
   ```

   The Jetson is at `192.168.55.1` after about 25 s. RCM boot uses `$L4T/kernel/Image`, not the
   extlinux default. To test the RT kernel, copy the RT Image to `kernel/Image` for that boot only.
   Put the stock Image back before you flash.
5. **QSPI write protection.** On the Jetson after RCM boot, run `sudo python3 qspi_status.py`
   (from `scripts/`). The script reads the registers of the flash chip and changes nothing.
   `BP3..0` not `0000`, or `WPSEL=1`, means that the chip is block-protected. On Macronix chips, a
   chip erase does nothing when a block is protected. Each flash then writes over old data, and the
   BootROM finds a corrupt BCT. The SPI-NOR driver of JetPack 7.2.1 cannot read or clear this
   protection on this chip (`flash_unlock -i` returns error 95).

   Someone set the protection on purpose, for example in a factory image of the vendor. Only the
   owner can decide to clear it. Ask the module or carrier vendor first. After the protection is
   clear, flash only the QSPI and make sure that the erase takes minutes:

   ```bash
   sudo ./l4t_initrd_flash.sh --qspi-only jetson-orin-nano-devkit internal
   ```

**JetPack 7, AGX Orin: the system crashes during or after the flash of an RT kernel** (NVIDIA release notes, issue 6244887)

Disconnect the display during the flash. Or flash the stock kernel and install the RT kernel by
OTA. The OTA RT kernel has no gs_usb, so you must build gs_usb separately.

**JetPack 6.2.2, Orin NX/Nano: the Jetson sometimes does not boot after a power cycle**

Apply NVIDIA's `overlay_pcie.tbz2` before you flash (see `versions.md`).

## Kernel build

**`source_sync.sh` cannot fetch a tag**

Make sure that the tag name is correct. For 39.2.1, the tag is `jetson_39.2.1`. The release notes
give `jetson_39.2.1_GA`, which does not exist. To list the tags, run
`git ls-remote --tags https://gitlab.com/nvidia/nv-tegra/linux-nv-oot.git`. An incomplete clone
blocks the next sync. Delete the directory of that repository, then sync again.

**The kernel has no `CONFIG_PREEMPT_RT=y`**

On kernel 6.8, `PREEMPT_RT` depends on `EXPERT`, and `EMBEDDED` does not select `EXPERT`. NVIDIA's
release notes (issue 5748062) describe a `generic_rt_build.sh` without `--enable EXPERT`. The
39.2.0 and 39.2.1 scripts have it. If `grep -c 'enable EXPERT' source/generic_rt_build.sh` shows 0,
add `--enable EXPERT` to the two `scripts/config` calls in `enable_rt()`. `build_kernel.sh` stops
with an error in this case.

**`make modules` fails with a PREEMPT_RT error from the display driver**

Set `IGNORE_PREEMPT_RT_PRESENCE=1`. `build_kernel.sh` sets it.

**`make modules` builds against the wrong kernel or cannot find the headers**

Set `KERNEL_HEADERS` to `source/kernel/<kernel dir>`. If `KERNEL_HEADERS` is not set, the Makefile
uses `/lib/modules/$(uname -r)/build` of the host.

**`install_kernel.sh` compiles or asks config questions**

`sudo` removed `CROSS_COMPILE`. Run the script with `sudo -E`.

## On the Jetson

**No CAN interface for the USB-CAN adapter**

1. Run `lsusb`. The adapter must show. candleLight/gs_usb adapters usually show as `1d50:606f`.
2. Run `modinfo gs_usb`. If the module is not found, the Jetson runs the stock kernel. Make sure
   that `uname -r` ends in `-rt-tegra`. If not, set `DEFAULT real-time` in `/boot/extlinux/extlinux.conf` and reboot.
3. Run `sudo modprobe gs_usb`, then `ip -details link show type can`.
4. If `mttcan` is `can0`, the adapter is `can1`.

**The CAN interface is up, but no frames arrive**

Make sure that all nodes use the same bitrate and that each end of the bus has a 120 Ω terminator.
Look for bus-off and error counters in `ip -details -statistics link show can0`. A node that sends
with no other node on the bus gets no acknowledgement and becomes error-passive.

**No `/dev/ttyUSB0` for a CH340/CH341 adapter** (gitbook)

Run `sudo dmesg --follow`, then disconnect and connect the adapter. The line
`interface 0 claimed by ch341 while 'brltty' sets config #1` means that `brltty` took the device.
Run `sudo systemctl stop brltty && sudo systemctl disable brltty`. If the problem continues, run `sudo apt remove brltty`.

**Permission denied on `/dev/ttyUSB*` or `/dev/ttyACM*`**

Add your user to `dialout` (`sudo usermod -aG dialout $USER`), then log in again. Or add a udev
rule, such as `KERNEL=="ttyACM[0-9]*",MODE="0666"` in `/etc/udev/rules.d/50-ttyacm.rules`.

**The Jetson boots the stock kernel after `apt upgrade`**

The upgrade of `nvidia-l4t-kernel` set `DEFAULT` in `/boot/extlinux/extlinux.conf` to the stock
kernel. Set `DEFAULT real-time` and reboot. To prevent this, hold the kernel packages (SKILL.md step 11).
