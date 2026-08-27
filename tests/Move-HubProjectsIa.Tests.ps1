#Requires -Version 5.1

BeforeAll {
  $script:repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
  Import-Module (Join-Path $script:repoRoot 'scripts\lib\ConsultingCopilot.psm1') -Force

  function New-TestHubLayout {
    param(
      [Parameter(Mandatory = $true)][string] $Root,
      [string[]] $Projects = @('demo-client-u01')
    )

    $paths = @(
      'hub-registry.json',
      'scripts\New-HubProject.ps1',
      'skeleton\README.md',
      'projects\.gitkeep'
    )
    foreach ($relative in $paths) {
      $full = Join-Path $Root $relative
      $parent = Split-Path -Parent $full
      if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
      }
      if ($relative.EndsWith('.json')) { continue }
      if (-not (Test-Path -LiteralPath $full)) {
        Set-Content -LiteralPath $full -Value '# test' -Encoding UTF8
      }
    }

    $registryProjects = @()
    foreach ($folder in $Projects) {
      $projectPath = [System.IO.Path]::GetFullPath((Join-Path $Root "projects\$folder"))
      $cursorDir = Join-Path $projectPath '.cursor'
      New-Item -ItemType Directory -Path $cursorDir -Force | Out-Null

      $mcp = @{
        mcpServers = @{
          backlog = @{
            command = 'backlog'
            args = @('mcp', 'start', '--cwd', $projectPath)
          }
        }
      } | ConvertTo-Json -Depth 6
      Set-Content -LiteralPath (Join-Path $cursorDir 'mcp.json') -Value ($mcp + "`n") -Encoding UTF8

      $registryProjects += [ordered]@{
        folderName = $folder
        absolutePath = $projectPath
        stackProfile = 'Full'
      }
    }

    $registry = [ordered]@{
      schemaVersion = 1
      projects = $registryProjects
    }
    $registryPath = Join-Path $Root 'hub-registry.json'
    Set-Content -LiteralPath $registryPath -Value (($registry | ConvertTo-Json -Depth 8) + "`n") -Encoding UTF8
  }
}

