#!/usr/bin/env bash
# setup-kiosk.sh — turn a Raspberry Pi 4 running Raspberry Pi OS Desktop into a
# hands-off YouTube appliance for a projector. Run this ON THE PI:
#
#   scp setup-kiosk.sh pi@rowpi.local:
#   ssh pi@rowpi.local 'bash setup-kiosk.sh'
#
# What it does:
#   * boots straight to the desktop with no login prompt
#   * launches Chromium fullscreen on the YouTube TV interface
#   * keeps the screen awake forever (no blanking mid-video)
#   * hides the mouse pointer
#   * restarts the browser automatically if it crashes
#   * routes audio out HDMI to the projector, or to the headphone jack
#
# The TV interface is the point: you pair your phone once, then queue and
# control videos from the phone. No keyboard needed at the rowing machine.
#
# Options:
#   --url URL          what to open. default: https://www.youtube.com/tv
#   --plain-youtube    use the normal desktop youtube.com instead of the TV UI
#   --audio hdmi|jack  where sound goes. default: hdmi
#   --force-h264       install an extension that makes YouTube serve H.264,
#                      which the Pi 4 decodes in hardware. See README.
#   --keep-wayland     do not switch the desktop session to X11
#   --uninstall        remove everything this script installed

set -euo pipefail

URL="https://www.youtube.com/tv"
AUDIO="hdmi"
FORCE_H264=0
KEEP_WAYLAND=0
UNINSTALL=0

# YouTube serves the TV interface based on the user agent. A desktop Chromium
# UA gets redirected to the normal site, so present as a Chromecast. If the TV
# UI ever stops loading, this string going stale is the first thing to suspect;
# --plain-youtube is the fallback.
TV_USER_AGENT="Mozilla/5.0 (X11; Linux armv7l) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 CrKey/1.56.500000"
USE_TV_UA=1

# enhanced-h264ify on the Chrome Web Store. VERIFY THIS ID before trusting it:
# open the extension's Web Store page and copy the ID out of the URL. A wrong
# ID here means the extension silently never installs.
H264IFY_ID="omkfmpieigblcllmkgbflkikinpkodlk"

while [ $# -gt 0 ]; do
  case "$1" in
    --url)           URL="${2:?}"; USE_TV_UA=0; shift 2 ;;
    --plain-youtube) URL="https://www.youtube.com"; USE_TV_UA=0; shift ;;
    --audio)         AUDIO="${2:?}"; shift 2 ;;
    --force-h264)    FORCE_H264=1; shift ;;
    --keep-wayland)  KEEP_WAYLAND=1; shift ;;
    --uninstall)     UNINSTALL=1; shift ;;
    -h|--help)       sed -n '2,26p' "$0"; exit 0 ;;
    *) printf 'unknown option: %s (try --help)\n' "$1" >&2; exit 1 ;;
  esac
done

case "$AUDIO" in hdmi|jack) ;; *) printf 'Error: --audio must be hdmi or jack\n' >&2; exit 1 ;; esac

USER_NAME="$(id -un)"
USER_HOME="$HOME"
KIOSK_DIR="$USER_HOME/youtube-kiosk"
AUTOSTART="$USER_HOME/.config/autostart/youtube-kiosk.desktop"
POLICY_DIR="/etc/chromium/policy/managed"

step() { printf '\n==> %s\n' "$*"; }

[ "$(id -u)" -ne 0 ] || { printf 'Run this as your normal user, not root (it configures your desktop session).\n' >&2; exit 1; }

# ------------------------------------------------------------------ uninstall

if [ "$UNINSTALL" -eq 1 ]; then
  step "Removing the kiosk"
  rm -f  "$AUTOSTART"
  rm -rf "$KIOSK_DIR"
  sudo rm -f "$POLICY_DIR/youtube-kiosk.json"
  sudo raspi-config nonint do_boot_behaviour B3 || true   # desktop, with login
  printf '\nRemoved. Reboot to get a normal desktop back: sudo reboot\n'
  exit 0
fi

# ------------------------------------------------------------ sanity checks

