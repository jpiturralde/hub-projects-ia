# Flujo de trabajo — Hub Projects IA

Motor único: **PowerShell 7** (`pwsh`) en Windows y Ubuntu/WSL. Guía completa: [docs/CROSS-PLATFORM.md](docs/CROSS-PLATFORM.md). Entrypoints: [scripts/README.md](scripts/README.md).

## 1. Diagnosticar

```powershell
# Windows
Set-Location "C:\ruta\hub-projects-ia\scripts"
pwsh -NoProfile -File .\Install-ConsultingCopilot.ps1 -StackProfile ConsultingAI
```

```bash
# Ubuntu / WSL
cd /home/usuario/work/hub-projects-ia
./scripts/hub doctor -StackProfile ConsultingAI
# equivalente: pwsh -File ./scripts/Install-ConsultingCopilot.ps1 ...
./scripts/hub env projects/<nombre>   # entorno del hijo (detect-only)
```

El diagnóstico es read-only (nombre histórico `Install-*`; no instala). Si hay varios ejecutables o global + workspace, corregir primero; el generador no toca archivos administrados.

Para **retrofit** de `requires` (schema 4) + GETTING-STARTED + doctor en hijos ya registrados — **mismo writer** que `Refresh-ProjectGettingStarted.ps1` (no hay script de copy-in):

```bash
./scripts/hub refresh --all
# o un hijo: ./scripts/hub refresh projects/<nombre>
# manual fuera del registry:
# pwsh -File ./scripts/Refresh-ProjectGettingStarted.ps1 -TargetPath /ruta/absoluta/hijo
```

Doctor de entorno (detect-only, mensajes en español): hijo `scripts/Test-ProjectEnvironment.ps1` o `./scripts/hub env projects/<nombre>`. Exit `2` si falla un tool required o el MCP local está `broken`.

## 2. Generar

```powershell
pwsh -NoProfile -File .\New-HubProject.ps1 `
  -StackProfile ConsultingAI `
  -ClientDisplayName "IPLAN" -ClientSlug "iplan" `
  -InitiativeDisplayName "Gobierno de APIs" -InitiativeId "U01"
```

Antes de crear el hijo:

1. Resuelve CLI Gentle AI.
2. Detecta global y workspace.
3. Reutiliza global si existe.
4. Sólo sin global pregunta Global/Proyecto/Cancelar.
5. Luego copia skeleton y overlays, escribe metadata, refresca registry y ejecuta `git init`.

## 3. Abrir el hijo

Abrir `projects/<nombre>/` como workspace raíz, no el hub. Leer `docs/GETTING-STARTED.md` y ejecutar `/start-task`.

MCP local esperado: Draw.io, Backlog y/o Archi según opciones. Engram debe aparecer por la configuración administrada por Gentle AI, no duplicado en el proyecto.

## 4. Trabajar con contexto acotado

1. Un objetivo y un dominio por chat.
2. `PROJECT-CONTEXT.md` + índice.
3. Hasta dos archivos de contenido.
4. Engram sólo por decisiones/hallazgos/punteros relevantes.
5. Fuentes pesadas por archivo exacto.

## 5. Elegir ruta

| Necesidad | Ruta |
|---|---|
| Tarea acotada | Ejecución directa |
| Análisis especializado | Agente cognitivo + skill de dominio |
| Entregable complejo | CDD |
| Desarrollo explícito | SDD |

CDD guarda el contenido completo en `.cdd/changes/` y memoria resumida en Engram.

## 6. Entregar

- Hechos confirmados primero en fuentes canónicas.
- Borradores en `docs/draft/` sin referencias internas.
- Antes de exportar: verify + revisiones client-facing y canonical-alignment.
- Transcripts permanecen inmutables salvo confirmación explícita.

## 7. Diagnosticar un hijo existente

```powershell
# Windows
pwsh -File .\Test-HubProject.ps1 -TargetPath "..\projects\iplan-prev-2142" -ExpectedProfile ConsultingAI
```

```bash
# Ubuntu / WSL
pwsh -File ./Test-GentleAiProject.ps1 -TargetPath ../projects/iplan-prev-2142
```

El resultado no aplica migraciones. Cualquier corrección de Gentle AI debe hacerse con comandos administrados y revisión previa.
