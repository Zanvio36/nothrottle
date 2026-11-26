# Risks

Read this before you run `apply` on a phone you need.

## Heat

`performance` governor plus max frequency disables the OS thermal policy for the CPU. The guard is the only remaining limit. A 2.4 GHz big core in a plastic body will hit 70 C in minutes of gaming and 80 C+ under sustained load - measured on a Galaxy A06 5G: 80.5 C after ~10 minutes of gaming, which tripped the old single 80 C guard.

That is why `--game` exists: it lets the chip reach 87 C before stepping the clocks down and 92 C before full restore. 92 C is junction temperature, not surface temperature, but it is still hot enough to be uncomfortable and to age the battery faster.

Consequences of running hot: battery wear, screen brightness reduction, modem instability, and in the worst case a thermal shutdown.

Do **not** game while charging. Charging adds 5-10 W to a device that is already at its thermal limit.

## Charging policy

`thermal_core` and `thermal-engine` also implement charging limits (current taper, battery temperature cutoffs). Stopping them removes that policy too. The battery protection in the charger IC still works, but the graceful taper does not.

If you use the phone as a daily driver, run `restore` before charging overnight, or keep the battery guard (47 C default, 45 C with `--game`).

## Battery life

Pinning to max frequency can double idle drain. `performance` never scales down. If battery matters, do not use `apply` as a permanent state - use it for gaming sessions.

## Root detection

Some apps refuse to run with root (banking, Netflix in HD, some games). That is root, not `nothrottle`. Hiding root is a separate problem (Zygisk + DenyList).

## Knox / warranty

Nothing is flashed, so the Knox warranty bit stays `0` and OTA updates keep working. Samsung Pay and Secure Folder may still refuse to run on a rooted device - that is root detection, not this tool.

## Exploit-based root

If root itself comes from an exploit (for example DirtyFrag / KernelSU), it disappears on reboot and may be unstable. `nothrottle` assumes a working `su`; if `su` dies, the guard keeps running with the old limits until reboot. Re-run `apply` after every reboot.

## Recovery

```sh
su -c 'sh nothrottle restore'
```

If that fails, a reboot restores every value, because nothing is persistent. If the phone is too hot to respond, let it cool and reboot.
