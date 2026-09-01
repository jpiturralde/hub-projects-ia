#Requires -Version 5.1
# Ensure↔portable parity checklist (doctor-install):
# - gentle-ai: non-interactive install (Choice I / go install) when required
# - backlog: non-interactive npm install -g when required (after node/npm OK)
# - dual-GA / WSL-origin: hard-fail before any Ensure mutation
# - no Engram written to child .cursor/mcp.json
# - no gentle-ai sync/upgrade from Setup

BeforeAll {
  $script:repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
  $script:helpers = Join-Path $script:repoRoot 'tests/helpers'
  Import-Module (Join-Path $script:repoRoot 'scripts/lib/ConsultingCopilot.psm1') -Force
  . (Join-Path $script:helpers 'FakeCommand.ps1')
  Import-Module (Join-Path $script:helpers 'TestSandbox.psm1') -Force

  function script:New-SetupChildProject {
    param(
      [string] $Name,
      [string] $StackProfileValue = 'consulting-only',
      [hashtable] $Fields = @{},
      [string] $RootParent = $TestDrive
    )
    $dir = Join-Path $RootParent $Name
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $defaults = [ordered]@{
      clientSlug = 'acme'
      clientDisplayName = 'Acme'
      initiativeId = 'u1'
      initiativeDisplayName = 'Init'
      includeDrawioMcp = $false
      includeBacklogMcp = $false
      includeArchiMcp = $false
      gentleAiScope = 'none'
    }
    foreach ($k in $Fields.Keys) { $defaults[$k] = $Fields[$k] }
    Write-EngagementMetadata -TargetPath $dir -StackProfileValue $StackProfileValue -Fields $defaults
    Sync-ProjectEnvironmentScripts -TargetPath $dir
    return $dir
  }

  function script:Invoke-SetupScript {
    param(
      [Parameter(Mandatory = $true)][string] $TargetPath,
      [string] $FakeBinDir = ''
    )
    $setup = Join-Path $TargetPath 'scripts/Setup-ProjectEnvironment.ps1'
    $prevPath = $env:PATH
    try {
      if (-not [string]::IsNullOrWhiteSpace($FakeBinDir)) {
        $env:PATH = Get-IsolatedTestPath -FakeBinDir $FakeBinDir -OriginalPath $prevPath
      }
      $output = & pwsh -NoProfile -File $setup -TargetPath $TargetPath 2>&1 | Out-String
      return [pscustomobject]@{
        ExitCode = $LASTEXITCODE
        Output = $output
      }
    } finally {
      $env:PATH = $prevPath
    }
  }
}
Describe 'Sync-ProjectEnvironmentScripts + engramProject' {
  It 'force-emite Test + Setup + Publish' {
    $dir = Join-Path $TestDrive 'sync-scripts'
    New-Item -ItemType Directory -Path $dir | Out-Null
    Sync-ProjectEnvironmentScripts -TargetPath $dir
    Test-Path (Join-Path $dir 'scripts/Setup-ProjectEnvironment.ps1') | Should -Be $true
    Test-Path (Join-Path $dir 'scripts/Publish-ProjectMemory.ps1') | Should -Be $true
    Test-Path (Join-Path $dir 'scripts/Test-ProjectEnvironment.ps1') | Should -Be $true
  }

  It 'escribe engramProject set-if-absent en engagement y lo preserva en refresh' {
    $dir = Join-Path $TestDrive 'eng-key'
    New-Item -ItemType Directory -Path $dir | Out-Null
    $fields = [ordered]@{
      clientSlug = 'acme'
      clientDisplayName = 'Acme'
      initiativeId = 'u1'
      initiativeDisplayName = 'Init'
      includeDrawioMcp = $false
      includeBacklogMcp = $false
      includeArchiMcp = $false
      gentleAiScope = 'none'
    }
    Write-EngagementMetadata -TargetPath $dir -StackProfileValue 'consulting-only' -Fields $fields
    $meta1 = Get-Content (Join-Path $dir '.consulting-engagement.json') -Raw | ConvertFrom-Json
    $meta1.engramProject | Should -Not -BeNullOrEmpty
    $key = [string]$meta1.engramProject

    $fields2 = [ordered]@{}
    foreach ($p in $meta1.PSObject.Properties) {
      if ($p.Name -in @('schemaVersion', 'stackProfile', 'generatedAt', 'requires')) { continue }
      $fields2[$p.Name] = $p.Value
    }
    Write-EngagementMetadata -TargetPath $dir -StackProfileValue 'consulting-only' -Fields $fields2
    $meta2 = Get-Content (Join-Path $dir '.consulting-engagement.json') -Raw | ConvertFrom-Json
    $meta2.engramProject | Should -Be $key
  }

  It 'escribe engramProject en project-profile GentleAi' {
    $dir = Join-Path $TestDrive 'ga-key'
    New-Item -ItemType Directory -Path $dir | Out-Null
    Write-ProjectProfile -TargetPath $dir -ProjectName 'demo-app' -GentleAiScope 'global'
    $meta = Get-Content (Join-Path $dir '.project-profile.json') -Raw | ConvertFrom-Json
    $meta.engramProject | Should -Not -BeNullOrEmpty
  }

  It 'GETTING-STARTED lista Preparar entorno y Publicar memoria en los cuatro perfiles' {
    $cases = @(
      @{ Profile = 'GentleAi'; Stack = 'GentleAi'; Title = 'ga'; Scope = 'Global'; Meta = 'profile' }
      @{ Profile = 'Consulting'; Stack = 'Consulting'; Title = 'c'; Scope = 'None'; Meta = 'engagement'; StackValue = 'consulting-only' }
      @{ Profile = 'ConsultingAI'; Stack = 'ConsultingAI'; Title = 'cai'; Scope = 'Global'; Meta = 'engagement'; StackValue = 'consulting-ai' }
      @{ Profile = 'Full'; Stack = 'Full'; Title = 'full'; Scope = 'Workspace'; Meta = 'engagement'; StackValue = 'full' }
    )
    foreach ($c in $cases) {
      $dir = Join-Path $TestDrive ("gs-" + $c.Profile)
      New-Item -ItemType Directory -Path $dir -Force | Out-Null
      if ($c.Meta -eq 'profile') {
        Write-ProjectProfile -TargetPath $dir -ProjectName $c.Title -GentleAiScope $c.Scope
        $null = Write-ProjectGettingStarted -TargetPath $dir -StackProfile GentleAi -Title $c.Title -GentleAiScope $c.Scope
      } else {
        Write-EngagementMetadata -TargetPath $dir -StackProfileValue $c.StackValue -Fields ([ordered]@{
          clientSlug = 'c'; clientDisplayName = 'C'; initiativeId = 'i'; initiativeDisplayName = 'I'
          includeDrawioMcp = $false; includeBacklogMcp = $false; includeArchiMcp = $false
          gentleAiScope = $c.Scope.ToLowerInvariant(); docTitlePrefix = $c.Title
        })
        $null = Write-ProjectGettingStarted -TargetPath $dir -StackProfile $c.Stack -Title $c.Title -GentleAiScope $c.Scope
      }
      $gs = Get-Content (Join-Path $dir 'docs/GETTING-STARTED.md') -Raw
      $gs | Should -Match 'Preparar entorno'
      $gs | Should -Match 'Setup-ProjectEnvironment.ps1'
      $gs | Should -Match 'Publicar memoria'
      $gs | Should -Match 'Publish-ProjectMemory.ps1'
      $gs | Should -Match 'sensible'
    }
  }
}

