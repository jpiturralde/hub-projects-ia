#Requires -Version 5.1

BeforeAll {
  $script:testsRoot = $PSScriptRoot | Split-Path -Parent
  $script:repoRoot = Split-Path -Parent $script:testsRoot
  $script:copilotModule = Join-Path (Join-Path (Join-Path $script:repoRoot 'scripts') 'lib') 'ConsultingCopilot.psm1'
  Import-Module $script:copilotModule -Force
}

Describe 'Write-ProjectGettingStarted environment checklist (Phase 2)' {
  BeforeEach {
    $script:dir = Join-Path ([System.IO.Path]::GetTempPath()) ("gs-env-" + [guid]::NewGuid().ToString('n'))
    New-Item -ItemType Directory -Path $script:dir -Force | Out-Null
  }

  AfterEach {
    if (Test-Path -LiteralPath $script:dir) {
      Remove-Item -LiteralPath $script:dir -Recurse -Force -ErrorAction SilentlyContinue
    }
  }

  It 'lista Node/npm/npx en ES para Consulting con drawio y no exige .ps1' {
    Write-EngagementMetadata -TargetPath $script:dir -StackProfileValue 'consulting-only' -Fields ([ordered]@{
      clientDisplayName = 'Cliente'
      includeDrawioMcp = $true
      includeBacklogMcp = $false
      includeArchiMcp = $false
      gentleAiScope = 'none'
      docTitlePrefix = 'Demo'
    })
    $path = Write-ProjectGettingStarted `
      -TargetPath $script:dir -StackProfile 'Consulting' -Title 'Demo' -GentleAiScope 'None' `
      -IncludeDrawioMcp $true -IncludeBacklogMcp $false -IncludeArchiMcp $false
    $text = Get-Content -LiteralPath $path -Raw -Encoding UTF8
    $text | Should -Match 'node'
    $text | Should -Match 'npm'
    $text | Should -Match 'npx'
    $text | Should -Match 'Obligatorio'
    $text | Should -Match 'Aun no materializado'
    $text | Should -Match 'Con problemas \(roto\)'
    $text | Should -Match 'siempre es un fallo'
    $text | Should -Match 'Preparar entorno'
    $text | Should -Match 'Setup-ProjectEnvironment\.ps1'
    $text | Should -Match 'Publicar memoria'
    $text | Should -Match 'Publish-ProjectMemory\.ps1'
    $text | Should -Match 'sensible'
    $text | Should -Not -Match '(?i)servidores esperados \(\*\*engram'
    $text | Should -Match 'hub generador padre'
  }

  It 'GentleAi no trata MCP local ausente como fallo obligatorio' {
    Write-ProjectProfile -TargetPath $script:dir -ProjectName 'solo-ga' -GentleAiScope 'Global'
    $path = Write-ProjectGettingStarted `
      -TargetPath $script:dir -StackProfile 'GentleAi' -Title 'solo-ga' -GentleAiScope 'Global'
    $text = Get-Content -LiteralPath $path -Raw -Encoding UTF8
    $text | Should -Match 'solo informativo'
    $text | Should -Match 'gentle-ai'
    $text | Should -Match 'Obligatorio'
  }
}

Describe 'Get-GentleAiDualInstallDiagnosis (Phase 2)' {
  BeforeEach {
    $script:fakeHome = Join-Path ([System.IO.Path]::GetTempPath()) ("ga-dual-home-" + [guid]::NewGuid().ToString('n'))
    $script:ws = Join-Path ([System.IO.Path]::GetTempPath()) ("ga-dual-ws-" + [guid]::NewGuid().ToString('n'))
    New-Item -ItemType Directory -Path $script:fakeHome -Force | Out-Null
    New-Item -ItemType Directory -Path $script:ws -Force | Out-Null
    $env:TEST_USER_HOME = $script:fakeHome
  }

  AfterEach {
    Remove-Item Env:TEST_USER_HOME -ErrorAction SilentlyContinue
    foreach ($p in @($script:fakeHome, $script:ws)) {
      if (Test-Path -LiteralPath $p) {
        Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction SilentlyContinue
      }
    }
  }

  It 'reporta conflicto dual sin mutar marcadores' {
    $globalRule = Join-Path $script:fakeHome '.cursor/rules/gentle-ai.mdc'
    $wsRule = Join-Path $script:ws '.cursor/rules/gentle-ai.mdc'
    New-Item -ItemType Directory -Path (Split-Path $globalRule -Parent) -Force | Out-Null
    New-Item -ItemType Directory -Path (Split-Path $wsRule -Parent) -Force | Out-Null
    Set-Content -LiteralPath $globalRule -Value '# global' -Encoding UTF8
    Set-Content -LiteralPath $wsRule -Value '# workspace' -Encoding UTF8

    $beforeGlobal = Get-Content -LiteralPath $globalRule -Raw
    $beforeWs = Get-Content -LiteralPath $wsRule -Raw

    $diag = Get-GentleAiDualInstallDiagnosis -TargetPath $script:ws -UserHome $script:fakeHome
    $diag.Dual | Should -BeTrue
    $diag.Status | Should -Be 'Conflict'
    $diag.Message | Should -Match 'No se modifica'
    Test-GentleAiDualInstall -TargetPath $script:ws -UserHome $script:fakeHome | Should -BeTrue

    (Get-Content -LiteralPath $globalRule -Raw) | Should -Be $beforeGlobal
    (Get-Content -LiteralPath $wsRule -Raw) | Should -Be $beforeWs
  }

  It 'Ok cuando solo hay instalacion global' {
    $globalRule = Join-Path $script:fakeHome '.cursor/rules/gentle-ai.mdc'
    New-Item -ItemType Directory -Path (Split-Path $globalRule -Parent) -Force | Out-Null
    Set-Content -LiteralPath $globalRule -Value '# global' -Encoding UTF8
    $diag = Get-GentleAiDualInstallDiagnosis -TargetPath $script:ws -UserHome $script:fakeHome
    $diag.Dual | Should -BeFalse
    $diag.Status | Should -Be 'Ok'
  }
}
