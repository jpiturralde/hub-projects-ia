#Requires -Version 5.1
<#
.SYNOPSIS
  Diagnóstico de prerrequisitos. No instala ni modifica Gentle AI.
#>
[CmdletBinding()]
param(
  [ValidateSet('GentleAi', 'Consulting', 'ConsultingAI', 'Full')]
  [string] $StackProfile = 'ConsultingAI',
  [string] $TargetPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'
Import-Module (Join-Path $PSScriptRoot 'lib\ConsultingCopilot.psm1') -Force

function Write-Check {
  param([string] $Label, [bool] $Ok, [string] $Detail = '')
  $icon = if ($Ok) { '[ok]' } else { '[!!]' }
  Write-Host "$icon  $Label" -ForegroundColor $(if ($Ok) { 'Green' } else { 'Yellow' })
  if ($Detail) { Write-Host "     $Detail" }
}

$effectiveProfile = if ($StackProfile -eq 'Full') { 'ConsultingAI' } else { $StackProfile }
$needsGentle = $effectiveProfile -in @('GentleAi', 'ConsultingAI')
$environment = Get-GentleAiEnvironment -TargetPath $TargetPath

Write-Host "Consulting Copilot — diagnóstico ($effectiveProfile)" -ForegroundColor Cyan
Write-Host ''

if ($needsGentle) {
  Write-Host '--- Gentle AI (sólo lectura) ---'
  Write-Check 'Un único gentle-ai CLI' ($environment.CliCount -eq 1) $(if ($environment.CliCount -eq 0) {
    'No encontrado. Instalación estable: go install github.com/gentleman-programming/gentle-ai/v2/cmd/gentle-ai@latest'
  } elseif ($environment.CliCount -gt 1) { $environment.CliPaths -join '; ' } else { $environment.CliPath })
  Write-Check 'Configuración global para Cursor' $environment.GlobalInstalled $(if ($environment.GlobalInstalled) {
    'Se reutilizará automáticamente; la opción workspace queda bloqueada.'
  } else { 'Al generar se preguntará: Global (recomendado), Proyecto o Cancelar.' })
  if ($TargetPath) {
    Write-Check 'Sin Gentle AI duplicado en workspace' (-not ($environment.GlobalInstalled -and $environment.WorkspaceInstalled)) $(if ($environment.WorkspaceInstalled) {
      $environment.WorkspaceMarkerPaths -join '; '
    })
    Write-Check 'Sin Engram duplicado en MCP local' (-not $environment.WorkspaceEngramConfigured) $(if ($environment.WorkspaceEngramConfigured) {
      $environment.WorkspaceMcpPath
    })
  }
  if ($environment.CliCount -eq 1) {
    Write-Host ''
    & $environment.CliPath doctor 2>&1 | ForEach-Object { Write-Host $_ }
  }
  Write-Host ''
}

if ($effectiveProfile -in @('Consulting', 'ConsultingAI')) {
  Write-Host '--- Consultoría ---'
  $nodePaths = @(Get-CommandExecutablePaths -Name 'node')
  Write-Check 'Node.js' ($nodePaths.Count -eq 1) 'Requerido sólo si se usa Draw.io MCP.'
  Write-Check 'Pandoc' (@(Get-CommandExecutablePaths -Name 'pandoc').Count -eq 1) 'Opcional para regenerar DOCX.'
  Write-Check 'Backlog CLI' (@(Get-CommandExecutablePaths -Name 'backlog').Count -eq 1) 'Opcional.'
  Write-Host ''
}

Write-Host 'Crear proyecto:' -ForegroundColor Cyan
Write-Host '  .\New-ConsultingCopilotProject.ps1 -TargetPath "D:\ruta\proyecto" -StackProfile ConsultingAI'
Write-Host ''
Write-Host 'El generador resuelve Gentle AI antes de crear archivos y no corrige instalaciones existentes automáticamente.'
