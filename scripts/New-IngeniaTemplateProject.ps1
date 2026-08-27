#Requires -Version 5.1
<#
.SYNOPSIS
  Alias retrocompatible — delega en New-ConsultingCopilotProject.ps1 con perfil ConsultingAI.

.DESCRIPTION
  Conserva el nombre antiguo para scripts o documentación que aún invoquen
  New-IngeniaTemplateProject.ps1.

  Equivalente a:
    New-ConsultingCopilotProject.ps1 -StackProfile ConsultingAI ...

.EXAMPLE
  # Windows
  pwsh -File .\New-IngeniaTemplateProject.ps1 -TargetPath "D:\work\proyecto" -ClientDisplayName "ACME" -ClientSlug "acme" -InitiativeDisplayName "U01" -InitiativeId "U01"

.EXAMPLE
  # Ubuntu/WSL
  pwsh -File ./New-IngeniaTemplateProject.ps1 -TargetPath "/home/user/work/proyecto" -ClientDisplayName "ACME" -ClientSlug "acme" -InitiativeDisplayName "U01" -InitiativeId "U01"
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $false)]
  [string] $TargetPath,

  [ValidateSet('Auto', 'Global', 'Workspace', 'Existing')]
  [string] $GentleAiScope = 'Auto',

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
  [bool] $IncludeClaudeCoworkLayer = $false,

  [switch] $SkipSkillRegistryRefresh,
  [switch] $SkipHandoffSummary,
  [switch] $Force
)

$main = Join-Path $PSScriptRoot 'New-ConsultingCopilotProject.ps1'
if (-not (Test-Path -LiteralPath $main)) {
  throw "No se encuentra: $main"
}

$params = @{}
foreach ($key in @($PSBoundParameters.Keys)) {
  if ($key -eq 'EngramPath') { continue } # obsoleto; el generador advierte si se pasa
  $params[$key] = $PSBoundParameters[$key]
}
if ($PSBoundParameters.ContainsKey('EngramPath')) {
  $params['EngramPath'] = $EngramPath
}

& $main @params -StackProfile ConsultingAI
