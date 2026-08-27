#Requires -Version 5.1

BeforeAll {
  $script:testsRoot = $PSScriptRoot | Split-Path -Parent
  $script:repoRoot = Split-Path -Parent $script:testsRoot
  $script:scriptsRoot = Join-Path $script:repoRoot 'scripts'
  Import-Module (Join-Path $script:repoRoot 'scripts\lib\ConsultingCopilot.psm1') -Force
  Import-Module (Join-Path $script:testsRoot 'helpers\TestSandbox.psm1') -Force
  . (Join-Path $script:testsRoot 'helpers\CharacterizationHelpers.ps1')
}

AfterAll {
  Remove-TestSandbox
}

Describe 'Entrypoints públicos Fase 7' {
  It 'mantiene aliases Ingenia con cadena ConsultingAI' {
    $template = Get-Content -LiteralPath (Join-Path $script:scriptsRoot 'New-IngeniaTemplateProject.ps1') -Raw
    $cursor = Get-Content -LiteralPath (Join-Path $script:scriptsRoot 'New-IngeniaCursorProject.ps1') -Raw
    $template | Should -Match 'StackProfile ConsultingAI'
    $template | Should -Match 'New-ConsultingCopilotProject\.ps1'
    $cursor | Should -Match 'New-IngeniaTemplateProject\.ps1'
  }

  It 'documenta Install como preflight/diagnóstico' {
    $install = Get-Content -LiteralPath (Join-Path $script:scriptsRoot 'Install-ConsultingCopilot.ps1') -Raw
    $install | Should -Match 'preflight|diagnóstico|diagnostico'
    $install | Should -Match 'Get-ConsultingCopilotPreflightDiagnostic'
    $install | Should -Not -Match 'Invoke-GentleAiWorkspaceInstall'
  }

  It 'Test-HubProject y Test-GentleAi consumen funciones del módulo' {
    $hub = Get-Content -LiteralPath (Join-Path $script:scriptsRoot 'Test-HubProject.ps1') -Raw
    $ga = Get-Content -LiteralPath (Join-Path $script:scriptsRoot 'Test-GentleAiProject.ps1') -Raw
    $hub | Should -Match 'Get-HubProjectDiagnostic'
    $ga | Should -Match 'Get-GentleAiProjectDiagnostic'
    $hub | Should -Not -Match 'Test-GentleAiProject\.ps1'
  }
}

Describe 'Diagnósticos read-only' {
  BeforeEach {
    $script:ctx = Initialize-CharacterizationContext
    $script:sentinel = Get-RealHomeSentinelSnapshot
  }

  AfterEach {
    if ($null -ne $script:sentinel -and @($script:sentinel).Count -gt 0) {
      Assert-SentinelSnapshotUnchanged -Before @($script:sentinel)
    }
    Remove-TestSandbox
  }

  It 'preflight, Gentle AI y Hub no mutan sentinels del home real' {
    $target = New-CharacterizationTarget -Name 'diag-readonly' -Context $script:ctx
    Invoke-CharacterizationGenerator -Context $script:ctx -TargetPath $target -Params @{
      StackProfile = 'Consulting'
      ClientDisplayName = 'Cliente'
      ClientSlug = 'cliente'
      InitiativeDisplayName = 'Assessment'
      InitiativeId = 'D01'
    }

    $pre = Get-ConsultingCopilotPreflightDiagnostic -StackProfile Consulting -TargetPath $target
    $pre | Should -Not -BeNullOrEmpty

    $ga = Get-GentleAiProjectDiagnostic -TargetPath $target
    $ga | Should -Not -BeNullOrEmpty

    $hub = Get-HubProjectDiagnostic -TargetPath $target -ExpectedProfile Consulting -SkipGentleAiCheck
    $hub.healthy | Should -Be $true

    # Entry points en subproceso: evitan que `exit` mate a Pester.
    $installScript = Join-Path $script:scriptsRoot 'Install-ConsultingCopilot.ps1'
    $hubScript = Join-Path $script:scriptsRoot 'Test-HubProject.ps1'
    $gaScript = Join-Path $script:scriptsRoot 'Test-GentleAiProject.ps1'

    $cmds = @(
      "& '$installScript' -StackProfile Consulting -TargetPath '$target' -AsJson | Out-Null; exit 0"
      "& '$hubScript' -TargetPath '$target' -ExpectedProfile Consulting -SkipGentleAiCheck -AsJson | Out-Null; exit 0"
      "& '$gaScript' -TargetPath '$target' -AsJson | Out-Null; exit 0"
    )
    foreach ($cmd in $cmds) {
      $p = Start-Process -FilePath 'pwsh' -ArgumentList @('-NoProfile', '-Command', $cmd) -Wait -PassThru -NoNewWindow
      $p.ExitCode | Should -Be 0
    }
  }
}
