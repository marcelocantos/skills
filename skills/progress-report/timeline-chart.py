#!/usr/bin/env python3
"""
Generate an SVG timeline chart of daily active repository counts across
the entire progress-report history.

Scans all repos under ~/work/ for commits since a given start date,
counts unique active repos per day, and produces an SVG area/bar chart.

Usage:
    timeline-chart.py --since 2026-01-19 -o timeline.svg
"""

import argparse
import os
import subprocess
import sys
from collections import defaultdict
from datetime import date, datetime, timedelta
from pathlib import Path

import yaml

import matplotlib
matplotlib.use("svg")
import matplotlib.pyplot as plt
import matplotlib.dates as mdates
import matplotlib.ticker as ticker


def find_repos(work_root: Path) -> list[Path]:
    """Find all git repos under work_root, excluding vendored dirs."""
    repos = []
    skip = {"vendor", "node_modules", ".build", "build"}
    for dirpath, dirnames, filenames in os.walk(work_root):
        dirnames[:] = [d for d in dirnames if d not in skip]
        if ".git" in dirnames:
            repos.append(Path(dirpath))
            dirnames.remove(".git")
    repos.sort()
    return repos


def get_commit_dates(repo: Path, since: str, author: str | None) -> set[date]:
    """Get the set of dates on which commits occurred in a repo."""
    cmd = [
        "git", "-C", str(repo), "log",
        "--format=%aI",  # author date in ISO 8601
        f"--since={since}",
        "--all",
    ]
    if author:
        cmd.append(f"--author={author}")

    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        return set()

    dates = set()
    for line in result.stdout.strip().splitlines():
        if line:
            # Parse ISO date, take just the date part.
            try:
                dates.add(datetime.fromisoformat(line).date())
            except ValueError:
                pass
    return dates


def main():
    parser = argparse.ArgumentParser(
        description="Timeline chart of daily active repos"
    )
    parser.add_argument(
        "--since", required=True,
        help="Start date (YYYY-MM-DD)"
    )
    parser.add_argument(
        "--until",
        help="End date inclusive (YYYY-MM-DD, default: today)"
    )
    parser.add_argument(
        "-o", "--output", required=True,
        help="Output SVG path"
    )
    parser.add_argument(
        "--weekly-dir",
        help="Also emit per-week SVGs (daily-activity-<date>.svg) into this directory"
    )
    parser.add_argument(
        "--cache",
        help="YAML cache file for daily repo counts (read/write)"
    )
    parser.add_argument(
        "--work-root",
        default=os.path.expanduser("~/work"),
        help="Root directory to scan for repos (default: ~/work)"
    )
    args = parser.parse_args()

    since_date = date.fromisoformat(args.since)
    until_date = date.fromisoformat(args.until) if args.until else date.today()
    work_root = Path(args.work_root)

    # Load cache if available.
    cached: dict[date, int] = {}
    cache_cutoff = date.min  # scan everything by default
    if args.cache and os.path.exists(args.cache):
        with open(args.cache) as f:
            raw = yaml.safe_load(f) or {}
        for d_str, count in (raw.get("dates") or {}).items():
            d = date.fromisoformat(str(d_str))
            cached[d] = count
        if cached:
            cache_cutoff = max(cached) + timedelta(days=1)
            print(f"Cache hit: {len(cached)} days through "
                  f"{max(cached)}, scanning from {cache_cutoff}...",
                  file=sys.stderr)

    # Determine the scan window: from cache_cutoff (or since) to until.
    scan_since = max(since_date, cache_cutoff)

    daily_repos: dict[date, int] = defaultdict(int)

    if scan_since <= until_date:
        author = subprocess.run(
            ["git", "config", "--global", "user.name"],
            capture_output=True, text=True
        ).stdout.strip() or None

        repos = find_repos(work_root)
        print(f"Scanning {len(repos)} repos from {scan_since}...",
              file=sys.stderr)

        for repo in repos:
            dates = get_commit_dates(repo, str(scan_since), author)
            for d in dates:
                if scan_since <= d <= until_date:
                    daily_repos[d] += 1
    else:
        print("Cache covers entire range, no scan needed.", file=sys.stderr)

    # Merge cached + freshly scanned data.
    merged: dict[date, int] = {}
    d = since_date
    while d <= until_date:
        if d in daily_repos:
            merged[d] = daily_repos[d]
        elif d in cached:
            merged[d] = cached[d]
        else:
            merged[d] = 0
        d += timedelta(days=1)

    # Write cache. Only cache dates 2+ days old to avoid timezone edge cases.
    if args.cache:
        cache_horizon = date.today() - timedelta(days=2)
        cache_data = {
            "since": since_date.isoformat(),
            "dates": {
                d.isoformat(): c
                for d, c in sorted(merged.items())
                if d <= cache_horizon
            },
        }
        with open(args.cache, "w") as f:
            yaml.dump(cache_data, f, default_flow_style=False, sort_keys=False)
        print(f"Cache written: {len(cache_data['dates'])} days "
              f"(through {cache_horizon})", file=sys.stderr)

    # Build full date range.
    all_dates = sorted(merged.keys())
    all_counts = [merged[d] for d in all_dates]

    if not all_dates:
        print("No data to chart.", file=sys.stderr)
        sys.exit(1)

    # Week boundaries for vertical lines (Mondays).
    mondays = [d for d in all_dates if d.weekday() == 0]

    fig, ax = plt.subplots(figsize=(12, 3.5))

    # Bar chart with thin bars for daily granularity.
    colours = ["#93c5fd" if c > 0 else "#e5e7eb" for c in all_counts]
    ax.bar(all_dates, all_counts, width=0.8, color=colours, edgecolor="none")

    # 7-day exponential moving average.
    if len(all_counts) >= 2:
        alpha = 2 / (7 + 1)  # EMA equivalent to 7-day SMA
        ema = [float(all_counts[0])]
        for c in all_counts[1:]:
            ema.append(alpha * c + (1 - alpha) * ema[-1])
        ax.plot(all_dates, ema, color="#2563eb", linewidth=1.5,
                label="7-day EMA", zorder=3)
        ax.legend(loc="upper left", fontsize=8, framealpha=0.8)

    # Week boundary lines.
    for monday in mondays:
        ax.axvline(monday, color="#d1d5db", linewidth=0.5, zorder=1)

    ax.set_ylabel("Active repos", fontsize=9)
    ax.yaxis.set_major_locator(ticker.MaxNLocator(integer=True))
    ax.set_ylim(0, max(all_counts) * 1.2 if all_counts else 1)
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)

    # X-axis: month labels.
    ax.xaxis.set_major_locator(mdates.MonthLocator())
    ax.xaxis.set_major_formatter(mdates.DateFormatter("%b"))
    ax.xaxis.set_minor_locator(mdates.WeekdayLocator(byweekday=mdates.MO))
    ax.tick_params(axis="x", which="major", labelsize=9)
    ax.tick_params(axis="x", which="minor", length=3, labelsize=0)

    ax.set_xlim(all_dates[0] - timedelta(days=1),
                all_dates[-1] + timedelta(days=1))

    ax.set_title("Daily Active Repositories", fontsize=11,
                 fontweight="bold", pad=10)

    fig.tight_layout()
    fig.savefig(args.output, format="svg", transparent=True)
    plt.close(fig)
    print(f"Wrote {args.output}", file=sys.stderr)

    # Per-week charts.
    if args.weekly_dir:
        _generate_weekly_charts(args.weekly_dir, all_dates, all_counts)


