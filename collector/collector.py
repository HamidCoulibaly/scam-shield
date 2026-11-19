#!/usr/bin/env python3
"""
Scam Shield collector - builds the daily scam-number list for the iPhone app.

Commands
  build              Merge all sources into dist/scamlist.json (default)
  add NUMBER         Add a number you were called by to data/my_reports.csv
  allow NUMBER       Add a number that must never be blocked to data/allowlist.csv
  check NUMBER       Show what the current list does with a number

Sources are listed in sources.json. Two kinds:
  csv       a local CSV file           (columns below)
  csv_url   a CSV fetched over HTTPS   (e.g. a licensed tellows export)

CSV columns (header row required, extra columns ignored):
  number       any UK/intl format: 07700 900123, +44 20 7946 0001, 0044...
  action       optional: block | label   (own reports only)
  score        optional: 1-9 community spam score (external feeds)
  reports      optional: how many people reported it
  label        optional: text shown on the incoming-call screen
  reported_at  optional: YYYY-MM-DD

Output (dist/scamlist.json), ready for Apple's Call Directory extension:
  {"version": "...", "block": [447700900123, ...], "identify": [[447700900124, "Likely scam"], ...]}
  Both lists are sorted ascending with no duplicates, as iOS requires.

Standard library only.
"""
import argparse
import csv
import datetime as dt
import hashlib
import io
import json
import os
import re
import sys
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
TODAY = dt.date.today()

# ------------------------------------------------------------------ numbers

def normalise(raw):
    """Return the number as international digits (e.g. 447700900123), or None if unusable."""
    if raw is None:
        return None
    s = str(raw).strip()
    plus = s.startswith("+")
    digits = re.sub(r"\D", "", s)
    if not digits:
        return None
    if plus:
        pass                                   # +44..., +33... already international
    elif digits.startswith("00"):
        digits = digits[2:]                    # 0044... -> 44...
    elif digits.startswith("0"):
        digits = "44" + digits[1:]             # UK national 07700... -> 447700...
    elif digits.startswith("44"):
        pass
    else:
        return None                            # ambiguous: no country code
    if digits.startswith("44"):
        if not 11 <= len(digits) <= 12:        # UK numbers are 9-10 digits after +44
            return None
    elif not 8 <= len(digits) <= 15:
        return None
    return int(digits)


def pretty(n):
    s = str(n)
    if s.startswith("44"):
        rest = "0" + s[2:]
        if rest.startswith("07") or rest.startswith("08"):
            return f"{rest[:5]} {rest[5:]}"
        if rest.startswith("02"):
            return f"{rest[:3]} {rest[3:7]} {rest[7:]}"
        return f"{rest[:5]} {rest[5:]}"
    return "+" + s


# ------------------------------------------------------------------ sources

def read_csv_text(text):
    return list(csv.DictReader(io.StringIO(text)))


def load_source(src, base):
    if src["type"] == "csv":
        path = os.path.join(base, src["path"])
        if not os.path.exists(path):
            return []
        with open(path, newline="", encoding="utf-8") as f:
            return list(csv.DictReader(f))
    if src["type"] == "csv_url":
        url = os.path.expandvars(src.get("url", ""))
        if not url or "$" in url:
            raise RuntimeError("no URL set (check the environment variable)")
        req = urllib.request.Request(url, headers={"User-Agent": "scam-shield-collector/1.0"})
        with urllib.request.urlopen(req, timeout=60) as r:
            return read_csv_text(r.read().decode("utf-8", errors="replace"))
    raise ValueError(f"unknown source type {src['type']}")


def parse_date(s):
    try:
        return dt.date.fromisoformat((s or "").strip()[:10])
    except ValueError:
        return None


def to_int(s, default=0):
    try:
        return int(float(str(s).strip()))
    except (ValueError, TypeError):
        return default


# ------------------------------------------------------------------ build

