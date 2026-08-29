#!/usr/bin/env bash
# flash-pi.sh — write headless first-boot config onto a freshly imaged
# Raspberry Pi OS SD card, from macOS, Linux, WSL, or Git Bash on Windows.
#
# Run this AFTER Raspberry Pi Imager (or dd) has written the image and the
# card's boot partition is mounted. It writes a `custom.toml` that Raspberry Pi
# OS Bookworm (2023-10) and later consume on first boot to set the hostname,
# create your user, enable SSH, and join Wi-Fi — no keyboard or monitor needed.
#
# Usage:
#   ./flash-pi.sh                          # prompts for everything
#   ./flash-pi.sh --ssid "MyWiFi" --hostname rowpi
#
# Options (any omitted value is prompted for):
#   --boot PATH        boot partition mount point (autodetected if omitted)
#   --hostname NAME    default: rowpi
#   --user NAME        default: pi
#   --password PASS    login password (prompted, hidden, if omitted)
#   --ssid SSID        Wi-Fi network name
#   --wifi-pass PASS   Wi-Fi password (prompted, hidden, if omitted)
#   --country CC       Wi-Fi regulatory domain, e.g. US GB DE. default: US
#   --timezone TZ      default: America/New_York
#   --keymap KM        default: us
#   --hdmi-mode MODE   force a display mode, e.g. 1920x1080@60 or 1280x720@60
#   --no-wifi          skip Wi-Fi entirely (wired ethernet only)
#   --dry-run          print what would be written, change nothing

set -euo pipefail

BOOT=""; HOSTNAME_="";  USERNAME_=""; PASSWORD_=""
SSID=""; WIFI_PASS=""; COUNTRY=""; TIMEZONE_=""; KEYMAP=""
HDMI_MODE=""; NO_WIFI=0; DRY_RUN=0
WIFI_PASS_SET=0; PASSWORD_SET=0

die() { printf '\nError: %s\n' "$*" >&2; exit 1; }
note() { printf '  %s\n' "$*"; }

while [ $# -gt 0 ]; do
  case "$1" in
    --boot)      BOOT="${2:?}"; shift 2 ;;
    --hostname)  HOSTNAME_="${2:?}"; shift 2 ;;
    --user)      USERNAME_="${2:?}"; shift 2 ;;
    --password)  PASSWORD_="${2:?}"; PASSWORD_SET=1; shift 2 ;;
    --ssid)      SSID="${2:?}"; shift 2 ;;
    --wifi-pass) WIFI_PASS="${2:?}"; WIFI_PASS_SET=1; shift 2 ;;
    --country)   COUNTRY="${2:?}"; shift 2 ;;
    --timezone)  TIMEZONE_="${2:?}"; shift 2 ;;
    --keymap)    KEYMAP="${2:?}"; shift 2 ;;
    --hdmi-mode) HDMI_MODE="${2:?}"; shift 2 ;;
    --no-wifi)   NO_WIFI=1; shift ;;
    --dry-run)   DRY_RUN=1; shift ;;
    -h|--help)   sed -n '2,30p' "$0"; exit 0 ;;
    *)           die "unknown option: $1 (try --help)" ;;
  esac
done

# ---------------------------------------------------------------- find the card

is_boot_partition() { [ -f "$1/config.txt" ] && [ -f "$1/cmdline.txt" ]; }

