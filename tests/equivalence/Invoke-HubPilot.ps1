#Requires -Version 5.1
<#
.SYNOPSIS
  Piloto Fase 11 — crea 4 perfiles descartables, valida y limpia.

.DESCRIPTION
  No toca IPLAN/GIRE. Verifica sentinels globales, registry, git, diagnósticos
  y contratos expected. Por defecto limpia los proyectos piloto al final.
#>
[CmdletBinding()]
param(
  [string] $HubRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
  [switch] $KeepProjects
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scripts = Join-Path $HubRoot 'scripts'
Import-Module (Join-Path $scripts 'lib\ConsultingCopilot.psm1') -Force
. (Join-Path $HubRoot 'tests\helpers\CharacterizationHelpers.ps1')

function Get-GlobalSentinelSnapshot {
  $userHome = [Environment]::GetFolderPath('UserProfile')
  $paths = @(
    (Join-Path $userHome '.cursor\mcp.json')
    (Join-Path $userHome '.gentle-ai\state.json')
    (Join-Path $userHome '.cursor\rules\gentle-ai.mdc')
  )
  $snap = @()
  foreach ($path in $paths) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { continue }
    $item = Get-Item -LiteralPath $path
    $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
    $snap += [pscustomobject]@{
      Path = $path
      Length = $item.Length
      LastWriteTimeUtc = $item.LastWriteTimeUtc
      Hash = $hash
    }
  }
  return $snap
}

function Assert-GlobalSentinelUnchanged {
  param([object[]] $Before)
  foreach ($s in $Before) {
    if (-not (Test-Path -LiteralPath $s.Path -PathType Leaf)) {
      throw "Sentinel global desapareció: $($s.Path)"
    }
    $item = Get-Item -LiteralPath $s.Path
    $hash = (Get-FileHash -LiteralPath $s.Path -Algorithm SHA256).Hash
    if ($item.Length -ne $s.Length -or $item.LastWriteTimeUtc -ne $s.LastWriteTimeUtc -or $hash -ne $s.Hash) {
      throw "Sentinel global modificado: $($s.Path)"
    }
  }
}

$report = [ordered]@{
  startedAt = (Get-Date).ToString('o')
  platform = (Get-HubPlatformInfo).Platform
  doctorOk = $false
  projects = @()
  sentinelOk = $false
  cleaned = $false
  findings = [System.Collections.Generic.List[string]]::new()
}

Write-Host '=== Fase 11 piloto hub multiplataforma ===' -ForegroundColor Cyan
Write-Host "Hub: $HubRoot"
Write-Host "Plataforma: $($report.platform)"

$beforeSentinel = Get-GlobalSentinelSnapshot
$registryPath = Join-Path $HubRoot 'hub-registry.json'
$registryBackup = Join-Path $HubRoot ("hub-registry.json.bak-pilot-{0}" -f (Get-Date -Format 'yyyyMMddHHmmss'))
Copy-Item -LiteralPath $registryPath -Destination $registryBackup -Force
Write-Host "Backup registry: $registryBackup"

Write-Host ''
Write-Host '--- doctor ---' -ForegroundColor Yellow
$doctor = & (Join-Path $scripts 'Install-ConsultingCopilot.ps1') -StackProfile ConsultingAI
$doctorFailed = @($doctor.checks | Where-Object { -not $_.ok -and $_.group -eq 'gentle-ai' })
if ($doctorFailed.Count -gt 0) {
  throw "Doctor Gentle AI no saludable: $($doctorFailed | ConvertTo-Json -Compress)"
}
$report.doctorOk = $true
$report.findings.Add('doctor: Gentle AI CLI único + global OK')

