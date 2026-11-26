# nothrottle

**Lock your Android clocks and stop the vendor thermal daemon from throttling you - on a rooted phone, without unlocking the bootloader or touching dm-verity.**

```
su -c 'sh nothrottle doctor'          # see what your phone exposes
su -c 'sh nothrottle apply --game'    # pin clocks + GPU, stop vendor thermal, start guard
su -c 'sh nothrottle restore'         # undo everything
```

> Root required (Magisk or KernelSU). Nothing is flashed, `/system` and `/vendor` are never written, verified boot stays green.

> **Tested on exactly one phone:** Samsung Galaxy A06 5G (SM-A066B, Dimensity 6300, Android 16, One UI 8.5).
> Every other device, including other Samsungs, is untested. The code is written to be portable - the profile system is the only device-specific part - but nobody has run it there yet. Run `doctor` first.

## The problem

Most phones do not throttle in the kernel. They run a userspace daemon - `thermal_core` on MediaTek, `thermal-engine` on Qualcomm, `thermald` on Exynos - that watches temperature and pushes a **clock limit** through the power HAL.

That is why the usual tricks fail:

```
echo 2400000 > scaling_max_freq   # looks fine, then drops back to 2200000
```

The kernel itself clamps the value while the daemon keeps requesting a lower one. Disabling thermal zones does not help either, because the daemon does not need them.

`nothrottle` stops the daemon (`stop thermal_core`), pins the clusters to `cpuinfo_max_freq` with the `performance` governor, raises the GPU floor, and keeps a two-stage guard: first it lets the clocks drop, and only if the phone keeps heating does it restore stock completely.

## What it does

| Step | Detail |
|---|---|
| CPU | every `policy*` pinned to `cpuinfo_max_freq`, `performance` governor when available |
| GPU | devfreq/KGSL node detected, floor raised to `GPU_MIN_PCT` of max (or pinned with `--gpu-max`) |
| Vendor thermal | known daemon for the SoC family stopped via `stop <service>` |
| Thermal zones | MTK profile disables CPU/GPU/SOC zones (optional on other vendors) |
| Guard | background loop: soft limit `soften`s, hard limit fully restores stock |
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
| `apply [--game] [--gpu-max] [--no-zones] [--force]` | lock + stop thermal daemon + start guard; `--game` also sets the GPU governor to `performance` and raises the guard to 92 C |
| `soften` | drop the frequency floor, keep the ceiling and keep vendor thermal off (guard calls this first) |
| `status` | current governor, min/max, guard pid, service state, softened or not |
| `restore` | put back every saved value, restart daemons, kill guard |
| `debloat <list> [--restore]` | disable/enable packages from a list file |
| `aot <pkg>...` | AOT compile apps (`cmd package compile -m speed`) |
| `animate [scale]` | animation scales, default `0.5` |
| `install-boot` / `uninstall-boot` | optional `/data/adb/service.d` hook |

Environment: `NOTHROTTLE_SOC` / `NOTHROTTLE_BAT` / `NOTHROTTLE_SOC_SOFT` (millidegrees) override the guard limits, `NOTHROTTLE_STATE` moves the state directory.

## Guard

`apply` starts `guard.sh`. Every 20 s it reads the `soc_max` and `battery` zones and has two thresholds:

1. **soft** - calls `soften`: governor becomes `schedutil`, the frequency floor goes back to stock, the ceiling stays pinned, vendor thermal stays off. Clocks may drop, nothing else changes. Happens once.
2. **hard** - calls `restore`: back to stock clocks, stock governor, thermal daemon running, zones enabled.

Defaults: soft **75 C**, hard **80 C** SOC, hard **47 C** battery. `apply --game` raises them to soft **87 C**, hard **92 C** SOC and **45 C** battery, and pins the GPU governor to `performance`.

This split exists because of a real report: on the A06 5G an 80 C guard fired after ~10 minutes of gaming and dumped the phone straight back to stock, which felt like the throttling the user was trying to avoid. Now it steps down first. Raise the hard limit if you accept more heat:

```sh
NOTHROTTLE_SOC=95000 NOTHROTTLE_SOC_SOFT=90000 su -c 'sh nothrottle apply'
```

## Device support

| SoC family | Thermal daemon | Status |
|---|---|---|
| MediaTek | `thermal_core` | tested: Galaxy A06 5G only |
| Qualcomm | `thermal-engine` | untested, profile included |
| Exynos | `thermald` | untested, profile included |
| other | none found | untested, generic profile only |

Snapdragon and Exynos kernels often do real mitigation in `tsens`/thermal zones, so those profiles intentionally do **not** disable zones. The guard is your safety net.

## Adding a device

1. Run `doctor` and save the output.
2. Find the running thermal service: `getprop | grep init.svc | grep -i thermal`.
3. Copy `profiles/mtk.conf`, change `SVC_THERMAL`, `ZONES_DISABLE`, limits.
4. Test `apply` -> `status` -> `restore` and check clocks actually return.
5. Open a PR with the doctor output and what changed.

## Safety

- Heat is real. Pinning `performance` removes the OS thermal policy for CPU; the guard is the only thing left. For gaming use `apply --game` rather than the default, and do not game while charging.
- Stopping the vendor daemon also removes its charging/battery policy on some phones.
- Root may break Samsung Pay / Secure Folder even without tripping Knox. Warranty bit stays `0` because nothing is flashed.
- This is not a magic ROM. It cannot fix a slow eMMC, a weak GPU, or 3 GB of RAM.

See [docs/how-it-works.md](docs/how-it-works.md) and [docs/risks.md](docs/risks.md).

## FAQ

**Does this unlock my bootloader?** No. It needs root, nothing else.
**Does it survive a reboot?** No. Root itself may not survive; re-run `apply` after boot.
**Why not just disable thermal zones?** On MTK the daemon ignores them. On Qualcomm they are the real mitigation - disabling them is how phones cook.
**My game lags after ~10 minutes. What is happening?** Either the guard restored stock (check `nothrottle.log` for `SOFTEN`/`TRIGGER`), or a reboot cleared the lock, or the phone ran out of RAM. 3-4 GB devices throttle on memory pressure regardless of clocks. Use `apply --game`.
**Will it work on my phone?** It has only been run on a Galaxy A06 5G. On anything else it is untested - run `doctor`, and open a device report with the output.

## License

MIT. Use at your own risk.
