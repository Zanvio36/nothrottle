# Contributors

This project is written, maintained and tested by one person.

## Zanvio36 ([@Zanvio36](https://github.com/Zanvio36))

Author, maintainer, and the only person who has run this on real hardware.

- All device testing: Samsung Galaxy A06 5G (SM-A066B), MediaTek Dimensity 6300, Android 16 / One UI 8.5, KernelSU root.
- Found and reported the original ~10-minute gaming slowdown that produced the two-stage guard.
- Requested and shaped the one-tap WebUI, the memory tuning, the reboot-persistence work, and the full-revert path.
- Wrote the README note that limits the tested-device claim to the A06 5G.

Every commit in this repository is authored by this account (`96323442+Zanvio36@users.noreply.github.com`). No other GitHub account has authored a commit here - you can check it yourself:

```sh
git log --all --format='%ae' | sort -u
```

## Test reports

If you run this on a different phone, open an issue with the `nothrottle doctor` output (model, SoC, Android version, root method, what worked). You get thanked in the release notes; the commit history stays single-author.
