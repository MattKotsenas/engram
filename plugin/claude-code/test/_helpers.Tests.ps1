BeforeAll {
    . $PSScriptRoot\..\scripts\_helpers.ps1
}

Describe "Get-EngramProject" {
    Context "when git remote origin is available" {
        It "extracts repo name from HTTPS URL" {
            Mock Invoke-Git { "https://github.com/user/my-repo.git" } -ParameterFilter { $Arguments -contains "get-url" }
            $result = Get-EngramProject "C:\some\path"
            $result | Should -Be "my-repo"
        }

        It "extracts repo name from SSH URL" {
            Mock Invoke-Git { "git@github.com:user/my-repo.git" } -ParameterFilter { $Arguments -contains "get-url" }
            $result = Get-EngramProject "C:\some\path"
            $result | Should -Be "my-repo"
        }

        It "handles URL without .git suffix" {
            Mock Invoke-Git { "https://github.com/user/my-repo" } -ParameterFilter { $Arguments -contains "get-url" }
            $result = Get-EngramProject "C:\some\path"
            $result | Should -Be "my-repo"
        }
    }

    Context "when git remote is not available" {
        BeforeEach {
            Mock Invoke-Git { throw "not a git repo" } -ParameterFilter { $Arguments -contains "get-url" }
        }

        It "falls back to git root directory name" {
            Mock Invoke-Git { "C:\Projects\my-project" } -ParameterFilter { $Arguments -contains "--show-toplevel" }
            $result = Get-EngramProject "C:\Projects\my-project\src"
            $result | Should -Be "my-project"
        }

        It "falls back to cwd basename when not in a git repo" {
            Mock Invoke-Git { throw "not a git repo" } -ParameterFilter { $Arguments -contains "--show-toplevel" }
            $result = Get-EngramProject "C:\Projects\my-folder"
            $result | Should -Be "my-folder"
        }
    }
}
