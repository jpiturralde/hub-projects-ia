#Requires -Version 5.1
<#
.SYNOPSIS
  Preflight / diagnóstico de prerrequisitos. No instala ni modifica Gentle AI.

.DESCRIPTION
  Conserva el nombre histórico Install-ConsultingCopilot.ps1 por compatibilidad.
  Comportamiento efectivo: diagnóstico read-only vía Get-ConsultingCopilotPreflightDiagnostic.

.EXAMPLE
  # Windows
  pwsh -File .\Install-ConsultingCopilot.ps1 -StackProfile ConsultingAI

.EXAMPLE
  # Ubuntu/WSL
  pwsh -File ./Install-ConsultingCopilot.ps1 -StackProfile ConsultingAI -AsJson
#>
[CmdletBinding()]
param(
  [ValidateSet('GentleAi', 'Consulting', 'ConsultingAI', 'Full')]
  [string] $StackProfile = 'ConsultingAI',
  [string] $TargetPath,
  [switch] $AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'
Import-Module (Join-Path (Join-Path $PSScriptRoot 'lib') 'ConsultingCopilot.psm1') -Force

$result = Get-ConsultingCopilotPreflightDiagnostic -StackProfile $StackProfile -TargetPath $TargetPath

if ($AsJson) {
  $result | ConvertTo-Json -Depth 6
} else {
  Write-ConsultingCopilotPreflightDiagnostic -Result $result
}

return $result