step "Checking the machine"
MODEL="$(tr -d '\0' < /proc/device-tree/model 2>/dev/null || echo unknown)"
printf '  Model: %s\n' "$MODEL"
case "$MODEL" in
  *"Raspberry Pi 4"*|*"Raspberry Pi 5"*) ;;
  *"Raspberry Pi 3"*) printf '  Warning: a Pi 3 will struggle badly with 1080p YouTube. Expect 720p at best.\n' ;;
  *) printf '  Warning: unrecognised model. Continuing anyway.\n' ;;
esac

if [ ! -d /etc/xdg/autostart ] || ! command -v raspi-config >/dev/null 2>&1; then
  printf '\nThis does not look like Raspberry Pi OS Desktop.\n' >&2
  printf 'The kiosk needs a desktop session; re-image with "Raspberry Pi OS (64-bit)"\n' >&2
  printf '(the full desktop version, not Lite) and run this again.\n' >&2
  exit 1
fi

# ------------------------------------------------------------------ packages

step "Installing packages (this takes a few minutes)"
sudo apt-get update
# chromium-browser is the package name on Raspberry Pi OS; on some releases it
# is plain "chromium". Try the Pi name first, fall back.
if ! sudo apt-get install -y chromium-browser unclutter x11-xserver-utils; then
  sudo apt-get install -y chromium unclutter x11-xserver-utils
fi

CHROMIUM_BIN="$(command -v chromium-browser || command -v chromium)"
[ -n "$CHROMIUM_BIN" ] || { printf 'Chromium did not install. Stopping.\n' >&2; exit 1; }
printf '  Chromium: %s\n' "$CHROMIUM_BIN"

# ------------------------------------------------------------- session setup

step "Configuring the desktop session"

# Boot straight to the desktop, already logged in. B4 = desktop + autologin.
sudo raspi-config nonint do_boot_behaviour B4
printf '  autologin to desktop: on\n'

# Screen blanking off. Nothing is worse than the projector going dark 10
# minutes into a row because nothing has touched the input devices.
sudo raspi-config nonint do_blanking 1
printf '  screen blanking: off\n'

# X11 rather than Wayland. Both can run a kiosk, but on X11 the pointer-hiding
# and screensaver tools (unclutter, xset) actually work; under Wayland on Pi OS
# they are no-ops and you get a mouse cursor parked in the middle of the film.
if [ "$KEEP_WAYLAND" -eq 0 ]; then
  if sudo raspi-config nonint do_wayland W1 2>/dev/null; then
    printf '  display server: X11\n'
  else
    printf '  display server: could not switch (older OS?) - continuing\n'
  fi
else
  printf '  display server: left as-is (--keep-wayland)\n'
fi

# ---------------------------------------------------------------- h264 policy

# The Pi 4 has hardware decoding for H.264 but NOT for VP9 or AV1, which is
# what YouTube serves by default. Software-decoding VP9 at 1080p60 drops
# frames. This extension makes YouTube offer H.264 instead.
if [ "$FORCE_H264" -eq 1 ]; then
  step "Forcing H.264 playback"
  sudo mkdir -p "$POLICY_DIR"
  sudo tee "$POLICY_DIR/youtube-kiosk.json" >/dev/null <<POLICY
{
  "ExtensionInstallForcelist": [
    "${H264IFY_ID};https://clients2.google.com/service/update2/crx"
  ]
}
POLICY
  printf '  policy written. Chromium installs the extension on next launch.\n'
  printf '  Verify at chrome://extensions - if nothing appears, the extension ID\n'
  printf '  in this script is wrong or stale. See the README.\n'
else
  sudo rm -f "$POLICY_DIR/youtube-kiosk.json" 2>/dev/null || true
fi

# --------------------------------------------------------------------- audio

step "Setting audio output to: $AUDIO"
if command -v wpctl >/dev/null 2>&1; then
  # Bookworm and later use PipeWire. Match the sink by name rather than index,
  # because indices shift between boots.
  case "$AUDIO" in
    hdmi) PATTERN='hdmi' ;;
    jack) PATTERN='Headphones|analog' ;;
  esac
  SINK_ID="$(wpctl status 2>/dev/null \
    | sed -n '/Sinks:/,/^ *$/p' \
    | grep -iE "$PATTERN" \
    | head -1 \
    | grep -oE '[0-9]+\.' | head -1 | tr -d '.')" || true
  if [ -n "${SINK_ID:-}" ]; then
    wpctl set-default "$SINK_ID" && printf '  default sink set to id %s\n' "$SINK_ID"
  else
    printf '  Could not find a matching sink automatically.\n'
    printf '  Set it by hand: run `wpctl status`, find your output under Sinks,\n'
    printf '  then `wpctl set-default <id>`.\n'
  fi
