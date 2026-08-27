# Plan de implementación — Hub multiplataforma Windows + Ubuntu/WSL

## 1. Propósito

Convertir la automatización de `hub-projects-ia` en un sistema compatible con:

- Windows PowerShell/PowerShell 7.
- Ubuntu sobre WSL con PowerShell 7.
- Los perfiles actuales `Consulting`, `ConsultingAI`, `Full` y `GentleAi`.
- Gentle AI y Engram globales cuando ya existen.
- Instalación guiada de Gentle AI y/o Engram cuando un perfil los requiere y no existe una instalación utilizable.

La implementación debe preservar primero el comportamiento actual. Cualquier modernización funcional se evaluará después de lograr equivalencia y contar con tests.

## 2. Instrucciones para Cursor

Usar este archivo como plan y fuente de verdad durante toda la implementación.

Modelo recomendado para las fases de análisis, tests y refactor principal:

- `GPT-5.6 Sol`.
- Razonamiento `High`.
- `Agent Mode`.

Para ajustes mecánicos, documentación y correcciones simples puede utilizarse `GPT-5.6 Luna`, pero la revisión de cada hito debe realizarse con `GPT-5.6 Sol — High`.

Reglas de ejecución:

1. Trabajar una fase por vez.
2. Antes de modificar código, inspeccionar los archivos involucrados y confirmar el comportamiento actual mediante tests.
3. No avanzar a la fase siguiente si no se cumplen sus criterios de salida.
4. Mostrar los archivos que se modificarán antes de cada fase.
5. Ejecutar los tests relevantes después de cada cambio.
6. No mezclar en un mismo cambio la caracterización, el refactor y la modernización funcional.
7. No modificar archivos ajenos al alcance de la fase.
8. No tocar instalaciones reales de Gentle AI, Engram, Cursor, Git, Go o Node durante los tests.
9. No hacer `git push`, publicar releases ni borrar archivos sin autorización explícita.
10. Si el comportamiento real contradice este plan, detenerse, documentar la evidencia y solicitar decisión antes de cambiar el contrato funcional.

## 3. Resultado esperado

Al finalizar:

- Existirá una única lógica de automatización implementada en PowerShell 7 multiplataforma.
- Windows y Ubuntu/WSL usarán los mismos scripts centrales.
- Ubuntu contará con un launcher Bash liviano para invocar el motor PowerShell.
- No se mantendrán implementaciones completas duplicadas en Bash y PowerShell.
- Los cuatro perfiles conservarán su comportamiento funcional.
- El registro del hub será portable y usará rutas relativas.
- Los diagnósticos serán de solo lectura.
- Gentle AI y Engram globales se reutilizarán cuando estén disponibles y saludables.
- Cuando falte una instalación requerida, el flujo conservará la instalación guiada o la cancelación segura.
- Habrá una suite Pester que valide perfiles, escenarios de instalación y equivalencia entre Windows y Ubuntu.

## 4. Alcance

### Incluido

- `Install-ConsultingCopilot.ps1`.
- `Test-GentleAiProject.ps1`.
- `Test-HubProject.ps1`.
- `New-ConsultingCopilotProject.ps1`.
- `New-HubProject.ps1`.
- `Refresh-ProjectGettingStarted.ps1`.
- `New-IngeniaTemplateProject.ps1`.
- `New-IngeniaCursorProject.ps1`.
- `scripts/lib/ConsultingCopilot.psm1`.
- `hub-registry.json`.
- Skeletons, overlays y templates consumidos por los generadores.
- Launcher Bash para Ubuntu/WSL.
- Tests unitarios, de caracterización, integración y equivalencia.
- Documentación de ejecución en Windows y Ubuntu/WSL.

### Fuera de alcance

- Reescritura completa de los scripts en Bash.
- Modificar el contenido real de `~/.engram`, `~/.gentle-ai` o `~/.cursor` durante pruebas.
- Cambiar el contrato de componentes instalados por Gentle AI antes del hito de equivalencia.
- Migrar proyectos existentes automáticamente.
- Ejecutar la primera prueba productiva sobre IPLAN.
- Convertir `Move-HubProjectsIa.ps1` en una herramienta Ubuntu o Windows↔WSL.

## 5. Decisiones ya tomadas

