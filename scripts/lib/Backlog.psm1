#Requires -Version 5.1
Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot 'Platform.psm1') -Force

function Get-BacklogManualInstallHint {
  return 'npm install -g backlog.md@latest --include=optional'
}

function Get-BacklogRawCommandPaths {
  param([string] $Name = 'backlog')
  $paths = @()
  Get-Command $Name -All -ErrorAction SilentlyContinue | ForEach-Object {
    $candidate = if ($_.Path) { $_.Path } elseif ($_.Source) { $_.Source } else { $null }
    if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
      $paths += Resolve-HubRootPath $candidate
    }
  }
  return @($paths | Sort-Object -Unique)
}

function Test-BacklogCliVersion {
  param(
    [Parameter(Mandatory = $true)][string] $Path,
    [scriptblock] $Invoker
  )
  if ($Invoker) {
    try {
      $result = & $Invoker $Path
      if ($result -is [bool]) { return [bool]$result }
      if ($null -eq $result) { return ($LASTEXITCODE -eq 0) }
      return [bool]$result
    } catch {
      return $false
    }
  }
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }
  try {
    $null = & $Path --version 2>&1
    return ($LASTEXITCODE -eq 0)
  } catch {
    return $false
  }
}

function Resolve-BacklogCliStatus {
  param(
    [string[]] $RawPaths,
    [scriptblock] $VersionInvoker
  )

  if ($null -eq $RawPaths) { $RawPaths = @(Get-BacklogRawCommandPaths) }
  $raw = @($RawPaths)
  $allowed = @($raw | Where-Object {
    Test-HubCommandAllowedOnPlatform -Name 'backlog' -Path $_
  })
  $rejected = @($raw | Where-Object {
    -not (Test-HubCommandAllowedOnPlatform -Name 'backlog' -Path $_)
  })

  if ($allowed.Count -eq 1) {
    $ok = Test-BacklogCliVersion -Path $allowed[0] -Invoker $VersionInvoker
    if (-not $ok) {
      return [pscustomobject]@{
        Status = 'Invalid'
        Path = $null
        Paths = @()
        RejectedPaths = $rejected
        InvalidPaths = @($allowed[0])
        Message = "backlog está en PATH pero no responde a --version: $($allowed[0]). Instalación recomendada: $(Get-BacklogManualInstallHint)"
      }
    }
    return [pscustomobject]@{
      Status = 'Ok'
      Path = $allowed[0]
      Paths = $allowed
      RejectedPaths = $rejected
      InvalidPaths = @()
      Message = $null
    }
  }

  if ($allowed.Count -gt 1) {
    $valid = [System.Collections.Generic.List[string]]::new()
    $invalid = [System.Collections.Generic.List[string]]::new()
    foreach ($candidate in $allowed) {
      if (Test-BacklogCliVersion -Path $candidate -Invoker $VersionInvoker) {
        $valid.Add($candidate)
      } else {
        $invalid.Add($candidate)
      }
    }
    if ($valid.Count -eq 1) {
      return [pscustomobject]@{
        Status = 'Ok'
        Path = $valid[0]
        Paths = @($valid)
        RejectedPaths = $rejected
        InvalidPaths = @($invalid)
        Message = $null
      }
    }
    if ($valid.Count -gt 1) {
      return [pscustomobject]@{
        Status = 'Duplicate'
        Path = $null
        Paths = @($valid)
        RejectedPaths = $rejected
        InvalidPaths = @($invalid)
        Message = "Se detectaron varias instalaciones válidas de backlog. Conservá una sola en PATH:`n$($valid -join "`n")"
      }
    }
    return [pscustomobject]@{
      Status = 'Invalid'
      Path = $null
      Paths = @()
      RejectedPaths = $rejected
      InvalidPaths = @($invalid)
      Message = "backlog aparece en PATH pero ninguna instalación responde a --version.`nInstalá con: $(Get-BacklogManualInstallHint)"
    }
  }

  if ($rejected.Count -gt 0) {
    return [pscustomobject]@{
      Status = 'WindowsOriginRejected'
      Path = $null
      Paths = @()
      RejectedPaths = $rejected
      InvalidPaths = @()
      Message = "backlog detectado sólo como ejecutable Windows (inválido en Linux/WSL):`n$($rejected -join "`n")`nInstalá Backlog.md nativo en la distro: $(Get-BacklogManualInstallHint)"
    }
  }

  return [pscustomobject]@{
    Status = 'Missing'
    Path = $null
    Paths = @()
    RejectedPaths = @()
    InvalidPaths = @()
    Message = "backlog no está en PATH. Instalación recomendada: $(Get-BacklogManualInstallHint)"
  }
}

function Resolve-BacklogNpmPrefixBin {
  param([Parameter(Mandatory = $true)][string] $NpmPath)
  $prefix = (& $NpmPath config get prefix 2>$null | Select-Object -First 1)
  if ([string]::IsNullOrWhiteSpace($prefix)) { return $null }
  $prefix = $prefix.Trim()
  $platform = Get-HubPlatformInfo
  if ($platform.IsWindowsNative) {
    return Resolve-HubRootPath $prefix
  }
  return Resolve-HubRootPath (Join-Path $prefix 'bin')
}

function Select-FirstUsableHubCommandPath {
  param(
    [Parameter(Mandatory = $true)][string] $Name,
    [scriptblock] $VersionInvoker
  )
  $paths = @(Get-HubCommandExecutablePaths -Name $Name)
  foreach ($candidate in $paths) {
    if (Test-BacklogCliVersion -Path $candidate -Invoker $VersionInvoker) {
      return $candidate
    }
  }
  return $null
}

function Install-BacklogCli {
  param(
    [scriptblock] $NpmInvoker,
    [scriptblock] $VersionInvoker
  )

  # 5B: allow multi-hit node/npm; pick first usable (not Count -eq 1).
  # VersionInvoker is for backlog --version only; node/npm use default --version probe.
  $nodePath = Select-FirstUsableHubCommandPath -Name 'node'
  $npmPath = Select-FirstUsableHubCommandPath -Name 'npm'

  if (-not $nodePath) {
    throw "Node.js no está disponible/usable en PATH (nativo de este SO). Instalá Node.js LTS y volvé a ejecutar. Luego: $(Get-BacklogManualInstallHint)"
  }
  if (-not $npmPath) {
    throw "npm no está disponible/usable en PATH (nativo de este SO). Instalá Node.js LTS (incluye npm) y volvé a ejecutar. Luego: $(Get-BacklogManualInstallHint)"
  }

  Write-Host "Instalando Backlog.md con npm nativo: $npmPath"
  Write-Host "Comando: npm install -g backlog.md@latest --include=optional"

  if ($NpmInvoker) {
    & $NpmInvoker $npmPath 'install' '-g' 'backlog.md@latest' '--include=optional'
  } else {
    & $npmPath install -g backlog.md@latest --include=optional
  }
  if ($LASTEXITCODE -ne 0) {
    throw "npm install de backlog.md falló con código $LASTEXITCODE. Ejecutá manualmente: $(Get-BacklogManualInstallHint)"
  }

  $binDir = Resolve-BacklogNpmPrefixBin -NpmPath $npmPath
  if ($binDir -and (Test-Path -LiteralPath $binDir -PathType Container)) {
    $pathParts = @($env:PATH -split [System.IO.Path]::PathSeparator)
    if ($pathParts -notcontains $binDir) {
      $env:PATH = "$binDir$([System.IO.Path]::PathSeparator)$env:PATH"
    }
  }

  # Evitar caché stale de Get-Command tras instalar en PATH.
  $null = Get-Command backlog -All -ErrorAction SilentlyContinue

  $status = Resolve-BacklogCliStatus -VersionInvoker $VersionInvoker
  if ($status.Status -eq 'WindowsOriginRejected') { throw $status.Message }
  if ($status.Status -ne 'Ok') {
    throw "La instalación terminó pero backlog no quedó usable ($($status.Status)). $($status.Message)"
  }
  return $status.Path
}

function Ensure-BacklogCli {
  param(
    [ValidateSet('Auto', 'Existing')] [string] $Mode = 'Auto',
    [string] $Choice,
    [scriptblock] $PromptChoice,
    [scriptblock] $NpmInvoker,
    [scriptblock] $VersionInvoker
  )

  $cliStatus = Resolve-BacklogCliStatus -VersionInvoker $VersionInvoker
  if ($cliStatus.Status -eq 'WindowsOriginRejected') { throw $cliStatus.Message }
  if ($cliStatus.Status -eq 'Duplicate') { throw $cliStatus.Message }
  if ($cliStatus.Status -eq 'Invalid') { throw $cliStatus.Message }
  if ($cliStatus.Status -eq 'Ok') {
    Write-Host "Se reutilizará backlog existente: $($cliStatus.Path)"
    return [pscustomobject]@{
      Available = $true
      Path = $cliStatus.Path
      Status = 'Ok'
      Choice = $null
      Installed = $false
    }
  }

  if ($Mode -eq 'Existing') {
    throw "backlog no está disponible y se solicitó usar una instalación existente. $($cliStatus.Message)"
  }

  if ([string]::IsNullOrWhiteSpace($Choice)) {
    if ($PromptChoice) {
      $Choice = & $PromptChoice
    } else {
      throw "El perfil requiere Backlog.md y no se encontró un CLI usable. En modo no interactivo pasá -BacklogCliChoice I (instalar) o X (cancelar). Manual: $(Get-BacklogManualInstallHint)"
    }
  }

  $Choice = $Choice.Trim().ToUpperInvariant()
  if ($Choice -notin @('I', 'X')) {
    throw "Opción de Backlog inválida: $Choice (válidas: I=instalar, X=cancelar)"
  }
  if ($Choice -eq 'X') {
    return [pscustomobject]@{
      Available = $false
      Path = $null
      Status = 'Cancelled'
      Choice = 'X'
      Installed = $false
    }
  }

  $installedPath = Install-BacklogCli -NpmInvoker $NpmInvoker -VersionInvoker $VersionInvoker
  return [pscustomobject]@{
    Available = $true
    Path = $installedPath
    Status = 'Installed'
    Choice = 'I'
    Installed = $true
  }
}

Export-ModuleMember -Function @(
  'Get-BacklogManualInstallHint',
  'Get-BacklogRawCommandPaths',
  'Test-BacklogCliVersion',
  'Resolve-BacklogCliStatus',
  'Resolve-BacklogNpmPrefixBin',
  'Install-BacklogCli',
  'Ensure-BacklogCli'
)