else
  printf '  PipeWire not found; set the output from the desktop volume icon.\n'
fi

# --------------------------------------------------------------- kiosk script

step "Installing the kiosk launcher"
mkdir -p "$KIOSK_DIR"

UA_FLAG=""
[ "$USE_TV_UA" -eq 1 ] && UA_FLAG="--user-agent=\"\$TV_USER_AGENT\""

cat > "$KIOSK_DIR/start-kiosk.sh" <<KIOSK
#!/usr/bin/env bash
# Launches the YouTube kiosk. Installed by setup-kiosk.sh - edit the URL or the
# Chromium flags below, then reboot (or log out and back in) to pick up changes.
set -u

URL="$URL"
CHROMIUM="$CHROMIUM_BIN"
PROFILE="\$HOME/youtube-kiosk/profile"
TV_USER_AGENT="$TV_USER_AGENT"

# Give the desktop session a moment to come up before grabbing the screen.
sleep 5

# Keep the display awake. No-ops harmlessly under Wayland.
xset s off       2>/dev/null || true
xset s noblank   2>/dev/null || true
xset -dpms       2>/dev/null || true

# Hide the pointer once it stops moving.
pgrep -x unclutter >/dev/null 2>&1 || (unclutter -idle 0.5 -root >/dev/null 2>&1 &)

# Chromium notices an unclean shutdown and shows a "Restore pages?" bubble that
# sits on top of the video until someone dismisses it. Rewrite the exit state
# before every launch so it never appears.
PREFS="\$PROFILE/Default/Preferences"
if [ -f "\$PREFS" ]; then
  sed -i 's/"exit_type":"[^"]*"/"exit_type":"Normal"/; s/"exited_cleanly":false/"exited_cleanly":true/' "\$PREFS" || true
fi

# Restart the browser if it dies, so a crash mid-row is a 5-second blip rather
# than a black projector and a trip up the stairs.
while true; do
  "\$CHROMIUM" \\
    --kiosk \\
    --user-data-dir="\$PROFILE" \\
    --noerrdialogs \\
    --disable-infobars \\
    --disable-session-crashed-bubble \\
    --disable-features=Translate \\
    --no-first-run \\
    --check-for-update-interval=31536000 \\
    --autoplay-policy=no-user-gesture-required \\
    --enable-features=VaapiVideoDecoder \\
    --use-gl=egl \\
    --start-fullscreen \\
    $UA_FLAG \\
    "\$URL" || true
  sleep 3
done
KIOSK

chmod +x "$KIOSK_DIR/start-kiosk.sh"
printf '  %s\n' "$KIOSK_DIR/start-kiosk.sh"

# Autostart via a .desktop entry rather than a systemd unit: it works the same
# under LXDE, wayfire and labwc, and it starts after the session actually has a
# display, which a system service does not reliably do.
mkdir -p "$USER_HOME/.config/autostart"
cat > "$AUTOSTART" <<DESKTOP
[Desktop Entry]
Type=Application
Name=YouTube Kiosk
Exec=$KIOSK_DIR/start-kiosk.sh
X-GNOME-Autostart-enabled=true
DESKTOP
printf '  %s\n' "$AUTOSTART"

# ---------------------------------------------------------------------- done

cat <<EOF

Kiosk installed. Reboot to start it:

  sudo reboot

After it comes up on the projector:

  Pair your phone (this is the good part)
    1. On the TV screen: Settings -> Link with TV code
    2. Phone YouTube app -> profile -> Settings -> Watch on TV -> Enter TV code
    3. From then on, hit the cast icon in the phone app to queue anything.

  Get out of the kiosk        Ctrl+Alt+F2 for a console, or SSH in
  Change the URL or flags     edit $KIOSK_DIR/start-kiosk.sh, then reboot
  Remove it all               bash setup-kiosk.sh --uninstall

  Playback stuttering?        Set quality to 1080p or below in the player, and
                              re-run with --force-h264. See README.md.

EOF
