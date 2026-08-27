#Requires -Version 5.1

BeforeAll {
  $script:testsRoot = $PSScriptRoot | Split-Path -Parent
  $script:repoRoot = Split-Path -Parent $script:testsRoot
  Import-Module (Join-Path $script:repoRoot 'scripts\lib\ConsultingCopilot.psm1') -Force
  Import-Module (Join-Path $script:testsRoot 'helpers\TestSandbox.psm1') -Force
}

AfterAll {
  Remove-TestSandbox
}

Describe 'Project staging' {
  BeforeEach {
    $script:sandbox = Initialize-TestSandbox -PesterTestDrive $TestDrive
  }

  AfterEach {
    Remove-TestSandbox
  }

  It 'promueve staging al destino final y elimina el directorio temporal' {
    $finalPath = Join-Path $script:sandbox.Root 'promoted-project'
    $stagingPath = New-ConsultingProjectStagingPath
    Register-TestSandboxWrite -Path $stagingPath
    Register-TestSandboxWrite -Path $finalPath
    Set-Content -LiteralPath (Join-Path $stagingPath 'marker.txt') -Value 'ok' -Encoding UTF8

    Promote-ConsultingProjectStaging -StagingPath $stagingPath -TargetPath $finalPath | Should -Be $finalPath
    Test-Path -LiteralPath $stagingPath | Should -Be $false
    (Get-Content -LiteralPath (Join-Path $finalPath 'marker.txt') -Raw).Trim() | Should -Be 'ok'
  }

  It 'limpia staging cuando falla la promoción' {
    $stagingPath = New-ConsultingProjectStagingPath
    Register-TestSandboxWrite -Path $stagingPath
    Set-Content -LiteralPath (Join-Path $stagingPath 'marker.txt') -Value 'fail' -Encoding UTF8

    { Promote-ConsultingProjectStaging -StagingPath $stagingPath -TargetPath '' } | Should -Throw
    Remove-ConsultingProjectStaging -StagingPath $stagingPath
    Test-Path -LiteralPath $stagingPath | Should -Be $false
  }
}

Describe 'Copy-ProjectOnboardingLayer' {
  BeforeEach {
    $script:sandbox = Initialize-TestSandbox -PesterTestDrive $TestDrive
    $script:sourceRoot = $script:repoRoot
    $script:targetPath = Join-Path $script:sandbox.Root 'onboarding-target'
    Register-TestSandboxWrite -Path $script:targetPath
    New-Item -ItemType Directory -Path $script:targetPath -Force | Out-Null
  }

  AfterEach {
    Remove-TestSandbox
  }

  It 'copia el skill onboarding sin wildcard LiteralPath' {
    Copy-ProjectOnboardingLayer -SourceRoot $script:sourceRoot -TargetPath $script:targetPath
    $skillPath = Join-Path $script:targetPath '.cursor\skills\onboarding\SKILL.md'
    Test-Path -LiteralPath $skillPath | Should -Be $true
  }
}
