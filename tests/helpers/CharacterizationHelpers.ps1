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
  $sandbox = Initialize-TestSandbox -FakeHomeFixture $FakeHomeFixture -WithFakeCommands:$WithFakeCommands -PesterTestDrive $TestDrive
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
  return @(@($names | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }))
}

function Get-NormalizedProjectManifest {
  param(
    [Parameter(Mandatory = $true)][string] $ProjectRoot,
    [string[]] $ExcludePatterns = @('\.git\\', 'onboarding-pending\.json')
  )

  $files = @()
  Get-ChildItem -LiteralPath $ProjectRoot -Recurse -File -Force | ForEach-Object {
    $relative = $_.FullName.Substring($ProjectRoot.Length).TrimStart('\', '/')
    $skip = $false
    foreach ($pattern in $ExcludePatterns) {
      if ($relative -match $pattern) { $skip = $true; break }
    }
    if ($skip) { return }

    $hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
    if ($_.Extension -eq '.json') {
      try {
        $json = Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($prop in @('generatedAt', 'createdAt')) {
          if ($json.PSObject.Properties.Name -contains $prop) {
            $json.PSObject.Properties.Remove($prop)
          }
        }
        $normalized = $json | ConvertTo-Json -Depth 20
        $bytes = [Text.Encoding]::UTF8.GetBytes($normalized)
        $stream = [System.IO.MemoryStream]::new($bytes)
        try {
          $hash = (Get-FileHash -InputStream $stream -Algorithm SHA256).Hash
        } finally {
          $stream.Dispose()
        }
      } catch { }
    }
    $files += [pscustomobject]@{ Path = $relative; Hash = $hash }
  }
  return @($files | Sort-Object Path)
}

function Compare-ProjectManifests {
  param(
    [Parameter(Mandatory = $true)][object[]] $Left,
    [Parameter(Mandatory = $true)][object[]] $Right
  )
  $leftMap = @{}
  foreach ($item in $Left) { $leftMap[$item.Path] = $item.Hash }
  $rightMap = @{}
  foreach ($item in $Right) { $rightMap[$item.Path] = $item.Hash }

  $onlyLeft = @($leftMap.Keys | Where-Object { -not $rightMap.ContainsKey($_) })
  $onlyRight = @($rightMap.Keys | Where-Object { -not $leftMap.ContainsKey($_) })
  $hashDiff = @($leftMap.Keys | Where-Object { $rightMap.ContainsKey($_) -and $leftMap[$_] -ne $rightMap[$_] })

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
