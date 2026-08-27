#Requires -Version 5.1
<#
.SYNOPSIS
  Smoke test unificado de un proyecto hijo generado desde hub-projects-ia.

.DESCRIPTION
  Punto de entrada canónico tras New-HubProject.ps1. Valida estructura, metadata,
  MCP y marcadores por perfil. Incluye diagnóstico Gentle AI vía funciones del
  módulo (read-only; no ejecuta scripts hijos con exit).

  Exit 0 = OK | Exit 2 = fallos detectados

.EXAMPLE
  # Windows
  pwsh -File .\Test-HubProject.ps1 -TargetPath "..\projects\iplan-prev-2142" -ExpectedProfile ConsultingAI

.EXAMPLE
  # Ubuntu/WSL
  pwsh -File ./Test-HubProject.ps1 -TargetPath ../projects/iplan-prev-2142 -ExpectedProfile Auto -AsJson
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

$modulePath = Join-Path (Join-Path $PSScriptRoot 'lib') 'ConsultingCopilot.psm1'
Import-Module $modulePath -Force

$result = Get-HubProjectDiagnostic `
  -TargetPath $TargetPath `
  -ExpectedProfile $ExpectedProfile `
  -SkipGentleAiCheck:$SkipGentleAiCheck

if ($AsJson) {
  $result | ConvertTo-Json -Depth 6
} else {
  Write-HubProjectDiagnostic -Result $result
}

if ($MyInvocation.InvocationName -ne '.' -and -not $result.healthy) {
  exit 2
}

return $result
