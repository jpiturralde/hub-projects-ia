#Requires -Version 5.1
Set-StrictMode -Version Latest

function New-SmartFakeGentleAi {
  param(
    [Parameter(Mandatory = $true)][string] $FakeBinDir,
    [Parameter(Mandatory = $true)][string] $FakeHome
  )

  . (Join-Path $PSScriptRoot 'FakeCommand.ps1')
  $logPath = Get-FakeCommandLogPath -FakeBinDir $FakeBinDir

  if ($IsWindows -or ($env:OS -eq 'Windows_NT')) {
    $targetPath = Join-Path $FakeBinDir 'gentle-ai.cmd'
    $content = @"
@echo off
powershell -NoProfile -File "$FakeBinDir\gentle-ai-smart.ps1" %*
exit /b %ERRORLEVEL%
"@
    Set-Content -LiteralPath $targetPath -Value $content -Encoding ASCII
    $scriptPath = Join-Path $FakeBinDir 'gentle-ai-smart.ps1'
  } else {
    $targetPath = Join-Path $FakeBinDir 'gentle-ai'
    $scriptPath = $targetPath
  }

  $content = @'
param([Parameter(ValueFromRemainingArguments = $true)][string[]] $Args)

$ErrorActionPreference = 'Stop'
$logPath = '__LOG_PATH__'
$entry = [ordered]@{
  timestamp = (Get-Date).ToString('o')
  name = 'gentle-ai'
  argv = @($Args)
  exitCode = 0
}
Add-Content -LiteralPath $logPath -Value ($entry | ConvertTo-Json -Compress) -Encoding UTF8

function Install-GentleAiMarkers {
  param([string] $Root)
  $paths = @(
    (Join-Path $Root '.cursor\rules\gentle-ai.mdc'),
    (Join-Path $Root '.cursor\agents\sdd-init.md'),
    (Join-Path $Root '.cursor\skills\sdd-init\SKILL.md'),
    (Join-Path $Root '.gentle-ai\state.json')
  )
  foreach ($path in $paths) {
    $parent = Split-Path -Parent $path
    if (-not (Test-Path -LiteralPath $parent)) {
      New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    if ($path.EndsWith('state.json')) {
      Set-Content -LiteralPath $path -Value '{"agents":{"cursor":{"installedAt":"2026-01-01T00:00:00Z"}}}' -Encoding UTF8
    } else {
      Set-Content -LiteralPath $path -Value '# fake gentle-ai marker' -Encoding UTF8
    }
  }
}

$command = if ($Args.Count -gt 0) { $Args[0] } else { '' }
switch ($command) {
  'install' {
    $scope = 'global'
    for ($i = 0; $i -lt $Args.Count; $i++) {
      if ($Args[$i] -eq '--scope' -and ($i + 1) -lt $Args.Count) {
        $scope = $Args[$i + 1].ToLowerInvariant()
      }
    }
    $root = if ($scope -eq 'workspace') { (Get-Location).Path } else { $env:HOME }
    Install-GentleAiMarkers -Root $root
    exit 0
  }
  'doctor' {
    Write-Output 'fake gentle-ai doctor ok'
    exit 0
  }
  'skill-registry' { exit 0 }
  default { exit 0 }
}
'@
  $content = $content.Replace('__LOG_PATH__', $logPath.Replace('\', '\\').Replace("'", "''"))
  if ($IsWindows -or ($env:OS -eq 'Windows_NT')) {
    Set-Content -LiteralPath $scriptPath -Value $content -Encoding UTF8
  } else {
    Set-Content -LiteralPath $scriptPath -Value "#!/usr/bin/env pwsh`n$content" -Encoding UTF8
    & chmod +x $scriptPath
  }
  return $targetPath
}

function New-SmartFakeGo {
  param(
    [Parameter(Mandatory = $true)][string] $FakeBinDir,
    [Parameter(Mandatory = $true)][string] $FakeHome,
    [Parameter(Mandatory = $true)][string] $Gopath,
    [Parameter(Mandatory = $true)][string] $GentleAiSourcePath
  )

  . (Join-Path $PSScriptRoot 'FakeCommand.ps1')
  $logPath = Get-FakeCommandLogPath -FakeBinDir $FakeBinDir
  $goExecutable = Join-Path $FakeBinDir 'go'
  $goPathBin = Join-Path $Gopath 'bin'
  New-Item -ItemType Directory -Path $goPathBin -Force | Out-Null
  if (Test-Path -LiteralPath $goExecutable) {
    Remove-Item -LiteralPath $goExecutable -Recurse -Force
  }
  $sourceLiteral = $GentleAiSourcePath.Replace("'", "''")

  $gopathRootLiteral = $Gopath.Replace("'", "''")
  $gopathBinLiteral = $goPathBin.Replace("'", "''")

  $content = @"
#!/usr/bin/env pwsh
`$ErrorActionPreference = 'Stop'
`$logPath = '$($logPath.Replace("'", "''"))'
`$entry = [ordered]@{ timestamp = (Get-Date).ToString('o'); name = 'go'; argv = @(`$args); exitCode = 0 }
Add-Content -LiteralPath `$logPath -Value (`$entry | ConvertTo-Json -Compress) -Encoding UTF8
if (`$args.Count -ge 2 -and `$args[0] -eq 'env' -and `$args[1] -eq 'GOPATH') {
  Write-Output '$gopathRootLiteral'
  exit 0
}
if (`$args.Count -ge 1 -and `$args[0] -eq 'install') {
  `$dest = Join-Path '$gopathBinLiteral' 'gentle-ai'
  New-Item -ItemType Directory -Path '$gopathBinLiteral' -Force | Out-Null
  Copy-Item -LiteralPath '$sourceLiteral' -Destination `$dest -Force
  if (`$IsLinux -or `$IsMacOS) { & chmod +x `$dest }
  exit 0
}
exit 0
"@
  Set-Content -LiteralPath $goExecutable -Value $content -Encoding UTF8
  if ($IsLinux -or $IsMacOS) { & chmod +x $goExecutable }
  return $goExecutable
}

