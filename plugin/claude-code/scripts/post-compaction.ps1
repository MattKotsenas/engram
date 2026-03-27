# Engram - Post-compaction hook for Claude Code / Copilot CLI (PowerShell)
#
# When compaction happens, inject Memory Protocol + context and instruct
# the agent to persist the compacted summary via mem_session_summary.

param()

. "$PSScriptRoot\_helpers.ps1"

$EngramPort = if ($env:ENGRAM_PORT) { $env:ENGRAM_PORT } else { "7437" }
$EngramUrl = "http://127.0.0.1:$EngramPort"

$RawInput = [Console]::In.ReadToEnd()
$Hook = $RawInput | ConvertFrom-Json

$SessionId = $Hook.session_id
$Cwd = $Hook.cwd
$Project = Get-EngramProject $Cwd

# Ensure session exists
if ($SessionId -and $Project) {
    try {
        Invoke-RestMethod -Uri "$EngramUrl/sessions" -Method Post `
            -ContentType "application/json" `
            -Body (@{ id = $SessionId; project = $Project; directory = $Cwd } | ConvertTo-Json) `
            -ErrorAction SilentlyContinue | Out-Null
    } catch {}
}

# Fetch context from previous sessions
$Context = ""
try {
    $EncodedProject = [uri]::EscapeDataString($Project)
    $response = Invoke-RestMethod -Uri "$EngramUrl/context?project=$EncodedProject" -TimeoutSec 3 -ErrorAction Stop
    $Context = $response.context
} catch {}

# Inject Memory Protocol + compaction instruction + context
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

**Self-check after EVERY task**: "Did I just make a decision, fix a bug, learn something, or establish a convention? If yes -> mem_save NOW."

### SEARCH MEMORY when:
- User asks to recall anything ("remember", "what did we do")
- Starting work on something that might have been done before
- User mentions a topic you have no context on

### SUB-AGENT SCOPE
If you are a sub-agent or delegated task (launched by an orchestrator/parent agent):
- DO NOT call ``mem_session_start``, ``mem_session_end``, or ``mem_session_summary``
- You MAY call ``mem_save`` once for important discoveries, and ``mem_search``/``mem_context`` as needed
- Return your result to the parent agent when done - that is your only "close" action

### SESSION CLOSE - TOP-LEVEL AGENT ONLY, before saying "done":
Call ``mem_session_summary`` with: Goal, Discoveries, Accomplished, Next Steps, Relevant Files.

---

CRITICAL INSTRUCTION POST-COMPACTION (TOP-LEVEL AGENT ONLY) - follow these steps IN ORDER:

1. FIRST: Call mem_session_summary with the content of the compacted summary above. Use project: '$Project'.
   This preserves what was accomplished before compaction.

2. THEN: Call mem_context with project: '$Project' to recover recent session history and observations.
   Read the returned context carefully - it tells you what was being worked on.

3. If you need more detail on a specific topic, call mem_search with relevant keywords.

4. Only THEN continue working on what the user asked.

All 4 steps are MANDATORY. Without them, you lose context and start blind.
"@

if ($Context) {
    Write-Output ""
    Write-Output $Context
}

exit 0
