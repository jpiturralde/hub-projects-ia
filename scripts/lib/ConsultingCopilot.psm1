#Requires -Version 5.1
Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot 'Platform.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'GentleAi.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'Backlog.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'HubRegistry.psm1') -Force

$script:TextExtensions = @(
  '.md', '.mdc', '.json', '.lua', '.yml', '.yaml', '.xml', '.drawio', '.gitignore', '.ps1', '.puml', '.mdx'
)

function ConvertTo-ConsultingSlug {
  param([string] $Text)
  if ([string]::IsNullOrWhiteSpace($Text)) { return '' }
  $value = $Text.Trim().ToLowerInvariant() -replace '[^a-z0-9]+', '-'
  $value = $value.Trim('-')
  if ($value.Length -gt 48) { $value = $value.Substring(0, 48).TrimEnd('-') }
  return $value
}

function Read-ConsultingPrompt {
  param([string] $Message, [string] $Default = '')
  if ($Default) {
    $response = Read-Host "$Message [$Default]"
    if ([string]::IsNullOrWhiteSpace($response)) { return $Default }
    return $response
  }
  return Read-Host $Message
}

function Read-ConsultingPromptYesNo {
  param([string] $Message, [bool] $Default = $false)
  $defaultLabel = if ($Default) { 'S' } else { 'N' }
  $response = Read-Host "$Message (S/N) [$defaultLabel]"
  if ([string]::IsNullOrWhiteSpace($response)) { return $Default }
  return $response.Trim().ToLowerInvariant() -in @('s', 'si', 'sí', 'y', 'yes', 'true', '1')
}

function Read-ConsultingChoice {
  param([string] $Message, [System.Collections.IDictionary] $Choices, [string] $DefaultKey)
  $labels = @($Choices.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ', '
  while ($true) {
    $response = Read-Host "$Message ($labels) [$DefaultKey]"
    if ([string]::IsNullOrWhiteSpace($response)) { $response = $DefaultKey }
    $key = $response.Trim().ToUpperInvariant()
    if ($Choices.Contains($key)) { return $key }
    Write-Warning "Opción inválida: $response"
  }
}

function Resolve-ConsultingFinalTargetPath {
  param([string] $TargetPath, [switch] $Force)
  if ([string]::IsNullOrWhiteSpace($TargetPath)) { throw 'TargetPath es obligatorio.' }
  $TargetPath = $TargetPath.Trim()
  if (-not [System.IO.Path]::IsPathRooted($TargetPath)) {
    throw "TargetPath debe ser una ruta absoluta. Recibido: $TargetPath"
  }
  $TargetPath = [System.IO.Path]::GetFullPath($TargetPath)
  if (Test-Path -LiteralPath $TargetPath) {
    $any = Get-ChildItem -LiteralPath $TargetPath -Force -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($any -and -not $Force) {
      throw "La carpeta destino no está vacía. Vaciala o usá -Force. Ruta: $TargetPath"
    }
  }
  return $TargetPath
}

function Test-ConsultingTargetPath {
  param([string] $TargetPath, [switch] $Force, [switch] $CreateIfMissing)
  $TargetPath = Resolve-ConsultingFinalTargetPath -TargetPath $TargetPath -Force:$Force
  if (-not (Test-Path -LiteralPath $TargetPath) -and $CreateIfMissing) {
    New-Item -ItemType Directory -Path $TargetPath -Force | Out-Null
  }
  return $TargetPath
}

function New-ConsultingProjectStagingPath {
  $stagingName = 'hub-project-staging-{0}' -f [Guid]::NewGuid().ToString('N')
  $stagingPath = Join-Path ([System.IO.Path]::GetTempPath()) $stagingName
  New-Item -ItemType Directory -Path $stagingPath -Force | Out-Null
  return $stagingPath
}

function Promote-ConsultingProjectStaging {
  param([string] $StagingPath, [string] $TargetPath, [switch] $Force)
  if ([string]::IsNullOrWhiteSpace($StagingPath) -or -not (Test-Path -LiteralPath $StagingPath)) {
    throw "Staging inválido o inexistente: $StagingPath"
  }
  $TargetPath = Resolve-ConsultingFinalTargetPath -TargetPath $TargetPath -Force:$Force
  $parent = Split-Path -Parent $TargetPath
  if (-not [string]::IsNullOrWhiteSpace($parent) -and -not (Test-Path -LiteralPath $parent)) {
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
  }
  if (Test-Path -LiteralPath $TargetPath) {
    if (-not $Force) { throw "El destino final ya existe: $TargetPath" }
    Remove-Item -LiteralPath $TargetPath -Recurse -Force
  }
  Move-Item -LiteralPath $StagingPath -Destination $TargetPath
  return $TargetPath
}

function Remove-ConsultingProjectStaging {
  param([string] $StagingPath)
  if ([string]::IsNullOrWhiteSpace($StagingPath)) { return }
  if (Test-Path -LiteralPath $StagingPath) {
    Remove-Item -LiteralPath $StagingPath -Recurse -Force -ErrorAction SilentlyContinue
  }
}

function Copy-ConsultingSkeleton {
  param([string] $SourcePath, [string] $TargetPath)
  if (-not (Test-Path -LiteralPath $SourcePath)) { throw "No se encuentra skeleton en: $SourcePath" }
  Write-Host "Copiando skeleton -> $TargetPath"
  Get-ChildItem -LiteralPath $SourcePath -Force | Copy-Item -Destination $TargetPath -Recurse -Force
}

function Copy-ProjectOverlay {
  param([string] $OverlayPath, [string] $TargetPath)
  if (-not (Test-Path -LiteralPath $OverlayPath)) { throw "No se encuentra overlay en: $OverlayPath" }
  Write-Host "Aplicando overlay -> $TargetPath"
  Get-ChildItem -LiteralPath $OverlayPath -Force | Copy-Item -Destination $TargetPath -Recurse -Force
}

function Rename-ConsultingArchimateTemplates {
  param([string] $TargetPath, [string] $ArchimateExportFilename, [string] $ArchimateViewsFilename)
  $renameMap = @(
    @{ From = '_TEMPLATE_archimate_export.xml'; To = $ArchimateExportFilename }
    @{ From = '_TEMPLATE_archimate_views.drawio'; To = $ArchimateViewsFilename }
  )
  foreach ($mapping in $renameMap) {
    $found = Get-ChildItem -LiteralPath $TargetPath -Recurse -Filter $mapping.From -File -ErrorAction SilentlyContinue
    foreach ($file in $found) {
      $newPath = Join-Path $file.DirectoryName $mapping.To
      if (-not (Test-Path -LiteralPath $newPath)) { Rename-Item -LiteralPath $file.FullName -NewName $mapping.To }
    }
  }
}

function Get-ConsultingTokenReplacements {
  param(
    [string] $ClientDisplayName, [string] $ClientSlug, [string] $InitiativeDisplayName,
    [string] $InitiativeId, [string] $ConsultancyName, [string] $PartnerTeamName,
    [string] $DocTitlePrefix, [string] $ArchimateExportFilename, [string] $ArchimateViewsFilename,
    [string] $CorporateDocxTemplateName
  )
  $partnerName = if ([string]::IsNullOrWhiteSpace($PartnerTeamName)) { '' } else { $PartnerTeamName.Trim() }
  $partnerSuffix = if ($partnerName) { "; partner citado cuando aplique: **$partnerName**" } else { '' }
  return [ordered]@{
    '{{CLIENT_DISPLAY_NAME}}' = $ClientDisplayName; '{{CLIENT_SLUG}}' = $ClientSlug
    '{{INITIATIVE_DISPLAY_NAME}}' = $InitiativeDisplayName; '{{INITIATIVE_ID}}' = $InitiativeId
    '{{CONSULTANCY_NAME}}' = $ConsultancyName; '{{PARTNER_TEAM_NAME}}' = $partnerName
    '{{PARTNER_TEAM_SUFFIX}}' = $partnerSuffix; '{{DOC_TITLE_PREFIX}}' = $DocTitlePrefix
    '{{ARCHIMATE_EXPORT_FILENAME}}' = $ArchimateExportFilename
    '{{ARCHIMATE_VIEWS_FILENAME}}' = $ArchimateViewsFilename
    '{{CORPORATE_DOCX_TEMPLATE_NAME}}' = $CorporateDocxTemplateName
  }
}

function Invoke-ConsultingTokenReplacement {
  param([string] $TargetPath, [System.Collections.IDictionary] $Replacements)
  Get-ChildItem -LiteralPath $TargetPath -Recurse -File -Force | ForEach-Object {
    $isText = ($_.Name -in @('.gitignore', '.cursorignore')) -or ($script:TextExtensions -contains $_.Extension.ToLowerInvariant())
    if (-not $isText) { return }
    $raw = [System.IO.File]::ReadAllText($_.FullName, [System.Text.UTF8Encoding]::new($false))
    foreach ($key in $Replacements.Keys) { $raw = $raw.Replace($key, [string]$Replacements[$key]) }
    [System.IO.File]::WriteAllText($_.FullName, $raw, [System.Text.UTF8Encoding]::new($false))
  }
}

function Remove-ConsultingClaudeLayer {
  param([string] $TargetPath)
  foreach ($path in @((Join-Path $TargetPath 'CLAUDE.md'), (Join-Path $TargetPath '.claude'))) {
    if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Recurse -Force }
  }
}

function Get-CommandExecutablePaths {
  param([string] $Name, [switch] $AllowWindowsExecutable)
  return Get-HubCommandExecutablePaths -Name $Name -AllowWindowsExecutable:$AllowWindowsExecutable
}

function Test-McpServerConfigured {
  param([string] $McpJsonPath, [string] $ServerName)
  return Test-GentleAiMcpServerConfigured -McpJsonPath $McpJsonPath -ServerName $ServerName
}

function Get-ConsultingUserHome {
  param([string] $UserHome)
  return Get-GentleAiUserHome -UserHome $UserHome
}

function Get-HubProjectsIaRoot {
  param([string] $ScriptRoot)
  if (-not [string]::IsNullOrWhiteSpace($env:HUB_PROJECTS_IA_ROOT)) {
    return Resolve-HubRootPath $env:HUB_PROJECTS_IA_ROOT
  }
  if ([string]::IsNullOrWhiteSpace($ScriptRoot)) {
    throw 'ScriptRoot es obligatorio cuando HUB_PROJECTS_IA_ROOT no está definido.'
  }
  return Resolve-HubProjectsRootFromScript -ScriptRoot $ScriptRoot
}

function Ensure-GentleAiCli {
  param(
    [ValidateSet('Auto', 'Existing')] [string] $Mode = 'Auto',
    [switch] $AllowConsultingFallback,
    [string] $Choice
  )
  $params = @{
    Mode = $Mode
    AllowConsultingFallback = $AllowConsultingFallback
  }
  if (-not [string]::IsNullOrWhiteSpace($Choice)) {
    $params['Choice'] = $Choice
  } else {
    $params['PromptChoice'] = {
      $choices = [ordered]@{ I = 'instalar estable (recomendado)'; X = 'cancelar' }
      if ($AllowConsultingFallback) { $choices['C'] = 'continuar con perfil Consulting sin Gentle AI' }
      Read-ConsultingChoice -Message 'Gentle AI es requerido y no se encontró el CLI' -Choices $choices -DefaultKey 'I'
    }.GetNewClosure()
  }
  $result = GentleAi\Ensure-GentleAiCli @params
  if ($result.Status -eq 'Cancelled') {
    throw 'Operación cancelada por el usuario antes de generar archivos.'
  }
  return $result
}

function Resolve-GentleAiScopeDecision {
  param(
    [psobject] $Environment,
    [ValidateSet('Auto', 'Global', 'Workspace', 'Existing')] [string] $RequestedScope = 'Auto',
    [string] $Choice
  )
  $params = @{
    Environment = $Environment
    RequestedScope = $RequestedScope
  }
  if (-not [string]::IsNullOrWhiteSpace($Choice)) {
    $params['Choice'] = $Choice
  } elseif ($RequestedScope -eq 'Auto' -and -not $Environment.GlobalInstalled -and -not $Environment.WorkspaceInstalled) {
    $params['PromptChoice'] = {
      Read-ConsultingChoice -Message 'No existe configuración global de Gentle AI. Elegí dónde instalarla' `
        -Choices ([ordered]@{ G = 'global (recomendado)'; P = 'solo en este proyecto'; X = 'cancelar' }) -DefaultKey 'G'
    }
  }
  $decision = GentleAi\Resolve-GentleAiScopeDecision @params
  if ($decision.Status -eq 'Cancelled') {
    throw 'Operación cancelada antes de instalar Gentle AI.'
  }
  return $decision
}

function Get-GentleAiEnvironment {
  param([string] $TargetPath, [string] $UserHome)
  GentleAi\Get-GentleAiEnvironment -TargetPath $TargetPath -UserHome $UserHome
}

function Get-GentleAiDualInstallDiagnosis {
  param(
    [string] $TargetPath,
    [string] $UserHome
  )
  GentleAi\Get-GentleAiDualInstallDiagnosis -TargetPath $TargetPath -UserHome $UserHome
}

function Test-GentleAiDualInstall {
  param(
    [string] $TargetPath,
    [string] $UserHome
  )
  GentleAi\Test-GentleAiDualInstall -TargetPath $TargetPath -UserHome $UserHome
}

function Install-GentleAiCliStable { GentleAi\Install-GentleAiCliStable }
function Invoke-GentleAiInstall {
  param(
    [string] $CliPath,
    [ValidateSet('Global', 'Workspace')] [string] $Scope,
    [string] $TargetPath,
    [string] $UserHome
  )
  GentleAi\Invoke-GentleAiInstall -CliPath $CliPath -Scope $Scope -TargetPath $TargetPath -UserHome $UserHome
}
function Invoke-SkillRegistryRefresh {
  param([string] $TargetPath, [string] $CliPath)
  GentleAi\Invoke-SkillRegistryRefresh -TargetPath $TargetPath -CliPath $CliPath
}
function Resolve-GentleAiPreflight {
  param(
    [Parameter(Mandatory = $true)][string] $TargetPath,
    [ValidateSet('Auto', 'Global', 'Workspace', 'Existing')] [string] $RequestedScope = 'Auto',
    [ValidateSet('Auto', 'Existing')] [string] $CliMode = 'Auto',
    [switch] $AllowConsultingFallback,
    [string] $CliChoice,
    [string] $ScopeChoice,
    [string] $UserHome
  )
  $params = @{
    TargetPath = $TargetPath
    RequestedScope = $RequestedScope
    CliMode = $CliMode
    AllowConsultingFallback = $AllowConsultingFallback
    UserHome = $UserHome
  }
  if (-not [string]::IsNullOrWhiteSpace($CliChoice)) {
    $params['CliChoice'] = $CliChoice
  } else {
    $params['PromptCliChoice'] = {
      $choices = [ordered]@{ I = 'instalar estable (recomendado)'; X = 'cancelar' }
      if ($AllowConsultingFallback) { $choices['C'] = 'continuar con perfil Consulting sin Gentle AI' }
      Read-ConsultingChoice -Message 'Gentle AI es requerido y no se encontró el CLI' -Choices $choices -DefaultKey 'I'
    }.GetNewClosure()
  }
  if (-not [string]::IsNullOrWhiteSpace($ScopeChoice)) {
    $params['ScopeChoice'] = $ScopeChoice
  } elseif ($RequestedScope -eq 'Auto') {
    $params['PromptScopeChoice'] = {
      Read-ConsultingChoice -Message 'No existe configuración global de Gentle AI. Elegí dónde instalarla' `
        -Choices ([ordered]@{ G = 'global (recomendado)'; P = 'solo en este proyecto'; X = 'cancelar' }) -DefaultKey 'G'
    }.GetNewClosure()
  }
  GentleAi\Resolve-GentleAiPreflight @params
}