### 5.1 Motor único

La lógica central permanecerá en PowerShell 7 y será multiplataforma. Bash se usará solamente como launcher en Ubuntu.

### 5.2 `Move-HubProjectsIa.ps1`

Este script fue diseñado para copiar o mover el hub/proyectos entre directorios Windows. Debe:

- Mantenerse como `Windows only`.
- Conservar su comportamiento actual salvo correcciones específicas aprobadas.
- Detectar un sistema no Windows y finalizar con un mensaje claro, sin modificar archivos.
- No usarse para migraciones Windows↔WSL.
- No tener una versión Bash equivalente.

### 5.3 Gentle AI y Engram

Para perfiles que los requieren:

- Reutilizar la instalación global si existe y es válida.
- Reutilizar una instalación de workspace si no hay global y el estado es válido.
- No duplicar Engram en `.cursor/mcp.json` si ya está administrado por Gentle AI.
- No modificar silenciosamente una instalación global existente.
- Cuando no exista una instalación utilizable, conservar un flujo explícito de instalación global, instalación en workspace o cancelación.
- Si el usuario cancela, no dejar un proyecto parcialmente creado.

### 5.4 Compatibilidad antes que modernización

El uso actual de:

```text
--component engram,sdd,skills
```

debe caracterizarse y quedar protegido con tests antes de evaluar un cambio a un preset oficial como `minimal`. No cambiarlo en esta implementación inicial.

## 6. Contrato funcional de perfiles

| Perfil solicitado | Perfil efectivo | Base | Consultoría | Gentle AI/Engram |
|---|---|---|---|---|
| `Consulting` | `Consulting` | Skeleton completo | Sí | No requerido |
| `ConsultingAI` | `ConsultingAI` | Skeleton completo | Sí | Requerido |
| `Full` | `ConsultingAI` | Igual a `ConsultingAI` | Sí | Requerido |
| `GentleAi` | `GentleAi` | Skeleton mínimo + onboarding | No | Requerido |

Reglas adicionales:

- `Full` sigue siendo un alias de `ConsultingAI`.
- Debe conservarse `requestedProfile: Full` y registrarse el perfil efectivo correspondiente.
- `Consulting` no debe buscar, instalar ni configurar Gentle AI.
- `GentleAi` no debe incorporar reglas u overlays propios de consultoría.
- `ConsultingAI` debe incluir las capas de consultoría y AI previstas actualmente.

## 7. Flujo esperado cuando un perfil requiere Gentle AI

1. Detectar si existe una configuración global válida.
2. Si existe, reutilizarla sin instalar ni sincronizar automáticamente.
3. Si no existe, detectar si hay configuración válida en el workspace.
4. Si existe solo en el workspace, reutilizarla.
5. Si existen simultáneamente configuraciones incompatibles o ambiguas, detenerse antes de escribir.
6. Si no existe ninguna configuración:
   - Verificar si el CLI `gentle-ai` está disponible.
   - Si falta, ofrecer la instalación prevista actualmente mediante Go.
   - Permitir elegir alcance global, workspace o cancelar.
7. Si se elige instalar, ejecutar exactamente una instalación en el alcance elegido.
8. Validar el resultado antes de generar/copiar el proyecto definitivo.
9. Si falla o se cancela, limpiar solamente el staging temporal creado por el proceso.

### Estados que deben distinguirse

- Gentle AI ausente.
- Gentle AI global válido.
- Gentle AI de workspace válido.
- Global y workspace simultáneos.
- Varias copias del CLI en `PATH`.
- CLI Windows resuelto desde Ubuntu/WSL.
- Engram configurado y saludable.
- Engram ausente.
- Engram configurado pero no disponible.
- Engram duplicado localmente.

## 8. Restricciones no negociables

Durante tests y diagnósticos no se debe:

- Escribir en `~/.engram`.
- Escribir en `~/.gentle-ai`.
- Escribir en `~/.cursor`.
- Ejecutar `gentle-ai install`, `sync`, `upgrade` o `uninstall` contra el entorno real.
- Iniciar o detener el Engram real.
- Modificar `.engram/engram.db` de ningún proyecto existente.
- Copiar Engram a un MCP local si ya está administrado globalmente.
- Usar binarios Windows de Git, Node, Go, Gentle AI o Engram desde Ubuntu.
- Crear proyectos de prueba dentro de un proyecto real.
- usar `exit` dentro de funciones reutilizables o módulos.

