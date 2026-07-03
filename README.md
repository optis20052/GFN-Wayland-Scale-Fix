# GeForce NOW – UI Scaling Fix (Linux)

Make NVIDIA's official **GeForce NOW** flatpak respect your desktop scale on Linux.

The GeForce NOW Linux app is built on **CEF (Chromium Embedded Framework)** and
renders its interface at **100%**, ignoring your GNOME/Wayland fractional scale
(150%, 175%, 200%, …). On a HiDPI/4K monitor this makes the whole UI tiny. The
app also **disables the in‑app `Ctrl` + `+/-` zoom**, so there's no built‑in way
to fix it.

This project sets CEF's own zoom level to match your desktop scale - the one
knob the app actually reads - via two small shell helpers and an auto‑scaling
launcher.

## Screenshot

Before: window is full‑size but every control, tile and label renders at 100%.
After: the interface matches the rest of your desktop.

## Requirements

- GeForce NOW flatpak installed: `flatpak install flathub com.nvidia.geforcenow`
- `bash`, `flatpak`, `grep`, `sed`, `awk`, `procps` (all standard)
- **Auto‑detect** of the desktop scale needs **GNOME** (`gdbus` + Mutter).
  On KDE/other desktops everything still works - you just pass the scale as a
  number instead of relying on auto‑detect.

## Install

```bash
git clone https://github.com/<you>/gfn-scaling-fix.git
cd gfn-scaling-fix
bash gfn-scaling-fix-install.sh
```

Or download just the installer and run it:

```bash
bash gfn-scaling-fix-install.sh
```

The installer writes everything into your own home directory:

| Path | What it is |
| --- | --- |
| `~/.local/bin/gfn-scale` | Manual "set the scale now" command |
| `~/.local/bin/gfn-launch` | Launcher that auto‑syncs zoom to your desktop scale |
| `~/.local/share/applications/gfn-autoscale.desktop` | "GeForce NOW (auto-scale)" menu entry |

Your existing GeForce NOW launcher is left untouched.

## Usage

### Recommended: just use the new menu entry

Launch **"GeForce NOW (auto-scale)"** from your app menu (pin it to your
dock/taskbar). Every launch reads your current desktop scale and applies it
automatically - including after you change your monitor scale later.

### Manual control

```bash
gfn-scale          # re-sync to the current desktop scale (GNOME auto-detect)
gfn-scale 1.5      # force 150%
gfn-scale 1.75     # force 175%
gfn-scale 2.0      # force 200%
gfn-scale 1.0      # back to 100%
```

`gfn-scale` closes GFN, writes the new scale, and relaunches it. It backs up the
previous settings to `Preferences.bak` each time.

> On non‑GNOME desktops always pass a number (auto‑detect is GNOME‑only).

## How it works

GeForce NOW stores its settings as plain JSON at:

```
~/.var/app/com.nvidia.geforcenow/.local/state/NVIDIA/GeForceNOW/CefCache/Default/Preferences
```

The scripts set `partition.default_zoom_level` for the app's storage partition.
CEF's zoom uses a base of `1.2`, so the zoom **level** for a given scale
**factor** is:

```
level = ln(factor) / ln(1.2)
```

e.g. `1.5x → ~2.224`. Because this lives in the app's own preferences, it
**survives GeForce NOW updates**.

### Why not `--force-device-scale-factor`?

The usual Chromium/CEF trick can't be injected here: the flatpak's internal
launcher runs the CEF binary with no argument pass‑through **and clears
`LD_PRELOAD`**. It also ignores `Xft.dpi`. Editing the zoom preference is the
one method that reliably works without modifying the read‑only flatpak.

## Uninstall

```bash
rm -f ~/.local/bin/gfn-scale ~/.local/bin/gfn-launch \
      ~/.local/share/applications/gfn-autoscale.desktop
gfn-scale 1.0 2>/dev/null   # optional: reset GFN back to 100% first
```

## Notes / caveats

- Scaling via zoom is not identical to a true HiDPI device‑scale, but in
  practice the GeForce NOW UI scales cleanly. The **game stream itself** is a
  video feed and is unaffected either way.
- If a future GeForce NOW update changes the storage partition name (currently
  `x`) or the preferences layout, the scripts may need a tweak.

## License

MIT - do whatever you like. No warranty.
