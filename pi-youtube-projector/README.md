# Raspberry Pi 4 → basement projector → YouTube

A Pi 4 set up as a hands-off YouTube appliance for a projector, so you can
queue and control videos from your phone while you're on the rowing machine.

Two scripts: one runs on your Mac or PC to prep the SD card, one runs on the
Pi to build the kiosk.

---

## Read this before you buy anything

**A Pi 4 is a workable YouTube box, not a great one.** The honest tradeoffs:

- The Pi 4 has hardware decoding for **H.264 and H.265, but not VP9 or AV1** —
  and VP9/AV1 is what YouTube serves by default. Those fall back to software
  decode on the CPU. In practice: 1080p30 is fine, 1080p60 drops frames, 4K is
  out of the question. There's a workaround below (`--force-h264`).
- A **Chromecast with Google TV, Fire TV Stick, or Roku** costs $30–50, does
  this with zero setup, handles 4K, and has a real remote. If the Pi isn't
  already sitting in a drawer, buy one of those instead.

**Where the Pi genuinely wins:** it's a general-purpose computer you already
own, it boots straight into what you want with no ads on a home screen, and
you can bend it to anything else later.

## What you need

- Raspberry Pi 4 (2GB is enough; 4GB is comfortable)
- Official 15W USB-C power supply — an underpowered phone charger causes
  throttling that looks exactly like "YouTube is choppy"
- microSD card, 16GB+, decent brand
- micro-HDMI → HDMI cable (the Pi 4 uses **micro**-HDMI, not mini, and not
  full-size — this trips up nearly everyone)
- The projector, and speakers if the projector's are weak

Audio note: many projectors have thin or no speakers. The Pi can send audio out
HDMI to the projector or out the 3.5mm jack to powered speakers — the setup
script handles both.

---

## Step 1 — image the card

