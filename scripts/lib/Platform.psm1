#Requires -Version 5.1
Set-StrictMode -Version Latest

$script:HubPlatformInfoCache = $null

function Reset-HubPlatformCache {
  $script:HubPlatformInfoCache = $null
}

function Get-HubPlatformInfo {
  if ($null -ne $script:HubPlatformInfoCache) { return $script:HubPlatformInfoCache }

  $isWindowsNative = [bool]($IsWindows -or ($env:OS -eq 'Windows_NT'))
  $isLinux = [bool]$IsLinux
  $isMacOS = [bool]$IsMacOS
  $isWsl = $false

  if ($isLinux) {
    if (-not [string]::IsNullOrWhiteSpace($env:WSL_DISTRO_NAME)) {
      $isWsl = $true
    } elseif (Test-Path -LiteralPath '/proc/version') {
      try {
        $procVersion = Get-Content -LiteralPath '/proc/version' -Raw -ErrorAction Stop
        $isWsl = $procVersion -match '(?i)microsoft|wsl'
      } catch {
        $isWsl = $false
      }
    }
  }

  $platformName = if ($isWindowsNative) {
    'Windows'
  } elseif ($isWsl) {
    'Wsl'
  } elseif ($isLinux) {
    'Linux'
  } elseif ($isMacOS) {
    'MacOS'
  } else {
    'Unknown'
  }

  $script:HubPlatformInfoCache = [pscustomobject]@{
    Platform = $platformName
    IsWindowsNative = $isWindowsNative
    IsLinux = $isLinux
    IsMacOS = $isMacOS
    IsWsl = $isWsl
    UsesCaseInsensitivePaths = $isWindowsNative
  }
  return $script:HubPlatformInfoCache
}

function Join-HubPath {
  param([Parameter(ValueFromRemainingArguments = $true)][string[]] $Segments)
  if ($null -eq $Segments -or $Segments.Count -eq 0) {
    throw 'Join-HubPath requiere al menos un segmento.'
  }
  $result = $Segments[0]
  for ($i = 1; $i -lt $Segments.Count; $i++) {
    if ([string]::IsNullOrWhiteSpace($Segments[$i])) { continue }
    $result = Join-Path $result $Segments[$i]
  }
  return $result
}

function Resolve-HubRootPath {
  param([Parameter(Mandatory = $true)][string] $Path)
  if ([string]::IsNullOrWhiteSpace($Path)) { throw 'Path vacío.' }
  return [System.IO.Path]::GetFullPath($Path.Trim().TrimEnd('\', '/'))
}

function Compare-HubPath {
  param(
    [Parameter(Mandatory = $true)][string] $Left,
    [Parameter(Mandatory = $true)][string] $Right
  )
  $leftNorm = Resolve-HubRootPath $Left
  $rightNorm = Resolve-HubRootPath $Right
  $comparison = if ((Get-HubPlatformInfo).UsesCaseInsensitivePaths) {
    [StringComparison]::OrdinalIgnoreCase
  } else {
    [StringComparison]::Ordinal
  }
  return [string]::Equals($leftNorm, $rightNorm, $comparison)
}

function Test-HubPathIsChildOf {
  param(
    [Parameter(Mandatory = $true)][string] $ChildPath,
    [Parameter(Mandatory = $true)][string] $ParentPath
  )
  $child = Resolve-HubRootPath $ChildPath
  $parent = Resolve-HubRootPath $ParentPath
  if ($child.Length -le $parent.Length) { return $false }
  $sep = [System.IO.Path]::DirectorySeparatorChar
  $comparison = if ((Get-HubPlatformInfo).UsesCaseInsensitivePaths) {
    [StringComparison]::OrdinalIgnoreCase
  } else {
    [StringComparison]::Ordinal
  }
  return $child.StartsWith($parent + $sep, $comparison)
}

function Test-HubPathUnderWindowsMount {
  param([Parameter(Mandatory = $true)][string] $Path)
  if (-not (Get-HubPlatformInfo).IsWsl) { return $false }
  $normalized = ($Path -replace '\\', '/').ToLowerInvariant()
  return $normalized -match '^/mnt/[a-z](?:/|$)'
}

function Test-HubExecutableIsWindowsOrigin {
  param([Parameter(Mandatory = $true)][string] $Path)
  if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
  $full = Resolve-HubRootPath $Path
  if ($full -match '(?i)\.exe$') { return $true }
  if ((Get-HubPlatformInfo).IsWsl) {
    $unix = ($full -replace '\\', '/')
    if ($unix -match '^/mnt/[a-z](?:/|$)') { return $true }
  }
  return $false
}

function Test-HubCommandAllowedOnPlatform {
  param(
    [Parameter(Mandatory = $true)][string] $Name,
    [Parameter(Mandatory = $true)][string] $Path,
    [switch] $AllowWindowsExecutable
  )
  $platform = Get-HubPlatformInfo
  if ($platform.IsWindowsNative) { return $true }
  if (-not (Test-HubExecutableIsWindowsOrigin -Path $Path)) { return $true }
  if ($AllowWindowsExecutable -and $Name -eq 'cursor') { return $true }
  return $false
}

function Get-HubCommandExecutablePaths {
  param(
    [Parameter(Mandatory = $true)][string] $Name,
    [switch] $AllowWindowsExecutable
  )
  $paths = @()
  Get-Command $Name -All -ErrorAction SilentlyContinue | ForEach-Object {
    $candidate = if ($_.Path) { $_.Path } elseif ($_.Source) { $_.Source } else { $null }
    if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
      $paths += Resolve-HubRootPath $candidate
    }
  }
  $paths = @($paths | Sort-Object -Unique)
  return @($paths | Where-Object {
    Test-HubCommandAllowedOnPlatform -Name $Name -Path $_ -AllowWindowsExecutable:$AllowWindowsExecutable
  })
}

function Resolve-HubModulePath {
  param(
    [Parameter(Mandatory = $true)][string] $ScriptRoot,
    [Parameter(Mandatory = $true)][string] $ModuleName
  )
  if ($ModuleName.EndsWith('.psm1', [StringComparison]::OrdinalIgnoreCase)) {
    return Join-HubPath $ScriptRoot 'lib' $ModuleName
  }
  return Join-HubPath $ScriptRoot 'lib' "$ModuleName.psm1"
}

function Resolve-HubProjectsRootFromScript {
  param([Parameter(Mandatory = $true)][string] $ScriptRoot)
  return (Resolve-Path (Join-HubPath $ScriptRoot '..')).Path
}

function Test-HubArchiMcpPath {
  param([Parameter(Mandatory = $true)][string] $Path)
  if ([string]::IsNullOrWhiteSpace($Path)) {
    throw 'IncludeArchiMcp requiere una ruta absoluta existente al index.js de archi-mcp.'
  }
  if (-not [System.IO.Path]::IsPathRooted($Path.Trim())) {
    throw "La ruta de Archi MCP debe ser absoluta. Recibido: $Path"
  }
  $resolved = Resolve-HubRootPath $Path.Trim()
  if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) {
    throw "No se encuentra el index.js de archi-mcp: $resolved"
  }
  if (-not (Get-HubPlatformInfo).IsWindowsNative -and (Test-HubExecutableIsWindowsOrigin -Path $resolved)) {
    throw "Archi MCP no puede apuntar a una ruta Windows desde Linux/WSL: $resolved"
  }
  return $resolved
}

