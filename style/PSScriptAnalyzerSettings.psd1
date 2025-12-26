@{
  Severity = @('Error','Warning')
  ExcludeRules = @(
    'PSAvoidUsingWriteHost' # CLI tools may intentionally use Write-Host
  )
  Rules = @{
    PSUseConsistentIndentation = @{
      Enable = $true
      IndentationSize = 2
      Kind = 'space'
    }
    PSUseConsistentWhitespace = @{
      Enable = $true
    }
    PSAlignAssignmentStatement = @{
      Enable = $true
    }
    PSAvoidTrailingWhitespace = @{
      Enable = $true
    }
    PSAvoidUsingCmdletAliases = @{
      Enable = $true
      Whitelist = @('cd','ls','rm','mv','cp')
    }
  }
}
