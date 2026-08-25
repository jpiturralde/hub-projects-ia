# Armar zip de config Cursor (comparar cualquier proyecto)

Receta idéntica en cada repo. El zip resta la capa de máquina y deja el delta de contexto del agente (reglas, skills, agents, MCP, canónicos, extras de consultoría).

Copiá este archivo a `backlog/interno/export-cursor-config-zip.md` en el otro proyecto y repetí los mismos pasos. Si el árbol interno del zip no coincide, la comparación no vale.

**Contrato v2.1** (2026-08-24). Igual que v2 (2026-08-18: agents de proyecto, CLAUDE.md, commands/hooks, markdown hermano de skills, capa `03-extra/`) más `PROJECT-CONTEXT.md` en `01-proyecto/`. Un zip v1/v2 se compara con v2.1 re-exportando el otro proyecto con este archivo, o ignorando paths que el zip viejo no copiaba.

## Quick path

1. Pegá este `.md` en el otro repo (misma ruta relativa).
2. En cada proyecto: correr el script (staging en `%TEMP%`). Copia `01-proyecto/`, `02-usuario/` y `03-extra/`.
3. Pegar User Rules en el stub. Re-zippear si hace falta.
4. Comparar: `02-usuario/` casi igual (misma PC, mismo día). El análisis es `01` vs `01`; `03` vs `03` si ambos tienen más que `CAPA.md`.

Nombre del zip: `cursor-config-<slug>-<yyyy-MM-dd>.zip`
Slug = nombre de la carpeta raíz del repo.

## Contrato del árbol (obligatorio)

Raíz dentro del zip. Las tres capas se crean siempre. Si un archivo no existe en el repo, no se inventa: se anota en el `CAPA.md` de esa capa.

```
cursor-config-<slug>/
├── README.md                     ← slug, fecha, máquina, nota de capas
├── INCLUIR.md                    ← copia de este archivo
├── 01-proyecto/                  ← ESTE REPO (el delta Cursor)
│   ├── CAPA.md
│   ├── README.md                 ← si existe
│   ├── SPECS.md / SPEC.md        ← el que exista (o ambos)
│   ├── ARCHITECTURE.md           ← si existe
│   ├── PROJECT-CONTEXT.md        ← si existe (contexto inicial del encargo)
│   ├── CLAUDE.md                 ← si existe (instrucciones de proyecto)
│   ├── AGENTS.md                 ← si existe
│   ├── .cursorignore             ← si existe
│   └── .cursor/
│       ├── mcp.json              ← si existe; redactar secretos
│       ├── mcp.json.example      ← si existe
│       ├── CURSOR-USAGE.md       ← si existe
│       ├── hooks.json            ← si existe
│       ├── rules/*.mdc
│       ├── agents/*.md           ← agents de ESTE repo (catálogo Task)
│       ├── commands/             ← si existe
│       └── skills/               ← SKILL.md + *.md hermanos + references/*.md
├── 02-usuario/                   ← ESTA MÁQUINA (baseline; restar al comparar)
│   ├── CAPA.md
│   ├── mcp.json                  ← ~/.cursor/mcp.json
│   ├── rules/
│   │   ├── settings-user-rules.md
│   │   └── *.mdc                 ← ~/.cursor/rules/
│   ├── skills/
│   │   ├── cursor-user/          ← ~/.cursor/skills
│   │   ├── cursor-product/       ← ~/.cursor/skills-cursor
│   │   ├── claude/               ← ~/.claude/skills
│   │   └── codex/                ← ~/.codex/skills
│   └── agents/                   ← ~/.cursor/agents
└── 03-extra/                     ← perfil consultoría / Cowork (puede ser solo CAPA.md)
    ├── CAPA.md
    ├── .consulting-engagement.json
    ├── .workbench-metadata.json
    ├── .atl/
    │   ├── stack-profile.json
    │   └── skill-registry.md
    └── .claude/rules/
```

`01-proyecto/` cambia entre repos. `02-usuario/` no debería cambiar si exportás los dos zips el mismo día en la misma cuenta. `03-extra/` cambia si un repo es consulting-copilot y el otro no.

