# Targets

<!-- last-evaluated: fd98e65 -->

## Active

(none)

## Achieved

### 🎯T1 Convergence evaluation is practical for daily use
- **Priority**: high
- **Acceptance**:
  - **Scan tier**: 1 tool call (gather script only). No codebase
    investigation. Output fits in a short summary paragraph.
  - **Default tier**: ≤15 tool calls for up to 15 active targets.
    Deep-evaluates only the top 2-3 by priority; rest are status +
    change hints. Total context consumed by the evaluation (gather
    output + investigation results) stays under ~8k tokens — less
    than 10% of a typical session window.
  - **Full tier**: Unbounded tool calls, explicitly opt-in. Expected
    only at milestone boundaries.
  - No tier blocks on external API calls unless the target's criteria
    explicitly require it (CI status uses cached gather data).
  - Empirical baseline: 8 targets, default tier, 3 tool calls
    (2026-03-04). Revisit if real-world usage consistently exceeds
    budgets.
- **Context**: The convergence system only works if it's cheap enough
  to run routinely. If `/cv` costs as much as a work session,
  people won't run it. The context-size constraint matters as much as
  tool-call count — a single grep returning 2k lines burns more
  budget than 10 targeted checks.
- **Status**: achieved
- **Achieved**: 2026-03-04
- **Discovered**: 2026-03-04

### 🎯T1.1 Default evaluation deeply investigates only top targets
- **Priority**: high
- **Acceptance**: `/cv` (default tier) fully evaluates only the
  top 2-3 targets by priority. Remaining targets are assessed from
  status fields and change-hint overlap. The skill definition
  explicitly specifies this tiered behaviour.
- **Context**: Evaluating every target on every run is O(n) in tool
  calls and context. Most runs only need to deeply assess the targets
  likely to be recommended — the rest just need a staleness check.
- **Parent**: 🎯T1
- **Status**: achieved
- **Achieved**: 2026-03-04
- **Discovered**: 2026-03-04

### 🎯T1.2 Gather script provides change hints
- **Priority**: high
- **Acceptance**: `gather.sh` emits a `changed-files` section listing
  files changed since the last evaluation SHA (stored in targets.md).
  `/cv` uses this to flag targets whose domain may be affected
  without running greps.
- **Context**: Level-triggered evaluation is correct but expensive. A
  hybrid approach that uses change sets as *hints* for where to focus
  captures most of the benefit at a fraction of the cost.
- **Parent**: 🎯T1
- **Status**: achieved
- **Achieved**: 2026-03-04
- **Discovered**: 2026-03-04

### 🎯T1.3 Re-evaluation happens at decision boundaries, not continuously
- **Priority**: high
- **Acceptance**: The `/cv` skill documentation and CLAUDE.md
  directive specify when to evaluate: session start, run completion,
  blockage. Mid-work re-evaluation is explicitly discouraged. The
  stash skill prompts for target status reflection (cheap) not full
  convergence evaluation (expensive).
- **Context**: Replanning has a cost (Ishida/Korf). The optimal
  strategy is to replan when the expected value of the new plan
  exceeds the replanning cost. For most small work increments, a
  status-field update suffices.
- **Parent**: 🎯T1
- **Status**: achieved
- **Achieved**: 2026-03-04
- **Discovered**: 2026-03-04

### 🎯T1.4 Acceptance criteria have evaluable cost classification
- **Priority**: medium
- **Acceptance**: The `/target` skill guidance recommends writing
  grep-checkable criteria where possible. The `/cv` skill
  documentation describes three cost categories (grep-checkable,
  ci-checkable, review-required) and how each is handled per tier.
- **Context**: Some criteria are a single grep; others require reading
  dozens of files for architectural judgement. Knowing the cost upfront
  lets `/cv` skip expensive evaluations in lighter tiers.
- **Parent**: 🎯T1
- **Status**: achieved
- **Achieved**: 2026-03-04
- **Discovered**: 2026-03-04

### 🎯T1.5 Implied target checks are amortized across targets
- **Priority**: medium
- **Acceptance**: Git state, PR list, and CI status are gathered once
  by `gather.sh` and matched to all targets by `/cv`, not
  queried per-target. The gather script has a single `git-state`
  section used for all implied delivery checks.
- **Context**: Checking delivery status per-target means N API calls
  for N targets. Gathering once and matching is O(1) in API calls.
- **Parent**: 🎯T1
- **Status**: achieved
- **Achieved**: 2026-03-04
- **Discovered**: 2026-03-04

### 🎯T1.6 Achieved targets don't accumulate unboundedly in context
- **Priority**: medium
- **Acceptance**: The `/target` skill documents an archival policy:
  achieved targets older than 30 days rotate to `## Archive` or a
  separate file. Gather script only emits `## Active` and
  `## Achieved` sections. The archival guideline is in the SKILL.md.
- **Context**: A project running for months could accumulate dozens of
  achieved targets. Each consumes context on every gather. Archival
  keeps context bounded while preserving history.
- **Parent**: 🎯T1
- **Status**: achieved
- **Achieved**: 2026-03-04
- **Discovered**: 2026-03-04

### 🎯T2 Convergence system has a comprehensive design report
- **Priority**: medium
- **Acceptance**: `docs/reports/desired-state-convergence.md` exists,
  covers theoretical foundations (≥7 domains), design principles,
  system mechanics, comparisons with alternatives, optimization
  analysis, and full bibliography.
- **Context**: The design rationale and literature review serves as
  the intellectual foundation for the system and helps future
  contributors understand why things are the way they are.
- **Status**: achieved
- **Achieved**: 2026-03-04
- **Discovered**: 2026-03-04
