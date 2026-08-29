#Requires -Version 5.1

BeforeAll {
  $script:testsRoot = $PSScriptRoot | Split-Path -Parent
  $script:repoRoot = Split-Path -Parent $script:testsRoot
  Import-Module (Join-Path $script:repoRoot 'scripts\lib\ConsultingCopilot.psm1') -Force
  Import-Module (Join-Path $script:testsRoot 'helpers\TestSandbox.psm1') -Force

  function New-PropagationGitChild {
    param(
      [Parameter(Mandatory = $true)][string] $Path,
      [string] $StackProfileValue = 'consulting-ai',
      [bool] $IncludeStartiaMcp = $false
    )
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
    $engagement = [ordered]@{
      stackProfile = $StackProfileValue
      clientDisplayName = 'Acme'
      clientSlug = 'acme'
      initiativeDisplayName = 'Demo'
      initiativeId = 'U01'
      consultancyName = 'Ingenia'
      includeStartiaMcp = $IncludeStartiaMcp
      includeDrawioMcp = $true
      includeBacklogMcp = $false
      includeArchiMcp = $false
      includeClaudeCoworkLayer = $false
      gentleAiScope = 'global'
    }
    $json = $engagement | ConvertTo-Json -Depth 5
    [System.IO.File]::WriteAllText(
      (Join-Path $Path '.consulting-engagement.json'),
      $json + "`n",
      [System.Text.UTF8Encoding]::new($false)
    )
    & git -C $Path init -q 2>$null | Out-Null
    & git -C $Path config user.email 'propagate-test@example.com' | Out-Null
    & git -C $Path config user.name 'Propagate Test' | Out-Null
    & git -C $Path add -A 2>$null | Out-Null
    & git -C $Path commit -qm 'seed' --allow-empty 2>$null | Out-Null
    return $Path
  }
}

AfterAll {
  Remove-TestSandbox
}

Describe 'Get-HubPropagatablePaths allowlist' {
  It 'excluye backlog, transcripts, .cdd/changes, gaps doc, hybrid (mcp/README/stack-profile) y archimate diagrams' {
    $info = Get-HubPropagatablePaths -HubRoot $script:repoRoot -StackProfile ConsultingAI

    $info.Deny | Should -Contain 'backlog.md'
    $info.Deny | Should -Contain 'docs/architecture-gaps-and-questions.md'
    ($info.Deny | Where-Object { $_ -like 'transcripts/*' }).Count | Should -BeGreaterThan 0
    ($info.Deny | Where-Object { $_ -like '.cdd/changes/*' }).Count | Should -BeGreaterThan 0

    $info.Hybrid | Should -Contain '.cursor/mcp.json'
    $info.Hybrid | Should -Contain 'README.md'
    $info.Hybrid | Should -Contain '.atl/stack-profile.json'
    $info.Hybrid | Should -Contain '.gitignore'
    $info.Hybrid | Should -Contain '.cursorignore'

    ($info.ArchimateDiagrams | Where-Object { $_ -match '^docs/diagrams/archimate-.*\.(xml|drawio)$' }).Count |
      Should -BeGreaterThan 0

    $info.Plan | Should -Not -Contain 'backlog.md'
    $info.Plan | Should -Not -Contain 'docs/architecture-gaps-and-questions.md'
    $info.Plan | Should -Not -Contain '.cursor/mcp.json'
    $info.Plan | Should -Not -Contain 'README.md'
    $info.Plan | Should -Not -Contain '.atl/stack-profile.json'
    foreach ($d in $info.ArchimateDiagrams) {
      $info.Plan | Should -Not -Contain $d
    }

    # Archimate rules may remain template-owned
    ($info.Plan | Where-Object { $_ -like '.cursor/rules/archimate-*.mdc' }).Count | Should -BeGreaterThan 0
  }

  It 'Full usa golden consulting-ai idéntico a ConsultingAI' {
    $ai = Get-HubPropagatablePaths -HubRoot $script:repoRoot -StackProfile ConsultingAI
    $full = Get-HubPropagatablePaths -HubRoot $script:repoRoot -StackProfile Full
    $full.GoldenName | Should -Be 'consulting-ai'
    Compare-Object $ai.Plan $full.Plan | Should -BeNullOrEmpty
  }

  It 'perfil match Full↔ConsultingAI' {
    Test-HubPropagationProfileMatch -RegistryProfile 'full' -FilterProfile ConsultingAI | Should -Be $true
    Test-HubPropagationProfileMatch -RegistryProfile 'consulting-ai' -FilterProfile Full | Should -Be $true
    Test-HubPropagationProfileMatch -RegistryProfile 'consulting-only' -FilterProfile ConsultingAI | Should -Be $false
  }
}

