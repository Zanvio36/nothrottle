# How it works

Android clocks are controlled in layers. Throttling happens at whichever layer the vendor chose, and that is different per SoC family.

## Layers

```
userspace daemon (thermal_core / thermal-engine / thermald)
        | writes limits through power HAL
kernel power driver (mtk power / qcom perf / exynos)   <-- clamps scaling_max_freq
        |
cpufreq policy (policy0, policy6 ...)
```

Thermal zones and cooling devices are a separate tree:

```
/sys/class/thermal/thermal_zone*/temp   temperature sensors
/sys/class/thermal/cooling_device*/     devices the kernel can push (fans, chargers, backlight)
```

On a well-built SoC the kernel registers the CPU as a cooling device, so `trip_point` -> `cooling_device` -> cpufreq is a graph the kernel walks by itself. Disabling the zone then really stops throttling.

On many MediaTek phones the CPU is **not** a cooling device. The graph only contains charger, backlight and GPU. The CPU limit comes from the userspace daemon instead, which is why:

- disabling `cpu_*` zones changes nothing;
- writing `scaling_max_freq` snaps back a second later;
- freezing the daemon fixes it, but its binder clients may stall.

Check which case you have:

```sh
for c in /sys/class/thermal/cooling_device*; do cat $c/type; done
```

If you see `cpufreq` or `cpu-cluster` there, the kernel does real mitigation. Leave the zones alone and only stop the userspace daemon, if any.

## What apply does

1. **Save state** - for every policy: governor, min, max; for the GPU node: governor, min, max; for every zone with a writable `mode`; for every thermal service that is running.
2. **Pin CPU** - `performance` governor when the policy offers it, then `scaling_min_freq = scaling_max_freq = cpuinfo_max_freq`. If `performance` is missing, min is raised to max under the current governor, which has the same effect.
3. **Pin GPU** - devfreq nodes are scanned for names containing `gpu`, `mali`, `kgsl`, `adreno`, `g3d`. The floor is raised to 50% of max by default, or the `performance` governor is used with `--gpu-max`.
4. **Disable zones** - only when the profile says so, matched by zone `type` glob (`cpu_*`, `gpu*`, `soc*`).
5. **Stop the daemon** - `stop <service>` through init, so init does not restart it (it stays stopped until `start`).
6. **Start the guard** - `guard.sh` in the background, logging to `nothrottle.log`.

`stop` is better than `kill` or `freeze`: init owns the service, `stop` records the state, `start` brings it back cleanly, and there is no binder client left talking to a frozen process.

## Why the guard exists

After `apply` the CPU has no thermal policy at all. That is the point. But it also means the phone will happily run at 2.4 GHz until the battery complains.

The guard restores **everything** - not just the governor - because a half-restore is worse than none:

- governor back to `sugov_ext`/`schedutil`
- min/max back to the saved values
- zones back to `enabled`
- `thermal_core` started again
- guard exits

`restore` accepts `NOTHROTTLE_FROM_GUARD=1` so the guard does not try to kill itself.

## State format

`/data/local/tmp/nothrottle/state` is pipe separated:

```
policy|/sys/devices/system/cpu/cpufreq/policy0|sugov_ext|2000000|500000
gpu|/sys/class/devfreq/13000000.mali|simple_ondemand|1100000000|390000000
zone|/sys/class/thermal/thermal_zone0|enabled
svc|thermal_core
```

`restore` replays it in order: policy limits, GPU, zones, services.

## Where it deliberately stops

- No writes to `/system`, `/vendor`, `/boot` - so no dm-verity, no OTA break, no Knox efuse.
- No kernel modules, no overclock, no undervolt.
- No scheduler tuning: `sched_*` knobs are undocumented per vendor and often ignored.
