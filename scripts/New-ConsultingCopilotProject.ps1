#Requires -Version 5.1
<#
.SYNOPSIS
  Crea un proyecto con perfil Gentle AI, Consulting Copilot o ambos (Full).

.DESCRIPTION
  Perfiles:
  - GentleAi: skeleton mínimo + gentle-ai install --scope workspace
  - Consulting: skeleton Ingenia + overlay consulting (sin CDD)
  - Full: skeleton Ingenia + gentle-ai install (SDD/Engram) + overlays consulting + full (CDD)

.EXAMPLE
  .\New-ConsultingCopilotProject.ps1 -TargetPath "D:\clientes\iplan" -StackProfile Full `
    -ClientDisplayName "IPLAN" -ClientSlug "iplan" `
    -InitiativeDisplayName "Gobierno de APIs" -InitiativeId "U01"
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $false)]
  [string] $TargetPath,

  [Parameter(Mandatory = $false)]
  [ValidateSet('GentleAi', 'Consulting', 'Full')]
  [string] $StackProfile,

  [Parameter(Mandatory = $false)]
  [string] $ProjectName,

  [Parameter(Mandatory = $false)]
  [string] $ClientDisplayName,

  [Parameter(Mandatory = $false)]
  [string] $ClientSlug,

  [Parameter(Mandatory = $false)]
  [string] $InitiativeDisplayName,

  [Parameter(Mandatory = $false)]
  [string] $InitiativeId,

  [Parameter(Mandatory = $false)]
  [string] $ConsultancyName = 'Ingenia',

  [Parameter(Mandatory = $false)]
  [string] $PartnerTeamName,

  [Parameter(Mandatory = $false)]
  [string] $CorporateDocxTemplateName = 'Plantilla Ingenia - 2025.docx',

  [Parameter(Mandatory = $false)]
  [string] $ArchimateExportFilename,

  [Parameter(Mandatory = $false)]
  [string] $ArchimateViewsFilename,

  [Parameter(Mandatory = $false)]
  [string] $BacklogMcpCwd,

  [Parameter(Mandatory = $false)]
  [string[]] $ArchiMcpArgs,

  [Parameter(Mandatory = $false)]
  [string] $EngramPath,

  [bool] $IncludeDrawioMcp = $true,
  [switch] $IncludeBacklogMcp,
  [switch] $IncludeArchiMcp,

  [Parameter(Mandatory = $false)]
  [bool] $IncludeClaudeCoworkLayer = $true,

  [switch] $SkipSkillRegistryRefresh,
  [switch] $SkipHandoffSummary,
  [switch] $Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ModulePath = Join-Path $PSScriptRoot 'lib\ConsultingCopilot.psm1'
Import-Module $ModulePath -Force

$TemplateRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$SkeletonPath = Join-Path $TemplateRoot 'skeleton'
$SkeletonMinimalPath = Join-Path $TemplateRoot 'skeleton-minimal'
$OverlayConsultingPath = Join-Path $TemplateRoot 'overlays\consulting'
$OverlayFullPath = Join-Path $TemplateRoot 'overlays\full'

if ([string]::IsNullOrWhiteSpace($TargetPath)) {
  $TargetPath = Read-ConsultingPrompt 'Ruta absoluta de la carpeta destino (nuevo proyecto)'
}
$TargetPath = Test-ConsultingTargetPath -TargetPath $TargetPath -Force:$Force

if ([string]::IsNullOrWhiteSpace($StackProfile)) {
  $choice = Read-ConsultingPrompt 'Perfil (GentleAi | Consulting | Full)' 'Full'
  $StackProfile = switch ($choice.Trim().ToLowerInvariant()) {
    'gentle-ai' { 'GentleAi' }
    'gentleai' { 'GentleAi' }
    'consulting' { 'Consulting' }
    'consulting-only' { 'Consulting' }
    'full' { 'Full' }
    default { $choice }
  }
}