Los comandos externos deben simularse mediante mocks o ejecutables fake dentro de un directorio temporal controlado por los tests.

## 9. Arquitectura objetivo

```text
scripts/
├── hub
├── Install-ConsultingCopilot.ps1
├── Test-GentleAiProject.ps1
├── Test-HubProject.ps1
├── New-ConsultingCopilotProject.ps1
├── New-HubProject.ps1
├── Refresh-ProjectGettingStarted.ps1
├── New-IngeniaTemplateProject.ps1
├── New-IngeniaCursorProject.ps1
├── Move-HubProjectsIa.ps1
└── lib/
    ├── ConsultingCopilot.psm1
    ├── Platform.psm1
    ├── GentleAi.psm1
    ├── ProjectGenerator.psm1
    ├── HubRegistry.psm1
    └── HubRelocation.psm1

tests/
├── unit/
│   ├── Platform.Tests.ps1
│   ├── GentleAiResolution.Tests.ps1
│   ├── HubRegistry.Tests.ps1
│   └── ProjectGeneration.Tests.ps1
├── characterization/
│   ├── Consulting.Tests.ps1
│   ├── ConsultingAI.Tests.ps1
│   ├── Full.Tests.ps1
│   └── GentleAi.Tests.ps1
├── integration/
│   ├── NewHubProject.Tests.ps1
│   └── DiagnosticsReadOnly.Tests.ps1
├── equivalence/
│   └── GeneratedManifest.Tests.ps1
├── fixtures/
│   ├── fake-bin/
│   ├── fake-home/
│   ├── global-gentle-ai/
│   └── workspace-gentle-ai/
└── expected/
    ├── consulting/
    ├── consulting-ai/
    └── gentle-ai/
```

La separación exacta de módulos puede ajustarse si el análisis del acoplamiento lo justifica, pero deben mantenerse estas responsabilidades:

- Plataforma y detección del sistema operativo.
- Resolución de Gentle AI/Engram.
- Generación de proyectos.
- Lectura y migración del registry.
- Movimiento Windows-only separado de la lógica multiplataforma.

## 10. Fases de implementación

### Fase 0 — Preparación y línea de base

Objetivo: establecer un punto de partida reproducible antes de cambiar comportamiento.

Tareas:

- [ ] Crear una rama específica de trabajo.
- [ ] Registrar la versión de PowerShell, Pester, Gentle AI y Engram utilizada como referencia.
- [ ] Inventariar scripts, parámetros, funciones exportadas, skeletons, overlays y templates.
- [ ] Identificar todas las escrituras y comandos externos.
- [ ] Identificar rutas con `\\`, rutas absolutas Windows, `.exe`, `robocopy`, `Start-Process`, `exit` y llamadas a otros scripts.
- [ ] Documentar el árbol actual generado por cada perfil.
- [ ] Guardar una salida diagnóstica de referencia sin secretos ni rutas personales innecesarias.
- [ ] Confirmar que el worktree no tenga cambios ajenos que puedan mezclarse.

Criterios de salida:

- Inventario completo.
- Matriz perfil→archivos/capas/comandos.
- Riesgos documentados.
- Ningún cambio funcional realizado.

### Fase 1 — Infraestructura segura de tests

Objetivo: ejecutar tests sin tocar el entorno real del usuario.

Tareas:

- [ ] Incorporar Pester 5 como requisito de desarrollo.
- [ ] Crear un `fake-home` temporal por test.
- [ ] Inyectar o parametrizar `HOME`, raíz del hub y `PATH` de pruebas.
- [ ] Crear falsos ejecutables para `gentle-ai`, `engram`, `go`, `git`, `node`, `npx`, `backlog` y `cursor`.
- [ ] Registrar llamadas, argumentos y códigos de salida de los ejecutables fake.
- [ ] Agregar guardas que fallen si un test intenta escribir fuera del sandbox temporal.
- [ ] Agregar helper de creación y limpieza de proyectos temporales.
- [ ] Asegurar que los tests puedan ejecutarse desde cualquier directorio.

