# Prerrequisitos MCP — template Ingenia

Este documento describe **qué instalar** y **cómo verificarlo** para usar los MCP configurados en [`.cursor/mcp.json`](../.cursor/mcp.json). Referencia al generar el proyecto: [`.cursor/mcp.json.example`](../.cursor/mcp.json.example) (sustituí placeholders por rutas absolutas de tu máquina).

| MCP en `mcp.json` | Rol | Obligatorio |
|-------------------|-----|-------------|
| **drawio** | Abrir/editar diagramas Draw.io desde el agente (`npx @drawio/mcp`). | Si activás Draw.io MCP (por defecto en el script). |
| **backlog** | Tareas y backlog Markdown vía [Backlog.md](https://github.com/MrLesk/Backlog.md). | Solo si elegís incluir MCP backlog. |
| **archi** | Modelo ArchiMate en vivo (proceso `node` + ruta a `dist/index.js`). | Solo si elegís MCP Archi. |

### Prerrequisitos según el cliente que uses

**Comunes:** Node.js LTS (§1) y, según configures en el script, backlog / Archi como se describe más abajo. Los procesos MCP usan el **PATH** del entorno que los lanza (IDE, agente integrado o terminal integrada).

**IDE con archivo `.cursor/mcp.json`** (p. ej. [Cursor Desktop](https://cursor.com), ajustes del IDE → MCP): este repo sigue esa convención de ruta.

**Claude Desktop / Claude Cowork:** los MCP **no** se leen desde `.cursor/mcp.json`; el equivalente manual está en [MCP-CLAUDE-DESKTOP.md](MCP-CLAUDE-DESKTOP.md).

### Valores por entorno (`mcp.json`)

> **Distinto del scaffold:** los placeholders de cliente (`{{CLIENT_SLUG}}`, etc.) están en [`SKELETON-PLACEHOLDERS.md`](../../SKELETON-PLACEHOLDERS.md) y los reemplaza el script `New-ConsultingCopilotProject.ps1`. Esta tabla lista **solo lo que depende de tu máquina o de tu instalación local** al copiar [`.cursor/mcp.json.example`](../.cursor/mcp.json.example) a `.cursor/mcp.json` y reemplazar los literales por rutas absolutas reales.

| Qué configurar | Dónde en `mcp.json` | Marcador en el ejemplo | Notas |
|----------------|---------------------|------------------------|-------|
| Raíz absoluta del **repo del proyecto** (`--cwd`) | `backlog` → segundo argumento de `--cwd` | `C:\ABSOLUTE\PATH\TO\THIS\REPO` | Carpeta raíz del workspace en el IDE. En WSL/Linux usá rutas tipo `/home/...`; en Windows nativo, rutas `C:\...`. |
| **Entrada compilada** del servidor MCP Archi | `archi` → `args[0]` (ruta a `index.js`) | `C:\ABSOLUTE\PATH\TO\archi-mcp\dist\index.js` | Origen/build según equipo interno — ver § 3. |
| **Comando `backlog`** (opcional) | `backlog` → `command` | `backlog` | Si el CLI no está en el `PATH` del proceso que ejecuta los MCP, poner la **ruta absoluta** al ejecutable (PowerShell: `Get-Command backlog`). |
| **`npx` o `node`** (opcional) | `drawio` → `command` | `npx` | Si `npx` no se resuelve desde ese mismo entorno, usar ruta absoluta al binario (p. ej. con nvm/Homebrew/npm prefix). § 1 en macOS. |

---

## 1. Draw.io MCP (`@drawio/mcp`)

**Necesitás:** [Node.js](https://nodejs.org/) **LTS** (incluye `npm` y `npx`). No hace falta instalar el paquete globalmente: el cliente MCP invocará `npx -y @drawio/mcp`.

**Referencias oficiales**

- Paquete npm: [https://www.npmjs.com/package/@drawio/mcp](https://www.npmjs.com/package/@drawio/mcp)  
- Código / documentación: [https://github.com/jgraph/drawio-mcp](https://github.com/jgraph/drawio-mcp)

### Windows

1. Descargá el instalador LTS desde [https://nodejs.org/](https://nodejs.org/) (`.msi`).
2. Durante la instalación, dejá marcada la opción **Add to PATH** (o equivalente).
3. Cerrá y volvé a abrir PowerShell (y el IDE si ya estaba abierto).
4. Verificación:

   ```powershell
   node -v
   npx -y @drawio/mcp --help
   ```

   Si `npx` no resuelve el paquete, probá con la ruta explícita a `npx.cmd` (suele estar junto a `node.exe`).

### macOS

1. **Opción A (recomendada):** instalador desde [https://nodejs.org/](https://nodejs.org/)  
2. **Opción B:** Homebrew: `brew install node`  
3. Verificación:

   ```bash
   node -v
   npx -y @drawio/mcp --help
   ```

Si usás **nvm**, asegurate de que el **proceso que lanza los MCP** herede el mismo `PATH` donde está `npx` (en algunos entornos conviene poner en `mcp.json` la ruta absoluta a `npx`, p. ej. `/Users/tuusuario/.nvm/versions/node/v22.x.x/bin/npx`).

### Linux y WSL (distribución Linux)

1. **NodeSource / paquete LTS:** según tu distro, o instalador desde [https://nodejs.org/](https://nodejs.org/) (tarball / setup recomendado por Node).
2. Ejemplo **Ubuntu/Debian** (versiones empaquetadas; para LTS reciente a veces conviene el repo NodeSource):

   ```bash
   sudo apt update
   sudo apt install -y nodejs npm
   node -v
   npx -y @drawio/mcp --help
   ```

3. **WSL2:** instalá Node **dentro de la distro WSL** si el host ejecuta los MCP desde ahí; si el IDE en **Windows** lanza los MCP con ejecutables de Windows, instalá Node en **Windows**, no solo en WSL.

---

## 2. MCP Backlog ([Backlog.md](https://github.com/MrLesk/Backlog.md))

**Necesitás:** Node.js LTS + npm, y el ejecutable `backlog` en el **PATH** del mismo SO donde corre Cursor/el generador.

El generador (`New-ConsultingCopilotProject.ps1` / `New-HubProject.ps1`) **no escribe** la entrada MCP de Backlog hasta validar el CLI:

1. Detecta `backlog` con `Get-Command` (filtrando binarios Windows bajo `/mnt/*` en WSL).
2. Valida con `backlog --version`.
3. Si ya hay una instalación nativa válida, **la reutiliza** (no reinstala) e informa la ruta.
4. Si falta, en modo interactivo ofrece instalar; en no interactivo requiere `-BacklogCliChoice I` (instalar) o `X` (cancelar).
5. Instalación (mismo host/SO del script; no usa `npm.exe` de Windows desde WSL):

   ```bash
   npm install -g backlog.md@latest --include=optional
   ```

   `--include=optional` es necesario: el binario de plataforma va en dependencias opcionales.

6. Sólo tras validar de nuevo `backlog --version` se escribe `.cursor/mcp.json` con `command: "backlog"`.

Si cancelás, falta npm/node, falla `npm install` o `--version` no responde: **no** queda una entrada MCP rota; el error indica el comando manual de arriba.

El servidor MCP se invoca como: `backlog mcp start` (el script añade `--cwd` con la ruta del repo).

**Referencias oficiales**

- Repositorio e instrucciones: [https://github.com/MrLesk/Backlog.md](https://github.com/MrLesk/Backlog.md)  
- Configuración manual MCP (ejemplo con `BACKLOG_CWD`): mismo README, sección *MCP Integration*.

### Windows

1. Instalá [Node.js LTS](https://nodejs.org/) (ver §1).
2. Instalación global del CLI:

   ```powershell
   npm install -g backlog.md@latest --include=optional
   ```

   Con **Bun** (opcional): [https://bun.sh](https://bun.sh) → `bun add -g backlog.md`.

3. Verificación:

   ```powershell
   backlog --version
   backlog mcp start --help
   ```

4. Si `backlog` no se encuentra, localizá el global bin de npm y agregalo al PATH:

   ```powershell
   npm config get prefix
   Get-Command backlog -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
   ```

### macOS

**Opción A — Homebrew:**

```bash
brew install backlog-md
backlog --version
```

**Opción B — npm:**

```bash
npm install -g backlog.md@latest --include=optional
backlog --version
```

### Linux y WSL

```bash
npm install -g backlog.md@latest --include=optional
backlog --version
```

**WSL:** instalá Node y Backlog **dentro de la distro**. No reutilices un `backlog`/`npm` de Windows bajo `/mnt/c` (el generador los rechaza). Si Cursor corre en Windows nativo, instalá el CLI en Windows (§ Windows).

**Scripts del hub:** con `-IncludeBacklogMcp`, el generador garantiza el CLI antes de escribir MCP. Automatización:

```powershell
pwsh -File ./scripts/New-HubProject.ps1 -StackProfile ConsultingAI `
  -IncludeBacklogMcp -BacklogCliChoice I ...
```

`-BacklogCliChoice X` cancela sin escribir la entrada. Sin choice en entorno no interactivo: error claro (no instala en silencio).

---

## 3. MCP Archi (modelo ArchiMate + `node`)

**Necesitás:**

1. **[Archi](https://www.archimatetool.com/download/)** — aplicación desktop (instalación manual desde el sitio oficial).
2. **Plugin [jArchi](https://github.com/archimatetool/jarchi)** — según la versión de Archi que uses (en documentación de proyectos reales suele citarse **Archi 5.7+** y **jArchi 1.11+** como línea base).
3. **Node.js LTS** — para ejecutar el punto de entrada del servidor MCP (`command`: `node`, `args`: ruta a `…/dist/index.js`).
4. **Bundle `archi-mcp` / archi-server** compatible con vuestro flujo: el [`.cursor/mcp.json.example`](../.cursor/mcp.json.example) usa un **placeholder** de ruta absoluta. Esa ruta la define cada entorno (por ejemplo tooling bajo `~/Documents/Archi/scripts/archi-server/` en algunos equipos). **No** es un paquete npm público único con nombre fijo en este template; obtené la ubicación y el procedimiento de build (`npm ci`, `npm run build`, etc.) del **equipo / documentación interna** o del repo donde versionen el servidor.

**Referencias útiles (ecosistema Archi + MCP; pueden diferir en puerto y API del stack Ingenia):**

- Archi: [https://www.archimatetool.com/](https://www.archimatetool.com/)  
- jArchi: [https://github.com/archimatetool/jarchi](https://github.com/archimatetool/jarchi)  
- Ejemplo de servidor relacionado con Archi + MCP (referencia técnica genérica): [https://github.com/ThomasRohde/archi-server](https://github.com/ThomasRohde/archi-server)

**Operación típica:** Archi debe estar en ejecución con el modelo abierto y el **servidor MCP/HTTP** iniciado según el procedimiento de tu instalación (p. ej. script en menú *Scripts* de Archi), **antes** de usar las herramientas desde el IDE o el agente.

### Windows / macOS / Linux y WSL

- Instalá **Archi** y **jArchi** desde los enlaces anteriores.
- Instalá **Node** (§1).
- Construí o copiá el `dist/index.js` según indique tu equipo y actualizá `.cursor/mcp.json` con la **ruta absoluta** (en WSL usá rutas estilo `/home/usuario/...` si el host ejecuta MCP dentro de WSL).

Verificación mínima de Node:

```bash
node -v
node /ruta/absoluta/archi-mcp/dist/index.js --help
```

(si el servidor no soporta `--help`, verificá en los **logs del cliente MCP** al habilitar el servidor).

---

## 4. Verificación en el IDE

### Con `.cursor/mcp.json` (p. ej. Cursor)

1. Abrí el **workspace** en la raíz del repo generado (importante para `backlog` y `--cwd`).
2. En ajustes del IDE → **MCP**, comprobá que `drawio`, `backlog` y/o `archi` figuren sin error.
3. Si falla **backlog**: revisá `command` y `args` en `.cursor/mcp.json` (ruta al binario y `--cwd` absoluto al repo).
4. Si falla **drawio**: revisá `node`/`npx` en PATH o usá ruta absoluta a `npx`.

### Con Claude Desktop / Cowork

Registrá los conectores y comprobá logs según [MCP-CLAUDE-DESKTOP.md](MCP-CLAUDE-DESKTOP.md).

---

## 5. Otros (no son MCP, pero la documentación del template los menciona)

| Herramienta | Para qué | Enlace |
|-------------|----------|--------|
| **Pandoc** | Regenerar `.docx` de borrador desde Markdown (workflow entregables). | [https://pandoc.org/installing.html](https://pandoc.org/installing.html) |
| **Plantilla Word corporativa** | Copia manual a `docs/templates/` con el nombre configurado (p. ej. `Plantilla Ingenia - 2025.docx`). | Repositorio interno / OneDrive Ingenia |

En macOS suele citarse `brew install pandoc`. En Windows: instalador desde la página de Pandoc o, con winget, `winget search pandoc` y luego `winget install <IdPublicado>` (el identificador puede variar; no confiarlo a ciegas).

---

## Resumen rápido

| SO | Draw.io MCP | Backlog MCP | Archi MCP |
|----|-------------|-------------|-----------|
| **Windows** | Node LTS desde nodejs.org | `npm i -g backlog.md@latest --include=optional` | Archi + jArchi + Node + ruta `index.js` |
| **macOS** | Node o Homebrew `brew install node` | `brew install backlog-md` o `npm i -g backlog.md@latest --include=optional` | Igual |
| **Linux / WSL** | Node desde distro o nodejs.org | `npm i -g backlog.md@latest --include=optional` (nativo WSL; no `/mnt/c`) | Igual; atención a si MCP corre en Windows vs WSL |

*Última actualización: alineado al template Ingenia (`ingenia-template-ia`) y a `mcp.json.example` del skeleton.*
