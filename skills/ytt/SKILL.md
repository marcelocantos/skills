---
name: ytt
description: Fetch a YouTube video's transcript and ingest it into ~/think/knowledge/youtube/ as a synopsis with key takeaways. Updates the knowledge-base index and commits.
user-invocable: true
---

# ytt

Fetch a YouTube video's transcript via the `ytt` CLI, write a detailed
synopsis to `~/think/knowledge/youtube/<id>/`, regenerate the
knowledge-base index, and commit. The user may suppress ingest with a
natural-language qualifier (e.g. "but don't ingest", "just summarise",
"in chat only") — in which case present the synopsis inline and stop.

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

### 3. Compose the synopsis

The output format (structure, TL;DR line, slug rules, and the machine
contract `ytt build-index` parses) is defined in one place — read it and
follow it verbatim:

```
~/work/github.com/marcelocantos/ytt/scripts/playlist-ingest/synopsis-contract.md
```

This is the same contract the scheduled `ingest` path feeds to its
synopsis agent, so the interactive and automated paths stay identical.
In chat-only mode, skip the `# <title>` and `Source:` lines and present
the Synopsis, Critique (when warranted), and Key Takeaways inline;
otherwise honour the contract as written.

### 4. Ingest (default)

Skip this step if the user qualified the command to suppress ingest.

1. **Check for existing ingest.** If `~/think/knowledge/youtube/<id>/`
   already exists, stop and tell the user — offer to refresh
   (overwrite synopsis + meta.json) or skip. Do not silently
   double-ingest.
2. **Fetch metadata** with yt-dlp:
   ```bash
   yt-dlp --skip-download \
     --print '%(.{id,title,uploader,channel,channel_id,upload_date,duration,view_count,description,webpage_url,tags})j' \
     '<url>'
   ```
   Pretty-print the JSON object into `meta.json` (preserve all fields,
   2-space indent, keep unicode characters readable — e.g. `t3․gg`).
3. **Write the synopsis** to
   `~/think/knowledge/youtube/<id>/<topic-slug>.md`. The slug is a
   short kebab-case description of the video's topic (e.g.
   `bash-is-not-enough.md`, `agent-memory-retrieval-shapes.md`), not
   the video title. One synopsis file per directory.
4. **Register the ID** in the scheduler's dedup record:
   ```bash
   echo '<id>' >> ~/think/knowledge/youtube/.processed
   ```
   Not optional: `.processed` is the authoritative record of successful
   ingest. The scheduled nightly run wipes any video directory whose ID
   is missing from it (orphan healing for crashed runs) — an
   unregistered manual ingest gets deleted and re-ingested with a
   machine synopsis. Stage `.processed` with the ingest commit.
5. **Regenerate the index:**
   ```bash
   ytt build-index
   ```
   This rewrites `~/think/knowledge/youtube/youtube-knowledge-base.md`
   from all `meta.json` + synopsis pairs, sorted newest-first.
6. **Commit** from `~/think/`:
   - First commit: `Ingest <channel>'s "<short-title>" video on <topic>`
     — stage `knowledge/youtube/<id>/`.
   - Second commit: `Regenerate youtube knowledge-base index` — stage
     `knowledge/youtube/youtube-knowledge-base.md`.

### 5. Present a brief summary in chat

After ingest, give the user a one-line confirmation plus a 2–3 sentence
recap of the video's thesis. Do not paste the full synopsis back into
chat — they can read the file.

In chat-only mode, present the full synopsis and key takeaways in the
response.

## Notes

- Length scales with the video. A 10-minute talk may need ~300 words;
  a 90-minute lecture may warrant ~1000+. Don't pad, but don't truncate
  substance to fit an arbitrary budget.
- Quote memorable lines sparingly — only when the exact phrasing
  carries weight the paraphrase loses.
- The directory name is always the 11-character YouTube video ID.
  The `.md` filename is a topic slug, not the title.
- Output structure, the TL;DR line format, and slug rules live in
  `synopsis-contract.md` (see step 3) — the single source of truth
  shared with the scheduled `ingest` path and the `ytt build-index`
  parser. Don't restate them here.
