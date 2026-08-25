# MCP en Claude Desktop y Claude Cowork

El script de scaffolding genera **`.cursor/mcp.json`** con los servidores stdio para **IDEs que siguen esa convención** (p. ej. Cursor). En **Claude Desktop** (chat, proyectos) y **Claude Cowork** (tareas con archivos locales), los mismos servidores se registran como **conectores MCP** en la configuración de la aplicación: ahí **no** se lee el archivo `.cursor/mcp.json` del repo.

Usá los mismos **comando** y **argumentos** que figuren en tu `.cursor/mcp.json` generado (o en [`.cursor/mcp.json.example`](../.cursor/mcp.json.example) sustituyendo placeholders).

## Tabla equivalente (stdio)

| Servidor (nombre sugerido) | `command` | `args` (lista) | Notas |
|----------------------------|-----------|----------------|--------|
| **drawio** | `npx` | `-y`, `@drawio/mcp` | Requiere Node/npm en el PATH que ve **Claude Desktop** (puede diferir del PATH del terminal u otro IDE). Si falla, probá ruta absoluta a `npx` / `npx.cmd`. |
| **backlog** | `backlog` | `mcp`, `start`, `--cwd`, `<RUTA_ABS_REPO>` | `<RUTA_ABS_REPO>` = raíz de **este** repo (carpeta del proyecto generado desde el template). Si `backlog` no está en PATH, usá ruta absoluta al ejecutable como `command`. |
| **archi** | `node` | `<RUTA_ABS>\archi-mcp\dist\index.js` | Sustituí por la ruta real al `index.js` del servidor MCP Archi en tu máquina. |

En Claude Desktop: **Settings → Connectors / Developer / MCP** (el nombre exacto del menú puede variar según versión) y añadí cada servidor con transporte **stdio**, pegando comando y argumentos como lista separada.

## Política corporativa (Bedrock / Vertex / gateway)

Si tu organización despliega Cowork con inferencia en terceros, los **MCP remotos** y la allowlist las define **IT** (MDM). En ese caso seguí la guía interna y la documentación [Use Claude Cowork with third-party platforms](https://support.claude.com/en/articles/14680729-use-claude-cowork-with-third-party-platforms).

## Cowork y permisos de carpeta

Cowork solo accede a carpetas que **conectes** al iniciar la tarea. Abrí la raíz de este repositorio (o la carpeta que contenga `backlog.md` y `docs/`) para que backlog y rutas relativas tengan sentido.

## Más ayuda

Instalación detallada por SO: [MCP-PREREQUISITOS.md](MCP-PREREQUISITOS.md).
