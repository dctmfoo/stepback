#!/bin/bash
# SessionStart hook: point a new/resumed agent at the most recent session
# journal — and at its highest-value fields (Status + Next step) — without
# injecting the whole file (context-budget conscious).

set -e

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
SESSIONS_DIR="$PROJECT_DIR/sessions"
CONTRACT="$SESSIONS_DIR/README.md"

# Public snapshots intentionally omit private session journals. Without the
# contract this hook is disabled instead of creating an undocumented workflow.
[ -f "$CONTRACT" ] || exit 0

# Newest journal (any .md except README.md)
LATEST=""
for f in "$SESSIONS_DIR"/*.md; do
  [ -e "$f" ] || continue
  [ "$(basename "$f")" = "README.md" ] && continue
  if [ -z "$LATEST" ] || [ "$f" -nt "$LATEST" ]; then
    LATEST="$f"
  fi
done

if [ -z "$LATEST" ]; then
  MSG="No prior session journal in sessions/. Per sessions/README.md, create one (YYYY-MM-DD-HHMM-<slug>.md, IST) once the user's first message clarifies the session intent. Default to THIN mode with Live plan pointer = PLAN.md (or the governing spec in docs/specs/)."
else
  REL="${LATEST#"$PROJECT_DIR"/}"
  STATUS_LINE=$(grep -m1 '^\*\*Status:\*\*' "$LATEST" 2>/dev/null || true)
  NEXT_STEP=$(awk '/^## Next step/{flag=1;next} flag&&/^## /{exit} flag&&NF' "$LATEST" 2>/dev/null | head -n 4 || true)
  MSG="Most recent session journal: $REL — read it before acting on the user's prompt. Continuing the same work: append to it. Unrelated work: create a fresh journal per sessions/README.md.
$STATUS_LINE
Next step recorded for a fresh agent:
$NEXT_STEP"
fi

if command -v python3 >/dev/null 2>&1; then
  ESCAPED=$(printf '%s' "$MSG" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))")
else
  ESCAPED="\"$(printf '%s' "$MSG" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\n' ' ')\""
fi

printf '{"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": %s}}\n' "$ESCAPED"
exit 0
