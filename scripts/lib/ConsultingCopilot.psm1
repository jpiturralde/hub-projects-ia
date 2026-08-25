#Requires -Version 5.1
Set-StrictMode -Version Latest

$script:TextExtensions = @(
  '.md', '.mdc', '.json', '.lua', '.yml', '.yaml', '.xml', '.drawio', '.gitignore', '.ps1', '.puml', '.mdx'
)

function ConvertTo-ConsultingSlug {
  param([string] $Text)
  if ([string]::IsNullOrWhiteSpace($Text)) { return '' }
  $t = $Text.Trim().ToLowerInvariant()
  $t = $t -replace '[^a-z0-9]+', '-'
  $t = $t.Trim('-')
  if ($t.Length -gt 48) { $t = $t.Substring(0, 48).TrimEnd('-') }
  return $t
}

function Read-ConsultingPrompt {
  param([string] $Message, [string] $Default = '')
  if ($Default) {
    $r = Read-Host "$Message [$Default]"
    if ([string]::IsNullOrWhiteSpace($r)) { return $Default }
    return $r
  }
  return Read-Host $Message
}

function Read-ConsultingPromptYesNo {
  param([string] $Message, [bool] $Default = $false)
  $def = if ($Default) { 'S' } else { 'N' }
  $r = Read-Host "$Message (S/N) [$def]"
  if ([string]::IsNullOrWhiteSpace($r)) { return $Default }
  return $r.Trim().ToLowerInvariant() -in @('s', 'si', 'sÃ­', 'y', 'yes', 'true', '1')
}

function Test-ConsultingTargetPath {
  param(
    [string] $TargetPath,
    [switch] $Force
  )
  if ([string]::IsNullOrWhiteSpace($TargetPath)) {
    throw 'TargetPath es obligatorio.'
  }
  $TargetPath = $TargetPath.Trim()
  if (-not [System.IO.Path]::IsPathRooted($TargetPath)) {
    throw "TargetPath debe ser una ruta absoluta. Recibido: $TargetPath"
  }
  $destExists = Test-Path -LiteralPath $TargetPath
  if ($destExists) {
    $any = Get-ChildItem -LiteralPath $TargetPath -Force -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($any -and -not $Force) {
      throw "La carpeta destino no estÃ¡ vacÃ­a. Vaciala o usÃ¡ -Force. Ruta: $TargetPath"
    }
  } else {
    New-Item -ItemType Directory -Path $TargetPath -Force | Out-Null
  }
  return $TargetPath
}

function Copy-ConsultingSkeleton {
  param(
    [string] $SourcePath,
    [string] $TargetPath
  )
  if (-not (Test-Path -LiteralPath $SourcePath)) {
    throw "No se encuentra skeleton en: $SourcePath"
  }
  Write-Host "Copiando skeleton -> $TargetPath"
  Get-ChildItem -LiteralPath $SourcePath -Force | Copy-Item -Destination $TargetPath -Recurse -Force
}

function Copy-ProjectOverlay {
  param(
    [string] $OverlayPath,
    [string] $TargetPath
  )
  if (-not (Test-Path -LiteralPath $OverlayPath)) {
    throw "No se encuentra overlay en: $OverlayPath"
  }
  Write-Host "Aplicando overlay -> $TargetPath"
  Get-ChildItem -LiteralPath $OverlayPath -Force | Copy-Item -Destination $TargetPath -Recurse -Force
}

function Rename-ConsultingArchimateTemplates {
  param(
    [string] $TargetPath,
    [string] $ArchimateExportFilename,
    [string] $ArchimateViewsFilename
  )
  $renameMap = @(
    @{ From = '_TEMPLATE_archimate_export.xml'; To = $ArchimateExportFilename }
    @{ From = '_TEMPLATE_archimate_views.drawio'; To = $ArchimateViewsFilename }
  )
  foreach ($m in $renameMap) {
    $found = Get-ChildItem -LiteralPath $TargetPath -Recurse -Filter $m.From -File -ErrorAction SilentlyContinue
    foreach ($f in $found) {
      $newPath = Join-Path $f.DirectoryName $m.To
      if (Test-Path -LiteralPath $newPath) { continue }
      Rename-Item -LiteralPath $f.FullName -NewName $m.To
    }
  }
}

