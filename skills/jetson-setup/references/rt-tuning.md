# RT latency tests and tuning

Read this page after the RT kernel boots (SKILL.md step 10). Sources: the gitbook page
[Performance Testing of Jetson Devices](https://tk233.gitbook.io/notes/tools/nvidia-jetson/performance-testing-of-jetson-devices)
and NVIDIA's [Installing Real-Time Kernel](https://docs.nvidia.com/jetson/archives/r39.2.1/DeveloperGuide/SD/Kernel/RealTimeKernel.html).
NVIDIA supplies the RT kernel at Developer Preview quality.

## Measure

Compare the maximum latency of the RT kernel and the stock kernel under the same load:

```bash
sudo apt install rt-tests stress
sudo jetson_clocks                       # lock clocks at maximum
stress --cpu 8 --io 8 --vm 8 &           # background load (match --cpu to the core count)
sudo cyclictest --smp -m -p 95 --policy=fifo -i 1000 -D 2h -q
```

- The gitbook command is `sudo cyclictest -t 8 -D 2h --policy=fifo`. The command above adds a
  thread priority (`-p 95`), locked memory (`-m`), and one thread on each core (`--smp`). Orin NX
  16GB and AGX Orin 32GB have 8 cores. AGX Orin 64GB has 12.
- Run for 2 hours or more (`-D 2h`). Short runs miss rare worst cases.
- Read the `Max:` column. For RT, the average is not important.
- NVIDIA measures with `rtla timerlat top`, which also shows the source of the latency. The RT
  build enables its tracer (`TIMERLAT_TRACER`).

## Tune

The items are in order of effect. Measure again after each item.

1. **Performance mode.** Select MAXN (or MAXN SUPER) with `sudo nvpmodel -m <id>`, then run
   `sudo jetson_clocks`. `sudo nvpmodel -q` shows the current mode. `/etc/nvpmodel.conf` lists the IDs.
2. **RT throttling** (NVIDIA). Run `sudo sysctl kernel.sched_rt_runtime_us=-1` and
   `sudo sysctl kernel.timer_migration=0`. To keep the values after a reboot, put them in `/etc/sysctl.d/`.
3. **CPU isolation** (NVIDIA). Add the parameters to `APPEND` in `/boot/extlinux/extlinux.conf`.
   This example isolates cores 4–7 of 8:

   ```text
   rcu_nocb_poll rcu_nocbs=4-7 nohz=on nohz_full=4-7 kthread_cpus=0-3 irqaffinity=0-3 isolcpus=managed_irq,domain,4-7
   ```

   `nohz_full` and `rcu_nocbs` need `CONFIG_NO_HZ_FULL=y` and `CONFIG_RCU_NOCB_CPU=y`. Add
   `--enable NO_HZ_FULL --enable RCU_NOCB_CPU` next to the gs_usb line in `build_kernel.sh`, then
   build again. Pin the application to the isolated cores (`taskset -c 4-7`, or `sched_setaffinity`).
4. **UEFI runtime services.** They are on by default and add latency. NVIDIA recommends that RT
   loads do not use them. Remove `efi=runtime` from the kernel command line.
5. **TPM hwrng thread** (NVIDIA issue 5748062). If `ps aux | grep hwrng` shows the thread, move it
   to a non-RT core: `sudo taskset -p -c 0 <pid>`. The stock Orin defconfig does not build the TPM
   hwrng, so this item usually does not apply.

NVIDIA's reference result (Jetson Thor, isolated cores, heavy load): a maximum of about 26 µs on
the isolated cores and 96 µs on the loaded cores.
