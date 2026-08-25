#Requires -Version 5.1
<#
.SYNOPSIS
  Genera proyectos con Gentle AI global-first y perfiles para desarrollo o consultoría.

.DESCRIPTION
  Perfiles:
  - ConsultingAI (default): skeleton de consultoría + Gentle AI + CDD.
  - Full: alias retrocompatible de ConsultingAI.
  - GentleAi: skeleton mínimo orientado a desarrollo.
  - Consulting: consultoría sin Gentle AI.

  Si existe Gentle AI global, se reutiliza y nunca se ofrece ni ejecuta una
  instalación workspace. La instalación local sólo está disponible cuando no
  existe configuración global.
#>
[CmdletBinding()]
param(
  [string] $TargetPath,
  [ValidateSet('GentleAi', 'Consulting', 'ConsultingAI', 'Full')]
  [string] $StackProfile,
  [ValidateSet('Auto', 'Global', 'Workspace', 'Existing')]
  [string] $GentleAiScope = 'Auto',
  [string] $ProjectName,
  [string] $ClientDisplayName,
  [string] $ClientSlug,
  [string] $InitiativeDisplayName,
  [string] $InitiativeId,
  [string] $ConsultancyName = 'Ingenia',
  [string] $PartnerTeamName,
  [string] $CorporateDocxTemplateName = 'Plantilla Ingenia - 2025.docx',
  [string] $ArchimateExportFilename,
  [string] $ArchimateViewsFilename,
  [string] $BacklogMcpCwd,
  [string[]] $ArchiMcpArgs,
  [string] $EngramPath,
  [bool] $IncludeDrawioMcp = $true,
  [switch] $IncludeBacklogMcp,
  [switch] $IncludeArchiMcp,
  [bool] $IncludeClaudeCoworkLayer = $false,
  [switch] $SkipSkillRegistryRefresh,
  [switch] $SkipHandoffSummary,
  [switch] $Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$modulePath = Join-Path $PSScriptRoot 'lib\ConsultingCopilot.psm1'
Import-Module $modulePath -Force

$templateRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$skeletonPath = Join-Path $templateRoot 'skeleton'
$skeletonMinimalPath = Join-Path $templateRoot 'skeleton-minimal'
$overlayConsultingPath = Join-Path $templateRoot 'overlays\consulting'
$overlayFullPath = Join-Path $templateRoot 'overlays\full'

if ([string]::IsNullOrWhiteSpace($TargetPath)) {
  $TargetPath = Read-ConsultingPrompt 'Ruta absoluta de la carpeta destino (nuevo proyecto)'
}
if (-not [System.IO.Path]::IsPathRooted($TargetPath.Trim())) {
  throw "TargetPath debe ser una ruta absoluta. Recibido: $TargetPath"
}
$TargetPath = [System.IO.Path]::GetFullPath($TargetPath.Trim())
if ((Test-Path -LiteralPath $TargetPath) -and -not $Force) {
  $existingContent = Get-ChildItem -LiteralPath $TargetPath -Force -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($existingContent) { throw "La carpeta destino no está vacía: $TargetPath" }
}

if ([string]::IsNullOrWhiteSpace($StackProfile)) {
  $choice = Read-ConsultingPrompt 'Perfil (ConsultingAI | Consulting | GentleAi)' 'ConsultingAI'
  $StackProfile = switch ($choice.Trim().ToLowerInvariant()) {
    'gentle-ai' { 'GentleAi' }
    'gentleai' { 'GentleAi' }
    'consulting' { 'Consulting' }
    'consulting-only' { 'Consulting' }
    'consultingai' { 'ConsultingAI' }
    'consulting-ai' { 'ConsultingAI' }
    'full' { 'Full' }
    default { $choice }
  }
}

$requestedProfile = $StackProfile
$effectiveProfile = if ($StackProfile -eq 'Full') { 'ConsultingAI' } else { $StackProfile }
$requiresGentleAi = $effectiveProfile -in @('GentleAi', 'ConsultingAI')
$gentleDecision = $null
$gentleCliPath = $null

if ($requiresGentleAi) {
  $preflightEnvironment = Get-GentleAiEnvironment -TargetPath $TargetPath
  if ($preflightEnvironment.GlobalInstalled -and $preflightEnvironment.WorkspaceInstalled) {
    throw 'Se detectó Gentle AI global y también en el workspace. Ejecutá el diagnóstico antes de generar.'
  }
  if ($preflightEnvironment.GlobalInstalled -and $GentleAiScope -eq 'Workspace') {
    throw 'No se permite Gentle AI local porque ya existe configuración global.'
  }
  if ($preflightEnvironment.WorkspaceInstalled -and $GentleAiScope -eq 'Global') {
    throw 'El workspace ya contiene Gentle AI; no se instalará otra copia global automáticamente.'
  }
  $cliMode = if ($GentleAiScope -eq 'Existing') { 'Existing' } else { 'Auto' }
  $cliResolution = Ensure-GentleAiCli -Mode $cliMode -AllowConsultingFallback:($effectiveProfile -eq 'ConsultingAI' -and $GentleAiScope -eq 'Auto')
  if ($cliResolution.FallbackToConsulting) {
    Write-Warning 'Se continuará con perfil Consulting sin Gentle AI, por elección del usuario.'
    $effectiveProfile = 'Consulting'
    $requiresGentleAi = $false
  } else {
    $gentleCliPath = $cliResolution.Path
    $environment = Get-GentleAiEnvironment -TargetPath $TargetPath
    $gentleDecision = Resolve-GentleAiScopeDecision -Environment $environment -RequestedScope $GentleAiScope
    if ($gentleDecision.Action -eq 'Install' -and $gentleDecision.Scope -eq 'Global') {
      Invoke-GentleAiInstall -CliPath $gentleCliPath -Scope Global -TargetPath $TargetPath
      $verified = Get-GentleAiEnvironment -TargetPath $TargetPath
      if (-not $verified.GlobalInstalled) { throw 'Gentle AI terminó sin dejar una configuración global detectable para Cursor.' }
    }
  }
}

if (-not [string]::IsNullOrWhiteSpace($EngramPath)) {
  Write-Warning '-EngramPath se conserva sólo por compatibilidad y se ignora: Engram es administrado por Gentle AI y no se duplica en el MCP local.'
}

$TargetPath = Test-ConsultingTargetPath -TargetPath $TargetPath -Force:$Force

if ($effectiveProfile -eq 'GentleAi') {
  if ([string]::IsNullOrWhiteSpace($ProjectName)) { $ProjectName = Split-Path -Leaf $TargetPath }
  Copy-ConsultingSkeleton -SourcePath $skeletonMinimalPath -TargetPath $TargetPath
  if ($gentleDecision.Action -eq 'Install' -and $gentleDecision.Scope -eq 'Workspace') {
    Invoke-GentleAiInstall -CliPath $gentleCliPath -Scope Workspace -TargetPath $TargetPath
  }
  Copy-ProjectOnboardingLayer -SourceRoot $templateRoot -TargetPath $TargetPath
  Invoke-ConsultingTokenReplacement -TargetPath $TargetPath -Replacements ([ordered]@{ '{{PROJECT_NAME}}' = $ProjectName })
  Write-ProjectProfile -TargetPath $TargetPath -ProjectName $ProjectName -GentleAiScope $gentleDecision.Scope
  Test-ConsultingPlaceholders -TargetPath $TargetPath
  if (-not $SkipSkillRegistryRefresh) { Invoke-SkillRegistryRefresh -TargetPath $TargetPath -CliPath $gentleCliPath }
  $gettingStarted = Write-ProjectGettingStarted -TargetPath $TargetPath -StackProfile GentleAi -Title $ProjectName -GentleAiScope $gentleDecision.Scope
  Write-Host "Listo. Proyecto Gentle AI generado en: $TargetPath"
  if (-not $SkipHandoffSummary) {
    Write-ProjectHandoffSummary -TargetPath $TargetPath -StackProfile GentleAi -GettingStartedPath $gettingStarted -GentleAiScope $gentleDecision.Scope
  }
  return
}

if ([string]::IsNullOrWhiteSpace($ClientDisplayName)) { $ClientDisplayName = Read-ConsultingPrompt 'Nombre del cliente' 'Cliente' }
if ([string]::IsNullOrWhiteSpace($ClientSlug)) {
  $suggestedSlug = ConvertTo-ConsultingSlug $ClientDisplayName
  if (-not $suggestedSlug) { $suggestedSlug = 'cliente' }
  $ClientSlug = Read-ConsultingPrompt 'Slug del cliente' $suggestedSlug
}
if ($ClientSlug -notmatch '^[a-z0-9][a-z0-9-]*$') { throw "ClientSlug inválido: $ClientSlug" }
if ([string]::IsNullOrWhiteSpace($InitiativeDisplayName)) { $InitiativeDisplayName = Read-ConsultingPrompt 'Nombre de la iniciativa / encargo' 'Arquitectura' }
if ([string]::IsNullOrWhiteSpace($InitiativeId)) { $InitiativeId = Read-ConsultingPrompt 'Código corto de iniciativa' 'U01' }
if ([string]::IsNullOrWhiteSpace($ArchimateExportFilename)) { $ArchimateExportFilename = "archimate-$ClientSlug-model.xml" }
if ([string]::IsNullOrWhiteSpace($ArchimateViewsFilename)) { $ArchimateViewsFilename = "archimate-$ClientSlug-views.drawio" }
$docTitlePrefix = "$ClientDisplayName - $InitiativeDisplayName"

if (-not $PSBoundParameters.ContainsKey('IncludeBacklogMcp')) {
  $IncludeBacklogMcp = Read-ConsultingPromptYesNo '¿Incluir MCP Backlog?' $false
}
if ($IncludeBacklogMcp -and [string]::IsNullOrWhiteSpace($BacklogMcpCwd)) { $BacklogMcpCwd = $TargetPath }
if (-not $PSBoundParameters.ContainsKey('IncludeArchiMcp')) {
  $IncludeArchiMcp = Read-ConsultingPromptYesNo '¿Incluir MCP Archi?' $false
}
if ($IncludeArchiMcp -and ($null -eq $ArchiMcpArgs -or $ArchiMcpArgs.Count -eq 0)) {
  $archiPath = Read-ConsultingPrompt 'Ruta absoluta al index.js de archi-mcp' 'C:\ruta\archi-mcp\dist\index.js'
  $ArchiMcpArgs = @($archiPath)
}
if (-not $PSBoundParameters.ContainsKey('IncludeClaudeCoworkLayer')) {
  $IncludeClaudeCoworkLayer = Read-ConsultingPromptYesNo '¿Incluir capa opcional Claude/Cowork?' $false
}

Copy-ConsultingSkeleton -SourcePath $skeletonPath -TargetPath $TargetPath
if ($requiresGentleAi -and $gentleDecision.Action -eq 'Install' -and $gentleDecision.Scope -eq 'Workspace') {
  Invoke-GentleAiInstall -CliPath $gentleCliPath -Scope Workspace -TargetPath $TargetPath
}
Copy-ProjectOverlay -OverlayPath $overlayConsultingPath -TargetPath $TargetPath
if ($effectiveProfile -eq 'ConsultingAI') { Copy-ProjectOverlay -OverlayPath $overlayFullPath -TargetPath $TargetPath }

Rename-ConsultingArchimateTemplates -TargetPath $TargetPath -ArchimateExportFilename $ArchimateExportFilename -ArchimateViewsFilename $ArchimateViewsFilename
$replacements = Get-ConsultingTokenReplacements `
  -ClientDisplayName $ClientDisplayName -ClientSlug $ClientSlug `
  -InitiativeDisplayName $InitiativeDisplayName -InitiativeId $InitiativeId `
  -ConsultancyName $ConsultancyName -PartnerTeamName $PartnerTeamName `
  -DocTitlePrefix $docTitlePrefix -ArchimateExportFilename $ArchimateExportFilename `
  -ArchimateViewsFilename $ArchimateViewsFilename -CorporateDocxTemplateName $CorporateDocxTemplateName
Invoke-ConsultingTokenReplacement -TargetPath $TargetPath -Replacements $replacements

if (-not $IncludeClaudeCoworkLayer) { Remove-ConsultingClaudeLayer -TargetPath $TargetPath }

$mcp = Get-ConsultingMcpServers `
  -IncludeDrawioMcp $IncludeDrawioMcp `
  -IncludeBacklogMcp ([bool]$IncludeBacklogMcp) -BacklogMcpCwd $BacklogMcpCwd `
  -IncludeArchiMcp ([bool]$IncludeArchiMcp) -ArchiMcpArgs $ArchiMcpArgs
Write-ConsultingMcpJson -TargetPath $TargetPath -McpServers $mcp

$stackProfileValue = if ($effectiveProfile -eq 'ConsultingAI') { 'consulting-ai' } else { 'consulting-only' }
Write-StackProfileConfig -TargetPath $TargetPath -StackProfileValue $stackProfileValue
$gentleScopeValue = if ($requiresGentleAi) { $gentleDecision.Scope } else { 'None' }
$gentleActionValue = if ($requiresGentleAi) { $gentleDecision.Action } else { 'None' }
$metaFields = [ordered]@{
  requestedProfile = $requestedProfile
  clientDisplayName = $ClientDisplayName
  clientSlug = $ClientSlug
  initiativeDisplayName = $InitiativeDisplayName
  initiativeId = $InitiativeId
  consultancyName = $ConsultancyName
  docTitlePrefix = $docTitlePrefix
  archimateExportFilename = $ArchimateExportFilename
  archimateViewsFilename = $ArchimateViewsFilename
  corporateDocxTemplateName = $CorporateDocxTemplateName
  includeDrawioMcp = [bool]$IncludeDrawioMcp
  includeBacklogMcp = [bool]$IncludeBacklogMcp
  includeArchiMcp = [bool]$IncludeArchiMcp
  includeClaudeCoworkLayer = [bool]$IncludeClaudeCoworkLayer
  gentleAiScope = $gentleScopeValue.ToLowerInvariant()
  gentleAiAction = $gentleActionValue.ToLowerInvariant()
  engramMcpSource = if ($requiresGentleAi) { 'gentle-ai-managed' } else { 'none' }
}
if (-not [string]::IsNullOrWhiteSpace($PartnerTeamName)) { $metaFields['partnerTeamName'] = $PartnerTeamName.Trim() }
Write-EngagementMetadata -TargetPath $TargetPath -StackProfileValue $stackProfileValue -Fields $metaFields
Test-ConsultingPlaceholders -TargetPath $TargetPath

if ($requiresGentleAi -and -not $SkipSkillRegistryRefresh) {
  Invoke-SkillRegistryRefresh -TargetPath $TargetPath -CliPath $gentleCliPath
}

$gettingStarted = Write-ProjectGettingStarted `
  -TargetPath $TargetPath -StackProfile $effectiveProfile -Title $docTitlePrefix `
  -GentleAiScope $gentleScopeValue -IncludeDrawioMcp $IncludeDrawioMcp `
  -IncludeBacklogMcp ([bool]$IncludeBacklogMcp) -IncludeArchiMcp ([bool]$IncludeArchiMcp) `
  -CorporateDocxTemplateName $CorporateDocxTemplateName

Write-Host "Listo. Proyecto $effectiveProfile generado en: $TargetPath"
if ($IncludeClaudeCoworkLayer) { Write-Host 'Capa opcional Claude/Cowork incluida.' }
if (-not $SkipHandoffSummary) {
  Write-ProjectHandoffSummary -TargetPath $TargetPath -StackProfile $effectiveProfile -GettingStartedPath $gettingStarted -GentleAiScope $gentleScopeValue
}
