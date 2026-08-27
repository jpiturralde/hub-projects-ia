#Requires -Version 5.1

BeforeAll {
  $script:testsRoot = $PSScriptRoot | Split-Path -Parent
  $script:repoRoot = Split-Path -Parent $script:testsRoot
  $script:expectedRoot = Join-Path $script:testsRoot 'expected'
  Import-Module (Join-Path $script:repoRoot 'scripts\lib\ConsultingCopilot.psm1') -Force
  Import-Module (Join-Path $script:testsRoot 'helpers\TestSandbox.psm1') -Force
  . (Join-Path $script:testsRoot 'helpers\CharacterizationHelpers.ps1')
}

AfterAll {
  Remove-TestSandbox
}

Describe 'Equivalencia de manifiestos normalizados' {
  AfterEach {
    Remove-TestSandbox
  }

  It 'Consulting coincide con el contrato expected y es determinista' {
    $ctx = Initialize-CharacterizationContext -FakeHomeFixture 'empty'
    $params = @{
      StackProfile = 'Consulting'
      ClientDisplayName = 'Equiv'
      ClientSlug = 'equiv'
      InitiativeDisplayName = 'Encargo'
      InitiativeId = 'EQV01'
    }

    $a = New-CharacterizationTarget -Name 'eq-consulting-a' -Context $ctx
    Invoke-CharacterizationGenerator -Context $ctx -TargetPath $a -Params $params
    $b = New-CharacterizationTarget -Name 'eq-consulting-b' -Context $ctx
    Invoke-CharacterizationGenerator -Context $ctx -TargetPath $b -Params $params

    $snap = Get-EquivalenceProjectSnapshot -ProjectRoot $a -ExpectedProfile 'Consulting'
    $check = Assert-EquivalenceContractMatch -Snapshot $snap -ExpectedPath (Join-Path $script:expectedRoot 'consulting\manifest.json')
    if (-not $check.Ok) { throw ($check.Errors -join [Environment]::NewLine) }

    $cmp = Compare-ProjectManifests `
      -Left (Get-NormalizedProjectManifest -ProjectRoot $a) `
      -Right (Get-NormalizedProjectManifest -ProjectRoot $b)
    $cmp.Equivalent | Should -Be $true
  }

  It 'ConsultingAI coincide con expected y es determinista' {
    $ctx = Initialize-CharacterizationContext -FakeHomeFixture 'global-gentle-ai' -WithFakeCommands -SmartGentleAi
    $params = @{
      StackProfile = 'ConsultingAI'
      GentleAiScope = 'Existing'
      ClientDisplayName = 'Equiv'
      ClientSlug = 'equiv'
      InitiativeDisplayName = 'Encargo'
      InitiativeId = 'EQV01'
    }

    $a = New-CharacterizationTarget -Name 'eq-cai-a' -Context $ctx
    Invoke-CharacterizationGenerator -Context $ctx -TargetPath $a -Params $params
    $b = New-CharacterizationTarget -Name 'eq-cai-b' -Context $ctx
    Invoke-CharacterizationGenerator -Context $ctx -TargetPath $b -Params $params

    $snap = Get-EquivalenceProjectSnapshot -ProjectRoot $a -ExpectedProfile 'ConsultingAI'
    $check = Assert-EquivalenceContractMatch -Snapshot $snap -ExpectedPath (Join-Path $script:expectedRoot 'consulting-ai\manifest.json')
    if (-not $check.Ok) { throw ($check.Errors -join [Environment]::NewLine) }

    $cmp = Compare-ProjectManifests `
      -Left (Get-NormalizedProjectManifest -ProjectRoot $a) `
      -Right (Get-NormalizedProjectManifest -ProjectRoot $b)
    $cmp.Equivalent | Should -Be $true
  }

  It 'GentleAi coincide con expected y es determinista' {
    $ctx = Initialize-CharacterizationContext -FakeHomeFixture 'global-gentle-ai' -WithFakeCommands -SmartGentleAi
    $params = @{
      StackProfile = 'GentleAi'
      GentleAiScope = 'Existing'
      ProjectName = 'equiv-app'
    }

    $a = New-CharacterizationTarget -Name 'eq-ga-a' -Context $ctx
    Invoke-CharacterizationGenerator -Context $ctx -TargetPath $a -Params $params
    $b = New-CharacterizationTarget -Name 'eq-ga-b' -Context $ctx
    Invoke-CharacterizationGenerator -Context $ctx -TargetPath $b -Params $params

    $snap = Get-EquivalenceProjectSnapshot -ProjectRoot $a -ExpectedProfile 'GentleAi'
    $check = Assert-EquivalenceContractMatch -Snapshot $snap -ExpectedPath (Join-Path $script:expectedRoot 'gentle-ai\manifest.json')
    if (-not $check.Ok) { throw ($check.Errors -join [Environment]::NewLine) }

    $cmp = Compare-ProjectManifests `
      -Left (Get-NormalizedProjectManifest -ProjectRoot $a) `
      -Right (Get-NormalizedProjectManifest -ProjectRoot $b)
    $cmp.Equivalent | Should -Be $true
  }

  It 'Full coincide con expected y equivale a ConsultingAI salvo requestedProfile' {
    $ctx = Initialize-CharacterizationContext -FakeHomeFixture 'global-gentle-ai' -WithFakeCommands -SmartGentleAi
    $base = @{
      GentleAiScope = 'Existing'
      ClientDisplayName = 'Equiv'
      ClientSlug = 'equiv'
      InitiativeDisplayName = 'Encargo'
      InitiativeId = 'EQV01'
    }

    $full = New-CharacterizationTarget -Name 'eq-full' -Context $ctx
    Invoke-CharacterizationGenerator -Context $ctx -TargetPath $full -Params ($base + @{ StackProfile = 'Full' })
    $ai = New-CharacterizationTarget -Name 'eq-ai' -Context $ctx
    Invoke-CharacterizationGenerator -Context $ctx -TargetPath $ai -Params ($base + @{ StackProfile = 'ConsultingAI' })

    $snapFull = Get-EquivalenceProjectSnapshot -ProjectRoot $full -ExpectedProfile 'Full'
    $check = Assert-EquivalenceContractMatch -Snapshot $snapFull -ExpectedPath (Join-Path $script:expectedRoot 'full\manifest.json')
    if (-not $check.Ok) { throw ($check.Errors -join [Environment]::NewLine) }

    $metaFull = Get-Content (Join-Path $full '.consulting-engagement.json') -Raw | ConvertFrom-Json
    $metaAi = Get-Content (Join-Path $ai '.consulting-engagement.json') -Raw | ConvertFrom-Json
    $metaFull.requestedProfile | Should -Be 'Full'
    $metaAi.requestedProfile | Should -Be 'ConsultingAI'
    $metaFull.stackProfile | Should -Be $metaAi.stackProfile

    $fullManifest = @(Get-NormalizedProjectManifest -ProjectRoot $full | Where-Object { $_.Path -ne '.consulting-engagement.json' })
    $aiManifest = @(Get-NormalizedProjectManifest -ProjectRoot $ai | Where-Object { $_.Path -ne '.consulting-engagement.json' })
    $cmp = Compare-ProjectManifests -Left $fullManifest -Right $aiManifest
    if (-not $cmp.Equivalent) {
      throw ("Full≠ConsultingAI OnlyLeft=$($cmp.OnlyLeft -join ',') OnlyRight=$($cmp.OnlyRight -join ',') HashDiff=$($cmp.HashDiff -join ',')")
    }
  }
}
