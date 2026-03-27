BeforeAll {
    . $PSScriptRoot\..\scripts\_helpers.ps1
}

Describe "post-compaction.ps1 protocol output" {
    It "includes memory protocol text" {
        $result = '{"session_id":"test-123","cwd":"C:\\Projects\\test-project"}' | pwsh -NoProfile -File "$PSScriptRoot\..\scripts\post-compaction.ps1" 2>$null
        $text = $result -join "`n"
        $text | Should -Match "Engram Persistent Memory"
    }

    It "includes post-compaction recovery steps" {
        $result = '{"session_id":"test-123","cwd":"C:\\Projects\\test-project"}' | pwsh -NoProfile -File "$PSScriptRoot\..\scripts\post-compaction.ps1" 2>$null
        $text = $result -join "`n"
        $text | Should -Match "CRITICAL INSTRUCTION POST-COMPACTION"
        $text | Should -Match "mem_session_summary"
    }

    It "includes sub-agent scope guard (PR #129)" {
        $result = '{"session_id":"test-123","cwd":"C:\\Projects\\test-project"}' | pwsh -NoProfile -File "$PSScriptRoot\..\scripts\post-compaction.ps1" 2>$null
        $text = $result -join "`n"
        $text | Should -Match "SUB-AGENT SCOPE"
    }

    It "marks post-compaction steps as TOP-LEVEL AGENT ONLY" {
        $result = '{"session_id":"test-123","cwd":"C:\\Projects\\test-project"}' | pwsh -NoProfile -File "$PSScriptRoot\..\scripts\post-compaction.ps1" 2>$null
        $text = $result -join "`n"
        $text | Should -Match "TOP-LEVEL AGENT ONLY"
    }
}

Describe "session-stop.ps1" {
    It "exits 0 with no session_id" {
        $result = '{"cwd":"C:\\Projects\\test"}' | pwsh -NoProfile -File "$PSScriptRoot\..\scripts\session-stop.ps1" 2>$null
        $LASTEXITCODE | Should -Be 0
    }

    It "exits 0 with a session_id" {
        $result = '{"session_id":"test-123","cwd":"C:\\Projects\\test"}' | pwsh -NoProfile -File "$PSScriptRoot\..\scripts\session-stop.ps1" 2>$null
        $LASTEXITCODE | Should -Be 0
    }
}

Describe "subagent-stop.ps1" {
    It "exits 0 with no stdout" {
        $result = '{"session_id":"test-123","cwd":"C:\\Projects\\test"}' | pwsh -NoProfile -File "$PSScriptRoot\..\scripts\subagent-stop.ps1" 2>$null
        $LASTEXITCODE | Should -Be 0
    }

    It "exits 0 with stdout content" {
        $result = '{"session_id":"test-123","cwd":"C:\\Projects\\test","stdout":"some output"}' | pwsh -NoProfile -File "$PSScriptRoot\..\scripts\subagent-stop.ps1" 2>$null
        $LASTEXITCODE | Should -Be 0
    }
}

Describe "user-prompt-submit.ps1" {
    BeforeEach {
        # Clean up any state files from previous test runs
        Get-ChildItem $env:TEMP -Filter "engram-claude-*" -ErrorAction SilentlyContinue | Remove-Item -Force
    }

    AfterAll {
        Get-ChildItem $env:TEMP -Filter "engram-claude-*" -ErrorAction SilentlyContinue | Remove-Item -Force
    }

    It "injects ToolSearch on first message" {
        $result = '{"session_id":"ups-test-first","cwd":"C:\\Projects\\test"}' | pwsh -NoProfile -File "$PSScriptRoot\..\scripts\user-prompt-submit.ps1" 2>$null
        $text = $result -join "`n"
        $text | Should -Match "systemMessage"
        $text | Should -Match "ToolSearch"
        $text | Should -Match "mem_context"
    }

    It "returns empty JSON on second message" {
        # First call creates state file
        '{"session_id":"ups-test-second","cwd":"C:\\Projects\\test"}' | pwsh -NoProfile -File "$PSScriptRoot\..\scripts\user-prompt-submit.ps1" 2>$null | Out-Null
        # Second call should return empty JSON
        $result = '{"session_id":"ups-test-second","cwd":"C:\\Projects\\test"}' | pwsh -NoProfile -File "$PSScriptRoot\..\scripts\user-prompt-submit.ps1" 2>$null
        $text = $result -join ""
        $text | Should -Be "{}"
    }
}
