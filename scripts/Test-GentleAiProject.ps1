#Requires -Version 5.1
<#
.SYNOPSIS
  Diagnóstico read-only de duplicación Gentle AI/Engram y configuración del template.

.DESCRIPTION
  No elimina ni reescribe archivos administrados. Devuelve código 2 si encuentra
  un conflicto que debería resolverse antes de regenerar o migrar el proyecto.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string] $TargetPath,
  [switch] $AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path (Join-Path $PSScriptRoot 'lib') 'ConsultingCopilot.psm1') -Force

$result = Get-GentleAiProjectDiagnostic -TargetPath $TargetPath

if ($AsJson) {
  $result | ConvertTo-Json -Depth 6
} else {
  Write-GentleAiProjectDiagnostic -Result $result
}

if ($MyInvocation.InvocationName -ne '.' -and -not $result.healthy) {
  exit 2
}

return $result