Describe 'DryRun / Sync never-touch / McpMerge' {
  BeforeEach {
    $script:sandbox = Initialize-TestSandbox -PesterTestDrive $TestDrive
  }

  AfterEach {
    Remove-TestSandbox
  }

  It 'Sync no toca engagement/backlog/gaps y rechaza denylist' {
    $dest = Join-Path $script:sandbox.Root 'dest'
    $staging = Join-Path $script:sandbox.Root 'staging'
    Register-TestSandboxWrite -Path $dest
    Register-TestSandboxWrite -Path $staging
    New-Item -ItemType Directory -Path $dest, $staging -Force | Out-Null

    $engagementPaths = @(
      'transcripts/note.md'
      'docs/draft/x.md'
      'docs/architecture-gaps-and-questions.md'
      'backlog.md'
      '.cdd/changes/c1/proposal.md'
    )
    foreach ($rel in $engagementPaths) {
      $p = Join-Path $dest ($rel -replace '/', [IO.Path]::DirectorySeparatorChar)
      New-Item -ItemType Directory -Path (Split-Path -Parent $p) -Force | Out-Null
      Set-Content -LiteralPath $p -Value "original-$rel" -Encoding UTF8
    }

    $templateRel = '.cursor/rules/onboarding.mdc'
    $src = Join-Path $staging ($templateRel -replace '/', [IO.Path]::DirectorySeparatorChar)
    New-Item -ItemType Directory -Path (Split-Path -Parent $src) -Force | Out-Null
    Set-Content -LiteralPath $src -Value 'propagated-rule' -Encoding UTF8

    Sync-HubTemplatePaths -StagingPath $staging -DestinationPath $dest -Plan @($templateRel)

    (Get-Content -LiteralPath (Join-Path $dest ($templateRel -replace '/', [IO.Path]::DirectorySeparatorChar)) -Raw).Trim() |
      Should -Be 'propagated-rule'
    foreach ($rel in $engagementPaths) {
      $p = Join-Path $dest ($rel -replace '/', [IO.Path]::DirectorySeparatorChar)
      (Get-Content -LiteralPath $p -Raw).Trim() | Should -Be "original-$rel"
    }

    { Sync-HubTemplatePaths -StagingPath $staging -DestinationPath $dest -Plan @('backlog.md') } |
      Should -Throw '*denylist*'
  }

  It 'McpMerge añade solo keys ausentes desde staging y preserva top-level' {
    $dest = Join-Path $script:sandbox.Root 'mcp-dest'
    $staging = Join-Path $script:sandbox.Root 'mcp-staging'
    Register-TestSandboxWrite -Path $dest
    Register-TestSandboxWrite -Path $staging
    New-Item -ItemType Directory -Path (Join-Path $dest '.cursor'), (Join-Path $staging '.cursor') -Force | Out-Null

    $destMcp = @{
      '$schema' = 'https://example.invalid/mcp.schema.json'
      mcpServers = @{ keep = @{ command = 'keep-cmd' }; shared = @{ command = 'child-shared' } }
    } | ConvertTo-Json -Depth 5
    $stagingMcp = @{ mcpServers = @{ shared = @{ command = 'staging-shared' }; neu = @{ command = 'neu-cmd' } } } | ConvertTo-Json -Depth 5
    [System.IO.File]::WriteAllText((Join-Path $dest '.cursor' 'mcp.json'), $destMcp + "`n", [Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText((Join-Path $staging '.cursor' 'mcp.json'), $stagingMcp + "`n", [Text.UTF8Encoding]::new($false))

    Sync-HubTemplatePaths -StagingPath $staging -DestinationPath $dest -Plan @() -IncludeMcpMerge

    $merged = Get-Content -LiteralPath (Join-Path $dest '.cursor' 'mcp.json') -Raw | ConvertFrom-Json
    $merged.'$schema' | Should -Be 'https://example.invalid/mcp.schema.json'
    $names = @($merged.mcpServers.PSObject.Properties.Name)
    $names | Should -Contain 'keep'
    $names | Should -Contain 'shared'
    $names | Should -Contain 'neu'
    $merged.mcpServers.shared.command | Should -Be 'child-shared'
    $merged.mcpServers.neu.command | Should -Be 'neu-cmd'
  }

  It 'DryRun del orquestador no crea worktree ni Sync (exit 0)' {
    $wtRoot = Join-Path $script:repoRoot '.hub-propagate-worktrees'
    $before = @()
    if (Test-Path -LiteralPath $wtRoot) {
      $before = @(Get-ChildItem -LiteralPath $wtRoot -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName })
    }

    $scriptPath = Join-Path $script:repoRoot 'scripts/Propagate-HubTemplateToChildren.ps1'
    $combined = & pwsh -NoProfile -File $scriptPath -All -DryRun 2>&1 | Out-String
    $LASTEXITCODE | Should -Be 0
    $combined | Should -Match 'Propagate summary|Skip|Ningún hijo seleccionado'

    $after = @()
    if (Test-Path -LiteralPath $wtRoot) {
      $after = @(Get-ChildItem -LiteralPath $wtRoot -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName })
    }
    Compare-Object $before $after | Should -BeNullOrEmpty
  }
}