def _generate_weekly_charts(
    output_dir: str,
    all_dates: list[date],
    all_counts: list[int],
) -> None:
    """Slice daily data into Mon-Sun weeks and emit per-week bar charts."""
    # Build a date->count lookup.
    by_date = dict(zip(all_dates, all_counts))

    # Find all Mondays in the range.
    mondays = [d for d in all_dates if d.weekday() == 0]

    for monday in mondays:
        sunday = monday + timedelta(days=6)
        week_dates = []
        week_counts = []
        d = monday
        while d <= sunday:
            week_dates.append(d)
            week_counts.append(by_date.get(d, 0))
            d += timedelta(days=1)

        if not any(c > 0 for c in week_counts):
            continue

        labels = [f"{d.strftime('%a')} {d.day}" for d in week_dates]

        fig, ax = plt.subplots(figsize=(7, 3))
        bars = ax.bar(range(len(week_counts)), week_counts,
                      color="#2563eb", width=0.6)

        for bar, count in zip(bars, week_counts):
            if count > 0:
                ax.text(
                    bar.get_x() + bar.get_width() / 2,
                    bar.get_height() + 0.15,
                    str(count),
                    ha="center", va="bottom",
                    fontsize=9, fontweight="bold",
                )

        ax.set_xticks(range(len(labels)))
        ax.set_xticklabels(labels, fontsize=8)
        ax.set_ylabel("Active repos", fontsize=9)
        ax.yaxis.set_major_locator(ticker.MaxNLocator(integer=True))
        ax.set_ylim(0, max(week_counts) * 1.25 if week_counts else 1)
        ax.spines["top"].set_visible(False)
        ax.spines["right"].set_visible(False)
        ax.set_title("Daily Active Repositories", fontsize=11,
                     fontweight="bold", pad=10)

        fig.tight_layout()
        svg_path = os.path.join(output_dir,
                                f"daily-activity-{sunday.isoformat()}.svg")
        fig.savefig(svg_path, format="svg", transparent=True)
        plt.close(fig)
        print(f"Wrote {svg_path}", file=sys.stderr)


if __name__ == "__main__":
    main()
