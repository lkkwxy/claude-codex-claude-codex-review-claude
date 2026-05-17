#!/usr/bin/env bash
set -u
set -o pipefail

REPO_RAW_BASE="${CODEX_REVIEW_REPO_RAW_BASE:-https://raw.githubusercontent.com/lkkwxy/claude-codex-claude-codex-review-claude/main}"
TARGET_DIR="${CODEX_REVIEW_TARGET_DIR:-$(pwd)}"
FORCE=0

usage() {
  cat <<'USAGE'
Usage: install.sh [options]

Installs the Claude Code /codex-review command into the current project.

Options:
  --target-dir <dir>  Install into a specific project directory. Default: current directory.
  --force             Overwrite existing codex-review files.
  -h, --help          Show this help.

Environment:
  CODEX_REVIEW_REPO_RAW_BASE  Override raw GitHub base URL for templates.
  CODEX_REVIEW_TARGET_DIR     Override install target directory.
USAGE
}

log() {
  printf "[codex-review install] %s\n" "$1"
}

fail() {
  printf "[codex-review install] ERROR: %s\n" "$1" >&2
  exit 1
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --target-dir)
      [ "$#" -ge 2 ] || fail "--target-dir requires a value."
      TARGET_DIR="$2"
      shift 2
      ;;
    --target-dir=*)
      TARGET_DIR="${1#*=}"
      shift
      ;;
    --force)
      FORCE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "unknown option: $1"
      ;;
  esac
done

need_command() {
  command -v "$1" >/dev/null 2>&1 || fail "$1 is required but was not found on PATH."
}

download() {
  local source_path="$1"
  local dest_path="$2"

  if [ -f "$dest_path" ] && [ "$FORCE" -ne 1 ]; then
    log "Keeping existing $dest_path"
    return
  fi

  mkdir -p "$(dirname "$dest_path")"
  curl -fsSL "${REPO_RAW_BASE}/${source_path}" -o "$dest_path"
}

append_gitignore_once() {
  local gitignore_path="$1"
  local entry=".ai-review/"

  touch "$gitignore_path"
  if grep -Fxq "$entry" "$gitignore_path"; then
    log "Keeping existing .gitignore entry: $entry"
  else
    printf "\n%s\n" "$entry" >> "$gitignore_path"
    log "Added .gitignore entry: $entry"
  fi
}

need_command curl

mkdir -p "$TARGET_DIR"
cd "$TARGET_DIR" || fail "cannot enter target directory: $TARGET_DIR"

download ".claude/commands/codex-review.md" ".claude/commands/codex-review.md"
download "scripts/codex-review.sh" "scripts/codex-review.sh"
download ".codex-review.yml" ".codex-review.yml"
chmod +x "scripts/codex-review.sh"
append_gitignore_once ".gitignore"

log "Installed /codex-review into $TARGET_DIR"
log "Usage in Claude Code: /codex-review"
log "Optional: /codex-review --mode severity --auto-fix-severities P0,P1"
