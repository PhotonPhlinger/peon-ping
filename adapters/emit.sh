#!/bin/bash
# peon-ping generic adapter
# Agent-neutral entry point: any tool, script, or agent harness can play a
# peon-ping sound by naming a CESP category, with no harness-specific adapter.
#
# Usage:
#   bash emit.sh task.complete
#   bash emit.sh input.required --session-id my-agent --message "needs approval"
#
# Categories: session.start, task.complete, input.required, task.error,
#             resource.limit, task.acknowledge
#
# Resolves the install folder from CLAUDE_PEON_DIR, then from this script's
# own location (<install>/adapters/emit.sh), then the default Claude path.

set -uo pipefail

_self_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -n "${CLAUDE_PEON_DIR:-}" ]; then
  PEON_DIR="$CLAUDE_PEON_DIR"
elif [ -f "$_self_dir/../peon.sh" ]; then
  PEON_DIR="$(cd "$_self_dir/.." && pwd)"
else
  PEON_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks/peon-ping"
fi
PEON_SH="$PEON_DIR/peon.sh"
[ -f "$PEON_SH" ] || exit 0

CATEGORY="${1:-}"
shift || true
SESSION_ID="emit-$$"
CWD="$PWD"
MESSAGE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --session-id) SESSION_ID="${2:-}"; shift 2 ;;
    --cwd) CWD="${2:-}"; shift 2 ;;
    --message) MESSAGE="${2:-}"; shift 2 ;;
    *) shift ;;
  esac
done

# CESP category -> the hook event peon.sh routes to that category
case "$CATEGORY" in
  session.start) EVENT="SessionStart" ;;
  task.complete) EVENT="Stop" ;;
  input.required) EVENT="PermissionRequest" ;;
  task.error) EVENT="PostToolUseFailure" ;;
  resource.limit) EVENT="PreCompact" ;;
  task.acknowledge) EVENT="SubagentStart" ;;
  *)
    echo "peon-ping emit: unknown category '$CATEGORY'. Use one of: session.start, task.complete, input.required, task.error, resource.limit, task.acknowledge" >&2
    exit 2
    ;;
esac

python3 -c '
import json, sys
event, session_id, cwd, message = sys.argv[1:5]
payload = {"hook_event_name": event, "notification_type": "", "cwd": cwd,
           "session_id": session_id, "permission_mode": ""}
if event == "PostToolUseFailure":
    payload["tool_name"] = "Bash"
    payload["error"] = message or "task error"
elif event == "PermissionRequest" and message:
    payload["tool_name"] = message
elif event == "Stop" and message:
    payload["last_assistant_message"] = message
    payload["transcript_summary"] = message
print(json.dumps(payload))
' "$EVENT" "$SESSION_ID" "$CWD" "$MESSAGE" | bash "$PEON_SH" >/dev/null 2>&1

exit 0
