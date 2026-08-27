#Requires -Version 5.1
<#
.SYNOPSIS
  Mueve todo el hub hub-projects-ia a otra ubicación con backup y actualización de rutas.

.DESCRIPTION
  1. Valida origen y destino
  2. Crea una copia de backup junto al origen (no se borra automáticamente)
  3. Mueve la carpeta del hub
  4. Actualiza hub-registry.json y .cursor/mcp.json de proyectos hijos
  5. Valida la migración

  Cerrá Cursor y cualquier terminal abierta dentro del hub antes de ejecutar.

.EXAMPLE
  .\Move-HubProjectsIa.ps1

.EXAMPLE
  .\Move-HubProjectsIa.ps1 `
    -SourcePath "C:\work\hub-projects-ia" `
    -DestinationPath "D:\repos\hub-projects-ia"
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
  [Parameter(Mandatory = $false)]
  [string] $SourcePath,

  [Parameter(Mandatory = $false)]
  [string] $DestinationPath,

  [switch] $Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ModulePath = Join-Path $PSScriptRoot 'lib\ConsultingCopilot.psm1'
Import-Module $ModulePath -Force

$defaultSource = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

if ([string]::IsNullOrWhiteSpace($SourcePath)) {
  $SourcePath = Read-ConsultingPrompt 'Ruta absoluta del hub origen' $defaultSource
}
if ([string]::IsNullOrWhiteSpace($DestinationPath)) {
  $DestinationPath = Read-ConsultingPrompt 'Ruta absoluta del hub destino'
}

$precheck = Test-HubMovePreconditions -SourcePath $SourcePath -DestinationPath $DestinationPath
if (-not $precheck.Ok) {
  Write-Host 'No se puede continuar:' -ForegroundColor Red
  $precheck.Issues | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
  exit 2
}

$source = $precheck.SourcePath
$destination = $precheck.DestinationPath
$backupPath = Get-HubMoveBackupPath -SourcePath $source

Write-Host ''
Write-Host '=== Migración del hub ===' -ForegroundColor Cyan
Write-Host "Origen:      $source"
Write-Host "Destino:     $destination"
Write-Host "Backup:      $backupPath"
Write-Host ''
Write-Host 'Antes de continuar:' -ForegroundColor Yellow
Write-Host '  - Cerrá Cursor si tenés abierto el hub o algún proyecto hijo.'
Write-Host '  - Cerrá terminales con cwd dentro del hub.'
Write-Host '  - El backup quedará en disco; borralo manualmente cuando confirmes que todo funciona.'
Write-Host ''

if ($PSBoundParameters.ContainsKey('WhatIf')) {
  $preview = Invoke-HubRelocate -SourcePath $source -DestinationPath $destination -WhatIf
  Write-Host 'WhatIf: no se realizaron cambios.' -ForegroundColor Yellow
  $preview.Plan | Format-List
  exit 0
}

if (-not $Force) {
  $confirmed = Read-ConsultingPromptYesNo '¿Confirmás la migración?' $false
  if (-not $confirmed) {
    Write-Host 'Cancelado.' -ForegroundColor Yellow
    exit 0
  }
}

Write-Host 'Creando backup...' -ForegroundColor Cyan
$result = Invoke-HubRelocate -SourcePath $source -DestinationPath $destination

Write-Host ''
Write-Host '=== Migración completada ===' -ForegroundColor Green
Write-Host "Hub nuevo:   $($result.Move.DestinationPath)"
Write-Host "Backup:      $($result.Backup.BackupPath)" -ForegroundColor Yellow
Write-Host "Registry:    $($result.PathUpdates.Registry.ProjectCount) proyecto(s) actualizado(s)"
Write-Host "MCP hijos:   $($result.PathUpdates.UpdatedMcpFiles.Count) archivo(s) actualizado(s)"
Write-Host ''
Write-Host 'Próximos pasos:' -ForegroundColor Cyan
Write-Host "  1. Abrí Cursor en: $($result.Move.DestinationPath)"
Write-Host '  2. Verificá MCP Backlog en proyectos hijos si los usás.'
Write-Host "  3. Cuando estés conforme, borrá manualmente el backup: $($result.Backup.BackupPath)"
Write-Host ''

exit 0
