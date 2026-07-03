#!/usr/bin/env bash
# GeForce NOW UI scaling fix - installer.
# NVIDIA's official GeForce NOW flatpak (CEF-based) ignores the desktop scale and
# disables Ctrl+/- zoom. This installs two helpers that set CEF's own zoom level:
#   gfn-scale [factor]  -> set UI scale (no arg = auto-detect GNOME desktop scale)
#   gfn-launch          -> launch GFN, auto-syncing zoom to the desktop scale
# and a "GeForce NOW (auto-scale)" menu entry that uses gfn-launch.
#
# Requirements: the GeForce NOW flatpak (com.nvidia.geforcenow) installed, plus
# bash, flatpak, grep/sed/awk, procps. Auto-detect needs GNOME (gdbus + Mutter);
# on other desktops just pass a factor, e.g.  gfn-scale 1.5
set -euo pipefail

BIN="$HOME/.local/bin"
APPS="$HOME/.local/share/applications"
mkdir -p "$BIN" "$APPS"

if ! flatpak info com.nvidia.geforcenow >/dev/null 2>&1; then
  echo "NOTE: com.nvidia.geforcenow flatpak not found. Install GeForce NOW first, then run this again."
fi

cat > "$BIN/gfn-scale" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
PREF="$HOME/.var/app/com.nvidia.geforcenow/.local/state/NVIDIA/GeForceNOW/CefCache/Default/Preferences"
detect_scale() {
  command -v gdbus >/dev/null 2>&1 || { echo 1; return; }
  gdbus call --session --dest org.gnome.Mutter.DisplayConfig \
    --object-path /org/gnome/Mutter/DisplayConfig \
    --method org.gnome.Mutter.DisplayConfig.GetCurrentState 2>/dev/null \
    | { grep -oE '[0-9]+(\.[0-9]+)?, uint32 [0-9]+, true' || true; } \
    | head -1 | grep -oE '^[0-9]+(\.[0-9]+)?' || echo 1
}
F="${1:-}"
if [ -z "$F" ]; then F="$(detect_scale)"; F="${F:-1}"; echo "Auto-detected desktop scale: ${F}x"; fi
[ -f "$PREF" ] || { echo "GFN Preferences not found - launch GFN once first."; exit 1; }
echo "Closing GeForce NOW..."
flatpak kill com.nvidia.geforcenow 2>/dev/null || true
for _ in $(seq 1 15); do pgrep -f "/app/cef/GeForceNOW" >/dev/null 2>&1 || break; sleep 1; done
pkill -9 -f "GeForceNOW" 2>/dev/null || true
sleep 1
LEVEL="$(LC_ALL=C awk -v f="$F" 'BEGIN{printf "%.6f", log(f)/log(1.2)}')"
cp "$PREF" "$PREF.bak"
if grep -q '"default_zoom_level"' "$PREF"; then
  sed -i -E "s/\"default_zoom_level\":\{\"x\":[0-9.eE+-]*\}/\"default_zoom_level\":{\"x\":$LEVEL}/" "$PREF"
else
  sed -i "s/\"partition\":{/\"partition\":{\"default_zoom_level\":{\"x\":$LEVEL},/" "$PREF"
fi
echo "Set GFN UI scale to ${F}x (zoom level $LEVEL)"
echo "Relaunching..."
nohup flatpak run com.nvidia.geforcenow >/dev/null 2>&1 & disown
echo "Done."
SCRIPT
chmod +x "$BIN/gfn-scale"

cat > "$BIN/gfn-launch" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
PREF="$HOME/.var/app/com.nvidia.geforcenow/.local/state/NVIDIA/GeForceNOW/CefCache/Default/Preferences"
scale=1
if command -v gdbus >/dev/null 2>&1; then
  s="$(gdbus call --session --dest org.gnome.Mutter.DisplayConfig \
        --object-path /org/gnome/Mutter/DisplayConfig \
        --method org.gnome.Mutter.DisplayConfig.GetCurrentState 2>/dev/null \
        | { grep -oE '[0-9]+(\.[0-9]+)?, uint32 [0-9]+, true' || true; } \
        | head -1 | grep -oE '^[0-9]+(\.[0-9]+)?')" || true
  [ -n "${s:-}" ] && scale="$s"
fi
if [ -f "$PREF" ] && ! pgrep -f "/app/cef/GeForceNOW" >/dev/null 2>&1; then
  LEVEL="$(LC_ALL=C awk -v f="$scale" 'BEGIN{printf "%.6f", log(f)/log(1.2)}')"
  if grep -q '"default_zoom_level"' "$PREF"; then
    sed -i -E "s/\"default_zoom_level\":\{\"x\":[0-9.eE+-]*\}/\"default_zoom_level\":{\"x\":$LEVEL}/" "$PREF"
  else
    sed -i "s/\"partition\":{/\"partition\":{\"default_zoom_level\":{\"x\":$LEVEL},/" "$PREF"
  fi
fi
exec flatpak run com.nvidia.geforcenow "$@"
SCRIPT
chmod +x "$BIN/gfn-launch"

cat > "$APPS/gfn-autoscale.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=GeForce NOW (auto-scale)
Comment=GeForce NOW, UI zoom synced to desktop scale
Exec=$BIN/gfn-launch
Icon=com.nvidia.geforcenow
Categories=Network;Game;
Terminal=false
StartupWMClass=GeForceNOW
DESKTOP

update-desktop-database "$APPS" >/dev/null 2>&1 || true

echo
echo "Installed:"
echo "  $BIN/gfn-scale"
echo "  $BIN/gfn-launch"
echo "  $APPS/gfn-autoscale.desktop  (menu: 'GeForce NOW (auto-scale)')"
case ":$PATH:" in
  *":$BIN:"*) echo "Run:  gfn-scale        (or launch the 'auto-scale' app entry)";;
  *) echo "Note: $BIN is not on PATH - run it as  $BIN/gfn-scale";;
esac
echo "Tip: on a non-GNOME desktop, pass a number, e.g.  gfn-scale 1.5"