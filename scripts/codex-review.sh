#!/usr/bin/env bash
set -u
set -o pipefail

OUTPUT_DIR=".ai-review"
REVIEW_FILE="${OUTPUT_DIR}/codex-review.md"
LOG_FILE="${OUTPUT_DIR}/codex-review.log"
EFFECTIVE_CONFIG_FILE="${OUTPUT_DIR}/effective-config.env"
CONFIG_FILE=".codex-review.yml"
DEFAULT_MODE="ask"
DEFAULT_REVIEW_SCOPE="uncommitted"
DEFAULT_MAX_FIX_ROUNDS="1"
DEFAULT_AUTO_FIX_SEVERITIES="[]"
MODE_ARG=""
REVIEW_SCOPE_ARG=""
MAX_FIX_ROUNDS_ARG=""
AUTO_FIX_SEVERITIES_ARG=""
EXTRA_INSTRUCTIONS=()

timestamp() {
  date "+%Y-%m-%d %H:%M:%S %z"
}

usage() {
  cat <<'USAGE'
Usage: scripts/codex-review.sh [options] [follow-up instructions]

Runs Codex CLI review and writes the result to .ai-review/codex-review.md.
Command-line options override .codex-review.yml. Missing options fall back to
.codex-review.yml, then built-in defaults.

Options:
  --mode <ask|auto|severity>
      Fix policy Claude should apply after reading the review. Default: ask.

  --review-scope <uncommitted>
      Review scope for Codex. Default: uncommitted.

  --max-fix-rounds <number>
      Maximum automatic fix rounds Claude should run. Default: 1.

  --auto-fix-severities <list>
      Comma-separated severities for mode=severity, for example: P0,P1.
      Default: empty.

  -h, --help
      Show this help.
USAGE
}

fail() {
  local message="$1"
  mkdir -p "$OUTPUT_DIR"
  {
    printf "[%s] ERROR: %s\n" "$(timestamp)" "$message"
  } | tee -a "$LOG_FILE" >&2
  exit 1
}

read_config_value() {
  local key="$1"
  local default_value="$2"

  if [ ! -f "$CONFIG_FILE" ]; then
    printf "%s" "$default_value"
    return
  fi

  local value
  value="$(awk -F ':' -v key="$key" '
    $1 == key {
      sub(/^[[:space:]]+/, "", $2)
      sub(/[[:space:]]+$/, "", $2)
      gsub(/^["'\'']|["'\'']$/, "", $2)
      print $2
      exit
    }
  ' "$CONFIG_FILE")"

  if [ -n "$value" ]; then
    printf "%s" "$value"
  else
    printf "%s" "$default_value"
  fi
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --mode)
      [ "$#" -ge 2 ] || fail "--mode requires a value."
      MODE_ARG="$2"
      shift 2
      ;;
    --mode=*)
      MODE_ARG="${1#*=}"
      shift
      ;;
    --review-scope)
      [ "$#" -ge 2 ] || fail "--review-scope requires a value."
      REVIEW_SCOPE_ARG="$2"
      shift 2
      ;;
    --review-scope=*)
      REVIEW_SCOPE_ARG="${1#*=}"
      shift
      ;;
    --max-fix-rounds)
      [ "$#" -ge 2 ] || fail "--max-fix-rounds requires a value."
      MAX_FIX_ROUNDS_ARG="$2"
      shift 2
      ;;
    --max-fix-rounds=*)
      MAX_FIX_ROUNDS_ARG="${1#*=}"
      shift
      ;;
    --auto-fix-severities)
      [ "$#" -ge 2 ] || fail "--auto-fix-severities requires a value."
      AUTO_FIX_SEVERITIES_ARG="$2"
      shift 2
      ;;
    --auto-fix-severities=*)
      AUTO_FIX_SEVERITIES_ARG="${1#*=}"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      while [ "$#" -gt 0 ]; do
        EXTRA_INSTRUCTIONS+=("$1")
        shift
      done
      ;;
    -*)
      fail "unknown option: $1"
      ;;
    *)
      EXTRA_INSTRUCTIONS+=("$1")
      shift
      ;;
  esac
done

if ! command -v git >/dev/null 2>&1; then
  fail "git is not available on PATH."
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  fail "current directory is not inside a git repository."
fi

if ! command -v codex >/dev/null 2>&1; then
  fail "codex CLI is not available on PATH."
fi

