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

Describe 'Perfil Full' {
  BeforeEach {
    $script:ctx = Initialize-CharacterizationContext -FakeHomeFixture 'global-gentle-ai' -WithFakeCommands -SmartGentleAi
  }

  AfterEach {
    Remove-TestSandbox
  }

  It 'conserva requestedProfile Full y stackProfile consulting-ai' {
    $target = New-CharacterizationTarget -Name 'full-meta' -Context $script:ctx
    Invoke-CharacterizationGenerator -Context $script:ctx -TargetPath $target -Params @{
      StackProfile = 'Full'
      GentleAiScope = 'Existing'
      ClientDisplayName = 'FullCo'
      ClientSlug = 'fullco'
      InitiativeDisplayName = 'Encargo'
      InitiativeId = 'FUL01'
    }

    $meta = Get-Content (Join-Path $target '.consulting-engagement.json') -Raw | ConvertFrom-Json
    $meta.requestedProfile | Should -Be 'Full'
    $meta.stackProfile | Should -Be 'consulting-ai'
    $meta.engramMcpSource | Should -Be 'gentle-ai-managed'
  }

  It 'genera el mismo contenido funcional que ConsultingAI' {
    $baseParams = @{
      GentleAiScope = 'Existing'
      ClientDisplayName = 'Equiv'
      ClientSlug = 'equiv'
      InitiativeDisplayName = 'Encargo'
      InitiativeId = 'EQV01'
    }

    $targetFull = New-CharacterizationTarget -Name 'full-equiv' -Context $script:ctx
    Invoke-CharacterizationGenerator -Context $script:ctx -TargetPath $targetFull -Params ($baseParams + @{
      StackProfile = 'Full'
    })

    $targetAi = New-CharacterizationTarget -Name 'consultingai-equiv' -Context $script:ctx
    Invoke-CharacterizationGenerator -Context $script:ctx -TargetPath $targetAi -Params ($baseParams + @{
      StackProfile = 'ConsultingAI'
    })

    $manifestFull = Get-NormalizedProjectManifest -ProjectRoot $targetFull
    $manifestAi = Get-NormalizedProjectManifest -ProjectRoot $targetAi

    $fullPaths = @($manifestFull | ForEach-Object { $_.Path })
    $aiPaths = @($manifestAi | ForEach-Object { $_.Path })
    $fullPaths | Should -Be $aiPaths

    $fullFiltered = @($manifestFull | Where-Object { $_.Path -ne '.consulting-engagement.json' })
    $aiFiltered = @($manifestAi | Where-Object { $_.Path -ne '.consulting-engagement.json' })
    $comparison = Compare-ProjectManifests -Left $fullFiltered -Right $aiFiltered
    $comparison.Equivalent | Should -Be $true
  }
}
