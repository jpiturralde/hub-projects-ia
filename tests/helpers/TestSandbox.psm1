#Requires -Version 5.1
Set-StrictMode -Version Latest

$script:TestSandboxState = $null
$script:RealHomeSentinels = @()

function Get-TestSandboxState {
  return $script:TestSandboxState
}

function Register-RealHomeSentinels {
  $script:RealHomeSentinels = @()
  $realHome = [Environment]::GetFolderPath('UserProfile')
  foreach ($relative in @('.cursor\mcp.json', '.gentle-ai\state.json', '.cursor\rules\gentle-ai.mdc')) {
    $path = Join-Path $realHome $relative
    if (Test-Path -LiteralPath $path -PathType Leaf) {
      $item = Get-Item -LiteralPath $path
      $script:RealHomeSentinels += [pscustomobject]@{
        Path = $path
        Length = $item.Length
        LastWriteTimeUtc = $item.LastWriteTimeUtc
      }
    }
  }
}

function Assert-RealHomeUnchanged {
  foreach ($sentinel in $script:RealHomeSentinels) {
    if (-not (Test-Path -LiteralPath $sentinel.Path -PathType Leaf)) {
      throw "El archivo real del usuario desapareció durante el test: $($sentinel.Path)"
    }
    $item = Get-Item -LiteralPath $sentinel.Path
    if ($item.Length -ne $sentinel.Length -or $item.LastWriteTimeUtc -ne $sentinel.LastWriteTimeUtc) {
      throw "El archivo real del usuario fue modificado durante el test: $($sentinel.Path)"
    }
  }
}

