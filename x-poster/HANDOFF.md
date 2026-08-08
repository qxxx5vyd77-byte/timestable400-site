# x-poster — Handoff / Resume Notes

Status snapshot for continuing this work in another session (e.g. on the Mac
mini). Read this top to bottom, then jump to **"Pick up here."**

## Goal

Post to the user's X account via the **official X API** (not browser automation),
running on the user's **Mac mini** (always-on, now online at a vacation place).
Two capabilities:
1. Publish the user's own content (text / images / video). — works on Free tier
2. Poll mentions and reply. — needs paid read access

## What's already DONE

- ✅ **Tool is built and pushed** to branch `claude/mac-mini-x-chrome-posting-9m1rpm`
  in repo `qxxx5vyd77-byte/timestable400-site`, under the `x-poster/` folder.
  Self-contained Python (tweepy); shares no code with the site.
- ✅ **Tested in dry-run** in the cloud session: config-error path, post-with-media,
  and thread all work. Byte-compiles clean.
- ✅ **X developer app fully configured** by the user on the phone:
  - Developer account/org name: **River Road Labs**
  - App permissions: **Read and Write** (DMs intentionally OFF — least privilege)
  - App type: **Web App, Automated App or Bot** (Confidential client)
  - Callback URI: `https://localhost/` (placeholder; 3-legged flow not used)
  - Website URL: a real domain (localhost was rejected by X's validator)
- ✅ **User has generated and saved all four OAuth 1.0a credentials**
  (API Key, API Secret, Access Token, Access Token Secret). Access token is
  Read+Write. The user has these saved privately — they were deliberately NOT
  shared into chat and must NOT be committed anywhere.
- ✅ User purchased **$25 in X API credits**. NOTE: this implies X now has a
  metered/pay-as-you-go model. We have NOT yet confirmed the per-post cost —
  verify empirically on the first live post (see below).

## Capabilities & the code

```
x-poster/
├── README.md               # full setup + usage docs
├── HANDOFF.md              # this file
├── requirements.txt        # tweepy
├── config.example.toml     # template → copy to config.toml (gitignored)
├── x_poster/
│   ├── config.py           # loads env vars OR config.toml; hard error if missing
│   ├── client.py           # tweepy wrapper: post / thread / media / mentions
│   ├── respond.py          # mention→reply rules (ignores by default; edit me)
│   ├── state.py            # tracks last-seen mention id
│   └── cli.py              # CLI entry: whoami / post / thread / mentions
├── launchd/
│   └── com.xposter.mentions.plist   # scheduled mentions poller (edit EDIT_ME_* paths)
└── state/                  # runtime state (gitignored)
```

Everything defaults to **dry-run**; add `--live` to actually post.

## PICK UP HERE — remaining steps (run on the Mac mini)

1. Get the code onto the Mac mini:
   ```bash
   cd ~ && git clone https://github.com/qxxx5vyd77-byte/timestable400-site.git
   cd timestable400-site/x-poster
   git checkout claude/mac-mini-x-chrome-posting-9m1rpm
   ```
   (If already cloned: `git pull origin claude/mac-mini-x-chrome-posting-9m1rpm`)

2. Python env + deps:
   ```bash
   python3 -m venv .venv && source .venv/bin/activate
   pip install -r requirements.txt
   ```

3. Credentials — user pastes their 4 saved keys:
   ```bash
   cp config.example.toml config.toml
   open -e config.toml     # paste api_key / api_secret / access_token / access_token_secret
   ```
   (config.toml is gitignored — never commit it.)

4. **Smoke test** (the go/no-go gate):
   ```bash
   python -m x_poster.cli whoami      # → "Authenticated as @handle"
   ```
   - 401 → a key was mistyped (stray space). 403 → token is read-only, regenerate.

5. First real post — confirm cost:
   ```bash
   python -m x_poster.cli post "test from the API"           # dry-run
   python -m x_poster.cli post "test from the API" --live     # real, public
   ```
   Then check the X console credit balance to measure per-post cost and settle
   the pricing question.

6. (Optional) Schedule mentions polling: edit the two `EDIT_ME_*` paths in
   `launchd/com.xposter.mentions.plist`, then `cp` it to `~/Library/LaunchAgents/`
   and `launchctl load` it. Keep `--live` out of the plist until dry-runs look right.

## Open questions / next features discussed (not yet built)

- (a) Auto-tweet when a new video is added to the site.
- (b) Smarter `respond.py` reply logic (later: LLM-backed).
- Confirm the credit/metered pricing model and per-post cost after the first live post.

## Guardrails (important)

- Never commit `config.toml`, `.env`, or the token values. `.gitignore` covers them.
- Keep DM scope off unless a DM use case is added.
- The first `--live` post is real and public — use throwaway text and delete after if desired.
