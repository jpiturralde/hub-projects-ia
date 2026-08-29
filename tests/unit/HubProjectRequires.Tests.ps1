#Requires -Version 5.1

BeforeAll {
  $script:testsRoot = $PSScriptRoot | Split-Path -Parent
  $script:repoRoot = Split-Path -Parent $script:testsRoot
  $script:copilotModule = Join-Path (Join-Path (Join-Path $script:repoRoot 'scripts') 'lib') 'ConsultingCopilot.psm1'
  Import-Module $script:copilotModule -Force
}

Describe 'Build-HubProjectRequires' {
  It 'emite sólo tools no-absent para ConsultingAI + drawio' {
    $req = Build-HubProjectRequires `
      -StackProfileValue 'consulting-ai' `
      -IncludeDrawioMcp $true `
      -IncludeBacklogMcp $false `
      -IncludeArchiMcp $false `
      -GentleAiScope 'global'
    $req.version | Should -Be 1
    $ids = @($req.tools | ForEach-Object { $_.id })
    $ids | Should -Contain 'node'
    $ids | Should -Contain 'npm'
    $ids | Should -Contain 'npx'
    $ids | Should -Contain 'pandoc'
    $ids | Should -Contain 'backlog'
    $ids | Should -Contain 'gentle-ai'
    $ids | Should -Not -Contain 'archi'
    $ids | Should -Not -Contain 'engram'
    ($req.tools | Where-Object { $_.id -eq 'node' }).level | Should -Be 'required'
    ($req.tools | Where-Object { $_.id -eq 'backlog' }).level | Should -Be 'optional'
    ($req.tools | Where-Object { $_.id -eq 'gentle-ai' }).level | Should -Be 'required'
  }

  It 'GentleAi omite tools de consulting y requiere gentle-ai' {
    $req = Build-HubProjectRequires -StackProfileValue 'gentle-ai-only' -GentleAiScope 'global'
    $ids = @($req.tools | ForEach-Object { $_.id })
    $ids | Should -Be @('gentle-ai')
    $req.tools[0].level | Should -Be 'required'
  }

  It 'Consulting sin gentle-ai omite gentle-ai' {
    $req = Build-HubProjectRequires -StackProfileValue 'consulting-only' -GentleAiScope 'none'
    $ids = @($req.tools | ForEach-Object { $_.id })
    $ids | Should -Not -Contain 'gentle-ai'
    $ids | Should -Contain 'pandoc'
    $ids | Should -Contain 'backlog'
  }
}

Describe 'Get-HubProjectRequirements' {
  It 'lee schema 4 requires y normaliza ids omitidos a absent' {
    $dir = Join-Path $TestDrive 'schema4'
    New-Item -ItemType Directory -Path $dir | Out-Null
    $meta = [ordered]@{
      schemaVersion = 4
      stackProfile = 'consulting-ai'
      includeDrawioMcp = $true
      includeBacklogMcp = $false
      includeArchiMcp = $false
      gentleAiScope = 'global'
      requires = [ordered]@{
        version = 1
        tools = @(
          [ordered]@{ id = 'node'; level = 'required' }
          [ordered]@{ id = 'gentle-ai'; level = 'required' }
        )
      }
    }
    [System.IO.File]::WriteAllText(
      (Join-Path $dir '.consulting-engagement.json'),
      (($meta | ConvertTo-Json -Depth 8) + "`n"),
      [System.Text.UTF8Encoding]::new($false)
    )

    $got = Get-HubProjectRequirements -TargetPath $dir
    ($got.tools | Where-Object { $_.id -eq 'node' }).level | Should -Be 'required'
    ($got.tools | Where-Object { $_.id -eq 'gentle-ai' }).level | Should -Be 'required'
    ($got.tools | Where-Object { $_.id -eq 'archi' }).level | Should -Be 'absent'
    ($got.tools | Where-Object { $_.id -eq 'npm' }).level | Should -Be 'absent'
  }

  It 'fallback pre-v4 deriva con Build sin fallar por requires ausente' {
    $dir = Join-Path $TestDrive 'schema3'
    New-Item -ItemType Directory -Path $dir | Out-Null
    $meta = [ordered]@{
      schemaVersion = 3
      stackProfile = 'consulting-only'
      includeDrawioMcp = $false
      includeBacklogMcp = $true
      includeArchiMcp = $false
      gentleAiScope = 'none'
    }
    [System.IO.File]::WriteAllText(
      (Join-Path $dir '.consulting-engagement.json'),
      (($meta | ConvertTo-Json -Depth 6) + "`n"),
      [System.Text.UTF8Encoding]::new($false)
    )

    $got = Get-HubProjectRequirements -TargetPath $dir
    ($got.tools | Where-Object { $_.id -eq 'backlog' }).level | Should -Be 'required'
    ($got.tools | Where-Object { $_.id -eq 'gentle-ai' }).level | Should -Be 'absent'
    ($got.tools | Where-Object { $_.id -eq 'pandoc' }).level | Should -Be 'optional'
  }
}

