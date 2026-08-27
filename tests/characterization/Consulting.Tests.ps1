#Requires -Version 5.1

BeforeAll {
  $script:testsRoot = $PSScriptRoot | Split-Path -Parent
  $script:repoRoot = Split-Path -Parent $script:testsRoot
  Import-Module (Join-Path $script:repoRoot 'scripts\lib\ConsultingCopilot.psm1') -Force
  Import-Module (Join-Path $script:testsRoot 'helpers\TestSandbox.psm1') -Force
  . (Join-Path $script:testsRoot 'helpers\CharacterizationHelpers.ps1')
}

AfterAll {
  Remove-TestSandbox
}

Describe 'Perfil Consulting' {
  BeforeEach {
    $script:ctx = Initialize-CharacterizationContext
  }

  AfterEach {
    Remove-TestSandbox
  }

  It 'no invoca gentle-ai durante la generación' {
    $target = New-CharacterizationTarget -Name 'consulting-no-ga' -Context $script:ctx
    Invoke-CharacterizationGenerator -Context $script:ctx -TargetPath $target -Params @{
      StackProfile = 'Consulting'
      ClientDisplayName = 'Cliente'
      ClientSlug = 'cliente'
      InitiativeDisplayName = 'Assessment'
      InitiativeId = 'A01'
    }

    $logPath = Join-Path $script:ctx.Sandbox.FakeBinDir 'fake-command.log'
    if (Test-Path -LiteralPath $logPath) {
      $log = Get-Content -LiteralPath $logPath -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
      if ($log) { $log.name | Should -Not -Be 'gentle-ai' }
    }
  }

  It 'usa skeleton completo y overlay de consultoría sin capa CDD' {
    $target = New-CharacterizationTarget -Name 'consulting-structure' -Context $script:ctx
    Invoke-CharacterizationGenerator -Context $script:ctx -TargetPath $target -Params @{
      StackProfile = 'Consulting'
      ClientDisplayName = 'Cliente'
      ClientSlug = 'cliente'
      InitiativeDisplayName = 'Assessment'
      InitiativeId = 'A02'
    }

    Test-Path (Join-Path $target 'SPEC.md') | Should -Be $true
    Test-Path (Join-Path $target 'ARCHITECTURE.md') | Should -Be $true
    Test-Path (Join-Path $target '.cursor\rules\consulting-copilot.mdc') | Should -Be $true
    Test-Path (Join-Path $target '.cursor\agents\cdd-explore.md') | Should -Be $false
    Test-Path (Join-Path $target '.cursor\rules\gentle-ai-consulting.mdc') | Should -Be $false
    Test-Path (Join-Path $target '.cursor\rules\gentle-ai.mdc') | Should -Be $false
  }

  It 'registra metadata consulting-only sin Engram local' {
    $target = New-CharacterizationTarget -Name 'consulting-meta' -Context $script:ctx
    Invoke-CharacterizationGenerator -Context $script:ctx -TargetPath $target -Params @{
      StackProfile = 'Consulting'
      ClientDisplayName = 'Cliente'
      ClientSlug = 'cliente'
      InitiativeDisplayName = 'Assessment'
      InitiativeId = 'A03'
    }

    $meta = Get-Content (Join-Path $target '.consulting-engagement.json') -Raw | ConvertFrom-Json
    $meta.stackProfile | Should -Be 'consulting-only'
    $meta.engramMcpSource | Should -Be 'none'
    $servers = @(Get-McpServerNamesFromProject -ProjectRoot $target)
    $servers | Should -Not -Contain 'engram'
  }
}
