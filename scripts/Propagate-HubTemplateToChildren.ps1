#Requires -Version 5.1
<#
.SYNOPSIS
  Propagates hub template allowlist paths into selected child projects (opt-in).

.DESCRIPTION
  Registry v2 selection → plan via Get-HubPropagatablePaths → DryRun prints plan only
  (effective plan ∩ staging). Apply stages first, then hub-side git worktree/branch only
  when there is work (paths and/or IncludeMcpMerge), syncs allowlist ∩ staging, never
  promotes staging, never writes the live checkout.

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
} elseif ($All -and -not [string]::IsNullOrWhiteSpace($StackProfile)) {
  # -All ∩ -StackProfile: filter by profile (do not silently ignore --profile).
  $selected = @(
    $registry.Projects | Where-Object {
      $profile = if ($_.Entry -and $_.Entry.PSObject.Properties.Name -contains 'stackProfile') {
        [string]$_.Entry.stackProfile
      } else { '' }
      if ([string]::IsNullOrWhiteSpace($profile)) { return $false }
      Test-HubPropagationProfileMatch -RegistryProfile $profile -FilterProfile $StackProfile
    }
  )
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

function Get-ChildDiskProfileForPlan {
  param(
    [string] $ChildRoot,
    [string] $RegistryProfileLabel
  )
  $diskProfile = Get-HubProjectProfileFromRoot -Root $ChildRoot
  if ($diskProfile -eq 'Full') { $diskProfile = 'ConsultingAI' }
  if ($diskProfile -notin @('Consulting', 'ConsultingAI', 'GentleAi')) {
    throw "Perfil en disco no soportado para propagate: $diskProfile ($ChildRoot)"
  }
  if (-not [string]::IsNullOrWhiteSpace($RegistryProfileLabel)) {
    $regNorm = switch ($RegistryProfileLabel.Trim()) {
      'consulting-ai' { 'ConsultingAI' }
      'consulting-only' { 'Consulting' }
      'gentle-ai-only' { 'GentleAi' }
      'full' { 'ConsultingAI' }
      'Full' { 'ConsultingAI' }
      default { $RegistryProfileLabel.Trim() }
    }
    if ($regNorm -eq 'Full') { $regNorm = 'ConsultingAI' }
    if ($regNorm -ne $diskProfile -and -not (
        ($regNorm -in @('ConsultingAI', 'Full') -and $diskProfile -eq 'ConsultingAI')
      )) {
      Write-Warning "Perfil registry ($RegistryProfileLabel) ≠ disco ($diskProfile); se usa disco para plan/staging."
    }
  }
  return $diskProfile
}

function Write-PropagationPlan {
  param(
    [string] $Label,
    [string] $ChildPath,
    [object] $PlanInfo,
    [string[]] $EffectivePlan = @(),
    [string] $Note = ''
  )
  Write-Host ""
  Write-Host "=== Propagate plan: $Label ===" -ForegroundColor Cyan
  Write-Host "Child: $ChildPath"
  Write-Host "Golden: $($PlanInfo.GoldenName) | profile: $($PlanInfo.StackProfile)"
  if (-not [string]::IsNullOrWhiteSpace($Note)) {
    Write-Host $Note
  }
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

    $registryLabel = ''
    if ($item.Entry -and $item.Entry.PSObject.Properties.Name -contains 'stackProfile') {
      $registryLabel = [string]$item.Entry.stackProfile
    }
    $profileForPlan = Get-ChildDiskProfileForPlan -ChildRoot $childRoot -RegistryProfileLabel $registryLabel
    $plan0 = Get-HubPropagatablePaths -HubRoot $hubRoot -StackProfile $profileForPlan

    $stagingPath = $null
    try {
      $stagingPath = New-HubPropagationStaging -HubRoot $hubRoot -ChildRoot $childRoot
      $effectivePlan = @(Select-HubPropagationPlanPresentInStaging -StagingPath $stagingPath -Plan @($plan0.Plan))

      if ($DryRun) {
        $annotated = foreach ($relative in $effectivePlan) {
          $childFile = Join-Path $childRoot ($relative -replace '/', [System.IO.Path]::DirectorySeparatorChar)
          $action = if (Test-Path -LiteralPath $childFile -PathType Leaf) { 'update' } else { 'add' }
          "$action  $relative"
        }
        Write-PropagationPlan `
          -Label $label `
          -ChildPath $childRoot `
          -PlanInfo $plan0 `
          -EffectivePlan @($annotated) `
          -Note 'DryRun: plan efectivo ∩ staging (vs live checkout; Apply escribe worktree).'
        if ($effectivePlan.Count -eq 0 -and -not $IncludeMcpMerge) {
          $empties.Add($label) | Out-Null
        } else {
          $successes.Add($label) | Out-Null
        }
        continue
      }

      $hasWork = ($effectivePlan.Count -gt 0) -or $IncludeMcpMerge
      if (-not $hasWork) {
        Write-PropagationPlan -Label $label -ChildPath $childRoot -PlanInfo $plan0 -EffectivePlan @()
        Write-Host "Plan vacío: no se crea worktree/branch para $label."
        $empties.Add($label) | Out-Null
        continue
      }

      $wt = Ensure-HubPropagationWorktree `
        -HubRoot $hubRoot `
        -ChildRoot $childRoot `
        -FolderName $label `
        -BranchName $BranchName
      Write-Host "Worktree ($($wt.SafeBranch)) reused=$($wt.Reused): $($wt.WorktreePath)"
      Write-PropagationPlan -Label $label -ChildPath $wt.WorktreePath -PlanInfo $plan0 -EffectivePlan $effectivePlan

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
if ($successes.Count -eq 0 -and $empties.Count -eq 0 -and $skips.Count -gt 0 -and $failures.Count -eq 0) {
  Write-Warning 'Ningún hijo propagado (solo skips). Exit 0 por contrato skip≠failure / all-skip→0.'
}
if ($failures.Count -gt 0) {
  foreach ($f in $failures) { Write-Host "  FAIL $f" -ForegroundColor Red }
  exit 1
}

exit 0
