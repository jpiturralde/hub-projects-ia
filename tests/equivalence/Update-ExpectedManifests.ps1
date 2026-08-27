#Requires -Version 5.1
<#
.SYNOPSIS
  Regenera tests/expected/*/manifest.json desde generaciones aisladas.

.DESCRIPTION
  Solo para mantenimiento de la suite de equivalencia. No toca HOME real.
#>
[CmdletBinding()]
param(
  [string] $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $RepoRoot 'scripts\lib\ConsultingCopilot.psm1') -Force
Import-Module (Join-Path $RepoRoot 'tests\helpers\TestSandbox.psm1') -Force
. (Join-Path $RepoRoot 'tests\helpers\CharacterizationHelpers.ps1')

$expectedRoot = Join-Path $RepoRoot 'tests\expected'
$profiles = @(
  @{
    Name = 'consulting'
    Profile = 'Consulting'
    Fixture = 'empty'
    Smart = $false
    Params = @{
      StackProfile = 'Consulting'
      ClientDisplayName = 'Equiv'
      ClientSlug = 'equiv'
      InitiativeDisplayName = 'Encargo'
      InitiativeId = 'EQV01'
    }
  }
  @{
    Name = 'consulting-ai'
    Profile = 'ConsultingAI'
    Fixture = 'global-gentle-ai'
    Smart = $true
    Params = @{
      StackProfile = 'ConsultingAI'
      GentleAiScope = 'Existing'
      ClientDisplayName = 'Equiv'
      ClientSlug = 'equiv'
      InitiativeDisplayName = 'Encargo'
      InitiativeId = 'EQV01'
    }
  }
  @{
    Name = 'full'
    Profile = 'Full'
    Fixture = 'global-gentle-ai'
    Smart = $true
    Params = @{
      StackProfile = 'Full'
      GentleAiScope = 'Existing'
      ClientDisplayName = 'Equiv'
      ClientSlug = 'equiv'
      InitiativeDisplayName = 'Encargo'
      InitiativeId = 'EQV01'
    }
  }
  @{
    Name = 'gentle-ai'
    Profile = 'GentleAi'
    Fixture = 'global-gentle-ai'
    Smart = $true
    Params = @{
      StackProfile = 'GentleAi'
      GentleAiScope = 'Existing'
      ProjectName = 'equiv-app'
    }
  }
)

try {
  foreach ($item in $profiles) {
    $ctx = Initialize-CharacterizationContext -FakeHomeFixture $item.Fixture -WithFakeCommands -SmartGentleAi:$item.Smart
    $target = New-CharacterizationTarget -Name ("expected-$($item.Name)") -Context $ctx
    Invoke-CharacterizationGenerator -Context $ctx -TargetPath $target -Params $item.Params | Out-Null
    $snap = Get-EquivalenceProjectSnapshot -ProjectRoot $target -ExpectedProfile $item.Profile
    $out = Join-Path $expectedRoot "$($item.Name)\manifest.json"
    Export-EquivalenceExpectedContract -Snapshot $snap -OutputPath $out | Out-Null
    Write-Host "OK $out ($($snap.files.Count) files)"
    Remove-TestSandbox
  }
} finally {
  Remove-TestSandbox
}
