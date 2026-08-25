---
name: draft-client-deliverable
description: "Redacta entregables orientados al cliente ({{CLIENT_DISPLAY_NAME}} — {{INITIATIVE_DISPLAY_NAME}}) desde Markdown; DOCX/Google Docs. Reportes, anexos, arquitectura."
---

# Draft Client Deliverable — {{DOC_TITLE_PREFIX}}

Usar este skill al preparar material que va a salir del repositorio y compartirse con {{CLIENT_DISPLAY_NAME}} u otros stakeholders del cliente.

## Fuente de verdad

Antes de escribir el entregable, verificar que el contenido esté respaldado por fuentes canónicas del proyecto:

- `SPEC.md` para alcance acordado (fase {{INITIATIVE_ID}} y foco actual).
- `ARCHITECTURE.md` para encuadre técnico.
- `docs/architecture-gaps-and-questions.md` para puntos abiertos y riesgos.
- Archi como fuente de verdad del modelo ArchiMate, con `docs/diagrams/{{ARCHIMATE_EXPORT_FILENAME}}` como export para versionado.
- `docs/diagrams/drawio/` y `docs/diagrams/puml/` para diagramas derivados del trabajo de arquitectura.
- `backlog.md`, `backlog/tasks/`, `backlog/meetings/` o `backlog/decisions/` para evidencia operativa.
- Material provisto por el cliente bajo `docs/client-documentation/`, si existe.
- `transcripts/` solo como material fuente crudo, nunca como documento editable de trabajo.

Si una afirmación no está respaldada por una fuente o confirmación del usuario, marcarla como pendiente de confirmación o preguntar.

## Tono y estilo de redacción

**Obligatorio en todo el texto del entregable** (resúmenes, cuerpo, anexos orientados al cliente). El documento debe leerse como escrito por un consultor IT senior argentino que se dirige a pares técnicos o directivos de tecnología. Aplicar:

### Registro general

- Español rioplatense formal: usar "ustedes" (no "vosotros"), pero evitar el voseo ("vos") en documentos de cliente. Preferir formas impersonales o infinitivos cuando sea natural ("se recomienda", "conviene evaluar", "implementar").
- Tono directo y concreto, sin rodeos ni fórmulas de cortesía excesivas. Ir al punto.
- Evitar anglicismos innecesarios cuando existe un equivalente claro en español. Usar el término técnico en inglés solo cuando es el estándar de la industria o el que el cliente maneja (API, endpoint, pipeline, cluster, gateway). No traducir forzadamente ("orquestación" está bien, "tubería" no).
- No usar jerga informal ni muletillas coloquiales (nada de "básicamente", "digamos", "ponele", "a priori" usado como "en principio").

### Construcción de oraciones

- Oraciones cortas y afirmativas. Evitar subordinadas largas y párrafos de más de 5-6 líneas.
- Preferir voz activa: "el equipo relevó los endpoints" en vez de "los endpoints fueron relevados por el equipo".
- Cuando haya un hallazgo o recomendación, enunciarlo primero y justificarlo después, no al revés.
- Evitar hedging excesivo: si algo es un problema, decir "es un problema" o "representa un riesgo", no "podría eventualmente llegar a representar cierta dificultad".

### Vocabulario técnico

- Usar la terminología que el cliente ya maneja según la documentación del proyecto. Revisar `ARCHITECTURE.md` y `docs/client-documentation/` para alinear nombres de componentes, entornos y procesos.
- Mantener consistencia terminológica dentro del documento: si se elige "catálogo de APIs" no alternar con "registro de servicios" salvo que sean conceptos distintos.
- Definir siglas en su primera aparición. No asumir que el lector conoce todas las siglas internas del equipo consultor.

### Lo que NO hacer

- No sonar como traducción del inglés ("en orden a", "siendo que", "aplica" como verbo intransitivo).
- No usar frases grandilocuentes vacías ("solución robusta de clase mundial", "ecosistema sinérgico", "transformación digital disruptiva").
- No adoptar un tono académico o de paper. Esto es un entregable de consultoría, no una tesis.
- No tutear ni vosear al cliente en el documento. Si hay que dirigirse al lector, usar "el equipo de [Cliente]" o formas impersonales.
- No usar bullet points donde un párrafo corto comunica mejor. Los bullets son para listas concretas (componentes, pasos, requisitos), no para desarrollo de ideas.

### Ejemplos de calibración