## Qué copiar

### 01-proyecto/ — este worktree

| Origen en el repo | Destino en el zip | Si no existe |
|---|---|---|
| `.cursor/rules/*.mdc` | `01-proyecto/.cursor/rules/` | Anotar en CAPA.md |
| `.cursor/agents/*.md` | `01-proyecto/.cursor/agents/` | Anotar (v1 no copiaba esto) |
| `.cursor/skills/**/SKILL.md` | misma ruta relativa | OK vacío |
| `.cursor/skills/**/*.md` en la carpeta del skill | misma ruta relativa | OK |
| `.cursor/skills/**/references/*.md` | misma ruta relativa | OK |
| `.cursor/mcp.json` | `01-proyecto/.cursor/mcp.json` | OK |
| `.cursor/mcp.json.example` | misma ruta relativa | OK |
| `.cursor/CURSOR-USAGE.md` | misma ruta relativa | OK |
| `.cursor/hooks.json` | misma ruta relativa | OK |
| `.cursor/commands/` | `01-proyecto/.cursor/commands/` | OK |
| `.cursorignore` | `01-proyecto/.cursorignore` | Anotar: sin ignore el índice ve más repo |
| `ARCHITECTURE.md` | `01-proyecto/ARCHITECTURE.md` | Anotar en CAPA.md |
| `PROJECT-CONTEXT.md` | `01-proyecto/PROJECT-CONTEXT.md` | Anotar (v2 no lo copiaba) |
| `README.md` | `01-proyecto/README.md` | OK |
| `SPECS.md` y/o `SPEC.md` | mismo nombre | OK |
| `CLAUDE.md` | `01-proyecto/CLAUDE.md` | OK (si existe, suele inyectarse) |
| `AGENTS.md` | `01-proyecto/AGENTS.md` | OK |

De cada skill: markdown de contrato — `SKILL.md`, otros `*.md` en la misma carpeta del skill (p. ej. `_shared/cdd-phase-common.md`, `strict-tdd.md`) y `references/*.md`. Sin `assets/`, `scripts/`, PNG, CSS, JS, HTML, `.py`, `.json` de templates.

### 02-usuario/ — esta PC

| Origen real | Destino en el zip |
|---|---|
| Cursor Settings → Rules → User Rules | `02-usuario/rules/settings-user-rules.md` |
| `%USERPROFILE%\.cursor\rules\*.mdc` | `02-usuario/rules/` |
| `%USERPROFILE%\.cursor\mcp.json` | `02-usuario/mcp.json` |
| `%USERPROFILE%\.cursor\skills\**` (markdown de contrato) | `02-usuario/skills/cursor-user/` |
| `%USERPROFILE%\.cursor\skills-cursor\**` | `02-usuario/skills/cursor-product/` |
| `%USERPROFILE%\.claude\skills\**` | `02-usuario/skills/claude/` |
| `%USERPROFILE%\.codex\skills\**` | `02-usuario/skills/codex/` |
| `%USERPROFILE%\.cursor\agents\*.md` | `02-usuario/agents/` |

Claude y Codex van: Cursor los lista en el catálogo de skills (cuentan descriptions).

### 03-extra/ — consultoría / Cowork

| Origen en el repo | Destino en el zip | Si no existe |
|---|---|---|
| `.consulting-engagement.json` | `03-extra/.consulting-engagement.json` | Anotar (repo no es consulting-copilot) |
| `.workbench-metadata.json` | `03-extra/.workbench-metadata.json` | OK |
| `.atl/stack-profile.json` | `03-extra/.atl/stack-profile.json` | Anotar |
| `.atl/skill-registry.md` | `03-extra/.atl/skill-registry.md` | Anotar |
| `.claude/rules/*` | `03-extra/.claude/rules/` | OK (solo Cowork/Claude Code) |

No copiar `.atl/.skill-registry.cache.json` ni `.atl/onboarding-pending.json` (cache / estado local).

