# Engram - Shared helpers for Claude Code hooks (PowerShell)

function Invoke-Git {
    param([string[]]$Arguments)
    $output = & git @Arguments 2>$null
    if ($LASTEXITCODE -ne 0) { throw "git failed" }
    return $output
}

function Get-EngramProject {
    param(
        [string]$Dir
    )

    # Try git remote origin URL
    try {
        $url = Invoke-Git -Arguments @("-C", $Dir, "remote", "get-url", "origin")
        if ($url) {
            $name = ($url -replace '\.git$', '') -replace '.*[/:]', ''
            if ($name) { return $name }
        }
    } catch {}

    # Fallback: git root directory name
    try {
        $root = Invoke-Git -Arguments @("-C", $Dir, "rev-parse", "--show-toplevel")
        if ($root) { return Split-Path $root -Leaf }
    } catch {}

    # Final fallback: cwd basename
    return Split-Path $Dir -Leaf
}
