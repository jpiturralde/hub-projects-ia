#Requires -Version 5.1

BeforeAll {
  $script:testsRoot = $PSScriptRoot | Split-Path -Parent
  $script:repoRoot = Split-Path -Parent $script:testsRoot
  Import-Module (Join-Path $script:repoRoot 'scripts\lib\ConsultingCopilot.psm1') -Force
  Import-Module (Join-Path $script:testsRoot 'helpers\TestSandbox.psm1') -Force
  . (Join-Path $script:testsRoot 'helpers\CharacterizationHelpers.ps1')
  . (Join-Path $script:testsRoot 'helpers\FakeCommand.ps1')

  function New-MockGentleAiEnvironment {
    param(
      [int] $CliCount = 1,
      [bool] $GlobalInstalled = $false,
      [bool] $WorkspaceInstalled = $false
    )
    $paths = if ($CliCount -gt 0) {
      @(1..$CliCount | ForEach-Object { Join-Path $TestDrive "gentle-ai-$_.sh" })
    } else { @() }
    [pscustomobject]@{
      CliCount = $CliCount
      CliPaths = $paths
      GlobalInstalled = $GlobalInstalled
      WorkspaceInstalled = $WorkspaceInstalled
    }
  }
}

AfterAll {
  Remove-TestSandbox
}

Describe 'Resolución Gentle AI — caracterización' {
  It 'detiene global y workspace simultáneos antes de escribir' {
    $ctx = Initialize-CharacterizationContext -FakeHomeFixture 'global-gentle-ai' -WithFakeCommands -SmartGentleAi
    try {
      $target = New-CharacterizationTarget -Name 'conflict-gw' -Context $ctx
      Install-WorkspaceGentleAiMarkers -TargetPath $target
      {
        Invoke-CharacterizationGenerator -Context $ctx -TargetPath $target -Params @{
          StackProfile = 'ConsultingAI'
          GentleAiScope = 'Existing'
          ClientDisplayName = 'X'
          ClientSlug = 'x'
          InitiativeDisplayName = 'Y'
          InitiativeId = 'Z01'
          Force = $true
        }
      } | Should -Throw '*global y también en el workspace*'
    } finally {
      Remove-TestSandbox
    }
  }

  It 'detiene múltiples CLI en Resolve-GentleAiScopeDecision' {
    {
      Resolve-GentleAiScopeDecision -Environment (New-MockGentleAiEnvironment -CliCount 2) -RequestedScope Auto
    } | Should -Throw '*varias instalaciones*'
  }

  It 'marca diagnóstico no saludable con Engram duplicado en workspace' {
    $ctx = Initialize-CharacterizationContext -WithFakeCommands
    try {
      $target = New-CharacterizationTarget -Name 'dup-engram' -Context $ctx
      Write-WorkspaceEngramMcp -TargetPath $target
      $json = & $ctx.TestGentleAi -TargetPath $target -AsJson
      $result = $json | ConvertFrom-Json
      $result.healthy | Should -Be $false
      $result.issues | Should -Contain 'workspace-engram-mcp'
    } finally {
      Remove-TestSandbox
    }
  }

  It 'marca diagnóstico no saludable con múltiples CLI' {
    $ctx = Initialize-CharacterizationContext -WithFakeCommands -SmartGentleAi
    try {
      $extraBin = Join-Path $ctx.Sandbox.Root 'extra-bin'
      New-Item -ItemType Directory -Path $extraBin -Force | Out-Null
      Copy-Item -LiteralPath (Join-Path $ctx.Sandbox.FakeBinDir 'gentle-ai') -Destination (Join-Path $extraBin 'gentle-ai') -Force
      $env:PATH = "$extraBin$([System.IO.Path]::PathSeparator)$($ctx.Sandbox.FakeBinDir)$([System.IO.Path]::PathSeparator)/usr/bin$([System.IO.Path]::PathSeparator)/bin"

      $target = New-CharacterizationTarget -Name 'multi-cli-diag' -Context $ctx
      New-Item -ItemType Directory -Path $target -Force | Out-Null
      $json = & $ctx.TestGentleAi -TargetPath $target -AsJson
      $result = $json | ConvertFrom-Json
      $result.healthy | Should -Be $false
      $result.issues | Should -Contain 'multiple-gentle-ai-cli'
    } finally {
      Remove-TestSandbox
    }
  }

  It 'no modifica archivos reales durante diagnósticos' {
    $before = Get-RealHomeSentinelSnapshot
    $ctx = Initialize-CharacterizationContext -FakeHomeFixture 'global-gentle-ai' -WithFakeCommands -SmartGentleAi
    try {
      $target = New-CharacterizationTarget -Name 'diag-readonly' -Context $ctx
      New-Item -ItemType Directory -Path $target -Force | Out-Null
      & $ctx.TestGentleAi -TargetPath $target -AsJson | Out-Null
      & $ctx.InstallDiagnostic -StackProfile ConsultingAI -TargetPath $target 2>&1 | Out-Null
      Assert-SentinelSnapshotUnchanged -Before $before
    } finally {
      Remove-TestSandbox
    }
  }

  It 'cancelación por usuario no deja proyecto generado' {
    $ctx = Initialize-CharacterizationContext -FakeHomeFixture 'empty' -WithFakeCommands -SmartGentleAi
    try {
      $target = New-CharacterizationTarget -Name 'cancel-no-files' -Context $ctx
      {
        Invoke-CharacterizationGenerator -Context $ctx -TargetPath $target -Params @{
          StackProfile = 'GentleAi'
          GentleAiScope = 'Auto'
          ProjectName = 'cancel-me'
          GentleAiScopeChoice = 'X'
        }
      } | Should -Throw '*cancel*'
      Test-Path -LiteralPath $target | Should -Be $false
    } finally {
      Remove-TestSandbox
    }
  }

  It 'CLI ausente + instalación invoca go install' {
    $ctx = Initialize-CharacterizationContext -FakeHomeFixture 'empty'
    try {
      $staging = Join-Path $ctx.Sandbox.Root 'ga-staging'
      New-Item -ItemType Directory -Path $staging -Force | Out-Null
      $gaSource = New-SmartFakeGentleAi -FakeBinDir $staging -FakeHome $ctx.Sandbox.FakeHome
      $gopath = Join-Path $ctx.Sandbox.Root 'fake-gopath'
      $goBinDir = Join-Path $ctx.Sandbox.Root 'go-bin'
      New-Item -ItemType Directory -Path $goBinDir -Force | Out-Null
      New-SmartFakeGo -FakeBinDir $goBinDir -FakeHome $ctx.Sandbox.FakeHome -Gopath $gopath -GentleAiSourcePath $gaSource | Out-Null
      $env:PATH = Get-IsolatedTestPath -FakeBinDir $goBinDir

      Mock Read-ConsultingChoice { return 'I' } -ModuleName ConsultingCopilot

      $result = Ensure-GentleAiCli -Mode Auto -Choice I
      $result.Available | Should -Be $true
      $result.Path | Should -Not -BeNullOrEmpty

      $log = Get-FakeCommandLog -FakeBinDir $goBinDir
      @($log | Where-Object { $_.name -eq 'go' -and $_.argv -contains 'install' }).Count | Should -BeGreaterThan 0
    } finally {
      Remove-TestSandbox
    }
  }
}

