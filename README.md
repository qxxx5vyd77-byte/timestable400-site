# timestable400-site

Two jobs live in this repo:

1. **Times Table 400 support site** — `index.html`, `privacy.html` (the repo's original purpose).
2. **Media host for social publishing** — reels, carousels, and story cards for the other app lanes, served via GitHub Pages and referenced by IG/TikTok publishing flows.

Job 2 is slated to move to object storage (Cloudflare R2 or similar) — git history keeps every
byte of every video forever, and Pages caps a site around 1 GB. Until then, this file is the map.

## Naming convention (new files)

```
<project>_<YYYYMMDD>_<slug>.<ext>
```

- **All lowercase.** URLs are case-sensitive; one capital letter is a silent 404 in any scripted publish.
- Underscores between the three fields; hyphens allowed inside the slug.
- Project codes: `wg` `zc` `lsd` `kanji` `math` `hardtime` `wardial` `qso` `softly` `sg` `gemgnome` `tt400`.
- Example: `wg_20260814_shenzhen.mp4`.

Files that predate this convention are **grandfathered — do not rename them**: their URLs are
already embedded in published posts, and duplicating them under new names would double the
deployed site. Scripts should take filenames from the manifest below, never construct them.

## Lane manifest

Status: **live** = current canonical asset for the lane · **superseded** = replaced by a newer cut,
keep until the hosting migration (then delete) · **archive** = published, kept for reference.

### Times Table 400 (the app this site is for)
| Asset | Status |
|---|---|
| `index.html`, `privacy.html` | live — support site |
| `tt400_reel_A.mp4` | archive |

### Weather Gnome — daily reels (the streak lane)
| Asset | Status |
|---|---|
| `wg_20260814_shenzhen.mp4` | live — latest daily |
| `wg_20260731_wg-paris.mp4` … `wg_20260813_wg-daily.mp4` | archive — prior dailies |
| `wg_bogota_dawn.mp4`, `weather-gnome-reel.mp4`, `wg-gnome-parade.mp4` | archive |
| `wg-story-1-tokyo.png` … `wg-story-5-appstore.png` | archive — story set |

### ZoneCycle
| Asset | Status |
|---|---|
| `zonecycle-wedge-20260812.mp4` | live — derived-watts wedge (latest hook test) |
| `zonecycle-reel-hook-20260811.mp4`, `ZoneCycle_heroflip_20260810.mp4` | archive — earlier hook tests (note: heroflip filename has capitals; copy it exactly) |
| `zonecycle-reel-01-2957.mp4`, `-02-2960`, `-03-2961` | superseded — 88 MB, first to delete after migration |
| `zonecycle_ai_spot_v1.mp4`, `zonecycle_ai_spot_v1-voice-branded.mp4` | archive |
| `zonecycle-vicky-coach-master.mp4`, `zonecycle-vicky-coach-ig.mp4` | archive |
| `zc_20260801_coaches.mp4`, `zonecycle_promo_reel_15s.mp4` | archive |

### @localsingledogs (IG API lane)
| Asset | Status |
|---|---|
| `lsd_01_brayden_{match,profile}.png` | live — carousel pair |
| `lsd_03_chief_reel.mp4`, `lsd_04_winnie_reel.mp4` | live — reels, handle burned in |
| `lsd_07_marlowe_{match,profile}.png`, `lsd_08_biscuit_{match,profile}.png`, `lsd_09_hank_{match,profile}.png` | live — carousel pairs |
| `lsd_10_kenji_reel.mp4` | live — audio reel |

### Kanji of the Day
| Asset | Status |
|---|---|
| `kanji-ab-countdown.mp4` | live — countdown-first A/B variant |
| `kanji-day003.mp4` … `kanji-day020.mp4`, `kanji-day01-yama.mp4`, `kanji-day02-kawa.mp4` | archive — daily series |
| `kanji-day007-silent.mp4` | archive — silent master for TikTok manual upload |
| `kanji100_reel_fast.mp4` | archive |

### Mental Math
| Asset | Status |
|---|---|
| `math-day001.mp4` … `math-day112.mp4` (15 clips) | archive — daily series |

### WARDIAL
| Asset | Status |
|---|---|
| `wardial-reel-f-20260812.mp4` | live — latest |
| `wardial-reel-a-the-decision-v2.mp4` … `wardial-reel-e-the-opponent.mp4` | archive — tier-2 spot lane |

### QSO Globe
| Asset | Status |
|---|---|
| `qsoglobe-vo-20260814.mp4` | live — VO cut for IG fan-out |
| `qsoglobe-teaser.mp4`, `qsoglobe-teaser-music.mp4` | archive |

### Hard Time
| Asset | Status |
|---|---|
| `hardtime-launch.mp4` | archive — launch reel (app live 8/4) |
| `hardtime-room-ig.mp4`, `hardtime-room-b-ig.mp4` | archive — THE ROOM music cuts |
| `hardtime-story-card.jpg` | archive |

### Softly
| Asset | Status |
|---|---|
| `softly_20260801_rainstory.mp4`, `softly_20260803_ep2_timer.mp4`, `softly_20260804_ep3_mix.mp4` | archive — episode reels |

### Stock Gnome
| Asset | Status |
|---|---|
| `sg_20260803_react_music.mp4` | archive — market-react reel with music bed |
| `sg_20260803_react.mp4`, `stock-gnome-meadow.mp4`, `stock-gnome-stomp-v2.mp4` | archive |

### Gem Gnome
| Asset | Status |
|---|---|
| `gemgnome-reel.mp4` | live — launch reel (8/11) |

### Misc / infra
| Asset | Status |
|---|---|
| `rrl-privacy.html`, `rrl-terms.html` | live — RRL Poster legal pages |
| `tiktok-callback.html` | live — RRL Poster TikTok OAuth callback |
| `tiktok5WbCX9NtTnTPv0a1htMSIgEhEFbE2C4J.txt` | live — TikTok domain verification, do not touch |
| `stories-cob-20260731/story_[1-4].png` | archive — story set |
