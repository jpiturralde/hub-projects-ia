#Requires -Version 5.1
<#
.SYNOPSIS
  Diagnóstico de prerrequisitos. No instala ni modifica Gentle AI.
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
Import-Module (Join-Path $PSScriptRoot 'lib\ConsultingCopilot.psm1') -Force

$result = Get-ConsultingCopilotPreflightDiagnostic -StackProfile $StackProfile -TargetPath $TargetPath

if ($AsJson) {
  $result | ConvertTo-Json -Depth 6
} else {
  Write-ConsultingCopilotPreflightDiagnostic -Result $result
}

return $result
