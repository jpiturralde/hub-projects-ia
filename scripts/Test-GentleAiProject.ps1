#Requires -Version 5.1
<#
.SYNOPSIS
  Diagnóstico read-only de duplicación Gentle AI/Engram y configuración del template.

.DESCRIPTION
  No elimina ni reescribe archivos administrados. Devuelve código 2 si encuentra
  un conflicto que debería resolverse antes de regenerar o migrar el proyecto.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string] $TargetPath,
  [switch] $AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'lib\ConsultingCopilot.psm1') -Force

$TargetPath = [System.IO.Path]::GetFullPath($TargetPath)
if (-not (Test-Path -LiteralPath $TargetPath -PathType Container)) { throw "Proyecto no encontrado: $TargetPath" }

$environment = Get-GentleAiEnvironment -TargetPath $TargetPath
$localSkillsRoot = Join-Path $TargetPath '.cursor\skills'
$globalSkillsRoot = Join-Path ([Environment]::GetFolderPath('UserProfile')) '.cursor\skills'
$skillCollisionExclude = @('_shared')
$collisions = @()
if ((Test-Path -LiteralPath $localSkillsRoot) -and (Test-Path -LiteralPath $globalSkillsRoot)) {
  $localNames = @(Get-ChildItem -LiteralPath $localSkillsRoot -Directory -Force | ForEach-Object { $_.Name })
  $globalNames = @(Get-ChildItem -LiteralPath $globalSkillsRoot -Directory -Force | ForEach-Object { $_.Name })
  $collisions = @($localNames | Where-Object {
    $_ -notin $skillCollisionExclude -and ($globalNames -contains $_)
  } | Sort-Object -Unique)
}

$alwaysApply = @()
$rulesRoot = Join-Path $TargetPath '.cursor\rules'
if (Test-Path -LiteralPath $rulesRoot) {
  Get-ChildItem -LiteralPath $rulesRoot -Filter '*.mdc' -File -Force | ForEach-Object {
    if ((Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8) -match '(?m)^alwaysApply:\s*true\s*$') {
      $alwaysApply += $_.Name
    }
  }
}

$issues = @()
if ($environment.CliCount -gt 1) { $issues += 'multiple-gentle-ai-cli' }
if ($environment.GlobalInstalled -and $environment.WorkspaceInstalled) { $issues += 'global-workspace-duplicate' }
if ($environment.WorkspaceEngramConfigured) { $issues += 'workspace-engram-mcp' }
if ($collisions.Count -gt 0) { $issues += 'local-global-skill-collision' }
if (@($alwaysApply | Where-Object { $_ -notin @('consulting-copilot.mdc', 'context-budget.mdc') }).Count -gt 0) {
  $issues += 'excessive-always-apply-rules'
}

$result = [ordered]@{
  targetPath = $TargetPath
  cliPaths = $environment.CliPaths
  globalGentleAi = $environment.GlobalInstalled
  workspaceGentleAi = $environment.WorkspaceInstalled
  globalEngramMcp = $environment.GlobalEngramConfigured
  workspaceEngramMcp = $environment.WorkspaceEngramConfigured
  skillCollisions = $collisions
  alwaysApplyRules = $alwaysApply
  issues = $issues
  healthy = $issues.Count -eq 0
  remediation = @(
    'No edites ni borres manualmente archivos administrados por Gentle AI.',
    'Usá gentle-ai doctor como primer diagnóstico.',
    'Si actualizaste el binario, usá gentle-ai sync.',
    'Revisá el dry-run del instalador antes de cualquier cambio de alcance.'
  )
}

if ($AsJson) {
  $result | ConvertTo-Json -Depth 6
} else {
  Write-Host "Proyecto: $TargetPath"
  Write-Host "Gentle AI global: $($result.globalGentleAi) | workspace: $($result.workspaceGentleAi)"
  Write-Host "Engram MCP global: $($result.globalEngramMcp) | workspace: $($result.workspaceEngramMcp)"
  Write-Host "CLI: $($result.cliPaths -join '; ')"
  Write-Host "Skills local/global repetidas: $($result.skillCollisions -join ', ')"
  Write-Host "Reglas alwaysApply: $($result.alwaysApplyRules -join ', ')"
  if ($result.healthy) { Write-Host 'Resultado: OK' -ForegroundColor Green }
  else { Write-Host "Resultado: revisar $($result.issues -join ', ')" -ForegroundColor Yellow }
}

if (-not $result.healthy) { exit 2 }
