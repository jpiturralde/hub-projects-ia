---
name: bootstrap-consulting-engagement
description: Instancia o enriquece un repo generado desde Consulting Copilot — preguntas de contexto y redacción de README, SPEC y ARCHITECTURE. Usar al iniciar un encargo, "rellenar SPEC", "bootstrap documentación", o tras ejecutar New-ConsultingCopilotProject.ps1.
---

# Bootstrap — Consulting Copilot

## Cuándo usar esta skill

- El usuario acaba de generar un repo con `New-ConsultingCopilotProject.ps1` y quiere **contenido inicial** en `README.md`, `SPEC.md`, `ARCHITECTURE.md`.
- El usuario pide **definir alcance**, contexto del cliente o estructura de trabajo sin repetir preguntas ya resueltas.

## Antes de preguntar

1. Leer metadata del encargo en este orden:
   - **`.consulting-engagement.json`** (preferido)
   - **`.workbench-metadata.json`** (retrocompat)
   No repreguntar cliente, iniciativa, slug ni nombres de export ArchiMate si ya están allí.
2. Respetar la regla **transcripts-immutable**: no editar `transcripts/` sin confirmación explícita del usuario en el mismo hilo.
3. Los archivos bajo `docs/draft/` y `docs/deliverables/` tienen reglas estrictas: **no** introducir paths internos del repo ni nombres de herramientas internas en material que vaya al cliente.

## Flujo de trabajo

1. Confirmar objetivo: ¿solo README, solo SPEC, o los tres documentos raíz?
2. Hacer preguntas **solo** sobre huecos no cubiertos por metadata ni por archivos ya existentes con contenido sustancial.
3. Proponer **edits concretos** (Markdown) alineados al tono de consultoría del skill `draft-client-deliverable` donde aplique texto orientado al cliente; para `SPEC.md` y `ARCHITECTURE.md` puede ser tono más técnico interno si el usuario lo prefiere.
4. Dejar placeholders explícitos (`⚠ Pendiente`) donde falte información que solo el cliente pueda confirmar.

## Preguntas sugeridas (checklist)

- ¿Tipo de repo: solo documentación, código de producto, o mixto?
- ¿Objetivos medibles del encargo y fuera de alcance?
- ¿Stakeholders clave del lado cliente?
- ¿Restricciones de confidencialidad o datos sensibles?
- ¿Stack o plataformas ya conocidas (para `ARCHITECTURE.md`)?
- ¿Herramientas MCP que usarán de forma habitual (backlog, Archi, draw.io)?

## Salida esperada

- Cambios aplicables y breves en `README.md`, `SPEC.md`, `ARCHITECTURE.md`.
- Si corresponde, una lista de **próximos pasos** (ej. copiar plantilla Word a `docs/templates/`, exportar ArchiMate según metadata).
