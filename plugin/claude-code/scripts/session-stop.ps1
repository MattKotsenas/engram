# Engram - Stop hook for Claude Code / Copilot CLI (PowerShell, async)
#
# Marks the session as ended via the HTTP API.
# Runs async so it doesn't block the agent's response.

param()

$EngramPort = if ($env:ENGRAM_PORT) { $env:ENGRAM_PORT } else { "7437" }
$EngramUrl = "http://127.0.0.1:$EngramPort"

$RawInput = [Console]::In.ReadToEnd()
$Hook = $RawInput | ConvertFrom-Json

$SessionId = $Hook.session_id
if (-not $SessionId) { exit 0 }

try {
    Invoke-RestMethod -Uri "$EngramUrl/sessions/$SessionId/end" -Method Post `
        -ContentType "application/json" -Body "{}" `
        -ErrorAction SilentlyContinue | Out-Null
} catch {}

exit 0
