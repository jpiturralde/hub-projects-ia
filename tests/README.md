# Tests — hub-projects-ia

Suite Pester aislada para el refactor multiplataforma. Los tests **no deben** leer ni escribir configuración real de Gentle AI, Engram o Cursor.

## Requisitos

- **PowerShell 7+** (`pwsh`)
- **Pester 5+**

Instalación manual (ejemplo Ubuntu/WSL):

```bash
# PowerShell 7 — seguir guía oficial de Microsoft para tu distro
pwsh --version

pwsh -NoProfile -Command 'Install-Module Pester -MinimumVersion 5.0 -Scope CurrentUser -Force'
pwsh -NoProfile -Command 'Get-Module Pester -ListAvailable | Select-Object Name, Version'
```

## Ejecutar

Desde cualquier directorio:

```powershell
pwsh -NoProfile -File ./tests/Run-Tests.ps1
```

O por carpeta:

```powershell
Invoke-Pester ./tests/unit
Invoke-Pester ./tests/characterization   # Fase 2 — perfiles y resolución GA
Invoke-Pester ./tests
```

## Estructura

| Ruta | Propósito |
|------|-----------|
| `helpers/TestSandbox.psm1` | Sandbox temporal: fake HOME, fake hub, PATH aislado |
| `helpers/FakeCommand.ps1` | Generador de ejecutables fake con log JSON |
| `helpers/TestProjectFactory.ps1` | Utilidades para proyectos temporales |
| `fixtures/fake-home/` | Árboles `.cursor` / `.gentle-ai` de referencia |
| `fixtures/minimal-hub/` | Hub mínimo para tests de registry/layout |
| `unit/` | Tests unitarios y humo del harness |

## Variables de entorno (tests)

| Variable | Uso |
|----------|-----|
| `TEST_USER_HOME` | HOME fake; también usada por `Get-ConsultingUserHome` |
| `HUB_PROJECTS_IA_ROOT` | Raíz del hub fake; usada por `Get-HubProjectsIaRoot` |

En runtime productivo estas variables no deben estar definidas.

## Guardas de seguridad

- `Register-RealHomeSentinels` captura mtime/tamaño de archivos reales antes del test.
- `Assert-RealHomeUnchanged` falla si se modificó `~/.cursor` o `~/.gentle-ai`.
- `Assert-NoWriteOutsideSandbox` valida que las escrituras registradas queden dentro del sandbox.

## Suites legacy

Los tests preexistentes siguen en la raíz de `tests/`:

- `ConsultingCopilot.Tests.ps1`
- `Move-HubProjectsIa.Tests.ps1`

Se ejecutan junto con `Run-Tests.ps1` hasta migrarlos en fases posteriores.
