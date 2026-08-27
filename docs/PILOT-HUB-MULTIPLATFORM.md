# Piloto hub multiplataforma (Fase 11)

Fecha: 2026-08-27 · Plataforma: **WSL/Ubuntu** · Resultado: **OK**

## Objetivo

Validar el flujo real `doctor → New-HubProject → git → registry → diagnóstico → contrato expected` sin tocar IPLAN, GIRE ni otros encargos activos.

## Cómo repetir

```bash
cd /ruta/hub-projects-ia
./scripts/hub doctor -StackProfile ConsultingAI
pwsh -NoProfile -File ./tests/equivalence/Invoke-HubPilot.ps1
# Conservar proyectos: -KeepProjects
```

El script crea `pilot-hubmp-*`, valida y **limpia** (restaura `hub-registry.json`).

## Qué se verificó

| Chequeo | Resultado |
|---------|-----------|
| `doctor` (Gentle AI CLI único + global) | OK |
| Perfiles Consulting, ConsultingAI, Full, GentleAi | OK |
| `git init` en cada hijo | OK |
| `docs/GETTING-STARTED.md` | OK |
| `Get-HubProjectDiagnostic` saludable | OK |
| Contrato `tests/expected/*/manifest.json` | OK |
| Sin Engram en MCP local | OK |
| Sentinels globales (`~/.cursor/mcp.json`, `~/.gentle-ai/state.json`, `gentle-ai.mdc`) | Sin cambios |
| Registry v2 `relativePath` durante el piloto | OK (luego restaurado) |

Apertura de Cursor: no se forzó (`-SkipOpenCursor`); la ruta impresa por el generador es la del hijo como workspace raíz.

## Hallazgo corregido

`New-HubProject.ps1` aún llamaba a `Get-HubRegistry` (API previa a Fase 6). El piloto falló al primer alta; se corrigió a `Read-HubRegistry` y se añadió regresión en `tests/integration/Entrypoints.Tests.ps1`.

## Windows

Este piloto se ejecutó en WSL. La equivalencia de contenido Windows↔Ubuntu queda cubierta por `tests/equivalence` + goldens normalizados. Un piloto nativo Windows pendiente de repetición manual con el mismo script.

## Artefactos

- JSON detallado: [PILOT-HUB-MULTIPLATFORM.json](./PILOT-HUB-MULTIPLATFORM.json)
- Diferencias permitidas: [../tests/equivalence/ALLOWED-DIFFS.md](../tests/equivalence/ALLOWED-DIFFS.md)
