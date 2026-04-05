---
name: audit
description: Comprehensive codebase audit — code quality, security, testing, performance, legal, CI/CD, documentation, and agent-friendliness.
user-invocable: true
---

**DELEGATE VIA AGENT.** Spawn an Agent (subagent_type: general-purpose,
model: opus) with the prompt `"Read and execute
~/.claude/skills/audit/worker.md. Return the full audit report."`.
Relay the agent's result to the user.

After presenting the report, offer to address findings by priority.
The worker handles all audit phases including team spawning, review
gate, and report assembly. The root session handles user interaction
(which findings to fix, commits, etc.).

## Skill improvement

After each audit, reflect on whether any reusable insights were gained — new categories of issues worth checking, better patterns for specific languages or project types, checks that would have caught problems earlier. Pay special attention to unexpected failures in companion scripts (e.g., `gather.sh`) or tool invocations encountered during the run — these may indicate bugs to fix in the skill or its scripts, not just one-off issues. If any improvements are identified, propose the specific changes to the skill files to the user. Only integrate them with user consent.
