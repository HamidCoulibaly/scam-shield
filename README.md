# Scam Shield: daily scam-number collector

Builds one list of scam numbers every day for the Scam Shield iPhone app. The app hands the list to iOS, which then blocks or labels those numbers on incoming calls.

```
your reports ─┐
licensed feed ─┼─► collector.py ─► dist/scamlist.json ─► iPhone app ─► iOS call blocking
allowlist ─────┘    (daily, GitHub Actions)
```

## What it does

- Accepts numbers in any format (`07700 900123`, `+44 7700 900123`, `0044…`) and converts them to the international form iOS needs (`447700900123`).
- **Your reports are always trusted.** They're blocked, or only labelled if you use `--label-only`.
- **Community feeds are filtered:** a score of 9/9 is blocked, 7–8 is labelled "Likely scam", and anything with fewer than 3 reports or older than 180 days is ignored.
- **Range detection:** when 3 or more flagged numbers share the same first digits (for example 07700 9002xx), the other numbers in that block of 100 are labelled "Possible scam". This catches scammers who step through neighbouring numbers.
- **The allowlist always wins.** Family, your GP, your bank's real number and so on are never blocked.
- **Safety checks:**
  - one broken feed doesn't stop the build
  - the list isn't published if it shrinks by more than 50% (usually a sign a feed failed)
  - both lists come out sorted with no duplicates, as iOS requires

All rules can be changed in `collector/sources.json`.

## Daily use (on your Mac)

```bash
cd collector
python3 collector.py add "07700 900123" --label "Fake HMRC"    # a number that called you
python3 collector.py add "020 7946 0555" --label-only          # suspicious, don't block yet
python3 collector.py allow "01189 000000" --label "GP surgery"  # never block
python3 collector.py build
python3 collector.py check 07700900123
```

Expected output from `build` with those two reports:

```
Sources:
  allowlist        1 protected number(s)
  my reports       2 used, 0 skipped
  tellows          disabled
  range detection  0 range(s), 0 numbers added

Published dist/scamlist.json: 1 blocked, 1 labelled (+2 new, -0 removed since last build)
```

and `check 07700900123` prints `07700 900123: BLOCKED`.

Tests: `python3 -m unittest discover -s tests`. Expected output: `Ran 7 tests ... OK`.

## Running it daily (GitHub)

1. Create a **public** GitHub repo called `scam-shield` and push this folder to it. It has to be public so the iPhone app can download the list without a password. Only scam numbers are published: `data/allowlist.csv` is in `.gitignore` and never leaves your Mac.
2. Copy your allowlist into a repository secret called `SCAM_SHIELD_ALLOWLIST` (Settings > Secrets > Actions), one number per line, so the daily build protects those numbers too.
3. In the repo, go to **Actions** and enable workflows. The list then rebuilds at 04:17 UTC every day, and whenever you push a new report.
4. Run it once by hand (Actions > Daily scam list > Run workflow). Expected result: a green tick and a commit called "Daily scam list YYYY-MM-DD".
5. The app will download from:
   `https://raw.githubusercontent.com/<your-github-name>/scam-shield/main/collector/dist/scamlist.json`

## Adding the tellows feed later

Once you have tellows partner access, add the feed URL as a repository secret called `TELLOWS_FEED_URL` (Settings > Secrets > Actions), then set `"enabled": true` for tellows in `sources.json`. If their export uses different column names, tell me and I'll map them.

## Next: the iPhone app

A small Swift app with a Call Directory extension. It downloads `scamlist.json` daily, checks the `.sha256` file, loads both lists into iOS, and has a "Report this number" button that adds to your reports.
