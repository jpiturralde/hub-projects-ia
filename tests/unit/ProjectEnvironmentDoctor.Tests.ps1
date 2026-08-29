#Requires -Version 5.1
BeforeAll {
  $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
  Import-Module (Join-Path $repoRoot 'scripts/lib/ConsultingCopilot.psm1') -Force
}

Describe 'Invoke-HubProjectEnvironmentDoctor' {
  It 'emite doctor en Write-ProjectProfile y AsJson tiene forma congelada' {
    $dir = Join-Path '/tmp' ("doc-unit-" + [guid]::NewGuid().ToString('n'))
    New-Item -ItemType Directory -Path $dir | Out-Null
    try {
      Write-ProjectProfile -TargetPath $dir -ProjectName 'u' -GentleAiScope global
      Test-Path (Join-Path $dir 'scripts/Test-ProjectEnvironment.ps1') | Should -Be $true
      $jsonText = Invoke-HubProjectEnvironmentDoctor -TargetPath $dir -AsJson
      $obj = $jsonText | ConvertFrom-Json
      $obj.PSObject.Properties.Name | Should -Contain 'ok'
      $obj.PSObject.Properties.Name | Should -Contain 'exitCode'
      $obj.PSObject.Properties.Name | Should -Contain 'checks'
      ($obj.checks | Where-Object { $_.id -eq 'local-mcp' }).state | Should -Be 'not-materialized'
    } finally {
      Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue
    }
  }

  It 'MCP broken fuerza exitCode 2' {
    $dir = Join-Path '/tmp' ("doc-brk-" + [guid]::NewGuid().ToString('n'))
    New-Item -ItemType Directory -Path $dir | Out-Null
    try {
      Write-ProjectProfile -TargetPath $dir -ProjectName 'u' -GentleAiScope global
      $cursor = Join-Path $dir '.cursor'
      New-Item -ItemType Directory -Path $cursor -Force | Out-Null
      Set-Content -LiteralPath (Join-Path $cursor 'mcp.json') -Value '{ bad' -NoNewline
      $r = Invoke-HubProjectEnvironmentDoctor -TargetPath $dir
      $r.exitCode | Should -Be 2
      $r.ok | Should -Be $false
      ($r.checks | Where-Object { $_.id -eq 'local-mcp' }).state | Should -Be 'broken'
    } finally {
      Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue
    }
  }
}
