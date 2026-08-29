#Requires -Version 5.1

BeforeAll {
  $script:testsRoot = $PSScriptRoot | Split-Path -Parent
  $script:repoRoot = Split-Path -Parent $script:testsRoot
  $script:copilotModule = Join-Path (Join-Path (Join-Path $script:repoRoot 'scripts') 'lib') 'ConsultingCopilot.psm1'
  $script:templatePath = Join-Path (Join-Path (Join-Path $script:repoRoot 'scripts') 'templates') 'Test-ProjectEnvironment.ps1'
  Import-Module $script:copilotModule -Force
}

Describe 'Sync-ProjectEnvironmentDoctorScript' {
  It 'copia la plantilla a scripts/Test-ProjectEnvironment.ps1 creando scripts/ si falta' {
    $dir = Join-Path $TestDrive 'emit-doctor'
    New-Item -ItemType Directory -Path $dir | Out-Null
    Sync-ProjectEnvironmentDoctorScript -TargetPath $dir
    $dest = Join-Path $dir 'scripts/Test-ProjectEnvironment.ps1'
    Test-Path -LiteralPath $dest -PathType Leaf | Should -Be $true
    (Get-FileHash -LiteralPath $dest -Algorithm SHA256).Hash |
      Should -Be (Get-FileHash -LiteralPath $script:templatePath -Algorithm SHA256).Hash
  }

  It 'Write-ProjectProfile emite el doctor' {
    $dir = Join-Path $TestDrive 'profile-doctor'
    New-Item -ItemType Directory -Path $dir | Out-Null
    Write-ProjectProfile -TargetPath $dir -ProjectName 'demo' -GentleAiScope 'Global'
    Test-Path -LiteralPath (Join-Path $dir 'scripts/Test-ProjectEnvironment.ps1') -PathType Leaf | Should -Be $true
  }
}

