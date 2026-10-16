# Reporte del bot y CSAT por bot

Informes → **Bot** (`reports/bot`) muestra el desempeño del agent bot (SuporteOficialX) con la misma estructura que el reporte de agentes: cabecera con el estado actual, pestañas, tira de métricas comparadas con el período anterior y gráficos. Detrás hay tres cambios: un evento nuevo que separa "cerrada por inactividad" de "resuelta por el bot", el reporte en sí, y el CSAT atribuido al bot.

## 1. Inactividad ≠ resuelta por el bot

Upstream grababa `conversation_bot_resolved` cada vez que una conversación de una bandeja con bot activo se resolvía sin que ningún agente escribiera, incluidas las que cerraba **Resolver conversas automaticamente** (`Conversations::ResolutionJob`, cada 5 min). Ahora:

- `Conversations::ResolutionJob` marca la conversación (`conversation.auto_resolved = true`) antes de `update(status: :resolved)`.
- `Conversation#dispatcher_dispatch` agrega `auto_resolved: true` a los datos del evento solo cuando la marca está puesta (el dispatch es asíncrono, así que la marca tiene que viajar en el evento; el resto de los eventos no cambia de forma).
- `ReportingEventListener#conversation_resolved` graba `conversation_auto_resolved` en vez de `conversation_bot_resolved` cuando el evento trae esa marca. Las dos condiciones de upstream siguen: bandeja con bot activo y ningún mensaje saliente de un `User`. Si un agente había escrito, no se graba ninguno de los dos (como antes).
- El evento está registrado en `ReportingEvents::EventMetricRegistry`, `ReportingEvents::MetricRegistry` y `Reports::ReportMetricRegistry` con la métrica `auto_resolutions_count`, así que entra en el rollup diario (`RollupService`, `BackfillService`) y se puede pedir por `GET /api/v2/accounts/:id/reports?metric=auto_resolutions_count`. `BackfillService` no necesitó cambios: toma la lista de eventos del registro.

El evento solo vale desde el despliegue. Para el histórico, el 16/10/2026 se renombraron en producción (cuenta Xplus) las 892 `conversation_bot_resolved` cuyas conversaciones tenían `sox_encerramento = Inatividade` (el atributo que SuporteOficialX escribe al cerrar; la etiqueta `inatividade` solo existe desde el 14/10 y cubría 280). Se hizo con `rails runner` desde una tarea programada de Dokploy (`ReportingEvent.where(name: 'conversation_bot_resolved', conversation_id: <ids>).update_all(name: 'conversation_auto_resolved')`); la cuenta no tiene `reporting_timezone`, así que no hay rollups que reconstruir (el reporte del bot lee los eventos crudos).

Desde ese mismo día SuporteOficialX deja en `sox_step` la última etapa del bot cuando la conversación se cierra por inactividad (antes escribía "Encerrado"), para que "Dónde abandonan" tenga datos.

## 2. Reporte del bot

- API: `GET /api/v2/accounts/:id/bot_insights?since=&until=&timezone_offset=` (`Api::V2::Accounts::BotInsightsController`, mismo permiso que los demás reportes). Lo arma `V2::Reports::BotInsightsBuilder`.
- Página: `BotReports.vue` → `components/botInsights/BotDetail.vue` (+ `BotOutcomePanel.vue`, `botSchedule.js`). Reutiliza `MetricStrip`, `InsightPanel`, `ChartLegend` y `chartTheme` del reporte de agentes. `ReportsAPI.getBotInsights` en `api/reports.js`.
- Textos: `BOT_INSIGHTS` en `report.json` de `en`, `es`, `pt`, `pt_BR`.

Qué es cada número:

| Dato | Cómo se calcula |
|---|---|
| Bot y bandejas | Bandejas con `active_bot?` y sus agent bots |
| Con el bot ahora | Conversaciones `pending` con `assignee_agent_bot_id` (la pestaña Bot) |
| Derivadas sin asignar | Conversaciones `open` sin asignar en bandejas con bot |
| Conversaciones atendidas | Creadas en el período en bandejas con bot |
| Resueltas por el bot | Conversaciones con `conversation_bot_resolved` en el período |
| Cerradas por inactividad | Conversaciones con `conversation_auto_resolved` en el período |
| Pasadas al equipo | Conversaciones con `conversation_bot_handoff` en el período |
| Asumidas por un agente | Conversaciones con `conversation_opened` (pending → open) en el período **sin** handoff del bot |
| Mensajes del bot | Mensajes salientes con `sender_type = AgentBot` |
| Tiempo medio hasta resolver / derivar | Promedio del `value` (segundos desde la creación) de `conversation_bot_resolved` / `conversation_bot_handoff` |
| Tasas | Cada resultado ÷ conversaciones atendidas (en la página) |
| CSAT | `csat_survey_responses` con `assigned_agent_bot_id` (sección 3) |
| Por día / por día de semana y hora | `group_by_day` / `group_by_day_of_week` × `group_by_hour_of_day` en la zona horaria del navegador |
| Asuntos | Valores del atributo de conversación `sox_title` |
| Dónde abandonan | Valores de `sox_step` de las cerradas por inactividad |
| Etiquetas | `cached_label_list` de las conversaciones atendidas |

