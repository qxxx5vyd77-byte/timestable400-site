# x-poster

A small, **standalone** Python tool to post to X (Twitter) via the official API,
and to poll your mentions and reply to them. It shares no code with the rest of
this repo — you can copy the `x-poster/` folder straight onto the iMac and run
it there.

## What it does

| Capability            | API tier needed | Notes |
|-----------------------|-----------------|-------|
| Post a single tweet   | **Free ($0)**   | Text only or with media |
| Post a thread         | **Free ($0)**   | Chained replies |
| Attach image/video    | **Free ($0)**   | Uses v1.1 media upload |
| Poll mentions + reply | **Basic (paid)**| Reading mentions consumes read quota that Free doesn't have |

Everything defaults to **dry-run** — it logs what it *would* do and posts
nothing until you pass `--live`. So you can build and test the whole pipeline
without spending a cent or risking an accidental tweet.

> Honest cost note: **posting is free**; only the **read/respond** loop needs
> the paid Basic tier (~$100–200/month, recurring). Your consumer X Premium
> subscription does **not** include API access — that's a separate signup at
> developer.x.com.

## Setup (on the iMac)

1. **Create the developer app** at <https://developer.x.com>:
   - New Project + App
   - App → *User authentication settings* → **Read and Write**
   - *Keys and tokens* → generate **API Key/Secret** and **Access Token/Secret**
   - ⚠️ If you set Read/Write *after* minting tokens, **regenerate** the Access
     Token/Secret — old ones stay read-only and posting 403s.

2. **Install:**
   ```bash
   cd x-poster
   python3 -m venv .venv && source .venv/bin/activate
   pip install -r requirements.txt
   cp config.example.toml config.toml   # then paste your 4 keys in
   ```
   (`config.toml` is gitignored — your secrets never get committed.)

3. **Verify credentials:**
   ```bash
   python -m x_poster.cli whoami
   ```

## Usage

```bash
# Dry-run by default — nothing is posted:
python -m x_poster.cli post "hello from the API"
python -m x_poster.cli post "with a reel" --media ../math-day001.mp4
python -m x_poster.cli thread "1/ setup" "2/ detail" "3/ wrap"
python -m x_poster.cli mentions

# Add --live to actually post:
python -m x_poster.cli post "for real this time" --live
```

## Scheduling mentions (launchd)

See `launchd/com.xposter.mentions.plist` — edit the two `EDIT_ME_*` paths, then:

```bash
cp launchd/com.xposter.mentions.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.xposter.mentions.plist
tail -f /tmp/xposter.mentions.log
```

It runs every 15 minutes. Keep `--live` out of the plist until the dry-run logs
look right.

## Customizing replies

Edit `x_poster/respond.py` → `decide_reply()`. Return the reply text, or
`None` to ignore a mention. It's deliberately conservative (ignores by default)
so the bot never spam-replies. Later this is the natural place to plug in an LLM.

## Files

```
x-poster/
├── README.md
├── requirements.txt
├── config.example.toml     # template → copy to config.toml
├── x_poster/
│   ├── config.py           # loads env vars / config.toml
│   ├── client.py           # tweepy wrapper: post, thread, media, mentions
│   ├── respond.py          # mention → reply rules (edit me)
│   ├── state.py            # tracks last-seen mention id
│   └── cli.py              # command-line entry point
├── launchd/
│   └── com.xposter.mentions.plist
└── state/                  # runtime state (gitignored)
```
