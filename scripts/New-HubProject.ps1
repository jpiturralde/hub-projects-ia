#Requires -Version 5.1
<#
.SYNOPSIS
  Crea un proyecto hijo dentro de projects/ del hub hub-projects-ia.

.DESCRIPTION
  Wrapper de New-ConsultingCopilotProject.ps1 que:
  - Resuelve la ruta absoluta bajo projects/
  - Delega la generación al script base
  - Ejecuta git init en el hijo
  - Registra el proyecto en hub-registry.json

.EXAMPLE
  .\New-HubProject.ps1 -StackProfile ConsultingAI `
    -ClientDisplayName "IPLAN" -ClientSlug "iplan" `
    -InitiativeDisplayName "Gobierno de APIs" -InitiativeId "U01"
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $false)]
  [ValidateSet('GentleAi', 'Consulting', 'ConsultingAI', 'Full')]
  [string] $StackProfile,

  [ValidateSet('Auto', 'Global', 'Workspace', 'Existing')]
  [string] $GentleAiScope = 'Auto',

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
  [string] $ProjectFolderName,

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
  [bool] $IncludeClaudeCoworkLayer = $false,

  [switch] $SkipSkillRegistryRefresh,
  [switch] $SkipGitInit,
  [switch] $SkipOpenCursor,
  [switch] $Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ModulePath = Join-Path $PSScriptRoot 'lib\ConsultingCopilot.psm1'
Import-Module $ModulePath -Force

$HubRoot = Get-HubProjectsIaRoot -ScriptRoot $PSScriptRoot
$ProjectsRoot = Join-Path $HubRoot 'projects'
$RegistryPath = Join-Path $HubRoot 'hub-registry.json'
$GeneratorScript = Join-Path $PSScriptRoot 'New-ConsultingCopilotProject.ps1'

if (-not (Test-Path -LiteralPath $ProjectsRoot)) {
  New-Item -ItemType Directory -Path $ProjectsRoot -Force | Out-Null
}

function Get-HubRegistry {
  param([string] $Path)
  if (-not (Test-Path -LiteralPath $Path)) {
    return [ordered]@{ schemaVersion = 1; projects = @() }
  }
  $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
  if ([string]::IsNullOrWhiteSpace($raw)) {
    return [ordered]@{ schemaVersion = 1; projects = @() }
  }
  return ($raw | ConvertFrom-Json)
}

function Resolve-HubProjectFolderName {
  param(
    [string] $Profile,
    [string] $FolderOverride,
    [string] $ClientSlugValue,
    [string] $InitiativeIdValue,
    [string] $ProjectNameValue
  )

  if (-not [string]::IsNullOrWhiteSpace($FolderOverride)) {
    $name = $FolderOverride.Trim()
    if ($name -notmatch '^[a-z0-9][a-z0-9-]*$') {
      throw "ProjectFolderName inválido (minúsculas, números y guiones): $name"
    }
    return $name
  }

  switch ($Profile) {
    'GentleAi' {
      if ([string]::IsNullOrWhiteSpace($ProjectNameValue)) {
        throw 'Para perfil GentleAi indicá -ProjectName o -ProjectFolderName.'
      }
      $slug = ConvertTo-ConsultingSlug $ProjectNameValue
      if ([string]::IsNullOrWhiteSpace($slug)) {
        throw "No se pudo derivar carpeta desde ProjectName: $ProjectNameValue"
      }
      return $slug
    }
    default {
      if ([string]::IsNullOrWhiteSpace($ClientSlugValue)) {
        throw 'Para Consulting/ConsultingAI indicá -ClientSlug o -ProjectFolderName.'
      }
      if ([string]::IsNullOrWhiteSpace($InitiativeIdValue)) {
        throw 'Para Consulting/ConsultingAI indicá -InitiativeId o -ProjectFolderName.'
      }
      $init = $InitiativeIdValue.Trim().ToLowerInvariant()
      return "$ClientSlugValue-$init"
    }
  }
}