Describe 'Git gate / empty plan / -All exit codes' {
  BeforeEach {
    $script:sandbox = Initialize-TestSandbox -PesterTestDrive $TestDrive
  }

  AfterEach {
    Remove-TestSandbox
  }

  It 'skip sin .git usable; gitInitialized false irrelevante si .git usable' {
    $noGit = Join-Path $script:sandbox.Root 'no-git'
    New-Item -ItemType Directory -Path $noGit -Force | Out-Null
    Test-HubChildGitUsable -ChildRoot $noGit | Should -Be $false

    $withGit = Join-Path $script:sandbox.Root 'with-git'
    New-PropagationGitChild -Path $withGit | Out-Null
    # Registry flag gitInitialized is not consulted by the gate:
    Test-HubChildGitUsable -ChildRoot $withGit | Should -Be $true
  }

  It 'empty plan → no worktree (gate); Sync empty plan no escribe' {
    $fakeHub = Join-Path $script:sandbox.Root 'fake-hub'
    $manifestDir = Join-Path $fakeHub 'tests\expected\consulting-ai'
    New-Item -ItemType Directory -Path $manifestDir -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $manifestDir 'manifest.json') -Value '{"files":[]}' -Encoding UTF8
    $empty = Get-HubPropagatablePaths -HubRoot $fakeHub -StackProfile ConsultingAI
    $empty.Plan.Count | Should -Be 0

    $child = Join-Path $script:sandbox.Root 'empty-child'
    New-PropagationGitChild -Path $child | Out-Null
    $safe = ConvertTo-HubPropagationSafeBranch -BranchName 'hub/propagate-empty'
    $wtPath = Get-HubPropagationWorktreePath -HubRoot $script:sandbox.Root -FolderName 'empty-child' -SafeBranch $safe
    # Mimic orchestrator: empty plan0 → do not Ensure
    if (@($empty.Plan).Count -eq 0) {
      Test-Path -LiteralPath $wtPath | Should -Be $false
    } else {
      throw 'expected empty plan'
    }

    $dest = Join-Path $script:sandbox.Root 'empty-sync-dest'
    $staging = Join-Path $script:sandbox.Root 'empty-sync-staging'
    New-Item -ItemType Directory -Path $dest, $staging -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $dest 'marker.txt') -Value 'keep' -Encoding UTF8
    Sync-HubTemplatePaths -StagingPath $staging -DestinationPath $dest -Plan @()
    (Get-Content -LiteralPath (Join-Path $dest 'marker.txt') -Raw).Trim() | Should -Be 'keep'
  }

  It 'orquestador source: empty plan y DryRun no llaman Sync; staging antes de Ensure' {
    $src = Get-Content -LiteralPath (Join-Path $script:repoRoot 'scripts\Propagate-HubTemplateToChildren.ps1') -Raw
    $src | Should -Match 'if \(\$\w*DryRun\)'
    $src | Should -Match 'Plan vacío: no se crea worktree'
    $src | Should -Match 'Sync-HubTemplatePaths'
    $src | Should -Match 'New-HubPropagationStaging'
    $src | Should -Match 'Select-HubPropagationPlanPresentInStaging'
    # DryRun continue before Ensure/Sync; staging before Ensure on apply
    $dryIdx = $src.IndexOf('if ($DryRun)')
    $stagingIdx = $src.IndexOf('New-HubPropagationStaging')
    $ensureIdx = $src.IndexOf('Ensure-HubPropagationWorktree')
    $syncIdx = $src.IndexOf('Sync-HubTemplatePaths')
    $dryIdx | Should -BeGreaterThan 0
    $stagingIdx | Should -BeGreaterThan 0
    $ensureIdx | Should -BeGreaterThan $stagingIdx
    $syncIdx | Should -BeGreaterThan $ensureIdx
    $dryIdx | Should -BeLessThan $ensureIdx
  }

  It 'SafeBranch y FolderName rechazan traversal' {
    { ConvertTo-HubPropagationSafeBranch -BranchName '..' } | Should -Throw
    { ConvertTo-HubPropagationSafeBranch -BranchName 'hub/../x' } | Should -Throw
    { ConvertTo-HubPropagationRelativePath -Path '../secrets' } | Should -Throw
    { ConvertTo-HubPropagationRelativePath -Path './backlog.md' } | Should -Not -Throw
    (ConvertTo-HubPropagationRelativePath -Path './backlog.md') | Should -Be 'backlog.md'
    {
      Get-HubPropagationWorktreePath -HubRoot $script:sandbox.Root -FolderName 'a/../../b' -SafeBranch 'ok'
    } | Should -Throw
  }
}