Describe 'Doctor sigue detect-only' {
  It 'Test-ProjectEnvironment.ps1 no expone -Remediate' {
    $template = Join-Path (Join-Path (Join-Path $PSScriptRoot '../..') 'scripts/templates') 'Test-ProjectEnvironment.ps1'
    $raw = Get-Content -LiteralPath $template -Raw
    $raw | Should -Not -Match '-Remediate'
    $raw | Should -Not -Match '-Fix'
  }
}

Describe 'Propagate plan incluye Setup y Publish' {
  It 'ConsultingAI plan lista ambos scripts' {
    $info = Get-HubPropagatablePaths -HubRoot $script:repoRoot -StackProfile ConsultingAI
    $info.Allow | Should -Contain 'scripts/Setup-ProjectEnvironment.ps1'
    $info.Allow | Should -Contain 'scripts/Publish-ProjectMemory.ps1'
  }
}

Describe 'Setup-ProjectEnvironment portable behavior' {
  AfterEach {
    Remove-Item Env:TEST_USER_HOME -ErrorAction SilentlyContinue
    if (Get-Command Remove-TestSandbox -ErrorAction SilentlyContinue) {
      try { Remove-TestSandbox } catch { }
    }
  }

  It 'no contiene prompts interactivos ni jerga pull-engram en el template' {
    $raw = Get-Content (Join-Path $script:repoRoot 'scripts/templates/Setup-ProjectEnvironment.ps1') -Raw
    $raw | Should -Not -Match 'Read-Host'
    $raw | Should -Not -Match '(?i)pull-engram'
    $raw | Should -Not -Match 'Import-Module.*ConsultingCopilot'
    $raw | Should -Not -Match 'Read-ConsultingChoice'
  }

  It 'dual-GA hard-fail antes de mutar backlog' {
    $sandbox = Initialize-TestSandbox -FakeHomeFixture 'empty' -WithFakeCommands -PesterTestDrive $TestDrive
    $dir = New-SetupChildProject -Name 'dual-ga' -StackProfileValue 'consulting-only' -Fields @{
      includeBacklogMcp = $true
      gentleAiScope = 'none'
    } -RootParent $sandbox.Root

    $globalRule = Join-Path $sandbox.FakeHome '.cursor/rules/gentle-ai.mdc'
    New-Item -ItemType Directory -Path (Split-Path $globalRule -Parent) -Force | Out-Null
    Set-Content -LiteralPath $globalRule -Value '# global' -Encoding UTF8
    $wsRule = Join-Path $dir '.cursor/rules/gentle-ai.mdc'
    New-Item -ItemType Directory -Path (Split-Path $wsRule -Parent) -Force | Out-Null
    Set-Content -LiteralPath $wsRule -Value '# ws' -Encoding UTF8

    # backlog missing: remove fake backlog so Ensure would otherwise install
    Remove-Item -LiteralPath (Join-Path $sandbox.FakeBinDir 'backlog') -Force -ErrorAction SilentlyContinue
    Clear-FakeCommandLog -FakeBinDir $sandbox.FakeBinDir

    $result = Invoke-SetupScript -TargetPath $dir -FakeBinDir $sandbox.FakeBinDir
    $result.ExitCode | Should -Be 2
    $result.Output | Should -Match 'duplicada|duplicado|global y en el workspace'

    $log = Get-FakeCommandLog -FakeBinDir $sandbox.FakeBinDir
    @($log | Where-Object { $_.name -eq 'npm' }).Count | Should -Be 0
  }

  It 'node required missing sale 2 antes de Ensure backlog' {
    $sandbox = Initialize-TestSandbox -FakeHomeFixture 'empty' -PesterTestDrive $TestDrive
    $emptyBin = $sandbox.FakeBinDir
    New-FakeExecutable -Name 'gentle-ai' -FakeBinDir $emptyBin -Stdout @('fake gentle-ai 1.0') | Out-Null
    # no node/npm
    $dir = New-SetupChildProject -Name 'node-miss' -StackProfileValue 'consulting-only' -Fields @{
      includeDrawioMcp = $true
      includeBacklogMcp = $true
    } -RootParent $sandbox.Root

    $result = Invoke-SetupScript -TargetPath $dir -FakeBinDir $emptyBin
    $result.ExitCode | Should -Be 2
    $result.Output | Should -Match 'node'
  }

  It 'chunks pendientes sin CLI → exit 2' {
    $sandbox = Initialize-TestSandbox -FakeHomeFixture 'empty' -PesterTestDrive $TestDrive
    $dir = New-SetupChildProject -Name 'pending-no-cli' -RootParent $sandbox.Root
    $chunks = Join-Path $dir '.engram/chunks'
    New-Item -ItemType Directory -Path $chunks -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $chunks 'c1.json') -Value '{}' -Encoding UTF8

    $result = Invoke-SetupScript -TargetPath $dir -FakeBinDir $sandbox.FakeBinDir
    $result.ExitCode | Should -Be 2
    $result.Output | Should -Match 'memoria pendiente|herramientas de memoria'
  }

  It 'solo manifest.json sin CLI → exit 0' {
    $sandbox = Initialize-TestSandbox -FakeHomeFixture 'empty' -PesterTestDrive $TestDrive
    $dir = New-SetupChildProject -Name 'manifest-only' -RootParent $sandbox.Root
    New-Item -ItemType Directory -Path (Join-Path $dir '.engram') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $dir '.engram/manifest.json') -Value '{"chunks":[]}' -Encoding UTF8

    $result = Invoke-SetupScript -TargetPath $dir -FakeBinDir $sandbox.FakeBinDir
    $result.ExitCode | Should -Be 0
  }

  It 'pending>0 con fake engram invoca sync --import' {
    $sandbox = Initialize-TestSandbox -FakeHomeFixture 'empty' -PesterTestDrive $TestDrive
    New-FakeEngram -FakeBinDir $sandbox.FakeBinDir -PendingImport 2 | Out-Null
    New-FakeExecutable -Name 'gentle-ai' -FakeBinDir $sandbox.FakeBinDir -Stdout @('fake 1.0') | Out-Null
    $dir = New-SetupChildProject -Name 'pending-import' -RootParent $sandbox.Root
    Clear-FakeCommandLog -FakeBinDir $sandbox.FakeBinDir

    $result = Invoke-SetupScript -TargetPath $dir -FakeBinDir $sandbox.FakeBinDir
    $result.ExitCode | Should -Be 0
    $log = Get-FakeCommandLog -FakeBinDir $sandbox.FakeBinDir
    @($log | Where-Object { $_.name -eq 'engram' -and ($_.argv -join ' ') -match '--import' }).Count | Should -BeGreaterThan 0
  }

  It 'pending>0 e import fallido → exit 2' {
    $sandbox = Initialize-TestSandbox -FakeHomeFixture 'empty' -PesterTestDrive $TestDrive
    New-FakeEngram -FakeBinDir $sandbox.FakeBinDir -PendingImport 1 -ImportExitCode 1 | Out-Null
    New-FakeExecutable -Name 'gentle-ai' -FakeBinDir $sandbox.FakeBinDir -Stdout @('fake 1.0') | Out-Null
    $dir = New-SetupChildProject -Name 'import-fail' -RootParent $sandbox.Root

    $result = Invoke-SetupScript -TargetPath $dir -FakeBinDir $sandbox.FakeBinDir
    $result.ExitCode | Should -Be 2
    $result.Output | Should -Match 'No se pudo sincronizar|memoria del proyecto'
  }

  It 'WSL Windows-origin gentle-ai → exit 2 antes de Ensure' {
    if (-not ($IsLinux -or $env:WSL_DISTRO_NAME)) {
      Set-ItResult -Skipped -Because 'requiere Linux/WSL para Windows-origin'
      return
    }
    $sandbox = Initialize-TestSandbox -FakeHomeFixture 'empty' -PesterTestDrive $TestDrive
    $winBin = $null
    try {
      if (Test-Path -LiteralPath '/mnt/c' -PathType Container) {
        $winBin = Join-Path '/mnt/c' ('tmp-hub-setup-wsl-' + [guid]::NewGuid().ToString('n'))
      } else {
        Set-ItResult -Skipped -Because '/mnt/c no disponible para simular Windows-origin'
        return
      }
      New-Item -ItemType Directory -Path $winBin -Force | Out-Null
      $ga = Join-Path $winBin 'gentle-ai'
      Set-Content -LiteralPath $ga -Value "#!/bin/sh`necho fake-win`nexit 0" -Encoding ASCII
      & chmod +x $ga

      $dir = New-SetupChildProject -Name 'wsl-origin' -StackProfileValue 'consulting-only' -Fields @{
        includeBacklogMcp = $true
      } -RootParent $sandbox.Root
      Remove-Item -LiteralPath (Join-Path $sandbox.FakeBinDir 'backlog') -Force -ErrorAction SilentlyContinue
      # Prefer Windows-origin gentle-ai only (no native fake)
      Remove-Item -LiteralPath (Join-Path $sandbox.FakeBinDir 'gentle-ai') -Force -ErrorAction SilentlyContinue
      Clear-FakeCommandLog -FakeBinDir $sandbox.FakeBinDir

      $prev = $env:PATH
      try {
        $env:PATH = Get-IsolatedTestPath -FakeBinDir $sandbox.FakeBinDir -OriginalPath $prev
        $env:PATH = "$winBin$([IO.Path]::PathSeparator)$env:PATH"
        $setup = Join-Path $dir 'scripts/Setup-ProjectEnvironment.ps1'
        $output = & pwsh -NoProfile -File $setup -TargetPath $dir 2>&1 | Out-String
        $LASTEXITCODE | Should -Be 2
        $output | Should -Match 'Windows|WSL|nativa'
      } finally {
        $env:PATH = $prev
      }
      $log = Get-FakeCommandLog -FakeBinDir $sandbox.FakeBinDir
      @($log | Where-Object { $_.name -eq 'npm' }).Count | Should -Be 0
    } finally {
      if ($winBin -and (Test-Path -LiteralPath $winBin)) {
        Remove-Item -LiteralPath $winBin -Recurse -Force -ErrorAction SilentlyContinue
      }
    }
  }

  It 'cwd distinto de engramProject imprime aviso ES' {
    $sandbox = Initialize-TestSandbox -FakeHomeFixture 'empty' -PesterTestDrive $TestDrive
    New-FakeExecutable -Name 'gentle-ai' -FakeBinDir $sandbox.FakeBinDir -Stdout @('fake 1.0') | Out-Null
    $dir = New-SetupChildProject -Name 'cwd-warn-folder' -RootParent $sandbox.Root
    $metaPath = Join-Path $dir '.consulting-engagement.json'
    $meta = Get-Content $metaPath -Raw | ConvertFrom-Json
    $meta | Add-Member -NotePropertyName engramProject -Force -NotePropertyValue 'clave-canonica-equipo'
    $meta | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $metaPath -Encoding UTF8

    $result = Invoke-SetupScript -TargetPath $dir -FakeBinDir $sandbox.FakeBinDir
    $result.ExitCode | Should -Be 0
    $result.Output | Should -Match "clave-canonica-equipo"
    $result.Output | Should -Match 'Aviso:'
  }

  It 'no escribe Engram en mcp.json del hijo' {
    $sandbox = Initialize-TestSandbox -FakeHomeFixture 'empty' -WithFakeCommands -PesterTestDrive $TestDrive
    $dir = New-SetupChildProject -Name 'no-mcp-engram' -RootParent $sandbox.Root
    $mcp = Join-Path $dir '.cursor/mcp.json'
    New-Item -ItemType Directory -Path (Split-Path $mcp -Parent) -Force | Out-Null
    Set-Content -LiteralPath $mcp -Value '{"mcpServers":{}}' -Encoding UTF8
    $before = Get-Content $mcp -Raw

    $null = Invoke-SetupScript -TargetPath $dir -FakeBinDir $sandbox.FakeBinDir
    (Get-Content $mcp -Raw) | Should -Be $before
    (Get-Content $mcp -Raw) | Should -Not -Match '(?i)engram'
  }

  It 'Setup no invoca gentle-ai sync ni upgrade' {
    $raw = Get-Content (Join-Path $script:repoRoot 'scripts/templates/Setup-ProjectEnvironment.ps1') -Raw
    $raw | Should -Not -Match 'gentle-ai\s+sync'
    $raw | Should -Not -Match 'gentle-ai\s+upgrade'
  }
}

