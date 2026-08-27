#Requires -Version 5.1
$ErrorActionPreference = 'Stop'

if (-not (Get-Module -ListAvailable -Name Pester)) {
  throw 'Pester no está instalado. Ejecutá: pwsh -NoProfile -Command "Install-Module Pester -MinimumVersion 5.0 -Scope CurrentUser -Force"'
}

$testsRoot = $PSScriptRoot

$paths = @(
  (Join-Path $testsRoot 'unit')
  (Join-Path $testsRoot 'characterization')
  (Join-Path $testsRoot 'integration')
  (Join-Path $testsRoot 'ConsultingCopilot.Tests.ps1')
  (Join-Path $testsRoot 'Move-HubProjectsIa.Tests.ps1')
) | Where-Object { Test-Path -LiteralPath $_ }

if ($paths.Count -eq 0) {
  throw "No se encontraron tests bajo: $testsRoot"
}

$result = Invoke-Pester -Path $paths -PassThru
if ($result.FailedCount -gt 0) {
  exit 1
}
exit 0
