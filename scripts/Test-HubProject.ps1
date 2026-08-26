#Requires -Version 5.1
<#
.SYNOPSIS
  Smoke test unificado de un proyecto hijo generado desde hub-projects-ia.

.DESCRIPTION
  Punto de entrada canónico tras New-HubProject.ps1. Valida estructura, metadata,
  MCP y marcadores por perfil (Consulting, ConsultingAI, GentleAi). Para
  ConsultingAI y GentleAi delega en Test-GentleAiProject.ps1.

  Exit 0 = OK | Exit 2 = fallos detectados

.EXAMPLE
  .\Test-HubProject.ps1 -TargetPath "..\projects\smokeai-smk02" -ExpectedProfile ConsultingAI
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string] $TargetPath,

  [ValidateSet('Consulting', 'ConsultingAI', 'GentleAi', 'Auto')]
  [string] $ExpectedProfile = 'Auto',

  [switch] $AsJson,
  [switch] $SkipGentleAiCheck
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$modulePath = Join-Path $PSScriptRoot 'lib\ConsultingCopilot.psm1'
Import-Module $modulePath -Force

$TargetPath = [System.IO.Path]::GetFullPath($TargetPath)
if (-not (Test-Path -LiteralPath $TargetPath -PathType Container)) {
  throw "Proyecto no encontrado: $TargetPath"
}

function Test-PathExists {
  param([string] $Path, [string] $Label)
  if (-not (Test-Path -LiteralPath $Path)) {
    return "missing-$Label"
  }
  return $null
}

function Test-PathAbsent {
  param([string] $Path, [string] $Label)
  if (Test-Path -LiteralPath $Path) {
    return "unexpected-$Label"
  }
  return $null
}

function Get-HubProjectProfile {
  param([string] $Root)
  $projectProfile = Join-Path $Root '.project-profile.json'
  $engagementMeta = Join-Path $Root '.consulting-engagement.json'

  if (Test-Path -LiteralPath $projectProfile) {
    $meta = Get-Content -LiteralPath $projectProfile -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($meta.stackProfile -eq 'gentle-ai-only') { return 'GentleAi' }
  }

  if (Test-Path -LiteralPath $engagementMeta) {
    $meta = Get-Content -LiteralPath $engagementMeta -Raw -Encoding UTF8 | ConvertFrom-Json
    switch ($meta.stackProfile) {
      'consulting-only' { return 'Consulting' }
      'consulting-ai' { return 'ConsultingAI' }
      default { return [string]$meta.stackProfile }
    }
  }

  return 'Unknown'
}

function Test-HubProfileUsesGentleAi {
  param([string] $Profile)
  return $Profile -in @('ConsultingAI', 'GentleAi')
}

function Get-McpServerNames {
  param([string] $McpJsonPath)
  if (-not (Test-Path -LiteralPath $McpJsonPath -PathType Leaf)) { return @() }
  $config = Get-Content -LiteralPath $McpJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
  if (-not $config.mcpServers) { return @() }
  return @($config.mcpServers.PSObject.Properties.Name)
}

function Test-HubCommonChecks {
  param([string] $Root)
  $issues = @()

  try {
    Test-ConsultingPlaceholders -TargetPath $Root
  } catch {
    $issues += 'unresolved-placeholders'
  }

  foreach ($pair in @(
    @{ Path = (Join-Path $Root 'docs\GETTING-STARTED.md'); Label = 'getting-started' }
    @{ Path = (Join-Path $Root 'PROJECT-CONTEXT.md'); Label = 'project-context' }
  )) {
    $issue = Test-PathExists -Path $pair.Path -Label $pair.Label
    if ($issue) { $issues += $issue }
  }

  return $issues
}

