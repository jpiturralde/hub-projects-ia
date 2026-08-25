#Requires -Version 5.1
<#
.SYNOPSIS
  Valida prerequisitos globales para Consulting Copilot y Gentle AI.

.PARAMETER StackProfile
  GentleAi | Consulting | Full (default Full)

.EXAMPLE
  .\Install-ConsultingCopilot.ps1 -StackProfile Full
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $false)]
  [ValidateSet('GentleAi', 'Consulting', 'Full')]
  [string] $StackProfile = 'Full'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

function Test-CommandExists {
  param([string] $Name)
  return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Write-Check {
  param([string] $Label, [bool] $Ok, [string] $Detail = '')
  $icon = if ($Ok) { '[ok]' } else { '[!!]' }
  Write-Host "$icon  $Label" -ForegroundColor $(if ($Ok) { 'Green' } else { 'Yellow' })
  if ($Detail) { Write-Host "     $Detail" }
}

Write-Host "Consulting Copilot — verificación de prerequisitos ($StackProfile)" -ForegroundColor Cyan
Write-Host ''

$needsGentle = $StackProfile -in @('GentleAi', 'Full')
$needsConsulting = $StackProfile -in @('Consulting', 'Full')

if ($needsGentle) {
  Write-Host '--- Gentle AI ---'
  $gentle = Test-CommandExists 'gentle-ai'
  Write-Check 'gentle-ai CLI' $gentle $(if (-not $gentle) { 'Instalar gentle-ai y agregar al PATH' })
  if ($gentle) {
    & gentle-ai doctor 2>&1 | ForEach-Object { Write-Host $_ }
  }
  $engram = Test-CommandExists 'engram'
  Write-Check 'engram CLI' $engram $(if (-not $engram) { 'Requerido para memoria persistente' })
  Write-Host ''
}

if ($needsConsulting) {
  Write-Host '--- Consulting Copilot ---'
  $node = Test-CommandExists 'node'
  Write-Check 'Node.js' $node 'Requerido para draw.io MCP (npx @drawio/mcp)'
  $pandoc = Test-CommandExists 'pandoc'
  Write-Check 'Pandoc' $pandoc 'Opcional pero recomendado para regenerar .docx'
  $backlog = Test-CommandExists 'backlog'
  Write-Check 'Backlog.md CLI' $backlog 'Solo si usarás MCP backlog'
  Write-Host ''
  Write-Host 'Documentación MCP: ver MCP-PREREQUISITOS.md en este repo'
  Write-Host ''
}

Write-Host '--- Próximo paso ---' -ForegroundColor Cyan
Write-Host @"

Crear un proyecto:

  cd scripts
  .\New-ConsultingCopilotProject.ps1 -TargetPath "D:\ruta\proyecto" -StackProfile $StackProfile

Perfiles:
  GentleAi   — solo desarrollo (SDD + Engram)
  Consulting — solo consultoría (entregables, diagramas)
  Full       — ambos (CDD + entregables)

"@
