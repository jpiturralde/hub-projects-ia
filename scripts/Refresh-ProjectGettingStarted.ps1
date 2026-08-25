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

$hubRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Import-Module (Join-Path $hubRoot 'scripts\lib\ConsultingCopilot.psm1') -Force

function Invoke-RefreshOne {
  param([string] $Path)
  $resolved = [System.IO.Path]::GetFullPath($Path)
  $output = Update-ProjectGettingStartedFromMetadata -TargetPath $resolved
  Write-Host "OK $output"
}

if ($PSCmdlet.ParameterSetName -eq 'Registry') {
  $registryPath = Join-Path $hubRoot 'hub-registry.json'
  if (-not (Test-Path -LiteralPath $registryPath)) {
    throw "No se encontró hub-registry.json en: $registryPath"
  }
  $registry = Get-Content -LiteralPath $registryPath -Raw -Encoding UTF8 | ConvertFrom-Json
  foreach ($project in @($registry.projects)) {
    if (-not $project.absolutePath) { continue }
    Invoke-RefreshOne -Path ([string]$project.absolutePath)
  }
  exit 0
}

if ([string]::IsNullOrWhiteSpace($TargetPath)) {
  throw 'Indicá -TargetPath o -AllFromRegistry.'
}

Invoke-RefreshOne -Path $TargetPath
