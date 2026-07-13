#!/bin/bash
# UserPromptSubmit hook: deterministically re-inject the apple-platform-think
# grounding rule at the moment the agent acts, so API-verification discipline
# does not depend on the agent recalling CLAUDE.md from a long context.
#
# Fires when the work is plausibly Apple-API-shaped: always once the repo
# contains Swift sources (implementation era), otherwise only when the prompt
# mentions an Apple-platform keyword (docs era stays noise-free).

set -e

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"

INPUT=$(cat 2>/dev/null || true)
PROMPT=$(printf '%s' "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('prompt',''))" 2>/dev/null || true)

HAS_SWIFT=0
if find "$PROJECT_DIR" -name '*.swift' -not -path '*/.*' -print -quit 2>/dev/null | grep -q .; then
  HAS_SWIFT=1
fi

MATCHES=0
if printf '%s' "$PROMPT" | grep -qiE 'swift|swiftui|swiftdata|cloudkit|xcode|widget|app intent|avfoundation|xctest|ios|ipados|macos|watchos|apple|api|simulator|entitlement|signing|catalog|player|stage|milestone|spec'; then
  MATCHES=1
fi

if [ "$HAS_SWIFT" = "0" ] && [ "$MATCHES" = "0" ]; then
  exit 0
fi

MSG="Apple-platform grounding (hard rule, CLAUDE.md/PLAN.md): before asserting or locking any Apple API, availability, deprecation, or platform behavior, use the apple-platform-think skill and its docs ladder (local exports -> offline docset -> Sosumi/web last). Never state Apple API facts from memory. For UI work also apply swiftui-design-principles."

printf '{"hookSpecificOutput": {"hookEventName": "UserPromptSubmit", "additionalContext": "%s"}}\n' "$MSG"
exit 0
