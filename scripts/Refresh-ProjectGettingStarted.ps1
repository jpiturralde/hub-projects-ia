#Requires -Version 5.1
<#
.SYNOPSIS
  Regenera docs/GETTING-STARTED.md desde la metadata del proyecto hijo.

.DESCRIPTION
  Lee .consulting-engagement.json o .project-profile.json y vuelve a escribir
  GETTING-STARTED sin rutas absolutas ni nombre fijo del hub.

.EXAMPLE
  .\Refresh-ProjectGettingStarted.ps1 -TargetPath "..\projects\iplan-prev-2142"

.EXAMPLE
  .\Refresh-ProjectGettingStarted.ps1 -AllFromRegistry
#>
[CmdletBinding()]
param(
  [Parameter(ParameterSetName = 'Single')]
  [string] $TargetPath,

  [Parameter(ParameterSetName = 'Registry')]
  [switch] $AllFromRegistry
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path (Join-Path $PSScriptRoot 'lib') 'Platform.psm1') -Force
Import-Module (Join-Path (Join-Path $PSScriptRoot 'lib') 'ConsultingCopilot.psm1') -Force

$hubRoot = Get-HubProjectsIaRoot -ScriptRoot $PSScriptRoot

function Invoke-RefreshOne {
  param([string] $Path)
  $resolved = [System.IO.Path]::GetFullPath($Path)
  if (-not (Test-Path -LiteralPath $resolved -PathType Container)) {
    Write-Warning "Proyecto no encontrado (se omite): $resolved"
    return
  }
  $output = Update-ProjectGettingStartedFromMetadata -TargetPath $resolved
  Write-Host "OK $output"
}

if ($PSCmdlet.ParameterSetName -eq 'Registry') {
  $registry = Read-HubRegistry -HubRoot $hubRoot
  foreach ($item in @($registry.Projects)) {
    if ($item.ResolveError) {
      Write-Warning "No se pudo resolver $($item.FolderName): $($item.ResolveError)"
      continue
    }
    if (-not $item.Exists) {
      Write-Warning "Proyecto registrado no encontrado ($($item.FolderName)): $($item.ResolvedPath)"
      continue
    }
    Invoke-RefreshOne -Path $item.ResolvedPath
  }
  return
}

if ([string]::IsNullOrWhiteSpace($TargetPath)) {
  throw 'Indicá -TargetPath o -AllFromRegistry.'
}

Invoke-RefreshOne -Path $TargetPath