Describe 'Worktree / staging / placeholders' {
  BeforeEach {
    $script:sandbox = Initialize-TestSandbox -PesterTestDrive $TestDrive
  }

  AfterEach {
    # Best-effort cleanup of worktrees created under sandbox hub root
    $wtRoot = Join-Path $script:sandbox.Root '.hub-propagate-worktrees'
    if (Test-Path -LiteralPath $wtRoot) {
      Get-ChildItem -LiteralPath $wtRoot -Directory -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
        & git -C $_.FullName rev-parse --is-inside-work-tree 1>$null 2>$null
        if ($LASTEXITCODE -eq 0) {
          $main = & git -C $_.FullName rev-parse --git-common-dir 2>$null
        }
      }
    }
    Remove-TestSandbox
  }

  It 'hub-side path; reuse same BranchName; orphan branch fails with cleanup' {
    $hub = $script:sandbox.Root
    $child = Join-Path $hub 'projects\wt-child'
    Register-TestSandboxWrite -Path $child
    New-PropagationGitChild -Path $child | Out-Null

    $branch = 'hub/propagate-unit'
    $wt1 = Ensure-HubPropagationWorktree -HubRoot $hub -ChildRoot $child -FolderName 'wt-child' -BranchName $branch
    $wt1.Reused | Should -Be $false
    $wt1.WorktreePath | Should -Match '\.hub-propagate-worktrees'
    $wt1.WorktreePath | Should -Match 'wt-child'
    Test-Path -LiteralPath $wt1.WorktreePath | Should -Be $true
    # Live child checkout must not be the worktree path
    $wt1.WorktreePath | Should -Not -Be $child

    $wt2 = Ensure-HubPropagationWorktree -HubRoot $hub -ChildRoot $child -FolderName 'wt-child' -BranchName $branch
    $wt2.Reused | Should -Be $true
    $wt2.WorktreePath | Should -Be $wt1.WorktreePath

    # Orphan branch: create branch without our worktree path
    $orphanBranch = 'hub/propagate-orphan'
    & git -C $child branch $orphanBranch 2>$null | Out-Null
    {
      Ensure-HubPropagationWorktree -HubRoot $hub -ChildRoot $child -FolderName 'wt-child' -BranchName $orphanBranch
    } | Should -Throw '*Cleanup*'

    # Cleanup worktree for sandbox
    & git -C $child worktree remove --force $wt1.WorktreePath 2>$null | Out-Null
    & git -C $child branch -D $branch 2>$null | Out-Null
    & git -C $child branch -D $orphanBranch 2>$null | Out-Null
  }

  It 'staging finally cleanup; placeholders unresolved fallan pre-Sync' {
    $stagingProbe = Join-Path $script:sandbox.Root 'placeholder-dir'
    New-Item -ItemType Directory -Path $stagingProbe -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $stagingProbe 'x.md') -Value 'Hello {{UNRESOLVED_TOKEN}}' -Encoding UTF8
    { Test-ConsultingPlaceholders -TargetPath $stagingProbe } | Should -Throw

    $child = Join-Path $script:sandbox.Root 'stage-child'
    Register-TestSandboxWrite -Path $child
    New-PropagationGitChild -Path $child -IncludeStartiaMcp:$false | Out-Null

    $stagingPath = $null
    try {
      $stagingPath = New-HubPropagationStaging -HubRoot $script:repoRoot -ChildRoot $child
      Register-TestSandboxWrite -Path $stagingPath
      Test-Path -LiteralPath $stagingPath | Should -Be $true
      # No unresolved tokens after successful staging
      { Test-ConsultingPlaceholders -TargetPath $stagingPath } | Should -Not -Throw
    } finally {
      Remove-ConsultingProjectStaging -StagingPath $stagingPath
    }
    if ($stagingPath) {
      Test-Path -LiteralPath $stagingPath | Should -Be $false
    }
  }
}

