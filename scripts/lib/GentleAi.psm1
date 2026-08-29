#Requires -Version 5.1
Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot 'Platform.psm1') -Force

function Get-GentleAiUserHome {
  param([string] $UserHome)
  if (-not [string]::IsNullOrWhiteSpace($UserHome)) {
    return Resolve-HubRootPath $UserHome
  }
  if (-not [string]::IsNullOrWhiteSpace($env:TEST_USER_HOME)) {
    return Resolve-HubRootPath $env:TEST_USER_HOME
  }
  return [Environment]::GetFolderPath('UserProfile')
}

function Test-GentleAiMcpServerConfigured {
  param([string] $McpJsonPath, [string] $ServerName)
  if (-not (Test-Path -LiteralPath $McpJsonPath -PathType Leaf)) { return $false }
  try {
    $config = Get-Content -LiteralPath $McpJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if (-not $config.mcpServers) { return $false }
    $names = @($config.mcpServers.PSObject.Properties | ForEach-Object { $_.Name })
    return $names -contains $ServerName
  } catch { return $false }
}

function Get-GentleAiRawCommandPaths {
  param([string] $Name = 'gentle-ai')
  $paths = @()
  Get-Command $Name -All -ErrorAction SilentlyContinue | ForEach-Object {
    $candidate = if ($_.Path) { $_.Path } elseif ($_.Source) { $_.Source } else { $null }
    if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
      $paths += Resolve-HubRootPath $candidate
    }
  }
  return @($paths | Sort-Object -Unique)
}