function Get-ConsultingTokenReplacements {
  param(
    [string] $ClientDisplayName,
    [string] $ClientSlug,
    [string] $InitiativeDisplayName,
    [string] $InitiativeId,
    [string] $ConsultancyName,
    [string] $PartnerTeamName,
    [string] $DocTitlePrefix,
    [string] $ArchimateExportFilename,
    [string] $ArchimateViewsFilename,
    [string] $CorporateDocxTemplateName
  )
  $partnerName = if ([string]::IsNullOrWhiteSpace($PartnerTeamName)) { '' } else { $PartnerTeamName.Trim() }
  $partnerSuffix = if ([string]::IsNullOrWhiteSpace($partnerName)) {
    ''
  } else {
    "; partner citado cuando aplique: **$partnerName**"
  }
  return [ordered]@{
    '{{CLIENT_DISPLAY_NAME}}'          = $ClientDisplayName
    '{{CLIENT_SLUG}}'                  = $ClientSlug
    '{{INITIATIVE_DISPLAY_NAME}}'      = $InitiativeDisplayName
    '{{INITIATIVE_ID}}'                = $InitiativeId
    '{{CONSULTANCY_NAME}}'             = $ConsultancyName
    '{{PARTNER_TEAM_NAME}}'            = $partnerName
    '{{PARTNER_TEAM_SUFFIX}}'          = $partnerSuffix
    '{{DOC_TITLE_PREFIX}}'             = $DocTitlePrefix
    '{{ARCHIMATE_EXPORT_FILENAME}}'    = $ArchimateExportFilename
    '{{ARCHIMATE_VIEWS_FILENAME}}'     = $ArchimateViewsFilename
    '{{CORPORATE_DOCX_TEMPLATE_NAME}}' = $CorporateDocxTemplateName
  }
}

function Invoke-ConsultingTokenReplacement {
  param(
    [string] $TargetPath,
    [hashtable] $Replacements
  )
  Get-ChildItem -LiteralPath $TargetPath -Recurse -File -Force | ForEach-Object {
    $ext = $_.Extension.ToLowerInvariant()
    $name = $_.Name
    $isText = ($name -eq '.gitignore') -or ($script:TextExtensions -contains $ext)
    if (-not $isText) { return }

    $raw = [System.IO.File]::ReadAllText($_.FullName, [System.Text.UTF8Encoding]::new($false))
    foreach ($key in $Replacements.Keys) {
      $raw = $raw.Replace($key, [string]$Replacements[$key])
    }
    [System.IO.File]::WriteAllText($_.FullName, $raw, [System.Text.UTF8Encoding]::new($false))
  }
}

function Remove-ConsultingClaudeLayer {
  param([string] $TargetPath)
  $claudeMd = Join-Path $TargetPath 'CLAUDE.md'
  if (Test-Path -LiteralPath $claudeMd) {
    Remove-Item -LiteralPath $claudeMd -Force
  }
  $claudeDir = Join-Path $TargetPath '.claude'
  if (Test-Path -LiteralPath $claudeDir) {
    Remove-Item -LiteralPath $claudeDir -Recurse -Force
  }
}

