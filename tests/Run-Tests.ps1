#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
if (-not (Get-Module -ListAvailable -Name Pester)) {
  throw 'Pester no está instalado. Ejecutá: Install-Module Pester -Scope CurrentUser'
}
Invoke-Pester -Path (Join-Path $PSScriptRoot 'ConsultingCopilot.Tests.ps1') -Output Detailed