## Qué no copiar

| Fuera | Motivo |
|---|---|
| `docs/`, `backlog/`, `transcripts/` / `transcripciones/`, GAPS, diagramas, `.docx` | Encargo, no config del agente |
| PNG / scripts / CSS / HTML / `.py` / templates JSON de skills | No entran al catálogo del prompt |
| `%USERPROFILE%\.cursor\projects\` | Caché MCP y estado de sesión |
| `extensions/`, `plugins/`, `ai-tracking/` | Runtime del IDE |
| `ide_state.json`, `argv.json` | Estado local |
| `.githooks/`, `.vscode/`, `.gitignore` | No es contexto del agente |
| `.git/` | Repo, no config |
| Tokens / API keys en `mcp.json` | Reemplazar el valor por `REDACTED` |

Si aparece otro archivo de contexto (p. ej. `SPEC-PREV-*.md`) y hace falta para tokens, copialo a `03-extra/` y anotalo en `03-extra/CAPA.md`. No lo metas en `01-proyecto/` salvo que actualices este contrato en todos los zips del mismo lote.

## Pasos (PowerShell)

Correr desde la raíz del repo. Staging en TEMP: no ensucia git.

```powershell
$ErrorActionPreference = 'Stop'
$repo = (git rev-parse --show-toplevel)
Set-Location $repo
$slug = Split-Path -Leaf $repo
$date = Get-Date -Format 'yyyy-MM-dd'
$stage = Join-Path $env:TEMP "cursor-config-export\$slug"
$root = Join-Path $stage "cursor-config-$slug"
if (Test-Path $stage) { Remove-Item -Recurse -Force $stage }
New-Item -ItemType Directory -Force -Path $root | Out-Null

function Copy-IfExists($src, $dstDir, $name) {
  if (Test-Path $src) {
    New-Item -ItemType Directory -Force -Path $dstDir | Out-Null
    Copy-Item $src (Join-Path $dstDir $name)
    return $true
  }
  return $false
}