function Get-ConsultingMcpServers {
  param(
    [bool] $IncludeDrawioMcp,
    [bool] $IncludeBacklogMcp,
    [string] $BacklogMcpCwd,
    [bool] $IncludeArchiMcp,
    [string[]] $ArchiMcpArgs,
    [bool] $IncludeEngramMcp,
    [string] $EngramPath
  )
  $mcpServers = [ordered]@{}

  if ($IncludeEngramMcp) {
    if ([string]::IsNullOrWhiteSpace($EngramPath)) {
      throw 'IncludeEngramMcp requiere EngramPath.'
    }
    $mcpServers['engram'] = @{
      command = $EngramPath
      args    = @('mcp', '--tools=agent')
    }
  }
  if ($IncludeDrawioMcp) {
    $mcpServers['drawio'] = @{
      command = 'npx'
      args    = @('-y', '@drawio/mcp')
    }
  }
  if ($IncludeBacklogMcp) {
    $mcpServers['backlog'] = @{
      command = 'backlog'
      args    = @('mcp', 'start', '--cwd', $BacklogMcpCwd)
    }
  }
  if ($IncludeArchiMcp) {
    $mcpServers['archi'] = @{
      command = 'node'
      args    = @($ArchiMcpArgs)
    }
  }

  return $mcpServers
}

function Write-ConsultingMcpJson {
  param(
    [string] $TargetPath,
    [hashtable] $McpServers
  )
  $cursorDir = Join-Path $TargetPath '.cursor'
  if (-not (Test-Path -LiteralPath $cursorDir)) {
    New-Item -ItemType Directory -Path $cursorDir -Force | Out-Null
  }
  $mcpObj = @{ mcpServers = $McpServers }
  $mcpJsonPath = Join-Path $cursorDir 'mcp.json'
  $mcpJson = $mcpObj | ConvertTo-Json -Depth 10
  [System.IO.File]::WriteAllText($mcpJsonPath, $mcpJson + "`n", [System.Text.UTF8Encoding]::new($false))
}

function Merge-ConsultingMcpServers {
  param(
    [hashtable] $Primary,
    [hashtable] $Secondary
  )
  $merged = [ordered]@{}
  foreach ($key in $Primary.Keys) { $merged[$key] = $Primary[$key] }
  foreach ($key in $Secondary.Keys) { $merged[$key] = $Secondary[$key] }
  return $merged
}

function Write-EngagementMetadata {
  param(
    [string] $TargetPath,
    [string] $StackProfileValue,
    [hashtable] $Fields
  )
  $meta = [ordered]@{
    schemaVersion = 2
    stackProfile  = $StackProfileValue
    generatedAt   = (Get-Date).ToString('o')
  }
  foreach ($key in $Fields.Keys) {
    $meta[$key] = $Fields[$key]
  }
  $metaPath = Join-Path $TargetPath '.consulting-engagement.json'
  ($meta | ConvertTo-Json -Depth 5) + "`n" | Set-Content -LiteralPath $metaPath -Encoding UTF8
}

function Write-ProjectProfile {
  param(
    [string] $TargetPath,
    [string] $ProjectName
  )
  $meta = [ordered]@{
    schemaVersion = 2
    stackProfile  = 'gentle-ai-only'
    projectName   = $ProjectName
    generatedAt   = (Get-Date).ToString('o')
  }
  $metaPath = Join-Path $TargetPath '.project-profile.json'
  ($meta | ConvertTo-Json -Depth 5) + "`n" | Set-Content -LiteralPath $metaPath -Encoding UTF8
}