Describe 'Fallback ConsultingAI → Consulting' {
  It 'genera consulting-only cuando el usuario elige fallback' {
    $ctx = Initialize-CharacterizationContext -FakeHomeFixture 'empty'
    try {
      $emptyBin = Join-Path $ctx.Sandbox.Root 'empty-bin'
      New-Item -ItemType Directory -Path $emptyBin -Force | Out-Null
      $env:PATH = Get-IsolatedTestPath -FakeBinDir $emptyBin

      $target = New-CharacterizationTarget -Name 'fallback-consulting' -Context $ctx
      Invoke-CharacterizationGenerator -Context $ctx -TargetPath $target -Params @{
        StackProfile = 'ConsultingAI'
        GentleAiScope = 'Auto'
        ClientDisplayName = 'Cliente'
        ClientSlug = 'cliente'
        InitiativeDisplayName = 'Ini'
        InitiativeId = 'U01'
        GentleAiCliChoice = 'C'
      }

      $meta = Get-Content (Join-Path $target '.consulting-engagement.json') -Raw | ConvertFrom-Json
      $meta.stackProfile | Should -Be 'consulting-only'
      Test-Path (Join-Path $target '.cursor\agents\cdd-explore.md') | Should -Be $false
    } finally {
      Remove-TestSandbox
    }
  }
}