function Initialize-CharacterizationContext {
  param(
    [string] $FakeHomeFixture = 'empty',
    [switch] $WithFakeCommands,
    [switch] $SmartGentleAi
  )

  Import-Module (Join-Path (Split-Path -Parent $PSScriptRoot) 'helpers\TestSandbox.psm1') -Force
  $pesterDrive = $null
  if (Get-Variable -Name TestDrive -Scope 1 -ErrorAction SilentlyContinue) {
    $pesterDrive = Get-Variable -Name TestDrive -Scope 1 -ValueOnly -ErrorAction SilentlyContinue
  } elseif (Get-Variable -Name TestDrive -ErrorAction SilentlyContinue) {
    $pesterDrive = $TestDrive
  }
  $sandbox = Initialize-TestSandbox -FakeHomeFixture $FakeHomeFixture -WithFakeCommands:$WithFakeCommands -PesterTestDrive $pesterDrive
  $repoRoot = $sandbox.RepoRoot
  $env:HUB_PROJECTS_IA_ROOT = $repoRoot

  if ($SmartGentleAi) {
    New-SmartFakeGentleAi -FakeBinDir $sandbox.FakeBinDir -FakeHome $sandbox.FakeHome | Out-Null
  }

  return [pscustomobject]@{
    Sandbox = $sandbox
    RepoRoot = $repoRoot
    Generator = Join-Path $repoRoot 'scripts\New-ConsultingCopilotProject.ps1'
    TestGentleAi = Join-Path $repoRoot 'scripts\Test-GentleAiProject.ps1'
    InstallDiagnostic = Join-Path $repoRoot 'scripts\Install-ConsultingCopilot.ps1'
  }
}

