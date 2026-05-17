---
allowed-tools: Bash(scripts/codex-review.sh:*), Bash(cat:*), Bash(test:*), Bash(git status:*), Bash(git diff:*)
description: Run Codex CLI review on current uncommitted changes, then ask which findings to fix
argument-hint: [optional review instructions]
---

# Codex Review

Run the project Codex review script first:

!`scripts/codex-review.sh "$ARGUMENTS"`

Then read `.ai-review/codex-review.md`, `.ai-review/effective-config.env`, and `.codex-review.yml` if they exist.

Your job:

1. Summarize whether Codex reported actionable findings.
2. If there are no actionable findings, say that clearly and stop.
3. If there are actionable findings, list them by severity and include file/line references when Codex provided them.
4. Ask the user which findings to fix before editing anything.
5. If the user chooses findings to fix, only fix those selected findings.
6. Do not perform unrelated refactors.
7. Do not create a commit.
8. After fixing selected findings, offer to run `/codex-review` again for confirmation.

Default behavior is manual approval. Treat `.ai-review/effective-config.env` as the effective runtime configuration. It is produced by `scripts/codex-review.sh` after applying this precedence:

1. `/codex-review` command arguments
2. `.codex-review.yml`
3. built-in defaults

Configuration meanings:

- `mode: ask` means always ask before fixing.
- `mode: auto` means the user has opted into automatic fixes, but still limit fixes to actionable Codex findings.
- `mode: severity` means only findings matching `auto_fix_severities` may be fixed automatically; ask before fixing all others.
- `max_fix_rounds` limits automatic review/fix loops.

Supported command arguments:

```text
--mode ask|auto|severity
--review-scope uncommitted
--max-fix-rounds 1
--auto-fix-severities P0,P1
```

Additional follow-up instructions passed by the user. The local Codex CLI may not accept custom prompts together with `--uncommitted`, so apply these instructions when summarizing findings and deciding how to repair selected issues:

```text
$ARGUMENTS
```
