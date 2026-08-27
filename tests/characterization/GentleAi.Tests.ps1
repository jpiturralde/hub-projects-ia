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

Describe 'Perfil GentleAi' -Skip:($IsLinux) {
  BeforeEach {
    $script:ctx = Initialize-CharacterizationContext -FakeHomeFixture 'global-gentle-ai' -WithFakeCommands -SmartGentleAi
  }

  AfterEach {
    Remove-TestSandbox
  }

  It 'usa skeleton-minimal con onboarding y sin consultoría' {
    $target = New-CharacterizationTarget -Name 'gentleai-structure' -Context $script:ctx
    Invoke-CharacterizationGenerator -Context $script:ctx -TargetPath $target -Params @{
      StackProfile = 'GentleAi'
      GentleAiScope = 'Existing'
      ProjectName = 'mi-app-test'
    }

    Test-Path (Join-Path $target 'README.md') | Should -Be $true
    Test-Path (Join-Path $target 'SPEC.md') | Should -Be $false
    Test-Path (Join-Path $target '.cursor\skills\onboarding\SKILL.md') | Should -Be $true
    Test-Path (Join-Path $target '.consulting-engagement.json') | Should -Be $false
    Test-Path (Join-Path $target '.cursor\rules\consulting-copilot.mdc') | Should -Be $false
    Test-Path (Join-Path $target '.cursor\agents\cdd-explore.md') | Should -Be $false
  }

  It 'crea .project-profile.json con gentle-ai-only' {
    $target = New-CharacterizationTarget -Name 'gentleai-meta' -Context $script:ctx
    Invoke-CharacterizationGenerator -Context $script:ctx -TargetPath $target -Params @{
      StackProfile = 'GentleAi'
      GentleAiScope = 'Existing'
      ProjectName = 'mi-app-meta'
    }

    $meta = Get-Content (Join-Path $target '.project-profile.json') -Raw | ConvertFrom-Json
    $meta.stackProfile | Should -Be 'gentle-ai-only'
    $meta.projectName | Should -Be 'mi-app-meta'
    $meta.gentleAiScope | Should -Be 'global'
  }

  It 'reutiliza Gentle AI global sin duplicar Engram en mcp local' {
    $target = New-CharacterizationTarget -Name 'gentleai-mcp' -Context $script:ctx
    Invoke-CharacterizationGenerator -Context $script:ctx -TargetPath $target -Params @{
      StackProfile = 'GentleAi'
      GentleAiScope = 'Existing'
      ProjectName = 'mi-app-mcp'
    }

    $mcpPath = Join-Path $target '.cursor\mcp.json'
    if (Test-Path -LiteralPath $mcpPath) {
      Get-McpServerNamesFromProject -ProjectRoot $target | Should -Not -Contain 'engram'
    } else {
      Set-ItResult -Inconclusive -Because 'El perfil GentleAi no crea mcp.json local por defecto'
    }
  }
}
