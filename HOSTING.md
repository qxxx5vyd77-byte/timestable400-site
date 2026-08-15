# Video hosting migration — GitHub Pages → Cloudflare R2

## Why

Git history keeps every byte of every committed video forever — deletes don't reclaim
space, and this repo is at ~326 MB growing ~60 MB/week against a ~1 GB GitHub Pages cap.
R2 is object storage: files get a public URL, deletes actually delete, and the free tier
(10 GB storage, **zero egress fees**) covers years at current volume.

**Plan:** new videos go to R2 from now on. Everything already in the repo stays put —
published URLs keep working. This repo goes back to being the TT400 support site plus
legal/OAuth pages.

## One-time setup (~20 minutes)

### 1. Create the bucket

1. Cloudflare dashboard → **R2 Object Storage** → *Create bucket*.
   (First time: R2 asks for a payment card even on the free tier — normal, nothing is charged
   under 10 GB.)
2. Name it `media`. Location: automatic.

### 2. Make it public

Two options — pick one:

- **Custom domain (recommended):** bucket → *Settings* → *Custom Domains* → add
  `media.matthewmalham.com`. Cloudflare creates the DNS record if the zone is already on
  Cloudflare. URLs look like `https://media.matthewmalham.com/<file>`. Cacheable, brandable,
  and survives any later storage move (repoint the subdomain, no post ever breaks).
- **r2.dev subdomain (quick start):** bucket → *Settings* → *Public access* → *Allow*.
  URLs look like `https://pub-<hash>.r2.dev/<file>`. Fine for testing; rate-limited and
  ugly — switch to the custom domain before wiring it into publishing scripts.

### 3. Create an API token for uploads

1. R2 overview page → *Manage R2 API Tokens* → *Create API Token*.
2. Permissions: **Object Read & Write**, scoped to the `media` bucket only.
3. Save the **Access Key ID** and **Secret Access Key** (shown once).
4. Note your **Account ID** (dashboard sidebar) — the S3 endpoint is
   `https://<ACCOUNT_ID>.r2.cloudflarestorage.com`.

### 4. Configure rclone

```ini
# ~/.config/rclone/rclone.conf
[r2]
type = s3
provider = Cloudflare
access_key_id = <ACCESS_KEY_ID>
secret_access_key = <SECRET_ACCESS_KEY>
endpoint = https://<ACCOUNT_ID>.r2.cloudflarestorage.com
```

Verify: `rclone lsd r2:` should list the `media` bucket.

## Daily workflow (replaces git add/commit/push for videos)

```sh
rclone copy wg_20260816_tokyo.mp4 r2:media/
# live seconds later at:
# https://media.matthewmalham.com/wg_20260816_tokyo.mp4
```

- Same [naming convention](README.md#naming-convention-new-files):
  `project_YYYYMMDD_slug.ext`, all lowercase.
- `rclone copy` is idempotent — re-running skips files already uploaded.
- To overwrite a bad upload: `rclone copyto <local> r2:media/<name>` (same name replaces it).
- To delete: `rclone delete r2:media/<name>` — gone for real, unlike git.

Update the README manifest when a lane's canonical asset moves to R2 — link the full R2 URL
in the manifest row so scripts and future-you know where it lives.

## Later cleanup (optional, after R2 is proven)

1. **Delete superseded files** from the repo working tree (start with
   `zonecycle-reel-01/02/03`, 88 MB) — trims the *deployed site* toward the Pages cap even
   though `.git` keeps the bytes.
2. **Full history purge** (`git filter-repo --strip-blobs-bigger-than 1M`) only if repo
   size itself ever becomes a problem — this breaks every existing Pages video URL, so
   first confirm nothing still hotlinks them. IG/TikTok copy media at publish time, so
   published posts don't care.

## Cost reality check

| | GitHub Pages (today) | R2 |
|---|---|---|
| Storage | hard ~1 GB site cap | 10 GB free, then $0.015/GB-mo |
| Bandwidth | soft 100 GB/mo | free, unmetered |
| Deletes | never reclaim history | real |
| Publish latency | push + Pages build | instant on upload |
