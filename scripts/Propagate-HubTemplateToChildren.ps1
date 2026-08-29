#Requires -Version 5.1
<#
.SYNOPSIS
  Propagates hub template allowlist paths into selected child projects (opt-in).

.DESCRIPTION
  Registry v2 selection → plan via Get-HubPropagatablePaths → DryRun prints plan only.
  Apply uses hub-side git worktree/branch, re-stages with child metadata, syncs
  allowlist ∩ staging, never promotes staging, never writes the live checkout.

.EXAMPLE
  pwsh -File ./Propagate-HubTemplateToChildren.ps1 -FolderName iplan-prev-2142 -DryRun

.EXAMPLE
  pwsh -File ./Propagate-HubTemplateToChildren.ps1 -StackProfile ConsultingAI -IncludeMcpMerge
#>
[CmdletBinding()]
param(
  [string] $FolderName,

  [switch] $All,

  [ValidateSet('Consulting', 'ConsultingAI', 'GentleAi', 'Full')]
  [string] $StackProfile,

  [switch] $DryRun,

  [switch] $IncludeMcpMerge,

  [string] $BranchName
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path (Join-Path $PSScriptRoot 'lib') 'Platform.psm1') -Force
$modulePath = Resolve-HubModulePath -ScriptRoot $PSScriptRoot -ModuleName 'ConsultingCopilot'
Import-Module $modulePath -Force

$hubRoot = Get-HubProjectsIaRoot -ScriptRoot $PSScriptRoot

if (-not $All -and [string]::IsNullOrWhiteSpace($FolderName) -and [string]::IsNullOrWhiteSpace($StackProfile)) {
  throw 'Indicá -FolderName, -All o -StackProfile.'
}

if ([string]::IsNullOrWhiteSpace($BranchName)) {
  $BranchName = 'hub/propagate-{0}' -f (Get-Date -Format 'yyyyMMdd')
}

$registry = Read-HubRegistry -HubRoot $hubRoot
$selected = @()

if (-not [string]::IsNullOrWhiteSpace($FolderName)) {
  $match = @($registry.Projects | Where-Object { $_.FolderName -eq $FolderName })
  if ($match.Count -eq 0) {
    throw "No hay proyecto registrado con folderName '$FolderName'."
  }
  $selected = $match
} elseif ($All) {
  $selected = @($registry.Projects)
} else {
  $selected = @(
    $registry.Projects | Where-Object {
      $profile = if ($_.Entry -and $_.Entry.PSObject.Properties.Name -contains 'stackProfile') {
        [string]$_.Entry.stackProfile
      } else { '' }
      if ([string]::IsNullOrWhiteSpace($profile)) { return $false }
      Test-HubPropagationProfileMatch -RegistryProfile $profile -FilterProfile $StackProfile
    }
  )
}

if ($selected.Count -eq 0) {
  Write-Warning 'Ningún hijo seleccionado para propagar.'
  exit 0
}

$failures = [System.Collections.Generic.List[string]]::new()
$skips = [System.Collections.Generic.List[string]]::new()
$empties = [System.Collections.Generic.List[string]]::new()
$successes = [System.Collections.Generic.List[string]]::new()

function Get-ChildRegistryProfile {
  param($Item)
  if ($Item.Entry -and $Item.Entry.PSObject.Properties.Name -contains 'stackProfile' -and $Item.Entry.stackProfile) {
    $raw = [string]$Item.Entry.stackProfile
    switch ($raw.Trim()) {
      'consulting-ai' { return 'ConsultingAI' }
      'consulting-only' { return 'Consulting' }
      'gentle-ai-only' { return 'GentleAi' }
      'full' { return 'Full' }
      default { return $raw.Trim() }
    }
  }
  if ($Item.Exists -and $Item.ResolvedPath) {
    $fromDisk = Get-HubProjectProfileFromRoot -Root $Item.ResolvedPath
    if ($fromDisk -ne 'Unknown') { return $fromDisk }
  }
  return 'ConsultingAI'
}

function Write-PropagationPlan {
  param(
    [string] $Label,
    [string] $ChildPath,
    [object] $PlanInfo,
    [string[]] $EffectivePlan = @()
  )
  Write-Host ""
  Write-Host "=== Propagate plan: $Label ===" -ForegroundColor Cyan
  Write-Host "Child: $ChildPath"
  Write-Host "Golden: $($PlanInfo.GoldenName) | profile: $($PlanInfo.StackProfile)"
  Write-Host "Plan paths ($($EffectivePlan.Count)):"
  if ($EffectivePlan.Count -eq 0) {
    Write-Host '  (empty)'
  } else {
    foreach ($path in $EffectivePlan) { Write-Host "  - $path" }
  }
}

