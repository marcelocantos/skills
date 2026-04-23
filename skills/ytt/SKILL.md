---
name: ytt
description: Fetch a YouTube video's transcript and present a detailed synopsis with key takeaways.
user-invocable: true
---

# ytt

Fetch a YouTube video's transcript via the `ytt` CLI and present a
detailed synopsis and key takeaways.

## Arguments

- `/ytt <url_or_video_id>` — required. A YouTube URL or bare video ID.

If no argument is given, ask the user for the URL and stop.

## Steps

### 1. Fetch the transcript

Run `ytt '<url_or_video_id>'` via Bash.

- **Always single-quote the URL.** zsh treats `?` as a glob and errors
  with `no matches found` on unquoted YouTube URLs (e.g. the `?v=...`
  query string).
- Do **not** use `WebFetch` on YouTube URLs — it only returns YouTube's
  footer chrome, not the transcript.

If `ytt` fails (no transcript available, video private, network error),
report the error and stop. Do not fabricate a synopsis.

### 2. Read and analyse

Read the transcript output end-to-end. Identify:

- The video's core topic and thesis.
- The narrative arc — how the argument or content progresses.
- Concrete claims, examples, data points, and recommendations.
- Any caveats, counterpoints, or nuances the speaker raises.

### 3. Present the synopsis

Structure the response as:

**Synopsis** — a detailed multi-paragraph summary covering the full
content of the video in logical order. Aim for depth over brevity;
the user wants to understand the video without watching it. Preserve
the speaker's framing and terminology where it matters.

**Key takeaways** — a bulleted list of the most important, actionable,
or surprising points. Each bullet should stand alone as a distinct
insight, not a mechanical restatement of the synopsis.

If the video has clear sections or chapters, you may break the synopsis
into labelled subsections. Otherwise keep it flowing.

## Notes

- Length scales with the video. A 10-minute talk may need ~300 words;
  a 90-minute lecture may warrant ~1000+. Don't pad, but don't truncate
  substance to fit an arbitrary budget.
- Quote memorable lines sparingly — only when the exact phrasing
  carries weight the paraphrase loses.
