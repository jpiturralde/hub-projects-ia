#Requires -Version 5.1

BeforeAll {
  $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
  Import-Module (Join-Path $repoRoot 'scripts\lib\ConsultingCopilot.psm1') -Force

  function New-TestEnvironment {
    param(
      [int] $CliCount = 1,
      [bool] $GlobalInstalled = $false,
      [bool] $WorkspaceInstalled = $false
    )
    $paths = if ($CliCount -gt 0) { @(1..$CliCount | ForEach-Object { "C:\tools\gentle-ai-$_.exe" }) } else { @() }
    [pscustomobject]@{
      CliCount = $CliCount
      CliPaths = $paths
      GlobalInstalled = $GlobalInstalled
      WorkspaceInstalled = $WorkspaceInstalled
    }
  }
}

Describe 'Resolución de alcance Gentle AI' {
  It 'reutiliza global automáticamente' {
    $decision = Resolve-GentleAiScopeDecision -Environment (New-TestEnvironment -GlobalInstalled $true) -RequestedScope Auto
    $decision.Action | Should -Be 'Reuse'
    $decision.Scope | Should -Be 'Global'
  }

  It 'nunca ofrece ni permite workspace si ya existe global' {
    { Resolve-GentleAiScopeDecision -Environment (New-TestEnvironment -GlobalInstalled $true) -RequestedScope Workspace } |
      Should -Throw '*No se permite Gentle AI local*'
  }

  It 'permite workspace sólo cuando no existe global' {
    $decision = Resolve-GentleAiScopeDecision -Environment (New-TestEnvironment) -RequestedScope Workspace
    $decision.Action | Should -Be 'Install'
    $decision.Scope | Should -Be 'Workspace'
  }

  It 'detiene global más workspace' {
    { Resolve-GentleAiScopeDecision -Environment (New-TestEnvironment -GlobalInstalled $true -WorkspaceInstalled $true) -RequestedScope Auto } |
      Should -Throw '*global y también en el workspace*'
  }

  It 'detiene múltiples ejecutables' {
    { Resolve-GentleAiScopeDecision -Environment (New-TestEnvironment -CliCount 2) -RequestedScope Auto } |
      Should -Throw '*varias instalaciones*'
  }

  It 'Existing no instala cuando no existe configuración' {
    { Resolve-GentleAiScopeDecision -Environment (New-TestEnvironment) -RequestedScope Existing } |
      Should -Throw '*No se encontró*'
  }
}

Describe 'Integridad del template' {
  It 'no conserva el instalador workspace anterior' {
    $allScripts = Get-ChildItem (Join-Path $repoRoot 'scripts') -Recurse -File | Get-Content -Raw
    $allScripts | Should -Not -Match 'Invoke-GentleAiWorkspaceInstall'
  }

  It 'no incluye judgment-day local ni nombres que sombrean skills globales conocidas' {
    Test-Path (Join-Path $repoRoot 'overlays\full\.cursor\skills\judgment-day') | Should -BeFalse
    Test-Path (Join-Path $repoRoot 'skeleton\.cursor\skills\draft-client-deliverable') | Should -BeFalse
    Test-Path (Join-Path $repoRoot 'skeleton\.cursor\skills\code-technical-analysis') | Should -BeFalse
  }

  It 'no fija modelos en agentes CDD' {
    $agents = Get-ChildItem (Join-Path $repoRoot 'overlays\full\.cursor\agents') -Filter '*.md' -File | Get-Content -Raw
    $agents | Should -Not -Match '(?m)^model:\s*(sonnet|opus|haiku)\s*$'
  }

  It 'limita alwaysApply al router y presupuesto de contexto' {
    $allowed = @('consulting-copilot.mdc', 'context-budget.mdc')
    $rules = @(
      Get-ChildItem (Join-Path $repoRoot 'skeleton\.cursor\rules') -Filter '*.mdc' -File
      Get-ChildItem (Join-Path $repoRoot 'overlays') -Recurse -Filter '*.mdc' -File
    )
    $unexpected = @($rules | Where-Object {
      (Get-Content $_.FullName -Raw) -match '(?m)^alwaysApply:\s*true\s*$' -and $_.Name -notin $allowed
    })
    $unexpected | Should -BeNullOrEmpty
  }

  It 'genera perfil Consulting sin Gentle AI ni Engram local' {
    $target = Join-Path $TestDrive 'consulting-project'
    & (Join-Path $repoRoot 'scripts\New-ConsultingCopilotProject.ps1') `
      -TargetPath $target -StackProfile Consulting `
      -ClientDisplayName 'Cliente' -ClientSlug 'cliente' `
      -InitiativeDisplayName 'Assessment' -InitiativeId 'A01' `
      -IncludeDrawioMcp:$false -IncludeBacklogMcp:$false -IncludeArchiMcp:$false `
      -IncludeClaudeCoworkLayer:$false -SkipHandoffSummary

    Test-Path (Join-Path $target 'PROJECT-CONTEXT.md') | Should -BeTrue
    Test-Path (Join-Path $target '.cursor\rules\context-budget.mdc') | Should -BeTrue
    Test-Path (Join-Path $target '.cursor\rules\gentle-ai.mdc') | Should -BeFalse
    $mcp = Get-Content (Join-Path $target '.cursor\mcp.json') -Raw | ConvertFrom-Json
    $mcp.mcpServers.PSObject.Properties.Name | Should -Not -Contain 'engram'
    $gettingStarted = Get-Content (Join-Path $target 'docs\GETTING-STARTED.md') -Raw
    $gettingStarted | Should -Not -Match '[A-Za-z]:\\'
    $gettingStarted | Should -Not -Match 'hub-projects-ia|ingenia-hub-ia'
    $gettingStarted | Should -Match 'hub generador padre'
  }
}