function New-CharacterizationTarget {
  param(
    [Parameter(Mandatory = $true)][string] $Name,
    [object] $Context
  )
  $target = Join-Path $Context.Sandbox.Root $Name
  if (Test-Path -LiteralPath $target) {
    Remove-Item -LiteralPath $target -Recurse -Force
  }
  Register-TestSandboxWrite -Path $target
  return [System.IO.Path]::GetFullPath($target)
}

function Invoke-CharacterizationGenerator {
  param(
    [Parameter(Mandatory = $true)][object] $Context,
    [Parameter(Mandatory = $true)][string] $TargetPath,
    [Parameter(Mandatory = $true)][hashtable] $Params
  )

  $defaults = @{
    SkipSkillRegistryRefresh = $true
    SkipHandoffSummary = $true
    IncludeDrawioMcp = $false
    IncludeBacklogMcp = $false
    IncludeArchiMcp = $false
    IncludeClaudeCoworkLayer = $false
  }
  foreach ($key in $defaults.Keys) {
    if (-not $Params.ContainsKey($key)) { $Params[$key] = $defaults[$key] }
  }
  $Params['TargetPath'] = $TargetPath

  & $Context.Generator @Params
  Register-TestSandboxWrite -Path $TargetPath
  return $TargetPath
}

function Get-McpServerNamesFromProject {
  param([Parameter(Mandatory = $true)][string] $ProjectRoot)
  $mcpPath = Join-Path $ProjectRoot '.cursor\mcp.json'
  if (-not (Test-Path -LiteralPath $mcpPath)) { return @() }
  $config = Get-Content -LiteralPath $mcpPath -Raw -Encoding UTF8 | ConvertFrom-Json
  if (-not $config.mcpServers) { return @() }
  $names = @($config.mcpServers.PSObject.Properties | ForEach-Object { $_.Name })
  return @(@($names | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) | Sort-Object)
}