$pilots = @(
  @{
    Key = 'consulting'
    Folder = 'pilot-hubmp-consulting'
    Expected = 'consulting'
    Profile = 'Consulting'
    Args = @{
      StackProfile = 'Consulting'
      ClientDisplayName = 'Equiv'
      ClientSlug = 'equiv'
      InitiativeDisplayName = 'Encargo'
      InitiativeId = 'EQV01'
      ProjectFolderName = 'pilot-hubmp-consulting'
    }
  }
  @{
    Key = 'consulting-ai'
    Folder = 'pilot-hubmp-consultingai'
    Expected = 'consulting-ai'
    Profile = 'ConsultingAI'
    Args = @{
      StackProfile = 'ConsultingAI'
      GentleAiScope = 'Existing'
      ClientDisplayName = 'Equiv'
      ClientSlug = 'equiv'
      InitiativeDisplayName = 'Encargo'
      InitiativeId = 'EQV01'
      ProjectFolderName = 'pilot-hubmp-consultingai'
    }
  }
  @{
    Key = 'full'
    Folder = 'pilot-hubmp-full'
    Expected = 'full'
    Profile = 'Full'
    Args = @{
      StackProfile = 'Full'
      GentleAiScope = 'Existing'
      ClientDisplayName = 'Equiv'
      ClientSlug = 'equiv'
      InitiativeDisplayName = 'Encargo'
      InitiativeId = 'EQV01'
      ProjectFolderName = 'pilot-hubmp-full'
    }
  }
  @{
    Key = 'gentle-ai'
    Folder = 'pilot-hubmp-gentleai'
    Expected = 'gentle-ai'
    Profile = 'GentleAi'
    Args = @{
      StackProfile = 'GentleAi'
      GentleAiScope = 'Existing'
      ProjectName = 'equiv-app'
      ProjectFolderName = 'pilot-hubmp-gentleai'
    }
  }
)

$hubScript = Join-Path $scripts 'New-HubProject.ps1'
$common = @{
  IncludeDrawioMcp = $false
  IncludeBacklogMcp = $false
  IncludeArchiMcp = $false
  IncludeClaudeCoworkLayer = $false
  SkipSkillRegistryRefresh = $true
  SkipOpenCursor = $true
  Force = $true
}

