#!/bin/bash
# Stop hook: nudge the agent to create/update the session journal, and scan
# the newest journal for secret-looking content (hard rule in CLAUDE.md).
#
# Loop prevention: reads stop_hook_active from the hook's stdin JSON — when
# true, this Stop was already blocked once this cycle, so we never nudge
# twice (no marker files needed, safe with concurrent sessions).
#
# Freshness window: journal mtime within JOURNAL_FRESH_SECS (default 300s)
# counts as "updated this turn".

set -e

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
SESSIONS_DIR="$PROJECT_DIR/sessions"
CONTRACT="$SESSIONS_DIR/README.md"
FRESH_SECS="${JOURNAL_FRESH_SECS:-300}"

INPUT=$(cat 2>/dev/null || true)
STOP_ACTIVE=$(printf '%s' "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('stop_hook_active', False))" 2>/dev/null || echo False)

# Public snapshots intentionally omit private session journals. Without the
# contract this hook is disabled instead of blocking on undocumented rules.
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

# Secrets scan runs even when stop_hook_active — a leaked credential must not
# survive because the nudge budget was spent. It blocks at most once per
# offending content since the agent is told to remove it.
if [ -n "$LATEST" ] && [ "$STOP_ACTIVE" != "True" ]; then
  # Hex run threshold is 48 (not 40) so full git SHAs never false-positive;
  # journals should use short hashes anyway (sessions/README.md).
  LEAK=$(grep -nE 'eyJ[A-Za-z0-9_-]{20,}|Bearer +[A-Za-z0-9._-]{20,}|(client_secret|api[_-]?key|password) *[=:] *[^ *<]{8,}|[0-9a-fA-F]{48,}' "$LATEST" 2>/dev/null | head -n 3 || true)
  if [ -n "$LEAK" ]; then
    echo "SESSION-JOURNAL-SECRETS-GUARD: $LATEST contains secret-looking content (hard rule: secrets never go in journals). Redact to key names / lengths before finishing this turn:" >&2
    echo "$LEAK" >&2
    exit 2
  fi
fi

if [ "$STOP_ACTIVE" = "True" ]; then
  exit 0
fi

# Case 1: no journal exists
if [ -z "$LATEST" ]; then
  echo "SESSION-JOURNAL-REMINDER: No session journal exists in sessions/. Per sessions/README.md, create one (YYYY-MM-DD-HHMM-<slug>.md, IST) before finishing this turn — THIN mode against PLAN.md (or the governing spec in docs/specs/) unless this is one-off work. Skip only if this session did literally nothing worth resuming (pure Q&A)." >&2
  exit 2
fi

# Case 2: journal exists — freshness check (mac stat -f, linux stat -c)
if stat -f %m "$LATEST" >/dev/null 2>&1; then
  MTIME=$(stat -f %m "$LATEST")
else
  MTIME=$(stat -c %Y "$LATEST")
fi
AGE=$(( $(date +%s) - MTIME ))
[ "$AGE" -lt "$FRESH_SECS" ] && exit 0

# Stale — mode-aware nudge. THIN = Live plan pointer set to a real doc.
PLAN_LINE=$(awk '/^## Live plan pointer[[:space:]]*$/{flag=1;next} flag&&/^## /{exit} flag&&NF{print;exit}' "$LATEST" 2>/dev/null | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' || true)
PLAN_LC=$(printf '%s' "$PLAN_LINE" | tr '[:upper:]' '[:lower:]')

if [ -z "$PLAN_LINE" ] || [ "${PLAN_LC#none}" != "$PLAN_LC" ] || [ "$PLAN_LC" = "<none>" ]; then
  echo "SESSION-JOURNAL-REMINDER (DETAILED mode): $LATEST last touched ${AGE}s ago. If this turn did resumable work, update Milestones / Commits / Files touched / Next step for a fresh agent + 'Last updated' before finishing. If a plan or spec now governs this work (PLAN.md milestone or a docs/specs/ spec), set 'Live plan pointer' and switch to THIN. If the topic keeps recurring in DETAILED mode, promote it to docs/specs/ per sessions/README.md." >&2
else
  echo "SESSION-JOURNAL-REMINDER (THIN mode — pointer: ${PLAN_LINE}): $LATEST last touched ${AGE}s ago. If this turn did resumable work, append a ONE-LINE milestone (milestone/checkpoint id, commit hash, or spec §ref) and refresh 'Last updated' + 'Where we are now' + 'Next step for a fresh agent'. Do NOT re-narrate the governing doc." >&2
fi
exit 2