Describe 'Write-EngagementMetadata schema 4' {
  It 'escribe schemaVersion 4 + requires sin Engram' {
    $dir = Join-Path $TestDrive 'write-meta'
    New-Item -ItemType Directory -Path $dir | Out-Null
    Write-EngagementMetadata -TargetPath $dir -StackProfileValue 'consulting-ai' -Fields ([ordered]@{
      includeDrawioMcp = $true
      includeBacklogMcp = $false
      includeArchiMcp = $false
      gentleAiScope = 'global'
      engramMcpSource = 'gentle-ai-managed'
    })
    $meta = Get-Content (Join-Path $dir '.consulting-engagement.json') -Raw | ConvertFrom-Json
    $meta.schemaVersion | Should -Be 4
    $ids = @($meta.requires.tools | ForEach-Object { $_.id })
    $ids | Should -Contain 'npx'
    $ids | Should -Not -Contain 'engram'
    ($meta.requires.tools | Where-Object { $_.level -eq 'absent' }).Count | Should -Be 0
  }
}

Describe 'Build-/Get-HubProjectRequirements edges (Phase 4.1)' {
  It 'includeArchiMcp fuerza archi+node+npm required' {
    $req = Build-HubProjectRequires `
      -StackProfileValue 'consulting-only' `
      -IncludeArchiMcp $true `
      -GentleAiScope 'none'
    ($req.tools | Where-Object { $_.id -eq 'archi' }).level | Should -Be 'required'
    ($req.tools | Where-Object { $_.id -eq 'node' }).level | Should -Be 'required'
    ($req.tools | Where-Object { $_.id -eq 'npm' }).level | Should -Be 'required'
    @($req.tools | Where-Object { $_.id -eq 'npx' }).Count | Should -Be 0
  }

  It 'schema 4 sin requires cae a Build fallback' {
    $dir = Join-Path $TestDrive 'schema4-noreq'
    New-Item -ItemType Directory -Path $dir | Out-Null
    $meta = [ordered]@{
      schemaVersion = 4
      stackProfile = 'consulting-ai'
      includeDrawioMcp = $true
      includeBacklogMcp = $false
      includeArchiMcp = $false
      gentleAiScope = 'global'
    }
    [System.IO.File]::WriteAllText(
      (Join-Path $dir '.consulting-engagement.json'),
      (($meta | ConvertTo-Json -Depth 6) + "`n"),
      [System.Text.UTF8Encoding]::new($false)
    )
    $got = Get-HubProjectRequirements -TargetPath $dir
    ($got.tools | Where-Object { $_.id -eq 'npx' }).level | Should -Be 'required'
    ($got.tools | Where-Object { $_.id -eq 'gentle-ai' }).level | Should -Be 'required'
  }

  It 'Write-ProjectProfile emite requires non-absent only' {
    $dir = Join-Path $TestDrive 'write-profile-req'
    New-Item -ItemType Directory -Path $dir | Out-Null
    Write-ProjectProfile -TargetPath $dir -ProjectName 'demo' -GentleAiScope 'Global'
    $meta = Get-Content (Join-Path $dir '.project-profile.json') -Raw | ConvertFrom-Json
    $meta.schemaVersion | Should -Be 4
    $ids = @($meta.requires.tools | ForEach-Object { $_.id })
    $ids | Should -Be @('gentle-ai')
    ($meta.requires.tools | Where-Object { $_.level -eq 'absent' }).Count | Should -Be 0
  }
}

