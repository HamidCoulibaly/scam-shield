"""Run: python3 -m unittest discover -s tests   (from the collector folder)
All numbers are from Ofcom's ranges reserved for drama/testing (07700 900xxx, 020 7946 0xxx)."""
import csv
import datetime as dt
import json
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import collector as c  # noqa: E402

TODAY = dt.date.today().isoformat()
OLD = (dt.date.today() - dt.timedelta(days=400)).isoformat()


def write(path, header, rows):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(header)
        w.writerows(rows)


class Normalise(unittest.TestCase):
    def test_formats(self):
        for raw in ["07700 900123", "+44 7700 900123", "0044 7700 900123", "447700900123", "(07700) 900-123"]:
            self.assertEqual(c.normalise(raw), 447700900123, raw)
        self.assertEqual(c.normalise("020 7946 0001"), 442079460001)
        self.assertEqual(c.normalise("+33 1 23 45 67 89"), 33123456789)

    def test_rejects(self):
        for raw in ["999", "7726", "112", "", None, "12345", "0770090"]:
            self.assertIsNone(c.normalise(raw), raw)


class Build(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        write(f"{self.tmp}/data/my_reports.csv", ["number", "action", "label", "reported_at"], [
            ["07700 900101", "block", "Fake Amazon", TODAY],
            ["07700 900102", "label", "", TODAY],
            ["07700 900999", "block", "", TODAY],        # on allowlist -> must be dropped
        ])
        write(f"{self.tmp}/data/allowlist.csv", ["number", "note"], [["+447700900999", "friend"]])
        write(f"{self.tmp}/data/feed.csv", ["number", "score", "reports", "reported_at"], [
            ["020 7946 0001", "9", "12", TODAY],   # block
            ["020 7946 0002", "7", "5", TODAY],    # label
            ["020 7946 0003", "8", "1", TODAY],    # too few reports -> skip
            ["020 7946 0004", "9", "40", OLD],     # too old -> skip
            ["020 7946 0500", "5", "9", TODAY],    # score too low -> skip
        ])
        self.cfg = {
            "output": "dist/scamlist.json", "allowlist": "data/allowlist.csv",
            "sources": [
                {"name": "my reports", "type": "csv", "path": "data/my_reports.csv", "trust": "own"},
                {"name": "feed", "type": "csv", "path": "data/feed.csv"},
            ],
            "rules": {"block_score": 9, "label_score": 7, "min_reports": 3, "max_age_days": 180,
                      "range_threshold": 3, "range_action": "label", "max_entries": 2000000, "max_shrink": 0.5},
        }

    def test_rules(self):
        out, stats = c.build(self.cfg, self.tmp)
        self.assertEqual(out["block"], [442079460001, 447700900101])
        labelled = dict((n, l) for n, l in out["identify"])
        self.assertEqual(set(labelled), {442079460002, 447700900102})
        self.assertNotIn(447700900999, out["block"])
        self.assertEqual(stats["feed"], "2 used, 3 skipped")

    def test_sorted_unique(self):
        out, _ = c.build(self.cfg, self.tmp)
        ids = [n for n, _ in out["identify"]]
        self.assertEqual(out["block"], sorted(set(out["block"])))
        self.assertEqual(ids, sorted(set(ids)))
        self.assertFalse(set(ids) & set(out["block"]))

    def test_range_detection(self):
        write(f"{self.tmp}/data/my_reports.csv", ["number", "action", "label", "reported_at"],
              [[f"07700 9002{i:02d}", "block", "", TODAY] for i in (10, 11, 12)])
        out, stats = c.build(self.cfg, self.tmp)
        ids = {n for n, _ in out["identify"]}
        self.assertIn(447700900250, ids)                 # neighbour in the hot range is labelled
        self.assertEqual(stats["range detection"], "1 range(s), 97 numbers added")

    def test_shrink_guard(self):
        prev = {"block": list(range(447700900000, 447700900100)), "identify": []}
        with self.assertRaises(SystemExit):
            c.build(self.cfg, self.tmp, previous=prev)

    def test_bad_feed_does_not_break_build(self):
        self.cfg["sources"].append({"name": "broken", "type": "csv_url", "url": "$NOT_SET"})
        out, stats = c.build(self.cfg, self.tmp)
        self.assertTrue(stats["broken"].startswith("ERROR"))
        self.assertTrue(out["block"])


if __name__ == "__main__":
    unittest.main()