| Evitar | Preferir |
|---|---|
| "Se sugiere que eventualmente podría ser conveniente considerar la implementación de..." | "Recomendamos implementar..." |
| "El approach propuesto leveragea las capacidades del API Management layer..." | "La propuesta aprovecha las capacidades de la plataforma de gestión de APIs..." |
| "Básicamente lo que hay que hacer es..." | "El paso siguiente es..." |
| "La solución end-to-end contempla un journey holístico..." | "La solución cubre el flujo completo desde el registro hasta el consumo de la API." |
| "En base a lo relevado, se puede observar que existe una situación donde..." | "El relevamiento muestra que..." |

## Reglas para cliente

- Escribir en Markdown como fuente editable.
- **No usar** `---` ni reglas horizontales como separador visual: Pandoc las convierte en línea horizontal en el `.docx`. Separar bloques con **dos líneas en blanco** consecutivas; delimitar secciones con headings.
- Usar títulos claros, secciones breves y lenguaje orientado al cliente.
- No mencionar marcas o nombres de herramientas internas de este repositorio de trabajo, MCPs, `.cursor/`, prompts internos, reglas internas, paths internos ni nombres de archivos de trabajo.
- No citar reuniones internas solo del equipo consultor salvo que el usuario pida explícitamente un documento interno.
- Al referenciar material del cliente, usar el nombre/path reconocible por el cliente, no el path interno del repositorio.
- Para entregables bajo `docs/draft/` y `docs/deliverables/`, seguir las reglas de `client-deliverables.mdc` y el workflow de composición de `deliverable-draft-workflow.mdc` (ambos en `.cursor/rules/`).

## Markdown a Google Docs

Preferir este flujo:

1. Redactar y revisar localmente la fuente `.md`.
2. Generar o regenerar `.docx` con Pandoc cuando haga falta una importación prolija en Google Docs.
3. Abrir/importar el `.docx` en Google Docs para formato manual final y distribución.

Si el proyecto usa plantilla corporativa (`reference-doc`), aplicarla en la generación Pandoc. Tratar los `.docx` generados como artefactos: regenerarlos desde Markdown en vez de editarlos a mano.

## Markdown a DOCX — workflow con borrador

Para entregables bajo `docs/draft/`, seguir el proceso de composición documentado en `.cursor/rules/deliverable-draft-workflow.mdc` (numeración de secciones/anexos, hard-gate de lint, comando Pandoc canónico y pasos manuales en Google Docs).

## Control de calidad

Antes de considerar listo un borrador, verificar:

- El tono y estilo cumplen la sección **Tono y estilo de redacción** (registro, oraciones, vocabulario, tablas de calibración).
- No se filtraron paths internos ni nombres de herramientas internas.
- Las afirmaciones son trazables a fuentes canónicas o confirmación del usuario.
- Las preguntas abiertas aparecen como preguntas abiertas, no como hechos.
- El documento se entiende sin conocer la estructura del repositorio.
- La numeración de secciones y las referencias entre anexos son consistentes cuando el entregable se compone desde varios `.md`.
- No hay líneas `---` ni reglas horizontales en la fuente Markdown (solo dos líneas en blanco entre bloques).

## Pasada de verificación final (modelo más profundo)

Después del drafting principal y antes de pasar el `.docx` a Google Docs / SharePoint, conviene una **pasada de verificación** con un modelo de razonamiento más profundo que el usado para redactar, manteniendo la entrada acotada al borrador final.

Anunciar al usuario que cambie manualmente el modelo en el IDE si hace falta, ya que el agente no puede forzar el cambio de modelo solo.

Checklist obligatorio de la pasada de verificación:

1. **Filtraciones contra `client-deliverables.mdc`**: cualquier mención
   de herramientas internas, paths internos del repo, nombres de archivos
   de trabajo, prompts internos.
2. **Trazabilidad de afirmaciones**: cada hecho técnico debe ser
   trazable a una fuente canónica del repo o a una confirmación
   explícita del usuario; los huecos quedan marcados como pendiente.
3. **Consistencia cruzada**: numeración de secciones, referencias a
   anexos, nombres de componentes, fechas y nombres de stakeholders
   deben coincidir entre el cuerpo del documento, los anexos y los
   diagramas referenciados.
4. **Claridad sin contexto interno**: el documento se entiende sin
   conocer la estructura del repo ni la jerga interna de {{CONSULTANCY_NAME}}.
5. **Tono cliente**: cumple la sección **Tono y estilo de redacción**;
   no aparecen frases tipo "el equipo decidió internamente que…" sin
   acuerdo formal con el cliente.

Devolver un reporte breve por bullet con findings concretos
(`Sección 3.2, párrafo 2: menciona herramienta interna — reemplazar por…`),
no solo "OK / no OK". Si no hay findings, decirlo explícitamente.