Describe 'Batch continue on per-child failure' {
  BeforeEach {
    $script:sandbox = Initialize-TestSandbox -PesterTestDrive $TestDrive
  }

  AfterEach {
    $wtRoot = Join-Path $script:sandbox.Root '.hub-propagate-worktrees'
    if (Test-Path -LiteralPath $wtRoot) {
      Get-ChildItem -LiteralPath $wtRoot -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        $folder = $_.Name
        Get-ChildItem -LiteralPath $_.FullName -Directory -ErrorAction SilentlyContinue | ForEach-Object {
          $childPath = Join-Path (Join-Path $script:sandbox.Root 'projects') $folder
          if (Test-Path -LiteralPath $childPath) {
            & git -C $childPath worktree remove --force $_.FullName 2>$null | Out-Null
          }
        }
      }
    }
    Remove-TestSandbox
  }

  It 'one child fails (orphan branch), siblings proceed; aggregate exit non-zero' {
    # Spec: "One child fails, others proceed" — mirrors Propagate-HubTemplateToChildren.ps1
    # foreach try/catch aggregation (real -All batch cannot inject HubRoot in unit scope).
    $hub = $script:sandbox.Root
    $branch = 'hub/propagate-batch'
    $labels = @('child-a', 'child-b', 'child-c')
    $children = @{}
    foreach ($label in $labels) {
      $path = Join-Path (Join-Path $hub 'projects') $label
      Register-TestSandboxWrite -Path $path
      New-PropagationGitChild -Path $path | Out-Null
      $children[$label] = $path
    }

    # Force second child to fail at Ensure (orphan branch without hub-side worktree).
    & git -C $children['child-b'] branch $branch 2>$null | Out-Null

    $failures = [System.Collections.Generic.List[string]]::new()
    $successes = [System.Collections.Generic.List[string]]::new()
    $processedOrder = [System.Collections.Generic.List[string]]::new()

    foreach ($label in $labels) {
      $processedOrder.Add($label) | Out-Null
      try {
        $wt = Ensure-HubPropagationWorktree `
          -HubRoot $hub `
          -ChildRoot $children[$label] `
          -FolderName $label `
          -BranchName $branch
        $successes.Add($label) | Out-Null
        Test-Path -LiteralPath $wt.WorktreePath | Should -Be $true
      } catch {
        $failures.Add("$label : $($_.Exception.Message)") | Out-Null
      }
    }

    $processedOrder | Should -Be $labels
    $successes | Should -Contain 'child-a'
    $successes | Should -Contain 'child-c'
    $successes.Count | Should -Be 2
    $failures.Count | Should -Be 1
    $failures[0] | Should -Match 'child-b'
    $failures[0] | Should -Match 'Cleanup'

    # Aggregate contract matching orchestrator tail:
    $exitCode = if ($failures.Count -gt 0) { 1 } else { 0 }
    $exitCode | Should -Not -Be 0

    $src = Get-Content -LiteralPath (Join-Path $script:repoRoot 'scripts\Propagate-HubTemplateToChildren.ps1') -Raw
    $src | Should -Match '\$failures\.Add'
    $src | Should -Match 'exit 1'
    ($src -match 'foreach \(\$item in \$selected\)') | Should -Be $true
  }
}