function Test-HubMcpConfigurationPaths {
  param(
    [bool] $IncludeBacklogMcp,
    [string] $BacklogMcpCwd,
    [bool] $IncludeArchiMcp,
    [string[]] $ArchiMcpArgs
  )
  if ($IncludeBacklogMcp) {
    if ([string]::IsNullOrWhiteSpace($BacklogMcpCwd)) {
      throw 'IncludeBacklogMcp requiere BacklogMcpCwd.'
    }
    $backlogPath = Resolve-HubRootPath $BacklogMcpCwd
    if (-not (Test-Path -LiteralPath $backlogPath -PathType Container)) {
      throw "BacklogMcpCwd no existe: $backlogPath"
    }
  }
  if ($IncludeArchiMcp) {
    if ($null -eq $ArchiMcpArgs -or $ArchiMcpArgs.Count -eq 0 -or [string]::IsNullOrWhiteSpace($ArchiMcpArgs[0])) {
      throw 'IncludeArchiMcp requiere ArchiMcpArgs con una ruta existente a dist/index.js.'
    }
    Test-HubArchiMcpPath -Path $ArchiMcpArgs[0] | Out-Null
  }
}

function Write-HubPathLocationWarnings {
  param([Parameter(Mandatory = $true)][string] $TargetPath)
  if (Test-HubPathUnderWindowsMount -Path $TargetPath) {
    Write-Warning @(
      "El proyecto quedará bajo $($TargetPath -replace '\\','/'), montado desde Windows (/mnt/*).",
      'Para mejor rendimiento en WSL, preferí rutas bajo /home/... dentro de la distro.'
    )
  }
}

function Assert-HubWindowsNativeHost {
  param(
    [string] $OperationName = 'Esta operación'
  )
  $info = Get-HubPlatformInfo
  if ($info.IsWindowsNative) { return }
  $where = if ($info.IsWsl) { 'WSL/Linux' } elseif ($info.IsLinux) { 'Linux' } elseif ($info.IsMacOS) { 'macOS' } else { $info.Platform }
  throw ("$OperationName solo está soportada en Windows nativo (ahora: $where). " +
    'No sirve para migrar el hub entre Windows y WSL ni para relocalizar desde Linux. ' +
    'En Ubuntu/WSL mové el directorio con herramientas nativas y usá registry schema v2 (relativePath).')
}

Export-ModuleMember -Function @(
  'Reset-HubPlatformCache', 'Get-HubPlatformInfo',
  'Join-HubPath', 'Resolve-HubRootPath', 'Compare-HubPath', 'Test-HubPathIsChildOf',
  'Test-HubPathUnderWindowsMount', 'Test-HubExecutableIsWindowsOrigin',
  'Test-HubCommandAllowedOnPlatform', 'Get-HubCommandExecutablePaths',
  'Resolve-HubModulePath', 'Resolve-HubProjectsRootFromScript',
  'Test-HubArchiMcpPath', 'Test-HubMcpConfigurationPaths', 'Write-HubPathLocationWarnings',
  'Assert-HubWindowsNativeHost'
)