function Copy-SkillMarkdowns([string]$src, [string]$dst) {
  if (-not (Test-Path $src)) { return }
  Get-ChildItem $src -Recurse -Filter 'SKILL.md' -File -ErrorAction SilentlyContinue | ForEach-Object {
    $rel = $_.DirectoryName.Substring((Resolve-Path $src).Path.Length).TrimStart('\')
    $targetDir = Join-Path $dst $rel
    New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
    Get-ChildItem $_.DirectoryName -Filter '*.md' -File -ErrorAction SilentlyContinue |
      ForEach-Object { Copy-Item $_.FullName $targetDir }
    $refDir = Join-Path $_.DirectoryName 'references'
    if (Test-Path $refDir) {
      $refDst = Join-Path $targetDir 'references'
      New-Item -ItemType Directory -Force -Path $refDst | Out-Null
      Get-ChildItem $refDir -Filter '*.md' -File -ErrorAction SilentlyContinue |
        ForEach-Object { Copy-Item $_.FullName $refDst }
    }
  }
}

function Get-AlwaysApplyNames([string]$rulesDir) {
  if (-not (Test-Path $rulesDir)) { return @() }
  Get-ChildItem $rulesDir -Filter '*.mdc' -File -ErrorAction SilentlyContinue | Where-Object {
    (Get-Content $_.FullName -Raw) -match '(?m)^alwaysApply:\s*true'
  } | ForEach-Object { $_.Name }
}

function Get-McpServerNames([string]$mcpPath) {
  if (-not (Test-Path $mcpPath)) { return @() }
  try {
    $json = Get-Content $mcpPath -Raw | ConvertFrom-Json
    if ($json.mcpServers) { return @($json.mcpServers.PSObject.Properties.Name) }
  } catch { }
  return @()
}

function Get-SkillFolderNames([string]$skillsDir) {
  if (-not (Test-Path $skillsDir)) { return @() }
  Get-ChildItem $skillsDir -Directory -ErrorAction SilentlyContinue | ForEach-Object { $_.Name }
}

function Test-Mark($path) { if (Test-Path $path) { 'sí' } else { 'no' } }

# --- 01-proyecto ---
$p = Join-Path $root '01-proyecto'
New-Item -ItemType Directory -Force -Path $p | Out-Null
Copy-IfExists (Join-Path $repo 'README.md') $p 'README.md' | Out-Null
Copy-IfExists (Join-Path $repo 'SPECS.md') $p 'SPECS.md' | Out-Null
Copy-IfExists (Join-Path $repo 'SPEC.md') $p 'SPEC.md' | Out-Null
Copy-IfExists (Join-Path $repo 'ARCHITECTURE.md') $p 'ARCHITECTURE.md' | Out-Null
Copy-IfExists (Join-Path $repo 'PROJECT-CONTEXT.md') $p 'PROJECT-CONTEXT.md' | Out-Null
Copy-IfExists (Join-Path $repo 'CLAUDE.md') $p 'CLAUDE.md' | Out-Null
Copy-IfExists (Join-Path $repo 'AGENTS.md') $p 'AGENTS.md' | Out-Null
Copy-IfExists (Join-Path $repo '.cursorignore') $p '.cursorignore' | Out-Null
$pCursor = Join-Path $p '.cursor'
Copy-IfExists (Join-Path $repo '.cursor\mcp.json') $pCursor 'mcp.json' | Out-Null
Copy-IfExists (Join-Path $repo '.cursor\mcp.json.example') $pCursor 'mcp.json.example' | Out-Null
Copy-IfExists (Join-Path $repo '.cursor\CURSOR-USAGE.md') $pCursor 'CURSOR-USAGE.md' | Out-Null
Copy-IfExists (Join-Path $repo '.cursor\hooks.json') $pCursor 'hooks.json' | Out-Null
$rulesSrc = Join-Path $repo '.cursor\rules'
if (Test-Path $rulesSrc) {
  $rulesDst = Join-Path $pCursor 'rules'
  New-Item -ItemType Directory -Force -Path $rulesDst | Out-Null
  Copy-Item (Join-Path $rulesSrc '*.mdc') $rulesDst -ErrorAction SilentlyContinue
}
$projAgentsSrc = Join-Path $repo '.cursor\agents'
if (Test-Path $projAgentsSrc) {
  $projAgentsDst = Join-Path $pCursor 'agents'
  New-Item -ItemType Directory -Force -Path $projAgentsDst | Out-Null
  Copy-Item (Join-Path $projAgentsSrc '*.md') $projAgentsDst -ErrorAction SilentlyContinue
}
$cmdSrc = Join-Path $repo '.cursor\commands'
if (Test-Path $cmdSrc) {
  Copy-Item $cmdSrc (Join-Path $pCursor 'commands') -Recurse -Force
}
Copy-SkillMarkdowns (Join-Path $repo '.cursor\skills') (Join-Path $pCursor 'skills')

# --- 02-usuario ---
$u = Join-Path $root '02-usuario'
$userProfile = $env:USERPROFILE
New-Item -ItemType Directory -Force -Path $u | Out-Null
Copy-IfExists (Join-Path $userProfile '.cursor\mcp.json') $u 'mcp.json' | Out-Null
$userRulesDir = Join-Path $userProfile '.cursor\rules'
if (Test-Path $userRulesDir) {
  $ur = Join-Path $u 'rules'
  New-Item -ItemType Directory -Force -Path $ur | Out-Null
  Copy-Item (Join-Path $userRulesDir '*.mdc') $ur -ErrorAction SilentlyContinue
}
Copy-SkillMarkdowns (Join-Path $userProfile '.cursor\skills') (Join-Path $u 'skills\cursor-user')
Copy-SkillMarkdowns (Join-Path $userProfile '.cursor\skills-cursor') (Join-Path $u 'skills\cursor-product')
Copy-SkillMarkdowns (Join-Path $userProfile '.claude\skills') (Join-Path $u 'skills\claude')
Copy-SkillMarkdowns (Join-Path $userProfile '.codex\skills') (Join-Path $u 'skills\codex')
$userAgentsSrc = Join-Path $userProfile '.cursor\agents'
if (Test-Path $userAgentsSrc) {
  $userAgentsDst = Join-Path $u 'agents'
  New-Item -ItemType Directory -Force -Path $userAgentsDst | Out-Null
  Copy-Item (Join-Path $userAgentsSrc '*.md') $userAgentsDst -ErrorAction SilentlyContinue
}

$settingsStub = Join-Path $u 'rules\settings-user-rules.md'
New-Item -ItemType Directory -Force -Path (Split-Path $settingsStub) | Out-Null
if (-not (Test-Path $settingsStub)) {
  @"
# User Rules (Cursor Settings)

Fuente: Cursor Settings → Rules → User Rules.
Máquina: $env:COMPUTERNAME
Fecha: $date
Repo: $slug

Pegá acá el texto completo de User Rules (no hay archivo plano en disco).
"@ | Set-Content -Encoding utf8 $settingsStub
}

# --- 03-extra ---
$e = Join-Path $root '03-extra'
New-Item -ItemType Directory -Force -Path $e | Out-Null
Copy-IfExists (Join-Path $repo '.consulting-engagement.json') $e '.consulting-engagement.json' | Out-Null
Copy-IfExists (Join-Path $repo '.workbench-metadata.json') $e '.workbench-metadata.json' | Out-Null
$atlDst = Join-Path $e '.atl'
Copy-IfExists (Join-Path $repo '.atl\stack-profile.json') $atlDst 'stack-profile.json' | Out-Null
Copy-IfExists (Join-Path $repo '.atl\skill-registry.md') $atlDst 'skill-registry.md' | Out-Null
$claudeRulesSrc = Join-Path $repo '.claude\rules'
if (Test-Path $claudeRulesSrc) {
  $claudeRulesDst = Join-Path $e '.claude\rules'
  New-Item -ItemType Directory -Force -Path $claudeRulesDst | Out-Null
  Get-ChildItem $claudeRulesSrc -File -ErrorAction SilentlyContinue |
    ForEach-Object { Copy-Item $_.FullName $claudeRulesDst }
}

# Redactar secretos obvios en mcp.json
Get-ChildItem $root -Recurse -Filter 'mcp.json' | ForEach-Object {
  $t = Get-Content $_.FullName -Raw
  $t = [regex]::Replace($t, '(?i)("(?:api[_-]?key|token|secret|password)"\s*:\s*")[^"]*"', '$1REDACTED"')
  Set-Content -Encoding utf8 $_.FullName $t
}

# Inventarios CAPA.md
$always = Get-AlwaysApplyNames (Join-Path $pCursor 'rules')
$ruleFiles = @()
if (Test-Path (Join-Path $pCursor 'rules')) {
  $ruleFiles = @(Get-ChildItem (Join-Path $pCursor 'rules') -Filter '*.mdc' -File | ForEach-Object { $_.Name })
}
$skillNames = Get-SkillFolderNames (Join-Path $pCursor 'skills')
$projAgentNames = @()
if (Test-Path (Join-Path $pCursor 'agents')) {
  $projAgentNames = @(Get-ChildItem (Join-Path $pCursor 'agents') -Filter '*.md' -File | ForEach-Object { $_.BaseName })
}
$mcpProj = Get-McpServerNames (Join-Path $pCursor 'mcp.json')

@"
# Capa 01 — proyecto

Repo: $slug
Fecha: $date
Contrato: v2.1
Esta carpeta es el **delta** (cambia entre proyectos).

- Rules: $($ruleFiles.Count) archivos .mdc
- alwaysApply true: $(if ($always) { ($always -join ', ') } else { '(ninguna)' })
- Agents de proyecto: $(if ($projAgentNames) { ($projAgentNames -join ', ') } else { '(ninguno)' })
- Skills de proyecto: $(if ($skillNames) { ($skillNames -join ', ') } else { '(ninguna)' })
- MCP proyecto: $(if ($mcpProj) { ($mcpProj -join ', ') } else { '(ninguno)' })
- README.md: $(Test-Mark (Join-Path $p 'README.md'))
- SPEC.md: $(Test-Mark (Join-Path $p 'SPEC.md'))
- SPECS.md: $(Test-Mark (Join-Path $p 'SPECS.md'))
- ARCHITECTURE.md: $(Test-Mark (Join-Path $p 'ARCHITECTURE.md'))
- PROJECT-CONTEXT.md: $(Test-Mark (Join-Path $p 'PROJECT-CONTEXT.md'))
- CLAUDE.md: $(Test-Mark (Join-Path $p 'CLAUDE.md'))
- AGENTS.md: $(Test-Mark (Join-Path $p 'AGENTS.md'))
- .cursorignore: $(Test-Mark (Join-Path $p '.cursorignore'))
- CURSOR-USAGE.md: $(Test-Mark (Join-Path $pCursor 'CURSOR-USAGE.md'))
- hooks.json: $(Test-Mark (Join-Path $pCursor 'hooks.json'))
- commands/: $(Test-Mark (Join-Path $pCursor 'commands'))
"@ | Set-Content -Encoding utf8 (Join-Path $p 'CAPA.md')

$userSkillCounts = foreach ($n in @('cursor-user','cursor-product','claude','codex')) {
  $d = Join-Path $u "skills\$n"
  $c = @(Get-SkillFolderNames $d).Count
  "${n}: $c"
}
$userAgentCount = 0
if (Test-Path (Join-Path $u 'agents')) {
  $userAgentCount = @(Get-ChildItem (Join-Path $u 'agents') -Filter '*.md' -File -ErrorAction SilentlyContinue).Count
}
$mcpUser = Get-McpServerNames (Join-Path $u 'mcp.json')

@"
# Capa 02 — usuario

Máquina: $env:COMPUTERNAME
Cuenta Cursor: esta PC
Fecha: $date
Contrato: v2.1
Esta carpeta es el **baseline**. Al comparar dos zips del mismo día en la misma PC, debería coincidir.

Si no coincide: se exportó en otra máquina o cambió la config global entre un zip y el otro.

- User Rules: stub en rules/settings-user-rules.md (pegar texto a mano si sigue el placeholder)
- MCP usuario: $(if ($mcpUser) { ($mcpUser -join ', ') } else { '(ninguno)' })
- Skills: $($userSkillCounts -join ' | ')
- Agents usuario: $userAgentCount
"@ | Set-Content -Encoding utf8 (Join-Path $u 'CAPA.md')

$stackProfile = ''
$stackPath = Join-Path $atlDst 'stack-profile.json'
if (Test-Path $stackPath) {
  try { $stackProfile = (Get-Content $stackPath -Raw | ConvertFrom-Json).stackProfile } catch { }
}

@"
# Capa 03 — extra (consultoría / Cowork)

Repo: $slug
Fecha: $date
Contrato: v2.1
Esta carpeta es **opcional en contenido**. Si el repo no es consulting-copilot, puede quedar solo este CAPA.md.

- .consulting-engagement.json: $(Test-Mark (Join-Path $e '.consulting-engagement.json'))
- .workbench-metadata.json: $(Test-Mark (Join-Path $e '.workbench-metadata.json'))
- stack-profile: $(if ($stackProfile) { $stackProfile } else { Test-Mark $stackPath })
- skill-registry.md: $(Test-Mark (Join-Path $atlDst 'skill-registry.md'))
- .claude/rules/: $(Test-Mark (Join-Path $e '.claude\rules'))
"@ | Set-Content -Encoding utf8 (Join-Path $e 'CAPA.md')

@"
# cursor-config-$slug

Fecha: $date
Máquina: $env:COMPUTERNAME
Contrato: v2.1

- 01-proyecto = delta del repo (comparar entre proyectos)
- 02-usuario = baseline de esta PC (debería coincidir el mismo día)
- 03-extra = consulting-copilot / Cowork (puede ser solo CAPA.md)
"@ | Set-Content -Encoding utf8 (Join-Path $root 'README.md')

$guide = Join-Path $repo 'backlog\interno\export-cursor-config-zip.md'
if (Test-Path $guide) {
  Copy-Item $guide (Join-Path $root 'INCLUIR.md')
} else {
  Set-Content -Encoding utf8 (Join-Path $root 'INCLUIR.md') "Guía no encontrada en backlog/interno/export-cursor-config-zip.md"
}

$zip = Join-Path ([Environment]::GetFolderPath('Desktop')) "cursor-config-$slug-$date.zip"
if (Test-Path $zip) { Remove-Item $zip }
Compress-Archive -Path $root -DestinationPath $zip
Write-Host "OK $zip"
Write-Host "Staging $root"
Write-Host "Falta: pegar User Rules en 02-usuario/rules/settings-user-rules.md y re-zippear si hace falta."
```

## Después del script

1. Cursor → Settings → Rules → User Rules → copiar todo a `02-usuario/rules/settings-user-rules.md` (en el staging, o reabrir el zip).
2. Revisar los `CAPA.md` generados (el script ya lista presentes/ausentes).
3. Si editaste el staging: borrar el zip y `Compress-Archive` de nuevo.

## Cómo comparar los dos zips

1. Descomprimir ambos en carpetas hermanas.
2. Diff de `02-usuario/`: si hay diferencia relevante, no restes a ciegas (otra PC o User Rules distintas).
3. Diff de `01-proyecto/`:
   - `.cursor/rules/` — always-on vs glob
   - `.cursor/agents/` — catálogo Task (costo fijo aunque no se lancen)
   - `.cursor/skills/` — duplicados vs capa usuario; `excludeSkills` en 03 no borra el catálogo de Cursor
   - `mcp.json`, `.cursorignore`
   - `CLAUDE.md` (si existe, suele ser always-on) vs `PROJECT-CONTEXT.md` / `ARCHITECTURE.md` / README / SPEC (on-demand salvo `@` desde CLAUDE.md)
4. Diff de `03-extra/`: perfil `stackProfile`, registry, reglas Cowork. Si un zip solo tiene `CAPA.md`, el otro es consulting y este no.

Tokens: mirá primero always-on (reglas `alwaysApply: true` + User Rules + `CLAUDE.md` + `gentle-ai.mdc` aunque no sea always-on) y el catálogo de descriptions de skills (proyecto + cursor-user + cursor-product + claude + codex) y de agents (proyecto + usuario).

Zip v1 / v2 (sin `PROJECT-CONTEXT.md` o sin agents de proyecto): no lo diffees crudo contra v2.1. Re-exportá ese repo con este archivo.

## Prompt para pegar en el otro proyecto

```
Leé backlog/interno/export-cursor-config-zip.md (o el .md que te acabo de pegar).
Armá el zip con el árbol v2.1: 01-proyecto / 02-usuario / 03-extra (incluye PROJECT-CONTEXT.md si existe), sin docs de negocio ni binarios.
Staging en %TEMP%, zip en el Escritorio: cursor-config-<slug>-<fecha>.zip
No commitees el zip. Completá User Rules a mano si el script dejó el stub.
```

## Checklist

- [ ] Árbol interno = contrato v2.1 (`01-proyecto`, `02-usuario`, `03-extra`)
- [ ] Skills: markdown de contrato (`SKILL.md` + `*.md` hermanos + `references/*.md`)
- [ ] Agents de proyecto en 01 y de usuario en 02
- [ ] `PROJECT-CONTEXT.md` / `CLAUDE.md` / `.cursorignore` / `CURSOR-USAGE.md` copiados si el repo los tiene
- [ ] `03-extra` con engagement + `.atl` + `.claude/rules` si aplica; si no, solo `CAPA.md`
- [ ] `mcp.json` sin tokens
- [ ] User Rules pegadas (no el stub vacío)
- [ ] Zip en el Escritorio, staging en TEMP (no en git)
- [ ] Mismo procedimiento en el otro proyecto, el mismo día