Criterios de salida:

- Un test de humo funciona en Windows y Ubuntu.
- Los tests no leen ni escriben configuración real.
- Es posible simular presencia, ausencia, duplicación y fallos de comandos.

### Fase 2 — Tests de caracterización del comportamiento actual

Objetivo: congelar el contrato existente antes del refactor.

#### Casos generales

- [ ] `Consulting` no busca ni instala Gentle AI.
- [ ] `ConsultingAI` reutiliza global cuando existe.
- [ ] `Full` produce el mismo resultado funcional que `ConsultingAI`.
- [ ] `GentleAi` usa skeleton mínimo y no agrega consultoría.
- [ ] Sin global + elección Global invoca una instalación global.
- [ ] Sin global + elección Workspace invoca una instalación workspace.
- [ ] Sin global + Cancelar no deja proyecto parcial.
- [ ] CLI ausente + aceptar instalación invoca el mecanismo de Go previsto.
- [ ] CLI ausente + fallback permitido genera el perfil efectivo esperado.
- [ ] Global y workspace incompatibles detienen el flujo antes de escribir.
- [ ] Varias copias de Gentle AI generan error o diagnóstico no saludable.
- [ ] Engram duplicado localmente genera error o diagnóstico no saludable.
- [ ] Los diagnósticos no modifican archivos.

#### Validación por perfil

`Consulting`:

- [ ] Usa skeleton completo.
- [ ] Aplica overlay de consultoría.
- [ ] No aplica overlay AI/CDD/SDD que no corresponda.
- [ ] No instala Gentle AI.
- [ ] No crea Engram local.
- [ ] Registra metadata `consulting-only` o su valor actual equivalente.

`ConsultingAI`:

- [ ] Usa skeleton completo.
- [ ] Aplica consultoría.
- [ ] Aplica la capa AI/CDD/SDD actual.
- [ ] Reutiliza o instala Gentle AI según el escenario.
- [ ] Registra `engramMcpSource: gentle-ai-managed` o su valor actual equivalente.
- [ ] No duplica Engram en `.cursor/mcp.json`.
- [ ] Registra metadata `consulting-ai` o su valor actual equivalente.

`Full`:

- [ ] Genera el mismo contenido funcional que `ConsultingAI`.
- [ ] Conserva `requestedProfile: Full`.
- [ ] Conserva el perfil efectivo equivalente a `ConsultingAI`.

`GentleAi`:

- [ ] Usa `skeleton-minimal`.
- [ ] Agrega onboarding.
- [ ] Crea `.project-profile.json`.
- [ ] No crea `.consulting-engagement.json`.
- [ ] No incorpora reglas ni overlays de consultoría.
- [ ] Reutiliza o instala Gentle AI según el escenario.

Criterios de salida:

- Tests en verde contra el comportamiento de referencia.
- Las excepciones o defectos actuales quedan documentados y marcados como `known issue`.
- No se corrigen defectos todavía dentro del mismo cambio de caracterización.

### Fase 3 — Correcciones estructurales previas

Objetivo: resolver defectos que impiden un refactor seguro, sin cambiar el contrato funcional.

Tareas:

- [x] Reemplazar `Copy-Item -LiteralPath ".../*"` por una copia portable que expanda correctamente el contenido.
- [x] Eliminar `exit` dentro de scripts llamados por otros scripts o dentro de funciones reutilizables.
- [x] Hacer que los diagnósticos devuelvan objetos/resultados estructurados.
- [x] Reservar los códigos de salida para los entrypoints ejecutables.
- [x] Separar claramente preflight, decisión del usuario, staging y commit de la creación.
- [x] Evitar proyectos parciales mediante directorios temporales y promoción final.

Criterios de salida:

- Todos los tests de caracterización siguen en verde.
- Los defectos corregidos tienen tests de regresión.

### Fase 4 — Capa multiplataforma

Objetivo: aislar diferencias Windows/Linux/WSL.

Tareas:

- [x] Implementar detección de Windows, Linux y WSL.
- [x] Resolver rutas por segmentos con `Join-Path` y APIs de `System.IO.Path`.
- [x] Eliminar fragmentos como `lib\\ConsultingCopilot.psm1` o `.cursor\\skills`.
- [x] Comparar rutas con sensibilidad a mayúsculas adecuada para cada plataforma.
- [x] Resolver dinámicamente la raíz del hub.
- [x] Validar comandos externos y su procedencia.
- [x] En Ubuntu, rechazar Git, Node, Go, Gentle AI y Engram provenientes de `/mnt/c` o terminados en `.exe`.
- [x] Permitir explícitamente el launcher Windows de Cursor desde WSL.
- [x] Advertir cuando un proyecto activo permanece bajo `/mnt/c`.
- [x] Validar rutas MCP reales y eliminar defaults Windows inválidos.
- [x] Exigir una ruta existente para Archi MCP si el perfil la requiere.

Criterios de salida:

- Tests unitarios de plataforma en verde en Windows y Ubuntu.
- Ninguna ruta del código depende de separadores Windows salvo en el script Windows-only.
- El motor puede ejecutarse desde cualquier directorio.

### Fase 5 — Resolución de Gentle AI y Engram

Objetivo: convertir la detección/instalación en un flujo explícito, testeable y seguro.

Tareas:

- [x] Extraer la detección a funciones puras cuando sea posible.
- [x] Separar presencia del CLI, configuración y estado saludable.
- [x] Modelar el resultado como un objeto con estado, alcance, rutas y errores.
- [x] Preservar la preferencia por instalación global existente.
- [x] Preservar reutilización workspace cuando corresponda.
- [x] Mantener la elección Global/Workspace/Cancelar cuando no exista configuración.
- [x] Mantener el comportamiento actual de instalación de componentes.
- [x] No ejecutar `sync`, `upgrade` ni reparación automática.
- [x] Evitar duplicar MCP de Engram.
- [x] Tratar global + workspace ambiguos como preflight fallido.
- [x] Tratar un CLI Windows dentro de WSL como inválido.
- [x] Mantener `-EngramPath` solo si es necesario para retrocompatibilidad, documentándolo como obsoleto si corresponde.

Criterios de salida:

- Matriz completa de escenarios en verde.
- Ningún test llama instalaciones reales.
- Cancelar o fallar no deja archivos productivos.

### Fase 6 — Registry portable

Objetivo: eliminar la dependencia de rutas absolutas del equipo.

Schema objetivo:

```json
{
  "schemaVersion": 2,
  "projects": [
    {
      "folderName": "iplan-prev-2142",
      "relativePath": "projects/iplan-prev-2142",
      "stackProfile": "ConsultingAI",
      "gitInitialized": true
    }
  ]
}
```

Tareas:

- [x] Implementar lectura del schema actual.
- [x] Implementar lectura del schema 2.
- [x] Convertir `absolutePath` a `relativePath` solo si la ruta pertenece al hub.
- [x] Rechazar o solicitar decisión para rutas externas al hub.
- [x] Preservar metadata desconocida durante la migración.
- [x] Resolver en runtime `Join-Path $HubRoot $project.relativePath`.
- [x] Escribir JSON de forma determinista.
- [x] Crear backup antes de una migración real.
- [x] Hacer la migración idempotente.
- [x] Validar que no queden rutas personales Windows o Linux en el registro.

Criterios de salida:

- El mismo registry funciona al abrir el hub en Windows y Ubuntu.
- Migrar dos veces no produce cambios adicionales.
- Los proyectos faltantes se reportan sin eliminar entradas automáticamente.

### Fase 7 — Generadores y scripts públicos

Objetivo: adaptar los entrypoints sin romper compatibilidad.

Tareas:

- [x] Adaptar `New-ConsultingCopilotProject.ps1` como generador central.
- [x] Adaptar `New-HubProject.ps1` como orquestador.
- [x] Adaptar `Refresh-ProjectGettingStarted.ps1` al registry relativo.
- [x] Mantener `New-IngeniaTemplateProject.ps1` como alias retrocompatible.
- [x] Mantener `New-IngeniaCursorProject.ps1` como alias retrocompatible.
- [x] Convertir `Install-ConsultingCopilot.ps1` en diagnóstico/preflight si ese es su comportamiento efectivo, manteniendo compatibilidad de nombre y parámetros.
- [x] Hacer `Test-GentleAiProject.ps1` estrictamente read-only.
- [x] Hacer `Test-HubProject.ps1` estrictamente read-only y consumir funciones, no ejecutar scripts que terminen el proceso.
- [x] Agregar ayuda y ejemplos para Windows y Ubuntu.
- [x] Mantener parámetros existentes o proveer aliases/deprecaciones claras.