try {
  foreach ($pilot in $pilots) {
    Write-Host ''
    Write-Host "--- generar $($pilot.Profile) → $($pilot.Folder) ---" -ForegroundColor Yellow
    $params = @{}
    foreach ($k in $pilot.Args.Keys) { $params[$k] = $pilot.Args[$k] }
    foreach ($k in $common.Keys) { $params[$k] = $common[$k] }

    & $hubScript @params

    $target = Join-Path $HubRoot "projects\$($pilot.Folder)"
    if (-not (Test-Path -LiteralPath $target)) {
      throw "No se creó el piloto: $target"
    }

    $gitOk = Test-Path -LiteralPath (Join-Path $target '.git')
    $gettingStarted = Test-Path -LiteralPath (Join-Path $target 'docs\GETTING-STARTED.md')

    $diagProfile = if ($pilot.Profile -eq 'Full') { 'ConsultingAI' } else { $pilot.Profile }
    $diag = Get-HubProjectDiagnostic -TargetPath $target -ExpectedProfile $diagProfile
    # Full solicita Full pero estructura = ConsultingAI; el diagnostic Auto lee requestedProfile.
    if ($pilot.Profile -eq 'Full') {
      $diag = Get-HubProjectDiagnostic -TargetPath $target -ExpectedProfile Auto
    }

    $snap = Get-EquivalenceProjectSnapshot -ProjectRoot $target -ExpectedProfile $pilot.Profile
    $expectedPath = Join-Path $HubRoot "tests\expected\$($pilot.Expected)\manifest.json"
    $contract = Assert-EquivalenceContractMatch -Snapshot $snap -ExpectedPath $expectedPath

    $entry = [ordered]@{
      profile = $pilot.Profile
      folder = $pilot.Folder
      path = $target
      gitInitialized = $gitOk
      gettingStarted = $gettingStarted
      diagnosticHealthy = [bool]$diag.healthy
      diagnosticIssues = @($diag.issues)
      contractOk = [bool]$contract.Ok
      contractErrors = @($contract.Errors)
      engramInLocalMcp = [bool]$snap.gentleAiMarkers.engramInLocalMcp
      metadata = $snap.metadata
    }
    $report.projects += $entry

    if (-not $gitOk) { $report.findings.Add("$($pilot.Folder): falta .git") }
    if (-not $gettingStarted) { $report.findings.Add("$($pilot.Folder): falta GETTING-STARTED") }
    if (-not $diag.healthy) { $report.findings.Add("$($pilot.Folder): diagnóstico: $($diag.issues -join '; ')") }
    if (-not $contract.Ok) { $report.findings.Add("$($pilot.Folder): contrato: $($contract.Errors -join '; ')") }
    if ($snap.gentleAiMarkers.engramInLocalMcp) { $report.findings.Add("$($pilot.Folder): Engram en MCP local") }

    Write-Host ("  git={0} gettingStarted={1} diag={2} contract={3}" -f $gitOk, $gettingStarted, $diag.healthy, $contract.Ok)
  }

  Assert-GlobalSentinelUnchanged -Before $beforeSentinel
  $report.sentinelOk = $true
  $report.findings.Add('sentinels globales sin cambios (mcp.json / gentle-ai state / gentle-ai.mdc)')

  $registry = Get-Content -LiteralPath $registryPath -Raw | ConvertFrom-Json
  $pilotNames = @($pilots | ForEach-Object { $_.Folder })
  $registered = @($registry.projects | Where-Object { $_.folderName -in $pilotNames })
  if ($registered.Count -ne $pilots.Count) {
    $report.findings.Add("registry: esperados $($pilots.Count) pilotos, hay $($registered.Count)")
  } else {
    $report.findings.Add("registry: $($registered.Count) entradas piloto con relativePath")
  }
}
finally {
  if (-not $KeepProjects) {
    Write-Host ''
    Write-Host '--- limpieza ---' -ForegroundColor Yellow
    foreach ($pilot in $pilots) {
      $target = Join-Path $HubRoot "projects\$($pilot.Folder)"
      if (Test-Path -LiteralPath $target) {
        Remove-Item -LiteralPath $target -Recurse -Force
        Write-Host "  removido $target"
      }
    }
    Copy-Item -LiteralPath $registryBackup -Destination $registryPath -Force
    $report.cleaned = $true
    $report.findings.Add('limpieza: proyectos piloto eliminados y registry restaurado')
  } else {
    $report.findings.Add('KeepProjects: proyectos y registry conservados')
  }
}

$report.finishedAt = (Get-Date).ToString('o')
$failed = @($report.projects | Where-Object { -not $_.gitInitialized -or -not $_.gettingStarted -or -not $_.diagnosticHealthy -or -not $_.contractOk -or $_.engramInLocalMcp })
$report.success = ($report.doctorOk -and $report.sentinelOk -and $failed.Count -eq 0)

$docsDir = Join-Path $HubRoot 'docs'
$outJson = Join-Path $docsDir 'PILOT-HUB-MULTIPLATFORM.json'
# Sin rutas personales en el artefacto versionado.
foreach ($proj in @($report.projects)) {
  if ($proj.path) {
    $proj.path = (($proj.path -replace [regex]::Escape($HubRoot), '<HUB_ROOT>') -replace '\\', '/')
  }
}
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $outJson -Encoding UTF8
Write-Host ''
Write-Host "Reporte JSON: $outJson" -ForegroundColor Cyan
if (-not $report.success) {
  Write-Host 'PILOTO CON HALLAZGOS' -ForegroundColor Red
  $report.findings | ForEach-Object { Write-Host "  - $_" }
  exit 2
}
Write-Host 'PILOTO OK' -ForegroundColor Green
$report.findings | ForEach-Object { Write-Host "  - $_" }
exit 0
