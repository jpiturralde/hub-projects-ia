#Requires -Version 5.1
<#
.SYNOPSIS
  Genera proyectos con Gentle AI global-first y perfiles para desarrollo o consultoría.

.DESCRIPTION
  Generador central del hub. Perfiles:
  - ConsultingAI (default): skeleton de consultoría + Gentle AI + CDD.
  - Full: alias retrocompatible de ConsultingAI.
  - GentleAi: skeleton mínimo orientado a desarrollo.
  - Consulting: consultoría sin Gentle AI.

  Si existe Gentle AI global, se reutiliza y nunca se ofrece ni ejecuta una
  instalación workspace. La instalación local sólo está disponible cuando no
  existe configuración global.

  -EngramPath está obsoleto y se ignora. Preferí New-HubProject.ps1 para
  proyectos bajo el hub (git + registry).

.EXAMPLE
  # Windows
  pwsh -File .\New-ConsultingCopilotProject.ps1 -TargetPath "D:\work\proyecto" `
    -StackProfile ConsultingAI -ClientDisplayName "IPLAN" -ClientSlug "iplan" `
    -InitiativeDisplayName "U01" -InitiativeId "U01"

.EXAMPLE
  # Ubuntu/WSL
  pwsh -File ./New-ConsultingCopilotProject.ps1 -TargetPath "/home/user/work/proyecto" `
    -StackProfile Consulting -ClientDisplayName "ACME" -ClientSlug "acme" `
    -InitiativeDisplayName "Assessment" -InitiativeId "A01"
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
  [string] $EngramPath, # Obsolete: ignored. Engram is managed by Gentle AI.
  [bool] $IncludeDrawioMcp = $true,
  [switch] $IncludeBacklogMcp,
  [switch] $IncludeArchiMcp,
  [bool] $IncludeClaudeCoworkLayer = $false,
  [bool] $IncludeStartiaMcp = $true,
  [switch] $SkipSkillRegistryRefresh,
  [switch] $SkipHandoffSummary,
  [switch] $Force,
  # Solo tests / automatización no interactiva (I|X|C y G|P|X).
  [string] $GentleAiCliChoice,
  [string] $GentleAiScopeChoice,
  # Solo tests / automatización no interactiva (I=instalar, X=cancelar).
  [string] $BacklogCliChoice
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path (Join-Path $PSScriptRoot 'lib') 'Platform.psm1') -Force
$modulePath = Resolve-HubModulePath -ScriptRoot $PSScriptRoot -ModuleName 'ConsultingCopilot'
Import-Module $modulePath -Force

$templateRoot = Get-HubProjectsIaRoot -ScriptRoot $PSScriptRoot
$skeletonPath = Join-HubPath $templateRoot 'skeleton'
$skeletonMinimalPath = Join-HubPath $templateRoot 'skeleton-minimal'
$overlayConsultingPath = Join-HubPath $templateRoot 'overlays' 'consulting'
$overlayFullPath = Join-HubPath $templateRoot 'overlays' 'full'

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
  $cliMode = if ($GentleAiScope -eq 'Existing') { 'Existing' } else { 'Auto' }
  $preflightParams = @{
    TargetPath = $TargetPath
    RequestedScope = $GentleAiScope
    CliMode = $cliMode
    AllowConsultingFallback = ($effectiveProfile -eq 'ConsultingAI' -and $GentleAiScope -eq 'Auto')
  }
  if (-not [string]::IsNullOrWhiteSpace($GentleAiCliChoice)) { $preflightParams['CliChoice'] = $GentleAiCliChoice }
  if (-not [string]::IsNullOrWhiteSpace($GentleAiScopeChoice)) { $preflightParams['ScopeChoice'] = $GentleAiScopeChoice }
  $preflight = Resolve-GentleAiPreflight @preflightParams
  if ($preflight.Status -eq 'Failed') { throw $preflight.Error }
  if ($preflight.Status -eq 'Cancelled') { throw $preflight.Error }
  if ($preflight.FallbackToConsulting) {
    Write-Warning 'Se continuará con perfil Consulting sin Gentle AI, por elección del usuario.'
    $effectiveProfile = 'Consulting'
    $requiresGentleAi = $false
  } else {
    $gentleCliPath = $preflight.Cli.Path
    $gentleDecision = $preflight.Decision
    if ($gentleDecision.Action -eq 'Install' -and $gentleDecision.Scope -eq 'Global') {
      Invoke-GentleAiInstall -CliPath $gentleCliPath -Scope Global -TargetPath $TargetPath
      $verified = Get-GentleAiEnvironment -TargetPath $TargetPath
      if (-not $verified.GlobalInstalled) { throw 'Gentle AI terminó sin dejar una configuración global detectable para Cursor.' }
    }
  }
}

if (-not [string]::IsNullOrWhiteSpace($EngramPath)) {
  Write-Warning '-EngramPath está obsoleto y se ignora: Engram es administrado por Gentle AI y no se duplica en el MCP local.'
}

if (-not $PSBoundParameters.ContainsKey('IncludeStartiaMcp')) {
  $IncludeStartiaMcp = Read-ConsultingPromptYesNo '¿Incluir MCP Startia + política de skills?' $true
}

$finalTargetPath = Resolve-ConsultingFinalTargetPath -TargetPath $TargetPath -Force:$Force
Write-HubPathLocationWarnings -TargetPath $finalTargetPath
$stagingPath = New-ConsultingProjectStagingPath
$TargetPath = $stagingPath

