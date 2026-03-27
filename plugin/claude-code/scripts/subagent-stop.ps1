# Engram - SubagentStop hook for Claude Code / Copilot CLI (PowerShell, async)
#
# Reads the subagent output from stdin, POSTs it to the passive capture
# endpoint. All extraction logic lives in the Go server.

param()

. "$PSScriptRoot\_helpers.ps1"

$EngramPort = if ($env:ENGRAM_PORT) { $env:ENGRAM_PORT } else { "7437" }
$EngramUrl = "http://127.0.0.1:$EngramPort"

$RawInput = [Console]::In.ReadToEnd()
$Hook = $RawInput | ConvertFrom-Json

$SessionId = $Hook.session_id
$Cwd = $Hook.cwd
$Output = $Hook.stdout
$Project = Get-EngramProject $Cwd

if (-not $Output) { exit 0 }

try {
    Invoke-RestMethod -Uri "$EngramUrl/observations/passive" -Method Post `
        -ContentType "application/json" `
        -Body (@{
            session_id = $SessionId
            content = $Output
            project = $Project
            source = "subagent-stop"
        } | ConvertTo-Json) `
        -ErrorAction SilentlyContinue | Out-Null
} catch {}

exit 0