foreach ($item in $selected) {
  $label = if ($item.FolderName) { $item.FolderName } else { 'unknown' }
  try {
    if ($item.ResolveError) {
      Write-Warning "Skip $label : $($item.ResolveError)"
      $skips.Add($label) | Out-Null
      continue
    }
    if (-not $item.Exists -or [string]::IsNullOrWhiteSpace($item.ResolvedPath)) {
      Write-Warning "Skip $label : proyecto no encontrado en disco ($($item.ResolvedPath))"
      $skips.Add($label) | Out-Null
      continue
    }

    $childRoot = [System.IO.Path]::GetFullPath($item.ResolvedPath)
    if (-not (Test-HubChildGitUsable -ChildRoot $childRoot)) {
      Write-Warning "Skip $label : .git no usable (rev-parse). No se crea worktree ni se escribe."
      $skips.Add($label) | Out-Null
      continue
    }

    $profileForPlan = Get-ChildRegistryProfile -Item $item
    if ($profileForPlan -eq 'Full') { $profileForPlan = 'ConsultingAI' }
    if ($profileForPlan -notin @('Consulting', 'ConsultingAI', 'GentleAi')) {
      # Fall back to disk profile resolution for unexpected registry labels.
      $diskProfile = Get-HubProjectProfileFromRoot -Root $childRoot
      if ($diskProfile -eq 'Full') { $diskProfile = 'ConsultingAI' }
      if ($diskProfile -in @('Consulting', 'ConsultingAI', 'GentleAi')) {
        $profileForPlan = $diskProfile
      } else {
        throw "Perfil no soportado para propagate: $profileForPlan"
      }
    }

    $plan0 = Get-HubPropagatablePaths -HubRoot $hubRoot -StackProfile $profileForPlan

    if ($DryRun) {
      $annotated = foreach ($relative in @($plan0.Plan)) {
        $childFile = Join-Path $childRoot ($relative -replace '/', [System.IO.Path]::DirectorySeparatorChar)
        $action = if (Test-Path -LiteralPath $childFile -PathType Leaf) { 'update' } else { 'add' }
        "$action  $relative"
      }
      Write-PropagationPlan -Label $label -ChildPath $childRoot -PlanInfo $plan0 -EffectivePlan @($annotated)
      if ($plan0.Plan.Count -eq 0) {
        $empties.Add($label) | Out-Null
      } else {
        $successes.Add($label) | Out-Null
      }
      continue
    }

    if (@($plan0.Plan).Count -eq 0) {
      Write-PropagationPlan -Label $label -ChildPath $childRoot -PlanInfo $plan0 -EffectivePlan @()
      Write-Host "Plan vacío: no se crea worktree/branch para $label."
      $empties.Add($label) | Out-Null
      continue
    }

    $wt = $null
    $stagingPath = $null
    try {
      $wt = Ensure-HubPropagationWorktree `
        -HubRoot $hubRoot `
        -ChildRoot $childRoot `
        -FolderName $label `
        -BranchName $BranchName
      Write-Host "Worktree ($($wt.SafeBranch)) reused=$($wt.Reused): $($wt.WorktreePath)"

      $stagingPath = New-HubPropagationStaging -HubRoot $hubRoot -ChildRoot $childRoot
      $effectivePlan = @(Select-HubPropagationPlanPresentInStaging -StagingPath $stagingPath -Plan @($plan0.Plan))
      Write-PropagationPlan -Label $label -ChildPath $wt.WorktreePath -PlanInfo $plan0 -EffectivePlan $effectivePlan

      if ($effectivePlan.Count -eq 0) {
        Write-Host "Plan efectivo vacío tras ∩ staging: no Sync para $label."
        $empties.Add($label) | Out-Null
        continue
      }

      Sync-HubTemplatePaths `
        -StagingPath $stagingPath `
        -DestinationPath $wt.WorktreePath `
        -Plan $effectivePlan `
        -IncludeMcpMerge:$IncludeMcpMerge

      try {
        $diag = Get-HubProjectDiagnostic -TargetPath $wt.WorktreePath -ExpectedProfile Auto -SkipGentleAiCheck
        if ($diag -and $diag.PSObject.Properties.Name -contains 'healthy' -and -not $diag.healthy) {
          Write-Warning "Test-HubProject warn-only falló en worktree de $label (no marca failure)."
        }
      } catch {
        Write-Warning "Test-HubProject warn-only error en $label : $($_.Exception.Message)"
      }

      Write-Host "OK propagate apply $label → $($wt.WorktreePath) (worktree left in place)"
      $successes.Add($label) | Out-Null
    } catch {
      # Mid-apply failure after worktree add: leave WT+branch for diagnosis.
      throw
    } finally {
      Remove-ConsultingProjectStaging -StagingPath $stagingPath
    }
  } catch {
    $msg = "$label : $($_.Exception.Message)"
    Write-Warning "Failure $msg"
    $failures.Add($msg) | Out-Null
  }
}

Write-Host ''
Write-Host '=== Propagate summary ===' -ForegroundColor Green
Write-Host "Success: $($successes.Count) | Empty plan: $($empties.Count) | Skip: $($skips.Count) | Failure: $($failures.Count)"
if ($failures.Count -gt 0) {
  foreach ($f in $failures) { Write-Host "  FAIL $f" -ForegroundColor Red }
  exit 1
}

exit 0
