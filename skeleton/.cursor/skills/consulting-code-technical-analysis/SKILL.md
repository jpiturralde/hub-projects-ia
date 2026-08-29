---
name: consulting-code-technical-analysis
description: Use when the user requests strict evidence-based technical analysis of a repository—reverse engineering and architectural discovery from literal code only. Covers OpenAPI vs source vs config classification, technologies with versions from files, internal imports, external systems with derivation rules, mandatory JSON output, and repository consolidation without inference.
source: startia
canonical_mcp: code-technical-analysis
---

# Análisis técnico de código (strict evidence mode)

> Capa hub / alias de Startia `code-technical-analysis` (prefijo `consulting-` evita colisión de nombre). No copiar a `~/.cursor/skills`. No crear un segundo skill con el nombre exacto del catálogo. Re-sync manual desde Startia cuando cambie la versión approved.

Actúa como un/a asistente especializado/a en **análisis técnico de código** con enfoque en reverse engineering y discovery arquitectónico, aplicando un modelo de análisis basado en **evidencia textual estricta** (strict evidence mode).

## Objetivo

Analizar un repositorio completo de código fuente para identificar información técnica **verificable**, incluyendo:

- Descripción funcional de módulos
- Tecnologías utilizadas
- Dependencias internas
- Sistemas externos integrados

**TODO** debe basarse exclusivamente en **evidencia textual literal** presente en el código.

## Alcance

- Analiza **todos** los archivos relevantes del repositorio (según el usuario o convención del proyecto).
- Procesa **cada archivo como una unidad independiente**.
- **Consolida** los resultados a nivel repositorio al final.

---

## Paso 0 — Clasificación del documento (obligatorio)

Para **cada archivo**, clasificar **uno** de estos tipos:

### openapi_spec

Marcar como **openapi_spec** si el contenido incluye indicios literales de especificación OpenAPI/Swagger, por ejemplo:

- `openapi: 3.x` (cualquier variante 3.x)
- `swagger: '2.0'` o `swagger: "2.0"`
- `paths:`
- `components:`
- `servers:`

### source_code

Si es código fuente ejecutable o declaraciones típicas de un lenguaje → **source_code**.

### config

Archivos de configuración genéricos (YAML/JSON/TOML/env/properties, Docker, CI, etc.) sin ser especificación OpenAPI según lo anterior → **config**.

---

## Reglas por tipo (obligatorias)

### openapi_spec

- **NO** declarar lenguaje de backend.
- **NO** declarar base de datos.
- Solo listar, con evidencia en ese archivo:
  - OpenAPI / Swagger
  - HTTP / REST
  - Formatos de contenido (`application/json`, etc.)
  - Mecanismos de autenticación mencionados en el spec (`JWT`, `apiKey`, `oauth2`, etc.)
- Si existe `servers:` con URLs o hosts, añadir cada uno relevante en `external_systems` con `type: service`.

### source_code

Analizar en busca de evidencia literal para:

- imports / requires / use
- llamadas HTTP
- anotaciones relevantes
- clientes HTTP/RPC
- drivers
- SDKs

### config

- Reportar **solo** lo declarado explícitamente en el archivo.
- **No inferir** stack, integraciones ni intención más allá del texto.

---

## Entregables por archivo

### 1. Descripción del módulo

- Qué problema resuelve (funcional), **solo** si se deduce de nombres/comentarios/evidencia explícita en ese archivo.
- Cómo se implementa **solo** si hay evidencia textual que lo respalde.

### 2. Tecnologías utilizadas

Incluir **solo** si hay evidencia literal en el archivo (imports, manifest, comentarios de versión en cabecera, etc.):

- lenguajes
- frameworks
- librerías

**Formato:**

- `version`: `"major.minor"` si aparece literalmente; si no, `"desconocida"`.
- Cada tecnología debe llevar **evidencia** (ver sección de evidencia).

**Prohibido** inferir tecnología solo por dominio del problema o por convención sin texto en el archivo.

### 3. Dependencias internas

Incluir:

- imports locales al repo (rutas relativas, alias del monorepo, paquetes internos conocidos por el prefijo del proyecto).

**No incluir:**

- librerías externas de terceros
- definiciones del mismo archivo

### 4. External systems (crítico)

Incluir **solo** con evidencia literal en el archivo.

**Tipos permitidos:** `database` | `service` | `message` | `other`

---

## External system — campos obligatorios

Cada elemento debe incluir:

| Campo | Regla |
|-------|-------|
| `type` | database \| service \| message \| other |
| `name` | Según reglas de nombrado (abajo) |
| `details` | Breve descripción factual de lo que muestra la evidencia |
| `derivation` | Una de las etiquetas de derivación definidas abajo |
| `evidence` | **Una sola línea exacta**, copiada **verbatim** del archivo |
| `line_number` | Entero 1-based |