autodetect_boot() {
  local candidates=() d
  # macOS
  for d in /Volumes/*; do [ -d "$d" ] && candidates+=("$d"); done 2>/dev/null
  # Linux / WSL
  for d in "/media/$USER"/* /media/*/* /mnt/*; do [ -d "$d" ] && candidates+=("$d"); done 2>/dev/null
  # Git Bash on Windows maps drive letters to /c, /d, ...
  for d in /[a-z]; do [ -d "$d" ] && candidates+=("$d"); done 2>/dev/null

  local found=()
  for d in "${candidates[@]:-}"; do
    [ -n "$d" ] || continue
    is_boot_partition "$d" && found+=("$d")
  done
  # de-duplicate
  printf '%s\n' "${found[@]:-}" | awk 'NF && !seen[$0]++'
}

if [ -z "$BOOT" ]; then
  printf 'Looking for the SD card boot partition...\n'
  hits=()
  mapfile -t hits < <(autodetect_boot) 2>/dev/null || {
    # bash 3.2 on macOS has no mapfile
    hits=(); while IFS= read -r line; do [ -n "$line" ] && hits+=("$line"); done < <(autodetect_boot)
  }
  case "${#hits[@]}" in
    0) die "no boot partition found. Insert the card and pass --boot /path/to/bootfs" ;;
    1) BOOT="${hits[0]}" ;;
    *) printf 'Multiple candidates found:\n'
       i=1; for h in "${hits[@]}"; do printf '  %d) %s\n' "$i" "$h"; i=$((i+1)); done
       printf 'Which one? [1] '; read -r pick; pick="${pick:-1}"
       BOOT="${hits[$((pick-1))]}" ;;
  esac
fi

is_boot_partition "$BOOT" || die "$BOOT does not look like a Pi boot partition (no config.txt/cmdline.txt)"
printf 'Boot partition: %s\n\n' "$BOOT"

# The custom.toml mechanism only exists in Bookworm and later. Older images
# silently ignore it, which looks exactly like "the Pi never joined Wi-Fi",
# so check for a Bookworm-era marker and warn loudly rather than fail quietly.
if [ ! -f "$BOOT/firmware/config.txt" ] && ! grep -qs 'dtoverlay=vc4-kms-v3d' "$BOOT/config.txt"; then
  printf 'Warning: this image may predate Raspberry Pi OS Bookworm.\n'
  printf '         custom.toml is only read by Bookworm (2023-10) and later.\n'
  printf '         If the Pi never appears on the network, re-image with a current release.\n\n'
fi

# -------------------------------------------------------------------- gather

ask() { # ask VAR_NAME "prompt" "default"
  local __var="$1" __prompt="$2" __default="${3:-}" __reply
  if [ -n "${!__var}" ]; then return; fi
  if [ -n "$__default" ]; then printf '%s [%s]: ' "$__prompt" "$__default"
  else printf '%s: ' "$__prompt"; fi
  read -r __reply
  printf -v "$__var" '%s' "${__reply:-$__default}"
}

ask_secret() { # ask_secret VAR_NAME "prompt"
  local __var="$1" __prompt="$2" __reply
  printf '%s: ' "$__prompt"; read -rs __reply; printf '\n'
  printf -v "$__var" '%s' "$__reply"
}

ask HOSTNAME_ "Hostname"          "rowpi"
ask USERNAME_ "Login username"    "pi"
[ "$PASSWORD_SET" -eq 1 ] || ask_secret PASSWORD_ "Login password for $USERNAME_"
[ -n "$PASSWORD_" ] || die "login password cannot be empty"

if [ "$NO_WIFI" -eq 0 ]; then
  ask SSID "Wi-Fi network name (SSID), or blank for wired only" ""
  if [ -n "$SSID" ]; then
    [ "$WIFI_PASS_SET" -eq 1 ] || ask_secret WIFI_PASS "Wi-Fi password for $SSID"
  else
    NO_WIFI=1
  fi
fi

ask COUNTRY   "Wi-Fi country code" "US"
ask TIMEZONE_ "Timezone"           "America/New_York"
ask KEYMAP    "Keyboard layout"    "us"

# ---------------------------------------------------------------- password hash

# Prefer a hashed password so it isn't sitting in cleartext on a FAT partition
# that any machine can read. Falls back to cleartext (which custom.toml does
# support) when openssl isn't available, e.g. a bare Windows shell.
PW_ENCRYPTED="false"
PW_FIELD="$PASSWORD_"
if command -v openssl >/dev/null 2>&1; then
  PW_FIELD="$(openssl passwd -6 "$PASSWORD_")"
  PW_ENCRYPTED="true"
else
  printf '\nNote: openssl not found — writing the login password in cleartext.\n'
  printf '      Change it after first boot with: passwd\n\n'
fi

# The Wi-Fi PSK is always cleartext here. custom.toml can take a precomputed
# PSK, but it is derived from the passphrase and SSID and is equally usable as
# a credential, so hashing it buys nothing. Treat the card as sensitive.

toml_escape() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }

# ------------------------------------------------------------------- compose

TOML="config_version = 1

[system]
hostname = \"$(toml_escape "$HOSTNAME_")\"

[user]
name = \"$(toml_escape "$USERNAME_")\"
password = \"$(toml_escape "$PW_FIELD")\"
password_encrypted = $PW_ENCRYPTED

[ssh]
enabled = true
password_authentication = true
"

if [ "$NO_WIFI" -eq 0 ]; then
  TOML="$TOML
[wlan]
ssid = \"$(toml_escape "$SSID")\"
password = \"$(toml_escape "$WIFI_PASS")\"
password_encrypted = false
hidden = false
country = \"$(toml_escape "$COUNTRY")\"
"
fi

TOML="$TOML
[locale]
keymap = \"$(toml_escape "$KEYMAP")\"
timezone = \"$(toml_escape "$TIMEZONE_")\"
"

# --------------------------------------------------------------------- write

redact() { sed -e 's/^password = .*/password = "***"/'; }

# The trailing D forces the mode even when the projector is off or asleep at
# boot; without it a dark projector leaves the Pi with no display at all.
VIDEO_PARAM=""
[ -n "$HDMI_MODE" ] && VIDEO_PARAM="video=HDMI-A-1:${HDMI_MODE}D"

if [ "$DRY_RUN" -eq 1 ]; then
  printf -- '--- would write %s/custom.toml ---\n' "$BOOT"
  printf '%s' "$TOML" | redact
  [ -n "$VIDEO_PARAM" ] && printf -- '--- would append to cmdline.txt: %s ---\n' "$VIDEO_PARAM"
  printf -- '--- dry run, nothing changed ---\n'
  exit 0
fi

printf '%s' "$TOML" > "$BOOT/custom.toml"
note "wrote custom.toml"

# Belt and braces: the empty `ssh` file enables sshd on every Pi OS release,
# including ones that ignore custom.toml.
: > "$BOOT/ssh"
note "wrote ssh (enables sshd)"

# Force a display mode. On a Pi 4 the KMS driver ignores the legacy hdmi_*
# knobs in config.txt, so the working lever is the kernel `video=` parameter.
if [ -n "$VIDEO_PARAM" ]; then
  if grep -q 'video=HDMI-A-1' "$BOOT/cmdline.txt"; then
    note "cmdline.txt already pins a HDMI mode — leaving it alone"
  else
    # cmdline.txt must stay one single line. Read it, strip the line ending,
    # append, write it back. Done in pure bash because sed and perl both mangle
    # a mode string containing "@".
    cmdline="$(tr -d '\r\n' < "$BOOT/cmdline.txt")"
    printf '%s %s\n' "$cmdline" "$VIDEO_PARAM" > "$BOOT/cmdline.txt"
    note "pinned display mode in cmdline.txt: $VIDEO_PARAM"
  fi
fi

sync 2>/dev/null || true

cat <<EOF

Done. Next:
  1. Eject the card safely, put it in the Pi, connect HDMI and power.
  2. First boot takes 2-3 minutes (it resizes the filesystem and reboots once).
  3. From this machine:  ssh ${USERNAME_}@${HOSTNAME_}.local
     If .local does not resolve, find the Pi's IP in your router's client list.
  4. Then run the kiosk setup:
       scp setup-kiosk.sh ${USERNAME_}@${HOSTNAME_}.local:
       ssh ${USERNAME_}@${HOSTNAME_}.local 'bash setup-kiosk.sh'

EOF
