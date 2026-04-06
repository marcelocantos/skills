#!/usr/bin/env python3
"""
Generate an SVG bar chart of daily active repository counts.

Reads lines of "DOW YYYY-MM-DD COUNT" on stdin (from gather.sh's
# daily_active_repos section) and produces an SVG bar chart.

Usage:
    gather.sh "2026-03-23" | sed -n '/^# daily_active_repos$/,/^# /p' | \\
        grep -E '^[A-Z][a-z]{2} ' | daily-chart.py -o daily-activity-2026-03-29.svg
"""

import argparse
import sys

import matplotlib
matplotlib.use("svg")
import matplotlib.pyplot as plt
import matplotlib.ticker as ticker


def main():
    parser = argparse.ArgumentParser(description="Daily active repos bar chart")
    parser.add_argument("-o", "--output", required=True, help="Output SVG path")
    args = parser.parse_args()

    labels = []
    counts = []
    for line in sys.stdin:
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split()
        if len(parts) < 3:
            continue
        dow, date_str, count = parts[0], parts[1], int(parts[2])
        # Label: "Mon 23"
        day_num = date_str.split("-")[2].lstrip("0")
        labels.append(f"{dow} {day_num}")
        counts.append(count)

    if not counts:
        print("No daily data to chart.", file=sys.stderr)
        sys.exit(1)

    fig, ax = plt.subplots(figsize=(7, 3))

    bars = ax.bar(range(len(counts)), counts, color="#2563eb", width=0.6)

    # Value labels on top of each bar.
    for bar, count in zip(bars, counts):
        if count > 0:
            ax.text(
                bar.get_x() + bar.get_width() / 2,
                bar.get_height() + 0.15,
                str(count),
                ha="center",
                va="bottom",
                fontsize=9,
                fontweight="bold",
            )

    ax.set_xticks(range(len(labels)))
    ax.set_xticklabels(labels, fontsize=8)
    ax.set_ylabel("Active repos", fontsize=9)
    ax.yaxis.set_major_locator(ticker.MaxNLocator(integer=True))
    ax.set_ylim(0, max(counts) * 1.25 if counts else 1)
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    ax.set_title("Daily Active Repositories", fontsize=11, fontweight="bold", pad=10)

    fig.tight_layout()
    fig.savefig(args.output, format="svg", transparent=True)
    plt.close(fig)
    print(f"Wrote {args.output}")


if __name__ == "__main__":
    main()