function ConvertTo-EquivalenceRelativePath {
  param([Parameter(Mandatory = $true)][string] $ProjectRoot, [Parameter(Mandatory = $true)][string] $FullPath)
  $root = [System.IO.Path]::GetFullPath($ProjectRoot).TrimEnd('\', '/')
  $full = [System.IO.Path]::GetFullPath($FullPath)
  if ($full.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) {
    $rel = $full.Substring($root.Length).TrimStart('\', '/')
  } else {
    $rel = $FullPath
  }
  return ($rel -replace '\\', '/')
}

function Get-EquivalenceNormalizedContent {
  param(
    [Parameter(Mandatory = $true)][string] $ProjectRoot,
    [Parameter(Mandatory = $true)][string] $FilePath
  )
  $root = [System.IO.Path]::GetFullPath($ProjectRoot).TrimEnd('\', '/')
  $rootSlash = $root -replace '\\', '/'
  $bytes = [System.IO.File]::ReadAllBytes($FilePath)
  # Quitar BOM UTF-8 si existe.
  if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
    $text = [Text.Encoding]::UTF8.GetString($bytes, 3, $bytes.Length - 3)
  } else {
    $text = [Text.Encoding]::UTF8.GetString($bytes)
  }
  $text = $text -replace "`r`n", "`n" -replace "`r", "`n"
  $text = $text.Replace($root, '<PROJECT_ROOT>').Replace($rootSlash, '<PROJECT_ROOT>')
  # Variantes Windows drive-letter case.
  if ($root -match '^[A-Za-z]:') {
    $alt = $root.Substring(0, 1).ToLowerInvariant() + $root.Substring(1)
    $text = $text.Replace($alt, '<PROJECT_ROOT>').Replace(($alt -replace '\\', '/'), '<PROJECT_ROOT>')
  }

  if ([System.IO.Path]::GetExtension($FilePath) -eq '.json') {
    try {
      $json = $text | ConvertFrom-Json
      foreach ($prop in @('generatedAt', 'createdAt', 'installedAt')) {
        if ($json.PSObject.Properties.Name -contains $prop) {
          $json.PSObject.Properties.Remove($prop)
        }
      }
      $text = ($json | ConvertTo-Json -Depth 30) -replace "`r`n", "`n" -replace "`r", "`n"
    } catch { }
  }
  return $text
}

function Get-NormalizedProjectManifest {
  param(
    [Parameter(Mandatory = $true)][string] $ProjectRoot,
    [string[]] $ExcludePatterns = @('(^|/)\.git(/|$)', 'onboarding-pending\.json', '(^|/)node_modules(/|$)', '(^|/)\.DS_Store$')
  )

  $root = [System.IO.Path]::GetFullPath($ProjectRoot)
  $files = @()
  Get-ChildItem -LiteralPath $root -Recurse -File -Force | ForEach-Object {
    $relative = ConvertTo-EquivalenceRelativePath -ProjectRoot $root -FullPath $_.FullName
    $skip = $false
    foreach ($pattern in $ExcludePatterns) {
      if ($relative -match $pattern) { $skip = $true; break }
    }
    if ($skip) { return }

    $normalized = Get-EquivalenceNormalizedContent -ProjectRoot $root -FilePath $_.FullName
    $bytes = [Text.Encoding]::UTF8.GetBytes($normalized)
    $stream = [System.IO.MemoryStream]::new($bytes)
    try {
      $hash = (Get-FileHash -InputStream $stream -Algorithm SHA256).Hash
    } finally {
      $stream.Dispose()
    }
    $files += [pscustomobject]@{ Path = $relative; Hash = $hash }
  }
  return @($files | Sort-Object Path)
}

function Get-EquivalenceProjectSnapshot {
  param(
    [Parameter(Mandatory = $true)][string] $ProjectRoot,
    [string] $ExpectedProfile
  )

  $root = [System.IO.Path]::GetFullPath($ProjectRoot)
  $manifest = Get-NormalizedProjectManifest -ProjectRoot $root
  $mcp = @(Get-McpServerNamesFromProject -ProjectRoot $root)

  $metadata = [ordered]@{}
  $engagementPath = Join-Path $root '.consulting-engagement.json'
  $profilePath = Join-Path $root '.project-profile.json'
  if (Test-Path -LiteralPath $engagementPath) {
    $meta = Get-Content -LiteralPath $engagementPath -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($key in @('schemaVersion', 'stackProfile', 'requestedProfile', 'engramMcpSource', 'gentleAiScope', 'includeDrawioMcp', 'includeBacklogMcp', 'includeArchiMcp')) {
      if ($meta.PSObject.Properties.Name -contains $key) {
        $metadata[$key] = $meta.$key
      }
    }
  } elseif (Test-Path -LiteralPath $profilePath) {
    $meta = Get-Content -LiteralPath $profilePath -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($key in @('schemaVersion', 'stackProfile', 'projectName', 'gentleAiScope')) {
      if ($meta.PSObject.Properties.Name -contains $key) {
        $metadata[$key] = $meta.$key
      }
    }
  }

  $hasPlaceholders = $false
  try {
    Test-ConsultingPlaceholders -TargetPath $root
  } catch {
    $hasPlaceholders = $true
  }

  $platform = Get-HubPlatformInfo

  $joined = (@($manifest | ForEach-Object { '{0}:{1}' -f $_.Path, $_.Hash }) -join "`n")
  $hashBytes = [Text.Encoding]::UTF8.GetBytes($joined)
  $hashStream = [System.IO.MemoryStream]::new($hashBytes)
  try {
    $manifestHash = (Get-FileHash -InputStream $hashStream -Algorithm SHA256).Hash
  } finally {
    $hashStream.Dispose()
  }

  $fingerprints = [ordered]@{}
  foreach ($item in $manifest) {
    $fingerprints[$item.Path] = $item.Hash
  }

  return [ordered]@{
    schemaVersion = 1
    expectedProfile = $ExpectedProfile
    platform = $platform.Platform
    files = @($manifest | ForEach-Object { $_.Path })
    fingerprints = $fingerprints
    mcpServers = $mcp
    metadata = $metadata
    gentleAiMarkers = [ordered]@{
      workspaceGentleAiRule = [bool](Test-Path -LiteralPath (Join-Path $root '.cursor\rules\gentle-ai.mdc'))
      workspaceCddExplore = [bool](Test-Path -LiteralPath (Join-Path $root '.cursor\agents\cdd-explore.md'))
      engramInLocalMcp = ($mcp -contains 'engram')
    }
    hasUnresolvedPlaceholders = $hasPlaceholders
    manifestHash = $manifestHash
  }
}

function Export-EquivalenceExpectedContract {
  param(
    [Parameter(Mandatory = $true)][hashtable] $Snapshot,
    [Parameter(Mandatory = $true)][string] $OutputPath
  )
  # Contrato estable: sin fingerprints ni platform (varían / no aportan al golden cross-OS).
  $contract = [ordered]@{
    schemaVersion = 1
    expectedProfile = $Snapshot.expectedProfile
    files = @($Snapshot.files)
    mcpServers = @($Snapshot.mcpServers)
    metadata = $Snapshot.metadata
    gentleAiMarkers = $Snapshot.gentleAiMarkers
    hasUnresolvedPlaceholders = [bool]$Snapshot.hasUnresolvedPlaceholders
  }
  $parent = Split-Path -Parent $OutputPath
  if (-not (Test-Path -LiteralPath $parent)) {
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
  }
  Set-Content -LiteralPath $OutputPath -Value (($contract | ConvertTo-Json -Depth 10) + "`n") -Encoding UTF8
  return $OutputPath
}

function Assert-EquivalenceContractMatch {
  param(
    [Parameter(Mandatory = $true)]$Snapshot,
    [Parameter(Mandatory = $true)][string] $ExpectedPath
  )
  $expected = Get-Content -LiteralPath $ExpectedPath -Raw -Encoding UTF8 | ConvertFrom-Json
  $errors = [System.Collections.Generic.List[string]]::new()

  if ([string]$Snapshot.expectedProfile -ne [string]$expected.expectedProfile) {
    $errors.Add("expectedProfile: actual=$($Snapshot.expectedProfile) expected=$($expected.expectedProfile)")
  }
  if ([bool]$Snapshot.hasUnresolvedPlaceholders -ne [bool]$expected.hasUnresolvedPlaceholders) {
    $errors.Add('hasUnresolvedPlaceholders mismatch')
  }

  $actualFiles = @($Snapshot.files)
  $expectedFiles = @($expected.files)
  $onlyActual = @($actualFiles | Where-Object { $_ -notin $expectedFiles })
  $onlyExpected = @($expectedFiles | Where-Object { $_ -notin $actualFiles })
  if ($onlyActual.Count -gt 0) { $errors.Add("files only in actual: $($onlyActual -join ', ')") }
  if ($onlyExpected.Count -gt 0) { $errors.Add("files only in expected: $($onlyExpected -join ', ')") }

  $actualMcp = @($Snapshot.mcpServers)
  $expectedMcp = @($expected.mcpServers)
  if (($actualMcp -join ',') -ne ($expectedMcp -join ',')) {
    $errors.Add("mcpServers: actual=[$($actualMcp -join ',')] expected=[$($expectedMcp -join ',')]")
  }

  foreach ($prop in @($expected.metadata.PSObject.Properties)) {
    $actualVal = $Snapshot.metadata[$prop.Name]
    if ("$actualVal" -ne "$($prop.Value)") {
      $errors.Add("metadata.$($prop.Name): actual=$actualVal expected=$($prop.Value)")
    }
  }
  foreach ($prop in @($expected.gentleAiMarkers.PSObject.Properties)) {
    $actualVal = $Snapshot.gentleAiMarkers[$prop.Name]
    if ([bool]$actualVal -ne [bool]$prop.Value) {
      $errors.Add("gentleAiMarkers.$($prop.Name): actual=$actualVal expected=$($prop.Value)")
    }
  }

  return [pscustomobject]@{
    Ok = ($errors.Count -eq 0)
    Errors = @($errors)
  }
}

function Compare-ProjectManifests {
  param(
    [Parameter(Mandatory = $true)][object[]] $Left,
    [Parameter(Mandatory = $true)][object[]] $Right
  )
  $leftMap = @{}
  foreach ($item in $Left) { $leftMap[$item.Path -replace '\\', '/'] = $item.Hash }
  $rightMap = @{}
  foreach ($item in $Right) { $rightMap[$item.Path -replace '\\', '/'] = $item.Hash }

  $onlyLeft = @($leftMap.Keys | Where-Object { -not $rightMap.ContainsKey($_) } | Sort-Object)
  $onlyRight = @($rightMap.Keys | Where-Object { -not $leftMap.ContainsKey($_) } | Sort-Object)
  $hashDiff = @($leftMap.Keys | Where-Object { $rightMap.ContainsKey($_) -and $leftMap[$_] -ne $rightMap[$_] } | Sort-Object)

  return [pscustomobject]@{
    OnlyLeft = $onlyLeft
    OnlyRight = $onlyRight
    HashDiff = $hashDiff
    Equivalent = ($onlyLeft.Count -eq 0 -and $onlyRight.Count -eq 0 -and $hashDiff.Count -eq 0)
  }
}

function Install-WorkspaceGentleAiMarkers {
  param([Parameter(Mandatory = $true)][string] $TargetPath)
  $paths = @(
    (Join-Path $TargetPath '.cursor\rules\gentle-ai.mdc'),
    (Join-Path $TargetPath '.cursor\agents\sdd-init.md')
  )
  foreach ($path in $paths) {
    $parent = Split-Path -Parent $path
    if (-not (Test-Path -LiteralPath $parent)) {
      New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    Set-Content -LiteralPath $path -Value '# workspace gentle-ai marker' -Encoding UTF8
  }
  Register-TestSandboxWrite -Path $TargetPath
}

function Write-WorkspaceEngramMcp {
  param([Parameter(Mandatory = $true)][string] $TargetPath)
  $cursorDir = Join-Path $TargetPath '.cursor'
  New-Item -ItemType Directory -Path $cursorDir -Force | Out-Null
  $json = @{
    mcpServers = @{
      engram = @{ command = 'engram'; args = @('mcp') }
    }
  } | ConvertTo-Json -Depth 5
  Set-Content -LiteralPath (Join-Path $cursorDir 'mcp.json') -Value ($json + "`n") -Encoding UTF8
  Register-TestSandboxWrite -Path $TargetPath
}

function Get-RealHomeSentinelSnapshot {
  $snap = @()
  $realHome = [Environment]::GetFolderPath('UserProfile')
  foreach ($relative in @('.cursor\mcp.json', '.gentle-ai\state.json', '.cursor\rules\gentle-ai.mdc')) {
    $path = Join-Path $realHome $relative
    if (Test-Path -LiteralPath $path -PathType Leaf) {
      $item = Get-Item -LiteralPath $path
      $snap += [pscustomobject]@{
        Path = $path
        Length = $item.Length
        LastWriteTimeUtc = $item.LastWriteTimeUtc
      }
    }
  }
  return $snap
}

function Assert-SentinelSnapshotUnchanged {
  param([Parameter(Mandatory = $true)][object[]] $Before)
  foreach ($sentinel in $Before) {
    if (-not (Test-Path -LiteralPath $sentinel.Path -PathType Leaf)) {
      throw "Sentinel desapareció: $($sentinel.Path)"
    }
    $item = Get-Item -LiteralPath $sentinel.Path
    if ($item.Length -ne $sentinel.Length -or $item.LastWriteTimeUtc -ne $sentinel.LastWriteTimeUtc) {
      throw "Sentinel modificado: $($sentinel.Path)"
    }
  }
}