Describe 'Invoke-HubProjectEnvironmentDoctor DoD' {
  It 'AsJson shape congelado + local-mcp not-materialized informativo sin MCP local requerido' {
    $dir = Join-Path $TestDrive 'doctor-gentle'
    New-Item -ItemType Directory -Path $dir | Out-Null
    Write-ProjectProfile -TargetPath $dir -ProjectName 'demo' -GentleAiScope 'Global'
    $result = Invoke-HubProjectEnvironmentDoctor -TargetPath $dir
    $result.PSObject.Properties.Name | Should -Contain 'ok'
    $result.PSObject.Properties.Name | Should -Contain 'exitCode'
    $result.PSObject.Properties.Name | Should -Contain 'checks'
    $mcp = @($result.checks | Where-Object { $_.id -eq 'local-mcp' }) | Select-Object -First 1
    $mcp | Should -Not -BeNullOrEmpty
    $mcp.state | Should -Be 'not-materialized'
    $mcp.pass | Should -Be $true
    $mcp.level | Should -Be 'optional'
  }

  It 'MCP broken (JSON invalido) → exit 2 y state broken' {
    $dir = Join-Path $TestDrive 'doctor-broken-mcp'
    New-Item -ItemType Directory -Path $dir | Out-Null
    Write-EngagementMetadata -TargetPath $dir -StackProfileValue 'consulting-only' -Fields (@{
        includeDrawioMcp = $false
        includeBacklogMcp = $false
        includeArchiMcp = $false
        gentleAiScope = 'none'
        requestedProfile = 'Consulting'
        engramMcpSource = 'none'
      })
    $cursor = Join-Path $dir '.cursor'
    New-Item -ItemType Directory -Path $cursor -Force | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $cursor 'mcp.json'), "{ not-json `n", [System.Text.UTF8Encoding]::new($false))
    $result = Invoke-HubProjectEnvironmentDoctor -TargetPath $dir
    $mcp = @($result.checks | Where-Object { $_.id -eq 'local-mcp' }) | Select-Object -First 1
    $mcp.state | Should -Be 'broken'
    $mcp.pass | Should -Be $false
    $result.exitCode | Should -Be 2
    $result.ok | Should -Be $false
  }

  It 'MCP con engram → broken exit 2' {
    $dir = Join-Path $TestDrive 'doctor-engram-mcp'
    New-Item -ItemType Directory -Path $dir | Out-Null
    Write-EngagementMetadata -TargetPath $dir -StackProfileValue 'consulting-only' -Fields (@{
        includeDrawioMcp = $false
        includeBacklogMcp = $false
        includeArchiMcp = $false
        gentleAiScope = 'none'
        requestedProfile = 'Consulting'
        engramMcpSource = 'none'
      })
    $cursor = Join-Path $dir '.cursor'
    New-Item -ItemType Directory -Path $cursor -Force | Out-Null
    $mcpBody = @{ mcpServers = @{ engram = @{ command = 'engram' } } } | ConvertTo-Json -Depth 5
    [System.IO.File]::WriteAllText((Join-Path $cursor 'mcp.json'), $mcpBody + "`n", [System.Text.UTF8Encoding]::new($false))
    $result = Invoke-HubProjectEnvironmentDoctor -TargetPath $dir
    $mcp = @($result.checks | Where-Object { $_.id -eq 'local-mcp' }) | Select-Object -First 1
    $mcp.state | Should -Be 'broken'
    $result.exitCode | Should -Be 2
  }

  It 'plantilla portable no importa modulos del hub' {
    $raw = Get-Content -LiteralPath $script:templatePath -Raw
    $raw | Should -Not -Match '(?m)^Import-Module\b'
    $raw | Should -Not -Match 'ConsultingCopilot\.psm1'
  }

  It 'not-materialized falla exit solo si drawio/backlog/archi required' {
    $dir = Join-Path $TestDrive 'doctor-mcp-required'
    New-Item -ItemType Directory -Path $dir | Out-Null
    Write-EngagementMetadata -TargetPath $dir -StackProfileValue 'consulting-ai' -Fields (@{
        includeDrawioMcp = $true
        includeBacklogMcp = $false
        includeArchiMcp = $false
        gentleAiScope = 'none'
        requestedProfile = 'Consulting'
        engramMcpSource = 'none'
      })
    # Ensure no mcp.json
    $mcpPath = Join-Path $dir '.cursor/mcp.json'
    if (Test-Path -LiteralPath $mcpPath) { Remove-Item -LiteralPath $mcpPath -Force }
    $result = Invoke-HubProjectEnvironmentDoctor -TargetPath $dir
    $mcp = @($result.checks | Where-Object { $_.id -eq 'local-mcp' }) | Select-Object -First 1
    $mcp.state | Should -Be 'not-materialized'
    $mcp.pass | Should -Be $false
    $mcp.level | Should -Be 'required'
    $result.exitCode | Should -Be 2
  }
}