Describe 'Move-HubProjectsIa' {
  Context 'Resolución de rutas del hub' {
    It 'normaliza barras finales' {
      $normalized = Resolve-HubRootPath (Join-Path $TestDrive 'hub\')
      $normalized | Should -Be (Resolve-HubRootPath (Join-Path $TestDrive 'hub'))
    }

    It 'detecta rutas hijas' {
      $parent = Join-Path $TestDrive 'hub-parent'
      $child = Join-Path $parent 'projects\demo'
      New-Item -ItemType Directory -Path $child -Force | Out-Null
      (Test-HubPathIsChildOf -ChildPath $child -ParentPath $parent) | Should -Be $true
      (Test-HubPathIsChildOf -ChildPath $parent -ParentPath $child) | Should -Be $false
    }
  }

  Context 'Precondiciones de migración' {
    It 'rechaza destino dentro del origen' {
      $source = Join-Path $TestDrive 'source-hub'
      $destination = Join-Path $source 'nested\dest'
      New-TestHubLayout -Root $source

      $result = Test-HubMovePreconditions -SourcePath $source -DestinationPath $destination
      $result.Ok | Should -Be $false
      ($result.Issues -join ' ') | Should -Match 'dentro del hub origen'
    }

    It 'rechaza origen que no parece hub' {
      $source = Join-Path $TestDrive 'not-a-hub'
      $destination = Join-Path $TestDrive 'dest-hub'
      New-Item -ItemType Directory -Path $source -Force | Out-Null

      $result = Test-HubMovePreconditions -SourcePath $source -DestinationPath $destination
      $result.Ok | Should -Be $false
      ($result.Issues -join ' ') | Should -Match 'Faltan:'
    }

    It 'acepta origen y destino válidos' {
      $source = Join-Path $TestDrive 'valid-source'
      $destination = Join-Path $TestDrive 'valid-dest'
      New-TestHubLayout -Root $source

      $result = Test-HubMovePreconditions -SourcePath $source -DestinationPath $destination
      $result.Ok | Should -Be $true
      @($result.Issues).Count | Should -Be 0
    }
  }

  Context 'Actualización de rutas' {
    It 'actualiza hub-registry.json y mcp.json de hijos' {
      $oldHub = Join-Path $TestDrive 'old-hub'
      $newHub = Join-Path $TestDrive 'new-hub'
      New-TestHubLayout -Root $oldHub -Projects @('client-a-u01', 'client-b-u02')

      Copy-Item -LiteralPath $oldHub -Destination $newHub -Recurse -Force
      $updates = Update-HubPathReferences -HubRoot $newHub -OldHubRoot $oldHub

      $updates.Registry.SchemaVersion | Should -Be 2
      $updates.UpdatedMcpFiles.Count | Should -Be 2

      $registry = Get-Content (Join-Path $newHub 'hub-registry.json') -Raw | ConvertFrom-Json
      $registry.schemaVersion | Should -Be 2
      foreach ($project in @($registry.projects)) {
        $project.PSObject.Properties.Name | Should -Contain 'relativePath'
        $project.PSObject.Properties.Name | Should -Not -Contain 'absolutePath'
        $resolved = Resolve-HubProjectPath -HubRoot $newHub -Project $project
        $resolved | Should -BeLike "$newHub*"
        (Test-Path -LiteralPath $resolved) | Should -Be $true
      }

      foreach ($mcpFile in $updates.UpdatedMcpFiles) {
        $raw = Get-Content -LiteralPath $mcpFile -Raw
        $raw | Should -Not -Match ([regex]::Escape($oldHub))
        $mcp = $raw | ConvertFrom-Json
        $cwd = [string]$mcp.mcpServers.backlog.args[3]
        $cwd.StartsWith($newHub, [StringComparison]::OrdinalIgnoreCase) | Should -Be $true
        (Test-Path -LiteralPath $cwd) | Should -Be $true
      }
    }
  }

  Context 'Validación post-migración' {
    It 'detecta absolutePath fuera del hub' {
      $hub = Join-Path $TestDrive 'broken-hub'
      New-TestHubLayout -Root $hub -Projects @('broken-u01')

      $registryPath = Join-Path $hub 'hub-registry.json'
      $registry = Get-Content $registryPath -Raw | ConvertFrom-Json
      $registry.projects[0].absolutePath = Join-Path $TestDrive 'outside-hub'
      Set-Content -LiteralPath $registryPath -Value (($registry | ConvertTo-Json -Depth 8) + "`n") -Encoding UTF8

      $result = Test-HubMoveResult -HubRoot $hub
      $result.Ok | Should -Be $false
      ($result.Issues -join ' ') | Should -Match 'fuera del hub'
    }

    It 'valida un hub consistente' {
      $hub = Join-Path $TestDrive 'good-hub'
      New-TestHubLayout -Root $hub -Projects @('good-u01')

      $result = Test-HubMoveResult -HubRoot $hub
      $result.Ok | Should -Be $true
      @($result.Issues).Count | Should -Be 0
    }
  }

  Context 'Migración integrada' {
    It 'crea backup, mueve el hub y deja rutas coherentes' {
      $source = Join-Path $TestDrive 'move-source'
      $destination = Join-Path $TestDrive 'move-dest'
      $backupRoot = Join-Path $TestDrive 'backups'
      New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
      New-TestHubLayout -Root $source -Projects @('move-u01')

      $backupPath = Join-Path $backupRoot 'move-source-backup-test'
      New-HubMoveBackup -SourcePath $source -BackupPath $backupPath | Out-Null
      (Test-Path -LiteralPath $backupPath) | Should -Be $true

      Move-HubRootDirectory -SourcePath $source -DestinationPath $destination | Out-Null
      (Test-Path -LiteralPath $source) | Should -Be $false
      (Test-Path -LiteralPath $destination) | Should -Be $true

      Update-HubPathReferences -HubRoot $destination -OldHubRoot $source | Out-Null
      $validation = Test-HubMoveResult -HubRoot $destination
      $validation.Ok | Should -Be $true

      $backupRegistry = Get-Content (Join-Path $backupPath 'hub-registry.json') -Raw | ConvertFrom-Json
      [string]$backupRegistry.projects[0].absolutePath | Should -BeLike '*move-source*'
    }
  }

  Context 'Invoke-HubRelocate' {
    It 'devuelve plan en WhatIf sin tocar disco' {
      $source = Join-Path $TestDrive 'whatif-source'
      $destination = Join-Path $TestDrive 'whatif-dest'
      New-TestHubLayout -Root $source

      $result = Invoke-HubRelocate -SourcePath $source -DestinationPath $destination -WhatIf
      $result.WhatIf | Should -Be $true
      (Test-Path -LiteralPath $source) | Should -Be $true
      (Test-Path -LiteralPath $destination) | Should -Be $false
    }
  }
}