Describe 'Skeleton gitignore + onboarding (doctor-install)' {
  It 'gitignore skeleton e ignore Engram DB y permite manifest/chunks' {
    foreach ($rel in @('skeleton/.gitignore', 'skeleton-minimal/.gitignore')) {
      $gi = Get-Content (Join-Path $script:repoRoot $rel) -Raw
      $gi | Should -Match '\.engram/\*\.db'
      $gi | Should -Match '\.engram/\*\.db-shm'
      $gi | Should -Match '\.engram/\*\.db-wal'
      $gi | Should -Match '\.engram/engram\.db\*'
      $gi | Should -Not -Match '(?m)^\s*\.engram/\s*$'
      $gi | Should -Not -Match '(?m)^\s*\.engram/\*\s*$'
    }
  }

  It 'onboarding menciona Preparar entorno y Publicar memoria' {
    $skill = Get-Content (Join-Path $script:repoRoot 'skeleton/.cursor/skills/onboarding/SKILL.md') -Raw
    $skill | Should -Match 'Preparar entorno'
    $skill | Should -Match 'Setup-ProjectEnvironment\.ps1'
    $skill | Should -Match 'Publicar memoria'
    $skill | Should -Match 'Publish-ProjectMemory\.ps1'
  }
}

Describe 'Publish-ProjectMemory' {
  AfterEach {
    try { Remove-TestSandbox } catch { }
  }

  It 'publica chunk y menciona datos sensibles sin git commit' {
    $sandbox = Initialize-TestSandbox -FakeHomeFixture 'empty' -PesterTestDrive $TestDrive
    $dir = New-SetupChildProject -Name 'publish-ok' -RootParent $sandbox.Root
    New-FakeEngram -FakeBinDir $sandbox.FakeBinDir -ProjectRoot $dir | Out-Null

    $publish = Join-Path $dir 'scripts/Publish-ProjectMemory.ps1'
    $prev = $env:PATH
    try {
      $env:PATH = Get-IsolatedTestPath -FakeBinDir $sandbox.FakeBinDir -OriginalPath $prev
      $out = & pwsh -NoProfile -File $publish -TargetPath $dir 2>&1 | Out-String
      $LASTEXITCODE | Should -Be 0
    } finally { $env:PATH = $prev }

    $out | Should -Match 'sensible'
    $out | Should -Match 'git add'
    Test-Path (Join-Path $dir '.engram/chunks') | Should -Be $true
    @((Get-ChildItem (Join-Path $dir '.engram/chunks') -File)).Count | Should -BeGreaterThan 0

    $log = Get-FakeCommandLog -FakeBinDir $sandbox.FakeBinDir
    @($log | Where-Object { $_.name -eq 'git' }).Count | Should -Be 0
  }

  It 'sin CLI de memoria → exit 2' {
    $sandbox = Initialize-TestSandbox -FakeHomeFixture 'empty' -PesterTestDrive $TestDrive
    $dir = New-SetupChildProject -Name 'publish-no-cli' -RootParent $sandbox.Root
    $publish = Join-Path $dir 'scripts/Publish-ProjectMemory.ps1'
    $prev = $env:PATH
    try {
      $env:PATH = Get-IsolatedTestPath -FakeBinDir $sandbox.FakeBinDir -OriginalPath $prev
      $out = & pwsh -NoProfile -File $publish -TargetPath $dir 2>&1 | Out-String
      $LASTEXITCODE | Should -Be 2
    } finally { $env:PATH = $prev }
    $out | Should -Match 'memoria|Preparar entorno'
  }

  It 'export fail → exit 2' {
    $sandbox = Initialize-TestSandbox -FakeHomeFixture 'empty' -PesterTestDrive $TestDrive
    $dir = New-SetupChildProject -Name 'publish-fail' -RootParent $sandbox.Root
    New-FakeEngram -FakeBinDir $sandbox.FakeBinDir -ExitCode 1 -ProjectRoot $dir | Out-Null
    $publish = Join-Path $dir 'scripts/Publish-ProjectMemory.ps1'
    $prev = $env:PATH
    try {
      $env:PATH = Get-IsolatedTestPath -FakeBinDir $sandbox.FakeBinDir -OriginalPath $prev
      $out = & pwsh -NoProfile -File $publish -TargetPath $dir 2>&1 | Out-String
      $LASTEXITCODE | Should -Be 2
    } finally { $env:PATH = $prev }
    $out | Should -Match 'No se pudo publicar'
  }
}