Describe 'Doctor exit / AsJson / optional (Phase 4.5)' {
  It 'optional pandoc missing mantiene exit 0 si required pasan' {
    $dir = Join-Path $TestDrive 'doctor-optional-pandoc'
    New-Item -ItemType Directory -Path $dir | Out-Null
    Write-EngagementMetadata -TargetPath $dir -StackProfileValue 'consulting-only' -Fields (@{
        includeDrawioMcp = $false
        includeBacklogMcp = $false
        includeArchiMcp = $false
        gentleAiScope = 'none'
        requestedProfile = 'Consulting'
        engramMcpSource = 'none'
      })
    Mock Test-HubToolUsable {
      param($Id, $Policy, $ArchiPath, $VersionInvoker)
      $ok = $Id -ne 'pandoc'
      [pscustomobject]@{
        Id = $Id; Ok = $ok; Path = if ($ok) { "/usr/bin/$Id" } else { $null }
        Paths = @(); Status = if ($ok) { 'Ok' } else { 'Missing' }; Message = $null; Policy = 'ge1-usable'
      }
    } -ModuleName ConsultingCopilot

    $result = Invoke-HubProjectEnvironmentDoctor -TargetPath $dir
    $pandoc = @($result.checks | Where-Object { $_.id -eq 'pandoc' }) | Select-Object -First 1
    $pandoc.level | Should -Be 'optional'
    $pandoc.pass | Should -Be $false
    $result.exitCode | Should -Be 0
    $result.ok | Should -Be $true
  }

  It 'AsJson parity child vs hub mismos ids/levels/pass para TargetPath' {
    $dir = Join-Path $TestDrive 'doctor-parity'
    New-Item -ItemType Directory -Path $dir | Out-Null
    Write-ProjectProfile -TargetPath $dir -ProjectName 'parity' -GentleAiScope 'Global'
    $hubJson = Invoke-HubProjectEnvironmentDoctor -TargetPath $dir -AsJson | ConvertFrom-Json
    $childScript = Join-Path $dir 'scripts/Test-ProjectEnvironment.ps1'
    $childText = & pwsh -NoProfile -File $childScript -AsJson 2>$null
    $childJson = $childText | ConvertFrom-Json

    $childIds = @($childJson.checks | Where-Object { $_.id -ne 'gentle-ai-dual' } | ForEach-Object { '{0}:{1}:{2}' -f $_.id, $_.level, [bool]$_.pass } | Sort-Object)
    # Shared tool + local-mcp vector must match (dual check is hub-optional inform).
    $hubCore = @($hubJson.checks | Where-Object { $_.id -ne 'gentle-ai-dual' } | ForEach-Object { '{0}:{1}:{2}' -f $_.id, $_.level, [bool]$_.pass } | Sort-Object)
    ($hubCore -join '|') | Should -Be ($childIds -join '|')
    $hubJson.PSObject.Properties.Name | Should -Contain 'ok'
    $childJson.PSObject.Properties.Name | Should -Contain 'exitCode'
  }
}

Describe 'Doctor invariants (Phase 4.6)' {
  It 'dual gentle-ai diagnostica sin mutar marcadores' {
    $fakeHome = Join-Path $TestDrive 'dual-home'
    $dir = Join-Path $TestDrive 'dual-ws'
    New-Item -ItemType Directory -Path $fakeHome -Force | Out-Null
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $env:TEST_USER_HOME = $fakeHome
    try {
      Write-ProjectProfile -TargetPath $dir -ProjectName 'dual' -GentleAiScope 'Global'
      $globalRule = Join-Path $fakeHome '.cursor/rules/gentle-ai.mdc'
      $wsRule = Join-Path $dir '.cursor/rules/gentle-ai.mdc'
      New-Item -ItemType Directory -Path (Split-Path $globalRule -Parent) -Force | Out-Null
      New-Item -ItemType Directory -Path (Split-Path $wsRule -Parent) -Force | Out-Null
      Set-Content -LiteralPath $globalRule -Value '# global-marker' -Encoding UTF8
      Set-Content -LiteralPath $wsRule -Value '# workspace-marker' -Encoding UTF8
      $beforeG = Get-Content -LiteralPath $globalRule -Raw
      $beforeW = Get-Content -LiteralPath $wsRule -Raw

      $result = Invoke-HubProjectEnvironmentDoctor -TargetPath $dir
      $dual = @($result.checks | Where-Object { $_.id -eq 'gentle-ai-dual' }) | Select-Object -First 1
      $dual | Should -Not -BeNullOrEmpty
      $dual.level | Should -Be 'optional'
      $dual.pass | Should -Be $false
      (Get-Content -LiteralPath $globalRule -Raw) | Should -Be $beforeG
      (Get-Content -LiteralPath $wsRule -Raw) | Should -Be $beforeW
    } finally {
      Remove-Item Env:TEST_USER_HOME -ErrorAction SilentlyContinue
    }
  }

  It 'WSL Windows-origin reject preservado en Test-HubToolUsable gentle-ai' {
    Mock Resolve-GentleAiCliStatus {
      [pscustomobject]@{
        Status = 'WindowsOriginRejected'
        Path = $null
        Paths = @()
        RejectedPaths = @('/mnt/c/tools/gentle-ai.exe')
        InvalidPaths = @()
        Message = 'gentle-ai detectado sólo como binario Windows (inválido en Linux/WSL)'
      }
    } -ModuleName ConsultingCopilot

    $probe = Test-HubToolUsable -Id 'gentle-ai'
    $probe.Ok | Should -Be $false
    $probe.Status | Should -Be 'WindowsOriginRejected'
    $probe.Message | Should -Match 'Windows'
  }

  It 'local-mcp not-materialized ≠ broken cuando no hay MCP local requerido' {
    $dir = Join-Path $TestDrive 'mcp-states'
    New-Item -ItemType Directory -Path $dir | Out-Null
    Write-ProjectProfile -TargetPath $dir -ProjectName 'mcp-states' -GentleAiScope 'Global'
    $result = Invoke-HubProjectEnvironmentDoctor -TargetPath $dir
    $mcp = @($result.checks | Where-Object { $_.id -eq 'local-mcp' }) | Select-Object -First 1
    $mcp.state | Should -Be 'not-materialized'
    $mcp.state | Should -Not -Be 'broken'
  }
}

