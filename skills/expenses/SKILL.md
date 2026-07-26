---
name: expenses
description: >
  Find Gmail receipts/invoices for a date range, let the user select which are
  work-related, and forward only confirmed items to the CBA work email. Use when
  the user runs /expenses, asks for receipts, invoices, expense claims,
  "send to CBA email", or work-expense packaging from Gmail.
user-invocable: true
---

# Expenses — Gmail receipts → select → CBA claim

Pull real receipts from Gmail for a period, de-noise marketing, then **stop
for selection**. Not every receipt is work-related. Only forward items the
user has explicitly marked as claimable.

## Defaults (Marcelo)

| Setting | Value |
|---------|--------|
| Work / claim mailbox | `marcelo.cantos@cba.com.au` |
| Personal Gmail | the connected Gmail MCP account (`marcelo.cantos@gmail.com`) |
| Merchants | **Include all**, including Uber (do not exclude by default) |
| Work vs personal | **User decides** — never assume all receipts are claimable |
| Year when omitted | current calendar year from session date |
| Date range when omitted | ask, or last full calendar month if the user said "monthly" / EOFY-style |

Do **not** invent amounts. Only report figures present in message bodies,
snippets, or attachment filenames.

## Modes

Parse args after `/expenses`:

| Invocation | Behaviour |
|------------|-----------|
| `/expenses` | Ask for date range (or use last full month if user prefers speed) |
| `/expenses 20-30 jun` / `/expenses june` / `/expenses 2026-06-20..2026-06-30` | List receipts for that window, then selection step |
| `/expenses … send 1,3,5` / "claim 2 and the Icebergs one" | After a prior numbered list, confirm selection then forward |
| `/expenses … -uber` / "ignore Uber" | Exclude Uber for this run only (ad-hoc; not the default) |

Even when the user names a merchant up front ("send Icebergs to CBA"), still
show that row and get a yes before forwarding — one-line confirm is enough
when the set is a single unambiguous item.

## Step 1 — Resolve the window

Convert natural dates to Gmail absolute operators:

- Inclusive start → `after:YYYY/MM/DD` (Gmail `after` is exclusive of that day
  at midnight — use the **day before** the first day if results look short by
  one day; prefer `after:YYYY/MM/DD` where DD is start−1 day, or
  `after:startDate` as commonly used and verify boundary receipts).
- Exclusive end → `before:YYYY/MM/DD` where DD is **day after** last day.

Example for 20–30 Jun 2026:

```
after:2026/06/20 before:2026/07/01
```

## Step 2 — Search (Gmail MCP)

Discover tools with `search_tool` if schemas are unknown; primary tools:

- `gmail__search` — list candidates
- `gmail__get_message` — full body, amounts, attachments
- `gmail__forward_message` — send to CBA (irreversible send)

### Query A — subject-shaped receipts (primary)

```
subject:(receipt OR invoice OR "payment confirmation" OR "order confirmation" OR "tax invoice" OR "your order" OR "payment received" OR "order receipt")
after:YYYY/MM/DD before:YYYY/MM/DD
```

### Query B — attachments (catches PDF invoices)

```
has:attachment (receipt OR invoice OR payment OR statement)
after:YYYY/MM/DD before:YYYY/MM/DD
```

### Query C — broad net if A+B look thin

```
(receipt OR invoice OR "order confirmation" OR payment OR "your order" OR "tax invoice" OR "you've been charged" OR "amount paid")
after:YYYY/MM/DD before:YYYY/MM/DD
```

### Query D — Uber (always, unless user said ignore Uber)

Uber volume is high and subjects vary; run an explicit pass so trips are not
missed by subject filters:

```
from:uber.com (receipt OR invoice OR trip OR "thanks for riding")
after:YYYY/MM/DD before:YYYY/MM/DD
```

Only add `-from:uber.com -from:uber -subject:uber` to A–C when the user
explicitly asked to ignore Uber for this run.

Run A, B, and D (and C if needed). Deduplicate by `message_id` / thread.

### Noise to drop (not receipts)

- Marketing: Harvey Norman, Qantas Red Email / Frequent Flyer promos, Superloop
  "lock your price", Spotify trials, sale newsletters
