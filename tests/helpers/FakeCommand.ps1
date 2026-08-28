#Requires -Version 5.1
Set-StrictMode -Version Latest

function Get-FakeCommandLogPath {
  param([Parameter(Mandatory = $true)][string] $FakeBinDir)
  return Join-Path $FakeBinDir 'fake-command.log'
}

function Clear-FakeCommandLog {
  param([Parameter(Mandatory = $true)][string] $FakeBinDir)
  $logPath = Get-FakeCommandLogPath -FakeBinDir $FakeBinDir
  if (Test-Path -LiteralPath $logPath) {
    Remove-Item -LiteralPath $logPath -Force
  }
}

function Get-FakeCommandLog {
  param([Parameter(Mandatory = $true)][string] $FakeBinDir)
  $logPath = Get-FakeCommandLogPath -FakeBinDir $FakeBinDir
  if (-not (Test-Path -LiteralPath $logPath)) { return @() }
  return @(Get-Content -LiteralPath $logPath -Encoding UTF8 | ForEach-Object { $_ | ConvertFrom-Json })
}

function New-FakeExecutable {
  <#
  .SYNOPSIS
    Crea un ejecutable fake multiplataforma que registra invocaciones en fake-command.log.
  #>
  param(
    [Parameter(Mandatory = $true)][string] $Name,
    [Parameter(Mandatory = $true)][string] $FakeBinDir,
    [int] $ExitCode = 0,
    [string[]] $Stdout = @(),
    [hashtable] $ResponseBySubcommand = @{}
  )

  if (-not (Test-Path -LiteralPath $FakeBinDir)) {
    New-Item -ItemType Directory -Path $FakeBinDir -Force | Out-Null
  }

  $logPath = Get-FakeCommandLogPath -FakeBinDir $FakeBinDir
  $responseJson = ($ResponseBySubcommand | ConvertTo-Json -Compress -Depth 4)

  if ($IsWindows -or ($env:OS -eq 'Windows_NT')) {
    $targetPath = Join-Path $FakeBinDir "$Name.cmd"
    $content = @"
@echo off
setlocal
set FAKE_CMD_LOG=$($logPath.Replace('%', '%%'))
set FAKE_CMD_NAME=$Name
set FAKE_CMD_EXIT=$ExitCode
powershell -NoProfile -Command "& { `$argsJson = (`$args | ConvertTo-Json -Compress); `$entry = [ordered]@{ timestamp = (Get-Date).ToString('o'); name = '$Name'; argv = @(`$args); exitCode = $ExitCode }; Add-Content -LiteralPath '$($logPath.Replace("'", "''"))' -Value (`$entry | ConvertTo-Json -Compress) -Encoding UTF8 }" %*
exit /b $ExitCode
"@
    Set-Content -LiteralPath $targetPath -Value $content -Encoding ASCII
    return $targetPath
  }

  $targetPath = Join-Path $FakeBinDir $Name
  $stdoutLines = if ($Stdout.Count -gt 0) {
    ($Stdout | ForEach-Object { "Write-Output '$($_.Replace("'", "''"))'" }) -join "`n"
  } else {
    ''
  }
  $content = @"
#!/usr/bin/env pwsh
`$ErrorActionPreference = 'Stop'
`$logPath = '$($logPath.Replace("'", "''"))'
`$entry = [ordered]@{
  timestamp = (Get-Date).ToString('o')
  name = '$Name'
  argv = @(`$args)
  exitCode = $ExitCode
}
Add-Content -LiteralPath `$logPath -Value (`$entry | ConvertTo-Json -Compress) -Encoding UTF8
$stdoutLines
exit $ExitCode
"@
  Set-Content -LiteralPath $targetPath -Value $content -Encoding UTF8
  if ($IsLinux -or $IsMacOS) {
    & chmod +x $targetPath
  }
  return $targetPath
}

function New-FakeCommandSet {
  param([Parameter(Mandatory = $true)][string] $FakeBinDir)

  Clear-FakeCommandLog -FakeBinDir $FakeBinDir

  $commands = @(
    @{ Name = 'gentle-ai'; ExitCode = 0 }
    @{ Name = 'go'; ExitCode = 0 }
    @{ Name = 'git'; ExitCode = 0 }
    @{ Name = 'node'; ExitCode = 0 }
    @{ Name = 'npm'; ExitCode = 0 }
    @{ Name = 'npx'; ExitCode = 0 }
    @{ Name = 'backlog'; ExitCode = 0 }
    @{ Name = 'cursor'; ExitCode = 0 }
    @{ Name = 'engram'; ExitCode = 0 }
  )

  $created = @()
  foreach ($cmd in $commands) {
    $created += New-FakeExecutable -Name $cmd.Name -FakeBinDir $FakeBinDir -ExitCode $cmd.ExitCode
  }
  return @($created)
}
