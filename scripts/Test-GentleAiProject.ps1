#Requires -Version 5.1
<#
.SYNOPSIS
  Diagnóstico read-only de duplicación Gentle AI/Engram y configuración del template.

.DESCRIPTION
  No elimina ni reescribe archivos administrados. Consume Get-GentleAiProjectDiagnostic
  del módulo (sin lanzar subprocesos que terminen el proceso).

  Exit 0 = healthy | Exit 2 = issues (solo si el script es el entrypoint).

.EXAMPLE
  # Windows
  pwsh -File .\Test-GentleAiProject.ps1 -TargetPath "D:\work\hub-projects-ia\projects\iplan-prev-2142"

.EXAMPLE
  # Ubuntu/WSL
  pwsh -File ./Test-GentleAiProject.ps1 -TargetPath ../projects/iplan-prev-2142 -AsJson
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