- Pure reminders that are **not** new charges (e.g. Wilson "Prepaid Parking
  Reminder" when a Payment Confirmation already exists for the same ref)
- Security / product noise: GitHub PAT expiry, TestFlight, Dependabot
- Account statements that are not purchase receipts (e.g. IG share-trading
  statement) — list under **Related, not purchase receipts** if useful
- Bill **reminders** without payment (VicRoads rego due) — same bucket

### Keep (examples of real receipts)

- Explicit "Your receipt from …" / "Payment received for … invoice"
- Order invoices (restaurants, shops) with line items + total paid
- Subscription charges (Google Play, Anthropic, ngrok, …)
- Parking **Payment Confirmation** / tax invoices (Wilson, etc.)
- **Uber** trip receipts / invoices
- Anything with invoice/receipt PDF attachments from a merchant

**Keeping a receipt ≠ claiming it.** Personal SaaS, home parking, private
meals, and leisure Uber trips still appear in the list so the user can
decide.

## Step 3 — Enrich

For each keep candidate, `gmail__get_message` when amount or merchant is
unclear from the snippet. Prefer body_text; HTML-only messages may need
tag-stripping to find `$` / GST / Total lines.

Capture:

| Field | Notes |
|-------|--------|
| Date | Message date (local when useful) |
| Merchant | From / brand in body |
| What | Product, plan, location, booking window; for Uber: route if present |
| Amount | Total paid incl. tax when stated |
| Currency | A$ vs $ — don't assume; show as written |
| Refs | Receipt #, invoice #, order #, booking ref, trip id |
| Profile / card | Capture when present (see signals below) |
| Attachments | PDF names if present |

If body is empty (some Google Play mails), still list with order number and
note amount missing. Uber often returns empty body_text via MCP — use
**subject + snippet** (and PDF attachments if present).

### Work vs personal signals (what mail actually has)

**Not all merchants expose a work/personal flag.** Treat signals as hints for
pre-selection defaults, never as silent auto-claim.

| Source | What you get | Strength |
|--------|----------------|----------|
| **Uber subject** | `[Business] Your … trip with Uber` when the trip was on the **Uber Business / work profile**. Personal trips omit the prefix (`Your Friday evening trip with Uber`). | **Strong** for profile (business vs personal Uber) |
| **Uber body** | Fare, route, tolls, total. Card last-4 / "Work" may appear in full HTML or attached PDF; often **missing** from snippet/body_text via MCP. | Medium if present; don't require it |
| **Stripe-style** (Anthropic, many SaaS) | `Payment method - ····2819` (last 4 only). No work/personal label. | Identifies **which card**, not purpose — useful only if the user has told you which last-4 is work |
| **Cover claim you already sent** | e.g. "all Mastercard ••••1011 Work" | Ground truth for that batch; can seed last-4→work mapping for the session |
| **Most retail / dining / parking** | Merchant + amount; rarely last-4 or profile | **No** card/profile signal — user must select |

**Uber rule of thumb for this account:**

- Subject contains `[Business]` → pre-mark as **likely work** (business profile)
- Subject has no `[Business]` → pre-mark as **likely personal**
- Still run Step 5; user can override either way

If the user states a work card last-4 (e.g. `1011` or `2819`), show matching
last-4 rows as **likely work** and others as **unknown/personal-leaning** —
still confirm before send.

## Step 4 — Present (numbered inventory)

Show **all** real receipts with stable **# indices** the user can select.
Do not pre-filter to "work only."

```
| # | Date | Merchant | What | Amount | Card/profile | Hint |
```

- **Card/profile**: last-4, `[Business]`, or "—" if unknown
- **Hint**: `work?` / `personal?` / `—` from signals above only

Buckets:

1. **Receipts** — every purchase/invoice in the window (include Uber)
2. **Related, not purchase receipts** — statements, reminders (no # for send)

Totals:

- **All found** — sum of known amounts in the receipts table
- **Suggested work** (optional) — sum of rows with strong work signals only
- Do **not** treat suggested work as the claim set until Step 5

Optional soft hints when card/profile is absent:

| Hint | Examples (suggestive, not rules) |
|------|----------------------------------|
| Often personal | Consumer media, home shopping, family-looking spend |
| Often work | Airport/office parking on workdays, client meals if context fits, tooling used for work |

Wrong guesses are fine; silent exclusion is not. Never hide a row because
the hint says personal.

If many Uber rows, use a sub-table still numbered in the same sequence
(e.g. 4–11) so selection stays consistent.

End Step 4 with a clear prompt — do **not** forward yet:

```
Which are work/claimable? Reply with numbers (e.g. 1,3,5-7), merchant
names, "all", or "none". Personal items stay listed but won't be sent.
```

## Step 5 — Confirm selection (mandatory gate)

**No forward until the user selects.** This is the hard gate.

Accept selection forms:

- Indices: `1, 3, 5-7`
- Names: `Icebergs`, `Wilson 30 Jun`, `all Uber to airport`
- Profile shortcuts: `all [Business] Uber`, `all work-hinted`, `suggested work`
- Sets: `all`, `none`, `all except 2 and 4`
- Mixed: `2, Icebergs, ngrok`

You may **pre-check** rows with strong signals (`[Business]` Uber, known work
last-4) in the restatement as a proposed default, but still require yes.

Then **restate the selection** before sending:

```
Claim set (N items, $X.XX known):
- #1 … 
- #3 …
Forward these to marcelo.cantos@cba.com.au? [yes / edit / cancel]
```

Rules:

- Proceed only on clear affirmative (`yes`, `send`, `go`, `confirm`)
- On `edit`, adjust the set and restate again
- On `cancel` / `none`, stop with no mail sent
- If selection is ambiguous, ask — do not guess
- "Send everything" / `all` still gets the restatement + yes gate
- A prior session's selection does not apply to a new list; re-confirm

Hold `message_id`s for selected rows only; never forward unselected rows.

## Step 6 — Forward to CBA

Only after Step 5 confirmation.

```
gmail__forward_message(
  message_id: "<id of a selected row>",
  to: ["marcelo.cantos@cba.com.au"],
  additional_message: "<one-line claim summary>"
)
```

**additional_message** style (match prior claims):

```
Icebergs Bar and Kitchen (SYD T3) — 25 Jun 2026 — $38.91 — order #20260625_0092 for expense claim.
```

```
Merchant (context) — <date> — <amount> — <ref> for expense claim.
```

For a batch of similar items (especially Uber), prefer **one cover email** to
CBA with a bullet summary of each **selected** trip/line plus forwarded
originals — do not spam one forward per trip unless asked. Style reference:
"Uber business receipts — June 2026 ($…)" with per-trip bullets (date, route,
amount, card). Cover total = selected items only.

Confirm after send: destination, count, each merchant/amount, original subjects.

**Irreversible:** forward/send goes immediately. Destination must be the CBA
address above unless the user names another.

## Worked example (session learning)

Window: 20–30 Jun 2026. Receipts found included Anthropic, Icebergs, Wilson
parking ×3, ngrok, Google Play (and Uber when not excluded). Not all of those
are necessarily work — e.g. personal SaaS vs work tooling is the user's call.

Correct flow: number the list → user picks claimable rows → restate → yes →
forward only those. One run forwarded Icebergs after explicit request.

## Failure modes

| Symptom | Fix |
|---------|-----|
| Gmail MCP missing / auth fail | Report; user re-auth the Gmail connector |
| Zero results | Widen Query C; check year; try `has:attachment` only |
| Missing Uber trips | Ensure Query D ran; widen Uber subject keywords |
| HTML-only amount | Strip tags; look for Tax Invoice / Total / GST blocks |
| Ambiguous selection | Re-list with #s; ask which indices |
| Forwarded without confirm | Treat as a bug in process — never skip Step 5 |
| Wrong year | Session "today" is source of truth for default year |

## Do not

- Treat "found receipt" as "work expense"
- Treat last-4 alone as work without a known mapping from the user
- Auto-send all `[Business]` Uber without Step 5 yes (pre-select is fine)
- Forward anything without Step 5 selection + affirmative confirm
- Pre-drop rows because they "look personal" (hint only; user selects)
- Exclude Uber unless the user asked for this run
- Treat marketing or PAT/TestFlight mail as receipts
- Fabricate totals for empty bodies
- Report a claim total that includes unselected personal items
- Commit or store receipt PDFs in a git repo unless the user asks
