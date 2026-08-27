#Requires -Version 5.1
Set-StrictMode -Version Latest

function New-TestProjectDirectory {
  param(
    [Parameter(Mandatory = $true)][string] $ParentPath,
    [Parameter(Mandatory = $true)][string] $FolderName
  )

  $target = [System.IO.Path]::GetFullPath((Join-Path $ParentPath $FolderName))
  if (-not (Test-Path -LiteralPath $target)) {
    New-Item -ItemType Directory -Path $target -Force | Out-Null
  }
  if (Get-Command Register-TestSandboxWrite -ErrorAction SilentlyContinue) {
    Register-TestSandboxWrite -Path $target
  }
  return $target
}

function Remove-TestProjectDirectory {
  param([Parameter(Mandatory = $true)][string] $TargetPath)
  if (Test-Path -LiteralPath $TargetPath) {
    Remove-Item -LiteralPath $TargetPath -Recurse -Force
  }
}

function Copy-TestFixtureTree {
  param(
    [Parameter(Mandatory = $true)][string] $SourcePath,
    [Parameter(Mandatory = $true)][string] $TargetPath
  )

  if (-not (Test-Path -LiteralPath $SourcePath)) {
    throw "Fixture no encontrado: $SourcePath"
  }
  if (-not (Test-Path -LiteralPath $TargetPath)) {
    New-Item -ItemType Directory -Path $TargetPath -Force | Out-Null
  }
  Get-ChildItem -LiteralPath $SourcePath -Force | Copy-Item -Destination $TargetPath -Recurse -Force
  if (Get-Command Register-TestSandboxWrite -ErrorAction SilentlyContinue) {
    Register-TestSandboxWrite -Path $TargetPath
  }
  return $TargetPath
}
