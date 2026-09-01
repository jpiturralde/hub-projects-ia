#Requires -Version 5.1
<#
.SYNOPSIS
  Prepara el entorno del proyecto hijo (portable). Consentimiento = ejecutar este script.

.DESCRIPTION
  Orden: hard-fail dual asistente / origen Windows en WSL → gaps guide-only required →
  Ensure no interactivo (asistente + backlog si aplica) → importar memoria pendiente del repo.
  No importa módulos del hub. Paridad Ensure: Choice I no interactivo (gentle-ai + backlog).

.EXAMPLE
  pwsh -File ./scripts/Setup-ProjectEnvironment.ps1
#>
[CmdletBinding()]
param(
  [string] $TargetPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- Portable helpers (parity with Test-ProjectEnvironment.ps1 / hub Ensure Choice I) ---

function Get-SetupRoot {
  param([string] $TargetPath)
  if (-not [string]::IsNullOrWhiteSpace($TargetPath)) {
    return [System.IO.Path]::GetFullPath($TargetPath)
  }
  return [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
}

function Get-SetupKnownToolIds { @('node', 'npm', 'npx', 'pandoc', 'backlog', 'archi', 'gentle-ai') }

function Resolve-SetupStackProfile {
  param([string] $StackProfileValue)
  $normalized = ([string]$StackProfileValue).Trim()
  switch -Regex ($normalized) {
    '^(?i)gentle-ai-only$' { return 'GentleAi' }
    '^(?i)gentleai$' { return 'GentleAi' }
    '^(?i)consulting-only$' { return 'Consulting' }
    '^(?i)consulting$' { return 'Consulting' }
    '^(?i)consulting-ai$' { return 'ConsultingAI' }
    '^(?i)consultingai$' { return 'ConsultingAI' }
    '^(?i)full$' { return 'Full' }
    default { return $normalized }
  }
}

function Build-SetupProjectRequires {
  param(
    [string] $StackProfileValue = 'Consulting',
    [bool] $IncludeDrawioMcp = $false,
    [bool] $IncludeBacklogMcp = $false,
    [bool] $IncludeArchiMcp = $false,
    [string] $GentleAiScope = 'none'
  )
  $profile = Resolve-SetupStackProfile -StackProfileValue $StackProfileValue
  $isConsulting = $profile -in @('Consulting', 'ConsultingAI', 'Full')
  $scope = if ([string]::IsNullOrWhiteSpace($GentleAiScope)) { 'none' } else { $GentleAiScope.Trim().ToLowerInvariant() }
  $levels = [ordered]@{}
  if ($IncludeDrawioMcp) {
    $levels['node'] = 'required'; $levels['npm'] = 'required'; $levels['npx'] = 'required'
  }
  if ($IncludeArchiMcp) {
    $levels['archi'] = 'required'; $levels['node'] = 'required'; $levels['npm'] = 'required'
  }
  if ($isConsulting) {
    $levels['pandoc'] = 'optional'
    if ($IncludeBacklogMcp) { $levels['backlog'] = 'required' } else { $levels['backlog'] = 'optional' }
  }
  if ($scope -in @('global', 'workspace')) { $levels['gentle-ai'] = 'required' }
  $tools = [System.Collections.Generic.List[object]]::new()
  foreach ($id in (Get-SetupKnownToolIds)) {
    if ($levels.Contains($id)) { $tools.Add([ordered]@{ id = $id; level = [string]$levels[$id] }) }
  }
  return [ordered]@{ version = 1; tools = @($tools.ToArray()) }
}

function Get-SetupProjectContext {
  param([string] $Root)
  $engagementPath = Join-Path $Root '.consulting-engagement.json'
  $profilePath = Join-Path $Root '.project-profile.json'
  $meta = $null; $metaKind = $null
  if (Test-Path -LiteralPath $engagementPath -PathType Leaf) {
    $meta = Get-Content -LiteralPath $engagementPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $metaKind = 'engagement'
  } elseif (Test-Path -LiteralPath $profilePath -PathType Leaf) {
    $meta = Get-Content -LiteralPath $profilePath -Raw -Encoding UTF8 | ConvertFrom-Json
    $metaKind = 'profile'
  } else {
    throw "No se encontro metadata del proyecto en $Root"
  }
  $stack = if ($meta.PSObject.Properties.Name -contains 'stackProfile') { [string]$meta.stackProfile } else { 'consulting-only' }
  $gentleScope = 'none'
  if ($meta.PSObject.Properties.Name -contains 'gentleAiScope' -and $meta.gentleAiScope) {
    $gentleScope = ([string]$meta.gentleAiScope).Trim().ToLowerInvariant()
  }
  $requires = $null
  if ($meta.PSObject.Properties.Name -contains 'requires' -and $null -ne $meta.requires) {
    $requires = $meta.requires
  } else {
    $requires = Build-SetupProjectRequires `
      -StackProfileValue $stack `
      -IncludeDrawioMcp ([bool]($(if ($meta.PSObject.Properties.Name -contains 'includeDrawioMcp') { $meta.includeDrawioMcp } else { $false }))) `
      -IncludeBacklogMcp ([bool]($(if ($meta.PSObject.Properties.Name -contains 'includeBacklogMcp') { $meta.includeBacklogMcp } else { $false }))) `
      -IncludeArchiMcp ([bool]($(if ($meta.PSObject.Properties.Name -contains 'includeArchiMcp') { $meta.includeArchiMcp } else { $false }))) `
      -GentleAiScope $gentleScope
  }
  $engramProject = $null
  if ($meta.PSObject.Properties.Name -contains 'engramProject' -and -not [string]::IsNullOrWhiteSpace([string]$meta.engramProject)) {
    $engramProject = ([string]$meta.engramProject).Trim()
  } else {
    $engramProject = (Split-Path -Leaf $Root)
  }
  return [pscustomobject]@{
    Root = $Root
    MetaKind = $metaKind
    Meta = $meta
    StackProfile = (Resolve-SetupStackProfile -StackProfileValue $stack)
    GentleAiScope = $gentleScope
    Requires = $requires
    EngramProject = $engramProject
  }
}

function Test-SetupIsLinuxLike {
  return [bool]($IsLinux -or (-not [string]::IsNullOrWhiteSpace($env:WSL_DISTRO_NAME)))
}

function Test-SetupWindowsOriginPath {
  param([string] $Path)
  if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
  if ($Path -match '(?i)^/mnt/[a-z]/') { return $true }
  if ($Path -match '(?i)\.exe$') { return $true }
  return $false
}

function Get-SetupCommandPaths {
  param([string] $Name)
  $cmds = @(Get-Command $Name -All -ErrorAction SilentlyContinue)
  return @($cmds | ForEach-Object { $_.Source } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

function Test-SetupVersionOk {
  param([string] $Path)
  try {
    $null = & $Path --version 2>&1
    return ($LASTEXITCODE -eq 0)
  } catch { return $false }
}

function Test-SetupGe1Usable {
  param([string] $Name)
  $usable = @((Get-SetupCommandPaths -Name $Name) | Where-Object {
    if ((Test-SetupIsLinuxLike) -and (Test-SetupWindowsOriginPath -Path $_)) { return $false }
    Test-SetupVersionOk -Path $_
  })
  return ($usable.Count -ge 1)
}

function Test-SetupGentleAiCli {
  $raw = @(Get-SetupCommandPaths -Name 'gentle-ai')
  $linuxLike = Test-SetupIsLinuxLike
  $allowed = @($raw | Where-Object { -not ($linuxLike -and (Test-SetupWindowsOriginPath -Path $_)) })
  $rejected = @($raw | Where-Object { $linuxLike -and (Test-SetupWindowsOriginPath -Path $_) })
  if ($allowed.Count -eq 1) { return [pscustomobject]@{ Ok = $true; Status = 'Ok'; Path = $allowed[0] } }
  if ($allowed.Count -gt 1) { return [pscustomobject]@{ Ok = $false; Status = 'Duplicate'; Path = $null } }
  if ($rejected.Count -gt 0) { return [pscustomobject]@{ Ok = $false; Status = 'WindowsOriginRejected'; Path = $null } }
  return [pscustomobject]@{ Ok = $false; Status = 'Missing'; Path = $null }
}

function Test-SetupDualGentleAi {
  param([string] $Root)
  $userHome = if (-not [string]::IsNullOrWhiteSpace($env:TEST_USER_HOME)) { $env:TEST_USER_HOME }
  else { [Environment]::GetFolderPath('UserProfile') }
  $globalMarkers = @(
    (Join-Path $userHome '.cursor/rules/gentle-ai.mdc')
    (Join-Path $userHome '.cursor/agents/sdd-init.md')
    (Join-Path $userHome '.cursor/skills/sdd-init/SKILL.md')
  )
  $workspaceMarkers = @(
    (Join-Path $Root '.cursor/rules/gentle-ai.mdc')
    (Join-Path $Root '.cursor/agents/sdd-init.md')
    (Join-Path $Root '.cursor/skills/sdd-init/SKILL.md')
  )
  $globalState = Join-Path $userHome '.gentle-ai/state.json'
  $stateMentionsCursor = $false
  if (Test-Path -LiteralPath $globalState -PathType Leaf) {
    try { $stateMentionsCursor = (Get-Content -LiteralPath $globalState -Raw -Encoding UTF8) -match '(?i)"cursor"' }
    catch { $stateMentionsCursor = $false }
  }
  $globalInstalled = (@($globalMarkers | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf }).Count -gt 0) -or $stateMentionsCursor
  $workspaceInstalled = (@($workspaceMarkers | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf }).Count -gt 0)
  return ($globalInstalled -and $workspaceInstalled)
}

function Get-SetupRequiredLevels {
  param($Requires)
  $map = [ordered]@{}
  foreach ($id in (Get-SetupKnownToolIds)) { $map[$id] = 'absent' }
  if ($null -ne $Requires -and ($Requires.PSObject.Properties.Name -contains 'tools')) {
    foreach ($tool in @($Requires.tools)) {
      $id = [string]$tool.id
      if ($map.Contains($id)) {
        $level = ([string]$tool.level).Trim().ToLowerInvariant()
        if ($level -in @('required', 'optional', 'absent')) { $map[$id] = $level }
      }
    }
  }
  return $map
}

function Install-SetupGentleAiCli {
  $goPaths = @((Get-SetupCommandPaths -Name 'go') | Where-Object { Test-SetupVersionOk -Path $_ })
  if ($goPaths.Count -lt 1) {
    throw 'Para instalar el asistente de desarrollo hace falta Go usable en PATH. Instala Go y volve a ejecutar.'
  }
  Write-Host 'Preparando el asistente de desarrollo...'
  & $goPaths[0] install github.com/gentleman-programming/gentle-ai/v2/cmd/gentle-ai@latest
  if ($LASTEXITCODE -ne 0) { throw "La instalacion del asistente fallo (codigo $LASTEXITCODE)." }
  $goPath = (& $goPaths[0] env GOPATH | Select-Object -First 1)
  if ($goPath) {
    $binPath = Join-Path $goPath.Trim() 'bin'
    if (($env:PATH -split [System.IO.Path]::PathSeparator) -notcontains $binPath) {
      $env:PATH = "$binPath$([System.IO.Path]::PathSeparator)$env:PATH"
    }
  }
  $cli = Test-SetupGentleAiCli
  if (-not $cli.Ok) { throw "La instalacion termino pero el asistente no quedo usable ($($cli.Status))." }
  return $cli.Path
}

function Install-SetupBacklogCli {
  if (-not (Test-SetupGe1Usable -Name 'node') -or -not (Test-SetupGe1Usable -Name 'npm')) {
    throw 'Node.js/npm son necesarios para instalar backlog. Instala Node LTS y volve a ejecutar.'
  }
  $npm = @((Get-SetupCommandPaths -Name 'npm') | Where-Object { Test-SetupVersionOk -Path $_ })[0]
  Write-Host 'Preparando backlog...'
  & $npm install -g backlog.md@latest --include=optional
  if ($LASTEXITCODE -ne 0) { throw "npm install de backlog fallo (codigo $LASTEXITCODE)." }
}

function Invoke-SetupGentleAiComponents {
  param([string] $CliPath, [string] $Scope, [string] $Root)
  if ($Scope -notin @('global', 'workspace')) { return }
  $working = if ($Scope -eq 'workspace') { $Root } else {
    if (-not [string]::IsNullOrWhiteSpace($env:TEST_USER_HOME)) { $env:TEST_USER_HOME }
    else { [Environment]::GetFolderPath('UserProfile') }
  }
  Write-Host 'Configurando componentes del asistente...'
  Push-Location $working
  try {
    & $CliPath install --agent cursor --scope $Scope --component engram,sdd,skills
    if ($LASTEXITCODE -ne 0) { throw "Configuracion del asistente fallo (codigo $LASTEXITCODE)." }
  } finally { Pop-Location }
}

function Get-SetupEngramChunkFileCount {
  param([string] $Root)
  $chunksDir = Join-Path $Root '.engram/chunks'
  if (-not (Test-Path -LiteralPath $chunksDir -PathType Container)) { return 0 }
  return @((Get-ChildItem -LiteralPath $chunksDir -File -ErrorAction SilentlyContinue)).Count
}

function Get-SetupEngramPendingCount {
  param([string] $Root)
  $engram = Get-Command engram -ErrorAction SilentlyContinue
  if ($engram) {
    try {
      $out = & $engram.Source sync --status 2>&1 | Out-String
      if ($out -match '(?i)Pending import:\s*(\d+)') { return [int]$Matches[1] }
      return 0
    } catch { return $null }
  }
  # Sin CLI: chunks en el repo cuentan como pendientes de importar (manifest solo → 0).
  $chunkCount = Get-SetupEngramChunkFileCount -Root $Root
  if ($chunkCount -gt 0) { return $chunkCount }
  return 0
}

function Invoke-SetupEngramImport {
  $engram = Get-Command engram -ErrorAction SilentlyContinue
  if (-not $engram) { throw 'Herramientas de memoria no disponibles en PATH.' }
  Write-Host 'Sincronizando memoria del proyecto...'
  & $engram.Source sync --import
  if ($LASTEXITCODE -ne 0) { throw "No se pudo sincronizar la memoria del proyecto (codigo $LASTEXITCODE)." }
}

# --- Main ---

$root = Get-SetupRoot -TargetPath $TargetPath
$ctx = Get-SetupProjectContext -Root $root
$levels = Get-SetupRequiredLevels -Requires $ctx.Requires
$cwdKey = Split-Path -Leaf $root
if ($cwdKey -ne $ctx.EngramProject) {
  Write-Host "Aviso: la memoria del proyecto usa el nombre '$($ctx.EngramProject)' (carpeta actual: '$cwdKey')." -ForegroundColor Yellow
}

# 1) Hard-fail before any install
if (Test-SetupDualGentleAi -Root $root) {
  Write-Host 'Hay una configuracion duplicada del asistente (global y en el workspace). Corregila manualmente y volve a ejecutar.' -ForegroundColor Red
  exit 2
}
$gaCli = Test-SetupGentleAiCli
if ($gaCli.Status -eq 'WindowsOriginRejected') {
  Write-Host 'Hay un asistente de Windows bajo WSL. Usa la instalacion nativa de Linux y volve a ejecutar.' -ForegroundColor Red
  exit 2
}
if ($gaCli.Status -eq 'Duplicate') {
  Write-Host 'Hay mas de un CLI del asistente en PATH. Deja solo uno nativo y volve a ejecutar.' -ForegroundColor Red
  exit 2
}

# 2) Guide-only required
$guideIds = @('node', 'npm', 'npx', 'pandoc', 'archi')
foreach ($id in $guideIds) {
  if ($levels[$id] -ne 'required') { continue }
  $ok = $false
  if ($id -eq 'archi') {
    $ok = $true # path-configured; guide only if probe needed later
    Write-Host "Nota: archi se configura por ruta en MCP (ver docs). Continua si ya esta listo." -ForegroundColor Yellow
  } else {
    $ok = Test-SetupGe1Usable -Name $id
  }
  if (-not $ok) {
    Write-Host "Falta $id (obligatorio). Instala la herramienta nativa de tu SO y volve a ejecutar Preparar entorno." -ForegroundColor Red
    exit 2
  }
}

# 3) Ensure gentle-ai / backlog (Choice I non-interactive)
if ($levels['gentle-ai'] -eq 'required') {
  if ($ctx.GentleAiScope -notin @('global', 'workspace')) {
    Write-Host 'Este perfil requiere el asistente pero el alcance no esta definido en la metadata. Regenera/actualiza el proyecto desde el hub.' -ForegroundColor Red
    exit 2
  }
  if (-not $gaCli.Ok) {
    try { $null = Install-SetupGentleAiCli }
    catch {
      Write-Host $_.Exception.Message -ForegroundColor Red
      exit 2
    }
    $gaCli = Test-SetupGentleAiCli
  }
  if ($gaCli.Ok) {
    try { Invoke-SetupGentleAiComponents -CliPath $gaCli.Path -Scope $ctx.GentleAiScope -Root $root }
    catch {
      Write-Host $_.Exception.Message -ForegroundColor Red
      exit 2
    }
  }
}

if ($levels['backlog'] -eq 'required') {
  $backlogOk = $false
  try {
    $null = & backlog --version 2>&1
    $backlogOk = ($LASTEXITCODE -eq 0)
  } catch { $backlogOk = $false }
  if (-not $backlogOk) {
    try { Install-SetupBacklogCli }
    catch {
      Write-Host $_.Exception.Message -ForegroundColor Red
      exit 2
    }
  }
}

# 4) Engram import (pending-gated; mere manifest.json is not a fail)
$pending = Get-SetupEngramPendingCount -Root $root
$engramCmd = Get-Command engram -ErrorAction SilentlyContinue
if ($null -ne $pending -and $pending -gt 0) {
  if (-not $engramCmd) {
    Write-Host 'Hay memoria pendiente de importar pero faltan herramientas de memoria en PATH.' -ForegroundColor Red
    exit 2
  }
  try { Invoke-SetupEngramImport }
  catch {
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 2
  }
} elseif ($engramCmd -and (Test-Path -LiteralPath (Join-Path $root '.engram') -PathType Container)) {
  try { $null = & $engramCmd.Source sync --import 2>&1 } catch { }
}

Write-Host 'Entorno preparado.' -ForegroundColor Green
exit 0
