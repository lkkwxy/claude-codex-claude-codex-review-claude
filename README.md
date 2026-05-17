# claude-codex-code-review

Install a Claude Code `/codex-review` command into a project. The command runs
Codex CLI review on current uncommitted changes, writes the review to
`.ai-review/codex-review.md`, and lets Claude ask which findings to fix.

## Install with curl

Use the raw GitHub URL:

```bash
curl -fsSL https://raw.githubusercontent.com/lkkwxy/claude-codex-claude-codex-review-claude/main/scripts/install.sh | bash
```

The `github.com/.../blob/main/...` URL renders HTML and will not work with
`curl | bash`.

## Install with npx

After publishing this package to npm:

```bash
npx claude-codex-code-review install
```

Then open Claude Code in the project and run:

```text
/codex-review
```

## Configuration

Command-line arguments override `.codex-review.yml`. Missing values fall back to
the config file, then these defaults:

```yaml
mode: ask
review_scope: uncommitted
max_fix_rounds: 1
auto_fix_severities: []
```

Example:

```text
/codex-review --mode severity --auto-fix-severities P0,P1
```