function Test-HubConsultingBaseChecks {
  param(
    [string] $Root,
    [object] $EngagementMeta
  )
  $issues = @()
  $mcpPath = Join-Path $Root '.cursor\mcp.json'

  foreach ($pair in @(
    @{ Path = (Join-Path $Root '.cursor\rules\consulting-copilot.mdc'); Label = 'consulting-copilot-rule' }
    @{ Path = (Join-Path $Root '.atl\stack-profile.json'); Label = 'stack-profile-config' }
    @{ Path = $mcpPath; Label = 'mcp-json' }
  )) {
    $issue = Test-PathExists -Path $pair.Path -Label $pair.Label
    if ($issue) { $issues += $issue }
  }

  $issue = Test-PathAbsent -Path (Join-Path $Root '.cursor\rules\gentle-ai.mdc') -Label 'gentle-ai-rule'
  if ($issue) { $issues += $issue }

  $servers = Get-McpServerNames -McpJsonPath $mcpPath
  if ($EngagementMeta.includeDrawioMcp -and 'drawio' -notin $servers) { $issues += 'missing-mcp-drawio' }
  if ($EngagementMeta.includeBacklogMcp -and 'backlog' -notin $servers) { $issues += 'missing-mcp-backlog' }
  if ($EngagementMeta.includeArchiMcp -and 'archi' -notin $servers) { $issues += 'missing-mcp-archi' }
  if ('engram' -in $servers) { $issues += 'workspace-engram-mcp' }

  return $issues
}

function Test-HubConsultingChecks {
  param(
    [string] $Root,
    [object] $EngagementMeta
  )
  $issues = Test-HubConsultingBaseChecks -Root $Root -EngagementMeta $EngagementMeta

  if ($EngagementMeta.stackProfile -ne 'consulting-only') {
    $issues += 'wrong-stack-profile'
  }

  $issue = Test-PathAbsent -Path (Join-Path $Root '.cursor\agents\cdd-explore.md') -Label 'cdd-overlay'
  if ($issue) { $issues += $issue }

  return $issues
}

function Test-HubConsultingAiChecks {
  param(
    [string] $Root,
    [object] $EngagementMeta
  )
  $issues = Test-HubConsultingBaseChecks -Root $Root -EngagementMeta $EngagementMeta

  if ($EngagementMeta.stackProfile -ne 'consulting-ai') {
    $issues += 'wrong-stack-profile'
  }

  foreach ($pair in @(
    @{ Path = (Join-Path $Root '.cursor\agents\cdd-explore.md'); Label = 'cdd-explore-agent' }
    @{ Path = (Join-Path $Root '.cursor\rules\gentle-ai-consulting.mdc'); Label = 'gentle-ai-consulting-rule' }
    @{ Path = (Join-Path $Root '.cursor\skills\consulting-driven-delivery\SKILL.md'); Label = 'cdd-skill' }
  )) {
    $issue = Test-PathExists -Path $pair.Path -Label $pair.Label
    if ($issue) { $issues += $issue }
  }

  if ($EngagementMeta.engramMcpSource -ne 'gentle-ai-managed') {
    $issues += 'unexpected-engram-source'
  }

  return $issues
}

function Test-HubGentleAiChecks {
  param(
    [string] $Root,
    [object] $ProjectMeta
  )
  $issues = @()
  $mcpPath = Join-Path $Root '.cursor\mcp.json'

  if ($ProjectMeta.stackProfile -ne 'gentle-ai-only') {
    $issues += 'wrong-stack-profile'
  }

  foreach ($pair in @(
    @{ Path = (Join-Path $Root '.cursor\skills\onboarding\SKILL.md'); Label = 'onboarding-skill' }
    @{ Path = (Join-Path $Root 'README.md'); Label = 'readme' }
  )) {
    $issue = Test-PathExists -Path $pair.Path -Label $pair.Label
    if ($issue) { $issues += $issue }
  }

  foreach ($pair in @(
    @{ Path = (Join-Path $Root '.consulting-engagement.json'); Label = 'consulting-engagement' }
    @{ Path = (Join-Path $Root '.cursor\rules\consulting-copilot.mdc'); Label = 'consulting-copilot-rule' }
    @{ Path = (Join-Path $Root '.cursor\agents\cdd-explore.md'); Label = 'cdd-overlay' }
  )) {
    $issue = Test-PathAbsent -Path $pair.Path -Label $pair.Label
    if ($issue) { $issues += $issue }
  }

  if (Test-Path -LiteralPath $mcpPath) {
    $servers = Get-McpServerNames -McpJsonPath $mcpPath
    if ('engram' -in $servers) { $issues += 'workspace-engram-mcp' }
  }

  return $issues
}

