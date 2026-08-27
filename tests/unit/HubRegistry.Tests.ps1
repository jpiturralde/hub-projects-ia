#Requires -Version 5.1

BeforeAll {
  $script:testsRoot = $PSScriptRoot | Split-Path -Parent
  $script:repoRoot = Split-Path -Parent $script:testsRoot
  $module = Join-Path (Join-Path (Join-Path $script:repoRoot 'scripts') 'lib') 'HubRegistry.psm1'
  Import-Module $module -Force
}

Describe 'HubRegistry v1 → v2' {
  BeforeEach {
    $script:hub = Join-Path $TestDrive 'hub-reg'
    New-Item -ItemType Directory -Path (Join-Path $script:hub 'projects' 'demo-u01') -Force | Out-Null
    $script:registryPath = Join-Path $script:hub 'hub-registry.json'
    $v1 = [ordered]@{
      schemaVersion = 1
      projects = @(
        [ordered]@{
          folderName = 'demo-u01'
          absolutePath = (Join-Path $script:hub 'projects' 'demo-u01')
          stackProfile = 'ConsultingAI'
          createdAt = '2026-01-01T00:00:00Z'
          gitInitialized = $true
          clientSlug = 'demo'
          initiativeId = 'U01'
        }
      )
    }
    Set-Content -LiteralPath $script:registryPath -Value (($v1 | ConvertTo-Json -Depth 6) + "`n") -Encoding UTF8
  }

  It 'migra absolutePath a relativePath y preserva metadata' {
    $result = Migrate-HubRegistryToV2 -HubRoot $script:hub -NoBackup
    $result.Changed | Should -Be $true
    $result.SchemaVersion | Should -Be 2

    $raw = Get-Content -LiteralPath $script:registryPath -Raw | ConvertFrom-Json
    $raw.schemaVersion | Should -Be 2
    $raw.projects[0].relativePath | Should -Be 'projects/demo-u01'
    $raw.projects[0].PSObject.Properties.Name | Should -Not -Contain 'absolutePath'
    $raw.projects[0].clientSlug | Should -Be 'demo'
    $raw.projects[0].initiativeId | Should -Be 'U01'
  }

  It 'es idempotente al migrar dos veces' {
    Migrate-HubRegistryToV2 -HubRoot $script:hub -NoBackup | Out-Null
    $first = Get-Content -LiteralPath $script:registryPath -Raw
    $second = Migrate-HubRegistryToV2 -HubRoot $script:hub -NoBackup
    $second.Changed | Should -Be $false
    (Get-Content -LiteralPath $script:registryPath -Raw) | Should -Be $first
  }

  It 'crea backup antes de migrar' {
    $result = Migrate-HubRegistryToV2 -HubRoot $script:hub
    $result.BackupPath | Should -Not -BeNullOrEmpty
    Test-Path -LiteralPath $result.BackupPath | Should -Be $true
    $backup = Get-Content -LiteralPath $result.BackupPath -Raw | ConvertFrom-Json
    $backup.schemaVersion | Should -Be 1
  }

  It 'rechaza rutas externas por defecto' {
    $outside = Join-Path $TestDrive 'outside-proj'
    New-Item -ItemType Directory -Path $outside -Force | Out-Null
    $v1 = Get-Content -LiteralPath $script:registryPath -Raw | ConvertFrom-Json
    $v1.projects[0].absolutePath = $outside
    Set-Content -LiteralPath $script:registryPath -Value (($v1 | ConvertTo-Json -Depth 6) + "`n") -Encoding UTF8
    { Migrate-HubRegistryToV2 -HubRoot $script:hub -NoBackup } | Should -Throw '*externa*'
  }

  It 'resuelve relativePath en runtime' {
    Migrate-HubRegistryToV2 -HubRoot $script:hub -NoBackup | Out-Null
    $read = Read-HubRegistry -HubRoot $script:hub
    $read.Projects[0].Exists | Should -Be $true
    $read.Projects[0].ResolvedPath | Should -Be ([System.IO.Path]::GetFullPath((Join-Path $script:hub 'projects' 'demo-u01')).TrimEnd('\', '/'))
  }

  It 'reporta proyectos faltantes sin eliminar entradas' {
    Migrate-HubRegistryToV2 -HubRoot $script:hub -NoBackup | Out-Null
    Remove-Item -LiteralPath (Join-Path $script:hub 'projects' 'demo-u01') -Recurse -Force
    $portability = Test-HubRegistryPortability -HubRoot $script:hub
    $portability.Ok | Should -Be $false
    ($portability.Issues -join ' ') | Should -Match 'no encontrado'
    $stillThere = (Get-Content -LiteralPath $script:registryPath -Raw | ConvertFrom-Json).projects
    @($stillThere).Count | Should -Be 1
  }

  It 'Add-HubRegistryProject escribe schema v2 relativo' {
    $emptyHub = Join-Path $TestDrive 'empty-hub'
    New-Item -ItemType Directory -Path (Join-Path $emptyHub 'projects' 'nuevo') -Force | Out-Null
    Add-HubRegistryProject -HubRoot $emptyHub -Entry @{
      folderName = 'nuevo'
      stackProfile = 'GentleAi'
      gitInitialized = $false
    }
    $raw = Get-Content (Join-Path $emptyHub 'hub-registry.json') -Raw | ConvertFrom-Json
    $raw.schemaVersion | Should -Be 2
    $raw.projects[0].relativePath | Should -Be 'projects/nuevo'
  }
}
