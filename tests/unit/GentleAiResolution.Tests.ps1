#Requires -Version 5.1

BeforeAll {
  $script:testsRoot = $PSScriptRoot | Split-Path -Parent
  $script:repoRoot = Split-Path -Parent $script:testsRoot
  $gentleModule = Join-Path (Join-Path (Join-Path $script:repoRoot 'scripts') 'lib') 'GentleAi.psm1'
  Import-Module $gentleModule -Force

  function New-Env {
    param(
      [int] $CliCount = 1,
      [string] $CliStatus = 'Ok',
      [bool] $GlobalInstalled = $false,
      [bool] $WorkspaceInstalled = $false,
      [string] $CliMessage = $null
    )
    $paths = if ($CliCount -gt 0) { @(1..$CliCount | ForEach-Object { "/usr/local/bin/gentle-ai-$_" }) } else { @() }
    [pscustomobject]@{
      CliCount = $CliCount
      CliPaths = $paths
      CliStatus = $CliStatus
      CliMessage = $CliMessage
      GlobalInstalled = $GlobalInstalled
      WorkspaceInstalled = $WorkspaceInstalled
    }
  }
}

Describe 'Resolve-GentleAiScopeDecision matrix' {
  It 'reutiliza global cuando existe' {
    $d = Resolve-GentleAiScopeDecision -Environment (New-Env -GlobalInstalled $true) -RequestedScope Auto
    $d.Action | Should -Be 'Reuse'
    $d.Scope | Should -Be 'Global'
  }

  It 'reutiliza workspace cuando no hay global' {
    $d = Resolve-GentleAiScopeDecision -Environment (New-Env -WorkspaceInstalled $true) -RequestedScope Auto
    $d.Action | Should -Be 'Reuse'
    $d.Scope | Should -Be 'Workspace'
  }

  It 'instala global con Choice G' {
    $d = Resolve-GentleAiScopeDecision -Environment (New-Env) -RequestedScope Auto -Choice G
    $d.Action | Should -Be 'Install'
    $d.Scope | Should -Be 'Global'
  }

  It 'instala workspace con Choice P' {
    $d = Resolve-GentleAiScopeDecision -Environment (New-Env) -RequestedScope Auto -Choice P
    $d.Action | Should -Be 'Install'
    $d.Scope | Should -Be 'Workspace'
  }

  It 'cancela con Choice X' {
    $d = Resolve-GentleAiScopeDecision -Environment (New-Env) -RequestedScope Auto -Choice X
    $d.Status | Should -Be 'Cancelled'
    $d.Action | Should -Be 'Cancel'
  }

  It 'falla ante global+workspace' {
    {
      Resolve-GentleAiScopeDecision -Environment (New-Env -GlobalInstalled $true -WorkspaceInstalled $true) -RequestedScope Auto
    } | Should -Throw '*global y también en el workspace*'
  }

  It 'falla ante CLI duplicado' {
    {
      Resolve-GentleAiScopeDecision -Environment (New-Env -CliCount 2 -CliStatus Duplicate) -RequestedScope Auto
    } | Should -Throw '*varias instalaciones*'
  }

  It 'rechaza CLI Windows en WSL' {
    {
      Resolve-GentleAiScopeDecision -Environment (New-Env -CliCount 0 -CliStatus WindowsOriginRejected -CliMessage 'binario Windows') -RequestedScope Auto
    } | Should -Throw '*Windows*'
  }

  It 'bloquea Workspace si ya hay global' {
    {
      Resolve-GentleAiScopeDecision -Environment (New-Env -GlobalInstalled $true) -RequestedScope Workspace
    } | Should -Throw '*No se permite Gentle AI local*'
  }
}

Describe 'Ensure-GentleAiCli choices' {
  It 'devuelve FallbackConsulting con Choice C' {
    Mock Resolve-GentleAiCliStatus {
      [pscustomobject]@{ Status = 'Missing'; Path = $null; Paths = @(); RejectedPaths = @(); Message = 'missing' }
    } -ModuleName GentleAi
    $r = Ensure-GentleAiCli -Mode Auto -AllowConsultingFallback -Choice C
    $r.FallbackToConsulting | Should -Be $true
    $r.Status | Should -Be 'FallbackConsulting'
  }

  It 'cancela con Choice X' {
    Mock Resolve-GentleAiCliStatus {
      [pscustomobject]@{ Status = 'Missing'; Path = $null; Paths = @(); RejectedPaths = @(); Message = 'missing' }
    } -ModuleName GentleAi
    $r = Ensure-GentleAiCli -Mode Auto -Choice X
    $r.Status | Should -Be 'Cancelled'
  }

  It 'rechaza WindowsOriginRejected' {
    Mock Resolve-GentleAiCliStatus {
      [pscustomobject]@{
        Status = 'WindowsOriginRejected'
        Path = $null
        Paths = @()
        RejectedPaths = @('/mnt/c/tools/gentle-ai.exe')
        Message = 'gentle-ai Windows inválido'
      }
    } -ModuleName GentleAi
    { Ensure-GentleAiCli -Mode Auto -Choice I } | Should -Throw '*Windows*'
  }
}

Describe 'Get-GentleAiEngramStatus' {
  It 'marca WorkspaceDuplicate sin reparar' {
    $s = Get-GentleAiEngramStatus -GlobalConfigured $true -WorkspaceConfigured $true
    $s.Status | Should -Be 'WorkspaceDuplicate'
  }

  It 'informa Missing cuando no hay Engram global' {
    $s = Get-GentleAiEngramStatus -GlobalConfigured $false -WorkspaceConfigured $false
    $s.Status | Should -Be 'Missing'
    $s.Message | Should -Match 'No se repara'
  }

  It 'Configured cuando solo global' {
    $s = Get-GentleAiEngramStatus -GlobalConfigured $true -WorkspaceConfigured $false
    $s.Status | Should -Be 'Configured'
  }
}

Describe 'Resolve-GentleAiCliStatus' {
  It 'clasifica Missing sin rutas' {
    $s = Resolve-GentleAiCliStatus -RawPaths @()
    $s.Status | Should -Be 'Missing'
  }

  It 'clasifica Duplicate con dos rutas nativas' {
    Mock Test-HubCommandAllowedOnPlatform { $true } -ModuleName GentleAi
    $s = Resolve-GentleAiCliStatus -RawPaths @('/usr/bin/gentle-ai', '/usr/local/bin/gentle-ai')
    $s.Status | Should -Be 'Duplicate'
  }

  It 'clasifica WindowsOriginRejected cuando sólo hay .exe' {
    Mock Test-HubCommandAllowedOnPlatform { $false } -ModuleName GentleAi
    $s = Resolve-GentleAiCliStatus -RawPaths @('/mnt/c/tools/gentle-ai.exe')
    $s.Status | Should -Be 'WindowsOriginRejected'
  }
}
