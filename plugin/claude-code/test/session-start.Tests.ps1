BeforeAll {
    . $PSScriptRoot\..\scripts\_helpers.ps1
}

Describe "session-start.ps1 protocol output" {
    It "can be executed and produces protocol text" {
        $result = '{"session_id":"test-123","cwd":"C:\\Projects\\test-project"}' | pwsh -NoProfile -File "$PSScriptRoot\..\scripts\session-start.ps1" 2>$null
        $text = $result -join "`n"
        $text | Should -Match "Engram Persistent Memory"
    }

    It "includes PROACTIVE SAVE instructions" {
        $result = '{"session_id":"test-123","cwd":"C:\\Projects\\test-project"}' | pwsh -NoProfile -File "$PSScriptRoot\..\scripts\session-start.ps1" 2>$null
        $text = $result -join "`n"
        $text | Should -Match "PROACTIVE SAVE"
        $text | Should -Match "mem_save"
    }

    It "includes sub-agent scope guard (PR #129)" {
        $result = '{"session_id":"test-123","cwd":"C:\\Projects\\test-project"}' | pwsh -NoProfile -File "$PSScriptRoot\..\scripts\session-start.ps1" 2>$null
        $text = $result -join "`n"
        $text | Should -Match "SUB-AGENT SCOPE"
        $text | Should -Match "DO NOT call"
    }

    It "marks SESSION CLOSE as TOP-LEVEL AGENT ONLY" {
        $result = '{"session_id":"test-123","cwd":"C:\\Projects\\test-project"}' | pwsh -NoProfile -File "$PSScriptRoot\..\scripts\session-start.ps1" 2>$null
        $text = $result -join "`n"
        $text | Should -Match "TOP-LEVEL AGENT ONLY"
    }

    It "includes SEARCH MEMORY instructions" {
        $result = '{"session_id":"test-123","cwd":"C:\\Projects\\test-project"}' | pwsh -NoProfile -File "$PSScriptRoot\..\scripts\session-start.ps1" 2>$null
        $text = $result -join "`n"
        $text | Should -Match "SEARCH MEMORY"
        $text | Should -Match "mem_search"
    }
}