Describe 'Startia=false omits missing policy from effective plan' {
  BeforeEach {
    $script:sandbox = Initialize-TestSandbox -PesterTestDrive $TestDrive
  }

  AfterEach {
    Remove-TestSandbox
  }

  It 'policy ausente en staging se omite (no fail)' {
    $child = Join-Path $script:sandbox.Root 'startia-off'
    Register-TestSandboxWrite -Path $child
    New-PropagationGitChild -Path $child -IncludeStartiaMcp:$false | Out-Null

    $stagingPath = $null
    try {
      $stagingPath = New-HubPropagationStaging -HubRoot $script:repoRoot -ChildRoot $child
      Register-TestSandboxWrite -Path $stagingPath
      $policyRel = '.cursor/rules/startia-mcp-skills-policy.mdc'
      $policyOnDisk = Join-Path $stagingPath ($policyRel -replace '/', [IO.Path]::DirectorySeparatorChar)
      Test-Path -LiteralPath $policyOnDisk | Should -Be $false

      $plan0 = Get-HubPropagatablePaths -HubRoot $script:repoRoot -StackProfile ConsultingAI
      $plan0.Plan | Should -Contain $policyRel
      $effective = @(Select-HubPropagationPlanPresentInStaging -StagingPath $stagingPath -Plan @($plan0.Plan))
      $effective | Should -Not -Contain $policyRel
      $effective.Count | Should -BeGreaterThan 0
    } finally {
      Remove-ConsultingProjectStaging -StagingPath $stagingPath
    }
  }
}