function Add-HubRegistryEntry {
  param(
    [string] $RegistryFile,
    [hashtable] $Entry
  )

  $registry = Get-HubRegistry -Path $RegistryFile
  $projects = @()
  if ($registry.projects) {
    $projects = @($registry.projects)
  }

  $existing = $projects | Where-Object { $_.folderName -eq $Entry.folderName }
  if ($existing -and -not $Force) {
    throw "folderName ya registrado en hub-registry.json: $($Entry.folderName). Usá -Force si querés regenerar."
  }

  $projects = @($projects | Where-Object { $_.folderName -ne $Entry.folderName })
  $projects += [pscustomobject]$Entry

  $out = [ordered]@{
    schemaVersion = 1
    projects      = $projects
  }
  ($out | ConvertTo-Json -Depth 6) + "`n" | Set-Content -LiteralPath $RegistryFile -Encoding UTF8
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

$folderName = Resolve-HubProjectFolderName `
  -Profile $StackProfile `
  -FolderOverride $ProjectFolderName `
  -ClientSlugValue $ClientSlug `
  -InitiativeIdValue $InitiativeId `
  -ProjectNameValue $ProjectName

$TargetPath = Join-Path $ProjectsRoot $folderName
$TargetPath = [System.IO.Path]::GetFullPath($TargetPath)

if (-not $TargetPath.StartsWith($ProjectsRoot, [StringComparison]::OrdinalIgnoreCase)) {
  Write-Warning "TargetPath fuera de projects/: $TargetPath. El gitignore del hub no lo excluirá automáticamente."
}

$registryPreview = Get-HubRegistry -Path $RegistryPath
if ($registryPreview.projects) {
  $dup = @($registryPreview.projects | Where-Object { $_.folderName -eq $folderName })
  if ($dup.Count -gt 0 -and -not $Force) {
    throw "Ya existe un proyecto registrado con folderName '$folderName'. Usá -Force para regenerar o elegí otro nombre."
  }
}

if ((Test-Path -LiteralPath $TargetPath) -and -not $Force) {
  $any = Get-ChildItem -LiteralPath $TargetPath -Force -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($any) {
    throw "La carpeta destino no está vacía: $TargetPath. Vaciala, usá -Force o elegí otro ProjectFolderName."
  }
}

if ($IncludeBacklogMcp -and [string]::IsNullOrWhiteSpace($BacklogMcpCwd)) {
  $BacklogMcpCwd = $TargetPath
}
if ($IncludeArchiMcp -and ($null -eq $ArchiMcpArgs -or $ArchiMcpArgs.Count -eq 0)) {
  $ArchiMcpArgs = @('C:\ruta\archi-mcp\dist\index.js')
}

$genParams = @{
  TargetPath               = $TargetPath
  StackProfile             = $StackProfile
  GentleAiScope            = $GentleAiScope
  ConsultancyName          = $ConsultancyName
  CorporateDocxTemplateName = $CorporateDocxTemplateName
  IncludeDrawioMcp         = $IncludeDrawioMcp
  Force                    = $Force
}

if ($PSBoundParameters.ContainsKey('PartnerTeamName') -and -not [string]::IsNullOrWhiteSpace($PartnerTeamName)) {
  $genParams.PartnerTeamName = $PartnerTeamName.Trim()
}

if ($PSBoundParameters.ContainsKey('ProjectName')) { $genParams.ProjectName = $ProjectName }
if ($PSBoundParameters.ContainsKey('ClientDisplayName')) { $genParams.ClientDisplayName = $ClientDisplayName }
if ($PSBoundParameters.ContainsKey('ClientSlug')) { $genParams.ClientSlug = $ClientSlug }
if ($PSBoundParameters.ContainsKey('InitiativeDisplayName')) { $genParams.InitiativeDisplayName = $InitiativeDisplayName }
if ($PSBoundParameters.ContainsKey('InitiativeId')) { $genParams.InitiativeId = $InitiativeId }
if ($PSBoundParameters.ContainsKey('ArchimateExportFilename')) { $genParams.ArchimateExportFilename = $ArchimateExportFilename }
if ($PSBoundParameters.ContainsKey('ArchimateViewsFilename')) { $genParams.ArchimateViewsFilename = $ArchimateViewsFilename }
if (-not [string]::IsNullOrWhiteSpace($BacklogMcpCwd)) { $genParams.BacklogMcpCwd = $BacklogMcpCwd }
if ($ArchiMcpArgs -and $ArchiMcpArgs.Count -gt 0) { $genParams.ArchiMcpArgs = $ArchiMcpArgs }
if ($PSBoundParameters.ContainsKey('EngramPath')) { $genParams.EngramPath = $EngramPath }
if ($PSBoundParameters.ContainsKey('IncludeBacklogMcp')) { $genParams.IncludeBacklogMcp = $IncludeBacklogMcp }
if ($PSBoundParameters.ContainsKey('IncludeArchiMcp')) { $genParams.IncludeArchiMcp = $IncludeArchiMcp }
if ($PSBoundParameters.ContainsKey('IncludeClaudeCoworkLayer')) { $genParams.IncludeClaudeCoworkLayer = $IncludeClaudeCoworkLayer }
if ($SkipSkillRegistryRefresh) { $genParams.SkipSkillRegistryRefresh = $true }
$genParams.SkipHandoffSummary = $true

Write-Host "Hub: $HubRoot"
Write-Host "Generando proyecto en: $TargetPath"
Write-Host "Perfil: $StackProfile"

& $GeneratorScript @genParams

$gitInitialized = $false
if (-not $SkipGitInit) {
  $gitDir = Join-Path $TargetPath '.git'
  if (-not (Test-Path -LiteralPath $gitDir)) {
    Write-Host "Inicializando repositorio Git en el proyecto hijo..."
    Push-Location $TargetPath
    try {
      & git init
      if ($LASTEXITCODE -ne 0) {
        throw "git init falló con código $LASTEXITCODE"
      }
      $gitInitialized = $true
    } finally {
      Pop-Location
    }
  } else {
    Write-Host "El proyecto hijo ya tiene .git; omitiendo git init."
    $gitInitialized = $true
  }
}

$registryProfile = $StackProfile
$generatedMetaPath = Join-Path $TargetPath '.consulting-engagement.json'
if (Test-Path -LiteralPath $generatedMetaPath) {
  $generatedMeta = Get-Content -LiteralPath $generatedMetaPath -Raw -Encoding UTF8 | ConvertFrom-Json
  if ($generatedMeta.stackProfile -eq 'consulting-only') { $registryProfile = 'Consulting' }
  elseif ($generatedMeta.stackProfile -eq 'consulting-ai') { $registryProfile = 'ConsultingAI' }
}

$entry = [ordered]@{
  folderName     = $folderName
  absolutePath   = $TargetPath
  stackProfile   = $registryProfile
  createdAt      = (Get-Date).ToString('o')
  gitInitialized = $gitInitialized
}

if ($StackProfile -eq 'GentleAi') {
  if (-not [string]::IsNullOrWhiteSpace($ProjectName)) {
    $entry.projectName = $ProjectName
  }
} else {
  if (-not [string]::IsNullOrWhiteSpace($ClientSlug)) { $entry.clientSlug = $ClientSlug }
  if (-not [string]::IsNullOrWhiteSpace($InitiativeId)) { $entry.initiativeId = $InitiativeId }
}

Add-HubRegistryEntry -RegistryFile $RegistryPath -Entry $entry

$gettingStartedPath = Join-Path $TargetPath 'docs\GETTING-STARTED.md'
$resolvedGentleScope = 'None'
$engagementMetaPath = Join-Path $TargetPath '.consulting-engagement.json'
$projectMetaPath = Join-Path $TargetPath '.project-profile.json'
foreach ($metaPath in @($engagementMetaPath, $projectMetaPath)) {
  if (Test-Path -LiteralPath $metaPath) {
    $meta = Get-Content -LiteralPath $metaPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($meta.gentleAiScope) { $resolvedGentleScope = [string]$meta.gentleAiScope }
    break
  }
}
Write-Host "Registro: $RegistryPath"
Write-ProjectHandoffSummary -TargetPath $TargetPath -StackProfile $registryProfile -GettingStartedPath $gettingStartedPath -GentleAiScope $resolvedGentleScope

if (-not $SkipOpenCursor) {
  Invoke-OpenCursorWorkspace -TargetPath $TargetPath | Out-Null
}
