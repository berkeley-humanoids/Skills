---
name: jetson-setup
description: Step-by-step tutorial to flash and set up an NVIDIA Jetson Orin (AGX Orin, Orin NX, Orin Nano, and P3768-compatible carriers such as Seeed reComputer and Yahboom) from an Ubuntu host with JetPack 7.2.1 or 6.2.2 and a custom PREEMPT_RT kernel with the gs_usb (USB-CAN) and ch341 (CH340/CH341 USB-serial) drivers. Covers SDK Manager and command-line flashing, recovery mode, headless first boot, and device checks for RT, CAN, and serial. Use this skill when the user wants to flash or set up a Jetson, install JetPack or Jetson Linux (L4T), build or customize a Jetson kernel, enable the real-time kernel, or fix USB-CAN (no can0, gs_usb missing) or /dev/ttyUSB (CH341, brltty) problems on a Jetson, even if they do not say "tutorial".
---

# Jetson Setup: JetPack, RT Kernel, USB-CAN

This tutorial flashes a Jetson Orin with a custom kernel. The kernel adds three items that stock
JetPack 6 and 7 do not have:

- PREEMPT_RT (real-time) preemption.
- `gs_usb`, the driver for candleLight/gs_usb USB-CAN adapters.
- `ch341`, the driver for CH340/CH341 USB-serial adapters.