Si una conversación tiene handoff en el período, **el handoff gana**: no cuenta como resuelta por el bot, ni por inactividad, ni como asumida (igual que `BotMetricsBuilder` de upstream). Los eventos se cuentan por conversación distinta. "Período anterior" es el mismo largo inmediatamente antes de `since`, como en el reporte de agentes.

La página upstream (`BotMetrics.vue`, `bot_metrics`, `bot_summary`) queda sin usar pero no se borra, para facilitar el rebase.

## 3. CSAT por bot

- Migración `20261016000000_add_assigned_agent_bot_id_to_csat_survey_responses`: columna `assigned_agent_bot_id` (bigint, índice) en `csat_survey_responses`.
- `CsatSurveys::ResponseBuilder` la llena con el `ai_assignee` de la conversación cuando no hay `assignee` y el asignado es un `AgentBot` (un Captain assistant no entra). `CsatSurveyResponse belongs_to :assigned_agent_bot`; `AgentBot has_many :csat_survey_responses` (nullify).
- `GET /api/v1/accounts/:id/csat_survey_responses` (y `metrics`, `download`) aceptan `agent_bot_id` (`filter_by_assigned_agent_bot_id`). La respuesta incluye `assigned_agent_bot { id, name, thumbnail }`.
- Informes → CSAT: en el filtro **Agente** aparecen también los agent bots de la cuenta ("SuporteOficialX · Bot"); en la tabla, la columna "Atendido por" muestra el bot con la insignia Bot. En el CSV hay una columna nueva al final, "Atendido por", con el nombre del agente o del bot (las columnas de upstream no se mueven).

Para que el bot tenga CSAT hace falta activar la encuesta en la bandeja de SuporteOficialX y que el conector mande la respuesta del cliente al Chatwoot (`PATCH /public/api/v1/csat_survey/:uuid`); ver `suporteoficialx/docs/relatorio-bot-chatwoot.md`, parte B.

## Archivos

- Backend: `app/jobs/conversations/resolution_job.rb`, `app/models/conversation.rb`, `app/listeners/reporting_event_listener.rb`, `app/services/reporting_events/{event_metric_registry,metric_registry}.rb`, `app/services/reports/report_metric_registry.rb`, `app/builders/v2/reports/bot_insights_builder.rb`, `app/controllers/api/v2/accounts/bot_insights_controller.rb`, `config/routes.rb`, `app/builders/csat_surveys/response_builder.rb`, `app/models/{csat_survey_response,agent_bot}.rb`, `app/controllers/api/v1/accounts/csat_survey_responses_controller.rb`, `app/views/api/v1/models/_csat_survey_response.json.jbuilder`, `app/views/api/v1/accounts/csat_survey_responses/download.csv.erb`, `config/locales/{en,es,pt,pt_BR}.yml` (`reports.csat.headers.handled_by`), `db/migrate/20261016000000_*.rb`, `db/schema.rb`.
- Frontend: `routes/dashboard/settings/reports/BotReports.vue`, `components/botInsights/*`, `api/reports.js`, `api/csatReports.js`, `CsatResponses.vue`, `components/Csat/CsatFilters.vue`, `components/CsatTable.vue`, `i18n/locale/{en,es,pt,pt_BR}/report.json`.
- Specs: `spec/listeners/reporting_event_listener_spec.rb`, `spec/jobs/conversations/resolution_job_spec.rb`, `spec/services/reporting_events/event_metric_registry_spec.rb`, `spec/builders/v2/reports/bot_insights_builder_spec.rb`, `spec/controllers/api/v2/accounts/bot_insights_controller_spec.rb`, `spec/builders/csat_surveys/response_builder_spec.rb`, `spec/controllers/api/v1/accounts/csat_survey_responses_controller_spec.rb`, `components/botInsights/specs/botSchedule.spec.js`.

## Probar en local

`docker/xplus/setup_local.rb` crea, además de "Rosa Con Bot" (pendiente), conversaciones del bot ya terminadas con sus eventos: una resuelta por el bot con CSAT, una cerrada por inactividad con `sox_step`, una derivada al equipo y una asumida por un agente. Con el stack local arriba (`DESARROLLO.md`, paso 3), Informes → Bot tiene que mostrar esas cuatro en "Cómo terminaron las conversaciones", el CSAT en la pestaña Calidad y la etapa en "Dónde abandonan". En Informes → CSAT, el filtro Agente ofrece "SuporteOficialX · Bot".