Describe 'node/npm/npx ge1-usable (Phase 4.2)' {
  It 'multi-hit usable → Test-HubToolUsable ok' {
    Mock Get-CommandExecutablePaths {
      param($Name, $AllowWindowsExecutable)
      switch ($Name) {
        'node' { return @('/usr/bin/node', '/usr/local/bin/node') }
        'npm' { return @('/usr/bin/npm', '/opt/npm') }
        'npx' { return @('/usr/bin/npx', '/opt/npx') }
        default { return @() }
      }
    } -ModuleName ConsultingCopilot
    Mock Test-HubCommandPathVersionOk { $true } -ModuleName ConsultingCopilot

    (Test-HubToolUsable -Id node).Ok | Should -Be $true
    (Test-HubToolUsable -Id npm).Ok | Should -Be $true
    (Test-HubToolUsable -Id npx).Ok | Should -Be $true
    (Test-HubToolUsable -Id node).Paths.Count | Should -Be 2
  }

  It 'zero usable → Test-HubToolUsable fail' {
    Mock Get-CommandExecutablePaths {
      param($Name, $AllowWindowsExecutable)
      return @("/broken/$Name")
    } -ModuleName ConsultingCopilot
    Mock Test-HubCommandPathVersionOk { $false } -ModuleName ConsultingCopilot

    (Test-HubToolUsable -Id node).Ok | Should -Be $false
    (Test-HubToolUsable -Id npx).Ok | Should -Be $false
  }

  It 'preflight ConsultingAI marca node/npm/npx ok con multi-hit' {
    Mock Get-GentleAiEnvironment {
      [pscustomobject]@{
        CliCount = 1
        CliPath = '/usr/bin/gentle-ai'
        CliPaths = @('/usr/bin/gentle-ai')
        GlobalInstalled = $true
        WorkspaceInstalled = $false
        WorkspaceEngramConfigured = $false
        WorkspaceMarkerPaths = @()
        WorkspaceMcpPath = $null
      }
    } -ModuleName ConsultingCopilot
    Mock Test-HubToolUsable {
      param($Id, $Policy, $ArchiPath, $VersionInvoker)
      [pscustomobject]@{ Id = $Id; Ok = $true; Path = "/usr/bin/$Id"; Paths = @("/a/$Id", "/b/$Id"); Status = 'Ok'; Message = $null; Policy = 'ge1-usable' }
    } -ModuleName ConsultingCopilot
    Mock Resolve-BacklogCliStatus {
      [pscustomobject]@{ Status = 'Missing'; Path = $null; Paths = @(); Message = 'missing' }
    } -ModuleName ConsultingCopilot

    $diag = Get-ConsultingCopilotPreflightDiagnostic -StackProfile ConsultingAI
    $node = @($diag.checks | Where-Object { $_.label -eq 'Node.js' }) | Select-Object -First 1
    $npm = @($diag.checks | Where-Object { $_.label -eq 'npm' }) | Select-Object -First 1
    $npx = @($diag.checks | Where-Object { $_.label -eq 'npx' }) | Select-Object -First 1
    $node.ok | Should -Be $true
    $npm.ok | Should -Be $true
    $npx.ok | Should -Be $true
  }

  It 'preflight falla node cuando cero usable' {
    Mock Get-GentleAiEnvironment {
      [pscustomobject]@{
        CliCount = 1
        CliPath = '/usr/bin/gentle-ai'
        CliPaths = @('/usr/bin/gentle-ai')
        GlobalInstalled = $true
        WorkspaceInstalled = $false
        WorkspaceEngramConfigured = $false
        WorkspaceMarkerPaths = @()
        WorkspaceMcpPath = $null
      }
    } -ModuleName ConsultingCopilot
    Mock Test-HubToolUsable {
      param($Id, $Policy, $ArchiPath, $VersionInvoker)
      $ok = $Id -ne 'node'
      [pscustomobject]@{ Id = $Id; Ok = $ok; Path = if ($ok) { "/usr/bin/$Id" } else { $null }; Paths = @(); Status = if ($ok) { 'Ok' } else { 'Missing' }; Message = $null; Policy = 'ge1-usable' }
    } -ModuleName ConsultingCopilot
    Mock Resolve-BacklogCliStatus {
      [pscustomobject]@{ Status = 'Missing'; Path = $null; Paths = @(); Message = 'missing' }
    } -ModuleName ConsultingCopilot

    $diag = Get-ConsultingCopilotPreflightDiagnostic -StackProfile Consulting
    $node = @($diag.checks | Where-Object { $_.label -eq 'Node.js' }) | Select-Object -First 1
    $node.ok | Should -Be $false
  }
}