Describe 'Child portable fallback parity (Phase 4.7)' {
  It 'schema 3 + drawio: child y hub tratan node/npm/npx como required con mismo pass' {
    $dir = Join-Path $TestDrive 'portable-parity'
    New-Item -ItemType Directory -Path $dir | Out-Null
    $meta = [ordered]@{
      schemaVersion = 3
      stackProfile = 'consulting-only'
      includeDrawioMcp = $true
      includeBacklogMcp = $false
      includeArchiMcp = $false
      gentleAiScope = 'none'
      requestedProfile = 'Consulting'
    }
    [System.IO.File]::WriteAllText(
      (Join-Path $dir '.consulting-engagement.json'),
      (($meta | ConvertTo-Json -Depth 6) + "`n"),
      [System.Text.UTF8Encoding]::new($false)
    )
    Sync-ProjectEnvironmentDoctorScript -TargetPath $dir

    $hubReq = Get-HubProjectRequirements -TargetPath $dir
    foreach ($id in @('node', 'npm', 'npx')) {
      ($hubReq.tools | Where-Object { $_.id -eq $id }).level | Should -Be 'required'
    }

    $hub = Invoke-HubProjectEnvironmentDoctor -TargetPath $dir
    $childText = & pwsh -NoProfile -File (Join-Path $dir 'scripts/Test-ProjectEnvironment.ps1') -AsJson 2>$null
    $child = $childText | ConvertFrom-Json

    foreach ($id in @('node', 'npm', 'npx')) {
      $h = @($hub.checks | Where-Object { $_.id -eq $id }) | Select-Object -First 1
      $c = @($child.checks | Where-Object { $_.id -eq $id }) | Select-Object -First 1
      $h | Should -Not -BeNullOrEmpty
      $c | Should -Not -BeNullOrEmpty
      $h.level | Should -Be 'required'
      $c.level | Should -Be 'required'
      [bool]$h.pass | Should -Be ([bool]$c.pass)
    }
  }
}