Criterios de salida:

- Los entrypoints antiguos siguen funcionando.
- Los cuatro perfiles pasan sus tests.
- Los diagnósticos no cambian el estado del sistema.

### Fase 8 — Launcher Ubuntu/WSL

Objetivo: ofrecer una entrada cómoda sin duplicar lógica.

Comandos objetivo:

```bash
./scripts/hub doctor
./scripts/hub new
./scripts/hub test projects/iplan-prev-2142
./scripts/hub refresh projects/iplan-prev-2142
```

Responsabilidades permitidas del launcher:

- Resolver la raíz del hub.
- Comprobar que `pwsh` sea Linux y esté disponible.
- Traducir subcomandos a entrypoints PowerShell.
- Propagar argumentos, salida y código de retorno.
- Mostrar `--help`.

Responsabilidades prohibidas:

- Generar proyectos directamente.
- Leer o escribir el registry.
- Instalar Gentle AI o Engram.
- Duplicar validaciones de negocio.
- Implementar lógica diferente a Windows.

Tareas:

- [x] Crear `scripts/hub` (Bash) con doctor/new/test/refresh/--help.
- [x] Validar `pwsh` Linux (rechazar `/mnt` y `$IsLinux=false`).
- [x] Trazas de test (`HUB_LAUNCHER_TRACE=1`) sin lógica de negocio.
- [x] Pasar `shellcheck` y tests de integración del launcher.
- [x] Documentar en `scripts/README.md` / README / HUB-WORKFLOW.

Criterios de salida:

- El launcher pasa `shellcheck`.
- Cada subcomando invoca el entrypoint correcto.
- Los códigos de salida se preservan.

### Fase 9 — `Move-HubProjectsIa.ps1` Windows-only

Objetivo: documentar y proteger su alcance real.

Tareas:

- [x] Agregar guard explícito de Windows al inicio.
- [x] Mantener `robocopy` y la lógica Windows solo dentro de este script/módulo específico.
- [x] Actualizar ayuda indicando que no sirve para Windows↔WSL.
- [x] Agregar test que compruebe fallo temprano y sin escrituras en Linux.
- [x] Agregar test Windows de su comportamiento actual si el entorno CI lo permite.

Criterios de salida:

- En Ubuntu falla antes de modificar archivos.
- En Windows conserva el comportamiento esperado.

### Fase 10 — Equivalencia Windows–Ubuntu

Objetivo: comprobar que la plataforma no cambia el resultado funcional.

Para cada perfil generar un proyecto temporal con parámetros equivalentes y construir un manifiesto normalizado con:

- Lista de archivos.
- Hash de contenidos.
- JSON normalizado semánticamente.
- MCP configurados.
- Metadata de perfil.
- Marcadores de Gentle AI.
- Ausencia de placeholders.

Excluir de la comparación:

- `generatedAt` y `createdAt`.
- Rutas absolutas.
- Separadores `/` y `\\` cuando representen la misma ruta.
- `.git`.
- Cachés.
- Archivos administrados globalmente.

Tareas:

- [x] Normalizar manifiestos (LF, `/`, `<PROJECT_ROOT>`, timestamps JSON).
- [x] Contratos golden en `tests/expected/{consulting,consulting-ai,full,gentle-ai}/`.
- [x] Suite `tests/equivalence` (contrato + determinismo + Full≡ConsultingAI).
- [x] Documentar diferencias permitidas (`ALLOWED-DIFFS.md`) y regeneración.

Criterios de salida:

- `Consulting`: equivalente en ambas plataformas.
- `ConsultingAI`: equivalente en ambas plataformas.
- `Full`: equivalente a `ConsultingAI`, conservando el perfil solicitado.
- `GentleAi`: equivalente en ambas plataformas.
- Diferencias permitidas documentadas y justificadas.

### Fase 11 — Piloto seguro

Objetivo: validar en un caso real sin arriesgar un proyecto importante.

Tareas:

- [x] Crear un proyecto piloto descartable fuera de IPLAN, GIRE y otros proyectos activos.
- [x] Ejecutar `doctor` antes de crear.
- [x] Probar cada perfil en directorios separados.
- [x] Verificar Git, registry, onboarding y apertura de Cursor.
- [x] Confirmar que Gentle AI/Engram globales fueron reutilizados y no modificados.
- [x] Ejecutar diagnósticos después de crear.
- [x] Comparar el piloto con los expected manifests.
- [x] Documentar hallazgos y corregir mediante tests de regresión.

Criterios de salida:

- Piloto exitoso en Ubuntu/WSL.
- Piloto equivalente en Windows.
- Ningún cambio inesperado en configuraciones globales.

Notas:

- Runner reproducible: `tests/equivalence/Invoke-HubPilot.ps1`.
- Informe: `docs/PILOT-HUB-MULTIPLATFORM.md` (+ JSON).
- Windows nativo: pendiente de repetición manual; equivalencia de artefactos cubierta por Fase 10.

### Fase 12 — Documentación y cierre

Tareas:

- [ ] Documentar requisitos: PowerShell 7, Pester, `jq` si sigue siendo necesario y herramientas externas.
- [ ] Documentar comandos Windows.
- [ ] Documentar comandos Ubuntu/WSL.
- [ ] Documentar perfiles y flujo de instalación.
- [ ] Documentar recuperación ante cancelación o error.
- [x] Documentar alcance Windows-only de `Move-HubProjectsIa.ps1`.
- [ ] Documentar migración del registry schema 1→2.
- [ ] Registrar decisiones pendientes sobre componentes vs preset `minimal`.
- [ ] Ejecutar suite completa y guardar el resumen final.

Criterios de salida:

- Documentación reproducible por otra persona.
- Suite completa en verde.
- Sin rutas personales ni secretos en el repositorio.

## 11. Matriz mínima de tests de Gentle AI/Engram

| Perfil | CLI | Global | Workspace | Elección | Resultado esperado |
|---|---|---|---|---|---|
| Consulting | Ausente | No | No | N/A | Crear sin consultar Gentle AI |
| ConsultingAI | Presente | Válido | No | N/A | Reutilizar global |
| Full | Presente | Válido | No | N/A | Igual a ConsultingAI |
| GentleAi | Presente | Válido | No | N/A | Skeleton mínimo + global |
| ConsultingAI | Presente | No | Válido | N/A | Reutilizar workspace |
| GentleAi | Presente | No | Válido | N/A | Reutilizar workspace |
| ConsultingAI | Presente | No | No | Global | Instalar una vez global |
| ConsultingAI | Presente | No | No | Workspace | Instalar una vez workspace |
| GentleAi | Presente | No | No | Cancelar | No crear proyecto |
| ConsultingAI | Ausente | No | No | Instalar CLI | Instalar CLI y continuar según flujo |
| ConsultingAI | Ausente | No | No | Fallback | Aplicar fallback actual documentado |
| ConsultingAI | Presente | Válido | Válido | N/A | Detener por ambigüedad si corresponde al contrato actual |
| ConsultingAI | Duplicado | No | No | N/A | Preflight fallido |
| GentleAi | Windows `.exe` en WSL | No | No | N/A | Rechazar CLI |
| ConsultingAI | Presente | GA válido / Engram ausente | No | N/A | Informar estado y no reparar silenciosamente |
| ConsultingAI | Presente | GA válido / Engram caído | No | N/A | Informar estado y no reparar silenciosamente |

## 12. Códigos de salida propuestos

Los entrypoints pueden normalizar códigos, siempre que se preserve compatibilidad o se documente la transición:

| Código | Significado |
|---:|---|
| 0 | Operación exitosa / diagnóstico saludable |
| 1 | Error de uso o parámetro |
| 2 | Diagnóstico no saludable |
| 3 | Dependencia faltante |
| 4 | Operación cancelada por el usuario |
| 5 | Conflicto o estado ambiguo |

Las funciones internas deben devolver objetos o lanzar excepciones controladas; no deben terminar el proceso mediante `exit`.

## 13. Estrategia de commits

Mantener cambios pequeños y revisables. Secuencia sugerida:

