# nothrottle

**Lock your Android clocks and stop the vendor thermal daemon from throttling you - on a rooted phone, without unlocking the bootloader or touching dm-verity.**

```
su -c 'sh nothrottle doctor'     # see what your phone exposes
su -c 'sh nothrottle apply'      # pin clocks, stop vendor thermal, start guard
su -c 'sh nothrottle restore'    # undo everything
```

> Root required (Magisk or KernelSU). Nothing is flashed, `/system` and `/vendor` are never written, verified boot stays green.

## The problem

Most phones do not throttle in the kernel. They run a userspace daemon - `thermal_core` on MediaTek, `thermal-engine` on Qualcomm, `thermald` on Exynos - that watches temperature and pushes a **clock limit** through the power HAL.

That is why the usual tricks fail:

```
echo 2400000 > scaling_max_freq   # looks fine, then drops back to 2200000
```

The kernel itself clamps the value while the daemon keeps requesting a lower one. Disabling thermal zones does not help either, because the daemon does not need them.

`nothrottle` stops the daemon (`stop thermal_core`), pins the clusters to `cpuinfo_max_freq` with the `performance` governor, raises the GPU floor, and keeps a guard that restores stock temperatures get dangerous.

## What it does

| Step | Detail |
|---|---|
| CPU | every `policy*` pinned to `cpuinfo_max_freq`, `performance` governor when available |
| GPU | devfreq/KGSL node detected, floor raised to `GPU_MIN_PCT` of max (or pinned with `--gpu-max`) |
| Vendor thermal | known daemon for the SoC family stopped via `stop <service>` |
| Thermal zones | MTK profile disables CPU/GPU/SOC zones (optional on other vendors) |
| Guard | background loop, restores stock when SOC or battery crosses the limit |
| Restore | full state saved first, `restore` puts every value back |

Nothing is permanent: a reboot clears all of it.

## Requirements

- Root: Magisk, KernelSU, or a userspace-root exploit (KernelSU via DirtyFrag works too)
- Android 10+ (uses `cmd package compile`, `getprop init.svc.*`)
- `sh` + toybox, no busybox needed

## Install

```sh
git clone https://github.com/<you>/nothrottle
adb push nothrottle /data/local/tmp/nothrottle
adb shell su -c 'sh /data/local/tmp/nothrottle/nothrottle doctor'
```

Read the doctor output once. If the profile picked the wrong vendor, copy a profile in `profiles/` and adjust.

## Commands

| Command | What it does |
|---|---|
| `doctor` | dumps policies, GPU nodes, thermal zones, cooling devices, thermal services |
| `apply [--gpu-max] [--no-zones] [--force]` | lock + stop thermal daemon + start guard |
| `status` | current governor, min/max, guard pid, service state |
| `restore` | put back every saved value, restart daemons, kill guard |
| `debloat <list> [--restore]` | disable/enable packages from a list file |
| `aot <pkg>...` | AOT compile apps (`cmd package compile -m speed`) |
| `animate [scale]` | animation scales, default `0.5` |
| `install-boot` / `uninstall-boot` | optional `/data/adb/service.d` hook |

Environment: `NOTHROTTLE_SOC` / `NOTHROTTLE_BAT` (millidegrees) override the guard limits, `NOTHROTTLE_STATE` moves the state directory.

## Guard

`apply` starts `guard.sh`. Every 20 s it reads the `soc_max` and `battery` zones. When either crosses the limit it calls `restore`, so the phone falls back to stock clocks, stock governor, thermal daemon running, zones enabled. Default: **80 C SOC / 47 C battery**.

Raise it if you accept more heat:

```sh
NOTHROTTLE_SOC=90000 NOTHROTTLE_BAT=50000 su -c 'sh nothrottle apply'
```

## Device support

| SoC family | Thermal daemon | Status |
|---|---|---|
| MediaTek | `thermal_core` | tested on Dimensity 6300 (SM-A066B, Android 16) |
| Qualcomm | `thermal-engine` | profile included, needs reports |
| Exynos | `thermald` | profile included, needs reports |
| other | none found | generic profile only |

Snapdragon and Exynos kernels often do real mitigation in `tsens`/thermal zones, so those profiles intentionally do **not** disable zones. The guard is your safety net.

## Adding a device

1. Run `doctor` and save the output.
2. Find the running thermal service: `getprop | grep init.svc | grep -i thermal`.
3. Copy `profiles/mtk.conf`, change `SVC_THERMAL`, `ZONES_DISABLE`, limits.
4. Test `apply` -> `status` -> `restore` and check clocks actually return.
5. Open a PR with the doctor output and what changed.

## Safety

- Heat is real. Pinning `performance` removes the OS thermal policy for CPU; the guard is the only thing left. Do not game while charging.
- Stopping the vendor daemon also removes its charging/battery policy on some phones.
- Root may break Samsung Pay / Secure Folder even without tripping Knox. Warranty bit stays `0` because nothing is flashed.
- This is not a magic ROM. It cannot fix a slow eMMC, a weak GPU, or 3 GB of RAM.

See [docs/how-it-works.md](docs/how-it-works.md) and [docs/risks.md](docs/risks.md).

## FAQ

**Does this unlock my bootloader?** No. It needs root, nothing else.
**Does it survive a reboot?** No. Root itself may not survive; re-run `apply` after boot.
**Why not just disable thermal zones?** On MTK the daemon ignores them. On Qualcomm they are the real mitigation - disabling them is how phones cook.
**Will it work on my phone?** Run `doctor`. If it finds policies and a throttle daemon, the generic/MTK path works.

## License

MIT. Use at your own risk.