function Invoke-HubGentleAiProjectCheck {
  param([string] $Root)
  $gentleScript = Join-Path $PSScriptRoot 'Test-GentleAiProject.ps1'
  if (-not (Test-Path -LiteralPath $gentleScript)) {
    throw "No se encuentra Test-GentleAiProject.ps1 en: $gentleScript"
  }
  $gentleJson = & $gentleScript -TargetPath $Root -AsJson
  if ([string]::IsNullOrWhiteSpace($gentleJson)) {
    throw 'Test-GentleAiProject.ps1 no devolvió salida JSON.'
  }
  return ($gentleJson | ConvertFrom-Json)
}

$profile = Get-HubProjectProfile -Root $TargetPath
$structureIssues = Test-HubCommonChecks -Root $TargetPath

$engagementMeta = $null
$projectMeta = $null
$engagementPath = Join-Path $TargetPath '.consulting-engagement.json'
$projectProfilePath = Join-Path $TargetPath '.project-profile.json'

if (Test-Path -LiteralPath $engagementPath) {
  $engagementMeta = Get-Content -LiteralPath $engagementPath -Raw -Encoding UTF8 | ConvertFrom-Json
}
if (Test-Path -LiteralPath $projectProfilePath) {
  $projectMeta = Get-Content -LiteralPath $projectProfilePath -Raw -Encoding UTF8 | ConvertFrom-Json
}

switch ($profile) {
  'Consulting' {
    if (-not $engagementMeta) { $structureIssues += 'missing-engagement-metadata' }
    else { $structureIssues += Test-HubConsultingChecks -Root $TargetPath -EngagementMeta $engagementMeta }
  }
  'ConsultingAI' {
    if (-not $engagementMeta) { $structureIssues += 'missing-engagement-metadata' }
    else { $structureIssues += Test-HubConsultingAiChecks -Root $TargetPath -EngagementMeta $engagementMeta }
  }
  'GentleAi' {
    if (-not $projectMeta) { $structureIssues += 'missing-project-profile' }
    else { $structureIssues += Test-HubGentleAiChecks -Root $TargetPath -ProjectMeta $projectMeta }
  }
  default { $structureIssues += 'unknown-profile' }
}

if ($ExpectedProfile -ne 'Auto' -and $profile -ne $ExpectedProfile) {
  $structureIssues += "profile-mismatch-expected-$ExpectedProfile-got-$profile"
}

