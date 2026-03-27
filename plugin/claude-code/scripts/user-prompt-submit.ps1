# Engram - UserPromptSubmit hook for Claude Code / Copilot CLI (PowerShell)
#
# On the FIRST message of a session: injects a ToolSearch instruction to force
# loading all engram memory tools (which are deferred by default).
#
# On subsequent messages: checks when the last mem_save was for the current
# project. If it's been > 15 minutes AND the session has been active > 5
# minutes, injects a nudge reminding the agent to save.
#
# MUST exit 0 always and output valid JSON - otherwise the message is blocked.

param()

. "$PSScriptRoot\_helpers.ps1"

$EngramPort = if ($env:ENGRAM_PORT) { $env:ENGRAM_PORT } else { "7437" }
$EngramUrl = "http://127.0.0.1:$EngramPort"

$RawInput = [Console]::In.ReadToEnd()
$Hook = $RawInput | ConvertFrom-Json

$Cwd = $Hook.cwd
$SessionId = $Hook.session_id
$Project = Get-EngramProject $Cwd

$Output = "{}"

# Build a stable session key for first-message detection
if ($SessionId) {
    $SessionKey = "engram-claude-$SessionId-tools-loaded"
} else {
    $SafeProject = if ($Project) { $Project } else { "unknown" }
    $SafeProject = $SafeProject -replace '[^a-zA-Z0-9_-]', '_'
    $SessionKey = "engram-claude-$SafeProject-$PID-tools-loaded"
}

$StateFile = Join-Path $env:TEMP $SessionKey

if (-not (Test-Path $StateFile)) {
    # FIRST MESSAGE - create state file and inject ToolSearch + mem_context
    New-Item -Path $StateFile -ItemType File -Force | Out-Null

    $ToolMsg = @"
CRITICAL FIRST ACTION - Execute this ToolSearch NOW before responding to the user:
select:mcp__plugin_engram_engram__mem_save,mcp__plugin_engram_engram__mem_search,mcp__plugin_engram_engram__mem_context,mcp__plugin_engram_engram__mem_session_summary,mcp__plugin_engram_engram__mem_get_observation,mcp__plugin_engram_engram__mem_save_prompt

After loading tools, call mem_context to check for prior session history before responding.
"@

    $Output = @{ systemMessage = $ToolMsg } | ConvertTo-Json -Compress
    Write-Output $Output
    exit 0
}

# SUBSEQUENT MESSAGES - save nudge logic

if (-not $Project) {
    Write-Output $Output
    exit 0
}

# Check session age - skip nudge if session < 5 minutes old
if ($SessionId) {
    try {
        $sessionInfo = Invoke-RestMethod -Uri "$EngramUrl/sessions/$SessionId" -TimeoutSec 1 -ErrorAction Stop
        $sessionStart = [datetime]::Parse($sessionInfo.started_at)
        $sessionAge = (Get-Date) - $sessionStart
        if ($sessionAge.TotalSeconds -lt 300) {
            Write-Output $Output
            exit 0
        }
    } catch {
        Write-Output $Output
        exit 0
    }
}

# Fetch the most recent observation for this project
try {
    $EncodedProject = [uri]::EscapeDataString($Project)
    $lastSave = Invoke-RestMethod -Uri "$EngramUrl/observations?project=$EncodedProject&limit=1&sort=created_at:desc" `
        -TimeoutSec 1 -ErrorAction Stop
} catch {
    Write-Output $Output
    exit 0
}

if (-not $lastSave -or -not $lastSave[0].created_at) {
    Write-Output $Output
    exit 0
}

# Parse last save timestamp and compare to now
try {
    $lastSaveAt = [datetime]::Parse($lastSave[0].created_at)
    $elapsed = (Get-Date) - $lastSaveAt

    # Nudge if last save was > 15 minutes ago
    if ($elapsed.TotalSeconds -gt 900) {
        $Output = @{
            systemMessage = "MEMORY REMINDER: It's been over 15 minutes since your last save. If you've made decisions, discoveries, or completed significant work, call mem_save now."
        } | ConvertTo-Json -Compress
    }
} catch {}

Write-Output $Output
exit 0
