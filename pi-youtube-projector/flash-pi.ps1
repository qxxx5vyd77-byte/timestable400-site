<#
.SYNOPSIS
  Write headless first-boot config onto a freshly imaged Raspberry Pi OS SD card.
  Windows PowerShell counterpart to flash-pi.sh.

.DESCRIPTION
  Run this AFTER Raspberry Pi Imager has written the image and the card's boot
  partition has a drive letter. It writes a custom.toml that Raspberry Pi OS
  Bookworm (2023-10) and later read on first boot to set the hostname, create
  your user, enable SSH and join Wi-Fi - no keyboard or monitor needed.

.EXAMPLE
  .\flash-pi.ps1
  .\flash-pi.ps1 -Ssid "Basement" -PiHostname rowpi -HdmiMode 1920x1080@60

.NOTES
  If PowerShell refuses to run this, it is the execution policy, not the script:
    powershell -ExecutionPolicy Bypass -File .\flash-pi.ps1
#>

[CmdletBinding()]
param(
  [string] $BootDrive,                       # e.g. "D:" - autodetected if omitted
  [string] $PiHostname = "rowpi",
  [string] $PiUser     = "pi",
  [string] $Ssid,
  [string] $Country    = "US",
  [string] $Timezone   = "America/New_York",
  [string] $Keymap     = "us",
  [string] $HdmiMode,                        # e.g. "1920x1080@60"
  [switch] $NoWifi,
  [switch] $DryRun
)

$ErrorActionPreference = 'Stop'

function Test-BootPartition {
  param([string] $Path)
  (Test-Path (Join-Path $Path 'config.txt')) -and (Test-Path (Join-Path $Path 'cmdline.txt'))
}

# ------------------------------------------------------------- find the card

if (-not $BootDrive) {
  Write-Host "Looking for the SD card boot partition..."
  $hits = @(
    Get-PSDrive -PSProvider FileSystem |
      Where-Object { $_.Root -and (Test-BootPartition $_.Root) } |
      ForEach-Object { $_.Root }
  )
  switch ($hits.Count) {
    0 { throw "No boot partition found. Insert the card and pass -BootDrive D:" }
    1 { $BootDrive = $hits[0] }
    default {
      Write-Host "Multiple candidates found:"
      for ($i = 0; $i -lt $hits.Count; $i++) { Write-Host "  $($i+1)) $($hits[$i])" }
      $pick = Read-Host "Which one? [1]"
      if (-not $pick) { $pick = 1 }
      $BootDrive = $hits[[int]$pick - 1]
    }
  }
}

if (-not (Test-BootPartition $BootDrive)) {
  throw "$BootDrive does not look like a Pi boot partition (no config.txt / cmdline.txt)"
}
Write-Host "Boot partition: $BootDrive`n"

# custom.toml is only read by Bookworm and later. An older image ignores it
# silently, which looks identical to "the Pi never joined Wi-Fi", so warn.
$cfg = Get-Content (Join-Path $BootDrive 'config.txt') -Raw
if ($cfg -notmatch 'dtoverlay=vc4-kms-v3d') {
  Write-Warning "This image may predate Raspberry Pi OS Bookworm; custom.toml is only read by Bookworm (2023-10) and later. If the Pi never appears on the network, re-image with a current release."
}

# ------------------------------------------------------------------- gather

function Read-Secret {
  param([string] $Prompt)
  $secure = Read-Host -Prompt $Prompt -AsSecureString
  [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))
}

$PiPassword = Read-Secret "Login password for $PiUser"
if (-not $PiPassword) { throw "Login password cannot be empty" }

$WifiPassword = $null
if (-not $NoWifi) {
  if (-not $Ssid) { $Ssid = Read-Host "Wi-Fi network name (SSID), or blank for wired only" }
  if ($Ssid) { $WifiPassword = Read-Secret "Wi-Fi password for $Ssid" }
  else       { $NoWifi = $true }
}

# ------------------------------------------------------------ password hash

# Prefer a hashed password so it is not sitting in cleartext on a FAT
# partition any machine can read. Windows has no crypt(3), so this depends on
# openssl being on PATH (Git for Windows ships one). custom.toml accepts
# cleartext, so fall back to that rather than failing.
$pwEncrypted = 'false'
$pwField     = $PiPassword
if (Get-Command openssl -ErrorAction SilentlyContinue) {
  $pwField     = (& openssl passwd -6 $PiPassword).Trim()
  $pwEncrypted = 'true'
} else {
  Write-Warning "openssl not found - writing the login password in cleartext. Change it after first boot with: passwd"
}