$structureIssues = @($structureIssues | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
$structureHealthy = $structureIssues.Count -eq 0

$gentleAiResult = $null
$gentleAiIssues = @()
$runGentleAiCheck = (Test-HubProfileUsesGentleAi -Profile $profile) -and -not $SkipGentleAiCheck

if ($runGentleAiCheck) {
  $gentleAiResult = Invoke-HubGentleAiProjectCheck -Root $TargetPath
  $gentleAiIssues = @($gentleAiResult.issues)
}

$issues = @($structureIssues)
if ($runGentleAiCheck -and -not [bool]$gentleAiResult.healthy) {
  $issues += @($gentleAiIssues | ForEach-Object { "gentle-ai:$_" })
}
$issues = @($issues | Select-Object -Unique)
$healthy = $issues.Count -eq 0

$result = [ordered]@{
  targetPath = $TargetPath
  profile = $profile
  expectedProfile = $ExpectedProfile
  structureCheck = [ordered]@{
    healthy = $structureHealthy
    issues = $structureIssues
  }
  gentleAiCheck = if ($runGentleAiCheck) {
    [ordered]@{
      skipped = $false
      healthy = [bool]$gentleAiResult.healthy
      issues = $gentleAiIssues
      cliPaths = @($gentleAiResult.cliPaths)
      globalGentleAi = [bool]$gentleAiResult.globalGentleAi
      workspaceGentleAi = [bool]$gentleAiResult.workspaceGentleAi
      globalEngramMcp = [bool]$gentleAiResult.globalEngramMcp
      workspaceEngramMcp = [bool]$gentleAiResult.workspaceEngramMcp
      skillCollisions = @($gentleAiResult.skillCollisions)
      alwaysApplyRules = @($gentleAiResult.alwaysApplyRules)
    }
  } elseif ((Test-HubProfileUsesGentleAi -Profile $profile) -and $SkipGentleAiCheck) {
    [ordered]@{ skipped = $true; reason = 'SkipGentleAiCheck' }
  } else {
    $null
  }
  issues = $issues
  healthy = $healthy
  remediation = @(
    'Abrí el proyecto hijo como workspace raíz en Cursor antes de probar MCP en el agente.',
    'Para correcciones Gentle AI: gentle-ai doctor y gentle-ai sync.',
    'Para MCP Archi/Backlog: rutas reales en .cursor/mcp.json (ver docs/MCP-PREREQUISITOS.md).'
  )
}

if ($AsJson) {
  $result | ConvertTo-Json -Depth 6
} else {
  Write-Host "Proyecto: $TargetPath"
  Write-Host "Perfil detectado: $profile"
  if ($ExpectedProfile -ne 'Auto') { Write-Host "Perfil esperado: $ExpectedProfile" }
  Write-Host ''
  Write-Host '--- Estructura del template ---' -ForegroundColor Cyan
  if ($structureHealthy) {
    Write-Host 'Resultado: OK' -ForegroundColor Green
  } else {
    Write-Host "Resultado: revisar $($structureIssues -join ', ')" -ForegroundColor Yellow
  }

  if ($runGentleAiCheck) {
    Write-Host ''
    Write-Host '--- Gentle AI (Test-GentleAiProject.ps1) ---' -ForegroundColor Cyan
    Write-Host "Gentle AI global: $($gentleAiResult.globalGentleAi) | workspace: $($gentleAiResult.workspaceGentleAi)"
    Write-Host "Engram MCP global: $($gentleAiResult.globalEngramMcp) | workspace: $($gentleAiResult.workspaceEngramMcp)"
    Write-Host "CLI: $($gentleAiResult.cliPaths -join '; ')"
    if (@($gentleAiResult.skillCollisions).Count -gt 0) {
      Write-Host "Skills local/global repetidas: $($gentleAiResult.skillCollisions -join ', ')"
    }
    Write-Host "Reglas alwaysApply: $($gentleAiResult.alwaysApplyRules -join ', ')"
    if ([bool]$gentleAiResult.healthy) {
      Write-Host 'Resultado: OK' -ForegroundColor Green
    } else {
      Write-Host "Resultado: revisar $($gentleAiIssues -join ', ')" -ForegroundColor Yellow
    }
  } elseif ((Test-HubProfileUsesGentleAi -Profile $profile) -and $SkipGentleAiCheck) {
    Write-Host ''
    Write-Host '--- Gentle AI ---' -ForegroundColor Cyan
    Write-Host 'Omitido (-SkipGentleAiCheck)' -ForegroundColor DarkYellow
  }

  Write-Host ''
  if ($healthy) {
    Write-Host 'Resultado global: OK' -ForegroundColor Green
  } else {
    Write-Host "Resultado global: revisar $($issues -join ', ')" -ForegroundColor Yellow
  }
}

if (-not $healthy) { exit 2 }