switch ($StackProfile) {
  'GentleAi' {
    if ([string]::IsNullOrWhiteSpace($ProjectName)) {
      $ProjectName = Split-Path -Leaf $TargetPath
    }
    Copy-ConsultingSkeleton -SourcePath $SkeletonMinimalPath -TargetPath $TargetPath
    $replacements = [ordered]@{ '{{PROJECT_NAME}}' = $ProjectName }
    Invoke-ConsultingTokenReplacement -TargetPath $TargetPath -Replacements $replacements
    Test-ConsultingPlaceholders -TargetPath $TargetPath

    $engramResolved = Resolve-EngramPath -EngramPath $EngramPath
    $mcp = Get-ConsultingMcpServers -IncludeEngramMcp $true -EngramPath $engramResolved `
      -IncludeDrawioMcp $false -IncludeBacklogMcp $false -IncludeArchiMcp $false
    Write-ConsultingMcpJson -TargetPath $TargetPath -McpServers $mcp
    Write-ProjectProfile -TargetPath $TargetPath -ProjectName $ProjectName
    Invoke-GentleAiWorkspaceInstall -TargetPath $TargetPath
    Copy-ProjectOnboardingLayer -SourceRoot $TemplateRoot -TargetPath $TargetPath
    if (-not $SkipSkillRegistryRefresh) {
      Invoke-SkillRegistryRefresh -TargetPath $TargetPath
    }

    $gsPath = Write-ProjectGettingStarted `
      -TargetPath $TargetPath `
      -StackProfile 'GentleAi' `
      -Title $ProjectName `
      -IncludeEngramMcp $true
    Write-Host "Listo. Proyecto Gentle AI generado en: $TargetPath"
    if (-not $SkipHandoffSummary) {
      Write-ProjectHandoffSummary -TargetPath $TargetPath -StackProfile 'GentleAi' -GettingStartedPath $gsPath
    } else {
      Write-Host "Continuá en: $gsPath"
    }
  }

  { $_ -in @('Consulting', 'Full') } {
    if ([string]::IsNullOrWhiteSpace($ClientDisplayName)) {
      $ClientDisplayName = Read-ConsultingPrompt 'Nombre del cliente (display)' 'Cliente'
    }
    if ([string]::IsNullOrWhiteSpace($ClientSlug)) {
      $sug = ConvertTo-ConsultingSlug $ClientDisplayName
      if ([string]::IsNullOrWhiteSpace($sug)) { $sug = 'cliente' }
      $ClientSlug = Read-ConsultingPrompt 'Slug del cliente (minúsculas, sin espacios)' $sug
    }
    if ($ClientSlug -notmatch '^[a-z0-9][a-z0-9-]*$') {
      throw "ClientSlug inválido: $ClientSlug"
    }
    if ([string]::IsNullOrWhiteSpace($InitiativeDisplayName)) {
      $InitiativeDisplayName = Read-ConsultingPrompt 'Nombre de la iniciativa / encargo' 'Arquitectura'
    }
    if ([string]::IsNullOrWhiteSpace($InitiativeId)) {
      $InitiativeId = Read-ConsultingPrompt 'Código corto de iniciativa (ej. U01)' 'U01'
    }
    if ([string]::IsNullOrWhiteSpace($ArchimateExportFilename)) {
      $ArchimateExportFilename = "archimate-$ClientSlug-model.xml"
    }
    if ([string]::IsNullOrWhiteSpace($ArchimateViewsFilename)) {
      $ArchimateViewsFilename = "archimate-$ClientSlug-views.drawio"
    }
    $DocTitlePrefix = "$ClientDisplayName - $InitiativeDisplayName"

    if (-not $PSBoundParameters.ContainsKey('IncludeBacklogMcp')) {
      $IncludeBacklogMcp = Read-ConsultingPromptYesNo '¿Incluir MCP backlog (Backlog.md)?' $false
    }
    if ($IncludeBacklogMcp -and [string]::IsNullOrWhiteSpace($BacklogMcpCwd)) {
      $BacklogMcpCwd = Read-ConsultingPrompt 'Ruta absoluta del cwd del repo para backlog' $TargetPath
    }
    if (-not $PSBoundParameters.ContainsKey('IncludeArchiMcp')) {
      $IncludeArchiMcp = Read-ConsultingPromptYesNo '¿Incluir MCP archi (archi-server)?' $false
    }
    if ($IncludeArchiMcp -and ($null -eq $ArchiMcpArgs -or $ArchiMcpArgs.Count -eq 0)) {
      $line = Read-ConsultingPrompt 'Ruta absoluta al index.js de archi-mcp' 'C:\ruta\archi-mcp\dist\index.js'
      $ArchiMcpArgs = $line -split '\|' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    }

    Copy-ConsultingSkeleton -SourcePath $SkeletonPath -TargetPath $TargetPath
    if ($StackProfile -eq 'Full') {
      Invoke-GentleAiWorkspaceInstall -TargetPath $TargetPath -Force:$Force
    }
    Copy-ProjectOverlay -OverlayPath $OverlayConsultingPath -TargetPath $TargetPath
    if ($StackProfile -eq 'Full') {
      Copy-ProjectOverlay -OverlayPath $OverlayFullPath -TargetPath $TargetPath
    }

    Rename-ConsultingArchimateTemplates -TargetPath $TargetPath `
      -ArchimateExportFilename $ArchimateExportFilename `
      -ArchimateViewsFilename $ArchimateViewsFilename

    $replacements = Get-ConsultingTokenReplacements `
      -ClientDisplayName $ClientDisplayName `
      -ClientSlug $ClientSlug `
      -InitiativeDisplayName $InitiativeDisplayName `
      -InitiativeId $InitiativeId `
      -ConsultancyName $ConsultancyName `
      -PartnerTeamName $PartnerTeamName `
      -DocTitlePrefix $DocTitlePrefix `
      -ArchimateExportFilename $ArchimateExportFilename `
      -ArchimateViewsFilename $ArchimateViewsFilename `
      -CorporateDocxTemplateName $CorporateDocxTemplateName
    Invoke-ConsultingTokenReplacement -TargetPath $TargetPath -Replacements $replacements

    if (-not $IncludeClaudeCoworkLayer) {
      Remove-ConsultingClaudeLayer -TargetPath $TargetPath
    }

    $consultingMcp = Get-ConsultingMcpServers `
      -IncludeDrawioMcp $IncludeDrawioMcp `
      -IncludeBacklogMcp ([bool]$IncludeBacklogMcp) `
      -BacklogMcpCwd $BacklogMcpCwd `
      -IncludeArchiMcp ([bool]$IncludeArchiMcp) `
      -ArchiMcpArgs $ArchiMcpArgs `
      -IncludeEngramMcp $false

    if ($StackProfile -eq 'Full') {
      $engramResolved = Resolve-EngramPath -EngramPath $EngramPath
      $engramMcp = Get-ConsultingMcpServers -IncludeEngramMcp $true -EngramPath $engramResolved `
        -IncludeDrawioMcp $false -IncludeBacklogMcp $false -IncludeArchiMcp $false
      $mcp = Merge-ConsultingMcpServers -Primary $consultingMcp -Secondary $engramMcp
      Write-StackProfileConfig -TargetPath $TargetPath -StackProfileValue 'full'
    } else {
      $mcp = $consultingMcp
      Write-StackProfileConfig -TargetPath $TargetPath -StackProfileValue 'consulting-only'
    }
    Write-ConsultingMcpJson -TargetPath $TargetPath -McpServers $mcp

    $stackProfileValue = if ($StackProfile -eq 'Full') { 'full' } else { 'consulting-only' }
    $metaFields = [ordered]@{
      clientDisplayName         = $ClientDisplayName
      clientSlug                = $ClientSlug
      initiativeDisplayName     = $InitiativeDisplayName
      initiativeId              = $InitiativeId
      consultancyName           = $ConsultancyName
      docTitlePrefix            = $DocTitlePrefix
      archimateExportFilename   = $ArchimateExportFilename
      archimateViewsFilename    = $ArchimateViewsFilename
      corporateDocxTemplateName = $CorporateDocxTemplateName
      includeDrawioMcp          = [bool]$IncludeDrawioMcp
      includeBacklogMcp         = [bool]$IncludeBacklogMcp
      includeArchiMcp           = [bool]$IncludeArchiMcp
      includeClaudeCoworkLayer  = [bool]$IncludeClaudeCoworkLayer
    }
    if (-not [string]::IsNullOrWhiteSpace($PartnerTeamName)) {
      $metaFields['partnerTeamName'] = $PartnerTeamName.Trim()
    }
    Write-EngagementMetadata -TargetPath $TargetPath -StackProfileValue $stackProfileValue -Fields $metaFields
    Test-ConsultingPlaceholders -TargetPath $TargetPath

    if ($StackProfile -eq 'Full' -and -not $SkipSkillRegistryRefresh) {
      Invoke-SkillRegistryRefresh -TargetPath $TargetPath
    }

    $gsPath = Write-ProjectGettingStarted `
      -TargetPath $TargetPath `
      -StackProfile $StackProfile `
      -Title $DocTitlePrefix `
      -IncludeEngramMcp ($StackProfile -eq 'Full') `
      -IncludeDrawioMcp ([bool]$IncludeDrawioMcp) `
      -IncludeBacklogMcp ([bool]$IncludeBacklogMcp) `
      -IncludeArchiMcp ([bool]$IncludeArchiMcp) `
      -CorporateDocxTemplateName $CorporateDocxTemplateName

    Write-Host "Listo. Proyecto Consulting Copilot ($StackProfile) generado en: $TargetPath"
    if ($IncludeClaudeCoworkLayer) {
      Write-Host 'Capa Anthropic: revisá CLAUDE.md y docs/MCP-CLAUDE-DESKTOP.md'
    }
    if (-not $SkipHandoffSummary) {
      Write-ProjectHandoffSummary -TargetPath $TargetPath -StackProfile $StackProfile -GettingStartedPath $gsPath
    } else {
      Write-Host "Continuá en: $gsPath"
    }
  }
}