function Ensure-BacklogCli {
  param(
    [ValidateSet('Auto', 'Existing')] [string] $Mode = 'Auto',
    [string] $Choice,
    [scriptblock] $NpmInvoker,
    [scriptblock] $VersionInvoker
  )
  $params = @{ Mode = $Mode }
  if (-not [string]::IsNullOrWhiteSpace($Choice)) {
    $params['Choice'] = $Choice
  } else {
    $params['PromptChoice'] = {
      Read-ConsultingChoice `
        -Message 'El perfil requiere Backlog.md (MCP) y no se encontró un CLI usable' `
        -Choices ([ordered]@{ I = 'instalar con npm (recomendado)'; X = 'cancelar' }) `
        -DefaultKey 'I'
    }
  }
  if ($NpmInvoker) { $params['NpmInvoker'] = $NpmInvoker }
  if ($VersionInvoker) { $params['VersionInvoker'] = $VersionInvoker }
  $result = Backlog\Ensure-BacklogCli @params
  if ($result.Status -eq 'Cancelled') {
    throw @"
Operación cancelada: no se generará la entrada MCP de Backlog sin un CLI usable.
Instalá manualmente y volvé a ejecutar:
  $(Get-BacklogManualInstallHint)
Validá con: backlog --version
"@
  }
  return $result
}

function Resolve-BacklogCliStatus {
  param([string[]] $RawPaths, [scriptblock] $VersionInvoker)
  $params = @{}
  if ($null -ne $RawPaths) { $params['RawPaths'] = $RawPaths }
  if ($VersionInvoker) { $params['VersionInvoker'] = $VersionInvoker }
  Backlog\Resolve-BacklogCliStatus @params
}

function Install-BacklogCli {
  param([scriptblock] $NpmInvoker, [scriptblock] $VersionInvoker)
  $params = @{}
  if ($NpmInvoker) { $params['NpmInvoker'] = $NpmInvoker }
  if ($VersionInvoker) { $params['VersionInvoker'] = $VersionInvoker }
  Backlog\Install-BacklogCli @params
}

function Get-BacklogManualInstallHint {
  Backlog\Get-BacklogManualInstallHint
}

function Get-ConsultingMcpServers {
  param([bool] $IncludeDrawioMcp, [bool] $IncludeBacklogMcp, [string] $BacklogMcpCwd, [bool] $IncludeArchiMcp, [string[]] $ArchiMcpArgs)
  $servers = [ordered]@{}
  if ($IncludeDrawioMcp) { $servers['drawio'] = @{ command = 'npx'; args = @('-y', '@drawio/mcp') } }
  if ($IncludeBacklogMcp) { $servers['backlog'] = @{ command = 'backlog'; args = @('mcp', 'start', '--cwd', $BacklogMcpCwd) } }
  if ($IncludeArchiMcp) { $servers['archi'] = @{ command = 'node'; args = @($ArchiMcpArgs) } }
  return $servers
}

function Write-ConsultingMcpJson {
  param([string] $TargetPath, [System.Collections.IDictionary] $McpServers)
  $cursorDir = Join-Path $TargetPath '.cursor'
  if (-not (Test-Path -LiteralPath $cursorDir)) { New-Item -ItemType Directory -Path $cursorDir -Force | Out-Null }
  $path = Join-Path $cursorDir 'mcp.json'
  $json = @{ mcpServers = $McpServers } | ConvertTo-Json -Depth 10
  [System.IO.File]::WriteAllText($path, $json + "`n", [System.Text.UTF8Encoding]::new($false))
}

function Get-HubProjectRequiresKnownIds {
  return @('node', 'npm', 'npx', 'pandoc', 'backlog', 'archi', 'gentle-ai')
}

function Resolve-HubRequiresStackProfile {
  param([string] $StackProfileValue)
  $normalized = ([string]$StackProfileValue).Trim()
  switch -Regex ($normalized) {
    '^(?i)gentle-ai-only$' { return 'GentleAi' }
    '^(?i)gentleai$' { return 'GentleAi' }
    '^(?i)consulting-only$' { return 'Consulting' }
    '^(?i)consulting$' { return 'Consulting' }
    '^(?i)consulting-ai$' { return 'ConsultingAI' }
    '^(?i)consultingai$' { return 'ConsultingAI' }
    '^(?i)full$' { return 'Full' }
    default { return $normalized }
  }
}

function Build-HubProjectRequires {
  param(
    [string] $StackProfileValue = 'Consulting',
    [bool] $IncludeDrawioMcp = $false,
    [bool] $IncludeBacklogMcp = $false,
    [bool] $IncludeArchiMcp = $false,
    [string] $GentleAiScope = 'none'
  )

  $profile = Resolve-HubRequiresStackProfile -StackProfileValue $StackProfileValue
  $isConsulting = $profile -in @('Consulting', 'ConsultingAI', 'Full')
  $scope = if ([string]::IsNullOrWhiteSpace($GentleAiScope)) { 'none' } else { $GentleAiScope.Trim().ToLowerInvariant() }

  $levels = [ordered]@{}
  if ($IncludeDrawioMcp) {
    $levels['node'] = 'required'
    $levels['npm'] = 'required'
    $levels['npx'] = 'required'
  }
  if ($IncludeArchiMcp) {
    $levels['archi'] = 'required'
    $levels['node'] = 'required'
    $levels['npm'] = 'required'
  }
  if ($isConsulting) {
    $levels['pandoc'] = 'optional'
    if ($IncludeBacklogMcp) { $levels['backlog'] = 'required' }
    else { $levels['backlog'] = 'optional' }
  }
  if ($scope -in @('global', 'workspace')) {
    $levels['gentle-ai'] = 'required'
  }

  # MUST emit only non-absent; Engram is never a tool id.
  $tools = [System.Collections.Generic.List[object]]::new()
  foreach ($id in (Get-HubProjectRequiresKnownIds)) {
    if ($levels.Contains($id)) {
      $tools.Add([ordered]@{ id = $id; level = [string]$levels[$id] })
    }
  }
  return [ordered]@{ version = 1; tools = @($tools.ToArray()) }
}

function ConvertTo-HubNormalizedRequires {
  param($Requires)
  $map = [ordered]@{}
  foreach ($id in (Get-HubProjectRequiresKnownIds)) { $map[$id] = 'absent' }
  if ($null -ne $Requires -and ($Requires.PSObject.Properties.Name -contains 'tools') -and $null -ne $Requires.tools) {
    foreach ($tool in @($Requires.tools)) {
      $id = [string]$tool.id
      if ($map.Contains($id)) {
        $level = ([string]$tool.level).Trim().ToLowerInvariant()
        if ($level -in @('required', 'optional', 'absent')) { $map[$id] = $level }
      }
    }
  }
  $tools = [System.Collections.Generic.List[object]]::new()
  foreach ($id in (Get-HubProjectRequiresKnownIds)) {
    $tools.Add([pscustomobject]@{ id = $id; level = [string]$map[$id] })
  }
  $version = 1
  if ($null -ne $Requires -and ($Requires.PSObject.Properties.Name -contains 'version') -and $null -ne $Requires.version) {
    $version = [int]$Requires.version
  }
  return [pscustomobject]@{ version = $version; tools = @($tools.ToArray()) }
}

function Get-HubProjectRequirements {
  param(
    [Parameter(Mandatory = $true)][string] $TargetPath
  )
  $TargetPath = [System.IO.Path]::GetFullPath($TargetPath)
  $engagementPath = Join-Path $TargetPath '.consulting-engagement.json'
  $profilePath = Join-Path $TargetPath '.project-profile.json'

  $meta = $null
  $metaKind = $null
  if (Test-Path -LiteralPath $engagementPath) {
    $meta = Get-Content -LiteralPath $engagementPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $metaKind = 'engagement'
  } elseif (Test-Path -LiteralPath $profilePath) {
    $meta = Get-Content -LiteralPath $profilePath -Raw -Encoding UTF8 | ConvertFrom-Json
    $metaKind = 'profile'
  } else {
    throw "No se encontró metadata de proyecto en: $TargetPath"
  }

  $schemaVersion = 0
  if ($meta.PSObject.Properties.Name -contains 'schemaVersion' -and $null -ne $meta.schemaVersion) {
    $schemaVersion = [int]$meta.schemaVersion
  }

  if ($schemaVersion -ge 4 -and ($meta.PSObject.Properties.Name -contains 'requires') -and $null -ne $meta.requires) {
    return ConvertTo-HubNormalizedRequires -Requires $meta.requires
  }

  $stackProfileValue = if ($metaKind -eq 'profile') { 'gentle-ai-only' } else { [string]$meta.stackProfile }
  $includeDrawio = $false
  $includeBacklog = $false
  $includeArchi = $false
  $gentleScope = 'none'
  if ($meta.PSObject.Properties.Name -contains 'includeDrawioMcp') { $includeDrawio = [bool]$meta.includeDrawioMcp }
  if ($meta.PSObject.Properties.Name -contains 'includeBacklogMcp') { $includeBacklog = [bool]$meta.includeBacklogMcp }
  if ($meta.PSObject.Properties.Name -contains 'includeArchiMcp') { $includeArchi = [bool]$meta.includeArchiMcp }
  if ($meta.PSObject.Properties.Name -contains 'gentleAiScope' -and $meta.gentleAiScope) {
    $gentleScope = [string]$meta.gentleAiScope
  } elseif ($metaKind -eq 'profile') {
    $gentleScope = 'global'
  }

  $built = Build-HubProjectRequires `
    -StackProfileValue $stackProfileValue `
    -IncludeDrawioMcp $includeDrawio `
    -IncludeBacklogMcp $includeBacklog `
    -IncludeArchiMcp $includeArchi `
    -GentleAiScope $gentleScope
  return ConvertTo-HubNormalizedRequires -Requires ([pscustomobject]$built)
}

function Test-HubCommandPathVersionOk {
  param(
    [Parameter(Mandatory = $true)][string] $Path,
    [scriptblock] $VersionInvoker
  )
  if ($VersionInvoker) {
    try {
      $result = & $VersionInvoker $Path
      if ($result -is [bool]) { return [bool]$result }
      if ($null -eq $result) { return ($LASTEXITCODE -eq 0) }
      return [bool]$result
    } catch {
      return $false
    }
  }
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }
  try {
    $null = & $Path --version 2>&1
    return ($LASTEXITCODE -eq 0)
  } catch {
    return $false
  }
}

function Get-HubUsableCommandPaths {
  param(
    [Parameter(Mandatory = $true)][string] $Name,
    [scriptblock] $VersionInvoker,
    [switch] $AllowWindowsExecutable
  )
  $paths = @(Get-CommandExecutablePaths -Name $Name -AllowWindowsExecutable:$AllowWindowsExecutable)
  return @($paths | Where-Object { Test-HubCommandPathVersionOk -Path $_ -VersionInvoker $VersionInvoker })
}

function Test-HubToolUsable {
  param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('node', 'npm', 'npx', 'pandoc', 'backlog', 'archi', 'gentle-ai')]
    [string] $Id,
    [string] $Policy,
    [string] $ArchiPath,
    [scriptblock] $VersionInvoker
  )

  if ([string]::IsNullOrWhiteSpace($Policy)) {
    $Policy = switch ($Id) {
      'gentle-ai' { 'eq1-native' }
      'backlog' { 'backlog-status' }
      'archi' { 'archi-path' }
      default { 'ge1-usable' }
    }
  }

  switch ($Id) {
    { $_ -in @('node', 'npm', 'npx', 'pandoc') } {
      $usable = @(Get-HubUsableCommandPaths -Name $Id -VersionInvoker $VersionInvoker)
      return [pscustomobject]@{
        Id = $Id
        Ok = ($usable.Count -ge 1)
        Policy = 'ge1-usable'
        Path = if ($usable.Count -ge 1) { $usable[0] } else { $null }
        Paths = $usable
        Status = if ($usable.Count -ge 1) { 'Ok' } else { 'Missing' }
        Message = if ($usable.Count -ge 1) { $null } else { "$Id no usable en PATH (≥1 requerido)." }
      }
    }
    'gentle-ai' {
      # eq1-native + WSL Windows-origin reject (Resolve-GentleAiCliStatus)
      $status = Resolve-GentleAiCliStatus
      return [pscustomobject]@{
        Id = $Id
        Ok = ($status.Status -eq 'Ok')
        Policy = 'eq1-native'
        Path = $status.Path
        Paths = @($status.Paths)
        Status = $status.Status
        Message = $status.Message
      }
    }
    'backlog' {
      $status = Resolve-BacklogCliStatus -VersionInvoker $VersionInvoker
      return [pscustomobject]@{
        Id = $Id
        Ok = ($status.Status -eq 'Ok')
        Policy = 'backlog-status'
        Path = $status.Path
        Paths = @($status.Paths)
        Status = $status.Status
        Message = $status.Message
      }
    }
    'archi' {
      if ([string]::IsNullOrWhiteSpace($ArchiPath)) {
        return [pscustomobject]@{
          Id = $Id
          Ok = $false
          Policy = 'archi-path'
          Path = $null
          Paths = @()
          Status = 'Missing'
          Message = 'Archi MCP path no configurado.'
        }
      }
      try {
        $resolved = Test-HubArchiMcpPath -Path $ArchiPath
        return [pscustomobject]@{
          Id = $Id
          Ok = $true
          Policy = 'archi-path'
          Path = $resolved
          Paths = @($resolved)
          Status = 'Ok'
          Message = $null
        }
      } catch {
        return [pscustomobject]@{
          Id = $Id
          Ok = $false
          Policy = 'archi-path'
          Path = $null
          Paths = @()
          Status = 'Invalid'
          Message = $_.Exception.Message
        }
      }
    }
  }
}

function Get-HubProjectEnvironmentDoctorTemplatePath {
  # Module lives in scripts/lib → template is scripts/templates/...
  $scriptsDir = Split-Path -Parent $PSScriptRoot
  return (Join-Path $scriptsDir 'templates' 'Test-ProjectEnvironment.ps1')
}

function Sync-ProjectEnvironmentDoctorScript {
  param([Parameter(Mandatory = $true)][string] $TargetPath)
  $TargetPath = [System.IO.Path]::GetFullPath($TargetPath)
  $template = Get-HubProjectEnvironmentDoctorTemplatePath
  if (-not (Test-Path -LiteralPath $template -PathType Leaf)) {
    throw "No se encuentra la plantilla del doctor de entorno: $template"
  }
  $scriptsDir = Join-Path $TargetPath 'scripts'
  if (-not (Test-Path -LiteralPath $scriptsDir)) {
    New-Item -ItemType Directory -Path $scriptsDir -Force | Out-Null
  }
  $dest = Join-Path $scriptsDir 'Test-ProjectEnvironment.ps1'
  Copy-Item -LiteralPath $template -Destination $dest -Force
}

function Test-HubLocalMcpJsonPathsHealthy {
  param([Parameter(Mandatory = $true)]$McpJson)
  if ($null -eq $McpJson -or -not ($McpJson.PSObject.Properties.Name -contains 'mcpServers') -or $null -eq $McpJson.mcpServers) {
    return $true
  }
  foreach ($prop in @($McpJson.mcpServers.PSObject.Properties)) {
    $server = $prop.Value
    if ($null -eq $server) { continue }
    $name = [string]$prop.Name
    # Parity with portable Get-PortableLocalMcpCheck / Test-PortableArchiPath
    if ($name -eq 'archi' -and ($server.PSObject.Properties.Name -contains 'args') -and $null -ne $server.args -and @($server.args).Count -gt 0) {
      try {
        Test-HubArchiMcpPath -Path ([string]$server.args[0]) | Out-Null
      } catch {
        return $false
      }
      continue
    }
    if ($server.PSObject.Properties.Name -contains 'args' -and $null -ne $server.args) {
      foreach ($arg in @($server.args)) {
        $s = [string]$arg
        if ([string]::IsNullOrWhiteSpace($s)) { continue }
        # Absolute path-like args must exist when they look like files/dirs
        if ($s -match '^(?:[A-Za-z]:[\\/]|/|\\\\)') {
          if ($s -match '(?i)(?:index\.js|\.mjs|\.cjs)$' -or $s -match '(?i)[/\\]') {
            if (-not (Test-Path -LiteralPath $s)) { return $false }
          }
        }
      }
    }
  }
  return $true
}

function Get-HubProjectLocalMcpDoctorCheck {
  param(
    [Parameter(Mandatory = $true)][string] $TargetPath,
    [bool] $LocalMcpToolsRequired = $false
  )
  $mcpPath = Join-HubPath $TargetPath '.cursor' 'mcp.json'
  $level = if ($LocalMcpToolsRequired) { 'required' } else { 'optional' }
  $base = [ordered]@{
    id = 'local-mcp'
    level = $level
    pass = $true
    state = 'n/a'
    message = ''
  }

  if (-not (Test-Path -LiteralPath $mcpPath -PathType Leaf)) {
    $base.state = 'not-materialized'
    if ($LocalMcpToolsRequired) {
      $base.pass = $false
      $base.message = 'Aún no hay archivo MCP local y este proyecto necesita servidores locales — copiá el ejemplo si aplica.'
    } else {
      $base.pass = $true
      $base.message = 'Aún no hay archivo MCP local — es normal tras un clone si no hace falta materializarlo.'
    }
    return [pscustomobject]$base
  }

  try {
    $raw = Get-Content -LiteralPath $mcpPath -Raw -Encoding UTF8
    $json = $raw | ConvertFrom-Json
  } catch {
    $base.state = 'broken'
    $base.pass = $false
    $base.level = 'required'
    $base.message = 'El archivo MCP local tiene problemas (JSON inválido).'
    return [pscustomobject]$base
  }

  $servers = $null
  if ($json.PSObject.Properties.Name -contains 'mcpServers') { $servers = $json.mcpServers }
  if ($null -ne $servers -and @($servers.PSObject.Properties.Name | Where-Object { $_ -eq 'engram' }).Count -gt 0) {
    $base.state = 'broken'
    $base.pass = $false
    $base.level = 'required'
    $base.message = 'El archivo MCP local tiene una entrada inesperada de memoria persistente — quitála; se gestiona fuera de este repo.'
    return [pscustomobject]$base
  }

  if (-not (Test-HubLocalMcpJsonPathsHealthy -McpJson $json)) {
    $base.state = 'broken'
    $base.pass = $false
    $base.level = 'required'
    $base.message = 'El archivo MCP local tiene problemas (rutas inválidas).'
    return [pscustomobject]$base
  }

  $base.state = 'configured'
  $base.pass = $true
  $base.message = 'El archivo MCP local parece listo.'
  return [pscustomobject]$base
}

function Get-HubProjectEnvironmentDoctorMeta {
  param([Parameter(Mandatory = $true)][string] $TargetPath)
  $engagementPath = Join-Path $TargetPath '.consulting-engagement.json'
  $profilePath = Join-Path $TargetPath '.project-profile.json'
  $meta = $null
  if (Test-Path -LiteralPath $engagementPath) {
    $meta = Get-Content -LiteralPath $engagementPath -Raw -Encoding UTF8 | ConvertFrom-Json
  } elseif (Test-Path -LiteralPath $profilePath) {
    $meta = Get-Content -LiteralPath $profilePath -Raw -Encoding UTF8 | ConvertFrom-Json
  }
  $includeDrawio = $false
  $includeBacklog = $false
  $includeArchi = $false
  $archiPath = $null
  if ($null -ne $meta) {
    if ($meta.PSObject.Properties.Name -contains 'includeDrawioMcp') { $includeDrawio = [bool]$meta.includeDrawioMcp }
    if ($meta.PSObject.Properties.Name -contains 'includeBacklogMcp') { $includeBacklog = [bool]$meta.includeBacklogMcp }
    if ($meta.PSObject.Properties.Name -contains 'includeArchiMcp') { $includeArchi = [bool]$meta.includeArchiMcp }
  }
  $mcpPath = Join-Path $TargetPath '.cursor' 'mcp.json'
  if ($includeArchi -and (Test-Path -LiteralPath $mcpPath -PathType Leaf)) {
    try {
      $mcp = Get-Content -LiteralPath $mcpPath -Raw -Encoding UTF8 | ConvertFrom-Json
      if ($mcp.mcpServers -and ($mcp.mcpServers.PSObject.Properties.Name -contains 'archi')) {
        $args = @($mcp.mcpServers.archi.args)
        if ($args.Count -gt 0) { $archiPath = [string]$args[0] }
      }
    } catch { }
  }
  return [pscustomobject]@{
    IncludeDrawioMcp = $includeDrawio
    IncludeBacklogMcp = $includeBacklog
    IncludeArchiMcp = $includeArchi
    ArchiPath = $archiPath
    LocalMcpToolsRequired = ($includeDrawio -or $includeBacklog -or $includeArchi)
  }
}

function Get-HubToolDoctorEsMessage {
  param(
    [string] $Id,
    [bool] $Pass,
    [string] $Status,
    [string] $Detail
  )
  if ($Pass) {
    switch ($Id) {
      'node' { return 'Node usable en PATH' }
      'npm' { return 'npm usable en PATH' }
      'npx' { return 'npx usable en PATH' }
      'pandoc' { return 'Pandoc usable en PATH' }
      'backlog' { return 'CLI de backlog usable' }
      'archi' { return 'Ruta Archi MCP configurada' }
      'gentle-ai' { return 'CLI del asistente de desarrollo usable (nativo)' }
      default { return "$Id OK" }
    }
  }
  switch ($Id) {
    'node' { return 'Falta Node usable en PATH (necesario para diagramas/herramientas del proyecto).' }
    'npm' { return 'Falta npm usable en PATH.' }
    'npx' { return 'Falta npx usable en PATH.' }
    'pandoc' { return 'Pandoc no está disponible (opcional para documentos).' }
    'backlog' {
      if ($Status -eq 'Duplicate') {
        return 'Hay más de una CLI de backlog válida en PATH — dejá solo una nativa.'
      }
      if ($Status -eq 'WindowsOriginRejected') {
        return 'CLI de backlog detectada solo como ejecutable Windows (inválido en Linux/WSL).'
      }
      if ($Status -eq 'Invalid' -or $Status -eq 'Failed') {
        if (-not [string]::IsNullOrWhiteSpace($Detail)) { return $Detail }
        return 'CLI backlog en PATH pero ninguna responde a --version.'
      }
      return 'Falta la CLI de backlog requerida por este proyecto.'
    }
    'archi' { return 'Falta o es inválida la ruta al servidor Archi MCP.' }
    'gentle-ai' {
      if ($Status -eq 'WindowsOriginRejected') {
        return 'Hay un CLI de asistente de Windows bajo WSL — usá la instalación nativa de Linux.'
      }
      if ($Status -eq 'Duplicate') {
        return 'Hay más de un CLI del asistente de desarrollo en PATH — dejá solo uno nativo.'
      }
      return 'Falta el CLI del asistente de desarrollo requerido por este proyecto.'
    }
    default {
      if (-not [string]::IsNullOrWhiteSpace($Detail)) { return $Detail }
      return "Falta o falló la herramienta: $Id"
    }
  }
}

function Invoke-HubProjectEnvironmentDoctor {
  <#
    Detect-only environment doctor for a child project.
    Exit semantics: ≠0 (2) when any required tool fails OR local-mcp is broken.
  #>
  param(
    [Parameter(Mandatory = $true)][string] $TargetPath,
    [switch] $AsJson
  )
  $TargetPath = [System.IO.Path]::GetFullPath($TargetPath)
  $requires = Get-HubProjectRequirements -TargetPath $TargetPath
  $metaCtx = Get-HubProjectEnvironmentDoctorMeta -TargetPath $TargetPath
  $checks = [System.Collections.Generic.List[object]]::new()

  foreach ($tool in @($requires.tools)) {
    $level = [string]$tool.level
    if ($level -eq 'absent') { continue }
    $id = [string]$tool.id
    $probe = Test-HubToolUsable -Id $id -ArchiPath $metaCtx.ArchiPath
    $pass = [bool]$probe.Ok
    $state = if ($pass) { 'ok' } elseif ($probe.Status -eq 'Missing') { 'missing' } else { 'failed' }
    $checks.Add([pscustomobject]@{
        id = $id
        level = $level
        pass = $pass
        state = $state
        message = (Get-HubToolDoctorEsMessage -Id $id -Pass $pass -Status ([string]$probe.Status) -Detail ([string]$probe.Message))
      })
  }

  $localMcp = Get-HubProjectLocalMcpDoctorCheck -TargetPath $TargetPath -LocalMcpToolsRequired ([bool]$metaCtx.LocalMcpToolsRequired)
  $checks.Add($localMcp)

  $dual = Get-GentleAiDualInstallDiagnosis -TargetPath $TargetPath
  if ($dual.Dual) {
    $checks.Add([pscustomobject]@{
        id = 'gentle-ai-dual'
        level = 'optional'
        pass = $false
        state = 'failed'
        message = 'Hay instalación duplicada del asistente (global y en este workspace). Es solo diagnóstico; no se modifica nada automáticamente.'
      })
  }

  $hasBrokenMcp = @($checks | Where-Object { [string]$_.id -eq 'local-mcp' -and [string]$_.state -eq 'broken' }).Count -gt 0
  $requiredOk = @($checks | Where-Object { [string]$_.level -eq 'required' -and -not [bool]$_.pass }).Count -eq 0
  $ok = $requiredOk -and (-not $hasBrokenMcp)
  $exitCode = if ($ok) { 0 } else { 2 }

  $result = [pscustomobject]@{
    ok = $ok
    exitCode = $exitCode
    checks = @($checks.ToArray())
    targetPath = $TargetPath
  }

  if ($AsJson) {
    return ($result | Select-Object ok, exitCode, checks | ConvertTo-Json -Depth 6)
  }
  return $result
}

function Write-HubProjectEnvironmentDoctor {
  param([Parameter(Mandatory = $true)]$Result)
  $status = if ($Result.ok) { 'OK' } else { 'PROBLEMAS' }
  Write-Host "Diagnóstico de entorno: $status (exit $($Result.exitCode))"
  foreach ($c in @($Result.checks)) {
    $mark = if ($c.pass) { '[ok]' } else { '[!!]' }
    Write-Host ("  {0} {1} ({2}): {3}" -f $mark, $c.id, $c.level, $c.message)
  }
}

function Write-EngagementMetadata {
  param([string] $TargetPath, [string] $StackProfileValue, [System.Collections.IDictionary] $Fields)
  $meta = [ordered]@{ schemaVersion = 4; stackProfile = $StackProfileValue; generatedAt = (Get-Date).ToString('o') }
  foreach ($key in $Fields.Keys) {
    if ($key -in @('requires', 'schemaVersion')) { continue }
    $meta[$key] = $Fields[$key]
  }
  $gentleScope = if ($meta.Contains('gentleAiScope')) { [string]$meta['gentleAiScope'] } else { 'none' }
  $meta['requires'] = Build-HubProjectRequires `
    -StackProfileValue $StackProfileValue `
    -IncludeDrawioMcp ([bool]$(if ($meta.Contains('includeDrawioMcp')) { $meta['includeDrawioMcp'] } else { $false })) `
    -IncludeBacklogMcp ([bool]$(if ($meta.Contains('includeBacklogMcp')) { $meta['includeBacklogMcp'] } else { $false })) `
    -IncludeArchiMcp ([bool]$(if ($meta.Contains('includeArchiMcp')) { $meta['includeArchiMcp'] } else { $false })) `
    -GentleAiScope $gentleScope
  $path = Join-Path $TargetPath '.consulting-engagement.json'
  [System.IO.File]::WriteAllText($path, (($meta | ConvertTo-Json -Depth 8) + "`n"), [System.Text.UTF8Encoding]::new($false))
  Sync-ProjectEnvironmentDoctorScript -TargetPath $TargetPath
}

function Write-ProjectProfile {
  param([string] $TargetPath, [string] $ProjectName, [string] $GentleAiScope)
  $scope = $GentleAiScope.ToLowerInvariant()
  $meta = [ordered]@{
    schemaVersion = 4
    stackProfile = 'gentle-ai-only'
    projectName = $ProjectName
    gentleAiScope = $scope
    generatedAt = (Get-Date).ToString('o')
    requires = Build-HubProjectRequires -StackProfileValue 'gentle-ai-only' -GentleAiScope $scope
  }
  $path = Join-Path $TargetPath '.project-profile.json'
  [System.IO.File]::WriteAllText($path, (($meta | ConvertTo-Json -Depth 8) + "`n"), [System.Text.UTF8Encoding]::new($false))
  Sync-ProjectEnvironmentDoctorScript -TargetPath $TargetPath
}

function Write-StackProfileConfig {
  param([string] $TargetPath, [string] $StackProfileValue)
  $atlDir = Join-Path $TargetPath '.atl'
  if (-not (Test-Path -LiteralPath $atlDir)) { New-Item -ItemType Directory -Path $atlDir -Force | Out-Null }
  $config = [ordered]@{ stackProfile = $StackProfileValue; excludeSkills = @('go-testing', 'branch-pr', 'chained-pr', 'work-unit-commits'); persistence = 'hybrid-repo-first' }
  $path = Join-Path $atlDir 'stack-profile.json'
  [System.IO.File]::WriteAllText($path, (($config | ConvertTo-Json -Depth 5) + "`n"), [System.Text.UTF8Encoding]::new($false))
}

function Test-ConsultingPlaceholders {
  param([string] $TargetPath)
  $bad = @()
  Get-ChildItem -LiteralPath $TargetPath -Recurse -File -Force | ForEach-Object {
    if (($_.Name -in @('.gitignore', '.cursorignore')) -or ($script:TextExtensions -contains $_.Extension.ToLowerInvariant())) {
      if ([System.IO.File]::ReadAllText($_.FullName) -match '\{\{') { $bad += $_.FullName }
    }
  }
  if ($bad.Count -gt 0) { throw "Quedaron placeholders sin reemplazar en:`n$($bad -join "`n")" }
}

function Write-ProjectOnboardingPending {
  param([string] $TargetPath, [string] $StackProfile)
  $atlDir = Join-Path $TargetPath '.atl'
  if (-not (Test-Path -LiteralPath $atlDir)) { New-Item -ItemType Directory -Path $atlDir -Force | Out-Null }
  $pending = [ordered]@{ pending = $true; stackProfile = $StackProfile; generatedAt = (Get-Date).ToString('o'); gettingStartedPath = 'docs/GETTING-STARTED.md'; hint = 'Ejecutá /onboarding o leé docs/GETTING-STARTED.md.' }
  $path = Join-Path $atlDir 'onboarding-pending.json'
  [System.IO.File]::WriteAllText($path, (($pending | ConvertTo-Json -Depth 5) + "`n"), [System.Text.UTF8Encoding]::new($false))
}

function Get-GettingStartedProfileLabel {
  param([string] $StackProfile, [string] $GentleAiScope = 'None')
  switch ($StackProfile) {
    'GentleAi' {
      if ($GentleAiScope -ne 'None') { return "GentleAi ($GentleAiScope + memoria del asistente)" }
      return 'GentleAi'
    }
    'Consulting' { return 'Consulting (sin Gentle AI)' }
    'ConsultingAI' { return 'ConsultingAI (CDD + SDD + memoria del asistente)' }
    'Full' { return 'Full (CDD + SDD + memoria del asistente)' }
    default { return $StackProfile }
  }
}

function Update-ProjectGettingStartedFromMetadata {
  param([Parameter(Mandatory = $true)][string] $TargetPath)
  $TargetPath = [System.IO.Path]::GetFullPath($TargetPath)
  if (-not (Test-Path -LiteralPath $TargetPath -PathType Container)) {
    throw "Proyecto no encontrado: $TargetPath"
  }

  $engagementPath = Join-Path $TargetPath '.consulting-engagement.json'
  $profilePath = Join-Path $TargetPath '.project-profile.json'

  if (Test-Path -LiteralPath $engagementPath) {
    $meta = Get-Content -LiteralPath $engagementPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $stackProfileValue = [string]$meta.stackProfile
    $stackProfile = switch ($stackProfileValue) {
      'consulting-only' { 'Consulting' }
      'consulting-ai' { 'ConsultingAI' }
      'full' { 'Full' }
      default {
        $normalized = $stackProfileValue.Trim()
        if ($normalized -match '^(?i)consultingai$') { 'ConsultingAI' }
        elseif ($normalized -match '^(?i)full$') { 'Full' }
        elseif ($normalized -match '^(?i)consulting$') { 'Consulting' }
        else { throw "stackProfile desconocido en $engagementPath : $($meta.stackProfile)" }
      }
    }
    $gentleScope = 'None'
    if ($meta.PSObject.Properties.Name -contains 'gentleAiScope' -and $meta.gentleAiScope) {
      $gentleScope = ([string]$meta.gentleAiScope).Substring(0, 1).ToUpperInvariant() + ([string]$meta.gentleAiScope).Substring(1).ToLowerInvariant()
    } elseif ($stackProfile -in @('ConsultingAI', 'Full')) {
      $gentleScope = 'Global'
    }

    # Same writer path as New-* / hub refresh --all: upsert schemaVersion 4 + requires.
    $fields = [ordered]@{}
    foreach ($prop in @($meta.PSObject.Properties)) {
      if ($prop.Name -in @('schemaVersion', 'stackProfile', 'generatedAt', 'requires')) { continue }
      $fields[$prop.Name] = $prop.Value
    }
    Write-EngagementMetadata -TargetPath $TargetPath -StackProfileValue $stackProfileValue -Fields $fields

    $title = if ($meta.docTitlePrefix) { [string]$meta.docTitlePrefix } else { Split-Path -Leaf $TargetPath }
    $templateName = if ($meta.corporateDocxTemplateName) { [string]$meta.corporateDocxTemplateName } else { 'Plantilla Ingenia - 2025.docx' }
    return Write-ProjectGettingStarted `
      -TargetPath $TargetPath -StackProfile $stackProfile -Title $title -GentleAiScope $gentleScope `
      -IncludeDrawioMcp ([bool]$meta.includeDrawioMcp) -IncludeBacklogMcp ([bool]$meta.includeBacklogMcp) `
      -IncludeArchiMcp ([bool]$meta.includeArchiMcp) -CorporateDocxTemplateName $templateName
  }

  if (Test-Path -LiteralPath $profilePath) {
    $meta = Get-Content -LiteralPath $profilePath -Raw -Encoding UTF8 | ConvertFrom-Json
    $projectName = if ($meta.projectName) { [string]$meta.projectName } else { Split-Path -Leaf $TargetPath }
    $gentleScope = if ($meta.gentleAiScope) {
      ([string]$meta.gentleAiScope).Substring(0, 1).ToUpperInvariant() + ([string]$meta.gentleAiScope).Substring(1).ToLowerInvariant()
    } else { 'Global' }
    # Same writer path as New-* / hub refresh --all: upsert schemaVersion 4 + requires.
    Write-ProjectProfile -TargetPath $TargetPath -ProjectName $projectName -GentleAiScope $gentleScope
    return Write-ProjectGettingStarted `
      -TargetPath $TargetPath -StackProfile GentleAi -Title $projectName -GentleAiScope $gentleScope
  }

  throw "No se encontró metadata de proyecto en: $TargetPath"
}

function Get-GettingStartedToolPurposeEs {
  param([Parameter(Mandatory = $true)][string] $Id)
  switch ($Id) {
    'node' { 'Node.js usable en PATH (diagramas y herramientas del proyecto)' }
    'npm' { 'npm usable en PATH' }
    'npx' { 'npx usable en PATH (diagramas Draw.io)' }
    'pandoc' { 'Pandoc para regenerar documentos (.docx)' }
    'backlog' { 'CLI backlog para el tablero del encargo' }
    'archi' { 'Archi / archi-server para modelado' }
    'gentle-ai' { 'CLI de asistencia del proyecto instalado y usable (una sola copia nativa)' }
    default { $Id }
  }
}

function Get-GettingStartedLevelLabelEs {
  param([Parameter(Mandatory = $true)][string] $Level)
  switch ($Level.ToLowerInvariant()) {
    'required' { 'Obligatorio' }
    'optional' { 'Opcional' }
    default { $Level }
  }
}

function Resolve-GettingStartedRequires {
  param(
    [string] $TargetPath,
    [string] $StackProfile,
    [string] $GentleAiScope = 'None',
    [bool] $IncludeDrawioMcp = $false,
    [bool] $IncludeBacklogMcp = $false,
    [bool] $IncludeArchiMcp = $false
  )

  if (-not [string]::IsNullOrWhiteSpace($TargetPath) -and (Test-Path -LiteralPath $TargetPath -PathType Container)) {
    $engagementPath = Join-Path $TargetPath '.consulting-engagement.json'
    $profilePath = Join-Path $TargetPath '.project-profile.json'
    if ((Test-Path -LiteralPath $engagementPath) -or (Test-Path -LiteralPath $profilePath)) {
      try {
        return Get-HubProjectRequirements -TargetPath $TargetPath
      } catch {
        # Fall through to toggle derivation.
      }
    }
  }

  $built = Build-HubProjectRequires `
    -StackProfileValue $StackProfile `
    -IncludeDrawioMcp $IncludeDrawioMcp `
    -IncludeBacklogMcp $IncludeBacklogMcp `
    -IncludeArchiMcp $IncludeArchiMcp `
    -GentleAiScope $GentleAiScope
  return ConvertTo-HubNormalizedRequires -Requires ([pscustomobject]$built)
}

function Write-ProjectGettingStarted {
  param(
    [string] $TargetPath, [string] $StackProfile, [string] $Title, [string] $GentleAiScope = 'None',
    [bool] $IncludeDrawioMcp = $false, [bool] $IncludeBacklogMcp = $false, [bool] $IncludeArchiMcp = $false,
    [string] $CorporateDocxTemplateName = 'Plantilla Ingenia - 2025.docx'
  )
  $docsDir = Join-Path $TargetPath 'docs'
  if (-not (Test-Path -LiteralPath $docsDir)) { New-Item -ItemType Directory -Path $docsDir -Force | Out-Null }

  $profileLabel = Get-GettingStartedProfileLabel -StackProfile $StackProfile -GentleAiScope $GentleAiScope
  $requiresGentleAi = $GentleAiScope -ne 'None'
  $isConsulting = $StackProfile -ne 'GentleAi'
  $hasCdd = $StackProfile -in @('ConsultingAI', 'Full')

  $requires = Resolve-GettingStartedRequires `
    -TargetPath $TargetPath `
    -StackProfile $StackProfile `
    -GentleAiScope $GentleAiScope `
    -IncludeDrawioMcp $IncludeDrawioMcp `
    -IncludeBacklogMcp $IncludeBacklogMcp `
    -IncludeArchiMcp $IncludeArchiMcp

  $visibleTools = @($requires.tools | Where-Object { $_.level -in @('required', 'optional') })
  $prereqRows = @()
  foreach ($tool in $visibleTools) {
    $levelLabel = Get-GettingStartedLevelLabelEs -Level ([string]$tool.level)
    $purpose = Get-GettingStartedToolPurposeEs -Id ([string]$tool.id)
    $prereqRows += "| ``$($tool.id)`` | $levelLabel | $purpose |"
  }
  $prereqTable = if ($prereqRows.Count) {
    "| Herramienta | Nivel | Para que |`n|-------------|-------|----------|`n$($prereqRows -join "`n")"
  } else {
    '_Sin herramientas adicionales listadas para este perfil._'
  }

  # Local MCP expected servers — never Engram (gentle-ai-managed, not child mcp.json).
  $localMcpServers = @()
  if ($IncludeDrawioMcp) { $localMcpServers += 'drawio' }
  if ($IncludeBacklogMcp) { $localMcpServers += 'backlog' }
  if ($IncludeArchiMcp) { $localMcpServers += 'archi' }
  $requiresLocalMcp = $localMcpServers.Count -gt 0
  $expectedMcpLabel = if ($requiresLocalMcp) { $localMcpServers -join ', ' } else { 'ninguno local' }

  $mcpStateNote = if ($requiresLocalMcp) {
@"

### Estados del archivo MCP local (``.cursor/mcp.json``)

- **Aun no materializado**: el archivo no existe o aun no esta generado. En este perfil **si importa** porque se esperan servidores locales (**$expectedMcpLabel**): sin ese archivo la verificacion del entorno falla hasta materializarlo.
- **Con problemas (roto)**: el archivo existe pero tiene JSON invalido, rutas incorrectas, o entradas que no deberian estar ahi. **Siempre es un fallo** a corregir (no es lo mismo que "aun no materializado").
"@
  } else {
@"

### Estados del archivo MCP local (``.cursor/mcp.json``)

- **Aun no materializado**: si no hay archivo MCP local, en este perfil es **solo informativo** (no se requieren servidores locales drawio/backlog/archi).
- **Con problemas (roto)**: si el archivo existe pero esta mal formado o con rutas/entradas invalidas, **siempre es un fallo** a corregir.
"@
  }

  $memoryNote = if ($requiresGentleAi) {
@"

> **Memoria del asistente:** no se configura en el MCP local de este repo. Tras abrir **esta** carpeta como workspace raiz, revisa Cursor Settings -> MCP: las herramientas de memoria deben figurar activas. Un CLI en terminal no alcanza si el workspace activo sigue siendo el hub padre.
"@
  } else { '' }

  $consultingWorkflow = if ($hasCdd) {
@"

### 3. Bootstrap del encargo

1. Invoca la skill **``bootstrap-consulting-engagement``** y responde las preguntas de contexto.
2. Completa o refina **README**, **SPEC** y **ARCHITECTURE**.

### 4. Inicializar CDD

1. Ejecuta **``/cdd-init``** para registrar el contexto del proyecto.
2. Primer entregable: **``/cdd-new [nombre-corto]``** (explore -> propose -> ... -> archive).

CDD es el flujo principal para entregables al cliente. SDD (``/sdd-new``) queda disponible si el encargo incluye desarrollo.

### 5. Trabajo cotidiano

- Material cliente -> ``docs/client-documentation/``, ``transcripts/``.
- Borradores -> ``docs/draft/``.
- Antes de exportar ``.docx`` al cliente: **``/cdd-verify``**.

### Plantilla Word

Copia **$CorporateDocxTemplateName** en ``docs/templates/`` desde el repositorio corporativo o almacenamiento interno de Ingenia.
"@
  } elseif ($isConsulting) {
@"

### 3. Bootstrap del encargo

1. Invoca la skill **``bootstrap-consulting-engagement``** y responde las preguntas de contexto.
2. Completa o refina **README**, **SPEC** y **ARCHITECTURE**.

### 4. Trabajo cotidiano

- Material cliente -> ``docs/client-documentation/``, ``transcripts/``.
- Borradores -> ``docs/draft/``.

### Plantilla Word

Copia **$CorporateDocxTemplateName** en ``docs/templates/`` desde el repositorio corporativo o almacenamiento interno de Ingenia.
"@
  } else { '' }

  $gentleAiWorkflow = if ($StackProfile -eq 'GentleAi') {
@"

## Paso 1 - Verificar entorno

$prereqTable

- Alcance de asistencia: **$GentleAiScope**. Los componentes administrados se heredan; **no** se duplican en ``.cursor/mcp.json``.
- Verifica cada herramienta **obligatoria** desde el terminal o Cursor Settings (no hace falta PowerShell).
$mcpStateNote
$memoryNote

## Paso 2 - Siguiente accion

Ejecutá **``/start-task``** para arrancar.
"@
  } else { '' }

  $consultingBody = if ($isConsulting) {
@"

## Paso 1 - Verificar entorno

$prereqTable

Comprueba cada herramienta **obligatoria** (version usable en PATH o instalacion nativa). **No** hace falta ejecutar scripts PowerShell para esta verificacion.
$mcpStateNote
$memoryNote

Detalle por SO: [MCP-PREREQUISITOS.md](MCP-PREREQUISITOS.md).

## Paso 2 - Confirmar metadata del encargo

Revisa ``.consulting-engagement.json`` (cliente, iniciativa, MCP toggles, ``stackProfile``, ``requires``).
$consultingWorkflow

## Referencia rapida

| Documento | Uso |
|-----------|-----|
| [README.md](../README.md) | Indice del repo |
| [SPEC.md](../SPEC.md) | Alcance y objetivos |
| [ARCHITECTURE.md](../ARCHITECTURE.md) | Contexto tecnico |
| ``.cursor/skills/`` | Skills del agente (bootstrap, entregables, CDD/SDD) |
"@
  } else { $gentleAiWorkflow }

  $localMcpSteps = if ($requiresLocalMcp) {
@"
3. **Cursor Settings -> MCP** - verifica que los servidores locales esperados (**$expectedMcpLabel**) figuren en verde.
4. Si **archi** o **backlog** usan rutas placeholder, edita ``.cursor/mcp.json`` con rutas absolutas reales (ver [MCP-PREREQUISITOS.md](MCP-PREREQUISITOS.md)).
5. En el chat del agente, ejecuta **/onboarding** para un recorrido guiado (workspace, entorno y proximos pasos).
"@
  } else {
@"
3. **Cursor Settings -> MCP** - confirma que no falten integraciones administradas del asistente (si aplica a tu perfil).
4. En el chat del agente, ejecuta **/onboarding** para un recorrido guiado (workspace, entorno y proximos pasos).
"@
  }

  $content = @"
# Primeros pasos - $Title

> Checklist generada al crear el proyecto. Perfil: **$profileLabel**.

## Paso 0 - Abri este repo como workspace (obligatorio)

Los servidores MCP **locales** del proyecto (**$expectedMcpLabel**) se leen desde ``.cursor/mcp.json`` de **esta carpeta**. Si seguis con el **hub generador padre** como workspace raiz, el contexto y las integraciones de **este** proyecto **no** estaran disponibles en el agente aunque un CLI funcione en terminal.
1. **File -> Open Folder** -> selecciona la raiz de **este** repositorio (la carpeta que contiene este archivo).
2. **Developer: Reload Window** si las integraciones no aparecen al abrir.
$localMcpSteps
$consultingBody
## Seguis en el hub generador?

Si creaste este proyecto desde un **hub generador**, el trabajo del encargo (SPEC, entregables, CDD) se hace **aqui**, no en el repo padre. Volve al hub solo para mantener el template o generar otros proyectos.

## Presupuesto de contexto

- Un objetivo y un dominio por chat.
- Empezar por ``PROJECT-CONTEXT.md`` y un indice del dominio.
- Abrir como maximo dos archivos de contenido; justificar antes de ampliar.
- Consultar fuentes pesadas o transcripts solo por necesidad concreta.
"@
  $path = Join-Path $docsDir 'GETTING-STARTED.md'
  [System.IO.File]::WriteAllText($path, ($content.TrimEnd() + "`n"), [System.Text.UTF8Encoding]::new($false))
  Write-ProjectOnboardingPending -TargetPath $TargetPath -StackProfile $StackProfile
  return $path
}

function Copy-ProjectOnboardingLayer {
  param([string] $SourceRoot, [string] $TargetPath)
  $ruleSrc = Join-HubPath $SourceRoot 'skeleton' '.cursor' 'rules' 'onboarding.mdc'
  $skillSrc = Join-HubPath $SourceRoot 'skeleton' '.cursor' 'skills' 'onboarding'
  $ruleDestDir = Join-HubPath $TargetPath '.cursor' 'rules'
  $skillDestDir = Join-HubPath $TargetPath '.cursor' 'skills' 'onboarding'
  if (-not (Test-Path -LiteralPath $ruleDestDir)) { New-Item -ItemType Directory -Path $ruleDestDir -Force | Out-Null }
  if (Test-Path -LiteralPath $ruleSrc) { Copy-Item -LiteralPath $ruleSrc -Destination $ruleDestDir -Force }
  if (Test-Path -LiteralPath $skillSrc) {
    if (-not (Test-Path -LiteralPath $skillDestDir)) { New-Item -ItemType Directory -Path $skillDestDir -Force | Out-Null }
    Get-ChildItem -LiteralPath $skillSrc -Force | Copy-Item -Destination $skillDestDir -Recurse -Force
  }
}

function Invoke-OpenCursorWorkspace {
  param([string] $TargetPath)
  $paths = @(Get-CommandExecutablePaths -Name 'cursor' -AllowWindowsExecutable)
  if ($paths.Count -ne 1) { Write-Warning "Abrí manualmente en Cursor: $TargetPath"; return $false }
  & $paths[0] $TargetPath
  return $LASTEXITCODE -eq 0
}

function Write-ProjectHandoffSummary {
  param([string] $TargetPath, [string] $StackProfile, [string] $GettingStartedPath, [string] $GentleAiScope = 'None')
  Write-Host ''; Write-Host '=== Proyecto creado ===' -ForegroundColor Green
  Write-Host "Abrí como workspace raíz: $TargetPath" -ForegroundColor Yellow
  Write-Host "Checklist: $GettingStartedPath"
  Write-Host "Perfil: $StackProfile | Gentle AI: $GentleAiScope"
  Write-Host 'Inicio recomendado: /start-task'; Write-Host ''
}

function Resolve-HubRootPath {
  param([Parameter(Mandatory = $true)][string] $Path)
  Platform\Resolve-HubRootPath -Path $Path
}

function Test-HubPathIsChildOf {
  param(
    [Parameter(Mandatory = $true)][string] $ChildPath,
    [Parameter(Mandatory = $true)][string] $ParentPath
  )
  Platform\Test-HubPathIsChildOf -ChildPath $ChildPath -ParentPath $ParentPath
}

function Test-HubRootLayout {
  param([Parameter(Mandatory = $true)][string] $HubRoot)
  $resolved = Resolve-HubRootPath $HubRoot
  $markers = @(
    (Join-HubPath $resolved 'hub-registry.json'),
    (Join-HubPath $resolved 'scripts' 'New-HubProject.ps1'),
    (Join-HubPath $resolved 'skeleton')
  )
  return @($markers | Where-Object { -not (Test-Path -LiteralPath $_) })
}

function Get-HubMoveBackupPath {
  param(
    [Parameter(Mandatory = $true)][string] $SourcePath,
    [datetime] $Timestamp = (Get-Date)
  )
  $source = Resolve-HubRootPath $SourcePath
  $leaf = Split-Path -Leaf $source
  $parent = Split-Path -Parent $source
  $stamp = $Timestamp.ToString('yyyyMMdd-HHmmss')
  return Join-Path $parent "${leaf}-backup-${stamp}"
}

function Test-HubMovePreconditions {
  param(
    [Parameter(Mandatory = $true)][string] $SourcePath,
    [Parameter(Mandatory = $true)][string] $DestinationPath
  )

  $issues = [System.Collections.Generic.List[string]]::new()
  $source = Resolve-HubRootPath $SourcePath
  $destination = Resolve-HubRootPath $DestinationPath

  if (-not (Test-Path -LiteralPath $source -PathType Container)) {
    $issues.Add("Origen inexistente: $source")
  }
  else {
    $missing = @(Test-HubRootLayout -HubRoot $source)
    if ($missing.Count -gt 0) {
      $issues.Add("Origen no parece un hub válido. Faltan: $($missing -join ', ')")
    }
  }

  if ($source -eq $destination) {
    $issues.Add('Origen y destino son la misma ruta.')
  }

  if (Test-HubPathIsChildOf -ChildPath $destination -ParentPath $source) {
    $issues.Add('El destino no puede estar dentro del hub origen.')
  }

  if (Test-HubPathIsChildOf -ChildPath $source -ParentPath $destination) {
    $issues.Add('El origen no puede estar dentro del destino.')
  }

  $destParent = Split-Path -Parent $destination
  if ([string]::IsNullOrWhiteSpace($destParent)) {
    $issues.Add("No se pudo resolver el directorio padre del destino: $destination")
  }
  elseif (-not (Test-Path -LiteralPath $destParent -PathType Container)) {
    $issues.Add("El directorio padre del destino no existe: $destParent")
  }

  if (Test-Path -LiteralPath $destination) {
    $existing = @(Get-ChildItem -LiteralPath $destination -Force -ErrorAction SilentlyContinue)
    if ($existing.Count -gt 0) {
      $issues.Add("El destino ya existe y no está vacío: $destination")
    }
  }

  return [pscustomobject]@{
    Ok = ($issues.Count -eq 0)
    SourcePath = $source
    DestinationPath = $destination
    Issues = @($issues)
  }
}

function Replace-HubPathPrefixInText {
  param(
    [Parameter(Mandatory = $true)][string] $Text,
    [Parameter(Mandatory = $true)][string] $OldPrefix,
    [Parameter(Mandatory = $true)][string] $NewPrefix
  )
  if ([string]::IsNullOrEmpty($Text)) { return $Text }

  $old = Resolve-HubRootPath $OldPrefix
  $new = Resolve-HubRootPath $NewPrefix
  if ($old -eq $new) { return $Text }
  if ($Text.IndexOf($old, [StringComparison]::OrdinalIgnoreCase) -lt 0) { return $Text }

  $result = $Text
  $index = 0
  while (($index = $result.IndexOf($old, $index, [StringComparison]::OrdinalIgnoreCase)) -ge 0) {
    $result = $result.Remove($index, $old.Length).Insert($index, $new)
    $index += $new.Length
  }
  return $result
}

function Replace-HubPathLiteralInText {
  param(
    [Parameter(Mandatory = $true)][string] $Text,
    [Parameter(Mandatory = $true)][string] $OldLiteral,
    [Parameter(Mandatory = $true)][string] $NewLiteral
  )
  if ([string]::IsNullOrEmpty($Text) -or [string]::IsNullOrEmpty($OldLiteral)) { return $Text }
  if ($OldLiteral -eq $NewLiteral) { return $Text }
  if ($Text.IndexOf($OldLiteral, [StringComparison]::OrdinalIgnoreCase) -lt 0) { return $Text }

  $result = $Text
  $index = 0
  while (($index = $result.IndexOf($OldLiteral, $index, [StringComparison]::OrdinalIgnoreCase)) -ge 0) {
    $result = $result.Remove($index, $OldLiteral.Length).Insert($index, $NewLiteral)
    $index += $NewLiteral.Length
  }
  return $result
}

function Update-HubRegistryPaths {
  param(
    [Parameter(Mandatory = $true)][string] $HubRoot,
    [Parameter(Mandatory = $true)][string] $OldHubRoot
  )

  $registryPath = Get-HubRegistryPath -HubRoot $HubRoot
  if (-not (Test-Path -LiteralPath $registryPath)) {
    return [pscustomobject]@{ Updated = $false; Path = $registryPath; ProjectCount = 0 }
  }

  $hub = Resolve-HubRootPath $HubRoot
  $oldHub = Resolve-HubRootPath $OldHubRoot
  $current = Read-HubRegistry -HubRoot $HubRoot -RegistryPath $registryPath
  $projects = [System.Collections.Generic.List[object]]::new()
  $updatedCount = 0

  foreach ($item in @($current.Projects)) {
    $entry = $item.Entry
    # Schema v2 relativo: no cambia al mover el hub.
    if ($entry.PSObject.Properties.Name -contains 'relativePath' -and -not [string]::IsNullOrWhiteSpace([string]$entry.relativePath)) {
      $migrated = Convert-HubRegistryProjectToV2 -HubRoot $hub -Project $entry -ExternalPolicy KeepExternal
      $projects.Add($migrated.Project) | Out-Null
      continue
    }
    if ($entry.PSObject.Properties.Name -contains 'absolutePath' -and -not [string]::IsNullOrWhiteSpace([string]$entry.absolutePath)) {
      $currentPath = [string]$entry.absolutePath
      $map = @{}
      foreach ($prop in @($entry.PSObject.Properties)) { $map[$prop.Name] = $prop.Value }
      if ($currentPath.StartsWith($oldHub, [StringComparison]::OrdinalIgnoreCase)) {
        $suffix = $currentPath.Substring($oldHub.Length)
        $map['absolutePath'] = $hub + $suffix
        $updatedCount++
      }
      $migrated = Convert-HubRegistryProjectToV2 -HubRoot $hub -Project ([pscustomobject]$map) -ExternalPolicy KeepExternal
      $projects.Add($migrated.Project) | Out-Null
      $updatedCount++
      continue
    }
    $migrated = Convert-HubRegistryProjectToV2 -HubRoot $hub -Project $entry -ExternalPolicy KeepExternal
    $projects.Add($migrated.Project) | Out-Null
  }

  $document = New-HubRegistryDocument -SchemaVersion 2 -Projects @($projects)
  Write-HubRegistry -RegistryPath $registryPath -Document $document | Out-Null

  return [pscustomobject]@{
    Updated = $true
    Path = $registryPath
    ProjectCount = $updatedCount
    SchemaVersion = 2
  }
}

function Update-HubChildMcpPaths {
  param(
    [Parameter(Mandatory = $true)][string] $HubRoot,
    [Parameter(Mandatory = $true)][string] $OldHubRoot
  )

  $hub = Resolve-HubRootPath $HubRoot
  $oldHub = Resolve-HubRootPath $OldHubRoot
  $projectsRoot = Join-Path $hub 'projects'
  $updatedFiles = [System.Collections.Generic.List[string]]::new()

  if (-not (Test-Path -LiteralPath $projectsRoot -PathType Container)) {
    return @()
  }

  foreach ($projectDir in @(Get-ChildItem -LiteralPath $projectsRoot -Directory -ErrorAction SilentlyContinue)) {
    $mcpPath = Join-HubPath $projectDir.FullName '.cursor' 'mcp.json'
    if (-not (Test-Path -LiteralPath $mcpPath -PathType Leaf)) { continue }

    $raw = [System.IO.File]::ReadAllText($mcpPath, [System.Text.UTF8Encoding]::new($false))
    $newRaw = Replace-HubPathPrefixInText -Text $raw -OldPrefix $oldHub -NewPrefix $hub

    $oldJson = $oldHub.Replace('\', '\\')
    $newJson = $hub.Replace('\', '\\')
    if ($oldJson -ne $oldHub) {
      $newRaw = Replace-HubPathLiteralInText -Text $newRaw -OldLiteral $oldJson -NewLiteral $newJson
    }

    if ($newRaw -eq $raw) { continue }

    [System.IO.File]::WriteAllText($mcpPath, $newRaw, [System.Text.UTF8Encoding]::new($false))
    $updatedFiles.Add($mcpPath) | Out-Null
  }

  return @($updatedFiles)
}

function Update-HubPathReferences {
  param(
    [Parameter(Mandatory = $true)][string] $HubRoot,
    [Parameter(Mandatory = $true)][string] $OldHubRoot
  )

  $registryResult = Update-HubRegistryPaths -HubRoot $HubRoot -OldHubRoot $OldHubRoot
  $mcpFiles = @(Update-HubChildMcpPaths -HubRoot $HubRoot -OldHubRoot $OldHubRoot)

  return [pscustomobject]@{
    HubRoot = (Resolve-HubRootPath $HubRoot)
    OldHubRoot = (Resolve-HubRootPath $OldHubRoot)
    Registry = $registryResult
    UpdatedMcpFiles = $mcpFiles
  }
}

function Test-HubMoveResult {
  param([Parameter(Mandatory = $true)][string] $HubRoot)

  $issues = [System.Collections.Generic.List[string]]::new()
  $hub = Resolve-HubRootPath $HubRoot

  foreach ($missing in @(Test-HubRootLayout -HubRoot $hub)) {
    $issues.Add("Estructura del hub incompleta. Falta: $missing")
  }

  $registryPath = Get-HubRegistryPath -HubRoot $hub
  if (-not (Test-Path -LiteralPath $registryPath)) {
    $issues.Add('No se encontró hub-registry.json.')
    return [pscustomobject]@{ Ok = $false; HubRoot = $hub; Issues = @($issues) }
  }

  $registry = Read-HubRegistry -HubRoot $hub -RegistryPath $registryPath
  foreach ($item in @($registry.Projects)) {
    if ($item.ResolveError) {
      $issues.Add("No se pudo resolver ($($item.FolderName)): $($item.ResolveError)")
      continue
    }
    $projectPath = $item.ResolvedPath
    if (-not (Test-HubPathIsChildOf -ChildPath $projectPath -ParentPath $hub) -and -not (Compare-HubPath -Left $projectPath -Right $hub)) {
      $issues.Add("Ruta de proyecto fuera del hub ($($item.FolderName)): $projectPath")
    }
    if (-not $item.Exists) {
      $issues.Add("Proyecto registrado no encontrado ($($item.FolderName)): $projectPath")
    }

    $mcpPath = Join-HubPath $projectPath '.cursor' 'mcp.json'
    if (-not (Test-Path -LiteralPath $mcpPath)) { continue }

    try {
      $mcp = Get-Content -LiteralPath $mcpPath -Raw -Encoding UTF8 | ConvertFrom-Json
      $backlog = $null
      $mcpNames = @(Get-HubMcpServerNames -McpJsonPath $mcpPath)
      if ('backlog' -in $mcpNames) {
        $backlog = $mcp.mcpServers.backlog
      }
      if ($backlog -and $backlog.args) {
        $backlogArgs = @($backlog.args)
        for ($i = 0; $i -lt $backlogArgs.Count; $i++) {
          if ($backlogArgs[$i] -eq '--cwd' -and ($i + 1) -lt $backlogArgs.Count) {
            $cwd = [string]$backlogArgs[$i + 1]
            if ($cwd -and -not (Test-Path -LiteralPath $cwd -PathType Container)) {
              $issues.Add("Backlog MCP --cwd inválido ($($item.FolderName)): $cwd")
            }
            elseif ($cwd -and -not ((Test-HubPathIsChildOf -ChildPath $cwd -ParentPath $hub) -or (Compare-HubPath -Left $cwd -Right $hub))) {
              $issues.Add("Backlog MCP --cwd fuera del hub ($($item.FolderName)): $cwd")
            }
          }
        }
      }
    } catch {
      $issues.Add("MCP inválido ($($item.FolderName)): $($_.Exception.Message)")
    }
  }

  return [pscustomobject]@{
    Ok = ($issues.Count -eq 0)
    HubRoot = $hub
    Issues = @($issues)
  }
}

function New-HubMoveBackup {
  param(
    [Parameter(Mandatory = $true)][string] $SourcePath,
    [Parameter(Mandatory = $true)][string] $BackupPath
  )

  Assert-HubWindowsNativeHost -OperationName 'New-HubMoveBackup'

  if (Test-Path -LiteralPath $BackupPath) {
    throw "Ya existe el destino de backup: $BackupPath"
  }

  $source = Resolve-HubRootPath $SourcePath
  $backup = Resolve-HubRootPath $BackupPath
  $backupParent = Split-Path -Parent $backup
  if (-not (Test-Path -LiteralPath $backupParent -PathType Container)) {
    New-Item -ItemType Directory -Path $backupParent -Force | Out-Null
  }

  # robocopy es Windows-only; sin él (raro en Windows) se usa Copy-Item.
  $robocopy = Get-Command robocopy.exe -ErrorAction SilentlyContinue
  if ($robocopy) {
    & robocopy.exe $source $backup /E /COPY:DAT /R:1 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -gt 7) {
      throw "Robocopy falló al crear backup (código $LASTEXITCODE)."
    }
  }
  else {
    Copy-Item -LiteralPath $source -Destination $backup -Recurse -Force
  }

  return [pscustomobject]@{
    SourcePath = $source
    BackupPath = $backup
  }
}

function Move-HubRootDirectory {
  param(
    [Parameter(Mandatory = $true)][string] $SourcePath,
    [Parameter(Mandatory = $true)][string] $DestinationPath
  )

  Assert-HubWindowsNativeHost -OperationName 'Move-HubRootDirectory'

  $source = Resolve-HubRootPath $SourcePath
  $destination = Resolve-HubRootPath $DestinationPath
  $destParent = Split-Path -Parent $destination

  if (-not (Test-Path -LiteralPath $destParent -PathType Container)) {
    New-Item -ItemType Directory -Path $destParent -Force | Out-Null
  }

  Move-Item -LiteralPath $source -Destination $destination
  return [pscustomobject]@{
    SourcePath = $source
    DestinationPath = (Resolve-HubRootPath $destination)
  }
}

function Invoke-HubRelocate {
  param(
    [Parameter(Mandatory = $true)][string] $SourcePath,
    [Parameter(Mandatory = $true)][string] $DestinationPath,
    [switch] $SkipBackup,
    [switch] $WhatIf
  )

  # WhatIf puede planear en cualquier OS (sin escrituras). La ejecución real es Windows-only.
  if (-not $WhatIf) {
    Assert-HubWindowsNativeHost -OperationName 'Invoke-HubRelocate'
  }

  $precheck = Test-HubMovePreconditions -SourcePath $SourcePath -DestinationPath $DestinationPath
  if (-not $precheck.Ok) {
    throw ($precheck.Issues -join [Environment]::NewLine)
  }

  $source = $precheck.SourcePath
  $destination = $precheck.DestinationPath
  $backupPath = Get-HubMoveBackupPath -SourcePath $source

  $plan = [ordered]@{
    SourcePath = $source
    DestinationPath = $destination
    BackupPath = if ($SkipBackup) { $null } else { $backupPath }
  }

  if ($WhatIf) {
    return [pscustomobject]@{
      WhatIf = $true
      Plan = $plan
      Validation = $null
      PathUpdates = $null
    }
  }

  $backupResult = $null
  if (-not $SkipBackup) {
    $backupResult = New-HubMoveBackup -SourcePath $source -BackupPath $backupPath
  }

  $moveResult = Move-HubRootDirectory -SourcePath $source -DestinationPath $destination
  $pathUpdates = Update-HubPathReferences -HubRoot $destination -OldHubRoot $source
  $validation = Test-HubMoveResult -HubRoot $destination

  if (-not $validation.Ok) {
    throw ("La migración terminó pero la validación falló:`n" + ($validation.Issues -join [Environment]::NewLine))
  }

  return [pscustomobject]@{
    WhatIf = $false
    Plan = $plan
    Backup = $backupResult
    Move = $moveResult
    PathUpdates = $pathUpdates
    Validation = $validation
  }
}

function Get-GentleAiProjectDiagnostic {
  param(
    [Parameter(Mandatory = $true)][string] $TargetPath,
    [string] $UserHome
  )
  $TargetPath = [System.IO.Path]::GetFullPath($TargetPath)
  if (-not (Test-Path -LiteralPath $TargetPath -PathType Container)) {
    throw "Proyecto no encontrado: $TargetPath"
  }

  $environment = Get-GentleAiEnvironment -TargetPath $TargetPath -UserHome $UserHome
  $userHomeResolved = Get-ConsultingUserHome -UserHome $UserHome
  $localSkillsRoot = Join-HubPath $TargetPath '.cursor' 'skills'
  $globalSkillsRoot = Join-HubPath $userHomeResolved '.cursor' 'skills'
  $skillCollisionExclude = @('_shared')
  $collisions = @()
  if ((Test-Path -LiteralPath $localSkillsRoot) -and (Test-Path -LiteralPath $globalSkillsRoot)) {
    $localNames = @(Get-ChildItem -LiteralPath $localSkillsRoot -Directory -Force | ForEach-Object { $_.Name })
    $globalNames = @(Get-ChildItem -LiteralPath $globalSkillsRoot -Directory -Force | ForEach-Object { $_.Name })
    $collisions = @($localNames | Where-Object {
      $_ -notin $skillCollisionExclude -and ($globalNames -contains $_)
    } | Sort-Object -Unique)
  }

  $alwaysApply = @()
  $rulesRoot = Join-HubPath $TargetPath '.cursor' 'rules'
  if (Test-Path -LiteralPath $rulesRoot) {
    Get-ChildItem -LiteralPath $rulesRoot -Filter '*.mdc' -File -Force | ForEach-Object {
      if ((Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8) -match '(?m)^alwaysApply:\s*true\s*$') {
        $alwaysApply += $_.Name
      }
    }
  }

  $issues = @()
  if ($environment.CliStatus -eq 'WindowsOriginRejected') { $issues += 'windows-origin-cli' }
  if ($environment.CliCount -gt 1 -or $environment.CliStatus -eq 'Duplicate') { $issues += 'multiple-gentle-ai-cli' }
  if ($environment.GlobalInstalled -and $environment.WorkspaceInstalled) { $issues += 'global-workspace-duplicate' }
  if ($environment.WorkspaceEngramConfigured) { $issues += 'workspace-engram-mcp' }
  if ($collisions.Count -gt 0) { $issues += 'local-global-skill-collision' }
  if (@($alwaysApply | Where-Object { $_ -notin @('consulting-copilot.mdc', 'context-budget.mdc') }).Count -gt 0) {
    $issues += 'excessive-always-apply-rules'
  }

  return [pscustomobject]@{
    targetPath = $TargetPath
    cliPaths = @($environment.CliPaths)
    globalGentleAi = [bool]$environment.GlobalInstalled
    workspaceGentleAi = [bool]$environment.WorkspaceInstalled
    globalEngramMcp = [bool]$environment.GlobalEngramConfigured
    workspaceEngramMcp = [bool]$environment.WorkspaceEngramConfigured
    skillCollisions = @($collisions)
    alwaysApplyRules = @($alwaysApply)
    issues = @($issues)
    healthy = $issues.Count -eq 0
    remediation = @(
      'No edites ni borres manualmente archivos administrados por Gentle AI.',
      'Usá gentle-ai doctor como primer diagnóstico.',
      'Si actualizaste el binario, usá gentle-ai sync.',
      'Revisá el dry-run del instalador antes de cualquier cambio de alcance.'
    )
  }
}

function Write-GentleAiProjectDiagnostic {
  param([Parameter(Mandatory = $true)] $Result)
  Write-Host "Proyecto: $($Result.targetPath)"
  Write-Host "Gentle AI global: $($Result.globalGentleAi) | workspace: $($Result.workspaceGentleAi)"
  Write-Host "Engram MCP global: $($Result.globalEngramMcp) | workspace: $($Result.workspaceEngramMcp)"
  Write-Host "CLI: $($Result.cliPaths -join '; ')"
  Write-Host "Skills local/global repetidas: $($Result.skillCollisions -join ', ')"
  Write-Host "Reglas alwaysApply: $($Result.alwaysApplyRules -join ', ')"
  if ($Result.healthy) { Write-Host 'Resultado: OK' -ForegroundColor Green }
  else { Write-Host "Resultado: revisar $($Result.issues -join ', ')" -ForegroundColor Yellow }
}

function Get-HubProjectProfileFromRoot {
  param([string] $Root)
  $projectProfile = Join-Path $Root '.project-profile.json'
  $engagementMeta = Join-Path $Root '.consulting-engagement.json'

  if (Test-Path -LiteralPath $projectProfile) {
    $meta = Get-Content -LiteralPath $projectProfile -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($meta.stackProfile -eq 'gentle-ai-only') { return 'GentleAi' }
  }

  if (Test-Path -LiteralPath $engagementMeta) {
    $meta = Get-Content -LiteralPath $engagementMeta -Raw -Encoding UTF8 | ConvertFrom-Json
    switch ($meta.stackProfile) {
      'consulting-only' { return 'Consulting' }
      'consulting-ai' { return 'ConsultingAI' }
      default { return [string]$meta.stackProfile }
    }
  }

  return 'Unknown'
}

function Test-HubDiagnosticPathExists {
  param([string] $Path, [string] $Label)
  if (-not (Test-Path -LiteralPath $Path)) { return "missing-$Label" }
  return $null
}

function Test-HubDiagnosticPathAbsent {
  param([string] $Path, [string] $Label)
  if (Test-Path -LiteralPath $Path) { return "unexpected-$Label" }
  return $null
}

function Get-HubMcpServerNames {
  param([string] $McpJsonPath)
  if (-not (Test-Path -LiteralPath $McpJsonPath -PathType Leaf)) { return @() }
  $config = Get-Content -LiteralPath $McpJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
  if (-not $config.mcpServers) { return @() }
  $props = @($config.mcpServers.PSObject.Properties)
  if ($props.Count -eq 0) { return @() }
  return @($props | ForEach-Object { $_.Name })
}

function Test-HubProfileUsesGentleAi {
  param([string] $Profile)
  return $Profile -in @('ConsultingAI', 'GentleAi')
}

function Test-HubCommonStructureChecks {
  param([string] $Root)
  $issues = @()
  try {
    Test-ConsultingPlaceholders -TargetPath $Root
  } catch {
    $issues += 'unresolved-placeholders'
  }

  foreach ($pair in @(
    @{ Path = (Join-HubPath $Root 'docs' 'GETTING-STARTED.md'); Label = 'getting-started' }
    @{ Path = (Join-Path $Root 'PROJECT-CONTEXT.md'); Label = 'project-context' }
  )) {
    $issue = Test-HubDiagnosticPathExists -Path $pair.Path -Label $pair.Label
    if ($issue) { $issues += $issue }
  }

  return $issues
}

function Test-HubConsultingBaseStructureChecks {
  param(
    [string] $Root,
    [object] $EngagementMeta
  )
  $issues = @()
  $mcpPath = Join-HubPath $Root '.cursor' 'mcp.json'

  foreach ($pair in @(
    @{ Path = (Join-HubPath $Root '.cursor' 'rules' 'consulting-copilot.mdc'); Label = 'consulting-copilot-rule' }
    @{ Path = (Join-HubPath $Root '.atl' 'stack-profile.json'); Label = 'stack-profile-config' }
    @{ Path = $mcpPath; Label = 'mcp-json' }
  )) {
    $issue = Test-HubDiagnosticPathExists -Path $pair.Path -Label $pair.Label
    if ($issue) { $issues += $issue }
  }

  $issue = Test-HubDiagnosticPathAbsent -Path (Join-HubPath $Root '.cursor' 'rules' 'gentle-ai.mdc') -Label 'gentle-ai-rule'
  if ($issue) { $issues += $issue }

  $servers = Get-HubMcpServerNames -McpJsonPath $mcpPath
  if ($EngagementMeta.includeDrawioMcp -and 'drawio' -notin $servers) { $issues += 'missing-mcp-drawio' }
  if ($EngagementMeta.includeBacklogMcp -and 'backlog' -notin $servers) { $issues += 'missing-mcp-backlog' }
  if ($EngagementMeta.includeArchiMcp -and 'archi' -notin $servers) { $issues += 'missing-mcp-archi' }
  if ('engram' -in $servers) { $issues += 'workspace-engram-mcp' }

  return $issues
}

function Test-HubConsultingStructureChecks {
  param(
    [string] $Root,
    [object] $EngagementMeta
  )
  $issues = Test-HubConsultingBaseStructureChecks -Root $Root -EngagementMeta $EngagementMeta
  if ($EngagementMeta.stackProfile -ne 'consulting-only') { $issues += 'wrong-stack-profile' }
  $issue = Test-HubDiagnosticPathAbsent -Path (Join-HubPath $Root '.cursor' 'agents' 'cdd-explore.md') -Label 'cdd-overlay'
  if ($issue) { $issues += $issue }
  return $issues
}

function Test-HubConsultingAiStructureChecks {
  param(
    [string] $Root,
    [object] $EngagementMeta
  )
  $issues = Test-HubConsultingBaseStructureChecks -Root $Root -EngagementMeta $EngagementMeta
  if ($EngagementMeta.stackProfile -ne 'consulting-ai') { $issues += 'wrong-stack-profile' }

  foreach ($pair in @(
    @{ Path = (Join-HubPath $Root '.cursor' 'agents' 'cdd-explore.md'); Label = 'cdd-explore-agent' }
    @{ Path = (Join-HubPath $Root '.cursor' 'rules' 'gentle-ai-consulting.mdc'); Label = 'gentle-ai-consulting-rule' }
    @{ Path = (Join-HubPath $Root '.cursor' 'skills' 'consulting-driven-delivery' 'SKILL.md'); Label = 'cdd-skill' }
  )) {
    $issue = Test-HubDiagnosticPathExists -Path $pair.Path -Label $pair.Label
    if ($issue) { $issues += $issue }
  }

  if ($EngagementMeta.engramMcpSource -ne 'gentle-ai-managed') { $issues += 'unexpected-engram-source' }
  return $issues
}

function Test-HubGentleAiStructureChecks {
  param(
    [string] $Root,
    [object] $ProjectMeta
  )
  $issues = @()
  $mcpPath = Join-HubPath $Root '.cursor' 'mcp.json'

  if ($ProjectMeta.stackProfile -ne 'gentle-ai-only') { $issues += 'wrong-stack-profile' }

  foreach ($pair in @(
    @{ Path = (Join-HubPath $Root '.cursor' 'skills' 'onboarding' 'SKILL.md'); Label = 'onboarding-skill' }
    @{ Path = (Join-Path $Root 'README.md'); Label = 'readme' }
  )) {
    $issue = Test-HubDiagnosticPathExists -Path $pair.Path -Label $pair.Label
    if ($issue) { $issues += $issue }
  }

  foreach ($pair in @(
    @{ Path = (Join-Path $Root '.consulting-engagement.json'); Label = 'consulting-engagement' }
    @{ Path = (Join-HubPath $Root '.cursor' 'rules' 'consulting-copilot.mdc'); Label = 'consulting-copilot-rule' }
    @{ Path = (Join-HubPath $Root '.cursor' 'agents' 'cdd-explore.md'); Label = 'cdd-overlay' }
  )) {
    $issue = Test-HubDiagnosticPathAbsent -Path $pair.Path -Label $pair.Label
    if ($issue) { $issues += $issue }
  }

  if (Test-Path -LiteralPath $mcpPath) {
    $servers = Get-HubMcpServerNames -McpJsonPath $mcpPath
    if ('engram' -in $servers) { $issues += 'workspace-engram-mcp' }
  }

  return $issues
}

function Get-HubProjectDiagnostic {
  param(
    [Parameter(Mandatory = $true)][string] $TargetPath,
    [ValidateSet('Consulting', 'ConsultingAI', 'GentleAi', 'Auto')]
    [string] $ExpectedProfile = 'Auto',
    [switch] $SkipGentleAiCheck,
    [string] $UserHome
  )

  $TargetPath = [System.IO.Path]::GetFullPath($TargetPath)
  if (-not (Test-Path -LiteralPath $TargetPath -PathType Container)) {
    throw "Proyecto no encontrado: $TargetPath"
  }

  $profile = Get-HubProjectProfileFromRoot -Root $TargetPath
  $structureIssues = Test-HubCommonStructureChecks -Root $TargetPath

  $engagementMeta = $null
  $projectMeta = $null
  $engagementPath = Join-Path $TargetPath '.consulting-engagement.json'
  $projectProfilePath = Join-Path $TargetPath '.project-profile.json'

  if (Test-Path -LiteralPath $engagementPath) {
    $engagementMeta = Get-Content -LiteralPath $engagementPath -Raw -Encoding UTF8 | ConvertFrom-Json
  }
  if (Test-Path -LiteralPath $projectProfilePath) {
    $projectMeta = Get-Content -LiteralPath $projectProfilePath -Raw -Encoding UTF8 | ConvertFrom-Json
  }

  switch ($profile) {
    'Consulting' {
      if (-not $engagementMeta) { $structureIssues += 'missing-engagement-metadata' }
      else { $structureIssues += Test-HubConsultingStructureChecks -Root $TargetPath -EngagementMeta $engagementMeta }
    }
    'ConsultingAI' {
      if (-not $engagementMeta) { $structureIssues += 'missing-engagement-metadata' }
      else { $structureIssues += Test-HubConsultingAiStructureChecks -Root $TargetPath -EngagementMeta $engagementMeta }
    }
    'GentleAi' {
      if (-not $projectMeta) { $structureIssues += 'missing-project-profile' }
      else { $structureIssues += Test-HubGentleAiStructureChecks -Root $TargetPath -ProjectMeta $projectMeta }
    }
    default { $structureIssues += 'unknown-profile' }
  }

  if ($ExpectedProfile -ne 'Auto' -and $profile -ne $ExpectedProfile) {
    $structureIssues += "profile-mismatch-expected-$ExpectedProfile-got-$profile"
  }

  $structureIssues = @($structureIssues | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
  $structureHealthy = $structureIssues.Count -eq 0

  $gentleAiResult = $null
  $gentleAiIssues = @()
  $runGentleAiCheck = (Test-HubProfileUsesGentleAi -Profile $profile) -and -not $SkipGentleAiCheck

  if ($runGentleAiCheck) {
    $gentleAiResult = Get-GentleAiProjectDiagnostic -TargetPath $TargetPath -UserHome $UserHome
    $gentleAiIssues = @($gentleAiResult.issues)
  }

  $issues = @($structureIssues)
  if ($runGentleAiCheck -and -not [bool]$gentleAiResult.healthy) {
    $issues += @($gentleAiIssues | ForEach-Object { "gentle-ai:$_" })
  }
  $issues = @($issues | Select-Object -Unique)

  return [pscustomobject]@{
    targetPath = $TargetPath
    profile = $profile
    expectedProfile = $ExpectedProfile
    structureCheck = [pscustomobject]@{
      healthy = $structureHealthy
      issues = @($structureIssues)
    }
    gentleAiCheck = if ($runGentleAiCheck) {
      [pscustomobject]@{
        skipped = $false
        healthy = [bool]$gentleAiResult.healthy
        issues = @($gentleAiIssues)
        cliPaths = @($gentleAiResult.cliPaths)
        globalGentleAi = [bool]$gentleAiResult.globalGentleAi
        workspaceGentleAi = [bool]$gentleAiResult.workspaceGentleAi
        globalEngramMcp = [bool]$gentleAiResult.globalEngramMcp
        workspaceEngramMcp = [bool]$gentleAiResult.workspaceEngramMcp
        skillCollisions = @($gentleAiResult.skillCollisions)
        alwaysApplyRules = @($gentleAiResult.alwaysApplyRules)
      }
    } elseif ((Test-HubProfileUsesGentleAi -Profile $profile) -and $SkipGentleAiCheck) {
      [pscustomobject]@{ skipped = $true; reason = 'SkipGentleAiCheck' }
    } else {
      $null
    }
    issues = @($issues)
    healthy = $issues.Count -eq 0
    remediation = @(
      'Abrí el proyecto hijo como workspace raíz en Cursor antes de probar MCP en el agente.',
      'Para correcciones Gentle AI: gentle-ai doctor y gentle-ai sync.',
      'Para MCP Archi/Backlog: rutas reales en .cursor/mcp.json (ver docs/MCP-PREREQUISITOS.md).'
    )
  }
}

function Write-HubProjectDiagnostic {
  param([Parameter(Mandatory = $true)] $Result)
  Write-Host "Proyecto: $($Result.targetPath)"
  Write-Host "Perfil detectado: $($Result.profile)"
  if ($Result.expectedProfile -ne 'Auto') { Write-Host "Perfil esperado: $($Result.expectedProfile)" }
  Write-Host ''
  Write-Host '--- Estructura del template ---' -ForegroundColor Cyan
  if ($Result.structureCheck.healthy) {
    Write-Host 'Resultado: OK' -ForegroundColor Green
  } else {
    Write-Host "Resultado: revisar $($Result.structureCheck.issues -join ', ')" -ForegroundColor Yellow
  }

  if ($Result.gentleAiCheck -and -not $Result.gentleAiCheck.skipped) {
    $gentle = $Result.gentleAiCheck
    Write-Host ''
    Write-Host '--- Gentle AI ---' -ForegroundColor Cyan
    Write-Host "Gentle AI global: $($gentle.globalGentleAi) | workspace: $($gentle.workspaceGentleAi)"
    Write-Host "Engram MCP global: $($gentle.globalEngramMcp) | workspace: $($gentle.workspaceEngramMcp)"
    Write-Host "CLI: $($gentle.cliPaths -join '; ')"
    if (@($gentle.skillCollisions).Count -gt 0) {
      Write-Host "Skills local/global repetidas: $($gentle.skillCollisions -join ', ')"
    }
    Write-Host "Reglas alwaysApply: $($gentle.alwaysApplyRules -join ', ')"
    if ($gentle.healthy) { Write-Host 'Resultado: OK' -ForegroundColor Green }
    else { Write-Host "Resultado: revisar $($gentle.issues -join ', ')" -ForegroundColor Yellow }
  } elseif ($Result.gentleAiCheck -and $Result.gentleAiCheck.skipped) {
    Write-Host ''
    Write-Host '--- Gentle AI ---' -ForegroundColor Cyan
    Write-Host 'Omitido (-SkipGentleAiCheck)' -ForegroundColor DarkYellow
  }

  Write-Host ''
  if ($Result.healthy) { Write-Host 'Resultado global: OK' -ForegroundColor Green }
  else { Write-Host "Resultado global: revisar $($Result.issues -join ', ')" -ForegroundColor Yellow }
}

function Get-ConsultingCopilotPreflightDiagnostic {
  param(
    [ValidateSet('GentleAi', 'Consulting', 'ConsultingAI', 'Full')]
    [string] $StackProfile = 'ConsultingAI',
    [string] $TargetPath,
    [string] $UserHome
  )

  $effectiveProfile = if ($StackProfile -eq 'Full') { 'ConsultingAI' } else { $StackProfile }
  $needsGentle = $effectiveProfile -in @('GentleAi', 'ConsultingAI')
  $environment = Get-GentleAiEnvironment -TargetPath $TargetPath -UserHome $UserHome

  $checks = [System.Collections.Generic.List[object]]::new()

  if ($needsGentle) {
    $checks.Add([pscustomobject]@{
      group = 'gentle-ai'
      label = 'Un único gentle-ai CLI'
      ok = $environment.CliCount -eq 1
      detail = if ($environment.CliCount -eq 0) {
        'No encontrado. Instalación estable: go install github.com/gentleman-programming/gentle-ai/v2/cmd/gentle-ai@latest'
      } elseif ($environment.CliCount -gt 1) { $environment.CliPaths -join '; ' } else { $environment.CliPath }
    })
    $checks.Add([pscustomobject]@{
      group = 'gentle-ai'
      label = 'Configuración global para Cursor'
      ok = [bool]$environment.GlobalInstalled
      detail = if ($environment.GlobalInstalled) {
        'Se reutilizará automáticamente; la opción workspace queda bloqueada.'
      } else { 'Al generar se preguntará: Global (recomendado), Proyecto o Cancelar.' }
    })
    if ($TargetPath) {
      $checks.Add([pscustomobject]@{
        group = 'gentle-ai'
        label = 'Sin Gentle AI duplicado en workspace'
        ok = -not ($environment.GlobalInstalled -and $environment.WorkspaceInstalled)
        detail = if ($environment.WorkspaceInstalled) { $environment.WorkspaceMarkerPaths -join '; ' } else { '' }
      })
      $checks.Add([pscustomobject]@{
        group = 'gentle-ai'
        label = 'Sin Engram duplicado en MCP local'
        ok = -not $environment.WorkspaceEngramConfigured
        detail = if ($environment.WorkspaceEngramConfigured) { $environment.WorkspaceMcpPath } else { '' }
      })
    }
  }

  if ($effectiveProfile -in @('Consulting', 'ConsultingAI')) {
    # 5B: node/npm/npx OK when ≥1 usable PATH hit (not Count -eq 1).
    $nodeCheck = Test-HubToolUsable -Id node -Policy ge1-usable
    $npmCheck = Test-HubToolUsable -Id npm -Policy ge1-usable
    $npxCheck = Test-HubToolUsable -Id npx -Policy ge1-usable
    $pandocCheck = Test-HubToolUsable -Id pandoc -Policy ge1-usable
    $checks.Add([pscustomobject]@{
      group = 'consulting'
      label = 'Node.js'
      ok = [bool]$nodeCheck.Ok
      detail = if ($nodeCheck.Ok) { $nodeCheck.Path } else { 'Requerido sólo si se usa Draw.io MCP (≥1 usable en PATH).' }
    })
    $checks.Add([pscustomobject]@{
      group = 'consulting'
      label = 'npm'
      ok = [bool]$npmCheck.Ok
      detail = if ($npmCheck.Ok) { $npmCheck.Path } else { 'Requerido con Draw.io / Archi MCP (≥1 usable en PATH).' }
    })
    $checks.Add([pscustomobject]@{
      group = 'consulting'
      label = 'npx'
      ok = [bool]$npxCheck.Ok
      detail = if ($npxCheck.Ok) { $npxCheck.Path } else { 'Requerido si se usa Draw.io MCP (≥1 usable en PATH).' }
    })
    $checks.Add([pscustomobject]@{
      group = 'consulting'
      label = 'Pandoc'
      ok = [bool]$pandocCheck.Ok
      detail = if ($pandocCheck.Ok) { $pandocCheck.Path } else { 'Opcional para regenerar DOCX (≥1 usable en PATH).' }
    })
    $backlogStatus = Resolve-BacklogCliStatus
    $backlogOk = $backlogStatus.Status -eq 'Ok'
    $backlogDetail = switch ($backlogStatus.Status) {
      'Ok' { "Se reutilizará: $($backlogStatus.Path)" }
      'Missing' { "Opcional salvo que actives MCP Backlog. Manual: $(Get-BacklogManualInstallHint)" }
      'WindowsOriginRejected' { $backlogStatus.Message }
      'Duplicate' { $backlogStatus.Message }
      'Invalid' { $backlogStatus.Message }
      default { $backlogStatus.Message }
    }
    $checks.Add([pscustomobject]@{
      group = 'consulting'
      label = 'Backlog CLI'
      ok = $backlogOk
      detail = $backlogDetail
    })
  }

  $failedChecks = @($checks | Where-Object { -not $_.ok })
  return [pscustomobject]@{
    stackProfile = $effectiveProfile
    targetPath = $TargetPath
    checks = @($checks)
    gentleAiCliPath = if ($environment.CliCount -eq 1) { $environment.CliPath } else { $null }
    healthy = $failedChecks.Count -eq 0
    issues = @($failedChecks | ForEach-Object { $_.label })
  }
}

function Write-ConsultingCopilotPreflightDiagnostic {
  param([Parameter(Mandatory = $true)] $Result)
  Write-Host "Consulting Copilot — diagnóstico ($($Result.stackProfile))" -ForegroundColor Cyan
  Write-Host ''

  $groups = @($Result.checks | Group-Object -Property group)
  foreach ($group in $groups) {
    $title = switch ($group.Name) {
      'gentle-ai' { '--- Gentle AI (sólo lectura) ---' }
      'consulting' { '--- Consultoría ---' }
      default { "--- $($group.Name) ---" }
    }
    Write-Host $title
    foreach ($check in $group.Group) {
      $icon = if ($check.ok) { '[ok]' } else { '[!!]' }
      Write-Host "$icon  $($check.label)" -ForegroundColor $(if ($check.ok) { 'Green' } else { 'Yellow' })
      if ($check.detail) { Write-Host "     $($check.detail)" }
    }
    if ($group.Name -eq 'gentle-ai' -and $Result.gentleAiCliPath) {
      Write-Host ''
      & $Result.gentleAiCliPath doctor 2>&1 | ForEach-Object { Write-Host $_ }
    }
    Write-Host ''
  }

  Write-Host 'Crear proyecto:' -ForegroundColor Cyan
  Write-Host '  pwsh -File ./scripts/New-ConsultingCopilotProject.ps1 -TargetPath "/ruta/absoluta/proyecto" -StackProfile ConsultingAI'
  Write-Host ''
  Write-Host 'El generador resuelve Gentle AI antes de crear archivos y no corrige instalaciones existentes automáticamente.'
}

function Get-HubPlatformInfo { Platform\Get-HubPlatformInfo @args }
function Assert-HubWindowsNativeHost { Platform\Assert-HubWindowsNativeHost @args }
function Join-HubPath {
  param([Parameter(ValueFromRemainingArguments = $true)][string[]] $Segments)
  Platform\Join-HubPath @Segments
}
function Compare-HubPath {
  param([Parameter(Mandatory = $true)][string] $Left, [Parameter(Mandatory = $true)][string] $Right)
  Platform\Compare-HubPath -Left $Left -Right $Right
}
function Resolve-HubModulePath {
  param([Parameter(Mandatory = $true)][string] $ScriptRoot, [Parameter(Mandatory = $true)][string] $ModuleName)
  Platform\Resolve-HubModulePath -ScriptRoot $ScriptRoot -ModuleName $ModuleName
}
function Test-HubPathUnderWindowsMount {
  param([Parameter(Mandatory = $true)][string] $Path)
  Platform\Test-HubPathUnderWindowsMount -Path $Path
}
function Test-HubArchiMcpPath {
  param([Parameter(Mandatory = $true)][string] $Path)
  Platform\Test-HubArchiMcpPath -Path $Path
}
function Test-HubMcpConfigurationPaths {
  param([bool] $IncludeBacklogMcp, [string] $BacklogMcpCwd, [bool] $IncludeArchiMcp, [string[]] $ArchiMcpArgs)
  Platform\Test-HubMcpConfigurationPaths -IncludeBacklogMcp:$IncludeBacklogMcp -BacklogMcpCwd $BacklogMcpCwd -IncludeArchiMcp:$IncludeArchiMcp -ArchiMcpArgs $ArchiMcpArgs
}
function Write-HubPathLocationWarnings {
  param([Parameter(Mandatory = $true)][string] $TargetPath)
  Platform\Write-HubPathLocationWarnings -TargetPath $TargetPath
}
function Get-HubCommandExecutablePaths {
  param([Parameter(Mandatory = $true)][string] $Name, [switch] $AllowWindowsExecutable)
  Platform\Get-HubCommandExecutablePaths -Name $Name -AllowWindowsExecutable:$AllowWindowsExecutable
}
function Get-HubRegistryPath {
  param([Parameter(Mandatory = $true)][string] $HubRoot)
  HubRegistry\Get-HubRegistryPath -HubRoot $HubRoot
}
function Read-HubRegistry {
  param([Parameter(Mandatory = $true)][string] $HubRoot, [string] $RegistryPath)
  HubRegistry\Read-HubRegistry -HubRoot $HubRoot -RegistryPath $RegistryPath
}
function Resolve-HubProjectPath {
  param([Parameter(Mandatory = $true)][string] $HubRoot, [Parameter(Mandatory = $true)] $Project)
  HubRegistry\Resolve-HubProjectPath -HubRoot $HubRoot -Project $Project
}
function Migrate-HubRegistryToV2 {
  param(
    [Parameter(Mandatory = $true)][string] $HubRoot,
    [string] $RegistryPath,
    [ValidateSet('Reject', 'KeepExternal')] [string] $ExternalPolicy = 'Reject',
    [switch] $DryRun,
    [switch] $NoBackup
  )
  HubRegistry\Migrate-HubRegistryToV2 -HubRoot $HubRoot -RegistryPath $RegistryPath -ExternalPolicy $ExternalPolicy -DryRun:$DryRun -NoBackup:$NoBackup
}
function Test-HubRegistryPortability {
  param([Parameter(Mandatory = $true)][string] $HubRoot, [string] $RegistryPath)
  HubRegistry\Test-HubRegistryPortability -HubRoot $HubRoot -RegistryPath $RegistryPath
}
function Add-HubRegistryProject {
  param(
    [Parameter(Mandatory = $true)][string] $HubRoot,
    [Parameter(Mandatory = $true)][hashtable] $Entry,
    [string] $RegistryPath,
    [switch] $Force
  )
  HubRegistry\Add-HubRegistryProject -HubRoot $HubRoot -Entry $Entry -RegistryPath $RegistryPath -Force:$Force
}
function Write-HubRegistry {
  param([Parameter(Mandatory = $true)][string] $RegistryPath, [Parameter(Mandatory = $true)] $Document)
  HubRegistry\Write-HubRegistry -RegistryPath $RegistryPath -Document $Document
}

Export-ModuleMember -Function @(
  'Get-ConsultingUserHome', 'Get-HubProjectsIaRoot',
  'ConvertTo-ConsultingSlug', 'Read-ConsultingPrompt', 'Read-ConsultingPromptYesNo', 'Read-ConsultingChoice',
  'Resolve-ConsultingFinalTargetPath', 'Test-ConsultingTargetPath',
  'New-ConsultingProjectStagingPath', 'Promote-ConsultingProjectStaging', 'Remove-ConsultingProjectStaging',
  'Copy-ConsultingSkeleton', 'Copy-ProjectOverlay',
  'Rename-ConsultingArchimateTemplates', 'Get-ConsultingTokenReplacements', 'Invoke-ConsultingTokenReplacement',
  'Remove-ConsultingClaudeLayer', 'Get-CommandExecutablePaths', 'Test-McpServerConfigured',
  'Get-GentleAiEnvironment', 'Get-GentleAiDualInstallDiagnosis', 'Test-GentleAiDualInstall',
  'Install-GentleAiCliStable', 'Ensure-GentleAiCli',
  'Resolve-GentleAiScopeDecision', 'Invoke-GentleAiInstall', 'Invoke-SkillRegistryRefresh',
  'Resolve-GentleAiPreflight', 'Resolve-GentleAiCliStatus', 'Get-GentleAiEngramStatus',
  'Get-HubRegistryPath', 'Read-HubRegistry', 'Resolve-HubProjectPath', 'Migrate-HubRegistryToV2',
  'Test-HubRegistryPortability', 'Add-HubRegistryProject', 'Write-HubRegistry',
  'Ensure-BacklogCli', 'Resolve-BacklogCliStatus', 'Install-BacklogCli', 'Get-BacklogManualInstallHint',
  'Get-ConsultingMcpServers', 'Write-ConsultingMcpJson', 'Write-EngagementMetadata',
  'Write-ProjectProfile', 'Write-StackProfileConfig', 'Test-ConsultingPlaceholders',
  'Build-HubProjectRequires', 'Get-HubProjectRequirements', 'Test-HubToolUsable',
  'Get-HubUsableCommandPaths', 'Sync-ProjectEnvironmentDoctorScript',
  'Get-HubProjectEnvironmentDoctorTemplatePath', 'Invoke-HubProjectEnvironmentDoctor',
  'Write-HubProjectEnvironmentDoctor', 'Get-HubProjectLocalMcpDoctorCheck',
  'Get-HubProjectEnvironmentDoctorMeta', 'Get-HubToolDoctorEsMessage',
  'Write-ProjectOnboardingPending', 'Write-ProjectGettingStarted', 'Update-ProjectGettingStartedFromMetadata', 'Copy-ProjectOnboardingLayer',
  'Invoke-OpenCursorWorkspace', 'Write-ProjectHandoffSummary',
  'Resolve-HubRootPath', 'Test-HubPathIsChildOf', 'Test-HubRootLayout', 'Get-HubMoveBackupPath',
  'Test-HubMovePreconditions', 'Replace-HubPathPrefixInText', 'Replace-HubPathLiteralInText', 'Update-HubRegistryPaths',
  'Update-HubChildMcpPaths', 'Update-HubPathReferences', 'Test-HubMoveResult',
  'New-HubMoveBackup', 'Move-HubRootDirectory', 'Invoke-HubRelocate',
  'Get-GentleAiProjectDiagnostic', 'Write-GentleAiProjectDiagnostic',
  'Get-HubProjectDiagnostic', 'Write-HubProjectDiagnostic',
  'Get-ConsultingCopilotPreflightDiagnostic', 'Write-ConsultingCopilotPreflightDiagnostic',
  'Get-HubPlatformInfo', 'Assert-HubWindowsNativeHost', 'Join-HubPath', 'Compare-HubPath', 'Resolve-HubModulePath',
  'Test-HubPathUnderWindowsMount', 'Test-HubArchiMcpPath', 'Test-HubMcpConfigurationPaths',
  'Write-HubPathLocationWarnings', 'Get-HubCommandExecutablePaths'
)