MODE="${MODE_ARG:-$(read_config_value "mode" "$DEFAULT_MODE")}"
REVIEW_SCOPE="${REVIEW_SCOPE_ARG:-$(read_config_value "review_scope" "$DEFAULT_REVIEW_SCOPE")}"
MAX_FIX_ROUNDS="${MAX_FIX_ROUNDS_ARG:-$(read_config_value "max_fix_rounds" "$DEFAULT_MAX_FIX_ROUNDS")}"
AUTO_FIX_SEVERITIES="${AUTO_FIX_SEVERITIES_ARG:-$(read_config_value "auto_fix_severities" "$DEFAULT_AUTO_FIX_SEVERITIES")}"
EXTRA_INSTRUCTIONS_TEXT="${EXTRA_INSTRUCTIONS[*]:-}"

case "$MODE" in
  ask|auto|severity) ;;
  *) fail "invalid --mode '$MODE'. Expected ask, auto, or severity." ;;
esac

case "$REVIEW_SCOPE" in
  uncommitted) ;;
  *) fail "invalid --review-scope '$REVIEW_SCOPE'. Only uncommitted is currently supported." ;;
esac

case "$MAX_FIX_ROUNDS" in
  ''|*[!0-9]*) fail "invalid --max-fix-rounds '$MAX_FIX_ROUNDS'. Expected a non-negative integer." ;;
  *) ;;
esac

PENDING_CHANGES="$(git status --porcelain)"

mkdir -p "$OUTPUT_DIR"
: > "$LOG_FILE"
{
  printf "MODE=%s\n" "$MODE"
  printf "REVIEW_SCOPE=%s\n" "$REVIEW_SCOPE"
  printf "MAX_FIX_ROUNDS=%s\n" "$MAX_FIX_ROUNDS"
  printf "AUTO_FIX_SEVERITIES=%s\n" "$AUTO_FIX_SEVERITIES"
} > "$EFFECTIVE_CONFIG_FILE"

{
  printf "[%s] Starting Codex review\n" "$(timestamp)"
  printf "Working directory: %s\n" "$(pwd)"
  printf "Review file: %s\n" "$REVIEW_FILE"
  printf "Log file: %s\n" "$LOG_FILE"
  printf "Effective mode: %s\n" "$MODE"
  printf "Effective review scope: %s\n" "$REVIEW_SCOPE"
  printf "Effective max fix rounds: %s\n" "$MAX_FIX_ROUNDS"
  printf "Effective auto-fix severities: %s\n" "$AUTO_FIX_SEVERITIES"
  if [ -n "$EXTRA_INSTRUCTIONS_TEXT" ]; then
    printf "Extra instructions: %s\n" "$EXTRA_INSTRUCTIONS_TEXT"
  fi
} >> "$LOG_FILE"

if [ ! -f "$CONFIG_FILE" ]; then
  {
    printf "[%s] Config file %s not found; using built-in defaults.\n" "$(timestamp)" "$CONFIG_FILE"
  } >> "$LOG_FILE"
fi

if [ -z "$PENDING_CHANGES" ]; then
  {
    printf "# Codex Review\n\n"
    printf "No staged, unstaged, or untracked changes were found.\n"
  } > "$REVIEW_FILE"
  {
    printf "[%s] No uncommitted changes found; skipped Codex review.\n" "$(timestamp)"
  } >> "$LOG_FILE"
  printf "No uncommitted changes found. Wrote %s\n" "$REVIEW_FILE"
  exit 0
fi

if [ -n "$EXTRA_INSTRUCTIONS_TEXT" ]; then
  {
    printf "[%s] Note: this Codex CLI version does not accept custom review instructions with --uncommitted; extra instructions are logged for Claude's follow-up context only.\n" "$(timestamp)"
  } >> "$LOG_FILE"
fi

{
  printf "[%s] Running: codex review --uncommitted\n" "$(timestamp)"
} >> "$LOG_FILE"

if codex review --uncommitted > "$REVIEW_FILE" 2>> "$LOG_FILE"; then
  {
    printf "[%s] Codex review completed successfully.\n" "$(timestamp)"
  } >> "$LOG_FILE"
  printf "Codex review completed. Wrote %s\n" "$REVIEW_FILE"
else
  status=$?
  {
    printf "[%s] Codex review failed with exit code %s.\n" "$(timestamp)" "$status"
  } >> "$LOG_FILE"
  printf "# Codex Review Failed\n\nCodex review failed with exit code %s. See %s for details.\n" "$status" "$LOG_FILE" > "$REVIEW_FILE"
  exit "$status"
fi