Describe 'Env doctor parity fixes (local-mcp / backlog / ge1 / labels)' {
  BeforeAll {
    $raw = Get-Content -LiteralPath $script:templatePath -Raw
    $chunk = ($raw -split '(?m)^# --- Entry ---')[0]
    $fnStart = $chunk.IndexOf('function ')
    $helpers = $chunk.Substring($fnStart)
    $script:portableHelpersPath = Join-Path $TestDrive 'portable-doctor-helpers.ps1'
    Set-Content -LiteralPath $script:portableHelpersPath -Value $helpers -Encoding UTF8
  }

  It 'local-mcp Archi Windows-origin (/mnt/c o .exe): hub y portable same pass/state/exit' {
    if (-not ($IsLinux -or -not [string]::IsNullOrWhiteSpace($env:WSL_DISTRO_NAME))) {
      Set-ItResult -Inconclusive -Because 'Requiere Linux/WSL para política Windows-origin'
      return
    }

    $archiPath = $null
    $mntCleanup = $null
    if (Test-Path -LiteralPath '/mnt/c' -PathType Container) {
      try {
        $mntDir = Join-Path '/mnt/c' ('tmp-hub-env-doctor-' + [guid]::NewGuid().ToString('n'))
        New-Item -ItemType Directory -Path $mntDir -Force -ErrorAction Stop | Out-Null
        $archiPath = Join-Path $mntDir 'index.js'
        Set-Content -LiteralPath $archiPath -Value '// fake archi' -Encoding UTF8
        $mntCleanup = $mntDir
      } catch {
        $archiPath = $null
      }
    }
    if (-not $archiPath) {
      $archiPath = Join-Path $TestDrive 'fake-archi-mcp.exe'
      Set-Content -LiteralPath $archiPath -Value '// fake' -Encoding UTF8
    }

    try {
      $dir = Join-Path $TestDrive 'archi-win-parity'
      New-Item -ItemType Directory -Path $dir | Out-Null
      Write-EngagementMetadata -TargetPath $dir -StackProfileValue 'consulting-only' -Fields (@{
          includeDrawioMcp = $false
          includeBacklogMcp = $false
          includeArchiMcp = $true
          gentleAiScope = 'none'
          requestedProfile = 'Consulting'
          engramMcpSource = 'none'
        })
      $cursor = Join-Path $dir '.cursor'
      New-Item -ItemType Directory -Path $cursor -Force | Out-Null
      $mcpBody = @{
        mcpServers = @{
          archi = @{
            command = 'node'
            args = @($archiPath)
          }
        }
      } | ConvertTo-Json -Depth 6
      [System.IO.File]::WriteAllText((Join-Path $cursor 'mcp.json'), $mcpBody + "`n", [System.Text.UTF8Encoding]::new($false))
      Sync-ProjectEnvironmentDoctorScript -TargetPath $dir

      $hub = Invoke-HubProjectEnvironmentDoctor -TargetPath $dir
      $childText = & pwsh -NoProfile -File (Join-Path $dir 'scripts/Test-ProjectEnvironment.ps1') -AsJson 2>$null
      $child = $childText | ConvertFrom-Json

      $hubMcp = @($hub.checks | Where-Object { $_.id -eq 'local-mcp' }) | Select-Object -First 1
      $childMcp = @($child.checks | Where-Object { $_.id -eq 'local-mcp' }) | Select-Object -First 1
      $hubMcp.state | Should -Be 'broken'
      $childMcp.state | Should -Be 'broken'
      [bool]$hubMcp.pass | Should -Be $false
      [bool]$childMcp.pass | Should -Be $false
      $hub.exitCode | Should -Be 2
      $child.exitCode | Should -Be 2
      [bool]$hub.ok | Should -Be ([bool]$child.ok)
    } finally {
      if ($mntCleanup -and (Test-Path -LiteralPath $mntCleanup)) {
        Remove-Item -LiteralPath $mntCleanup -Recurse -Force -ErrorAction SilentlyContinue
      }
    }
  }

  It 'portable backlog Duplicate (multi-hit) falla como Resolve-BacklogCliStatus' {
    . $script:portableHelpersPath
    Mock Get-PortableRawCommandPaths {
      @('/usr/bin/backlog', '/usr/local/bin/backlog')
    }
    Mock Test-PortableVersionOk { $true }
    Mock Test-PortableIsLinuxLike { $true }
    Mock Test-PortableWindowsOriginPath { $false }

    $probe = Test-PortableBacklogCli
    $probe.Ok | Should -Be $false
    $probe.Status | Should -Be 'Duplicate'
  }

  It 'hub doctor ES message backlog discrimina Duplicate (no solo Falta)' {
    $msg = Get-HubToolDoctorEsMessage -Id 'backlog' -Pass $false -Status 'Duplicate' -Detail ''
    $msg | Should -Match 'más de una'
    $msg | Should -Not -Match '^Falta la CLI de backlog'
  }

  It 'Test-HubChildEnvironment.ps1 -AsJson es ConvertFrom-Json limpio' {
    $dir = Join-Path $TestDrive 'asjson-entrypoint'
    New-Item -ItemType Directory -Path $dir | Out-Null
    Write-ProjectProfile -TargetPath $dir -StackProfile 'GentleAi' -GentleAiScope 'Global'
    Sync-ProjectEnvironmentDoctorScript -TargetPath $dir
    $entry = Join-Path $script:repoRoot 'scripts/Test-HubChildEnvironment.ps1'
    $raw = & pwsh -NoProfile -File $entry -TargetPath $dir -AsJson 2>$null
    { $raw | ConvertFrom-Json } | Should -Not -Throw
    $json = $raw | ConvertFrom-Json
    $json.ok | Should -BeOfType [bool]
    $json.PSObject.Properties.Name | Should -Contain 'exitCode'
    $json.PSObject.Properties.Name | Should -Contain 'checks'
  }

  It 'Get-PortableCommandPaths filtra Windows-origin en LinuxLike (ge1)' {
    . $script:portableHelpersPath
    Mock Get-PortableRawCommandPaths {
      @('/usr/bin/node', '/mnt/c/Program Files/nodejs/node.exe')
    }
    Mock Test-PortableIsLinuxLike { $true }

    $paths = @(Get-PortableCommandPaths -Name 'node')
    $paths | Should -Contain '/usr/bin/node'
    $paths | Should -Not -Contain '/mnt/c/Program Files/nodejs/node.exe'
  }

  It 'GETTING-STARTED profile label no menciona Engram' {
    $dir = Join-Path $TestDrive 'label-gs'
    New-Item -ItemType Directory -Path $dir | Out-Null
    Write-ProjectGettingStarted -TargetPath $dir -StackProfile 'Full' -Title 'demo' -GentleAiScope 'Global'
    $gs = Get-Content -LiteralPath (Join-Path $dir 'docs/GETTING-STARTED.md') -Raw
    $gs | Should -Not -Match '(?i)\bEngram\b'
    $gs | Should -Match 'memoria del asistente'
    # Profile label line specifically (not just body copy)
    $gs | Should -Match 'Full \(CDD \+ SDD \+ memoria del asistente\)'
  }

  It 'MCP Engram key compare es case-insensitive en hub' {
    $dir = Join-Path $TestDrive 'engram-case'
    New-Item -ItemType Directory -Path $dir | Out-Null
    Write-EngagementMetadata -TargetPath $dir -StackProfileValue 'consulting-only' -Fields (@{
        includeDrawioMcp = $false
        includeBacklogMcp = $false
        includeArchiMcp = $false
        gentleAiScope = 'none'
        requestedProfile = 'Consulting'
        engramMcpSource = 'none'
      })
    $cursor = Join-Path $dir '.cursor'
    New-Item -ItemType Directory -Path $cursor -Force | Out-Null
    # Force unusual casing via raw JSON (ConvertTo-Json would normalize)
    $mcpBody = '{"mcpServers":{"Engram":{"command":"engram"}}}'
    [System.IO.File]::WriteAllText((Join-Path $cursor 'mcp.json'), $mcpBody + "`n", [System.Text.UTF8Encoding]::new($false))
    $result = Invoke-HubProjectEnvironmentDoctor -TargetPath $dir
    $mcp = @($result.checks | Where-Object { $_.id -eq 'local-mcp' }) | Select-Object -First 1
    $mcp.state | Should -Be 'broken'
    $result.exitCode | Should -Be 2
  }
}
