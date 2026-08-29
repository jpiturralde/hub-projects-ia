#Requires -Version 5.1
<#
.SYNOPSIS
  Detect-only environment doctor for a generated hub child project (portable).

.DESCRIPTION
  Reads local root metadata / requires. When schemaVersion < 4 or requires is
  missing, derives the same vector as hub Build-HubProjectRequires (inline pure
  rules). Does NOT import hub modules. Never installs, syncs, upgrades, or writes
  mcp.json / Engram.

  Exit 0 when all required checks pass and local-mcp is not broken.
  Exit 2 when any required check fails or local-mcp is broken.

.EXAMPLE
  pwsh -File ./scripts/Test-ProjectEnvironment.ps1
  pwsh -File ./scripts/Test-ProjectEnvironment.ps1 -AsJson
#>
[CmdletBinding()]
param(
  [string] $TargetPath,
  [switch] $AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- Pure requires derivation (parity with hub Build-HubProjectRequires) ---

function Get-PortableKnownToolIds {
  return @('node', 'npm', 'npx', 'pandoc', 'backlog', 'archi', 'gentle-ai')
}

function Resolve-PortableStackProfile {
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

function Build-PortableProjectRequires {
  param(
    [string] $StackProfileValue = 'Consulting',
    [bool] $IncludeDrawioMcp = $false,
    [bool] $IncludeBacklogMcp = $false,
    [bool] $IncludeArchiMcp = $false,
    [string] $GentleAiScope = 'none'
  )
  $profile = Resolve-PortableStackProfile -StackProfileValue $StackProfileValue
  $isConsulting = $profile -in @('Consulting', 'ConsultingAI', 'Full')
  $scope = if ([string]::IsNullOrWhiteSpace($GentleAiScope)) { 'none' } else { $GentleAiScope.Trim().ToLowerInvariant() }

  $levels = [ordered]@{}
  if ($IncludeDrawioMcp) {
    $levels['node'] = 'required'
    $levels['npm'] = 'required'
    $levels['npx'] = 'required'
  }
  if ($IncludeArchiMcp) {
    $levels['archi'] = 'required'
    $levels['node'] = 'required'
    $levels['npm'] = 'required'
  }
  if ($isConsulting) {
    $levels['pandoc'] = 'optional'
    if ($IncludeBacklogMcp) { $levels['backlog'] = 'required' }
    else { $levels['backlog'] = 'optional' }
  }
  if ($scope -in @('global', 'workspace')) {
    $levels['gentle-ai'] = 'required'
  }

  $tools = [System.Collections.Generic.List[object]]::new()
  foreach ($id in (Get-PortableKnownToolIds)) {
    if ($levels.Contains($id)) {
      $tools.Add([ordered]@{ id = $id; level = [string]$levels[$id] })
    }
  }
  return [ordered]@{ version = 1; tools = @($tools.ToArray()) }
}

function ConvertTo-PortableNormalizedRequires {
  param($Requires)
  $map = [ordered]@{}
  foreach ($id in (Get-PortableKnownToolIds)) { $map[$id] = 'absent' }
  if ($null -ne $Requires -and ($Requires.PSObject.Properties.Name -contains 'tools') -and $null -ne $Requires.tools) {
    foreach ($tool in @($Requires.tools)) {
      $id = [string]$tool.id
      if ($map.Contains($id)) {
        $level = ([string]$tool.level).Trim().ToLowerInvariant()
        if ($level -in @('required', 'optional', 'absent')) { $map[$id] = $level }
      }
    }
  }
  $tools = [System.Collections.Generic.List[object]]::new()
  foreach ($id in (Get-PortableKnownToolIds)) {
    $tools.Add([pscustomobject]@{ id = $id; level = [string]$map[$id] })
  }
  $version = 1
  if ($null -ne $Requires -and ($Requires.PSObject.Properties.Name -contains 'version') -and $null -ne $Requires.version) {
    $version = [int]$Requires.version
  }
  return [pscustomobject]@{ version = $version; tools = @($tools.ToArray()) }
}

function Get-PortableProjectContext {
  param([Parameter(Mandatory = $true)][string] $Root)
  $engagementPath = Join-Path $Root '.consulting-engagement.json'
  $profilePath = Join-Path $Root '.project-profile.json'

  $meta = $null
  $metaKind = $null
  if (Test-Path -LiteralPath $engagementPath) {
    $meta = Get-Content -LiteralPath $engagementPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $metaKind = 'engagement'
  } elseif (Test-Path -LiteralPath $profilePath) {
    $meta = Get-Content -LiteralPath $profilePath -Raw -Encoding UTF8 | ConvertFrom-Json
    $metaKind = 'profile'
  } else {
    throw "No se encontro metadata de proyecto en: $Root"
  }

  $schemaVersion = 0
  if ($meta.PSObject.Properties.Name -contains 'schemaVersion' -and $null -ne $meta.schemaVersion) {
    $schemaVersion = [int]$meta.schemaVersion
  }

  $includeDrawio = $false
  $includeBacklog = $false
  $includeArchi = $false
  $gentleScope = 'none'
  if ($meta.PSObject.Properties.Name -contains 'includeDrawioMcp') { $includeDrawio = [bool]$meta.includeDrawioMcp }
  if ($meta.PSObject.Properties.Name -contains 'includeBacklogMcp') { $includeBacklog = [bool]$meta.includeBacklogMcp }
  if ($meta.PSObject.Properties.Name -contains 'includeArchiMcp') { $includeArchi = [bool]$meta.includeArchiMcp }
  if ($meta.PSObject.Properties.Name -contains 'gentleAiScope' -and $meta.gentleAiScope) {
    $gentleScope = [string]$meta.gentleAiScope
  } elseif ($metaKind -eq 'profile') {
    $gentleScope = 'global'
  }

  if ($schemaVersion -ge 4 -and ($meta.PSObject.Properties.Name -contains 'requires') -and $null -ne $meta.requires) {
    $requires = ConvertTo-PortableNormalizedRequires -Requires $meta.requires
  } else {
    $stackProfileValue = if ($metaKind -eq 'profile') { 'gentle-ai-only' } else { [string]$meta.stackProfile }
    $built = Build-PortableProjectRequires `
      -StackProfileValue $stackProfileValue `
      -IncludeDrawioMcp $includeDrawio `
      -IncludeBacklogMcp $includeBacklog `
      -IncludeArchiMcp $includeArchi `
      -GentleAiScope $gentleScope
    $requires = ConvertTo-PortableNormalizedRequires -Requires ([pscustomobject]$built)
  }

  return [pscustomobject]@{
    Requires = $requires
    IncludeDrawioMcp = $includeDrawio
    IncludeBacklogMcp = $includeBacklog
    IncludeArchiMcp = $includeArchi
    LocalMcpToolsRequired = ($includeDrawio -or $includeBacklog -or $includeArchi)
  }
}

# --- Portable probes (detect-only; never write) ---

function Test-PortableWindowsOriginPath {
  param([string] $Path)
  if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
  $full = [System.IO.Path]::GetFullPath($Path)
  if ($full -match '(?i)\.exe$') { return $true }
  $unix = ($full -replace '\\', '/')
  if ($unix -match '^/mnt/[a-z](?:/|$)') { return $true }
  return $false
}

function Get-PortableRawCommandPaths {
  param([Parameter(Mandatory = $true)][string] $Name)
  $paths = @()
  Get-Command $Name -All -ErrorAction SilentlyContinue | ForEach-Object {
    $candidate = if ($_.Path) { $_.Path } elseif ($_.Source) { $_.Source } else { $null }
    if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
      $paths += [System.IO.Path]::GetFullPath($candidate)
    }
  }
  return @($paths | Sort-Object -Unique)
}

function Get-PortableCommandPaths {
  param(
    [Parameter(Mandatory = $true)][string] $Name,
    [switch] $AllowWindowsExecutable
  )
  # Parity with hub Get-HubCommandExecutablePaths / Test-HubCommandAllowedOnPlatform
  $paths = @(Get-PortableRawCommandPaths -Name $Name)
  $linuxLike = Test-PortableIsLinuxLike
  return @($paths | Where-Object {
    if (-not $linuxLike) { return $true }
    if (-not (Test-PortableWindowsOriginPath -Path $_)) { return $true }
    if ($AllowWindowsExecutable -and $Name -eq 'cursor') { return $true }
    return $false
  })
}

function Test-PortableVersionOk {
  param([Parameter(Mandatory = $true)][string] $Path)
  try {
    $null = & $Path --version 2>&1
    return ($LASTEXITCODE -eq 0)
  } catch {
    return $false
  }
}

function Test-PortableIsLinuxLike {
  return [bool]($IsLinux -or (-not [string]::IsNullOrWhiteSpace($env:WSL_DISTRO_NAME)))
}

function Test-PortableGe1Usable {
  param([Parameter(Mandatory = $true)][string] $Name)
  $raw = @(Get-PortableCommandPaths -Name $Name)
  $usable = @($raw | Where-Object { Test-PortableVersionOk -Path $_ })
  return [pscustomobject]@{
    Ok = ($usable.Count -ge 1)
    Status = if ($usable.Count -ge 1) { 'Ok' } else { 'Missing' }
    Message = if ($usable.Count -ge 1) { "$Name usable en PATH" } else { "No hay $Name usable en PATH" }
  }
}

function Test-PortableGentleAiCli {
  $raw = @(Get-PortableRawCommandPaths -Name 'gentle-ai')
  $linuxLike = Test-PortableIsLinuxLike
  $allowed = @($raw | Where-Object {
    if (-not $linuxLike) { return $true }
    -not (Test-PortableWindowsOriginPath -Path $_)
  })
  $rejected = @($raw | Where-Object {
    $linuxLike -and (Test-PortableWindowsOriginPath -Path $_)
  })

  if ($allowed.Count -eq 1) {
    return [pscustomobject]@{
      Ok = $true; Status = 'Ok'
      Message = 'CLI del asistente de desarrollo usable (nativo)'
    }
  }
  if ($allowed.Count -gt 1) {
    return [pscustomobject]@{
      Ok = $false; Status = 'Duplicate'
      Message = 'Hay mas de un CLI del asistente de desarrollo en PATH — deja solo uno nativo.'
    }
  }
  if ($rejected.Count -gt 0) {
    return [pscustomobject]@{
      Ok = $false; Status = 'WindowsOriginRejected'
      Message = 'Hay un CLI de asistente de Windows bajo WSL — usa la instalacion nativa de Linux.'
    }
  }
  return [pscustomobject]@{
    Ok = $false; Status = 'Missing'
    Message = 'Falta el CLI del asistente de desarrollo requerido por este proyecto.'
  }
}

function Test-PortableDualGentleAi {
  param([string] $Root)
  $userHome = if (-not [string]::IsNullOrWhiteSpace($env:TEST_USER_HOME)) {
    $env:TEST_USER_HOME
  } else {
    [Environment]::GetFolderPath('UserProfile')
  }
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

function Test-PortableBacklogCli {
  # Parity with hub Resolve-BacklogCliStatus (eq1 / Duplicate → fail, not ge1)
  $raw = @(Get-PortableRawCommandPaths -Name 'backlog')
  $linuxLike = Test-PortableIsLinuxLike
  $allowed = @($raw | Where-Object {
    if (-not $linuxLike) { return $true }
    -not (Test-PortableWindowsOriginPath -Path $_)
  })
  if ($allowed.Count -eq 1) {
    $ok = Test-PortableVersionOk -Path $allowed[0]
    return [pscustomobject]@{
      Ok = $ok
      Status = if ($ok) { 'Ok' } else { 'Failed' }
      Message = if ($ok) { 'CLI de backlog usable' } else { 'CLI backlog encontrada pero no responde a --version.' }
    }
  }
  if ($allowed.Count -gt 1) {
    $valid = @($allowed | Where-Object { Test-PortableVersionOk -Path $_ })
    if ($valid.Count -eq 1) {
      return [pscustomobject]@{
        Ok = $true; Status = 'Ok'; Message = 'CLI de backlog usable'
      }
    }
    if ($valid.Count -gt 1) {
      return [pscustomobject]@{
        Ok = $false; Status = 'Duplicate'
        Message = 'Hay mas de una CLI de backlog valida en PATH — deja solo una nativa.'
      }
    }
    return [pscustomobject]@{
      Ok = $false; Status = 'Failed'
      Message = 'CLI backlog en PATH pero ninguna responde a --version.'
    }
  }
  if ($raw.Count -gt 0) {
    return [pscustomobject]@{
      Ok = $false; Status = 'WindowsOriginRejected'
      Message = 'CLI backlog detectada solo como ejecutable Windows (invalido en Linux/WSL).'
    }
  }
  return [pscustomobject]@{
    Ok = $false; Status = 'Missing'
    Message = 'Falta la CLI de backlog requerida por este proyecto.'
  }
}

function Test-PortableArchiPath {
  param([string] $Path)
  if ([string]::IsNullOrWhiteSpace($Path)) {
    return [pscustomobject]@{ Ok = $false; Status = 'Missing'; Message = 'Falta o es invalida la ruta al servidor Archi MCP.' }
  }
  if (-not [System.IO.Path]::IsPathRooted($Path.Trim())) {
    return [pscustomobject]@{ Ok = $false; Status = 'Invalid'; Message = 'La ruta de Archi MCP debe ser absoluta.' }
  }
  $resolved = [System.IO.Path]::GetFullPath($Path.Trim())
  if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) {
    return [pscustomobject]@{ Ok = $false; Status = 'Missing'; Message = "No se encuentra Archi MCP en: $resolved" }
  }
  if ((Test-PortableIsLinuxLike) -and (Test-PortableWindowsOriginPath -Path $resolved)) {
    return [pscustomobject]@{ Ok = $false; Status = 'Invalid'; Message = 'Archi MCP no puede apuntar a una ruta Windows desde Linux/WSL.' }
  }
  return [pscustomobject]@{ Ok = $true; Status = 'Ok'; Message = 'Ruta Archi MCP configurada' }
}

function Get-PortableArchiPathFromMcp {
  param([string] $McpJsonPath)
  if (-not (Test-Path -LiteralPath $McpJsonPath -PathType Leaf)) { return $null }
  try {
    $config = Get-Content -LiteralPath $McpJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if (-not $config.mcpServers -or -not $config.mcpServers.archi) { return $null }
    $archi = $config.mcpServers.archi
    if ($archi.PSObject.Properties.Name -contains 'args' -and $archi.args -and @($archi.args).Count -gt 0) {
      return [string]$archi.args[0]
    }
  } catch {
    return $null
  }
  return $null
}

function Get-PortableLocalMcpCheck {
  param(
    [Parameter(Mandatory = $true)][string] $Root,
    [bool] $RequiresLocalMcp
  )
  $mcpPath = Join-Path $Root '.cursor/mcp.json'
  $level = if ($RequiresLocalMcp) { 'required' } else { 'optional' }

  if (-not (Test-Path -LiteralPath $mcpPath -PathType Leaf)) {
    return [pscustomobject]@{
      id = 'local-mcp'
      level = $level
      pass = (-not $RequiresLocalMcp)
      state = 'not-materialized'
      message = if ($RequiresLocalMcp) {
        'Aun no hay archivo MCP local y este proyecto necesita servidores locales.'
      } else {
        'Aun no hay archivo MCP local — es normal tras un clone si no hace falta materializarlo.'
      }
    }
  }

  try {
    $config = Get-Content -LiteralPath $mcpPath -Raw -Encoding UTF8 | ConvertFrom-Json
  } catch {
    return [pscustomobject]@{
      id = 'local-mcp'; level = 'required'; pass = $false; state = 'broken'
      message = 'El archivo MCP local tiene problemas (JSON invalido).'
    }
  }

  $serverNames = @()
  if ($null -ne $config.mcpServers) {
    $serverNames = @($config.mcpServers.PSObject.Properties | ForEach-Object { $_.Name })
  }
  if (@($serverNames | Where-Object { $_ -eq 'engram' }).Count -gt 0) {
    return [pscustomobject]@{
      id = 'local-mcp'; level = 'required'; pass = $false; state = 'broken'
      message = 'El archivo MCP local tiene una entrada inesperada de memoria persistente.'
    }
  }

  foreach ($name in $serverNames) {
    $server = $config.mcpServers.$name
    if ($null -eq $server) { continue }
    if ($name -eq 'archi' -and ($server.PSObject.Properties.Name -contains 'args') -and $server.args -and @($server.args).Count -gt 0) {
      $archiProbe = Test-PortableArchiPath -Path ([string]$server.args[0])
      if (-not $archiProbe.Ok) {
        return [pscustomobject]@{
          id = 'local-mcp'; level = 'required'; pass = $false; state = 'broken'
          message = "MCP local con rutas incorrectas (archi): $($archiProbe.Message)"
        }
      }
    }
    if ($name -eq 'backlog' -and ($server.PSObject.Properties.Name -contains 'args')) {
      $argsList = @($server.args)
      $cwdIdx = [array]::IndexOf($argsList, '--cwd')
      if ($cwdIdx -ge 0 -and ($cwdIdx + 1) -lt $argsList.Count) {
        $cwd = [string]$argsList[$cwdIdx + 1]
        if (-not [string]::IsNullOrWhiteSpace($cwd) -and -not (Test-Path -LiteralPath $cwd -PathType Container)) {
          return [pscustomobject]@{
            id = 'local-mcp'; level = 'required'; pass = $false; state = 'broken'
            message = "MCP local con rutas incorrectas (backlog cwd inexistente): $cwd"
          }
        }
      }
    }
  }

  return [pscustomobject]@{
    id = 'local-mcp'
    level = $level
    pass = $true
    state = 'configured'
    message = 'El archivo MCP local parece listo.'
  }
}

function Invoke-PortableProjectEnvironmentDoctor {
  param([Parameter(Mandatory = $true)][string] $Root)

  $ctx = Get-PortableProjectContext -Root $Root
  $requires = $ctx.Requires
  $mcpPath = Join-Path $Root '.cursor/mcp.json'
  $checks = [System.Collections.Generic.List[object]]::new()

  foreach ($tool in @($requires.tools)) {
    $level = [string]$tool.level
    if ($level -eq 'absent') { continue }
    $id = [string]$tool.id
    $pass = $false
    $state = 'missing'
    $message = $null

    switch ($id) {
      { $_ -in @('node', 'npm', 'npx', 'pandoc') } {
        $probe = Test-PortableGe1Usable -Name $id
        $pass = [bool]$probe.Ok
        $state = if ($pass) { 'ok' } else { 'missing' }
        $message = $probe.Message
      }
      'gentle-ai' {
        $probe = Test-PortableGentleAiCli
        $pass = [bool]$probe.Ok
        $state = if ($pass) { 'ok' } elseif ($probe.Status -eq 'Missing') { 'missing' } else { 'failed' }
        $message = $probe.Message
      }
      'backlog' {
        $probe = Test-PortableBacklogCli
        $pass = [bool]$probe.Ok
        $state = if ($pass) { 'ok' } elseif ($probe.Status -eq 'Missing') { 'missing' } else { 'failed' }
        $message = $probe.Message
      }
      'archi' {
        $archiPath = Get-PortableArchiPathFromMcp -McpJsonPath $mcpPath
        $probe = Test-PortableArchiPath -Path $archiPath
        $pass = [bool]$probe.Ok
        $state = if ($pass) { 'ok' } elseif ($probe.Status -eq 'Missing') { 'missing' } else { 'failed' }
        $message = $probe.Message
      }
      default {
        $pass = $false
        $state = 'n/a'
        $message = "Herramienta desconocida: $id"
      }
    }

    $checks.Add([pscustomobject]@{
        id = $id; level = $level; pass = $pass; state = $state; message = $message
      })
  }

  $mcpCheck = Get-PortableLocalMcpCheck -Root $Root -RequiresLocalMcp ([bool]$ctx.LocalMcpToolsRequired)
  $checks.Add($mcpCheck)

  if (Test-PortableDualGentleAi -Root $Root) {
    $checks.Add([pscustomobject]@{
        id = 'gentle-ai-dual'
        level = 'optional'
        pass = $false
        state = 'failed'
        message = 'Hay instalacion duplicada del asistente (global y en este workspace). Es solo diagnostico; no se modifica nada automaticamente.'
      })
  }

  $hasBrokenMcp = @($checks | Where-Object { [string]$_.id -eq 'local-mcp' -and [string]$_.state -eq 'broken' }).Count -gt 0
  $requiredFailed = @($checks | Where-Object { [string]$_.level -eq 'required' -and -not [bool]$_.pass })
  $ok = ($requiredFailed.Count -eq 0) -and (-not $hasBrokenMcp)
  $exitCode = if ($ok) { 0 } else { 2 }
  return [pscustomobject]@{
    ok = $ok
    exitCode = $exitCode
    checks = @($checks.ToArray())
  }
}

# --- Entry ---

if ([string]::IsNullOrWhiteSpace($TargetPath)) {
  if ((Split-Path -Leaf $PSScriptRoot) -ne 'scripts') {
    throw 'Indica -TargetPath al proyecto hijo cuando ejecutas la plantilla desde el hub.'
  }
  $TargetPath = Split-Path -Parent $PSScriptRoot
}
$TargetPath = [System.IO.Path]::GetFullPath($TargetPath)

# Portable-only: never Import-Module hub libs from a child copy.
$result = Invoke-PortableProjectEnvironmentDoctor -Root $TargetPath

if ($AsJson) {
  $result | Select-Object ok, exitCode, checks | ConvertTo-Json -Depth 6
  if ($MyInvocation.InvocationName -ne '.' -and -not $result.ok) {
    exit 2
  }
  exit 0
}

$status = if ($result.ok) { 'OK' } else { 'PROBLEMAS' }
Write-Host "Diagnostico de entorno: $status (exit $($result.exitCode))"
foreach ($c in @($result.checks)) {
  $mark = if ($c.pass) { '[ok]' } else { '[!!]' }
  Write-Host ("  {0} {1} ({2}): {3}" -f $mark, $c.id, $c.level, $c.message)
}

if ($MyInvocation.InvocationName -ne '.' -and -not $result.ok) {
  exit 2
}