Install [Raspberry Pi Imager](https://www.raspberrypi.com/software/) on your
Mac or PC. Choose:

- **Device:** Raspberry Pi 4
- **OS:** Raspberry Pi OS (64-bit) — the **full desktop** version, *not* Lite.
  The kiosk needs a desktop session.
- **Storage:** your card

Imager will offer to preconfigure hostname, user, Wi-Fi and SSH. You can do it
there and skip Step 2 entirely. `flash-pi.sh` exists for when you'd rather have
the settings in a file you can re-run, tweak, and keep in version control.

## Step 2 — write the headless config

With the card still inserted after imaging (the `bootfs` partition should be
mounted), from the repo directory:

**macOS, Linux, WSL, or Git Bash on Windows**

```bash
./flash-pi.sh
```

**Windows PowerShell**

```powershell
powershell -ExecutionPolicy Bypass -File .\flash-pi.ps1
```

Both prompt for anything you don't pass as a flag, and both find the boot
partition themselves. Non-interactive example:

```bash
./flash-pi.sh --hostname rowpi --user pi --ssid "Basement" \
              --country US --timezone America/New_York \
              --hdmi-mode 1920x1080@60
```

Add `--dry-run` to see exactly what it would write without touching the card.

Useful flags:

| Flag | Why |
|---|---|
| `--hdmi-mode 1920x1080@60` | Pins the output mode and forces it even when the projector is off or asleep at boot. Without this a cold projector can leave the Pi with no display at all. |
| `--hdmi-mode 1280x720@60` | Run at 720p. The single most effective fix for stuttering — see Playback below. |
| `--no-wifi` | Wired ethernet only. |

Then eject the card safely, put it in the Pi, connect HDMI and power.

**First boot takes 2–3 minutes** — it expands the filesystem and reboots once.

## Step 3 — build the kiosk

```bash
scp setup-kiosk.sh pi@rowpi.local:
ssh pi@rowpi.local 'bash setup-kiosk.sh'
sudo reboot        # or: ssh pi@rowpi.local 'sudo reboot'
```

If `rowpi.local` doesn't resolve, find the Pi's IP in your router's client list
and use that.

`setup-kiosk.sh` configures:

- autologin straight to the desktop, no login prompt
- Chromium fullscreen on the YouTube TV interface, launched on session start
- screen blanking off, so the projector never goes dark mid-row
- mouse pointer hidden
- the browser relaunched automatically if it crashes
- audio routed to HDMI (or `--audio jack` for the headphone socket)
- the X11 session rather than Wayland — both can run a kiosk, but under Wayland
  on Pi OS the pointer-hiding and screensaver tools are silently no-ops, and you
  end up with a cursor parked in the middle of the picture

## Step 4 — pair your phone

This is the part that makes it worth doing. On the projector screen:

1. **Settings → Link with TV code**
2. Phone YouTube app → your profile → **Settings → Watch on TV → Enter TV code**

From then on, the cast icon in the phone app queues anything straight to the
projector. No keyboard, no getting off the erg.

---

## Playback quality

If video stutters, work through these in order — they're ranked by how much
they actually help:

1. **Drop to 720p.** Re-run `flash-pi.sh --hdmi-mode 1280x720@60`. YouTube then
   serves a 720p stream, which the Pi 4 decodes comfortably even in software.
   On a projector at basement viewing distance the difference is much smaller
   than the frame drops are.
2. **Force H.264.** Re-run the setup with `--force-h264`. This installs a
   browser policy that force-installs the `enhanced-h264ify` extension, which
   makes YouTube offer H.264 — which the Pi 4 *does* decode in hardware.
   **Verify it worked:** open `chrome://extensions` on the Pi. If nothing is
   listed, the extension ID baked into `setup-kiosk.sh` (`H264IFY_ID`) is stale
   — get the current one from the extension's Chrome Web Store URL and edit it.
3. **Check power.** Under-voltage throttles the CPU and looks just like a codec
   problem. Run `vcgencmd get_throttled` on the Pi — anything other than
   `throttled=0x0` means your power supply or cable is the real culprit.
4. **Check temperature.** `vcgencmd measure_temp`. Sustained video decode in a
   closed case will thermally throttle a bare Pi 4. A $5 heatsink fixes it.

## Everyday operation

| Task | How |
|---|---|
| Get out of the kiosk | `Ctrl+Alt+F2` for a console, or just SSH in |
| Change the URL or Chromium flags | Edit `~/youtube-kiosk/start-kiosk.sh` on the Pi, then reboot |
| Use the normal desktop YouTube site | Re-run setup with `--plain-youtube` |
| Point it somewhere else entirely | Re-run setup with `--url https://...` |
| Remove everything | `bash setup-kiosk.sh --uninstall` |

## If the TV interface stops loading

`youtube.com/tv` is served based on the browser's user agent, and the setup
presents itself as a Chromecast to get it. This is not a documented or
supported interface — YouTube can change it, and the user-agent string in
`setup-kiosk.sh` (`TV_USER_AGENT`) can go stale.

If the TV UI stops appearing, fall back to the normal site:

```bash
bash setup-kiosk.sh --plain-youtube
```

You lose phone pairing and gain the need for a remote. A cheap Bluetooth
media remote or air mouse works well and lives on the erg.

## Security notes

- `custom.toml` sits on the card's FAT boot partition, which **any** computer
  can read. The scripts hash the login password when `openssl` is available,
  but the **Wi-Fi password is stored in cleartext** — that's inherent to how
  Pi OS first-boot provisioning works. Treat the card as sensitive, and don't
  hand it to anyone you wouldn't give your Wi-Fi password to.
- The setup enables SSH with password authentication so you can reach the Pi
  headlessly. If this Pi is ever reachable from outside your LAN, switch to key
  authentication and turn passwords off.

## Status

Written and reviewed, but **not tested against real hardware** — there was no
Pi in the loop when these were written. The shell scripts were syntax-checked
and their generated output verified; `flash-pi.ps1` could not be checked at all
(no PowerShell available). Expect to hit at least one thing that needs a nudge,
most likely a package name or a raspi-config option that moved between OS
releases. The scripts print what they're doing at each step so failures are
easy to localise.
