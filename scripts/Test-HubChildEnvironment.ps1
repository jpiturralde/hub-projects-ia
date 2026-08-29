#Requires -Version 5.1
<#
.SYNOPSIS
  Diagnóstico detect-only del entorno de un proyecto hijo (gemelo hub).

.DESCRIPTION
  Usa Get-HubProjectRequirements + probes compartidos. No instala ni repara.
  Exit 0 = OK | Exit 2 = fallos en requisitos o MCP local roto

.EXAMPLE
  pwsh -File ./Test-HubChildEnvironment.ps1 -TargetPath ../projects/mi-hijo
  pwsh -File ./Test-HubChildEnvironment.ps1 -TargetPath ../projects/mi-hijo -AsJson
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string] $TargetPath,

  [switch] $AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$modulePath = Join-Path (Join-Path $PSScriptRoot 'lib') 'ConsultingCopilot.psm1'
# -AsJson must be ConvertFrom-Json clean: suppress unapproved-verb Import-Module noise on stdout/stderr.
if ($AsJson) {
  $WarningPreference = 'SilentlyContinue'
}
Import-Module $modulePath -Force -WarningAction SilentlyContinue

$result = Invoke-HubProjectEnvironmentDoctor -TargetPath $TargetPath

if ($AsJson) {
  $result | Select-Object ok, exitCode, checks | ConvertTo-Json -Depth 6
  if ($MyInvocation.InvocationName -ne '.' -and -not $result.ok) {
    exit 2
  }
  exit 0
}

Write-HubProjectEnvironmentDoctor -Result $result

if ($MyInvocation.InvocationName -ne '.' -and -not $result.ok) {
  exit 2
}
if ($MyInvocation.InvocationName -ne '.') {
  exit 0
}