function Test-PathUnderRoot {
  param(
    [Parameter(Mandatory = $true)][string] $Path,
    [Parameter(Mandatory = $true)][string[]] $AllowedRoots
  )
  $resolved = [System.IO.Path]::GetFullPath($Path)
  foreach ($root in $AllowedRoots) {
    if ([string]::IsNullOrWhiteSpace($root)) { continue }
    $normalizedRoot = [System.IO.Path]::GetFullPath($root.TrimEnd('\', '/'))
    if ($resolved -eq $normalizedRoot) { return $true }
    $sep = [System.IO.Path]::DirectorySeparatorChar
    if ($resolved.StartsWith($normalizedRoot + $sep, [StringComparison]::OrdinalIgnoreCase)) {
      return $true
    }
  }
  return $false
}

function Assert-NoWriteOutsideSandbox {
  param([string[]] $ExtraAllowedRoots = @())

  if (-not $script:TestSandboxState) {
    throw 'TestSandbox no inicializado. Llamá Initialize-TestSandbox primero.'
  }

  $allowed = @(
    $script:TestSandboxState.Root
    $script:TestSandboxState.FakeHome
    $script:TestSandboxState.FakeHubRoot
    $script:TestSandboxState.FakeBinDir
    $script:TestSandboxState.PesterTestDrive
  ) + @($ExtraAllowedRoots) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique

  foreach ($file in $script:TestSandboxState.NewFiles) {
    if (-not (Test-PathUnderRoot -Path $file -AllowedRoots $allowed)) {
      throw "Escritura fuera del sandbox detectada: $file"
    }
  }

  Assert-RealHomeUnchanged
}

function Get-IsolatedTestPath {
  param(
    [Parameter(Mandatory = $true)][string] $FakeBinDir,
    [string] $OriginalPath = $env:PATH
  )

  $segments = @($FakeBinDir)
  foreach ($seg in ($OriginalPath -split [System.IO.Path]::PathSeparator)) {
    if ([string]::IsNullOrWhiteSpace($seg)) { continue }
    if ($seg -match '(?i)([/\\]go[/\\]bin|[/\\]gentle-ai|\.local[/\\]bin)') { continue }
    if ($seg -match '(?i)(^/usr/bin$|^/bin$|^/usr/local/bin$|powershell|pwsh|WindowsPowerShell|PowerShell)') {
      $segments += $seg
    }
  }
  return ($segments | Select-Object -Unique) -join [System.IO.Path]::PathSeparator
}

function Initialize-TestSandbox {
  param(
    [string] $Root = $null,
    [string] $FakeHomeFixture = 'empty',
    [switch] $WithFakeCommands,
    [string] $PesterTestDrive = $null
  )

  if ($script:TestSandboxState) {
    Remove-TestSandbox
  }

  Register-RealHomeSentinels

  $testsRoot = Split-Path -Parent $PSScriptRoot
  $repoRoot = Split-Path -Parent $testsRoot
  $fixturesRoot = Join-Path $testsRoot 'fixtures'

  if ([string]::IsNullOrWhiteSpace($Root)) {
    $Root = Join-Path ([System.IO.Path]::GetTempPath()) ("hub-test-sandbox-{0}" -f [Guid]::NewGuid().ToString('N'))
  }
  $Root = [System.IO.Path]::GetFullPath($Root)

  $fakeHome = Join-Path $Root 'fake-home'
  $fakeHub = Join-Path $Root 'fake-hub'
  $fakeBin = Join-Path $Root 'fake-bin'
  $projects = Join-Path $fakeHub 'projects'

  New-Item -ItemType Directory -Path $fakeHome -Force | Out-Null
  New-Item -ItemType Directory -Path $fakeBin -Force | Out-Null
  New-Item -ItemType Directory -Path $projects -Force | Out-Null

  $fixtureSource = Join-Path $fixturesRoot (Join-Path 'fake-home' $FakeHomeFixture)
  if (Test-Path -LiteralPath $fixtureSource) {
    Get-ChildItem -LiteralPath $fixtureSource -Force | Copy-Item -Destination $fakeHome -Recurse -Force
  }

  $minimalHubFixture = Join-Path $fixturesRoot 'minimal-hub'
  if (Test-Path -LiteralPath $minimalHubFixture) {
    Get-ChildItem -LiteralPath $minimalHubFixture -Force | Copy-Item -Destination $fakeHub -Recurse -Force
  } else {
    New-Item -ItemType Directory -Path (Join-Path $fakeHub 'skeleton') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $fakeHub 'hub-registry.json') -Value '{"schemaVersion":1,"projects":[]}' -Encoding UTF8
  }

  $savedEnv = [ordered]@{
    HOME = $env:HOME
    USERPROFILE = $env:USERPROFILE
    PATH = $env:PATH
    HUB_PROJECTS_IA_ROOT = $env:HUB_PROJECTS_IA_ROOT
    TEST_USER_HOME = $env:TEST_USER_HOME
  }

  $env:HOME = $fakeHome
  $env:USERPROFILE = $fakeHome
  $env:TEST_USER_HOME = $fakeHome
  $env:HUB_PROJECTS_IA_ROOT = $fakeHub

  if ($WithFakeCommands) {
    . (Join-Path $PSScriptRoot 'FakeCommand.ps1')
    New-FakeCommandSet -FakeBinDir $fakeBin | Out-Null
    $env:PATH = Get-IsolatedTestPath -FakeBinDir $fakeBin -OriginalPath $savedEnv.PATH
  }

  $script:TestSandboxState = [pscustomobject]@{
    Root = $Root
    FakeHome = $fakeHome
    FakeHubRoot = $fakeHub
    FakeBinDir = $fakeBin
    PesterTestDrive = $PesterTestDrive
    SavedEnv = $savedEnv
    NewFiles = [System.Collections.Generic.List[string]]::new()
    RepoRoot = $repoRoot
  }

  return $script:TestSandboxState
}

function Register-TestSandboxWrite {
  param([Parameter(Mandatory = $true)][string] $Path)
  if (-not $script:TestSandboxState) { return }
  $resolved = [System.IO.Path]::GetFullPath($Path)
  if ($script:TestSandboxState.NewFiles -notcontains $resolved) {
    $script:TestSandboxState.NewFiles.Add($resolved) | Out-Null
  }
}

function Invoke-InTestSandbox {
  param([Parameter(Mandatory = $true)][scriptblock] $ScriptBlock)

  if (-not $script:TestSandboxState) {
    throw 'TestSandbox no inicializado.'
  }

  $previousLocation = Get-Location
  try {
    Set-Location $script:TestSandboxState.FakeHubRoot
    & $ScriptBlock
  } finally {
    Set-Location $previousLocation
  }
}

function Remove-TestSandbox {
  if (-not $script:TestSandboxState) { return }

  $saved = $script:TestSandboxState.SavedEnv
  $env:HOME = $saved.HOME
  $env:USERPROFILE = $saved.USERPROFILE
  $env:PATH = $saved.PATH
  if ($saved.HUB_PROJECTS_IA_ROOT) {
    $env:HUB_PROJECTS_IA_ROOT = $saved.HUB_PROJECTS_IA_ROOT
  } else {
    Remove-Item Env:HUB_PROJECTS_IA_ROOT -ErrorAction SilentlyContinue
  }
  if ($saved.TEST_USER_HOME) {
    $env:TEST_USER_HOME = $saved.TEST_USER_HOME
  } else {
    Remove-Item Env:TEST_USER_HOME -ErrorAction SilentlyContinue
  }

  if (Test-Path -LiteralPath $script:TestSandboxState.Root) {
    Remove-Item -LiteralPath $script:TestSandboxState.Root -Recurse -Force -ErrorAction SilentlyContinue
  }

  $script:TestSandboxState = $null
}

Export-ModuleMember -Function @(
  'Initialize-TestSandbox',
  'Remove-TestSandbox',
  'Get-TestSandboxState',
  'Invoke-InTestSandbox',
  'Register-TestSandboxWrite',
  'Assert-NoWriteOutsideSandbox',
  'Assert-RealHomeUnchanged',
  'Register-RealHomeSentinels',
  'Test-PathUnderRoot',
  'Get-IsolatedTestPath'
)