function Test-ConsultingPlaceholders {
  param([string] $TargetPath)
  $bad = @()
  Get-ChildItem -LiteralPath $TargetPath -Recurse -File -Force | ForEach-Object {
    $ext = $_.Extension.ToLowerInvariant()
    if ($script:TextExtensions -contains $ext -or $_.Name -eq '.gitignore') {
      $c = [System.IO.File]::ReadAllText($_.FullName)
      if ($c -match '\{\{') { $bad += $_.FullName }
    }
  }
  if ($bad.Count -gt 0) {
    throw "Quedaron placeholders sin reemplazar en:`n$($bad -join "`n")"
  }
}

function Resolve-EngramPath {
  param([string] $EngramPath)
  if (-not [string]::IsNullOrWhiteSpace($EngramPath)) {
    if (-not (Test-Path -LiteralPath $EngramPath)) {
      throw "EngramPath no encontrado: $EngramPath"
    }
    return $EngramPath
  }
  $cmd = Get-Command engram -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  throw 'No se encontrÃ³ engram en PATH. PasÃ¡ -EngramPath con la ruta absoluta al ejecutable.'
}

function Test-GentleAiWorkspaceInstalled {
  param([string] $TargetPath)
  $marker = Join-Path $TargetPath '.cursor\rules\gentle-ai.mdc'
  return Test-Path -LiteralPath $marker
}

function Invoke-GentleAiWorkspaceInstall {
  param(
    [string] $TargetPath,
    [switch] $Force
  )
  $gentle = Get-Command gentle-ai -ErrorAction SilentlyContinue
  if (-not $gentle) {
    throw 'gentle-ai no estÃ¡ en PATH. EjecutÃ¡ Install-ConsultingCopilot.ps1 -StackProfile Full (o GentleAi) primero.'
  }
  if ((Test-GentleAiWorkspaceInstalled -TargetPath $TargetPath) -and -not $Force) {
    Write-Host "Gentle AI ya instalado en workspace; omitiendo gentle-ai install."
    return
  }
  Write-Host "Instalando Gentle AI en workspace: $TargetPath"
  Push-Location $TargetPath
  try {
    & gentle-ai install --agent cursor --scope workspace --component engram,sdd,skills
    if ($LASTEXITCODE -ne 0) {
      throw "gentle-ai install fallÃ³ con cÃ³digo $LASTEXITCODE"
    }
  } finally {
    Pop-Location
  }
}

function Invoke-SkillRegistryRefresh {
  param([string] $TargetPath)
  $gentle = Get-Command gentle-ai -ErrorAction SilentlyContinue
  if (-not $gentle) {
    Write-Warning 'gentle-ai no estÃ¡ en PATH; omitiendo skill-registry refresh.'
    return
  }
  Push-Location $TargetPath
  try {
    & gentle-ai skill-registry refresh --force
  } finally {
    Pop-Location
  }
}

function Write-StackProfileConfig {
  param(
    [string] $TargetPath,
    [string] $StackProfileValue
  )
  $atlDir = Join-Path $TargetPath '.atl'
  if (-not (Test-Path -LiteralPath $atlDir)) {
    New-Item -ItemType Directory -Path $atlDir -Force | Out-Null
  }
  $exclude = @('go-testing', 'branch-pr', 'chained-pr', 'work-unit-commits')
  $cfg = [ordered]@{
    stackProfile  = $StackProfileValue
    excludeSkills = $exclude
  }
  $cfgPath = Join-Path $atlDir 'stack-profile.json'
  ($cfg | ConvertTo-Json -Depth 5) + "`n" | Set-Content -LiteralPath $cfgPath -Encoding UTF8
}

function Get-ProjectMcpServerLabels {
  param(
    [bool] $IncludeEngramMcp,
    [bool] $IncludeDrawioMcp,
    [bool] $IncludeBacklogMcp,
    [bool] $IncludeArchiMcp
  )
  $labels = @()
  if ($IncludeEngramMcp) { $labels += 'engram' }
  if ($IncludeDrawioMcp) { $labels += 'drawio' }
  if ($IncludeBacklogMcp) { $labels += 'backlog' }
  if ($IncludeArchiMcp) { $labels += 'archi' }
  return $labels
}

function Write-ProjectGettingStarted {
  param(
    [string] $TargetPath,
    [string] $StackProfile,
    [string] $Title,
    [bool] $IncludeEngramMcp = $false,
    [bool] $IncludeDrawioMcp = $false,
    [bool] $IncludeBacklogMcp = $false,
    [bool] $IncludeArchiMcp = $false,
    [string] $CorporateDocxTemplateName = 'Plantilla Ingenia - 2025.docx'
  )

  $docsDir = Join-Path $TargetPath 'docs'
  if (-not (Test-Path -LiteralPath $docsDir)) {
    New-Item -ItemType Directory -Path $docsDir -Force | Out-Null
  }

  $mcpLabels = Get-ProjectMcpServerLabels `
    -IncludeEngramMcp $IncludeEngramMcp `
    -IncludeDrawioMcp $IncludeDrawioMcp `
    -IncludeBacklogMcp $IncludeBacklogMcp `
    -IncludeArchiMcp $IncludeArchiMcp
  $mcpList = if ($mcpLabels.Count -gt 0) { ($mcpLabels -join ', ') } else { '(ninguno configurado)' }

  $profileLabel = switch ($StackProfile) {
    'GentleAi' { 'GentleAi (SDD + Engram)' }
    'Consulting' { 'Consulting (entregables y diagramas)' }
    'Full' { 'Full (CDD + SDD + Engram)' }
    default { $StackProfile }
  }

  $workflowSection = switch ($StackProfile) {
    'GentleAi' {
      @'
### 3. Inicializar SDD

1. En el chat del agente, ejecuta **`/sdd-init`**.
2. Para el primer cambio de codigo: **`/sdd-new [nombre-corto]`**.

Flujo habitual: explore -> propose -> spec -> design -> tasks -> apply -> verify -> archive.
'@
    }
    'Consulting' {
      @'
### 3. Bootstrap del encargo

1. Invoca la skill **`bootstrap-consulting-engagement`** y responde las preguntas de contexto.
2. Completa o refina **README**, **SPEC** y **ARCHITECTURE** con lo acordado con el cliente.
3. Copia la plantilla Word corporativa a `docs/templates/` (ver paso de plantilla abajo).

### 4. Trabajo de consultoria

- Reuniones -> `transcripts/` (inmutables) y derivados en `backlog/meetings/`.
- Modelo ArchiMate -> export a `docs/diagrams/`.
- Entregables al cliente -> `docs/draft/` (ver reglas en `.cursor/rules/`).
'@
    }
    'Full' {
      @'
### 3. Bootstrap del encargo

1. Invoca la skill **`bootstrap-consulting-engagement`** y responde las preguntas de contexto.
2. Completa o refina **README**, **SPEC** y **ARCHITECTURE**.

### 4. Inicializar CDD

1. Ejecuta **`/cdd-init`** para registrar contexto del proyecto en Engram.
2. Primer entregable: **`/cdd-new [nombre-corto]`** (explore -> propose -> ... -> archive).

CDD es el flujo principal para entregables al cliente. SDD (`/sdd-new`) queda disponible si el encargo incluye desarrollo.

### 5. Trabajo cotidiano

- Material cliente -> `docs/client-documentation/`, `transcripts/`.
- Borradores -> `docs/draft/`.
- Antes de exportar `.docx` al cliente: **`/cdd-verify`**.
'@
    }
  }

  $templateStep = if ($StackProfile -eq 'GentleAi') {
    ''
  } else {
    "`n`n### Plantilla Word`n`nCopia **$CorporateDocxTemplateName** en ``docs/templates/`` desde el repositorio corporativo o almacenamiento interno de Ingenia."
  }

  $engramNote = if ($IncludeEngramMcp) {
    @'

> **Engram:** el binario en tu maquina no alcanza. Las herramientas MCP (`mem_save`, `mem_search`, etc.) solo estan disponibles cuando el servidor **engram** figura activo en Cursor Settings -> MCP **despues** de abrir este repo como workspace raiz.
'@
  } else {
    ''
  }

  $metaStep = if ($StackProfile -eq 'GentleAi') {
    'Revisa ``.project-profile.json``.'
  } else {
    'Revisa ``.consulting-engagement.json`` (cliente, iniciativa, MCP toggles, ``stackProfile``).'
  }

  $content = @"
# Primeros pasos - $Title

> Checklist generada al crear el proyecto. Perfil: **$profileLabel**.

## Paso 0 - Abri este repo como workspace (obligatorio)

Los MCP del proyecto (**$mcpList**) se leen desde ``.cursor/mcp.json`` de **esta carpeta**. Si seguis con el hub ``ingenia-hub-ia`` como workspace raiz, Engram y el resto **no** estaran disponibles en el agente aunque el CLI funcione en terminal.$engramNote

1. **File -> Open Folder** -> selecciona la raiz de **este** repositorio:
   ``$TargetPath``
2. **Developer: Reload Window** si los MCP no aparecen al abrir.
3. **Cursor Settings -> MCP** - verifica que los servidores esperados (**$mcpList**) figuren en verde.
4. Si **archi** o **backlog** usan rutas placeholder, edita ``.cursor/mcp.json`` con rutas absolutas reales (ver [MCP-PREREQUISITOS.md](MCP-PREREQUISITOS.md)).
5. En el chat del agente, ejecuta **`/onboarding`** para un recorrido guiado (workspace, MCP y proximos pasos).

## Paso 1 - Verificar prerequisitos

| Herramienta | Para que |
|-------------|----------|
| Node.js + npx | MCP Draw.io |
| ``engram`` CLI | Memoria persistente (Full / GentleAi) |
| ``backlog`` CLI | MCP Backlog (si esta configurado) |
| Pandoc | Regenerar `.docx` de entregables |
| Archi + archi-server | MCP Archi (si esta configurado) |

Detalle por SO: [MCP-PREREQUISITOS.md](MCP-PREREQUISITOS.md).

## Paso 2 - Confirmar metadata del encargo

$metaStep

$workflowSection
$templateStep

## Referencia rapida

| Documento | Uso |
|-----------|-----|
| [README.md](../README.md) | Indice del repo |
| [SPEC.md](../SPEC.md) | Alcance y objetivos |
| [ARCHITECTURE.md](../ARCHITECTURE.md) | Contexto tecnico |
| ``.cursor/skills/`` | Skills del agente (bootstrap, entregables, CDD/SDD) |

## Seguis en el hub?

Si creaste este proyecto desde **ingenia-hub-ia**, el trabajo del encargo (SPEC, entregables, CDD) se hace **aqui**, no en el repo padre. Volve al hub solo para mantener el template o generar otros proyectos.
"@

  $path = Join-Path $docsDir 'GETTING-STARTED.md'
  Set-Content -LiteralPath $path -Value ($content.TrimEnd() + "`n") -Encoding UTF8
  Write-ProjectOnboardingPending -TargetPath $TargetPath -StackProfile $StackProfile
  return $path
}

function Write-ProjectOnboardingPending {
  param(
    [string] $TargetPath,
    [string] $StackProfile
  )
  $atlDir = Join-Path $TargetPath '.atl'
  if (-not (Test-Path -LiteralPath $atlDir)) {
    New-Item -ItemType Directory -Path $atlDir -Force | Out-Null
  }
  $pending = [ordered]@{
    pending            = $true
    stackProfile       = $StackProfile
    generatedAt        = (Get-Date).ToString('o')
    gettingStartedPath = 'docs/GETTING-STARTED.md'
    hint               = 'Run /onboarding or read docs/GETTING-STARTED.md. Open this folder as Cursor workspace root for MCP.'
  }
  $pendingPath = Join-Path $atlDir 'onboarding-pending.json'
  ($pending | ConvertTo-Json -Depth 5) + "`n" | Set-Content -LiteralPath $pendingPath -Encoding UTF8
}

function Copy-ProjectOnboardingLayer {
  param(
    [string] $SourceRoot,
    [string] $TargetPath
  )
  $ruleSrc = Join-Path $SourceRoot 'skeleton\.cursor\rules\onboarding.mdc'
  $skillSrc = Join-Path $SourceRoot 'skeleton\.cursor\skills\onboarding'
  if (-not (Test-Path -LiteralPath $ruleSrc)) {
    Write-Warning "No se encuentra onboarding rule en: $ruleSrc"
    return
  }
  $ruleDestDir = Join-Path $TargetPath '.cursor\rules'
  $skillDestDir = Join-Path $TargetPath '.cursor\skills\onboarding'
  if (-not (Test-Path -LiteralPath $ruleDestDir)) {
    New-Item -ItemType Directory -Path $ruleDestDir -Force | Out-Null
  }
  Copy-Item -LiteralPath $ruleSrc -Destination $ruleDestDir -Force
  if (Test-Path -LiteralPath $skillSrc) {
    if (Test-Path -LiteralPath $skillDestDir) {
      Remove-Item -LiteralPath $skillDestDir -Recurse -Force
    }
    Copy-Item -LiteralPath $skillSrc -Destination (Join-Path $TargetPath '.cursor\skills') -Recurse -Force
  }
}

function Invoke-OpenCursorWorkspace {
  param([string] $TargetPath)
  if (-not (Test-Path -LiteralPath $TargetPath)) {
    Write-Warning "Ruta no encontrada: $TargetPath"
    return $false
  }
  $cursor = Get-Command cursor -ErrorAction SilentlyContinue
  if (-not $cursor) {
    Write-Warning 'CLI cursor no encontrado en PATH. Abri manualmente: File -> Open Folder.'
    Write-Host "  $TargetPath"
    return $false
  }
  Write-Host "Abriendo Cursor en el proyecto hijo..."
  & $cursor.Source $TargetPath
  if ($LASTEXITCODE -ne 0) {
    Write-Warning "cursor CLI retorno codigo $LASTEXITCODE. Abri manualmente la carpeta."
    return $false
  }
  return $true
}

function Write-ProjectHandoffSummary {
  param(
    [string] $TargetPath,
    [string] $StackProfile,
    [string] $GettingStartedPath
  )

  Write-Host ''
  Write-Host '=== Proyecto creado - como continuar ===' -ForegroundColor Green
  Write-Host ''
  Write-Host 'IMPORTANTE: abri el proyecto hijo como workspace raiz.' -ForegroundColor Yellow
  Write-Host "  $TargetPath"
  Write-Host ''
  Write-Host 'Checklist completa:'
  Write-Host "  $GettingStartedPath"
  Write-Host ''
  Write-Host 'Resumen:'
  Write-Host '  1. Open Folder -> ruta de arriba (no el hub padre)'
  Write-Host '  2. Settings -> MCP -> verificar engram y demas servidores en verde'
  switch ($StackProfile) {
    'GentleAi' {
      Write-Host '  3. /onboarding -> workspace raiz + MCP -> /sdd-init -> /sdd-new [cambio]'
    }
    'Consulting' {
      Write-Host '  3. /onboarding -> workspace raiz + MCP'
      Write-Host '  4. skill bootstrap-consulting-engagement -> completar SPEC'
      Write-Host '  5. Copiar plantilla Word a docs/templates/'
    }
    'Full' {
      Write-Host '  3. /onboarding -> workspace raiz + MCP'
      Write-Host '  4. skill bootstrap-consulting-engagement -> completar SPEC'
      Write-Host '  5. /cdd-init -> luego /cdd-new [entregable]'
      Write-Host '  6. Copiar plantilla Word a docs/templates/'
    }
  }
  Write-Host ''
}

Export-ModuleMember -Function @(
  'ConvertTo-ConsultingSlug',
  'Read-ConsultingPrompt',
  'Read-ConsultingPromptYesNo',
  'Test-ConsultingTargetPath',
  'Copy-ConsultingSkeleton',
  'Copy-ProjectOverlay',
  'Rename-ConsultingArchimateTemplates',
  'Get-ConsultingTokenReplacements',
  'Invoke-ConsultingTokenReplacement',
  'Remove-ConsultingClaudeLayer',
  'Get-ConsultingMcpServers',
  'Write-ConsultingMcpJson',
  'Merge-ConsultingMcpServers',
  'Write-EngagementMetadata',
  'Write-ProjectProfile',
  'Test-ConsultingPlaceholders',
  'Resolve-EngramPath',
  'Test-GentleAiWorkspaceInstalled',
  'Invoke-GentleAiWorkspaceInstall',
  'Invoke-SkillRegistryRefresh',
  'Write-StackProfileConfig',
  'Get-ProjectMcpServerLabels',
  'Write-ProjectGettingStarted',
  'Write-ProjectOnboardingPending',
  'Copy-ProjectOnboardingLayer',
  'Invoke-OpenCursorWorkspace',
  'Write-ProjectHandoffSummary'
)
