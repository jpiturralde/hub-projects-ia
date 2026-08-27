#Requires -Version 5.1

BeforeAll {
  $script:repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
  $script:modulePath = Join-Path $script:repoRoot 'scripts\lib\ConsultingCopilot.psm1'
  $script:sandboxModulePath = Join-Path $PSScriptRoot '..\helpers\TestSandbox.psm1'

  Import-Module $script:modulePath -Force
  Import-Module $script:sandboxModulePath -Force
  . (Join-Path $PSScriptRoot '..\helpers\FakeCommand.ps1')
  . (Join-Path $PSScriptRoot '..\helpers\TestProjectFactory.ps1')
}

AfterAll {
  Remove-TestSandbox
}

Describe 'TestSandbox harness' {
  Context 'Entorno aislado vacío' {
    BeforeEach {
      $script:sandbox = Initialize-TestSandbox -WithFakeCommands -PesterTestDrive $TestDrive
    }

    AfterEach {
      Remove-TestSandbox
    }

    It 'redirige HOME y HUB_PROJECTS_IA_ROOT al sandbox' {
      $script:sandbox.FakeHome | Should -Be $env:HOME
      $script:sandbox.FakeHome | Should -Be $env:TEST_USER_HOME
      $script:sandbox.FakeHubRoot | Should -Be $env:HUB_PROJECTS_IA_ROOT
    }

    It 'resuelve la raíz del hub desde HUB_PROJECTS_IA_ROOT' {
      $hubRoot = Get-HubProjectsIaRoot -ScriptRoot (Join-Path $script:repoRoot 'scripts')
      $hubRoot | Should -Be $script:sandbox.FakeHubRoot
    }

    It 'detecta un único gentle-ai fake en PATH' {
      $env = Get-GentleAiEnvironment -TargetPath (New-TestProjectDirectory -ParentPath $script:sandbox.FakeHubRoot -FolderName 'tmp-detect')
      $env.CliCount | Should -Be 1
      $env.CliPath | Should -BeLike "$($script:sandbox.FakeBinDir)*"
      $env.GlobalInstalled | Should -Be $false
    }

    It 'registra invocaciones del ejecutable fake' {
      $cli = Join-Path $script:sandbox.FakeBinDir 'gentle-ai'
      if ($IsWindows -or ($env:OS -eq 'Windows_NT')) {
        $cli = Join-Path $script:sandbox.FakeBinDir 'gentle-ai.cmd'
      }
      Test-Path -LiteralPath $cli | Should -Be $true

      & $cli install --agent cursor --scope global --component engram,sdd,skills
      $LASTEXITCODE | Should -Be 0

      $log = Get-FakeCommandLog -FakeBinDir $script:sandbox.FakeBinDir
      $log.Count | Should -BeGreaterThan 0
      $log[0].name | Should -Be 'gentle-ai'
      $log[0].argv | Should -Contain 'install'
    }

    It 'no modifica archivos reales del usuario' {
      Assert-RealHomeUnchanged
      Assert-NoWriteOutsideSandbox
    }
  }

  Context 'Fixture global-gentle-ai' {
    BeforeEach {
      $script:sandbox = Initialize-TestSandbox -FakeHomeFixture 'global-gentle-ai' -WithFakeCommands -PesterTestDrive $TestDrive
    }

    AfterEach {
      Remove-TestSandbox
    }

    It 'detecta Gentle AI global en fake-home sin tocar el entorno real' {
      $target = New-TestProjectDirectory -ParentPath $script:sandbox.FakeHubRoot -FolderName 'tmp-global'
      $env = Get-GentleAiEnvironment -TargetPath $target
      $env.GlobalInstalled | Should -Be $true
      $env.GlobalEngramConfigured | Should -Be $true
      $env.WorkspaceInstalled | Should -Be $false
    }

    It 'reutiliza global automáticamente en Resolve-GentleAiScopeDecision' {
      $target = New-TestProjectDirectory -ParentPath $script:sandbox.FakeHubRoot -FolderName 'tmp-scope'
      $environment = Get-GentleAiEnvironment -TargetPath $target
      $decision = Resolve-GentleAiScopeDecision -Environment $environment -RequestedScope Auto
      $decision.Action | Should -Be 'Reuse'
      $decision.Scope | Should -Be 'Global'
    }
  }
}

Describe 'TestSandbox smoke desde cualquier directorio' {
  It 'ejecuta Initialize-TestSandbox fuera de la raíz del repo' {
    $previous = Get-Location
    try {
      Set-Location $env:TEMP
      $sandbox = Initialize-TestSandbox -WithFakeCommands -PesterTestDrive $TestDrive
      $sandbox.Root | Should -Not -BeNullOrEmpty
      Get-HubProjectsIaRoot -ScriptRoot (Join-Path $script:repoRoot 'scripts') | Should -Be $sandbox.FakeHubRoot
    } finally {
      Remove-TestSandbox
      Set-Location $previous
    }
  }
}