function ConvertTo-TomlString {
  param([string] $Value)
  $Value -replace '\\', '\\\\' -replace '"', '\"'
}

# ---------------------------------------------------------------- compose

$sb = [System.Text.StringBuilder]::new()
[void]$sb.AppendLine('config_version = 1')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('[system]')
[void]$sb.AppendLine("hostname = `"$(ConvertTo-TomlString $PiHostname)`"")
[void]$sb.AppendLine('')
[void]$sb.AppendLine('[user]')
[void]$sb.AppendLine("name = `"$(ConvertTo-TomlString $PiUser)`"")
[void]$sb.AppendLine("password = `"$(ConvertTo-TomlString $pwField)`"")
[void]$sb.AppendLine("password_encrypted = $pwEncrypted")
[void]$sb.AppendLine('')
[void]$sb.AppendLine('[ssh]')
[void]$sb.AppendLine('enabled = true')
[void]$sb.AppendLine('password_authentication = true')

if (-not $NoWifi) {
  [void]$sb.AppendLine('')
  [void]$sb.AppendLine('[wlan]')
  [void]$sb.AppendLine("ssid = `"$(ConvertTo-TomlString $Ssid)`"")
  [void]$sb.AppendLine("password = `"$(ConvertTo-TomlString $WifiPassword)`"")
  [void]$sb.AppendLine('password_encrypted = false')
  [void]$sb.AppendLine('hidden = false')
  [void]$sb.AppendLine("country = `"$(ConvertTo-TomlString $Country)`"")
}

[void]$sb.AppendLine('')
[void]$sb.AppendLine('[locale]')
[void]$sb.AppendLine("keymap = `"$(ConvertTo-TomlString $Keymap)`"")
[void]$sb.AppendLine("timezone = `"$(ConvertTo-TomlString $Timezone)`"")

# The trailing D forces the mode even when the projector is off or asleep at
# boot; without it a dark projector leaves the Pi with no display at all.
$videoParam = if ($HdmiMode) { "video=HDMI-A-1:${HdmiMode}D" } else { $null }

# ------------------------------------------------------------------- write

$tomlPath    = Join-Path $BootDrive 'custom.toml'
$cmdlinePath = Join-Path $BootDrive 'cmdline.txt'

if ($DryRun) {
  Write-Host "--- would write $tomlPath ---"
  Write-Host ($sb.ToString() -replace '(?m)^password = .*', 'password = "***"')
  if ($videoParam) { Write-Host "--- would append to cmdline.txt: $videoParam ---" }
  Write-Host "--- dry run, nothing changed ---"
  return
}

# Pi OS firmware wants LF and no BOM. Set-Content on Windows would give it
# CRLF and, on Windows PowerShell 5.1, a UTF-8 BOM.
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText($tomlPath, ($sb.ToString() -replace "`r`n", "`n"), $utf8NoBom)
Write-Host "  wrote custom.toml"

# The empty `ssh` file enables sshd on every Pi OS release, including ones
# that ignore custom.toml.
[System.IO.File]::WriteAllText((Join-Path $BootDrive 'ssh'), '', $utf8NoBom)
Write-Host "  wrote ssh (enables sshd)"

# Force a display mode. On a Pi 4 the KMS driver ignores the legacy hdmi_*
# knobs in config.txt, so the working lever is the kernel `video=` parameter.
if ($videoParam) {
  $cmdline = [System.IO.File]::ReadAllText($cmdlinePath)
  if ($cmdline -match 'video=HDMI-A-1') {
    Write-Host "  cmdline.txt already pins a HDMI mode - leaving it alone"
  } else {
    # cmdline.txt must stay one single line.
    $cmdline = ($cmdline -replace '[\r\n]', '').TrimEnd()
    [System.IO.File]::WriteAllText($cmdlinePath, "$cmdline $videoParam`n", $utf8NoBom)
    Write-Host "  pinned display mode in cmdline.txt: $videoParam"
  }
}

Write-Host @"

Done. Next:
  1. Eject the card safely, put it in the Pi, connect HDMI and power.
  2. First boot takes 2-3 minutes (it resizes the filesystem and reboots once).
  3. From this machine:  ssh $PiUser@$PiHostname.local
     If .local does not resolve, find the Pi's IP in your router's client list.
  4. Then run the kiosk setup:
       scp setup-kiosk.sh ${PiUser}@${PiHostname}.local:
       ssh ${PiUser}@${PiHostname}.local "bash setup-kiosk.sh"

"@
