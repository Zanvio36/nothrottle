# Debloat lists

Each line is one package name. Lines starting with `#` and empty lines are ignored.

```sh
su -c 'sh nothrottle debloat debloat/example.list'
su -c 'sh nothrottle debloat debloat/example.list --restore'
```

`pm disable-user --user 0` is used, not `pm uninstall`, so the APK stays on the system image and `--restore` brings it back instantly.

Make your own list from a phone you have already tuned:

```sh
pm list packages -d
```

That prints every disabled package. Paste the ones you are sure about, with a comment saying what they do.

Rules of thumb:

- Safe: Facebook stubs, carrier apps, duplicate browsers, AR/Bixby extras, unused Samsung services.
- Careful: anything with `provider`, `sync`, `backup`, `push`, `location` in the name.
- Never: `com.android.*` core packages, `com.google.android.gms`, the launcher, the keyboard.
