#Requires -Version 5.1

BeforeAll {
  $script:testsRoot = $PSScriptRoot | Split-Path -Parent
  $script:repoRoot = Split-Path -Parent $script:testsRoot
  Import-Module (Join-Path $script:repoRoot 'scripts\lib\ConsultingCopilot.psm1') -Force
  Import-Module (Join-Path $script:testsRoot 'helpers\TestSandbox.psm1') -Force
  . (Join-Path $script:testsRoot 'helpers\CharacterizationHelpers.ps1')
  . (Join-Path $script:testsRoot 'helpers\FakeCommand.ps1')
}

AfterAll {
  Remove-TestSandbox
}

Describe 'Perfil ConsultingAI' {
  BeforeEach {
    $script:ctx = Initialize-CharacterizationContext -FakeHomeFixture 'global-gentle-ai' -WithFakeCommands -SmartGentleAi
  }

  AfterEach {
    Remove-TestSandbox
  }

  It 'reutiliza Gentle AI global sin invocar install' {
    $target = New-CharacterizationTarget -Name 'consultingai-reuse-global' -Context $script:ctx
    Invoke-CharacterizationGenerator -Context $script:ctx -TargetPath $target -Params @{
      StackProfile = 'ConsultingAI'
      GentleAiScope = 'Existing'
      ClientDisplayName = 'SmokeAI'
      ClientSlug = 'smokeai'
      InitiativeDisplayName = 'Encargo'
      InitiativeId = 'SMK01'
    }

    $log = Get-FakeCommandLog -FakeBinDir $script:ctx.Sandbox.FakeBinDir
    @($log | Where-Object { $_.argv -contains 'install' }).Count | Should -Be 0
  }

  It 'aplica skeleton, consultoría y capa CDD/SDD' {
    $target = New-CharacterizationTarget -Name 'consultingai-structure' -Context $script:ctx
    Invoke-CharacterizationGenerator -Context $script:ctx -TargetPath $target -Params @{
      StackProfile = 'ConsultingAI'
      GentleAiScope = 'Existing'
      ClientDisplayName = 'SmokeAI'
      ClientSlug = 'smokeai'
      InitiativeDisplayName = 'Encargo'
      InitiativeId = 'SMK02'
    }

    Test-Path (Join-Path $target '.cursor\rules\consulting-copilot.mdc') | Should -Be $true
    Test-Path (Join-Path $target '.cursor\rules\gentle-ai-consulting.mdc') | Should -Be $true
    Test-Path (Join-Path $target '.cursor\agents\cdd-explore.md') | Should -Be $true
    Test-Path (Join-Path $target '.cursor\skills\consulting-driven-delivery\SKILL.md') | Should -Be $true
    Test-Path (Join-Path $target '.atl\stack-profile.json') | Should -Be $true
  }

  It 'registra consulting-ai y engramMcpSource gentle-ai-managed sin Engram local' {
    $target = New-CharacterizationTarget -Name 'consultingai-meta' -Context $script:ctx
    Invoke-CharacterizationGenerator -Context $script:ctx -TargetPath $target -Params @{
      StackProfile = 'ConsultingAI'
      GentleAiScope = 'Existing'
      ClientDisplayName = 'SmokeAI'
      ClientSlug = 'smokeai'
      InitiativeDisplayName = 'Encargo'
      InitiativeId = 'SMK03'
    }

    $meta = Get-Content (Join-Path $target '.consulting-engagement.json') -Raw | ConvertFrom-Json
    $meta.stackProfile | Should -Be 'consulting-ai'
    $meta.engramMcpSource | Should -Be 'gentle-ai-managed'
    $meta.requestedProfile | Should -Be 'ConsultingAI'
    $meta.schemaVersion | Should -Be 4
    $reqIds = @($meta.requires.tools | ForEach-Object { $_.id })
    $reqIds | Should -Not -Contain 'engram'
    @($meta.requires.tools | Where-Object { $_.level -eq 'absent' }).Count | Should -Be 0
    $servers = @(Get-McpServerNamesFromProject -ProjectRoot $target)
    $servers | Should -Not -Contain 'engram'
    Test-Path (Join-Path $target 'scripts/Test-ProjectEnvironment.ps1') | Should -Be $true
  }

  It 'instala Gentle AI global cuando se elige Global sin configuración previa' {
    Remove-TestSandbox
    $script:ctx = Initialize-CharacterizationContext -FakeHomeFixture 'empty' -WithFakeCommands -SmartGentleAi
    $target = New-CharacterizationTarget -Name 'consultingai-install-global' -Context $script:ctx

    Invoke-CharacterizationGenerator -Context $script:ctx -TargetPath $target -Params @{
      StackProfile = 'ConsultingAI'
      GentleAiScope = 'Global'
      ClientDisplayName = 'SmokeAI'
      ClientSlug = 'smokeai'
      InitiativeDisplayName = 'Encargo'
      InitiativeId = 'SMK04'
    }

    $log = Get-FakeCommandLog -FakeBinDir $script:ctx.Sandbox.FakeBinDir
    @($log | Where-Object { $_.name -eq 'gentle-ai' -and $_.argv -contains 'install' }).Count | Should -BeGreaterThan 0
    Test-Path (Join-Path $script:ctx.Sandbox.FakeHome '.cursor\rules\gentle-ai.mdc') | Should -Be $true
  }

  It 'instala Gentle AI workspace cuando se elige Workspace sin global' {
    Remove-TestSandbox
    $script:ctx = Initialize-CharacterizationContext -FakeHomeFixture 'empty' -WithFakeCommands -SmartGentleAi
    $target = New-CharacterizationTarget -Name 'consultingai-install-workspace' -Context $script:ctx

    Invoke-CharacterizationGenerator -Context $script:ctx -TargetPath $target -Params @{
      StackProfile = 'ConsultingAI'
      GentleAiScope = 'Workspace'
      ClientDisplayName = 'SmokeAI'
      ClientSlug = 'smokeai'
      InitiativeDisplayName = 'Encargo'
      InitiativeId = 'SMK05'
    }

    Test-Path (Join-Path $target '.cursor\rules\gentle-ai.mdc') | Should -Be $true
    $meta = Get-Content (Join-Path $target '.consulting-engagement.json') -Raw | ConvertFrom-Json
    $meta.gentleAiScope | Should -Be 'workspace'
  }
}
