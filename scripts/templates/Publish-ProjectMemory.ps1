#Requires -Version 5.1
<#
.SYNOPSIS
  Publica la memoria del proyecto hacia `.engram/` (delta Git Sync). Sin auto-commit.

.DESCRIPTION
  Usa `engram sync --project <engramProject>` (Engram ≥1.20). Imprime aviso PII + hint git add.
  Paridad: no ejecuta git commit/push.

.EXAMPLE
  pwsh -File ./scripts/Publish-ProjectMemory.ps1
#>
[CmdletBinding()]
param(
  [string] $TargetPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-PublishRoot {
  param([string] $TargetPath)
  if (-not [string]::IsNullOrWhiteSpace($TargetPath)) {
    return [System.IO.Path]::GetFullPath($TargetPath)
  }
  return [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
}

function Get-PublishEngramProjectKey {
  param([string] $Root)
  foreach ($name in @('.consulting-engagement.json', '.project-profile.json')) {
    $path = Join-Path $Root $name
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { continue }
    try {
      $meta = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
      if ($meta.PSObject.Properties.Name -contains 'engramProject' -and -not [string]::IsNullOrWhiteSpace([string]$meta.engramProject)) {
        return ([string]$meta.engramProject).Trim()
      }
    } catch { }
  }
  return (Split-Path -Leaf $Root)
}

$root = Get-PublishRoot -TargetPath $TargetPath
Push-Location $root
try {
  $key = Get-PublishEngramProjectKey -Root $root
  $engram = Get-Command engram -ErrorAction SilentlyContinue
  if (-not $engram) {
    Write-Host 'No se encontraron herramientas de memoria en PATH. Ejecuta antes Preparar entorno.' -ForegroundColor Red
    exit 2
  }

  Write-Host "Publicando memoria del proyecto ($key)..."
  $before = @()
  $chunksDir = Join-Path $root '.engram/chunks'
  if (Test-Path -LiteralPath $chunksDir) {
    $before = @(Get-ChildItem -LiteralPath $chunksDir -File -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name)
  }

  & $engram.Source sync --project $key
  if ($LASTEXITCODE -ne 0) {
    Write-Host "No se pudo publicar la memoria (codigo $LASTEXITCODE)." -ForegroundColor Red
    exit 2
  }

  $after = @()
  if (Test-Path -LiteralPath $chunksDir) {
    $after = @(Get-ChildItem -LiteralPath $chunksDir -File -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name)
  }
  $newChunks = @($after | Where-Object { $_ -notin $before })
  if ($newChunks.Count -eq 0 -and -not (Test-Path -LiteralPath (Join-Path $root '.engram/manifest.json'))) {
    Write-Host 'No habia memoria nueva para publicar.' -ForegroundColor Yellow
    exit 0
  }

  Write-Host 'Memoria del proyecto actualizada en `.engram/`. Revisá que no haya datos sensibles, luego: git add .engram/ y commit.' -ForegroundColor Green
  exit 0
} finally {
  Pop-Location
}