def build(cfg, base, previous=None):
    rules = cfg["rules"]
    block, identify = {}, {}          # number -> reason / label
    stats = {}

    # Allowlist: local file (kept out of git) plus, on GitHub, the SCAM_SHIELD_ALLOWLIST secret.
    allow = set()
    rows = load_source({"type": "csv", "path": cfg["allowlist"]}, base)
    if os.environ.get("SCAM_SHIELD_ALLOWLIST"):
        rows += read_csv_text("number,note\n" + os.environ["SCAM_SHIELD_ALLOWLIST"])
    for row in rows:
        n = normalise(row.get("number"))
        if n:
            allow.add(n)
    stats["allowlist"] = f"{len(allow)} protected number(s)"

    for src in cfg["sources"]:
        name = src["name"]
        if not src.get("enabled", True):
            stats[name] = "disabled"
            continue
        try:
            rows = load_source(src, base)
        except Exception as e:                       # one bad feed must not kill the build
            stats[name] = f"ERROR: {e}"
            continue
        used = skipped = 0
        for row in rows:
            n = normalise(row.get("number"))
            if not n or n in allow:
                skipped += 1
                continue
            label = (row.get("label") or "").strip()
            if src.get("trust") == "own":
                if (row.get("action") or "block").strip().lower() == "label":
                    identify.setdefault(n, label or "Reported scam")
                else:
                    block[n] = label or "Reported scam"
                used += 1
                continue
            # external community feed
            when = parse_date(row.get("reported_at"))
            if when and (TODAY - when).days > rules["max_age_days"]:
                skipped += 1
                continue
            score, reports = to_int(row.get("score")), to_int(row.get("reports"), 1)
            if reports < rules["min_reports"]:
                skipped += 1
                continue
            if score >= rules["block_score"]:
                block.setdefault(n, label or f"Scam ({name} {score}/9)")
            elif score >= rules["label_score"]:
                identify.setdefault(n, label or f"Likely scam ({name} {score}/9)")
            else:
                skipped += 1
                continue
            used += 1
        stats[name] = f"{used} used, {skipped} skipped"

    # Range detection: scammers step through neighbouring numbers (…968, …969).
    flagged = set(block) | set(identify)
    ranges = {}
    for n in flagged:
        ranges.setdefault(n // 100, set()).add(n)
    hot = sorted(r for r, members in ranges.items() if len(members) >= rules["range_threshold"])
    range_added = 0
    for r in hot:
        for n in range(r * 100, r * 100 + 100):
            if n in allow or n in block or n in identify:
                continue
            if rules["range_action"] == "block":
                block[n] = "Scam number range"
            else:
                identify[n] = "Possible scam (number range)"
            range_added += 1
    stats["range detection"] = f"{len(hot)} range(s), {range_added} numbers added"

    for n in block:                                  # a number lives in one list only
        identify.pop(n, None)

    out = {
        "version": dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "block": sorted(block),
        "identify": [[n, identify[n][:40]] for n in sorted(identify)],
    }

    total = len(out["block"]) + len(out["identify"])
    if total > rules["max_entries"]:
        raise SystemExit(f"Refusing to publish {total} entries (max_entries {rules['max_entries']}).")
    if previous:
        prev_total = len(previous.get("block", [])) + len(previous.get("identify", []))
        if prev_total >= 50 and total < prev_total * (1 - rules["max_shrink"]):
            raise SystemExit(
                f"List shrank from {prev_total} to {total} entries - looks like a feed failure. "
                "Not publishing. Re-run with --force if this is intended.")
    return out, stats


def diff(prev, new):
    def all_nums(d):
        return set(d.get("block", [])) | {n for n, _ in d.get("identify", [])}
    a, b = all_nums(prev or {}), all_nums(new)
    return len(b - a), len(a - b)


# ------------------------------------------------------------------ CLI

def load_cfg(path):
    with open(path) as f:
        return json.load(f)


def append_row(path, row, header):
    new = not os.path.exists(path)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "a", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=header)
        if new:
            w.writeheader()
        w.writerow(row)


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("command", nargs="?", default="build", choices=["build", "add", "allow", "check"])
    p.add_argument("number", nargs="?")
    p.add_argument("--config", default=os.path.join(HERE, "sources.json"))
    p.add_argument("--label", default="")
    p.add_argument("--label-only", action="store_true", help="add: label the call instead of blocking it")
    p.add_argument("--force", action="store_true", help="build: publish even if the list shrank a lot")
    args = p.parse_args()

    cfg = load_cfg(args.config)
    base = os.path.dirname(os.path.abspath(args.config))
    out_path = os.path.join(base, cfg["output"])

    if args.command in ("add", "allow", "check"):
        n = normalise(args.number)
        if not n:
            sys.exit(f"Not a usable number: {args.number!r}. Use a UK format like 07700 900123 or +44 ...")

    if args.command == "add":
        append_row(os.path.join(base, cfg["sources"][0]["path"]),
                   {"number": f"+{n}", "action": "label" if args.label_only else "block",
                    "label": args.label, "reported_at": TODAY.isoformat()},
                   ["number", "action", "label", "reported_at"])
        print(f"Added {pretty(n)} ({'label' if args.label_only else 'block'}). Run `build` to publish.")
        return 0

    if args.command == "allow":
        append_row(os.path.join(base, cfg["allowlist"]), {"number": f"+{n}", "note": args.label},
                   ["number", "note"])
        print(f"{pretty(n)} will never be blocked. Run `build` to publish.")
        return 0

    if args.command == "check":
        if not os.path.exists(out_path):
            sys.exit("No list built yet. Run `build` first.")
        cur = load_cfg(out_path)
        if n in set(cur["block"]):
            print(f"{pretty(n)}: BLOCKED")
        else:
            hit = next((lbl for m, lbl in cur["identify"] if m == n), None)
            print(f"{pretty(n)}: " + (f"LABELLED \"{hit}\"" if hit else "not on the list"))
        return 0

    previous = load_cfg(out_path) if os.path.exists(out_path) else None
    out, stats = build(cfg, base, None if args.force else previous)
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    body = json.dumps(out, separators=(",", ":"))
    with open(out_path, "w") as f:
        f.write(body)
    with open(out_path + ".sha256", "w") as f:
        f.write(hashlib.sha256(body.encode()).hexdigest() + "\n")

    added, removed = diff(previous, out)
    print("Sources:")
    for k, v in stats.items():
        print(f"  {k:<16} {v}")
    print(f"\nPublished {cfg['output']}: {len(out['block'])} blocked, {len(out['identify'])} labelled "
          f"(+{added} new, -{removed} removed since last build)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