function Resolve-GentleAiCliStatus {
  param([string[]] $RawPaths)

  if ($null -eq $RawPaths) { $RawPaths = @(Get-GentleAiRawCommandPaths) }
  $raw = @($RawPaths)
  $allowed = @($raw | Where-Object {
    Test-HubCommandAllowedOnPlatform -Name 'gentle-ai' -Path $_
  })
  $rejected = @($raw | Where-Object {
    -not (Test-HubCommandAllowedOnPlatform -Name 'gentle-ai' -Path $_)
  })

  if ($allowed.Count -eq 1) {
    return [pscustomobject]@{
      Status = 'Ok'
      Path = $allowed[0]
      Paths = $allowed
      RejectedPaths = $rejected
      Message = $null
    }
  }
  if ($allowed.Count -gt 1) {
    return [pscustomobject]@{
      Status = 'Duplicate'
      Path = $null
      Paths = $allowed
      RejectedPaths = $rejected
      Message = "Se detectaron varias instalaciones de gentle-ai. Conservá una sola en PATH:`n$($allowed -join "`n")"
    }
  }
  if ($rejected.Count -gt 0) {
    return [pscustomobject]@{
      Status = 'WindowsOriginRejected'
      Path = $null
      Paths = @()
      RejectedPaths = $rejected
      Message = "gentle-ai detectado sólo como binario Windows (inválido en Linux/WSL):`n$($rejected -join "`n")`nInstalá Gentle AI nativo en la distro (go install ...@latest) y quitá el .exe de PATH."
    }
  }
  return [pscustomobject]@{
    Status = 'Missing'
    Path = $null
    Paths = @()
    RejectedPaths = @()
    Message = 'gentle-ai no está en PATH.'
  }
}

function Get-GentleAiEngramStatus {
  param(
    [bool] $GlobalConfigured,
    [bool] $WorkspaceConfigured
  )
  if ($WorkspaceConfigured) {
    return [pscustomobject]@{
      Status = 'WorkspaceDuplicate'
      GlobalConfigured = $GlobalConfigured
      WorkspaceConfigured = $true
      Message = 'Engram aparece en el MCP local del workspace; debe administrarlo Gentle AI (global), no duplicarse.'
    }
  }
  if ($GlobalConfigured) {
    return [pscustomobject]@{
      Status = 'Configured'
      GlobalConfigured = $true
      WorkspaceConfigured = $false
      Message = $null
    }
  }
  return [pscustomobject]@{
    Status = 'Missing'
    GlobalConfigured = $false
    WorkspaceConfigured = $false
    Message = 'Engram MCP global no detectado. No se repara automáticamente; usá gentle-ai doctor/sync si corresponde.'
  }
}

function Get-GentleAiDualInstallDiagnosis {
  <#
    Detect-only: reports global+workspace gentle-ai coexistence.
    MUST NOT install, sync, upgrade, remove, or auto-fix either install.
  #>
  param(
    [string] $TargetPath,
    [string] $UserHome
  )
  $UserHome = Get-GentleAiUserHome -UserHome $UserHome
  $globalRule = Join-HubPath $UserHome '.cursor' 'rules' 'gentle-ai.mdc'
  $globalState = Join-HubPath $UserHome '.gentle-ai' 'state.json'
  $globalMarkers = @(
    $globalRule,
    (Join-HubPath $UserHome '.cursor' 'agents' 'sdd-init.md'),
    (Join-HubPath $UserHome '.cursor' 'skills' 'sdd-init' 'SKILL.md')
  )
  $stateMentionsCursor = $false
  if (Test-Path -LiteralPath $globalState -PathType Leaf) {
    try { $stateMentionsCursor = (Get-Content -LiteralPath $globalState -Raw -Encoding UTF8) -match '(?i)"cursor"' }
    catch { $stateMentionsCursor = $false }
  }
  $workspaceMarkers = @()
  if (-not [string]::IsNullOrWhiteSpace($TargetPath)) {
    $workspaceMarkers = @(
      (Join-HubPath $TargetPath '.cursor' 'rules' 'gentle-ai.mdc'),
      (Join-HubPath $TargetPath '.cursor' 'agents' 'sdd-init.md'),
      (Join-HubPath $TargetPath '.cursor' 'skills' 'sdd-init' 'SKILL.md')
    )
  }
  $existingWorkspaceMarkers = @($workspaceMarkers | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf })
  $existingGlobalMarkers = @($globalMarkers | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf })
  $globalInstalled = ($existingGlobalMarkers.Count -gt 0) -or $stateMentionsCursor
  $workspaceInstalled = $existingWorkspaceMarkers.Count -gt 0
  $dual = $globalInstalled -and $workspaceInstalled

  if ($dual) {
    return [pscustomobject]@{
      Dual = $true
      Status = 'Conflict'
      GlobalInstalled = $true
      WorkspaceInstalled = $true
      GlobalMarkerPaths = @($existingGlobalMarkers)
      WorkspaceMarkerPaths = @($existingWorkspaceMarkers)
      Message = "Se detecto asistencia instalada a la vez en el perfil global y en este workspace. No se modifica ninguna instalacion; reporta el conflicto y pedi al usuario que elija un unico alcance."
    }
  }

  return [pscustomobject]@{
    Dual = $false
    Status = 'Ok'
    GlobalInstalled = $globalInstalled
    WorkspaceInstalled = $workspaceInstalled
    GlobalMarkerPaths = @($existingGlobalMarkers)
    WorkspaceMarkerPaths = @($existingWorkspaceMarkers)
    Message = $null
  }
}

function Test-GentleAiDualInstall {
  param(
    [string] $TargetPath,
    [string] $UserHome
  )
  return [bool](Get-GentleAiDualInstallDiagnosis -TargetPath $TargetPath -UserHome $UserHome).Dual
}

function Get-GentleAiEnvironment {
  param([string] $TargetPath, [string] $UserHome)
  $UserHome = Get-GentleAiUserHome -UserHome $UserHome
  $cliStatus = Resolve-GentleAiCliStatus
  $cliPaths = @($cliStatus.Paths)
  $globalRule = Join-HubPath $UserHome '.cursor' 'rules' 'gentle-ai.mdc'
  $globalState = Join-HubPath $UserHome '.gentle-ai' 'state.json'
  $globalMcp = Join-HubPath $UserHome '.cursor' 'mcp.json'
  $dual = Get-GentleAiDualInstallDiagnosis -TargetPath $TargetPath -UserHome $UserHome
  $existingWorkspaceMarkers = @($dual.WorkspaceMarkerPaths)
  $existingGlobalMarkers = @($dual.GlobalMarkerPaths)
  $globalInstalled = [bool]$dual.GlobalInstalled
  $workspaceInstalled = [bool]$dual.WorkspaceInstalled
  $workspaceMcp = $null
  if (-not [string]::IsNullOrWhiteSpace($TargetPath)) {
    $workspaceMcp = Join-HubPath $TargetPath '.cursor' 'mcp.json'
  }
  $globalEngram = Test-GentleAiMcpServerConfigured -McpJsonPath $globalMcp -ServerName 'engram'
  $workspaceEngram = if ($workspaceMcp) {
    Test-GentleAiMcpServerConfigured -McpJsonPath $workspaceMcp -ServerName 'engram'
  } else { $false }
  $engramStatus = Get-GentleAiEngramStatus -GlobalConfigured $globalEngram -WorkspaceConfigured $workspaceEngram

  $issues = [System.Collections.Generic.List[string]]::new()
  $notes = [System.Collections.Generic.List[string]]::new()
  switch ($cliStatus.Status) {
    'Duplicate' { $issues.Add('multiple-gentle-ai-cli') }
    'WindowsOriginRejected' { $issues.Add('windows-origin-cli') }
    'Missing' { $notes.Add('cli-missing') }
  }
  if ($dual.Dual) { $issues.Add('global-workspace-duplicate') }
  if ($engramStatus.Status -eq 'WorkspaceDuplicate') { $issues.Add('workspace-engram-mcp') }
  elseif ($engramStatus.Status -eq 'Missing' -and $globalInstalled) {
    $notes.Add('engram-global-missing')
    $notes.Add($engramStatus.Message)
  }

  return [pscustomobject]@{
    CliStatus = $cliStatus.Status
    CliPaths = $cliPaths
    CliCount = $cliPaths.Count
    CliPath = if ($cliPaths.Count -eq 1) { $cliPaths[0] } else { $null }
    CliRejectedPaths = @($cliStatus.RejectedPaths)
    CliMessage = $cliStatus.Message
    GlobalInstalled = $globalInstalled
    GlobalMarkerPaths = $existingGlobalMarkers
    GlobalRulePath = $globalRule
    GlobalStatePath = $globalState
    GlobalStateExists = Test-Path -LiteralPath $globalState -PathType Leaf
    GlobalMcpPath = $globalMcp
    GlobalEngramConfigured = $globalEngram
    WorkspaceInstalled = $workspaceInstalled
    WorkspaceMarkerPaths = $existingWorkspaceMarkers
    WorkspaceMcpPath = $workspaceMcp
    WorkspaceEngramConfigured = $workspaceEngram
    EngramStatus = $engramStatus.Status
    EngramMessage = $engramStatus.Message
    DualInstall = $dual
    Issues = @($issues)
    Notes = @($notes)
    Healthy = ($issues.Count -eq 0)
  }
}

function Install-GentleAiCliStable {
  $goPaths = @(Get-HubCommandExecutablePaths -Name 'go')
  if ($goPaths.Count -ne 1) {
    throw 'Para instalar Gentle AI estable se requiere una única instalación de Go en PATH. Instalá Go 1.25.10+ y volvé a ejecutar.'
  }
  Write-Host 'Instalando Gentle AI estable con Go...'
  & $goPaths[0] install github.com/gentleman-programming/gentle-ai/v2/cmd/gentle-ai@latest
  if ($LASTEXITCODE -ne 0) { throw "La instalación de gentle-ai falló con código $LASTEXITCODE." }
  $goPath = (& $goPaths[0] env GOPATH | Select-Object -First 1).Trim()
  if ($goPath) {
    $binPath = Join-Path $goPath 'bin'
    if (($env:PATH -split [System.IO.Path]::PathSeparator) -notcontains $binPath) {
      $env:PATH = "$binPath$([System.IO.Path]::PathSeparator)$env:PATH"
    }
  }
  $cliStatus = Resolve-GentleAiCliStatus
  if ($cliStatus.Status -eq 'WindowsOriginRejected') { throw $cliStatus.Message }
  if ($cliStatus.Status -ne 'Ok') {
    throw "La instalación terminó pero gentle-ai no quedó usable ($($cliStatus.Status)). $($cliStatus.Message)"
  }
  return $cliStatus.Path
}

function Ensure-GentleAiCli {
  param(
    [ValidateSet('Auto', 'Existing')] [string] $Mode = 'Auto',
    [switch] $AllowConsultingFallback,
    [string] $Choice,
    [scriptblock] $PromptChoice
  )

  $cliStatus = Resolve-GentleAiCliStatus
  if ($cliStatus.Status -eq 'WindowsOriginRejected') { throw $cliStatus.Message }
  if ($cliStatus.Status -eq 'Duplicate') { throw $cliStatus.Message }
  if ($cliStatus.Status -eq 'Ok') {
    return [pscustomobject]@{
      Available = $true
      Path = $cliStatus.Path
      FallbackToConsulting = $false
      Status = 'Ok'
      Choice = $null
    }
  }
  if ($Mode -eq 'Existing') { throw 'gentle-ai no está en PATH y se solicitó usar una instalación existente.' }

  if ([string]::IsNullOrWhiteSpace($Choice)) {
    if ($PromptChoice) {
      $Choice = & $PromptChoice
    } else {
      throw 'Gentle AI es requerido y no se encontró el CLI. Pasá -Choice I|X|C o un -PromptChoice.'
    }
  }
  $Choice = $Choice.Trim().ToUpperInvariant()
  if ($Choice -notin @('I', 'X', 'C')) { throw "Opción de CLI inválida: $Choice" }
  if ($Choice -eq 'X') {
    return [pscustomobject]@{
      Available = $false
      Path = $null
      FallbackToConsulting = $false
      Status = 'Cancelled'
      Choice = 'X'
    }
  }
  if ($Choice -eq 'C') {
    if (-not $AllowConsultingFallback) {
      throw 'El fallback a Consulting sin Gentle AI no está permitido en este perfil.'
    }
    return [pscustomobject]@{
      Available = $false
      Path = $null
      FallbackToConsulting = $true
      Status = 'FallbackConsulting'
      Choice = 'C'
    }
  }
  $path = Install-GentleAiCliStable
  return [pscustomobject]@{
    Available = $true
    Path = $path
    FallbackToConsulting = $false
    Status = 'Installed'
    Choice = 'I'
  }
}

function Resolve-GentleAiScopeDecision {
  param(
    [psobject] $Environment,
    [ValidateSet('Auto', 'Global', 'Workspace', 'Existing')] [string] $RequestedScope = 'Auto',
    [string] $Choice,
    [scriptblock] $PromptChoice
  )

  $cliStatus = $null
  if ($Environment.PSObject.Properties.Name -contains 'CliStatus') { $cliStatus = $Environment.CliStatus }
  if ($cliStatus -eq 'WindowsOriginRejected') {
    $msg = if ($Environment.PSObject.Properties.Name -contains 'CliMessage') { $Environment.CliMessage } else { 'CLI Windows rechazado en Linux/WSL.' }
    throw $msg
  }
  if ($Environment.CliCount -gt 1 -or $cliStatus -eq 'Duplicate') {
    throw "Se detectaron varias instalaciones de gentle-ai:`n$($Environment.CliPaths -join "`n")"
  }
  if ($Environment.GlobalInstalled -and $Environment.WorkspaceInstalled) {
    throw 'Se detectó Gentle AI global y también en el workspace. No se modificará nada automáticamente. Ejecutá el diagnóstico y corregí la duplicación con comandos administrados por Gentle AI.'
  }
  if ($Environment.GlobalInstalled) {
    if ($RequestedScope -eq 'Workspace') { throw 'No se permite Gentle AI local porque ya existe configuración global.' }
    return [pscustomobject]@{ Action = 'Reuse'; Scope = 'Global'; Reason = 'global-existing'; Status = 'Ready' }
  }
  if ($Environment.WorkspaceInstalled) {
    if ($RequestedScope -eq 'Global') { throw 'El workspace ya contiene Gentle AI; no se instalará otra copia global automáticamente.' }
    return [pscustomobject]@{ Action = 'Reuse'; Scope = 'Workspace'; Reason = 'workspace-existing'; Status = 'Ready' }
  }
  if ($RequestedScope -eq 'Existing') { throw 'No se encontró una configuración Gentle AI existente para Cursor.' }
  if ($RequestedScope -eq 'Global') {
    return [pscustomobject]@{ Action = 'Install'; Scope = 'Global'; Reason = 'explicit-global'; Status = 'Ready' }
  }
  if ($RequestedScope -eq 'Workspace') {
    return [pscustomobject]@{ Action = 'Install'; Scope = 'Workspace'; Reason = 'explicit-workspace'; Status = 'Ready' }
  }

  if ([string]::IsNullOrWhiteSpace($Choice)) {
    if ($PromptChoice) {
      $Choice = & $PromptChoice
    } else {
      throw 'No existe configuración global de Gentle AI. Pasá -Choice G|P|X o un -PromptChoice.'
    }
  }
  $Choice = $Choice.Trim().ToUpperInvariant()
  if ($Choice -eq 'X') {
    return [pscustomobject]@{ Action = 'Cancel'; Scope = 'None'; Reason = 'interactive-cancel'; Status = 'Cancelled' }
  }
  if ($Choice -notin @('G', 'P')) { throw "Opción de alcance inválida: $Choice" }
  $scope = if ($Choice -eq 'G') { 'Global' } else { 'Workspace' }
  return [pscustomobject]@{ Action = 'Install'; Scope = $scope; Reason = 'interactive-choice'; Status = 'Ready' }
}

function Invoke-GentleAiInstall {
  param(
    [string] $CliPath,
    [ValidateSet('Global', 'Workspace')] [string] $Scope,
    [string] $TargetPath,
    [string] $UserHome
  )
  if (-not (Test-Path -LiteralPath $CliPath -PathType Leaf)) { throw "gentle-ai no encontrado: $CliPath" }
  if (Test-HubExecutableIsWindowsOrigin -Path $CliPath) {
    throw "No se ejecutará gentle-ai Windows desde Linux/WSL: $CliPath"
  }
  if ($Scope -eq 'Workspace' -and [string]::IsNullOrWhiteSpace($TargetPath)) { throw 'Workspace requiere TargetPath.' }
  $workingPath = if ($Scope -eq 'Workspace') { $TargetPath } else { Get-GentleAiUserHome -UserHome $UserHome }
  Write-Host "Configurando Gentle AI para Cursor con alcance $Scope..."
  Push-Location $workingPath
  try {
    # Solo install de componentes; nunca sync/upgrade/reparación automática.
    & $CliPath install --agent cursor --scope $Scope.ToLowerInvariant() --component engram,sdd,skills
    if ($LASTEXITCODE -ne 0) { throw "gentle-ai install falló con código $LASTEXITCODE." }
  } finally { Pop-Location }
}

function Invoke-SkillRegistryRefresh {
  param([string] $TargetPath, [string] $CliPath)
  if ([string]::IsNullOrWhiteSpace($CliPath)) {
    $cliStatus = Resolve-GentleAiCliStatus
    if ($cliStatus.Status -ne 'Ok') {
      Write-Warning 'No hay un único gentle-ai nativo en PATH; se omite skill-registry refresh.'
      return
    }
    $CliPath = $cliStatus.Path
  }
  Push-Location $TargetPath
  try {
    & $CliPath skill-registry refresh --force
    if ($LASTEXITCODE -ne 0) { Write-Warning "skill-registry refresh terminó con código $LASTEXITCODE." }
  } finally { Pop-Location }
}

function Resolve-GentleAiPreflight {
  param(
    [Parameter(Mandatory = $true)][string] $TargetPath,
    [ValidateSet('Auto', 'Global', 'Workspace', 'Existing')] [string] $RequestedScope = 'Auto',
    [ValidateSet('Auto', 'Existing')] [string] $CliMode = 'Auto',
    [switch] $AllowConsultingFallback,
    [string] $CliChoice,
    [string] $ScopeChoice,
    [scriptblock] $PromptCliChoice,
    [scriptblock] $PromptScopeChoice,
    [string] $UserHome
  )

  $environment = Get-GentleAiEnvironment -TargetPath $TargetPath -UserHome $UserHome
  if ($environment.CliStatus -eq 'WindowsOriginRejected') {
    return [pscustomobject]@{
      Status = 'Failed'
      Error = $environment.CliMessage
      Environment = $environment
      Cli = $null
      Decision = $null
      FallbackToConsulting = $false
    }
  }
  if ($environment.GlobalInstalled -and $environment.WorkspaceInstalled) {
    return [pscustomobject]@{
      Status = 'Failed'
      Error = 'Se detectó Gentle AI global y también en el workspace. Ejecutá el diagnóstico antes de generar.'
      Environment = $environment
      Cli = $null
      Decision = $null
      FallbackToConsulting = $false
    }
  }

  try {
    $cliParams = @{ Mode = $CliMode; AllowConsultingFallback = $AllowConsultingFallback }
    if ($CliChoice) { $cliParams['Choice'] = $CliChoice }
    if ($PromptCliChoice) { $cliParams['PromptChoice'] = $PromptCliChoice }
    $cli = Ensure-GentleAiCli @cliParams
  } catch {
    return [pscustomobject]@{
      Status = 'Failed'
      Error = $_.Exception.Message
      Environment = $environment
      Cli = $null
      Decision = $null
      FallbackToConsulting = $false
    }
  }

  if ($cli.Status -eq 'Cancelled') {
    return [pscustomobject]@{
      Status = 'Cancelled'
      Error = 'Operación cancelada por el usuario antes de generar archivos.'
      Environment = $environment
      Cli = $cli
      Decision = $null
      FallbackToConsulting = $false
    }
  }
  if ($cli.FallbackToConsulting) {
    return [pscustomobject]@{
      Status = 'FallbackConsulting'
      Error = $null
      Environment = $environment
      Cli = $cli
      Decision = $null
      FallbackToConsulting = $true
    }
  }

  $environment = Get-GentleAiEnvironment -TargetPath $TargetPath -UserHome $UserHome
  try {
    $decisionParams = @{ Environment = $environment; RequestedScope = $RequestedScope }
    if ($ScopeChoice) { $decisionParams['Choice'] = $ScopeChoice }
    if ($PromptScopeChoice) { $decisionParams['PromptChoice'] = $PromptScopeChoice }
    $decision = Resolve-GentleAiScopeDecision @decisionParams
  } catch {
    return [pscustomobject]@{
      Status = 'Failed'
      Error = $_.Exception.Message
      Environment = $environment
      Cli = $cli
      Decision = $null
      FallbackToConsulting = $false
    }
  }

  if ($decision.Status -eq 'Cancelled') {
    return [pscustomobject]@{
      Status = 'Cancelled'
      Error = 'Operación cancelada antes de instalar Gentle AI.'
      Environment = $environment
      Cli = $cli
      Decision = $decision
      FallbackToConsulting = $false
    }
  }

  return [pscustomobject]@{
    Status = 'Ready'
    Error = $null
    Environment = $environment
    Cli = $cli
    Decision = $decision
    FallbackToConsulting = $false
  }
}

Export-ModuleMember -Function @(
  'Get-GentleAiUserHome', 'Test-GentleAiMcpServerConfigured',
  'Get-GentleAiRawCommandPaths', 'Resolve-GentleAiCliStatus', 'Get-GentleAiEngramStatus',
  'Get-GentleAiDualInstallDiagnosis', 'Test-GentleAiDualInstall',
  'Get-GentleAiEnvironment', 'Install-GentleAiCliStable', 'Ensure-GentleAiCli',
  'Resolve-GentleAiScopeDecision', 'Invoke-GentleAiInstall', 'Invoke-SkillRegistryRefresh',
  'Resolve-GentleAiPreflight'
)