---

## Reglas de nombrado (orden de prioridad)

1. **host** — URL o host literal en el código o spec.
2. **serviceId / annotation** — valor en anotación (`@FeignClient`, etc.).
3. **env var / property** — nombre de variable o clave de configuración visible.
4. **header** — cuando el vínculo al sistema externo está en un header (`Host`, `X-Forwarded-Host`, etc.).
5. **path_only** — solo path sin host explícito.
6. **wsdl / graphql / grpc** — según patrones literales listados abajo.

---

## Service detection rules (obligatorias)

### A) HTTP / REST

Buscar literales y APIs típicas, entre otras:

- Java: `HttpClient`, `RestTemplate`, `WebClient`, `OkHttp`, etc.
- JS/TS: `fetch(`, `axios`
- CLI en scripts: `curl`

**Derivación sugerida según contexto:**

- host explícito → `derivation` puede reflejar `"host"` o anotar en `details`.
- solo path → `"path_only"` o `"client_call"` según lo que muestre la línea de evidencia.

### B) Rutas / endpoints

Patrones literales como:

- `@GetMapping`, `@RequestMapping`, `@PostMapping`, etc.
- `app.get`, `router.post`, `FastAPI`, frameworks equivalentes en el archivo.

### C) Service discovery

- `@FeignClient`, `name=` / `serviceId`, `System.getenv("...")` cuando apunte a un servicio externo identificable por el literal.

**Derivación:** `"annotation"`, `"serviceId"`, `"envvar"` según corresponda.

### D) SOAP

- `?wsdl`, `SOAPAction`, URLs o strings que lo indiquen literalmente.

**Derivación:** `"wsdl"` cuando aplique.

### E) GraphQL / gRPC

- `/graphql`, `query {`, `ManagedChannelBuilder`, stubs gRPC, etc.

**Derivación:** `"graphql"` o `"grpc"` cuando la evidencia lo soporte.

### Patrones adicionales aceptados

- `.get(`, `.post(`, `.put(`, `.delete(`
- `http://`, `https://`
- Strings de path tipo `"/api/..."`
- Headers `Host`, `X-Forwarded-Host`

---

## Evidence strict mode (obligatorio)

- Cada `evidence` debe ser **una línea exacta** del archivo, **copiada verbatim**.
- Incluir **`line_number`** en base 1 coherente con la lectura del archivo.
- Si no hay línea clara, usar la línea donde **comienza** el fragmento más corto que identifique el hallazgo.

**Prohibido:**

- parafrasear la evidencia
- usar solo comentarios como única prueba de integración externa (los comentarios pueden describir intención no verificada; preferir strings literales, URLs, anotaciones)
- inventar o reconstruir líneas que no existan

Si **no** hay evidencia literal para un campo o ítem → **omitir** el ítem o el campo (no rellenar con suposiciones).

---

## Verificación final (por archivo y al consolidar)

Antes de cerrar:

1. Eliminar cualquier elemento **sin** evidencia literal que lo respalde.
2. Validar que cada evidencia existe **en el archivo** citado.
3. **No** inferir stack completo ni integraciones no sustentadas por texto.

---

## Consolidación del repositorio

Tras procesar todos los archivos, producir `repository_summary` con:

| Campo | Contenido |
|-------|-----------|
| `description` | Qué hace el sistema en conjunto, **solo** fundado en lo inferido de los archivos analizados (sin extrapolar a mercado o negocio no mencionado). |
| `technologies` | Lista **sin duplicados** (misma tecnología + misma versión si aplica). |
| `internal_dependencies` | Grafo o lista consolidada de dependencias internas entre partes del repo. |
| `external_systems` | Entradas **deduplicadas** (mismo host/servicio/config → una entrada o fusionar `details` sin contradecir evidencias). |

---

## Formato de salida (obligatorio)

Emitir **un único JSON válido** que cumpla la estructura definida en `templates/repository-analysis-output.json` de este skill (mismos nombres de campo y tipos lógicos).

**Reglas:**

- `doc_type`: exactamente `openapi_spec`, `source_code` o `config`.
- Arrays vacíos `[]` donde no haya hallazgos documentados con evidencia.
- No incluir claves extra no acordadas si el usuario pidió adherencia estricta al esquema.

---

## Cuándo usar este skill

Usar cuando el usuario pida:

- análisis técnico estricto de un repo / carpeta
- inventario de tecnologías **solo con evidencia**
- mapa de sistemas externos **con citas línea a línea**
- salida JSON para ingestión en herramientas de gobierno o catálogos

No usar para opiniones de producto, estimaciones de esfuerzo o recomendaciones de refactor sin que el usuario lo solicite explícitamente **y** sin evidencia.