The steps follow the gitbook writeup
[Getting Started with Jetson Using SDK Manager on Ubuntu 22.04](https://tk233.gitbook.io/notes/tools/nvidia-jetson/getting-started-with-jetson-using-sdk-manager-on-ubuntu-22.04)
and the NVIDIA Jetson Linux Developer Guide. Each step tells where the two differ.

Tested on 2026-09-30: JetPack 7.2.1, Orin NX 16GB, Yahboom (P3768-compatible) carrier, 256 GB
NVMe, Ubuntu 24.04 host. Steps 1–9 and all step 10 checks passed. For step 10, the host booted the
Jetson over USB, because the QSPI flash of that module was write-protected before setup. See
"Board returns to recovery mode after flashing" in `references/troubleshooting.md`.

## How to run this tutorial

Do the steps in order. Each step ends with a check. Do not start the next step until the check passes.

As an agent, stop and ask the user at these points:

| Point | Reason |
|---|---|
| Root access (steps 1, 2, 6, 7, 9) | These steps use `sudo`. If `sudo -n true` fails, ask the user for a temporary rule: `! echo "$USER ALL=(ALL) NOPASSWD: ALL" \| sudo tee /etc/sudoers.d/99-jetson-flash`. Delete the rule at the end. |
| Recovery mode (step 9) | A person must set the jumper or push the buttons. |
| Erase (step 9) | The flash erases the target storage and the QSPI flash. Get confirmation of the board and the storage device. |
| User account (step 7) | Get the username. Do not choose a permanent password. |
| QSPI write protection (step 9) | If the QSPI flash is block-protected, stop. Only the owner can decide to remove a protection that someone set on purpose. |

The scripts in `scripts/` do the long steps. Read each script before you run it.

## 0. Choose the JetPack version

| | JetPack 7.2.1 (L4T 39.2.1) | JetPack 6.2.2 (L4T 36.5) |
|---|---|---|
| Jetson OS | Ubuntu 24.04, kernel 6.8, CUDA 13.2 | Ubuntu 22.04, kernel 5.15 |
| Host OS for flashing | Ubuntu 22.04 or **24.04** | Ubuntu 20.04 or 22.04 only |
| Maturity on Orin | First 7.x release for Orin (June 2026). Isaac ROS: not released yet. | Mature. The gitbook uses it. |

Use 7.2.1, unless the Jetson must run Ubuntu 22.04 or a stack that needs JetPack 6 (for example,
Isaac ROS 3). SDK Manager does not offer JetPack 6.2.2 on an Ubuntu 24.04 host. To see the host
version, run `lsb_release -rs`.

Set `JP`, `TAG`, `NV`, `L4T`, and `CROSS_COMPILE` from `references/versions.md`. Set `SKILL` to
the directory of this skill. All later commands use these variables.

## 1. Prepare the host

1. Install the build tools (the gitbook list and the NVIDIA prerequisites):

   ```bash
   sudo apt install git build-essential bc flex bison libssl-dev libelf-dev libncurses-dev zstd dpkg-dev
   ```

2. Make sure that `$NV` has 40 GB or more of free space: `df -h ~`.
3. Make sure that the host can reach gitlab.com over HTTPS or git port 9418. `source_sync.sh` tries GitLab first.
4. Find the active NFS exports:

   ```bash
   grep -v '^\s*#' /etc/exports | grep -v '^\s*$'   # expect no output
   ```

5. Delete each line in `/etc/exports` that points to a path that does not exist. The flash uses NFS,
   and a stale line makes it fail with `exportfs: Failed to stat ...`.

**Check:** `git --version && make --version` succeed. No line in `/etc/exports` points to a missing path.

## 2. Get Jetson Linux (BSP and rootfs)

Use one of the two options. Both make `$L4T` with a full `rootfs/`.

### Option A: SDK Manager (the gitbook path, GUI)

1. Download SDK Manager from <https://developer.nvidia.com/sdk-manager>.
2. Install it: `sudo apt install ./sdkmanager_*_amd64.deb`.
3. Start SDK Manager and log in with an NVIDIA developer account.
4. In STEP 01, select the target hardware and the JetPack version. The Jetson can stay disconnected.
5. In STEP 02, select only **Host SDK Components** and **Jetson Linux**.
6. Set the download path to `~/Downloads/nvidia/sdkm_downloads/` and the target path to `$NV/nvidia_sdk/`.
7. At the end, SDK Manager tries to connect to the board. Skip that step. You flash in step 9.

### Option B: command line (NVIDIA Quick Start)

```bash
mkdir -p ~/Downloads/nvidia/sdkm_downloads "$(dirname "$L4T")"
cd ~/Downloads/nvidia/sdkm_downloads
wget <BSP URL> <sample rootfs URL>        # URLs in references/versions.md
sha1sum *.tbz2                            # compare with release_sha_hashes.txt (JetPack 7)
tar xf Jetson_Linux_*_aarch64.tbz2 -C "$(dirname "$L4T")"
sudo tar xpf Tegra_Linux_Sample-Root-Filesystem_*_aarch64.tbz2 -C "$L4T/rootfs/"
cd "$L4T"
sudo ./tools/l4t_flash_prerequisites.sh
sudo ./apply_binaries.sh
```

The rootfs extract uses `sudo tar xpf`, because the files must keep root ownership and permissions.

**Check:** `cat $L4T/rootfs/etc/nv_tegra_release` shows the expected release, for example `R39 (release), REVISION: 2.1`.

## 3. Get the toolchain

Download the toolchain from `references/versions.md` and extract it:

```bash
tar xf x-tools.tbz2 -C "$NV"                                          # JetPack 7
mkdir -p "$NV/toolchain" && tar xf aarch64--glibc--stable-2022.08-1.tar.bz2 -C "$NV/toolchain"   # JetPack 6
```

**Check:** `${CROSS_COMPILE}gcc --version` shows GCC 13.2 (JetPack 7) or GCC 11.3 (JetPack 6).

## 4. Sync the kernel sources

```bash
cd "$L4T/source"
./source_sync.sh -k -s -e -t "$TAG"
```

- `-k` syncs only the repositories that the build uses: kernel, NVIDIA out-of-tree (OOT) modules,
  and device tree. The gitbook omits `-k` and also syncs multimedia sources.
- `-s` makes shallow clones, which is much faster. `-e` stops at the first error.
- Use the tag from `references/versions.md`. For 39.2.1, the tag is `jetson_39.2.1`. The release
  notes give `jetson_39.2.1_GA`, which does not exist.

**Check:** The log shows `Successfully synced ...` for each repository, and
`$L4T/source/kernel/kernel-noble` (JetPack 7) or `kernel-jammy-src` (JetPack 6) exists.

## 5. Build the RT kernel with USB-CAN and CH341

```bash
"$SKILL/scripts/build_kernel.sh" "$L4T" 2>&1 | tee "$L4T/../build_kernel.log"
```

The script does the gitbook steps "Configure the Kernel" and "Building the Kernel". It enables RT
with NVIDIA's `./generic_rt_build.sh "enable"` and adds the two drivers to
`kernel/<kernel dir>/arch/arm64/configs/defconfig`. This is the gitbook edit:

```diff
 CONFIG_CAN=m
+CONFIG_CAN_GS_USB=m
 ...
 CONFIG_USB_SERIAL=m
+CONFIG_USB_SERIAL_CH341=m
```

Then it builds the kernel, the NVIDIA OOT modules, and the DTBs. It stops if `.config`
does not have `CONFIG_PREEMPT_RT=y`, `CONFIG_CAN_GS_USB=m`, and `CONFIG_USB_SERIAL_CH341=m`.
A second run of the script is safe.

The build takes about 5 minutes on a 24-core host.

**Check:** The script ends with `Built kernel <release>`, and the release ends in `-rt-tegra`.

## 6. Install the kernel into Linux_for_Tegra

```bash
sudo -E "$SKILL/scripts/install_kernel.sh" "$L4T"
```

`sudo -E` keeps `CROSS_COMPILE`. Without it, kbuild finds the host compiler and reconfigures the kernel tree.

The script installs the RT kernel next to the stock kernel. The layout is the same as in the NVIDIA
RT kernel packages:

| File in `$L4T/rootfs/boot/` | Content |
|---|---|
| `Image` | stock kernel, `LABEL primary` |
| `Image.real-time` | RT kernel, `LABEL real-time`, set as `DEFAULT` |
| `initrd` | one initrd with the modules of both kernels |

The script also installs the modules, adds the `real-time` entry to `rootfs/boot/extlinux/extlinux.conf`,
and rebuilds the initrd with `./tools/l4t_update_initrd.sh`.

**This step differs from the gitbook.** The gitbook copies the RT Image to `$L4T/kernel/Image`.
The flash tool also boots `kernel/Image` as the flashing environment: a Linux initrd that runs on
the Jetson over USB during the flash. NVIDIA reports that a flash with an RT kernel can crash
(issue 6244887). A stock `kernel/Image` prevents this and gives the Jetson a stock fallback boot
entry. The script stops if `kernel/Image` is an RT kernel.

The script does not install the DTBs, because the prebuilt DTBs in `$L4T/kernel/dtb/` are the same.
To install changed DTBs, set `INSTALL_DTBS=1` (the gitbook step "(Optionally) Build DTB").

**Check:** The script ends with `Installed kernel <release>`.

## 7. (Headless only) Create the user before flashing

If the Jetson has no monitor and keyboard, create the first user in the rootfs:

```bash
cd "$L4T"
sudo ./tools/l4t_create_default_user.sh -u <username> -p <temporary password> -n <hostname> --accept-license
```

The Jetson then boots to a login prompt, and you can connect with SSH. Tell the user to change the
temporary password with `passwd` at the first login.

To use the first-boot wizard (oem-config) on a DisplayPort monitor, as in the gitbook, skip this
step. In SDK Manager, the pre-config option of the flash dialog creates the user.

## 8. Check before flashing

```bash
sudo "$SKILL/scripts/check_build.sh" "$L4T"
```

The script prints one `PASS` or `FAIL` line for each check: kernel config, boot layout, modules, and initrd.

**Check:** Each line shows `PASS`, and the exit code is 0. If a line shows `FAIL`, fix the related step before you flash.

## 9. Enter recovery mode and flash

### Connect and enter Force Recovery Mode

| Board | Steps |
|---|---|
| AGX Orin devkit | Connect the host to the **USB-C port next to the 40-pin header**. Hold the **Force Recovery** button (middle). Push and release **Power**, or connect power. Release Force Recovery. |
| Orin NX / Nano on a P3768 or compatible carrier (NVIDIA devkit, Seeed reComputer J401, Yahboom) | Disconnect power. Put a jumper across **FC REC** and **GND** on the button header under the module. Connect the host to the USB-C port of the carrier. Connect power. |

**Check:** `lsusb | grep 0955` shows the recovery ID of the module, for example `0955:7323` for
Orin NX 16GB. `references/versions.md` lists all IDs.

- If it shows `0955:7020`, the Jetson booted Linux. Do the recovery steps again.
- If it shows nothing, or the host `dmesg` shows `Cannot enable. Maybe the USB cable is bad?`,
  use a different USB port on the host or a different cable.

### Flash

**Warning:** Get confirmation from the user before you flash. The flash erases the target storage
(NVMe or eMMC) and the QSPI flash.

**Option A: SDK Manager (gitbook).**

1. Start SDK Manager. It finds the Jetson on USB.
2. In STEP 02, select all components. SDK Manager shows **OS image ready**, because it finds the kernel from step 6.
3. In the dialog, set the username and password (or pre-config) and the storage device: NVMe for
   Orin NX/Nano, eMMC or NVMe for AGX Orin.
4. At about 30%, the Jetson reboots into Linux. When it has fully booted, click **Install** to install the SDK components.
5. If SDK Manager cannot connect over USB, select Ethernet and enter the IP address of the Jetson.

**Option B: command line.** Run the flash command for the board from `references/versions.md`, for example:

```bash
cd "$L4T"
sudo ./l4t_initrd_flash.sh jetson-orin-nano-devkit internal 2>&1 | tee ../flash.log
```

- Do not use `--erase-all` for NVMe targets. NVIDIA's Quick Start uses it, but then the flashing
  environment discards the full SSD before it connects to the host. Some SSDs take minutes, and
  the host stops waiting after 120 s. The flash then fails with `Device ping failed after RCM boot`.
  Without `--erase-all`, the flash tool still writes a new GPT and all partitions.
- On third-party carriers, use the plain config (`jetson-orin-nano-devkit`) first. Use the `-super`
  config (for example `jetson-orin-nano-devkit-super`) for the Super power modes only on carriers
  rated for them, such as the NVIDIA devkit.
- For JetPack 7 on AGX Orin, disconnect the display before you flash an RT kernel (NVIDIA issue 6244887).
- Examine the QSPI erase time in the log. `Erasing 65536 Kibyte @ 0 -- 100 % complete` must come
  minutes after `Starting to flash the QSPI` (about 3.5 minutes on Orin NX). If the two lines come
  at the same time, the QSPI flash is write-protected, and the Jetson cannot boot from it. See
  "Board returns to recovery mode after flashing" in `references/troubleshooting.md`.

The flash takes about 10 minutes. At the end, the log shows `Flash is successful`, and the Jetson reboots.

On Orin NX/Nano, remove the FC REC jumper after the log shows `Step 3: Start the flashing process`.
The Jetson reads the jumper only at power-on and reset. If the jumper is in place when the flash
tool reboots the Jetson, the Jetson goes into recovery mode again (`0955:7323`). Then disconnect
power, remove the jumper, and connect power.

**Check:** In about 2 minutes, `lsusb` shows `0955:7020`, and `ping 192.168.55.1` gets a reply. If
the Jetson is in recovery mode again without the jumper, the boot from QSPI failed. See
"Board returns to recovery mode after flashing" in `references/troubleshooting.md`.

## 10. First boot and verification

Connect to the Jetson over the USB-C cable of the flash. The Jetson is `192.168.55.1`, and the host
is `192.168.55.100`. You can also use Ethernet, or a monitor and keyboard.

```bash
ssh <username>@192.168.55.1
```

Copy the target check to the Jetson and run it:

```bash
scp "$SKILL/scripts/check_target.sh" <username>@192.168.55.1:
ssh -t <username>@192.168.55.1 'sudo ./check_target.sh'
```

The script shows the L4T release and the kernel. Then it prints one `PASS` or `FAIL` line for each
check: RT kernel, `gs_usb`, `ch341`, `can_raw`, NVIDIA GPU driver, and `brltty`. It also lists the CAN
interfaces with their drivers, and the USB serial ports.

**Check:** Each line shows `PASS`.

### Test a USB-CAN adapter

Connect the gs_usb adapter (candleLight firmware, CANable 2.0, or similar). Then find its interface
and start it. Use the interface that shows the driver `gs_usb`:

```bash
sudo apt install can-utils
ip -details link show type can                       # find the adapter; driver gs_usb
sudo ip link set can0 up type can bitrate 1000000
candump can0                                         # in a second shell: cansend can0 123#DEADBEEF
```

- The Orin module also has a native CAN controller (`mttcan`). On the Yahboom carrier, `mttcan`
  loads at boot and becomes `can0`, so the USB-CAN adapter becomes `can1`. For fixed names, add a
  udev rule or a systemd `.link` file that matches `DRIVERS=="gs_usb"`.
- To receive without an effect on the bus, add `listen-only on` to the `ip link set` command.
- A sent frame gets an acknowledgement only from another node on the bus. Each end of the bus
  must have a 120 Ω terminator. With no other node, add `loopback on` to the `ip link set` command.
  On the CANable 2.0, `loopback on` together with `listen-only on` sends no frames.

### Test a CH340/CH341 USB-serial adapter

Connect the adapter. It must show as `/dev/ttyUSB0`. If it does not, watch the kernel log while you
disconnect and connect the adapter again:

```bash
sudo dmesg --follow
```

If the log shows `usbfs: interface 0 claimed by ch341 while 'brltty' sets config #1` and then
`ch341-uart converter now disconnected from ttyUSB0`, the `brltty` braille service took the device.
Stop and disable `brltty`. If the problem continues, remove `brltty`:

```bash
sudo systemctl stop brltty && sudo systemctl disable brltty
sudo apt remove brltty
```

By default, only root can use serial devices. For a CDC-ACM device, such as the Recoil USB-CAN
adapter (`/dev/ttyACM*`), add a udev rule, then connect the device again:

```bash
echo 'KERNEL=="ttyACM[0-9]*",MODE="0666"' | sudo tee /etc/udev/rules.d/50-ttyacm.rules
```

## 11. Finish the setup on the Jetson

1. **Keep the RT kernel as the default.** When `apt upgrade` installs a newer `nvidia-l4t-kernel`,
   it can set `DEFAULT` in `/boot/extlinux/extlinux.conf` back to the stock kernel (NVIDIA Kernel
   Customization guide). Hold the kernel packages:

   ```bash
   sudo apt-mark hold $(dpkg-query -W -f='${db:Status-Abbrev} ${Package}\n' 'nvidia-l4t-*kernel*' | awk '$1 == "ii" {print $2}')
   apt-mark showhold
   ```

   If you upgrade these packages later, set `DEFAULT real-time` again.

2. **Install the JetPack SDK components** (CUDA, cuDNN, TensorRT, VPI) if SDK Manager did not
   install them: `sudo apt update && sudo apt install nvidia-jetpack`. To examine the result, run
   `sudo apt show nvidia-jetpack -a` and `nvcc --version`. `nvcc` is in `/usr/local/cuda/bin`,
   which is not in `PATH` by default.

3. **Delete the temporary sudo rule** on the host, if you added it: `sudo rm /etc/sudoers.d/99-jetson-flash`.

For RT latency tests and tuning, read `references/rt-tuning.md`. For flash failures and other
problems, read `references/troubleshooting.md`.

## Other paths

- **RT kernel without USB-CAN:** NVIDIA supplies the RT kernel as OTA Debian packages
  (`deb https://repo.download.nvidia.com/jetson/rt-kernel r39.2 main`, then
  `nvidia-l4t-rt-kernel nvidia-l4t-rt-kernel-headers nvidia-l4t-rt-kernel-oot-modules nvidia-l4t-display-rt-kernel nvidia-l4t-rt-kernel-nvgpu`).
  These packages use the stock defconfig, so they do not have gs_usb or ch341.
- **Build on the Jetson:** The same steps work on the Jetson without `CROSS_COMPILE`. Use
  `sudo nv-update-initrd` instead of `l4t_update_initrd.sh`.
- **Reset SDK Manager:** `rm -rf ~/.nvsdkm/` deletes all SDK Manager state.
