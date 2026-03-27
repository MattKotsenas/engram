# Engram - SessionStart hook for Claude Code / Copilot CLI (PowerShell)
#
# 1. Ensures the engram server is running
# 2. Creates a session in engram
# 3. Auto-imports git-synced chunks if .engram/manifest.json exists
# 4. Injects Memory Protocol instructions + memory context

param()

. "$PSScriptRoot\_helpers.ps1"

$EngramPort = if ($env:ENGRAM_PORT) { $env:ENGRAM_PORT } else { "7437" }
$EngramUrl = "http://127.0.0.1:$EngramPort"

$Input = [Console]::In.ReadToEnd()
$Hook = $Input | ConvertFrom-Json

$SessionId = $Hook.session_id
$Cwd = $Hook.cwd
$OldProject = Split-Path $Cwd -Leaf
$Project = Get-EngramProject $Cwd

# Ensure engram server is running
try {
    Invoke-RestMethod -Uri "$EngramUrl/health" -TimeoutSec 1 -ErrorAction Stop | Out-Null
} catch {
    try {
        Start-Process -FilePath "engram" -ArgumentList "serve" -WindowStyle Hidden
        Start-Sleep -Milliseconds 500
    } catch {}
}

# Migrate project name if it changed
if ($OldProject -ne $Project -and $OldProject -and $Project) {
    try {
        Invoke-RestMethod -Uri "$EngramUrl/projects/migrate" -Method Post `
            -ContentType "application/json" `
            -Body (@{ old_project = $OldProject; new_project = $Project } | ConvertTo-Json) `
            -ErrorAction SilentlyContinue | Out-Null
    } catch {}
}

# Create session
if ($SessionId -and $Project) {
    try {
        Invoke-RestMethod -Uri "$EngramUrl/sessions" -Method Post `
            -ContentType "application/json" `
            -Body (@{ id = $SessionId; project = $Project; directory = $Cwd } | ConvertTo-Json) `
            -ErrorAction SilentlyContinue | Out-Null
    } catch {}
}

# Auto-import git-synced chunks
if (Test-Path (Join-Path $Cwd ".engram" "manifest.json")) {
    try { & engram sync --import 2>$null } catch {}
}

# Fetch memory context
$Context = ""
try {
    $EncodedProject = [uri]::EscapeDataString($Project)
    $response = Invoke-RestMethod -Uri "$EngramUrl/context?project=$EncodedProject" -TimeoutSec 3 -ErrorAction Stop
    $Context = $response.context
} catch {}

# Inject Memory Protocol + context - stdout goes to agent as additionalContext
@"
## Engram Persistent Memory - ACTIVE PROTOCOL

You have engram memory tools. This protocol is MANDATORY and ALWAYS ACTIVE.

### CORE TOOLS - always available, no ToolSearch needed
mem_save, mem_search, mem_context, mem_session_summary, mem_get_observation, mem_save_prompt

Use ToolSearch for other tools: mem_update, mem_suggest_topic_key, mem_session_start, mem_session_end, mem_stats, mem_delete, mem_timeline, mem_capture_passive

### PROACTIVE SAVE - do NOT wait for user to ask
Call ``mem_save`` IMMEDIATELY after ANY of these:
- Decision made (architecture, convention, workflow, tool choice)
- Bug fixed (include root cause)
- Convention or workflow documented/updated
- Notion/Jira/GitHub artifact created or updated with significant content
- Non-obvious discovery, gotcha, or edge case found
- Pattern established (naming, structure, approach)
- User preference or constraint learned
- Feature implemented with non-obvious approach
- User confirms your recommendation ("dale", "go with that", "sounds good", "si, esa")
- User rejects an approach or expresses a preference ("no, better X", "I prefer X", "siempre hace X")
- Discussion concludes with a clear direction chosen

**Self-check after EVERY task**: "Did I or the user just make a decision, confirm a recommendation, express a preference, fix a bug, learn something, or establish a convention? If yes -> mem_save NOW."

### SEARCH MEMORY when:
- User asks to recall anything ("remember", "what did we do", "acordate", "que hicimos")
- Starting work on something that might have been done before
- User mentions a topic you have no context on
- User's FIRST message references the project, a feature, or a problem - call ``mem_search`` with keywords from their message to check for prior work before responding

### SUB-AGENT SCOPE
If you are a sub-agent or delegated task (launched by an orchestrator/parent agent):
- DO NOT call ``mem_session_start``, ``mem_session_end``, or ``mem_session_summary``
- You MAY call ``mem_save`` once for important discoveries, and ``mem_search``/``mem_context`` as needed
- Return your result to the parent agent when done - that is your only "close" action

### SESSION CLOSE - TOP-LEVEL AGENT ONLY, before saying "done":
Call ``mem_session_summary`` with: Goal, Discoveries, Accomplished, Next Steps, Relevant Files.
"@

if ($Context) {
    Write-Output ""
    Write-Output $Context
}

exit 0
