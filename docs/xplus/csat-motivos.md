# Xplus: motivos de calificación baja y conversaciones cerradas por agente

Qué agrega esta función, cómo se configura y qué archivos la componen.

## Qué hace

**Motivos (reasons).** Cuando el cliente califica una conversación con una nota baja, se le ofrece una lista de motivos para que elija uno (opcional). El motivo queda guardado junto con la calificación y el comentario.

- Dónde aparece: en la página pública de la encuesta (`/survey/responses/<uuid>`, la que abre el botón del template de WhatsApp) y en el widget web, debajo de los emojis o estrellas.
- Cuándo: después de elegir la calificación, si es menor o igual a **"pedir motivo hasta"** (por defecto 2: Ruim/Pobre y Neutro/Justo). Al elegir un motivo se guarda al instante; se puede cambiar hasta que el cliente envíe el comentario.
- Qué lista: la configurada en la bandeja. Si la bandeja nunca configuró motivos, la encuesta usa una lista por defecto en el idioma de la cuenta (es, pt_BR, pt, en): *Demora en responder · No resolvieron mi problema · Atención poco amable · Información confusa o incorrecta · Otro*. Una lista vacía guardada a propósito desactiva la pregunta.

**Reporte del agente** (Informes → Agentes → un agente → pestaña **Calidad**):

- Panel **Conversaciones cerradas**: las conversaciones que ese agente resolvió en el período, con bandeja, fecha de cierre, calificación, motivo y comentario, con link a cada conversación. Se filtra por calificación (incluida "Sin calificación") y por motivo (incluido "Sin motivo" = calificó pero no eligió motivo). 25 por página.
- Panel **Motivos de las calificaciones bajas**: barras con cuántas veces se eligió cada motivo y cuántos calificaron sin motivo.

**Informe CSAT** (Informes → CSAT): columna **Motivo** en la tabla y en el CSV. El API `GET /api/v1/accounts/:id/csat_survey_responses` acepta `reason=<texto>` o `reason=none`.

**Conversación**: la burbuja de la encuesta en la vista de la conversación muestra el motivo debajo de la calificación.

## Configuración

Bandeja → Configuración → **CSAT** → sección **Motivos de calificación baja**:

- "Pedir motivo cuando la calificación sea … o menor": selector con las cinco calificaciones.
- Lista de motivos: chips con una X para quitar, campo + botón **Agregar** para sumar. Al abrir la sección en una bandeja que nunca configuró motivos, ya aparecen los cinco por defecto; al guardar quedan fijos en esa bandeja.

Se guarda en `inboxes.csat_config` como `reasons` (array de textos) y `reasons_max_rating` (1–5). El API de bandejas (`PATCH /api/v1/accounts/:id/inboxes/:id`) los acepta dentro de `csat_config`.

## Datos

- `csat_survey_responses.reason` (string, nulo cuando no eligió). Migración `20261026000000_add_reason_to_csat_survey_responses.rb`.
- El cliente manda `submitted_values.csat_survey_response.reason` en el `PUT` de la encuesta (`/public/api/v1/csat_survey/:uuid`) o del widget (`/api/v1/widget/messages/:id`); `CsatSurveys::ResponseBuilder` lo copia a la respuesta.
- El mensaje `input_csat` lleva en `content_attributes` los `reasons` y `reasons_max_rating` de la bandeja para que el widget los muestre; la encuesta pública los recibe en el `GET` de la encuesta.

## API del reporte

`GET /api/v2/accounts/:id/agent_insights/:user_id/conversations?since&until&page&rating&reason`

- `rating`: `1`..`5` o `none`.
- `reason`: texto exacto o `none` (calificó sin motivo).
- Respuesta: `{ total_count, page, per_page, records: [{ id, display_id, contact, inbox, labels, resolved_at, csat: { rating, reason, feedback_message, created_at } | null }] }`.

"Cerrada por el agente" = evento `conversation_resolved` con `user_id` del agente en el período (la última vez que la resolvió). La calificación es la última respuesta CSAT de esa conversación, aunque la haya dejado para otro agente asignado.

`GET /api/v2/accounts/:id/agent_insights/:user_id` suma en `csat` los campos `reasons: [{ reason, count }]` y `without_reason_count`.

## Archivos

Backend: `app/builders/v2/reports/agent_conversations_builder.rb`, `app/controllers/api/v2/accounts/agent_insights_controller.rb` (`conversations`), `app/builders/v2/reports/agent_insights_builder.rb` (`csat_reasons`), `app/builders/csat_surveys/response_builder.rb`, `app/models/csat_survey_response.rb` (`filter_by_reason`), `app/models/inbox.rb` (`CSAT_REASONS_MAX_RATING`), `app/controllers/api/v1/accounts/inboxes_controller.rb` (`format_template_config`), `app/services/message_templates/template/csat_survey.rb`, jbuilders `_csat_survey.json` y `_csat_survey_response.json`, CSV `download.csv.erb`.

Frontend: `shared/components/CsatReasons.vue` (chips), `survey/views/Response.vue`, `shared/components/CustomerSatisfaction.vue` (widget), `dashboard/.../agentInsights/AgentConversationsPanel.vue`, `AgentDetail.vue`, `AgentInsightsReports.vue`, `dashboard/api/reports.js` (`getAgentConversations`), `dashboard/.../reports/components/CsatTable.vue`, `components-next/message/bubbles/CSAT.vue`, `dashboard/.../inbox/settingsPage/CustomerSatisfactionPage.vue`. Textos en `en`, `es`, `pt`, `pt_BR` de `report.json`, `inboxMgmt.json`, `conversation.json`, `survey/i18n` y `widget/i18n`, y `config/locales/*.yml` (`reports.csat.headers.reason`).

Specs: `spec/builders/v2/reports/agent_conversations_builder_spec.rb`, `spec/controllers/api/v2/accounts/agent_insights_controller_spec.rb`.