try {
if ($effectiveProfile -eq 'GentleAi') {
  if ([string]::IsNullOrWhiteSpace($ProjectName)) { $ProjectName = Split-Path -Leaf $finalTargetPath }
  Copy-ConsultingSkeleton -SourcePath $skeletonMinimalPath -TargetPath $TargetPath
  if ($gentleDecision.Action -eq 'Install' -and $gentleDecision.Scope -eq 'Workspace') {
    Invoke-GentleAiInstall -CliPath $gentleCliPath -Scope Workspace -TargetPath $TargetPath
  }
  Copy-ProjectOnboardingLayer -SourceRoot $templateRoot -TargetPath $TargetPath
  if ($IncludeStartiaMcp) {
    Copy-StartiaMcpPolicy -SourceRoot $templateRoot -TargetPath $TargetPath
    $mcp = Get-ConsultingMcpServers `
      -IncludeDrawioMcp $false -IncludeBacklogMcp $false -BacklogMcpCwd '' `
      -IncludeArchiMcp $false -ArchiMcpArgs @() -IncludeStartiaMcp $IncludeStartiaMcp
    Write-ConsultingMcpJson -TargetPath $TargetPath -McpServers $mcp
  }
  Invoke-ConsultingTokenReplacement -TargetPath $TargetPath -Replacements ([ordered]@{ '{{PROJECT_NAME}}' = $ProjectName })
  Write-ProjectProfile -TargetPath $TargetPath -ProjectName $ProjectName -GentleAiScope $gentleDecision.Scope -IncludeStartiaMcp $IncludeStartiaMcp
  Test-ConsultingPlaceholders -TargetPath $TargetPath
  if (-not $SkipSkillRegistryRefresh) { Invoke-SkillRegistryRefresh -TargetPath $TargetPath -CliPath $gentleCliPath }
  $gettingStarted = Write-ProjectGettingStarted `
    -TargetPath $TargetPath -StackProfile GentleAi -Title $ProjectName -GentleAiScope $gentleDecision.Scope `
    -IncludeStartiaMcp $IncludeStartiaMcp
} else {
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
if ($IncludeBacklogMcp -and [string]::IsNullOrWhiteSpace($BacklogMcpCwd)) { $BacklogMcpCwd = $finalTargetPath }
if ($IncludeBacklogMcp) {
  $backlogParams = @{ Mode = 'Auto' }
  if (-not [string]::IsNullOrWhiteSpace($BacklogCliChoice)) {
    $backlogParams['Choice'] = $BacklogCliChoice
  }
  $null = Ensure-BacklogCli @backlogParams
}
if (-not $PSBoundParameters.ContainsKey('IncludeArchiMcp')) {
  $IncludeArchiMcp = Read-ConsultingPromptYesNo '¿Incluir MCP Archi?' $false
}
if ($IncludeArchiMcp -and ($null -eq $ArchiMcpArgs -or $ArchiMcpArgs.Count -eq 0)) {
  $archiPath = Read-ConsultingPrompt 'Ruta absoluta al index.js de archi-mcp'
  if ([string]::IsNullOrWhiteSpace($archiPath)) {
    throw 'IncludeArchiMcp requiere una ruta absoluta existente al index.js de archi-mcp.'
  }
  $ArchiMcpArgs = @(Test-HubArchiMcpPath -Path $archiPath)
} elseif ($IncludeArchiMcp) {
  $ArchiMcpArgs = @((Test-HubArchiMcpPath -Path $ArchiMcpArgs[0]))
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

if ($IncludeStartiaMcp) {
  Copy-StartiaMcpPolicy -SourceRoot $templateRoot -TargetPath $TargetPath
}

$mcp = Get-ConsultingMcpServers `
  -IncludeDrawioMcp $IncludeDrawioMcp `
  -IncludeBacklogMcp ([bool]$IncludeBacklogMcp) -BacklogMcpCwd $BacklogMcpCwd `
  -IncludeArchiMcp ([bool]$IncludeArchiMcp) -ArchiMcpArgs $ArchiMcpArgs `
  -IncludeStartiaMcp $IncludeStartiaMcp
Test-HubMcpConfigurationPaths `
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
  includeStartiaMcp = [bool]$IncludeStartiaMcp
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
  -IncludeStartiaMcp $IncludeStartiaMcp `
  -CorporateDocxTemplateName $CorporateDocxTemplateName
}

  $TargetPath = Promote-ConsultingProjectStaging -StagingPath $stagingPath -TargetPath $finalTargetPath -Force:$Force
  $stagingPath = $null

  if ($effectiveProfile -eq 'GentleAi') {
    Write-Host "Listo. Proyecto Gentle AI generado en: $TargetPath"
    if ($IncludeStartiaMcp) { Write-StartiaMcpHandoffHint }
    if (-not $SkipHandoffSummary) {
      Write-ProjectHandoffSummary -TargetPath $TargetPath -StackProfile GentleAi -GettingStartedPath $gettingStarted -GentleAiScope $gentleDecision.Scope
    }
  } else {
    Write-Host "Listo. Proyecto $effectiveProfile generado en: $TargetPath"
    if ($IncludeClaudeCoworkLayer) { Write-Host 'Capa opcional Claude/Cowork incluida.' }
    if ($IncludeStartiaMcp) { Write-StartiaMcpHandoffHint }
    if (-not $SkipHandoffSummary) {
      Write-ProjectHandoffSummary -TargetPath $TargetPath -StackProfile $effectiveProfile -GettingStartedPath $gettingStarted -GentleAiScope $gentleScopeValue
    }
  }
} catch {
  Remove-ConsultingProjectStaging -StagingPath $stagingPath
  throw
}
