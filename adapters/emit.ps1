# peon-ping generic adapter (Windows)
# Agent-neutral entry point: any tool, script, or agent harness can play a
# peon-ping sound by naming a CESP category, with no harness-specific adapter.
#
# Usage:
#   powershell -NoProfile -File emit.ps1 task.complete
#   powershell -NoProfile -File emit.ps1 input.required -SessionId my-agent -Message "needs approval"
#
# Categories: session.start, task.complete, input.required, task.error,
#             resource.limit, task.acknowledge
#
# Resolves the install folder from CLAUDE_PEON_DIR, then from this script's
# own location (<install>\adapters\emit.ps1), then the default Claude path.

param(
    [Parameter(Position = 0)]
    [string]$Category = "",
    [string]$SessionId = "",
    [string]$Cwd = "",
    [string]$Message = ""
)

$ErrorActionPreference = "SilentlyContinue"

$PeonDir = if ($env:CLAUDE_PEON_DIR) { $env:CLAUDE_PEON_DIR }
           elseif ($PSScriptRoot -and (Test-Path (Join-Path (Split-Path -Parent $PSScriptRoot) "peon.ps1"))) { Split-Path -Parent $PSScriptRoot }
           else { Join-Path $env:USERPROFILE ".claude\hooks\peon-ping" }

$PeonScript = Join-Path $PeonDir "peon.ps1"
if (-not (Test-Path $PeonScript)) { exit 0 }

# CESP category -> the hook event peon.ps1 routes to that category
$eventMap = @{
    "session.start"    = "SessionStart"
    "task.complete"    = "Stop"
    "input.required"   = "PermissionRequest"
    "task.error"       = "PostToolUseFailure"
    "resource.limit"   = "PreCompact"
    "task.acknowledge" = "SubagentStart"
}

$key = $Category.Trim().ToLower()
if (-not $eventMap.ContainsKey($key)) {
    [Console]::Error.WriteLine("peon-ping emit: unknown category '$Category'. Use one of: $($eventMap.Keys -join ', ')")
    exit 2
}

if (-not $SessionId) { $SessionId = "emit-$PID" }
if (-not $Cwd) { $Cwd = $PWD.Path }

$payload = @{
    hook_event_name = $eventMap[$key]
    notification_type = ""
    cwd = $Cwd
    session_id = $SessionId
    permission_mode = ""
}
if ($key -eq "task.error") {
    $payload["tool_name"] = "Bash"
    $payload["error"] = if ($Message) { $Message } else { "task error" }
}
if ($key -eq "input.required" -and $Message) { $payload["tool_name"] = $Message }
if ($key -eq "task.complete" -and $Message) {
    $payload["last_assistant_message"] = $Message
    $payload["transcript_summary"] = $Message
}

$payloadJson = $payload | ConvertTo-Json -Compress
$payloadJson | powershell -NoProfile -NonInteractive -File $PeonScript >$null 2>$null

exit 0
