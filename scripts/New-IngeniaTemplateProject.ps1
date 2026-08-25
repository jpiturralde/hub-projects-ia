#Requires -Version 5.1
<#
.SYNOPSIS
  Alias retrocompatible — delega en New-ConsultingCopilotProject.ps1 con perfil Consulting.

.DESCRIPTION
  Conserva el nombre antiguo para scripts o documentación que aún invoquen New-IngeniaTemplateProject.ps1.
  Equivalente a: New-ConsultingCopilotProject.ps1 -StackProfile Consulting @args
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $false)]
  [string] $TargetPath,

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

  [bool] $IncludeDrawioMcp = $true,
  [switch] $IncludeBacklogMcp,
  [switch] $IncludeArchiMcp,

  [Parameter(Mandatory = $false)]
  [bool] $IncludeClaudeCoworkLayer = $true,

  [switch] $Force
)

$main = Join-Path $PSScriptRoot 'New-ConsultingCopilotProject.ps1'
if (-not (Test-Path -LiteralPath $main)) {
  throw "No se encuentra: $main"
}

$params = @{}
if ($PSBoundParameters.ContainsKey('TargetPath')) { $params['TargetPath'] = $TargetPath }
if ($PSBoundParameters.ContainsKey('ClientDisplayName')) { $params['ClientDisplayName'] = $ClientDisplayName }
if ($PSBoundParameters.ContainsKey('ClientSlug')) { $params['ClientSlug'] = $ClientSlug }
if ($PSBoundParameters.ContainsKey('InitiativeDisplayName')) { $params['InitiativeDisplayName'] = $InitiativeDisplayName }
if ($PSBoundParameters.ContainsKey('InitiativeId')) { $params['InitiativeId'] = $InitiativeId }
if ($PSBoundParameters.ContainsKey('ConsultancyName')) { $params['ConsultancyName'] = $ConsultancyName }
if ($PSBoundParameters.ContainsKey('PartnerTeamName') -and -not [string]::IsNullOrWhiteSpace($PartnerTeamName)) {
  $params['PartnerTeamName'] = $PartnerTeamName.Trim()
}
if ($PSBoundParameters.ContainsKey('CorporateDocxTemplateName')) { $params['CorporateDocxTemplateName'] = $CorporateDocxTemplateName }
if ($PSBoundParameters.ContainsKey('ArchimateExportFilename')) { $params['ArchimateExportFilename'] = $ArchimateExportFilename }
if ($PSBoundParameters.ContainsKey('ArchimateViewsFilename')) { $params['ArchimateViewsFilename'] = $ArchimateViewsFilename }
if ($PSBoundParameters.ContainsKey('BacklogMcpCwd')) { $params['BacklogMcpCwd'] = $BacklogMcpCwd }
if ($PSBoundParameters.ContainsKey('ArchiMcpArgs')) { $params['ArchiMcpArgs'] = $ArchiMcpArgs }
if ($PSBoundParameters.ContainsKey('IncludeDrawioMcp')) { $params['IncludeDrawioMcp'] = $IncludeDrawioMcp }
if ($PSBoundParameters.ContainsKey('IncludeBacklogMcp')) { $params['IncludeBacklogMcp'] = $IncludeBacklogMcp.IsPresent }
if ($PSBoundParameters.ContainsKey('IncludeArchiMcp')) { $params['IncludeArchiMcp'] = $IncludeArchiMcp.IsPresent }
if ($PSBoundParameters.ContainsKey('IncludeClaudeCoworkLayer')) { $params['IncludeClaudeCoworkLayer'] = $IncludeClaudeCoworkLayer }
if ($PSBoundParameters.ContainsKey('Force')) { $params['Force'] = $Force.IsPresent }

& $main @params -StackProfile Consulting