1. `test: add isolated Pester test harness`
2. `test: characterize current project profiles`
3. `fix: make diagnostics composable and read-only`
4. `refactor: isolate platform-specific behavior`
5. `refactor: isolate Gentle AI resolution`
6. `feat: add portable hub registry schema`
7. `refactor: make project generators cross-platform`
8. `feat: add WSL hub launcher`
9. `docs: mark hub relocation as Windows-only`
10. `test: verify Windows and Ubuntu equivalence`
11. `docs: add cross-platform operating guide`

No combinar todos los puntos en un único commit.

## 14. Comandos de validación esperados

Los comandos exactos podrán ajustarse a la estructura final.

```powershell
Invoke-Pester ./tests/unit
Invoke-Pester ./tests/characterization
Invoke-Pester ./tests/integration
Invoke-Pester ./tests/equivalence
Invoke-Pester ./tests
```

En Ubuntu/WSL:

```bash
shellcheck ./scripts/hub
./scripts/hub doctor
./scripts/hub --help
pwsh -NoProfile -File ./scripts/Test-HubProject.ps1
```

Búsqueda de residuos Windows fuera del código Windows-only y fixtures:

```bash
rg -n --hidden \
  --glob '!**/.git/**' \
  --glob '!tests/fixtures/**' \
  'C:\\\\|D:\\\\|\\\\Users\\\\|robocopy\.exe|\.exe\b' \
  scripts hub-registry.json
```

La revisión debe clasificar cada coincidencia; no debe hacerse un reemplazo masivo sin contexto.

## 15. Definition of Done

La implementación estará terminada cuando:

- [ ] La suite Pester completa pasa en Windows y Ubuntu/WSL.
- [ ] Los cuatro perfiles generan la estructura esperada.
- [ ] `Full` conserva su identidad solicitada y equivale funcionalmente a `ConsultingAI`.
- [ ] Gentle AI/Engram globales válidos se reutilizan sin reinstalación.
- [ ] La ausencia de instalación requerida ofrece un flujo explícito y testeado.
- [ ] Cancelar o fallar no deja proyectos parciales.
- [ ] Ninguna prueba toca configuraciones globales reales.
- [ ] El registry utiliza rutas relativas y funciona en ambas plataformas.
- [ ] Los diagnósticos son read-only.
- [ ] Los scripts multiplataforma no contienen dependencias accidentales de Windows.
- [x] `Move-HubProjectsIa.ps1` está protegido y documentado como Windows-only.
- [x] El launcher Bash no duplica lógica de negocio y pasa `shellcheck`.
- [x] Los manifiestos normalizados de Windows y Ubuntu son equivalentes.
- [ ] Un piloto descartable fue validado antes de usar la solución sobre IPLAN.
- [ ] La documentación permite reproducir instalación, pruebas y uso.

## 16. Decisiones posteriores, no incluidas en la primera implementación

Una vez alcanzada la equivalencia, abrir decisiones separadas para:

- Sustituir `--component engram,sdd,skills` por un preset oficial como `minimal`.
- Retirar parámetros obsoletos como `-EngramPath`.
- Renombrar scripts históricos manteniendo aliases.
- Incorporar CI matricial Windows + Ubuntu.
- Agregar firma o empaquetado del módulo PowerShell.
- Evaluar si algún comando menor aporta valor como Bash nativo.

Estas decisiones requieren sus propios criterios y tests; no deben introducirse silenciosamente durante el refactor multiplataforma.

## 17. Primer paso que debe ejecutar Cursor

Cursor debe comenzar únicamente por la Fase 0 y la preparación de la Fase 1.

Prompt de inicio sugerido:

> Lee completamente `PLAN_IMPLEMENTACION_HUB_MULTIPLATAFORMA.md` y úsalo como fuente de verdad. Inspecciona el repositorio sin modificar archivos. Ejecuta la Fase 0: inventaría scripts, funciones, parámetros, comandos externos, escrituras, skeletons, overlays y dependencias específicas de Windows. Luego propone la estructura mínima del harness Pester de la Fase 1. No refactorices código productivo, no instales nada y no toques Gentle AI, Engram ni Cursor reales. Entrega hallazgos, riesgos, archivos que crearías y criterios de aceptación para que los apruebe antes de implementar.

